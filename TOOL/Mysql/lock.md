```sql
-- 事务，锁，存储引擎




#事务

##事务语句

START TRANSACTION;(开始)(加锁)
sql1;
SAVEPOINT sp1;(设置保存点)
sql2;
SAVEPOINT sp2;
select;(检查)
[发生错误时:ROLLBACK/ROLLBACK TO SAVEPOINT  sp1;]
COMMIT;(提交)
-- RELEASE SAVEPOINT sp1;  -- 删除保存点
-- SET autocommit = 0;     -- 默认开启   -- 0:关闭自动提交, 1:开启自动提交

##隔离级别

-- 查看[全局]隔离级别
SELECT @@[global.]transaction_isolation;

-- 设置隔离级别
SET [GLOBAL] SESSION TRANSACTION ISOLATION LEVEL
READ UNCOMMITTED/READ COMMITTED/REPEATABLE READ/SERIALIZABLE;
^                ^              ^              ^
最强隔离                           默认           性能最好




#存储引擎

-- 查看表的存储引擎
SHOW TABLE STATUS LIKE 'table_name';

-- InnoDB（默认）
特点：支持事务、行锁、外键、崩溃恢复
场景：通用

-- MyISAM
特点：不支持事务、表级锁、全文索引
场景：适合只读或读多写少（频繁查询）

-- Memory
特点：数据存储在内存，速度快，重启后数据丢失
场景：临时表/缓存




#锁

-- 按范围分类
表锁(锁定整张表,MyISAM, InnoDB)    
行锁(锁定单行记录,InnoDB):
-- 记录锁[WHERE id = 1 FOR UPDATE]
-- 间隙锁[WHERE id BETWEEN 5 AND 10 FOR UPDATE]
-- 临键锁[WHERE id > 5 FOR UPDATE]

-- 按模式分类
共享锁（S锁）     读锁，允许其他事务读取        与共享锁兼容，与排他锁冲突
排他锁（X锁）     写锁，不允许其他事务读写   与所有锁冲突
意向共享锁（IS）   表级锁，表示要加共享锁        与排他锁冲突
意向排他锁（IX）   表级锁，表示要加排他锁        与共享/排他锁冲突

--- 意向锁
-- 事务A：给行加锁 → 自动加意向锁
-- 事务B：想加表锁 → 检查意向锁，发现有行锁，等待

-- InnoDB
START TRANSACTION;(开启事务默认写锁:可读写)
SELECT * FROM products WHERE id = 1 FOR SHARE;(只读)
COMMIT;

-- MyISAM(只有表锁)
-- 加锁
LOCK TABIE tb_name READ(只读)/WRITE(可读写);
-- 解锁
UNLOCK TABLES;
```