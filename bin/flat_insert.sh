#!/bin/sh

set -e

BIN_PATH=`dirname "$0"`
BIN_PATH=`cd "${BIN_PATH}"; pwd`

operation_type="flat_insert"
PYTHON=python3
$PYTHON $BIN_PATH/../lib/ssb_test/doris_db_table_operation.py $operation_type
