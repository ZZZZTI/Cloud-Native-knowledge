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
│   ├── Untitled.md
│   └── gRPC.md
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

```text
┌──────────────────────────────────────────────────────────────────────────┐
│ ① 交付链路  代码 → 构建 → 镜像 → 交付 → 运行时 → 可观测 → 决策           │
│              git    Jenkins  Docker  ArgoCD   K8s    Prom/SLO            │
├──────────────────────────────────────────────────────────────────────────┤
│ ② 知识分层                                                               │
│    L5 可观测与稳定性  SRE/SRE (4)                                        │
│       Prometheus · Loki · Tempo · SLI/SLO · Alertmanager                 │
│    L4 交付与自动化    SRE/CICD (6) + ArgoCD (1)                          │
│       git · gh · Jenkins · Terraform · Ansible · tccli · GitOps          │
│    L3 编排与运行时    K8S (5) + K8S/架构 (8)                             │
│       kubeadm HA · pod · 控制器 · 网络 · 存储 · 调度 · helm · docker     │
│    L2 中间件与应用    TOOL (4) + Mysql (6)                               │
│       MySQL · Nginx · Redis · 文件格式 · 组件                            │
│    L1 系统基础        LINUX (11) + SEC/network (1)                       │
│       内核 · 网络 · 资源 · 管理 · 目录 · SHELL · 网络原理                │
├──────────────────────────────────────────────────────────────────────────┤
│ ③ 横切      安全  K8S/架构/安全 · SEC/safety · LINUX/本机/安全           │
│             排障  K8S/排障（贯穿 L1–L3）                                 │
│             认证  K8S/CKA · SEC/safety/CKS                               │
└──────────────────────────────────────────────────────────────────────────┘
```

### My projects:

基于 IaC 与 GitOps 的多环境交付流水线建设（自动化、工具链整合）：

https://github.com/ZZZZTI/Cloud-Native-knowledge.git

核心链路 SLO 保障与全链路可观测性治理（稳定性、监控、应急响应）：

https://github.com/ZZZZTI/Cloud-Native-knowledge.git



