> 追踪数据（Traces）：记录一个请求在分布式系统中的完整调用链路，展示每个服务的耗时和依赖关系。适合定位性能瓶颈和跨服务问题。
>
> 工具：Jaeger / Tempo
>
> OpenTelemetry（OTel）：提供 SDK和 Collector用于收集Metrics，Logs，Traces数据

------

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



### TracesQL

```Shell

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

