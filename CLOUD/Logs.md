> 日志数据（Logs）：离散的文本事件记录，包含详细的上下文。信息最丰富，但量大、成本高，适合排查具体错误。
>
> 工具：ELK / Loki 
>

------

### LogQL查询

```bash
# 标签过滤
{job="varlogs", filename="/var/log/syslog"}

# 正则匹配
!=	不等于	     {job!="varlogs"}
=~	正则匹配	   {filename=~"/var/log/.*\\.log"}  # 标签选择器不能用 {job=~".*"} 这种全匹配
!~	正则不匹配	  {filename!~".*syslog.*"}

# 行过滤
{job="varlogs"} |= "error"   # 返回所有包含 error 的行
{job="varlogs"} != "debug"   # 排除所有含 debug 的行
{job="varlogs"} |~ "timeout|refused"
{job="varlogs"} !~ "healthcheck|ping"
{job="varlogs"} |= "error" != "timeout" !~ "connection reset"  # 过滤性最强的条件放前面
{job="varlogs"} | json/regexp/logfmt/pattern       # 日志格式过滤

# 指标查询
rate({job="varlogs" |= "error"}[5m])               # 每秒日志行数
sum by (filename) (rate({job="varlogs"}[5m]))      # 按类型分组聚合
count_over_time({job="varlogs"} |= "error" [1h])   # 时间窗口内的总行数  

# 认证失败激增
sum(count_over_time({job="varlogs"} |= "authentication failure" [5m])) > 10
# 服务停止输出日志
sum(count_over_time({job="varlogs"} [10m])) < 1
# 关键错误立即告警
count_over_time({job="varlogs"} |~ "CRITICAL|FATAL" [5m]) > 0
```







### 

```Shell
结构化数据：日志用 JSON 等格式，便于查询和分析
```



