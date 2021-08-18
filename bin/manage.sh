#!/bin/bash
DORIS_HOME=/home/disk1/
VERSION=1.5.5
DORIS_CONF=doris.conf


CURDIR=`dirname "$0"`
CURDIR=`cd "$CURDIR/.."; pwd`

ARGS=`getopt -a -o h:,v:,i,u -l startfe,stopfe,startbr,stopbr,startbe,stopbe,install,uninstall,updatefe:,updatebe:,addbe,addbr,config,status,version:,clear,help -- "$@"`
function usage() {
    echo "Usage: manager.sh -h hostfile [options]"
    echo '  Options:'
    echo '    --install : install binary to remote DORIS_HOME'
    echo '    --config : sync config to remote'
    echo '    --startbe : start doris be'
    echo '    --startfe : start doris fe'
    echo '    --startbr : start doris broker'
    echo '    --stopbe  : stop doris be'
    echo '    --stopfe  : stop doris fe'
    echo '    --stopbr  : stop doris broker'
    echo '    --addbe : add backends to cluster'
    echo '    --addbr : add brokers to cluster'
    echo '    --version : indicated specific version'
    echo '    --updatebe dorisdb_be_path : update be'
    echo '    --updatefe dorsidb_fe_path : update fe'
    echo '    --uninstall : uninstall binary to remote DORIS_HOME'
    echo '    --clear : delete remote tar & bak'
    echo '    --help : show this massage'
}

function load_conf() {
    CONF_FILE=$CURDIR/conf/$DORIS_CONF
    MYSQL_HOST=`sed '/^mysql_host:/!d;s/.*://' $CONF_FILE`
    MYSQL_PORT=`sed '/^mysql_port:/!d;s/.*://' $CONF_FILE`
    MYSQL_USER=`sed '/^mysql_user:/!d;s/.*://' $CONF_FILE`
    MYSQL_PASS=`sed '/^mysql_password:/!d;s/.*://' $CONF_FILE`
    BE_HEARTBEAT_PORT=`sed '/^be_heartbeat_port: */!d;s/.*://' $CONF_FILE`
    BROKER_PORT=`sed '/^broker_port: */!d;s/.*://' $CONF_FILE`
    #echo $MYSQL_HOST, $MYSQL_PORT, $MYSQL_USER, $MYSQL_PASS
}

#function comfirm() {
#}

function uninstall() {
    echo "=====uninstalling doris===== "
    pssh -h $hostfile -i "cd $DORIS_HOME &&  mv  DorisDB-$VERSION DorisDB.bak"
}

function clear() {
    echo "=====clearing doris===== "
    pssh -h $hostfile -i "cd $DORIS_HOME &&  rm -rf DorisDB-$VERSION.tar.gz DorisDB.bak"
}

function get_status() {
    echo "=====get doris cluster status===== "
    load_conf
    if [ -z $MYSQL_PASS ]
    then
        echo "=====fe===== "
        mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "show proc \"\/frontends\";"
        echo "=====be===== "
        mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "show proc \"\/backends\";"
        echo "=====broker===== "
        mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "show proc \"\/brokers\";"
    else
        echo "=====fe===== "
        mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p $MYSQL_PASS -e "show proc \"\/frontends\";"
        echo "=====be===== "
        mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p $MYSQL_PASS -e "show proc \"\/backends\";"
        echo "=====broker===== "
        mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p $MYSQL_PASS -e "show proc \"\/brokers\";"
    fi
}

function install() {
    echo "=====installing doris===== "
    cd $CURDIR && tar xvf DorisDB-$VERSION.tar.gz
    echo "=====copying doris===== "
    pscp.pssh -v -h $hostfile $CURDIR/DorisDB-$VERSION.tar.gz $DORIS_HOME
    echo "=====unzipping doris===== "
    pssh -h $hostfile "cd $DORIS_HOME &&  tar xvf DorisDB-$VERSION.tar.gz"
    pssh -h $hostfile "mkdir -p $DORIS_HOME/DorisDB-$VERSION/fe/doris-meta"
    pssh -h $hostfile "mkdir -p $DORIS_HOME/DorisDB-$VERSION/be/storage"
}


function sync_config_fe() {
    echo "=====syncing doris fe config===== "
    echo pscp.pssh -v -h $hostfile $CURDIR/DorisDB-$VERSION/fe/conf/fe.conf $DORIS_HOME/DorisDB-$VERSION/fe/conf/
    pscp.pssh -h $hostfile $CURDIR/DorisDB-$VERSION/fe/conf/fe.conf $DORIS_HOME/DorisDB-$VERSION/fe/conf/
}

function sync_config_be() {
    echo "=====syncing doris be config===== "
    echo pscp.pssh -h $hostfile $CURDIR/DorisDB-$VERSION/be/conf/be.conf $DORIS_HOME/DorisDB-$VERSION/be/conf/
    pscp.pssh -h $hostfile $CURDIR/DorisDB-$VERSION/be/conf/be.conf $DORIS_HOME/DorisDB-$VERSION/be/conf/
}

