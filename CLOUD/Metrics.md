>  指标数据（Metrics）：随时间聚合的数值，如 QPS、延迟、错误率、CPU 使用率。适合告警和趋势分析，细节有限
>
>  工具：Prometheus-> Grafana面板 -> Alertmanager告警/webhook中间件告警

------

### docker-compose.yml

```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/rules:/etc/prometheus/rules
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

  node-exporter:
    image: quay.io/prometheus/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    network_mode: host
    pid: host
    volumes:
      - /:/host:ro,rslave
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
    command:
      - '--path.rootfs=/host'
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'

  grafana:
    image: grafana/grafana-enterprise:latest
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    volumes:
      - grafana-storage:/var/lib/grafana

volumes:
  prometheus-data:
  grafana-storage:
    external: true
```

### prometheus.yml

```yaml
global:
  scrape_interval: 15s

alerting:          # 告警规则文件
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

rule_files:        # 告警规则文件
  - /etc/prometheus/rules/*.yml

scrape_configs:     # 抓取配置
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
```

### 指标数据

```Shell
# 指标类型
Counter  	只增不减的计数器，用于累计值
Gauge	    可增可减的瞬时值

# ============ 主机类 (node_exporter) ============
node_cpu_seconds_total                                  # CPU 各模式累计时间（Counter，单位秒）
node_memory_MemTotal_bytes                              # 物理内存总量（Gauge，单位字节）
node_memory_MemAvailable_bytes                          # 可用内存（Gauge，单位字节）
node_filesystem_avail_bytes                             # 文件系统可用空间（Gauge，单位字节）
node_filesystem_size_bytes                              # 文件系统总空间（Gauge，单位字节）
node_disk_read_bytes_total                              # 磁盘读取字节数（Counter，单位字节）
node_disk_written_bytes_total                           # 磁盘写入字节数（Counter，单位字节）
node_network_receive_bytes_total                        # 网卡接收字节数（Counter，单位字节）
node_network_transmit_bytes_total                       # 网卡发送字节数（Counter，单位字节）
node_load1/5/15                                         # 1/5/15 分钟平均负载（Gauge）
# ============ 容器类 (cAdvisor / kubelet) ============
container_cpu_usage_seconds_total                       # 容器 CPU 累计使用时间（Counter，单位秒）
container_memory_usage_bytes                            # 容器内存使用量（Gauge，单位字节）
container_memory_working_set_bytes                      # 容器内存工作集（Gauge，单位字节）
container_fs_usage_bytes                                # 容器文件系统使用量（Gauge，单位字节）
container_network_receive_bytes_total                   # 容器网络接收字节数（Counter，单位字节）
container_network_transmit_bytes_total                  # 容器网络发送字节数（Counter，单位字节）
# ============ Kubernetes 类 (kube-state-metrics) ============
kube_pod_status_phase                                   # Pod 所处阶段（Gauge，1/0，标签 phase）
kube_pod_status_ready                                   # Pod 是否 Ready（Gauge，1/0）
kube_pod_container_status_restarts_total                # 容器重启次数（Counter）
kube_pod_container_resource_requests                    # 容器资源 requests（Gauge，标签 resource/unit）
kube_pod_container_resource_limits                      # 容器资源 limits（Gauge，标签 resource/unit）
kube_deployment_status_replicas                         # Deployment 期望副本数（Gauge）
kube_deployment_status_replicas_available               # Deployment 可用副本数（Gauge）
kube_node_status_condition                              # 节点状态条件（Gauge，1/0，标签 condition/status）
kube_node_status_allocatable                            # 节点可分配资源（Gauge，标签 resource/unit）
kube_node_status_capacity                               # 节点总容量资源（Gauge，标签 resource/unit）
# ============ HTTP / 应用类 ============
http_requests_total                                     # HTTP 请求总数（Counter，标签 method/status/path）
http_request_duration_seconds_bucket                    # 请求耗时直方图分桶（Histogram，标签 le）
http_request_duration_seconds_sum                       # 请求耗时总和（Histogram，单位秒）
http_request_duration_seconds_count                     # 请求总数（Histogram，单位次）
http_requests_in_flight                                 # 当前处理中请求数（Gauge）
process_cpu_seconds_total                               # 进程 CPU 累计时间（Counter，单位秒）
process_resident_memory_bytes                           # 进程常驻内存（Gauge，单位字节）
go_goroutines                                           # Go 协程数（Gauge）
go_memstats_alloc_bytes                                 # Go 已分配内存（Gauge，单位字节）
# ============ MySQL 类 (mysqld_exporter) ============
mysql_global_status_threads_connected                   # 当前连接数（Gauge）
mysql_global_status_threads_running                     # 当前运行线程数（Gauge）
mysql_global_status_slow_queries                        # 慢查询总数（Counter）
mysql_global_variables_max_connections                  # 最大连接数（Gauge）
mysql_global_status_uptime                              # MySQL 运行时长（Gauge，单位秒）
# ============ Redis 类 (redis_exporter) ============
redis_up                                               # Redis 是否存活（Gauge，1/0）
redis_connected_clients                                # 当前客户端连接数（Gauge）
redis_memory_used_bytes                                # 已用内存（Gauge，单位字节）
redis_memory_max_bytes                                 # 最大内存限制（Gauge，单位字节）
redis_keyspace_hits_total                              # 命中次数（Counter）
redis_keyspace_misses_total                            # 未命中次数（Counter）
# ============ Nginx 类 (nginx-prometheus-exporter) ============
nginx_connections_active                               # 活跃连接数（Gauge）
nginx_http_requests_total                              # HTTP 请求总数（Counter）
nginx_up                                               # Nginx 是否存活（Gauge，1/0）
# ============ Prometheus 自身 ============
up                                                     # 采集目标是否存活（Gauge，1/0）
scrape_duration_seconds                                # 单次采集耗时（Gauge，单位秒）
scrape_samples_scraped                                 # 单次采集样本数（Gauge）
prometheus_tsdb_head_series                            # 当前 head 中 series 数（Gauge）
prometheus_target_scrape_pool_targets                  # 采集目标数（Gauge）
```

