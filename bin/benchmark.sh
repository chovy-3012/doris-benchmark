#!/bin/sh

set -e

BIN_PATH=`dirname "$0"`
BIN_PATH=`cd "${BIN_PATH}"; pwd`

if [ "$1" = "" ]; then
    echo "Usage: benchmark.sh -p|-c [-s 100] [-d ssb|ssb-flat|all]"
    echo "    -p: performance"
    echo "    -c: check_result"
    echo "    -s: data scale"
    echo "    -d: dataset"
    exit -1
fi

PYTHON=python3
$PYTHON $BIN_PATH/../lib/ssb_test/doris_benchmark.py "$@"
