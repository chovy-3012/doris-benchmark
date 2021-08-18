#!/usr/bin/env python
# -- coding: utf-8 --
import argparse
import json
import os
import subprocess
import sys
import time
import threading
sys.path.append(".")

import doris_lib
import conf_parser


CONCURRENCY_NUM = 10
CONCURRENCY_TABLES = ["lineorder"]


class StreamLoadThread(threading.Thread):
    def __init__(self, table_name, file_path):
        threading.Thread.__init__(self)
        self.table_name = table_name
        self.file_path = file_path
        self.lib = doris_lib.CommonLib()

    def run(self):
        print("stream load start. table: %s, path: %s" % (self.table_name, self.file_path))
        cmd = self.lib.get_stream_load_cmd(self.file_path, self.table_name)
        res, output = subprocess.getstatusoutput(cmd)
        is_success = False
        msg = None
        error_url = None
        for line in output.split("\n"):
            if "\"Status\": \"Success\"" in line:
                is_success = True
            if "Message" in line:
                msg = line
            if "ErrorURL" in line:
                error_url = line

        if is_success:
            print("stream load success. table: %s, path: %s" % (self.table_name, self.file_path))
        else:
            print("stream load error. table: %s, path: %s, msg: %s, error_url: %s" % (self.table_name, self.file_path, msg, error_url))


