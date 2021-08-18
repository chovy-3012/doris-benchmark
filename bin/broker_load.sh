#!/bin/sh

set -e

BIN_PATH=`dirname "$0"`
BIN_PATH=`cd "${BIN_PATH}"; pwd`

if [ "$1" = "" ]; then
    echo "Usage: broker_load.sh table_name hdfs_path"
    echo "    -c: file columns"
    echo "    -cp: columns from hdfs path"
    exit -1
fi

operation_type="broker_load"
PYTHON=python3
$PYTHON $BIN_PATH/../lib/ssb_test/doris_db_table_operation.py $operation_type "$@"
