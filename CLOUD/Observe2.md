> Loki采集日志数据（Logs）：离散的文本事件记录，包含详细的上下文。信息最丰富，但量大、成本高，适合排查具体错误。
>
> Tempo采集追踪数据（Traces）：记录一个请求在分布式系统中的完整调用链路，展示每个服务的耗时和依赖关系。适合定位性能瓶颈和跨服务问题。
>
> OpenTelemetry（OTel）：提供 SDK和 Collector用于收集Metrics，Logs，Traces数据

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

### Tempo.yml

```yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318

storage:
  trace:
    backend: local
    local:
      path: /var/tempo/traces
    wal:
      path: /var/tempo/wal
```

### OTel 

```Shell
# OTel Collector配置（接收数据 → 处理数据 → 导出到后端）
receivers:   # 数据从哪里来
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:  # 数据怎么处理
  batch:
    send_batch_size: 512
    timeout: 5s
  tail_sampling:          # 尾部采样
    decision_wait: 10s
    policies:
      - name: errors-policy
        type: status_code
        status_code:
          status_codes: [ERROR]     # 所有错误 Trace 都保留
      - name: probabilistic-policy
        type: probabilistic
        probabilistic:
          sampling_percentage: 10   # 其他保留 10%

exporters:   # 数据发到哪里
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, tail_sampling]
      exporters: [otlp/tempo]


# OTLP 协议
OTLP（OpenTelemetry Protocol）是 OTel 的原生传输协议。 你的应用用 OTLP 把数据发给 Collector，Collector 也用 OTLP 发给后端。它支持 gRPC（默认端口 4317）和 HTTP（默认端口 4318）两种传输方式。
应用端配置环境变量：OTEL_EXPORTER_OTLP_ENDPOINT=http://collector:4317
数据就会自动流向 Collector，再被转发到后端。
```

### TracesQL

```Shell
# Waterfall
telemetrygen (root span, 整个请求)
├── OK (子 span)
├── OK (子 span)
└── OK (子 span)

# 基础结构：{ 选择器 } | 管道操作

# 按资源属性筛选
{ resource.service.name = "user-service" }
{ resource.service.name = "api-gateway" }
{ resource.deployment.environment = "prod" }

# 按Span属性筛选（status/duration/name/kind）
{ name = "GET /api/users" }           
{ status = error }                    # 等值
{ duration > 5s }                     # 持续时间（纳秒/ms/s/m/h）
{ span.db.system = "postgresql" }     # Span 属性

# 整条Trace级别
{ trace:duration > 2s }
{ trace:rootService = "api" }

# 逻辑运算符
=  !=  >  >=  <  <=  =~  !~  &&  ||
{ resource.service.name = "api" && duration >= 5s } # 同Span
{ resource.service.name = "frontend" } && { resource.service.name = "backend" }# 同Trace不同Span

# 结构运算符
{ span.name = "GET /" } >> { span.db.system = "postgresql" }   # 祖先 >> 后代
{ span.name = "parent" } > { span.name = "child" }             # 父 > 子
{ span.kind = "client" } ~ { span.kind = "server" }            # 兄弟

# 管道聚合（将查询转为指标）
{ span.db.operation = "SELECT" } | count() > 3
{ resource.service.name = "api" } | avg(duration)
{ span.name = "GET /" } | quantile_over_time(duration, .99) by (span.http.target)
{ status = error } | rate() by (resource.service.name)

# 查询提示：返回最近结果
{ resource.service.name = "api" } with (most_recent=true)
```

### Metrics Generator 数据

```Shell
# 调用次数
traces_span_metrics_calls_total
# 耗时直方图
traces_span_metrics_duration_seconds_bucket	   
# 服务间调用次数
traces_service_graph_request_total	   
# 服务间失败调用次数
traces_service_graph_request_failed_total	     
# 请求率
sum by (service) (rate(traces_span_metrics_calls_total[5m]))
# 错误率
sum by (service) (rate(traces_span_metrics_calls_total{status_code="STATUS_CODE_ERROR"}[5m]))
# P95耗时
histogram_quantile(0.95, sum by (le, service) (rate(traces_span_metrics_duration_seconds_bucket[5m])))
```



### 架构

```Shell
1.客户端埋点（Instrumentation）：应用把OpenTelemetry SDK 作为标准生成 Span 并传递给下游
2.管道（OpenTelemetry Collector）：Collector 接收应用的 OTLP 数据，做批处理、采样、属性修改，转发给 Tempo
3.后端（Tempo）：接收 Span，按 Trace ID 分片，存储为 Parquet 块，最终写入对象存储或本地文件系统。
4.可视化（Grafana）：内置 Tempo 数据源，可以查看 Trace 瀑布图、搜索 Trace、从指标/日志跳转到 Trace。


Trace	          一次完整请求的调用链，由多个 Span 组成，共享同一个 Trace ID
Span	          调用链中的一个操作单元，记录操作名、耗时、父子关系
Trace ID	      全局唯一标识，贯穿整个调用链，用于串联所有 Span
Parent Span ID	标识当前 Span 的调用者，用于重建调用树结构
OTLP	          OpenTelemetry Protocol，Tempo 的原生接收协议
```

