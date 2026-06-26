```sql
--基础SQL语句(创建库表和用户，填充修改数据)




#DDL(结构)

##库

-- 查询所有数据库
SHOW DATABASES;

-- 查询当前数据库
SELECT DATABASE(database_name);

-- 创建数据库
CREATE DATABASE IF NOT EXISTS database_name
CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;指定字符集以及排序(防止输入中文或表情导致乱码)

-- 删除数据库
DROP DATABASE IF EXISTS database_name;

-- 修改数据库字符集（MySQL）
ALTER DATABASE database_name CHARACTER SET utf8mb4;

-- 切换/使用数据库
USE database_name;

##表

-- 查询库中所有表
SHOW TABLES;

-- 查询表结构
DESC table_name;

-- 查询建表语句
SHOW CREATE TABLE table_name;

-- 建表
CREATE TABLE table_name (
column1 datatype constraint comment'注释' [约束],
column2 datatype constraint comment'注释' [约束],
name varchar(10) not null   comment'姓名' [约束],
...
[表级约束] (CONSTRAINT 约束名)
[INDEX idx_name (col)]
)ENGINE = XXX comment'注释';

-- 重命名表
ALTER TABLE old_name RENAME TO new_name;

-- 删除表
DROP TABLE IF EXISTS table_name;

-- 创建备份表
CREATE TABLE tb_name_backup LIKE tb_name;

-- 移动表
RENAME TABLE old_db.table_name TO new_db.table_name;

-- 约束
主键约束    PRIMARY KEY         唯一标识每行记录
外键约束    FOREIGN KEY         表之间建立关联(表级约束)(在从表中写)    CONSTRAINT 外键名 FOREIGN KEY (col) REFERENCES 主表名(col)
唯一约束    UNIQUE          确保列值唯一
非空约束    NOT NULL        确保列不为空
检查约束    CHECK(condition) 限制列值范围
默认约束    DEFAULT 'value'  提供默认值

-- 查看表的所有约束
SHOW CREATE TABLE table_name;

##列

-- 添加列
ALTER TABLE table_name ADD column_name datatype constraint;

-- 删除列
ALTER TABLE table_name DROP column_name;

-- 修改列数据类型
ALTER TABLE table_name MODIFY COLUMN column_name new_datatype;

-- 重命名列
ALTER TABLE table_name RENAME COLUMN old_name TO new_name;

-- 增删约束
ALTER TABLE table_name ADD/DROP [约束](col);

-- 数据类型
--整数         TINYINT      INT       BIGINT
--浮点数        FLOAT       DOUBLE
--布尔         TINYINT(1)
--定长字符串    CHAR(n)     固定长度，不足补空格
--变长字符串    VARCHAR(n)  TEXT
--日期时间      DATE          'YYYY-MM-DD'
TIME      'HH:MM:SS'
DATETIME      'YYYY-MM-DD HH:MM:SS'
--集合         JSON        '["XX","XX"]'    '{"age": 25,"city": "上海"}'

##视图

-- 创建或修改视图
CREATE OR REPLACE VIEW view_name AS
SELECT col1,col2
FROM tb_name
(WHERE condition)
(JOIN other_table ON condition)
[WITH LOCAL/CASCADED CHECK OPTION];防止通过视图插入或更新不符合视图WHERE条件的数据
LOCAL:检查当前视图
CASCADED:检查所有关联视图

-- 删除视图
DROP VIEW IF EXISTS view_name;

-- 查看所有视图
SHOW FULL TABLES WHERE table_type = 'VIEW';

-- 查看视图定义
SHOW CREATE VIEW view_name;

-- 查看视图结构
DESC view_name;

-- 单表视图：可以执行更新操作
UPDATE updatable_view SET score = 90 WHERE id = 1;
INSERT INTO updatable_view (name, age, score) VALUES ('小明', 18, 85);
DELETE FROM updatable_view WHERE id = 5;
-- 只读视图：包含聚合，连接，分组，DISTINCT，常量列，连查





#DML(数据)

-- 完整插入数据
INSERT INTO table_name VALUES (value1, value2, DEFAULT),(value1, value2, value3);

-- 指定列插入数据
INSERT INTO table_name (col1, col2, col3)
VALUES (value1, value2, value3),
(value1, value2, value3),
(value1, value2, value3);

-- 批量插入数据
LOAD DATA INFILE '文件路径'
INTO TABLE tb_name
FIELDS TERMINATED BY ','     -- 分割
LINES TERMINATED BY '\n';

-- 修改数据
UPDATE table_name
SET col1 = value1, col2 = value2
WHERE condition;
-- 没写条件会修改全部

-- 删除数据
DELETE FROM table_name WHERE condition;

-- 还原空表
TRUNCATE TABLE table_name;





#DCL(用户)

-- 创建用户
CREATE USER 'username'@'host' IDENTIFIED BY 'password';
host:localhost:本地主机  %:任何主机

-- 删除用户
DROP USER 'username'@'host';

-- 修改密码
ALTER USER 'username'@'host' IDENTIFIED BY 'new_password';

-- 查看所有用户
SELECT user, host, authentication_string FROM mysql.user;

-- 查看用户权限
SHOW GRANTS FOR 'username'@'host';

-- 授予用户权限
GRANT privilege_type [(column_list)]      <权限(如:ALL PRIVILEGES)
ON [object_type] object_name              <位置(如:*.*)(db1.tb_users)
TO 'username'@'host';                     <用户

-- 撤销用户权限
REVOKE privilege_type [(column_list)]
ON [object_type] object_name
FROM 'username'@'host';

-- 创建角色(权限的集合)
CREATE ROLE 'role_name1','role_name2';创建角色
GRANT SELECT ON mydb.* TO 'app_readonly';授予权限给角色
GRANT 'role_name' TO 'john'@'localhost';将角色授予用户
SET DEFAULT ROLE 'app_readonly' TO 'john'@'localhost';激活角色
SELECT * FROM mysql.roles_mapping;查看所有角色
DROP ROLE 'app_readonly';删除角色

-- 权限
ALL         所有权限
ALTER       修改表结构
CREATE      创建数据库/表
DROP        删除数据库/表
SELECT      查询数据
INSERT      插入数据
UPDATE      更新数据
DELETE      删除数据
INDEX       创建/删除索引
EXECUTE     执行存储过程
CREATE VIEW 创建视图
SHOW VIEW   查看视图定义
TRIGGER     创建/删除触发器
REFERENCES  外键约束
CREATE USER 创建/删除/修改用户
PROCESS     查看所有进程
RELOAD      重新加载系统表
REPLICATION SLAVE   复制从服务器
REPLICATION CLIENT  复制客户端
SHOW DATABASES      查看所有数据库
LOCK TABLES         锁定表
CREATE TEMPORARY TABLES 创建临时表
CREATE ROUTINE          创建存储过程/函数
ALTER ROUTINE           修改/删除存储过程 
```