### PromQL查询

```bash
# 过滤
node_cpu_seconds_total{mode="idle", cpu="0"}     # 按标签过滤
node_cpu_seconds_total{mode=~"idle|user|system"}
node_cpu_seconds_total{mode！~"idle|user|system"}
node_load1[5m/1h/1d]          # 按时间过滤：最近 5分钟/1小时/1天
node_load1 offset 1h          #           1小时前的值

# 计算后输出
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100
node_load1 > 5
node_filesystem_avail_bytes < 1073741824

# 聚合运算
sum(node_cpu_seconds_total) by (mode)
avg(node_load1) by (instance)
max(node_memory_usage_bytes) without (cpu)
min / count / stddev / stdvar
topk(5, node_load1)
bottomk(3, node_load1)

# 函数计算
rate(http_requests_total[5m])              # Counter 每秒增长率
irate(http_requests_total[5m])             # 瞬时速率
increase(http_requests_total[1h])          # 1 小时增量
delta(node_load1[1h])                      # Gauge 变化量
idelta(node_load1[5m])
changes(node_load1[1h])                    # 变化次数
deriv(node_load1[5m])                      # 导数
predict_linear(node_filesystem_avail_bytes[1h], 4*3600)   # 预测 4h 后 
time()                                     # 时间
timestamp(node_load1)
hour() / day_of_week() / month()
sort(node_load1)                           # 排序
sort_desc(node_load1)
```

### 架构

```Shell
# 添加新 Exporter
起容器：写进 docker-compose.yml，docker compose up -d
配抓取：在 prometheus.yml 加 job_name，指向 Exporter 地址
重启验证：docker compose restart prometheus，Targets 页面确认 UP

┌──────────────────────────────────────────────────── ─┐
│           云服务器 (docker host 网络)                  |
│                                                      |
│       主机               容器              http       │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  │
│  │ Node Exporter│  │   cAdvisor   │  │  Blackbox  │  │
│  │   :9100      │  │    :8080     │  │   :9115    │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬─────┘  │
│         │                 │                 │        │
│         └─────────────────┼─────────────────┘        │
│                           │                          │
│                    ┌──────▼───────┐                  │
│                    │  Prometheus  │抓取+存储+查询      │
│                    │    :9090     │                  │
│                    └──────┬───────┘                  │
│                           │                          │
│                    ┌──────▼───────┐                  │
│                    │ Alertmanager │告警通知           │
│                    │    :9093     │                  │
│                    └──────────────┘                  │
│                                                      │
│                    ┌──────────────┐                  │
│                    │   Grafana    │ 可视化            │
│                    │    :3000     │                  │
│                    └──────────────┘                  │
└──────────────────────────────────────────────────── ─┘
术语	     含义
拉模型   	Prometheus 主动去 Target 抓取指标，而非等应用推送
Target	  被监控的对象，比如一台服务器、一个应用
Job	      一组同类 Target 的集合，比如所有 Web 服务器
Exporter	一个把系统/应用指标暴露成 HTTP 接口的程序
Metrics	  指标数据，格式如 node_cpu_seconds_total{mode="idle"} 12345
Scrape	  Prometheus 主动去抓取一次数据的行为
Instance	一个具体的抓取目标地址
```

