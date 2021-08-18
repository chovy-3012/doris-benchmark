## Star Schema Benchmark 测试工具包

### requirments

1. python3
2. java 注意每个用户配置JAVA_HOME
3. pymysql 安装: pip3 install pymysql
4. pssh 安装并打通ssh: yum install -y pssh
5. iperf 安装: yum install -y iperf  

### scripts

* benchmark.sh  性能测试脚本
* broker_load.sh 根据配置拆分并提交broker导入任务
* create_db_table.sh 创建ssb table
* dbgen         ssb数据生成工具
* detect.sh     硬件检测脚本
* gen-ssb.sh    ssb数据生成脚本 
* manage.sh     集群部署/启停脚本 
* stream        内存检测工具 
* stream_load.sh stream_load方式并行导入数据

### ssb测试步骤

1. 确认requirments都安装完成
2. 编译工具并安装, 所有文件安装到output目录:
```
$ make && make install
```
3. cd output 并创建 hosts fe be broker文件，分别存放所有机器/FE/BE/broker的IP, 一行一个, 例如:
```
$ cat hosts
192.168.1.1
192.168.1.2
192.168.1.3
192.168.1.4
$ cat fe
192.168.1.1
$ cat be
192.168.1.2
192.168.1.3
192.168.1.4
$ cat broker
192.168.1.1
192.168.1.2
192.168.1.3
192.168.1.4
```
4. 确认pssh 可以免密打通
```
$ pssh -h hosts -i "whoami"
```
5. 检测机器环境并输出到文件 
```
$ bin/detect.sh -h hosts -d /home/disk1/doris | tee host_status
```
如果有多块硬盘可以使用 -d /home/disk1,/home/disk2

6. 复制安装包到output目录
```
$ cp xxx/DorisDB-xxx.tar.gz output/
```
然后修改 bin/manage.sh 的DORIS_HOME, 该目录是远程安装doris的目录, 如果版本升级可能修改VERSION

7. 安装doris到远程所有hosts机器 
```
$ bin/manage.sh -h hosts --install
```
8. 修改 Doris-version/fe/conf/fe.conf  Doris-version/be/conf/be.conf Doris-version/broker/conf/broker.conf
  - be.conf 添加配置
    - push_write_mbytes_per_sec=100
    - brpc_max_body_size=2097152000
    - brpc_socket_max_unwritten_bytes=1342177280
  - fe.conf 添加配置
    - -Xmx4096m 修改为 -Xmx32768m
9. 同步配置文件到远程 
```
$ bin/manage.sh -h hosts --config
```
10. 启动be  
```
$ bin/manage.sh -h be --startbe
```
11. 启动fe 
```
$ bin/manage.sh -h fe --startfe 
``` 
12. 启动broker 
```
$ bin/manage.sh -h broker --startbr 
```
13. (Optional) 用mysql连接集群 创建用户(https://doris.apache.org/master/zh-CN/getting-started/basic-usage.html#_1-%E5%88%9B%E5%BB%BA%E7%94%A8%E6%88%B7) 配置权限(https://doris.apache.org/master/zh-CN/getting-started/basic-usage.html#_2-2-%E8%B4%A6%E6%88%B7%E6%8E%88%E6%9D%83)
14. 修改conf/doris.conf  配置集群端口 用户密码等 
```
# for mysql cmd
mysql_host: test1
mysql_port: 9030
mysql_user: root
mysql_password:
doris_db: ssb

# cluster ports
http_port: 8030
be_heartbeat_port: 9050
broker_port: 8000

...
```

15. 添加be/broker到集群 
```
$ bin/manage.sh -h be --addbe  &&  bin/manage.sh -h broker --addbr 
```
完成后可以用 查看be fe 状态
```
$ bin/manage.sh -h hosts --status 
```
16. (Optional) 安装部署DorisManager 可以方便查看集群状态和Profile等
17. 生成ssb数据(100GB) 
```
$ bin/gen-ssb.sh 100 data_dir
```
18. 生成ssb表结构(100GB规模的建表语句) 
```
$ bin/create_db_table.sh ddl_100
```
19. 导入ssb多表数据 
```
$ bin/stream_load.sh data_dir
```
20. 测试ssb多表查询 (SQL 参见 share/ssb_test/sql/ssb/) 
```
$ ssb bin/benchmark.sh -p -d ssb 
```
21. 生成ssb单表数据 
```
$ bin/flat_insert.sh
```
22. 测试ssb单表查询(SQL 参见 share/ssb_test/sql/ssb-flat/) 
```
$ bin/benchmark.sh -p -d ssb-flat  
```

### 升级过程
1. 停止BE 
```
$ bin/manage.sh -h be --stopbe
```
2. 升级BE 
```
$ bin/manage.sh -h be --updatebe xxx/dorisdb_be
```
3. 启动BE 
```
$ bin/manage.sh -h be --startbe
```
4. 停止FE 
```
$ bin/manage.sh -h fe --stopfe
```
5. 升级FE 
```
$ bin/manage.sh -h fe --updatefe xxx/dorsdb-fe.jar
```
6. 启动FE 
```
$ bin/manage.sh -h fe --startfe
```

### 清理
1. 停止be  
```
$ bin/manage.sh -h be --stopbe
```
2. 停止broker  
```
$ bin/manage.sh -h broker --stopbr
```
3. 停止fe  
```
$ bin/manage.sh -h fe --stopfe
```
4. 删除doris (仅仅重命名了目录)
```
$ bin/manage.sh -h hosts --uninstall 
```
4. (Optional)清除doris (删除备份目录)
```
bin/manage.sh -h hosts --clear 
```
