```sql
-- 函数,存储过程,触发器




#Function

##字符串

CONCAT(str1, str2)          字符串连接  CONCAT('Hello', ' ', 'World')      Hello World
CONCAT_WS(sep, str1, str2)  用分隔符连接 CONCAT_WS('-', '2024', '01', '15') 2024-01-15
LENGTH(str)                 返回字节长度 LENGTH('你好')       6 (UTF-8)
CHAR_LENGTH(str)            返回字符长度 CHAR_LENGTH('你好')  2
UPPER(str)                  转大写        UPPER('hello')     HELLO
LOWER(str)                  转小写        LOWER('HELLO')     hello
SUBSTRING(str, pos, len)    提取子串       SUBSTRING('Hello World', 7, 5) World
LEFT(str, len)              左边截取       LEFT('Hello', 2)   He
RIGHT(str, len)             右边截取       RIGHT('Hello', 2)  lo
TRIM(str)                   去除两端空格 TRIM(' Hi ')       Hi
REPLACE(str, old, new)      替换字符串  REPLACE('Hello', 'l', 'x')     Hexxo
REVERSE(str)                反转字符串  REVERSE('Hello')   olleH
INSTR(str, substr)          查找位置       INSTR('Hello', 'e')    2
LPAD(str, len, pad)         左填充        LPAD('123', 5, '0')    00123
RPAD(str, len, pad)         右填充        RPAD('123', 5, '*')    123**

##数值

ABS(n)          绝对值    ABS(-10)   10
ROUND(n, d)     四舍五入   ROUND(3.14159, 2)  3.14
CEIL(n)         向上取整   CEIL(3.14) 4
FLOOR(n)        向下取整   FLOOR(3.14)    3
RAND()          随机数   0-1  RAND() 0.123456789
MOD(n, m)       取模     MOD(10, 3) 1
POWER(n, m)     幂运算    POWER(2, 3)    8
SQRT(n)         平方根    SQRT(16)   4
TRUNCATE(n, d)  截断小数   TRUNCATE(3.14159, 2)   3.14
FLOOR(n)        向下取整   FLOOR(3.99)    3
SIGN(n)         返回符号   SIGN(-5)   -1

##日期

NOW()           当前日期时间 NOW()  2024-01-15 10:30:00
CURDATE()       当前日期       CURDATE()  2024-01-15
CURTIME()       当前时间       CURTIME()  10:30:00
DATE(date)      提取日期部分 DATE('2024-01-15 10:30:00')    2024-01-15
TIME(datetime)  提取时间部分 TIME('2024-01-15 10:30:00')    10:30:00
YEAR(date)      提取年份       YEAR('2024-01-15') 2024
MONTH(date)     提取月份       MONTH('2024-01-15')    1
DAY(date)       提取日        DAY('2024-01-15')  15
HOUR(time)      提取小时       HOUR('10:30:00')   10
MINUTE(time)    提取分钟       MINUTE('10:30:00') 30
SECOND(time)    提取秒        SECOND('10:30:00') 0
DAYOFWEEK(date) 提取星期       DAYOFWEEK('2024-01-15')    2 (周一)
DATE_ADD(date, INTERVAL)    日期加法   DATE_ADD(NOW(), INTERVAL 1 DAY)    明天
DATE_SUB(date, INTERVAL)    日期减法   DATE_SUB(NOW(), INTERVAL 1 MONTH)  一个月前
DATEDIFF(date1, date2)      相差天数   DATEDIFF('2024-01-15', '2024-01-01')   14
TIMESTAMPDIFF(unit, start, end) 时间差    TIMESTAMPDIFF(YEAR, '2000-01-01', NOW())   24

##流程

-- IF(条件, 真值, 假值)
SELECT
name,
score,
IF(score >= 60, '及格', '不及格') AS result
FROM students;

-- IFNULL(表达式, 默认值)
SELECT
name,
IFNULL(phone, '无电话') AS phone
FROM users;

-- CASE
SELECT
name,
score,
CASE
WHEN score >= 90 THEN 'A'
WHEN score >= 80 THEN 'B'
WHEN score >= 70 THEN 'C'
WHEN score >= 60 THEN 'D'
ELSE 'F'
END AS grade
FROM students;

-- 判断NULL
COALESCE(col/函数,0/'无参数');

##自定义

-- 定义函数
DELIMITER $$                                   -- 1. 更改分隔符
CREATE FUNCTION function_name(parameter_list)  -- 2. 创建函数（函数名和参数类型）
RETURNS data_type                              -- 3. 声明返回类型
[DETERMINISTIC | NOT DETERMINISTIC]            -- 4. 确定性声明（确定：同输入返回同结果，非确定：同输入可能返回不同结果）
BEGIN                                          
-- 函数体(DECLARE 变量 变量类型;声明变量)(用存储过程定义函数)
RETURN value;                                  -- 5. 返回值
END$$                                          
DELIMITER ;                                    -- 6. 恢复分隔符

-- 使用函数
SELECT name, CalculateAge(birth_date) AS age FROM users;

-- 查看函数定义
SHOW CREATE FUNCTION function_name;

-- 查看自定义函数
SHOW FUNCTION STATUS [WHERE Db = 'database_name'];

-- 删除函数
DROP FUNCTION IF EXISTS function_name;







#PROCEDURE

-- 创建存储过程
DELIMITER $$
CREATE PROCEDURE procedure_name
[IN | OUT | INOUT] parameter_name data_type      -- IN:传入参数 OUT:返回值 INOUT:可传入和返回          
(COMMENT 'description')
(DETERMINISTIC | NOT DETERMINISTIC)
(LANGUAGE DEV_mySQL)
(DEV_mySQL SECURITY {DEFINER | INVOKER})
BEGIN
DECLARE variable_name data_type [DEFAULT value];             -- 声明局部变量
DECLARE EXIT/CONTINUE HANDLER FOR [状态码]
BEGIN
[ROLLBACK;(EXIT:退出处理器,发生错误时回滚并退出)]
DEV_mySQL;
END;                                                         -- 声明条件处理器
-- 存储过程体
-- DEV_mySQL statements
END$$
DELIMITER ;

-- 调用存储过程
SET [GLOBAL]inout1=10;(INOUT参数类型可设置传入值)
CALL procedure_name(1/@out1/@inout1);
SELECT @out1/@inout1;(查看返回值)

-- 游标(遍历)
DECLARE cursor_name CURSOR FOR
SELECT id, name, age FROM users;声明游标
OPEN cursor_name;打开游标
read_loop: LOOP
FETCH cursor_name INTO v_id, v_name, v_age;(循环遍历)
IF done THEN
LEAVE read_loop;
END IF;
SELECT CONCAT('ID:', v_id, ', Name:', v_name, ', Age:', v_age);-- 处理每一行数据
END LOOP;
CLOSE user_cursor;关闭游标

-- 查询所有存储过程
SHOW PROCEDURE STATUS [WHERE Db = 'database_name'];

-- 查看存储过程定义
SHOW CREATE PROCEDURE procedure_name;

-- 存储过程体

-- IF
IF      condition THEN [...;]
ELSE IF condition THEN [...;]
...
ELSE [...;]
END IF;

-- CASE
CASE
WHEN condition THEN [...;]
WHEN condition THEN [...;]
WHEN condition THEN [...;]
ELSE [...;]
END CASE;

-- LOOP
loop_name: LOOP
IF i > n THEN
LEAVE loop_name;  -- 退出循环的条件
END IF;
SET sum_val = sum_val + i;
SET i = i + 1;
END LOOP;

-- WHILE
WHILE i <= n DO
SET sum_val = sum_val + i;
SET i = i + 1;
END WHILE;

-- REPEAT
REPEAT
SET sum_val = sum_val + i;
SET i = i + 1;
UNTIL i > n
END REPEAT;





#TRIGGER

-- 创建触发器(不用调用)
DELIMITER $$
CREATE TRIGGER tr_name
{BEFORE | AFTER}                --操作前/后触发（数据验证、修改数据/日志记录、同步数据）
{INSERT | UPDATE | DELETE}      --触发事件
ON table_name
FOR EACH ROW
BEGIN
-- 触发器逻辑
IF [OLD.col != NEW.col] THEN [...;]    -- OLD和NEW关键字使用
END$$
DELIMITER ;

-- 触发器限制
不能使用事务语句（COMMIT, ROLLBACK）
不能返回结果集
不能调用存储过程（有结果集）
不能对自身表进行修改（避免循环）

-- 查询触发器
SHOW TRIGGERS [WHERE `Table` = 'tb_name'];

-- 查询触发器定义
SHOW CREATE TRIGGER tr_name;
```