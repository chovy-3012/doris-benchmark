#!/usr/bin/env python
# -- coding: utf-8 --
import configparser
import os
import sys

root_path = os.path.dirname(os.path.abspath(__file__)) + "/../.."

doris_config = "%s/conf/doris.conf" % (root_path)
if os.path.exists(doris_config) == False:
    sys.exit()
config = configparser.ConfigParser()
config.read(doris_config)

# doris config
doris_mysql_host = config.get("doris", "mysql_host")
doris_mysql_port = config.get("doris", "mysql_port")
doris_mysql_user = config.get("doris", "mysql_user")
doris_mysql_password = config.get("doris", "mysql_password")
doris_db = config.get("doris", "doris_db")
doris_http_port = config.get("doris", "http_port")
sleep_ms = config.get("doris", "sleep_ms")

# optional
parallel_num_string = config.get("doris", "parallel_num", fallback="1")
parallel_num_list = parallel_num_string.split(",")
concurrency_num_string = config.get("doris", "concurrency_num", fallback="1")
concurrency_num_list = concurrency_num_string.split(",")
num_of_queries = config.getint("doris", "num_of_queries", fallback=1)

# broker config
broker_name = config.get("broker_load", "broker")
broker_username = config.get("broker_load", "broker_username")
broker_password = config.get("broker_load", "broker_password")
hadoop_home = config.get("broker_load", "hadoop_home")
max_bytes_per_job = config.getint("broker_load", "max_bytes_per_job", fallback=524288000)
file_format = config.get("broker_load", "file_format", fallback="orc")
column_separator = config.get("broker_load", "column_separator", fallback="\t")
max_filter_ratio = config.get("broker_load", "max_filter_ratio", fallback="0")
timeout = config.get("broker_load", "timeout", fallback="14400")
