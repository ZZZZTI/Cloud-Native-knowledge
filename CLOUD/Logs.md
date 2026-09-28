> 日志数据（Logs）：离散的文本事件记录，包含详细的上下文。信息最丰富，但量大、成本高，适合排查具体错误。
>
> 工具：ELK / Loki 
>

------

### Promtail.yml

```yaml
# 服务端配置（Promtail 自身的 HTTP 服务，用于健康检查等）
server:
  http_listen_port: 9080   # Promtail 对外暴露的 HTTP 端口
  grpc_listen_port: 0      # gRPC 端口，0 表示随机分配（一般无需改动）

# 记录 Promtail 已读取文件位置的文件，避免重启后重复采集
positions:
  filename: /tmp/positions.yaml

# 要推送日志的 Loki 服务地址
clients:
  - url: http://loki:3100/loki/api/v1/push   # Loki 的 push 接口地址

# 采集配置，可以配置多个 job
scrape_configs:
  # 示例 1：采集本地系统日志文件
  - job_name: system
    static_configs:
      - targets:
          - localhost                 # 目标地址（本地文件采集时一般写 localhost）
        labels:
          job: varlogs                # 自定义标签，用于在 Loki 中查询
          host: my-server             # 主机名标签
          __path__: /var/log/*.log    # 要采集的日志文件路径，支持通配符
  
  # 示例 2：采集 Docker 容器日志（通过 Docker 服务发现）
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock   # Docker socket 地址
        refresh_interval: 5s                # 容器列表刷新间隔
    relabel_configs:
      # 只采集运行中的容器
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'container_name'
      # 用容器名作为 job 标签
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)'
        target_label: 'job'
      # 采集容器日志的实际路径
      - source_labels: ['__meta_docker_container_log_stream']
        target_label: 'stream'
```



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



