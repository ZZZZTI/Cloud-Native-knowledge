```shell
-- redis


# 数据结构

    一般
-- 查找键
KEYS *[模糊匹配]
-- 查看键的过期时间
TTL key
-- 删除所有键
FLUSHALL
-- 事务
MULTI---xxx,xxx---EXEC   

    String(字符串)
-- 设置键的值(设置键的过期时间)
SET key value [EX seconds]
-- 批量设置
MSET k1 v1 k2 v2
-- 获取/删除/判断是否存在 键
GET/DEL/EXISTS key
-- 批量获取
MGET k1 k2 k3
-- 字符串长度
STRLEN key

    List(栈/队列)
-- 在键中往左右推入值
LPUSH/RPUSH key v1 v2 v3
-- 获取键中指定下标/范围的元素
LRANGE key index/(start stop)      --(0,-1)为所有
-- 删除从左/右开始的i个元素
LPOP/RPOP key i
-- 保留指定范围的元素，其他删除
LTRIM key start stop
--列表长度
LLEN key

    Set(元素不能重复的集合)
-- 添加元素
SADD key m1 m2 m3
-- 删除/判断是否存在 元素
SREM key m1
-- 元素个数
SCARD key
-- 获取所有元素
SMEMBERS key
-- 随机弹出元素i个
SPOP key i

    Sorted Set(有序双列集合)
-- 添加元素(score/member)
ZADD key (s1 m1) (s2 m2) (s3 m3)
-- 升序获取范围的m (s)
ZRANGE key start stop [WITHSCORES]
-- 获取成员分数
ZSCORE key member
-- 获取成员升/降序排名
ZRANK/ZREVRANK key member

    Hash(键值对)
-- 设置键中的多个字段的名和值
HSET key (f1 v) (f2 v)
-- 获取键中多个字段的值
HMGET key f1 f2
-- 删除/判断是否存在 字段
HDEL/HEXISTS key f1
-- 字段数量
HLEN key
--获取所有字段名或值
HKEYS / HVALS

    Stream(小型消息队列)
-- 订阅消息
subscribe channel
-- 发布消息(id)
XADD key (xx-xx)/* channel message
-- 消息数量
XLEN key
-- 获取消息
XRANGE key - +
XREAD [COUNT n] [BLOCK ms] STREAMS key id/$    --(消息数量)(阻塞时间)(开始读取的id)
-- 创建消费者组
XGROUP CREATE key groupname id/$
-- 在组里添加消费者
XCRATECONSUMER key groupname c1 c2 c3

    Geospatial(地理空间)
-- 添加地点
GEOADD key longitude latitude member
-- 获取经纬度
GEOPOS key member
-- 计算地点间距离
GEODIST key member1 member2 [km/m]
-- 查询半径内的另一个地点
GEOSEARCH key m1 BYRADIUS 300 km

    HyperLogLog(基数统计)
-- 添加元素
PFADD key e1 e2 e3
-- 返回近似基数
PFCOUNT key
-- 合并多个 HyperLogLog
PFMERGE destkey key1 key2   

    Bitmap(位图)
-- 设置位数的值
SETBIT key offset(0/1/2/3...) value(0/1)
-- 获取值
GETBIT key offset
-- 统计值为1的数量
BITCOUNT key [start end]




# 八股文
redis是什么?
Redis架构是怎么样的？
怎么设计redis？
RDB是什么，AOF是什么？
RDB和AOF的区别是什么？
Redis有什么作用？
Redis为什么要单线程？
DEV_Redis redis的持久化机制是怎么样的？
Redis支持String，List，Set，Zset
Redis支持哪些数据类型？
Redis是单线程吗？
Redis缓存过期策略
Redis缓存淘汰策略
缓存过期策略和缓存淘汰策略的区别是什么？
LRU是什么？
DEV_Redis-cli是什么？
Redis通信协议是怎么样的？
Redis的协议格式是怎么样的？
为什么Redis不用HTTP？
RedisJson是什么？
RediSearch是什么？
RediTImeSeries是什么？
RedisGraph是什么？
Redis的高可用，高性能怎么做？
Redis是什么？
主从模式是什么？
主从模式的具体实现细节？
主从同步中有数据写入怎么办？
经典主从模式有什么问题？
哨兵是什么？
哨兵模式是什么？
哨兵集群是什么？
Redis怎么提升高可用？
什么是主观下线和客观下线
Redis内存不足的解决方案
Redis集群模式架构解析
Redis数据切分方法详解
Redis哈希槽工作原理
Redis集群高可扩展性实现
Redis单机崩溃服务不可用问题
Redis集群节点扩容步骤
Redis哈希槽迁移过程
Redis读写重定向机制
DEV_Redis CLUSTER SLOTS命令详解
Redis数据迁移期间访问策略
Redis集群主从故障切换流程
Redis集群客户端连接实践
Redis集群与主从复制区别
Redis避免全量数据迁移方法
Redis扩容后数据分布逻辑
Redis哈希槽16384个原因
Redis高可用高扩展实现
Redis突破单机内存限制方案
Redis集群模式数据分片原理
Redis键值分片计算公式
Redis节点增减数据迁移风险
Redis哈希槽固定长度优势
Redis集群节点间通信机制
Redis重定向错误处理方法
Redis集群客户端库推荐
Redis迁移状态判断技巧
Redis集群主节点选举过程
Redis集群读写请求流程示例
Redis集群三主节点配置案例
Redis哈希槽范围分配规则
Redis集群扩容数据迁移量
Redis客户端slot缓存机制
Redis集群节点宕机处理
Redis集群数据持久化策略
Redis集群性能优化技巧
Redis集群监控关键指标
Redis集群常见问题排查
Redis集群槽位重新分配
Redis集群数据一致性保障
Redis集群慢查询优化
Redis集群大Key处理方案
Redis集群热Key解决方案
Redis集群管道技术使用
Redis集群事务支持情况
Redis集群Lua脚本限制
Redis集群如何分片数据
Redis集群节点职责划分
Redis集群数据重定向原理
Redis集群为什么需要16384个槽
Redis集群扩容时数据迁移量
Redis集群客户端如何感知节点变化
Redis集群主节点故障处理流程
Redis集群从节点如何提升为主节点
Redis集群如何保证高可用性
Redis集群数据分布策略详解
Redis键值对如何映射到哈希槽
Redis集群跨槽操作支持情况
Redis数据切分是什么
Redis重定向机制是什么
DEV_Redis CLUSTER SLOTS命令是什么
Redis集群节点扩容是什么
Redis哈希槽迁移是什么
Redis主从故障切换是什么
Redis集群高可扩展性是什么
Redis集群高可用性是什么
Redis键值分片计算是什么
Redis集群节点通信是什么
Redis集群跨槽操作是什么
Redis槽位重新分配是什么
Redis客户端Slot缓存是什么
```