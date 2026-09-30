> SLI / SLO / SLA：服务水平指标、目标、协议，用于衡量系统健康度

------

### 可观测性成本治理

```Shell
17.1 数据采样与保留策略

追踪采样：

开发环境：100% 采样
生产环境：尾部采样，错误全留 + 正常请求 1%~10%
关键业务链路：提高采样率
Collector 的 tail_sampling 配置（第五阶段已提过）：

yaml
processors:
  tail_sampling:
    decision_wait: 10s
    policies:
      - name: errors
        type: status_code
        status_code:
          status_codes: [ERROR]
      - name: slow
        type: latency
        latency:
          threshold_ms: 500
      - name: random
        type: probabilistic
        probabilistic:
          sampling_percentage: 5
日志保留：

Loki 按流（stream）设置保留期
热数据（7 天）放 SSD，冷数据（30 天+）转对象存储
用 compactor 配置保留策略：
yaml
limits_config:
  retention_period: 720h  # 30 天

compactor:
  working_directory: /loki/compactor
  retention_enabled: true
指标保留：

Prometheus 默认保留 15 天。生产环境通常：

本地保留 15 天（快速查询）
通过 remote_write 把数据转发到 Thanos 或 VictoriaMetrics 做长期存储
17.2 高基数问题

高基数是可观测性成本的头号杀手。

基数 = 一个指标/标签组合的唯一值数量。

问题示例：

promql
http_requests_total{user_id="12345", path="/api/order"}
如果 user_id 有 100 万用户，path 有 100 个，这个指标的时序数量就是 1 亿。Prometheus 内存直接爆炸。

解决原则：

不要把用户 ID、请求 ID、Session ID 作为标签
可以把 status_code、method、service 作为标签（基数可控）
需要高基数分析时，用日志或 Trace，而不是指标
排查高基数：

promql
# 查看哪个指标的时间序列最多
topk(10, count by (__name__)({__name__=~".+"}))
17.3 存储优化

Prometheus：用 --storage.tsdb.retention.time 控制本地保留；用 remote_write 转长期存储
Loki：用对象存储（S3/OSS）做后端，本地只存索引
Tempo：天然依赖对象存储，成本最低
压缩：Prometheus 的 TSDB 块默认压缩，Loki 的 chunks 也会压缩
18. 生产实践

18.1 高可用部署

Prometheus 高可用：

部署两个 Prometheus 实例，抓取相同目标（双写）
查询层用 Thanos Query 或 VictoriaMetrics 做统一入口
Alertmanager 用集群模式（gossip 协议）避免单点
Loki 高可用：

微服务模式部署：distributor、ingester、querier 分开
用对象存储做共享后端
Tempo 高可用：

distributor、ingester、querier 分离
对象存储天然高可用
18.2 安全加固

认证与授权：

Grafana：开启登录认证，配置 LDAP/OAuth
Prometheus：用反向代理（Nginx）加 Basic Auth 或 OAuth2
Alertmanager：同上
TLS：

所有组件间通信启用 TLS
OTLP 传输用 TLS（OTEL_EXPORTER_OTLP_CERTIFICATE）
访问控制：

云服务器安全组只开放必要端口
Grafana 不要暴露在公网，用 SSH 隧道或 VPN 访问
敏感标签（如密码）不要写入指标
示例：Nginx 反向代理 Prometheus 加 Basic Auth：

nginx
location /prometheus/ {
    auth_basic "Prometheus";
    auth_basic_user_file /etc/nginx/.htpasswd;
    proxy_pass http://localhost:9090/;
}
18.3 容量规划

Prometheus：

估算：每秒采样数（samples/s）× 保留时间 × 每个样本约 1.5 字节
经验值：10 万 samples/s 约需 4~8 核 CPU、16~32GB 内存、1TB SSD
Loki：

日志量（GB/天）× 保留天数 × 压缩比（约 10:1）
索引单独估算
Tempo：

Trace 量 × 平均 Span 数 × 每个 Span 大小
对象存储成本远低于块存储
监控自身：

Prometheus 自己也要被监控（up、prometheus_tsdb_*）
Grafana 面板响应时间
Collector 的队列长度和丢弃数
```

