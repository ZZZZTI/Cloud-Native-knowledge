```sql
--查询数据语句与函数(重点)





#DQL

-- 查询的总语法
SELECT [DISTINCT]                              <去重   
count(*),                                      <查询目标:函数/列
col1,
col2 别名,
AVG(col) OVER (PARTITION BY col) AS XXX
FROM table_name
[JOIN other_table ON condition]                <多表查询
[WHERE condition]                              <条件(过滤行)
[GROUP BY col[HAVING group_condition]]         <分组(对剩下的行分组)
[ORDER BY col]                                 <排序    
[LIMIT(n,n)];                                  <分页

-- 多表查询[JOIN other_table ON condition]
-- INNER JOIN         (返回两个表中匹配成功的行)(交集)
-- LEFT/RIGHT JOIN    (返回左/右表所有行，右/左表不匹配的字段为NULL)
-- LEFT+INNER JOIN    (并集)
-- 自连接              (两表为同一张表，用别名区分)
-- 多表连接            (XX JOIN...XX JOIN....)
SELECT students.name, classes.name
FROM students(左表)
[INNER]/LEFT/RIGHT JOIN classes(右表) ON students.class_id(左表列)= classes.id(右表列);

-- 聚合函数
COUNT() 计数     COUNT(*), COUNT(DISTINCT col)
SUM()   求和     SUM(amount)
AVG()   平均值    AVG(price)
MAX()   最大值    MAX(score)
MIN()   最小值    MIN(score)

-- 窗口函数(当成一列:排名)
function_type(col) OVER (
[PARTITION BY col]           -- 分区（分组）
[ORDER BY col]               -- 排序
[frame_clause]               -- 窗口帧（定义计算范围）
) AS 'XXX'
--function_type:
函数                  说明                     示例结果（分数：95, 90, 90, 85）
ROW_NUMBER()        连续排名，相同值不同排名   1, 2, 3, 4
RANK()              跳跃排名，相同值相同排名   1, 2, 2, 4
DENSE_RANK()        连续排名，相同值相同排名   1, 2, 2, 3
NTILE(n)            分桶排名，分成n组          1, 1, 2, 2
聚合函数....
LAG(col,n)          获取前N行的值
LEAD(col,n)         获取后N行的值
FIRST_VALUE(col)    获取窗口内第一个值
LAST_VALUE(col)     获取窗口内最后一个值
NTH_VALUE(col,n)    获取窗口内第N个值

-- 条件[WHERE condition]
WHERE中不能用别名，不能用聚合函数
WHERE age > /< /= /!=  18;                       <>:数据大小比较(>all:大于所有，>auy:大于任意)
WHERE name = '张三';                              =:数据匹配
WHERE price BETWEEN 10 AND 100;                  数据范围比较
WHERE name LIKE '张%' OR '张__' OR '%伟';         模糊匹配：%任意字符，_单个字符
WHERE id IN (1,2,3);                             in:满足其中一个(NOT IN)
WHERE email IS [NOT] NULL;                       判断列为空
WHERE EXISTS (SELECT...)                         满足子查询中的一个

-- 分组 [GROUP BY col[HAVING group_condition]]
col为聚合列，放在列首，自动去重,可以有多个
查询目标中不能出现其他col，可以出现函数(col)
HAVING:对于分组后的条件过滤，不能用其他col,可以用函数和别名
例:HAVING SUM(salary) > 20000 AND AVG(salary) > 10000;

-- 排序[ORDER BY col]
-- ORDER BY [CASE col .... END]
ORDER BY col1 ASC, col2 DESC;  
ASC升序（默认），DESC降序
当第一个排序下的数据相同时，按第二个排序排

-- 分页[LIMIT(n,n)]
LIMIT(n)限制查询的对象个数
LIMIT(n,m)从第n行开始查询m个对象

#联合查询
UNION:合并多个SELECT语句的结果
--要求表列数相同、数据类型兼容
SELECT ... FROM tb [..]
UNION(去重)/UNION ALL(不去重)
SELECT ... FROM tb [..];

#子查询
-- SELECT (SELECT...) FROM (SELECT...) WFERE (SELECT...)/((col1,col2)==(SELECT...));

#CTE
WITH cte_name AS (
SELECT column1, column2
FROM table_name
WHERE condition
)
SELECT * FROM cte_name;





#索引（加快查询速度）

-- 索引类型
B-Tree     最常用，支持范围查询  大部分场景（默认）
Hash       精确查询快，不支持范围  Memory引擎
Full-text  全文搜索             文本搜索
R-Tree     地理空间数据           GIS应用

-- 操作索引
CREATE [UNIQUE] INDEX idx_username ON tb_name(col1,col2);   -- 创建索引
DROP INDEX idx_username ON tb_name;                         -- 删除索引
SHOW INDEX FROM tb_name;                                    -- 查询索引

-- 分析查询语句的性能
EXPLAIN SELECT * FROM tb_name WHERE col = 'XXX'\G
-- type: 访问类型（性能从好到差）
system >
const(主键或唯一索引等值查询)>
eq_ref >
ref(非唯一索引等值查询) >
range(范围查询) >
index >
ALL(无索引)
-- possible_keys: 可能使用的索引
-- key: 实际使用的索引
-- key_len: 使用的索引长度
-- rows: 预估扫描行数
-- Extra: 额外信息

-- 索引查询限制
WHERE a = 1 AND b = 2              索引有多个col ，查询时必须有最左列
WHERE a = 1 AND b > 2 AND c = 3    某列使用范围查询后右边的列无法使用索引
WHERE name = 'John' OR age = 20;   OR两边都要有索引

-- 索引失效情况
WHERE name LIKE '%ice'             后缀模糊匹配
WHERE LOWER(name) = 'john';        函数
WHERE age + 1 = 20;                计算
WHERE age != 20;                   否定：!=/IS NULL/NOT IN/NOT EXISTS

-- 应该创建索引的情况
-- 1. WHERE 子句中频繁使用的列
-- 2. JOIN 关联的列
-- 3. ORDER BY 排序的列
-- 4. GROUP BY 分组的列
-- 5. 高选择性的列（唯一性强）
-- 6. 覆盖查询的列（多字段用索引，不用回表查询）







#慢查询

-- 开启慢查询日志
SET GLOBAL slow_query_log = ON;
SET GLOBAL long_query_time = 2;  -- 超过2秒记录
SET GLOBAL log_queries_not_using_indexes = ON;

-- 查看慢查询
SELECT * FROM mysql.slow_log;

#SQL优化

-- 避免隐式类型转换
SELECT * FROM users WHERE phone = 13800138000;
改为
SELECT * FROM users WHERE phone = '13800138000';

-- 避免使用 OR
SELECT * FROM users WHERE age = 18 OR age = 20 OR age = 22;
改为
SELECT * FROM users WHERE age IN (18, 20, 22);

-- 使用 BETWEEN 代替多个条件
SELECT * FROM users WHERE age >= 18 AND age <= 25;
-- 改为
SELECT * FROM users WHERE age BETWEEN 18 AND 25;

-- 使用 EXISTS 代替 IN（子查询结果集大时）
SELECT * FROM users WHERE id IN (SELECT user_id FROM orders);
-- 改为
SELECT * FROM users u
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);

-- 先过滤再JOIN/分组
SELECT status, COUNT(*)
FROM (SELECT * FROM users WHERE create_time > '2024-01-01')
GROUP BY status;

-- 索引列顺序（复合索引）：区分度高的在前，等值查询在前，范围查询在后
CREATE INDEX idx_status_time ON users(create_time, status);
改为
CREATE INDEX idx_time_status ON users(status, create_time);

-- 分页查询
SELECT * FROM users ORDER BY id LIMIT 100000, 20;
改为
SELECT * FROM users WHERE id > 100000 ORDER BY id LIMIT 20;



#高级查询例子

-- 查询所有员工的姓名、性别、年龄（按出生日期计算）、入职年份、薪资，按薪资降序排序
SELECT
name,
gender,
TIMESTAMPDIFF(YEAR, birth_date, NOW()) AS age,
hire_date,
salary
FROM employees
ORDER BY salary DESC;

-- 统计每个部门的员工数量、平均薪资、最高薪资、最低薪资、薪资总额
SELECT
department_name,
count(employee_id),
AVG(salary),
MAX(salary),
MIN(salary),
SUM(salary)
FROM employees
JOIN departments ON employees.department_id=departments.department_id
GROUP BY department_name;

-- 查询2020年之前入职的员工，显示姓名、入职日期、工龄（年），按工龄降序
SELECT
name,
hire_date,
TIMESTAMPDIFF(YEAR, hire_date, NOW())
FROM employees
WHERE YEAR(hire_date) <2020
ORDER BY TIMESTAMPDIFF(YEAR, hire_date, NOW()) DESC;

-- 统计不同薪资区间的员工数量：0-10000, 10001-20000, 20001-30000, 30001以上
SELECT
CASE
WHEN salary <= 10000 THEN '0-10000'
WHEN salary >= 10001 AND salary<=20000 THEN '10001-20000'
WHEN salary >= 20001 AND salary<=30000 THEN '20001-30000'
ELSE '30001以上'
END AS s,
COUNT(employee_id)
FROM employees
GROUP BY s
ORDER BY
CASE s
WHEN '0-10000' THEN 1
WHEN '10001-20000' THEN 2
WHEN '20001-30000' THEN 3
ELSE 4
END;

-- 查询部门预算大于平均预算的部门，显示部门名称、预算、员工数量
SELECT
d.department_name,
d.budget,
COUNT(e.employee_id) AS employee_count
FROM departments d
JOIN employees e ON d.department_id = e.department_id
GROUP BY d.department_id, d.department_name, d.budget
HAVING budget>(SELECT AVG(budget)FROM departments);

-- 使用窗口函数对员工薪资进行排名（部门内排名和全公司排名）
-- 显示姓名、部门、薪资、部门内排名、全公司排名
SELECT
e.name AS 姓名,
d.department_name AS 部门,
e.salary AS 薪资,
RANK() OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) AS 部门内排名,
RANK() OVER (ORDER BY e.salary DESC) AS 全公司排名
FROM employees e
JOIN departments d ON e.department_id = d.department_id
WHERE e.status = 'active'
ORDER BY e.salary DESC;

-- 按入职日期顺序，计算公司的累计薪资总额（Running Total）
-- 显示入职日期、当日入职人数、当日新增薪资、累计薪资总额
WITH daily_hires AS (
SELECT
hire_date,
COUNT(*) AS hire_count,
SUM(salary) AS daily_salary_sum
FROM employees
WHERE status = 'active'
GROUP BY hire_date
)
SELECT
hire_date AS 入职日期,
hire_count AS 当日入职人数,
daily_salary_sum AS 当日新增薪资,
SUM(daily_salary_sum) OVER (ORDER BY hire_date) AS 累计薪资总额
FROM daily_hires
ORDER BY hire_date;
```