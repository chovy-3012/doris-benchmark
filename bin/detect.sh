#!/bin/bash


disk=~/

ARGS=`getopt -a -o h:d: -l host:,disk:,help -- "$@"`
function usage() {
    echo "Requirments: pssh, iperf"
    echo "Usage: detect.sh -h hostfile"
    echo '    Options:'
    echo '    -h hostfile'
    echo '    -d disk_path split by "," ex: /home/disk1/doris,/home/disk2/doris,/home/disk3/doris'
}
[ $? -ne 0 ] && usage
#set -- "${ARGS}"
eval set -- "${ARGS}"
while true
do
      case "$1" in
      -h|--host)
              hostfile="$2"
              shift
              ;;
      -d|--disk)
              disk="$2"
              shift
              ;;
      --help)
              usage
              exit 0
              ;;
      --)
              shift
              break
              ;;
      esac
shift
done 

if [ -z $hostfile ] 
then
    echo 'Please set hostfile'
    usage
    exit 1
fi



echo "=====cpuinfo===== "
pssh -h $hostfile -i "cat /proc/cpuinfo |grep -E 'flags|model name|cache size'| head -n3 "
echo "=====cpu core number====="
pssh -h $hostfile -i "cat /proc/cpuinfo |grep 'cpu cores'|wc -l "
echo "=====cpu siblings number====="
pssh -h $hostfile -i "cat /proc/cpuinfo | grep 'siblings'|wc -l"

echo "=====meminfo====="
pssh -h $hostfile -i "free -g"
echo "=====vm.overcommit===== "
pssh -h $hostfile -i "cat /proc/sys/vm/overcommit_memory"
echo "=====vm.swapness===== "
pssh -h $hostfile -i "cat /proc/sys/vm/swappiness"
echo "=====open files===== "
pssh -h $hostfile -i "ulimit -n"
echo "=====JAVA_HOME====="
pssh -h $hostfile -i "env | grep JAVA_HOME"
echo "=====mem test====="
remotedir="/tmp"
curdir=`dirname "$0"`
curdir=`cd "$curdir"; pwd`
pscp.pssh -h $hostfile $curdir/stream $remotedir
pssh -h $hostfile -i "$remotedir/stream"

echo "=====disk test====="
disks=(${disk//,/ }) 
for d in ${disks[@]}
do
    echo "dd test on " $d
    pssh -h $hostfile -i "dd if=/dev/zero of=$d/ddtest bs=1M count=1k oflag=direct,sync && rm $d/ddtest"
done

#pscp.pssh -h $hostfile bin/iperf /tmp
echo "=====network test====="
for h in `cat $hostfile`
do
    echo "perf test network status to " $h
    pssh -H $h -i "iperf -s -D" 
    iperf  -c $h -i 1 -t 5 -w 32M -P 4
    pssh -H $h -i "killall iperf" 
done
