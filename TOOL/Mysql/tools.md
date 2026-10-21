```sql
-- 运维工具





#mysql客户端工具（终端执行）

-- 查看本地IP
ipconfig getifaddr en0

#mysql
mysql options [database_name]
options:
-h: 主机地址
-P: 端口（默认3306）
-u: 用户名
-p: 密码（后面不加空格直接跟密码，但安全起见建议不写）
-e: 执行SQL并退出

#mysqlladmin
mysqladmin options action
action:
查看MySQL状态 status
#查看所有变量 variables
查看所有进程 processlist
创建数据库 create newdb
删除数据库 drop olddb
修改密码 password 'new password'
重载权限 reload
关闭MySQL shutdown
刷新日志 flush-logs
查看扩展状态 extended-status

#mysqldump
备份数据库 mysqldump -u root -p database_name > backup.sql
备份所有数据库 mysqldump -u root -p --all-databases > all_backup.sql
只备份结构 mysqldump -u root -p --no-data database_name > structure.sql
恢复备份 mysql -u root -p database_name < backup.sql

-- mysqlimport
导入CSV文件      mysqlimport -u root -p --fields-terminated-by=',' database_name data.csv
指定列分隔符      mysqlimport -u root -p --fields-terminated-by='|' database_name data.txt





#LOG

-- ERROR LOG

-- 查看错误日志配置
SHOW VARIABLES LIKE 'log_error%';
SHOW VARIABLES LIKE 'datadir';

-- 设置错误日志路径（my.cnf）
[mysqld]
log_error = /var/log/mysql/error.log
log_warnings = 2  -- 记录警告信息

-- 查看错误日志内容（命令行）
tail -f /var/log/mysql/error.log
错误日志示例
2024-01-15T10:30:00.123456Z 0 [ERROR] InnoDB: Unable to lock ./ibdata1 error: 35

-- BINLOG

-- 查看 Binlog 配置
SHOW VARIABLES LIKE 'binlog%';

--查看二进制日志内容
mysqlbinlog [--host=192.168.1.100 --user=root --password] binlog.000001

-- 恢复数据
mysqlbinlog --start-datetime="2024-01-01 10:00:00" \
--stop-datetime="2024-01-01 11:00:00" \
mysql-bin.000001 | mysql -u root -p
FLUSH LOGS;

-- SLOW QUERY LOG

-- 查看慢查询配置
SHOW VARIABLES LIKE 'slow_query_log%';

-- 开启慢查询日志
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 2;  -- 超过2秒记录
SET GLOBAL log_queries_not_using_indexes = ON;  -- 记录未使用索引的查询
SET GLOBAL log_slow_admin_statements = ON;  -- 记录慢管理语句

-- 配置文件设置（my.cnf）
[mysqld]
slow_query_log = ON
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
log_queries_not_using_indexes = ON
log_slow_admin_statements = ON
min_examined_row_limit = 100  -- 至少检查100行

-- 查看慢查询统计
SHOW STATUS LIKE 'Slow_queries';





#主从复制
写操作使用主库
读操作使用从库（负载均衡）

-- 主库配置
[mysqld]
server_id = 1                    # 唯一ID
log_bin = /var/log/mysql/mysql-bin  # 开启Binlog
binlog_format = ROW              # 推荐ROW格式
binlog_do_db = mydb              # 要同步的数据库（可选）
binlog_ignore_db = mysql         # 忽略的数据库（可选）
expire_logs_days = 7             # Binlog保留天数
max_binlog_size = 1G             # Binlog最大大小
gtid_mode = ON
enforce_gtid_consistency = ON

-- 创建复制用户
CREATE USER 'repl_name'@'IP' IDENTIFIED BY 'repl_password';
GRANT REPLICATION SLAVE ON *.* TO 'repl_name'@'IP';
FLUSH PRIVILEGES;
SHOW MASTER STATUS;

-- 从库配置
server_id = 2                    # 唯一ID，不能与主库相同
relay_log = /var/log/mysql/relay-bin  # 中继日志
read_only = ON                   # 从库只读
skip_slave_start = ON            # 不自动启动复制
log_slave_updates = OFF          # 是否记录到自己的Binlog（级联复制时开启）
gtid_mode = ON
enforce_gtid_consistency = ON
slave_parallel_workers = 4       # 并行复制线程数
slave_parallel_type = LOGICAL_CLOCK

---- 复制
STOP SLAVE;
CHANGE MASTER TO
MASTER_HOST = '192.168.1.100',
MASTER_PORT = 3306,
MASTER_USER = 'repl',
MASTER_PASSWORD = 'repl_password',
MASTER_LOG_FILE = 'mysql-bin.000001',  -- 主库 SHOW MASTER STATUS 的 File
MASTER_LOG_POS = 154,                   -- 主库的 Position
MASTER_CONNECT_RETRY = 10;              -- 重连间隔
START SLAVE;
SHOW SLAVE STATUS\G
```