function sync_config_br() {
    echo "=====syncing doris broker config===== "
    echo pscp.pssh -h $hostfile $CURDIR/DorisDB-$VERSION/apache_hdfs_broker/conf/apache_hdfs_broker.conf $DORIS_HOME/DorisDB-$VERSION/apache_hdfs_broker/conf/
    pscp.pssh -h $hostfile $CURDIR/DorisDB-$VERSION/apache_hdfs_broker/conf/apache_hdfs_broker.conf $DORIS_HOME/DorisDB-$VERSION/apache_hdfs_broker/conf/
}

function add_be() {
    echo "=====add doris be===== "
    load_conf
    for be in `cat $hostfile`
    do
        echo mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "ALTER SYSTEM ADD BACKEND \"$be:$BE_HEARTBEAT_PORT\""
        if [ -z $MYSQL_PASS ]
        then
            mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "ALTER SYSTEM ADD BACKEND \"$be:$BE_HEARTBEAT_PORT\""
        else
            mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p $MYSQL_PASS -e "ALTER SYSTEM ADD BACKEND \"$be:$BE_HEARTBEAT_PORT\""
        fi
    done
}

function add_br() {
    echo "=====adding doris broker===== "
    load_conf
    i=0
    for br in `cat $hostfile`
    do
        echo mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "ALTER SYSTEM ADD BROKER  \"$br:$BROKER_PORT\""
        if [ -z $MYSQL_PASS ]
        then
            mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -e "ALTER SYSTEM ADD BROKER doris \"$br:$BROKER_PORT\""
        else
            mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p $MYSQL_PASS -e "ALTER SYSTEM ADD BROKER doris \"$br:$BROKER_PORT\""
        fi
    done
}
function start_br() {
    echo "=====starting doris broker===== "
    pssh -h $hostfile -i "$DORIS_HOME/DorisDB-$VERSION/apache_hdfs_broker/bin/start_broker.sh --daemon"
}

function stop_br() {
    echo "=====stoping doris broker===== "
    pssh -h $hostfile -i "$DORIS_HOME/DorisDB-$VERSION/apache_hdfs_broker/bin/stop_broker.sh"
}

function start_be() {
    echo "=====starting doris be===== "
    pssh -h $hostfile -i "$DORIS_HOME/DorisDB-$VERSION/be/bin/start_be.sh --daemon"
}

function stop_be() {
    echo "=====stoping doris be===== "
    pssh -h $hostfile -i "$DORIS_HOME/DorisDB-$VERSION/be/bin/stop_be.sh"
}

function start_fe() {
    echo "=====starting doris fe===== "
    pssh -h $hostfile -i "$DORIS_HOME/DorisDB-$VERSION/fe/bin/start_fe.sh --daemon"
}

function stop_fe() {
    echo "=====stoping doris fe===== "
    pssh -h $hostfile -i "$DORIS_HOME/DorisDB-$VERSION/fe/bin/stop_fe.sh"
}

function update_be() {
    echo "=====update doris be===== " $BE_FILE
    pscp.pssh -v -h $hostfile $BE_FILE $DORIS_HOME/DorisDB-$VERSION/be/lib
}

function update_fe() {
    echo "=====update doris fe===== " $FE_FILE
    pscp.pssh -v -h $hostfile $FE_FILE $DORIS_HOME/DorisDB-$VERSION/fe/lib
}

[ $? -ne 0 ] && usage
#set -- "${ARGS}"
eval set -- "${ARGS}"
while true
do
      case "$1" in
      -h|--host)
              hostfile=$2
              shift
              ;;
      -v|--version)
              VERSION=$2
              shift
              ;;
      -i|--install)
              op="install"
              ;;
      -u|--uninstall)
              op="uninstall"
              ;;
      --clear)
              op="clear"
              ;;
      --startbe)
              op="start_be"
              ;;
      --stopbe)
              op="stop_be"
              ;;
      --startbr)
              op="start_br"
              ;;
      --stopbr)
              op="stop_br"
              ;;
      --startfe)
              op="start_fe"
              ;;
      --stopfe)
              op="stop_fe"
              ;;
      --updatefe)
              FE_FILE=$2
              if [ ! -f $FE_FILE ]; then echo "file not found:" $FE_FILE ;exit 1; fi
              op="updatefe"
              shift
              ;;
      --updatebe)
              BE_FILE=$2
              if [ ! -f $BE_FILE ]; then echo "file not found:" $BE_FILE ;exit 1; fi
              op="updatebe"
              shift
              ;;
      -c|--config)
              op="config"
              ;;
      --addbe)
              op="add_be"
              ;;
      --addbr)
              op="add_br"
              ;;
      --status)
              op="getstatus"
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


case "$op" in
    "start_be")
        start_be
        ;;
    "stop_be")
        stop_be
        ;;
    "start_br")
        start_br
        ;;
    "stop_br")
        stop_br
        ;;
    "start_fe")
        start_fe
        ;;
    "stop_fe")
        stop_fe
        ;;
    "add_be")
        add_be
        ;;
    "add_br")
        add_br
        ;;
    "updatebe")
        update_be
        ;;
    "updatefe")
        update_fe
        ;;
    "install")
        install
        ;;
    "uninstall")
        uninstall
        ;;
    "getstatus")
        get_status
        ;;
    "clear")
        clear
        ;;
    "config")
        sync_config_fe
        sync_config_be
        sync_config_br
        ;;
esac
