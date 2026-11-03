# Welcome to ZTI's CloudNative knowledge repository

> I'm still learning......
>

### Knowledge structure

```css
.
├── K8S
│   ├── 架构
│   │   ├── pod.md
│   │   ├── 存储.md
│   │   ├── 安全.md
│   │   ├── 网络.md
│   │   ├── 调度.md
│   │   ├── 包管理.md
│   │   └── 控制器.md
│   ├── ArgoCD.md
│   ├── CKAS.md
│   ├── docker.md
│   └── 排障.md
├── LINUX
│   ├── RHEL.md
│   ├── SHELL.md
│   ├── 内核.md
│   ├── 安全.md
│   ├── 文件.md
│   ├── 文本.md
│   ├── 目录.md
│   ├── 管理.md
│   ├── 网络.md
│   └── 资源.md
├── PYTHON
│   ├── 01-环境与运行.md
│   ├── 02-语言基础.md
│   ├── 03-字符串与正则.md
│   ├── 04-控制流.md
│   ├── 05-数据结构.md
│   ├── 06-函数.md
│   ├── 07-模块与包.md
│   ├── 08-文件与数据格式.md
│   ├── 09-异常与调试.md
│   ├── 10-面向对象.md
│   ├── 11-标准库运维常用.md
│   ├── 12-并发编程.md
│   ├── 13-网络与HTTP.md
│   ├── 14-gRPC与云原生.md
│   └── 15-可观测性与工程化.md
├── SEC
│   ├── network
│   │   └── network.md
│   └── safety
│       └── safety.md
├── SRE
│   ├── CICD
│   │   ├── Ansible.md
│   │   ├── Jenkins.md
│   │   ├── Terraform.md
│   │   ├── gh.md
│   │   └── git.md
│   └── SRE
│       ├── Observe1.md
│       ├── Observe2.md
│       ├── SRE.md
│       └── cloud.md
├── TOOL
│   ├── Mysql
│   │   ├── basis.md
│   │   ├── func.md
│   │   ├── jdbc.md
│   │   ├── lock.md
│   │   ├── sql.md
│   │   └── tools.md
│   ├── nginx.md
│   ├── redis.md
│   ├── 文件.md
│   └── 组件.md
└── README.md
```

### Technical architecture

```mermaid
flowchart TB
    %% 样式定义
    classDef dev fill:#e1f5fe,stroke:#0288d1,stroke-width:2px,color:#01579b;
    classDef sec fill:#ffebee,stroke:#d32f2f,stroke-width:2px,color:#b71c1c;
    classDef net fill:#f3e5f5,stroke:#8e24aa,stroke-width:2px,color:#4a148c;
    classDef ctrl fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px,color:#1a237e;
    classDef k8s fill:#e0f2f1,stroke:#00897b,stroke-width:2px,color:#004d40;
    classDef data fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#e65100;
    classDef obs fill:#fffde7,stroke:#fbc02d,stroke-width:2px,color:#f57f17;
    classDef ext fill:#f5f5f5,stroke:#9e9e9e,stroke-width:2px,color:#424242;
    classDef alert fill:#ffebee,stroke:#e53935,stroke-width:2px,color:#b71c1c,stroke-dasharray: 5 5;

    %% ================= 开发与运维端 =================
    subgraph DevZone [Mac 运维/开发端]
        direction LR
        Terminal[Terminal<br/>Ansible / tccli / Docker / kubectl]:::dev
        VSCode[VSCode<br/>Python / API调用 / 编写代码]:::dev
        Browser[浏览器<br/>HTTPS 访问]:::dev
 
    end

    %% ================= 安全防线 =================
    subgraph SecZone [安全接入层]
        VPN[VPN / 内网穿透]:::sec
        Bastion[堡垒机 JumpServer<br/>SSH 审计]:::sec
    end
    
    Terminal -->|安全隧道| VPN
    VPN --> Bastion

    %% ================= 外部服务 =================
    subgraph ExtZone [外部生态 / 内部平台]
        GitHub[GitHub]:::ext
        DSH[内部 Dashboard / 工具]:::ext
        AlertMsg[钉钉/飞书/邮件告警]:::alert
    end

    Browser -->|拉取代码/开源| GitHub
    Browser -->|访问平台| DSH

    %% ================= 腾讯云 VPC =================
    subgraph TencentCloud [腾讯云 VPC 生产环境]
        direction TB
        
        %% 网络入口
        subgraph Network [网络与流量入口]
            CLB[腾讯云 CLB 负载均衡]:::net
            Nginx[Nginx Ingress Controller]:::net
            CLB --> Nginx
        end
        
        Browser -->|业务访问| CLB

        %% 管控与 CI/CD 区域
        subgraph ControlPlane [管控与 CI/CD 流水线]
            direction LR
            GitLab[GitLab CE<br/>代码托管]:::ctrl
            Jenkins[Jenkins<br/>CI 流水线]:::ctrl
            Harbor[Harbor<br/>私有镜像仓库]:::ctrl
            Terraform[Terraform<br/>基础设施编排]:::ctrl
            
            GitLab -->|Webhook 触发| Jenkins
            Jenkins -->|Push 镜像| Harbor
        end

        VSCode -->|Git Push| GitLab
        Bastion -->|运维管理| ControlPlane

        %% K8s 生产集群
        subgraph K8sCluster [K8s 生产集群]
            direction TB
            K8sMaster[K8s Master 高可用]:::k8s
            K8sWorker[K8s Worker 节点]:::k8s
            
            subgraph Pods [业务容器 Pods]
                Backend[后端业务服务]:::k8s
                Promtail[Promtail<br/>日志采集]:::obs
                OTel[OTel Collector<br/>链路采集]:::obs
            end
            
            K8sMaster --> K8sWorker
            K8sWorker --> Pods
        end

        Jenkins -->|CD 部署 kubectl apply| K8sCluster
        Harbor -.->|Pull Image| Pods
        Nginx -->|路由转发| Backend

        %% 数据层 (独立高可用)
        subgraph DataLayer [数据与中间件层]
            MySQL[(MySQL 主从集群)]:::data
            Redis[(Redis 哨兵/集群)]:::data
            MQ[(Kafka / 消息队列)]:::data
        end

        Backend -->|读写| MySQL
        Backend -->|缓存| Redis
        Backend -->|消息| MQ

        %% 可观测性平台
        subgraph Observability [可观测性平台]
            Prometheus[Prometheus<br/>指标监控]:::obs
            Alertmanager[Alertmanager<br/>告警路由]:::obs
            Loki[Loki<br/>日志聚合]:::obs
            Tempo[Tempo<br/>链路追踪]:::obs
            Grafana[Grafana<br/>可视化面板]:::obs
            
            Prometheus -->|触发告警| Alertmanager
            Alertmanager -->|发送通知| AlertMsg
            
            Grafana -->|查询| Prometheus
            Grafana -->|查询| Loki
            Grafana -->|查询| Tempo
        end
        
        %% 数据流向监控平台
        Prometheus -.->|拉取指标| K8sCluster
        Promtail -.->|推送日志| Loki
        OTel -.->|推送链路| Tempo
        
        Browser -->|HTTPS 查看报表| Grafana
    end
```

### My projects:

基于 IaC 与 GitOps 的多环境交付流水线建设（自动化、工具链整合）：

https://github.com/ZZZZTI/Cloud-Native-knowledge.git

核心链路 SLO 保障与全链路可观测性治理（稳定性、监控、应急响应）：

https://github.com/ZZZZTI/Cloud-Native-knowledge.git