class DorisDbTableOperation(object):
    def __init__(self):
        self.lib = doris_lib.CommonLib()

    def connect_doris(self):
        self.lib.connect_doris()

    def close_doris(self):
        self.lib.close_doris()

    def create_database(self, db_name):
        return self.lib.create_database(db_name)

    def use_database(self, db_name):
        self.lib.use_database(db_name)

    def create_db_table(self, data_dir_path):
        self.connect_doris()
        try:
            # create db
            doris_db = conf_parser.doris_db
            res = self.lib.create_database(doris_db)
            if res is None:
                print("create database error.")
                sys.exit(-1)
            if not res["status"]:
                print("create database error, msg: %s" % (res["msg"]))
                sys.exit(-1)

            # use db
            self.use_database(doris_db)

            # get create db table sql
            ddl_sqls = self.lib.get_create_db_table_sqls(data_dir_path)
            for sql_dict in ddl_sqls:
                res = self.lib.execute_sql(sql_dict["sql"], "ddl")
                if res is None:
                    print("sql: %s. create table error" % (sql_dict["file_name"]))

                if not res["status"]:
                    print("sql: %s. create table error, msg: %s" % (sql_dict["file_name"], res["msg"]))
                else:
                    print("sql: %s success" % (sql_dict["file_name"]))
        finally:
            self.close_doris()

    def stream_load(self, data_dir_path):
        load_data_paths = self.lib.get_load_data_paths(data_dir_path)
        for file_name in load_data_paths:
            table_name = file_name
            file_paths = load_data_paths[table_name]

            thread_num = 1
            if table_name in CONCURRENCY_TABLES:
                thread_num = CONCURRENCY_NUM

            left_num = len(file_paths)
            index = 0
            while index < len(file_paths):
                thread_num_this_cycle = min(left_num, thread_num)
                threads = list()
                for i in range(thread_num_this_cycle):
                    t = StreamLoadThread(table_name, file_paths[index])
                    t.start()
                    threads.append(t)
                    index = index + 1
                for t in threads:
                    t.join()
                left_num = left_num - thread_num_this_cycle

    def flat_insert(self):
        self.connect_doris()
        try:
            # use db
            doris_db = conf_parser.doris_db
            self.use_database(doris_db)

            # get flat insert sql
            insert_sqls = self.lib.get_flat_insert_sqls()
            for sql_dict in insert_sqls:
                print("sql: %s start" % (sql_dict["file_name"]))
                res = self.lib.execute_sql(sql_dict["sql"], "dml")
                if res is None:
                    print("sql: %s. flat insert error" % (sql_dict["file_name"]))

                if not res["status"]:
                    print("sql: %s. flat insert error, msg: %s" % (sql_dict["file_name"], res["msg"]))
                else:
                    print("sql: %s success" % (sql_dict["file_name"]))
        finally:
            self.close_doris()

    def parse_broker_load_args(self):
        """
        parse args
        """
        parser = argparse.ArgumentParser(description="broker load args parser")
        parser.add_argument("table_name", type=str, help="doris table name")
        parser.add_argument("hdfs_path", type=str, help="hdfs path")
        parser.add_argument("-c", "--columns", dest="columns", action="store",
                            type=str, default="", help="file columns")
        parser.add_argument("-cp", "--columns_from_path", dest="columns_from_path",
                            action="store", type=str, default="", help="columns from hdfs path")
        # skip this_file and operation_type
        return parser.parse_args(sys.argv[2:])

    def broker_load(self, table_name, hdfs_path, columns, columns_from_path):
        """
        split small broker load jobs according to config.max_bytes_per_job
        """
        self.connect_doris()
        try:
            # get all files size in hdfs path
            # [(file_path, file_size), ...]
            file_list = self.lib.get_hdfs_file_infos(hdfs_path)
            if not file_list:
                raise doris_lib.DorisException("get hdfs file infos error. file list empty")

            # use db
            doris_db = conf_parser.doris_db
            self.use_database(doris_db)

            # get file columns
            if not columns:
                res = self.lib.execute_sql("describe %s" % (table_name), "dml")
                if res is None:
                    raise doris_lib.DorisException("table:%s get schema error" % (table_name))
                if not res["status"]:
                    raise doris_lib.DorisException("table:%s get schema error. msg: %s"\
                                                   % (table_name, res["msg"]))
                table_columns = [column_info[0] for column_info in res["result"]]
                columns = [c for c in table_columns if c not in columns_from_path]

            # split and submit broker load job
            file_num = len(file_list)
            i = 0
            while i < file_num:
                job_file_list = []
                job_file_size = 0
                while i < file_num:
                    file_info = file_list[i]
                    job_file_size = job_file_size + int(file_info[0])
                    if not job_file_list or job_file_size < conf_parser.max_bytes_per_job:
                        job_file_list.append(file_info[1])
                        i = i + 1
                    else:
                        break

                sql = self.lib.get_broker_load_sql(doris_db, table_name, job_file_list,
                                                   columns, columns_from_path)
                res = self.lib.execute_sql(sql, "dml")
                print("-" * 18)
                if res is None:
                    print("%s\n\nbroker load job submit error." % (sql))

                if not res["status"]:
                    print("%s\n\nbroker load job submit error. msg: %s" % (sql, res["msg"]))
                else:
                    print("%s\n\nbroker load job submit success." % (sql))
        except doris_lib.DorisException as e:
            print(e.value)
            sys.exit(-1)
        finally:
            self.close_doris()


if __name__ == '__main__':
    doris_operation = DorisDbTableOperation()
    if len(sys.argv) < 2:
        print("missing operation type: create | stream_load")
        sys.exit(-1)
    operation_type = sys.argv[1]
    if operation_type == "create":
        if len(sys.argv) < 3:
            print("missing data dir path")
            sys.exit(-1)
        doris_operation.create_db_table(sys.argv[2])
    elif operation_type == "stream_load":
        if len(sys.argv) < 3:
            print("missing data dir path")
            sys.exit(-1)
        doris_operation.stream_load(sys.argv[2])
    elif operation_type == "flat_insert":
        doris_operation.flat_insert()
    elif operation_type == "broker_load":
        args = doris_operation.parse_broker_load_args()
        table_name = args.table_name
        hdfs_path = args.hdfs_path
        columns = [c.strip() for c in args.columns.split(",")] if args.columns else []
        columns_from_path = [c.strip() for c in args.columns_from_path.split(",")]\
            if args.columns_from_path else []
        doris_operation.broker_load(table_name, hdfs_path, columns, columns_from_path)
    else:
        print("error operation type: " + operation_type)
