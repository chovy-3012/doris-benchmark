#!/bin/sh

set -e

BIN_PATH=`dirname "$0"`
BIN_PATH=`cd "${BIN_PATH}"; pwd`

if [ "$1" = "" ]; then
    echo "Usage: stream_load.sh data_dir_path"
    exit -1
fi

operation_type="stream_load"
PYTHON=python3
$PYTHON $BIN_PATH/../lib/ssb_test/doris_db_table_operation.py $operation_type $1
