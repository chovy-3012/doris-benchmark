#!/usr/bin/env python
# -- coding: utf-8 --
import argparse
import json
import time
import os
import subprocess
import sys
import time
sys.path.append(".")

import doris_lib
import conf_parser


MYSQLSLAP_RESULT_STR = "Average number of seconds to run all queries"


class DorisBenchmark(object):
    def __init__(self):
        self.lib = doris_lib.CommonLib()

    def parse_args(self):
        """
        parse args
        """
        parser = argparse.ArgumentParser(description="benchmark args parser")
        parser.add_argument("-p", "--performance", dest="performance", action="store_true",
                            default=False, help="test performance")
        parser.add_argument("-c", "--check_result", dest="check_result", action="store_true",
                            default=False, help="check result")
        parser.add_argument("-s", "--scale", dest="scale", type=int, action="store",
                            default=100, help="data scale")
        parser.add_argument("-d", "--dataset", type=str, action="store",
                            default="all", help="dataset")
        return parser.parse_args()

    def connect_doris(self):
        self.lib.connect_doris()

    def close_doris(self):
        self.lib.close_doris()

    def use_database(self, db_name):
        self.lib.use_database(db_name)

    def sort_sql_list(self, sql_list):
        """
        order by q1, q2, ... q10
        """
        for sql_dict in sql_list:
            sql_dict["index"] = int(sql_dict["file_name"][1:])
        sql_list.sort(key = lambda x: x["index"])

    def get_test_sql_dirs(self, sql_dirname):
        test_sql_dirs = []
        # get all query sql dirs
        sql_dirs = self.lib.get_query_sql_dirs()
        # check user assigned sql dir
        if sql_dirname == "all":
            test_sql_dirs.extend(sql_dirs)
        elif sql_dirname in sql_dirs:
            test_sql_dirs.append(sql_dirname)
        else:
            print("wrong dataset: %s, alternative: ssb | ssb-flat | all" % (sql_dirname))
            sys.exit(-1)
        return test_sql_dirs

    def test_parallel_performance(self, sql_dirname):
        """ parallel performance """

        self.connect_doris()
        try:
            # use db
            doris_db = conf_parser.doris_db
            self.use_database(doris_db)

            # check sql dir args
            test_sql_dirs = self.get_test_sql_dirs(sql_dirname)

            # execute query
            # sql\time(ms)\parallel_num   1   2   3
            # sql1  10  20  30
            # sql2  11  21  31
            for sql_dir in test_sql_dirs:
                sql_list = self.lib.get_query_table_sqls(sql_dir)
                self.sort_sql_list(sql_list)
                for concurrency_num in conf_parser.concurrency_num_list:
                    print("------ dataset: %s, concurrency: %s ------" % (sql_dir, concurrency_num))
                    print("sql\\time(ms)\parallel_num\t%s" % ("\t".join(conf_parser.parallel_num_list)))
                    for sql_dict in sql_list:
                        result = []
                        result.append(sql_dict["file_name"])
                        for parallel_num in conf_parser.parallel_num_list:
                            query_dict = {}
                            query_dict["parallel_num"] = parallel_num
                            query_dict["concurrency"] = concurrency_num
                            query_dict["num_of_queries"] = conf_parser.num_of_queries
                            query_dict["database"] = doris_db
                            query_dict["sql"] = sql_dict["sql"]

                            cmd = self.lib.get_parallel_cmd(query_dict)
                            begin_time = time.time()
                            res, output = subprocess.getstatusoutput(cmd)
                            end_time = time.time()
                            if res != 0 or (output and MYSQLSLAP_RESULT_STR not in output):
                                print("exec sql error. sql: %s, output: \n%s" \
                                    % (sql_dict["file_name"], output))
                                result.append("-")
                            else:
                                time_cost = (int(round(end_time * 1000)) - int(round(begin_time * 1000)))\
                                    / int(1 if conf_parser.num_of_queries < int(concurrency_num)
                                      else conf_parser.num_of_queries / int(concurrency_num))
                                result.append(str(time_cost))
                            time.sleep(int(conf_parser.sleep_ms)/1000.0)
                            #print(begin_time, end_time, time_cost, output)

                        print("\t".join(result))
        finally:
            self.close_doris()

    def check_results(self, sql_dirname, scale):
        self.connect_doris()
        try:
            # use db
            doris_db = conf_parser.doris_db
            self.use_database(doris_db)

            # check sql dir args
            test_sql_dirs = self.get_test_sql_dirs(sql_dirname)

            # execute query and diff
            for sql_dir in test_sql_dirs:
                print("------ %s ------" % (sql_dir))
                sql_list = self.lib.get_query_table_sqls(sql_dir)
                self.sort_sql_list(sql_list)
                for sql_dict in sql_list:
                    query_res = self.lib.execute_sql(sql_dict["sql"], "dml")
                    if query_res is None:
                        print("sql: %s. exec sql error." % (sql_dict["file_name"]))
                        continue

                    if not query_res["status"]:
                        print("sql: %s. exec sql error, msg: %s" % (sql_dict["file_name"], query_res["msg"]))
                        continue

                    # get base result from file
                    base_result = self.lib.get_query_base_result(sql_dir, scale, sql_dict["file_name"])
                    if base_result is None:
                        print("sql: %s, scale: %d. check result error, msg: base result file not exist" % (sql_dict["file_name"], scale))
                        continue

                    # diff query result
                    # row count
                    query_result = query_res["result"]
                    if len(query_result) != len(base_result):
                        print("sql: %s. check result error, row count is different, base: %s, query: %s" \
                                % (sql_dict["file_name"], len(base_result), len(query_result)))
                        continue

                    # row
                    i = 0
                    is_same = True
                    for line in query_res["result"]:
                        normalize_line = [str(col) if col is not None else "NULL" for col in line]
                        normalize_line_str = "\t".join(normalize_line)
                        base_result_line_str = base_result[i]
                        i = i + 1
                        if normalize_line_str != base_result_line_str:
                            is_same = False
                            print("sql: %s. check result error, row content is different, base: (%s), query: (%s)" \
                                % (sql_dict["file_name"], base_result_line_str, normalize_line_str))
                            break
                    if not is_same:
                        continue

                    print("sql: %s ok" % (sql_dict["file_name"]))
        finally:
            self.close_doris()


if __name__ == '__main__':
    benchmark = DorisBenchmark()
    # check args
    args = benchmark.parse_args()
    if args.performance and args.check_result:
        print("-c and -p should not be assigned at the same time")
        sys.exit(-1)
    elif args.performance:
        benchmark.test_parallel_performance(args.dataset)
    elif args.check_result:
        benchmark.check_results(args.dataset, args.scale)
    else:
        print("missing -c or -p args")
        sys.exit(-1)
