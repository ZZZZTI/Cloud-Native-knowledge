> Kubernetes 管理员认证

------

**CKA 考核领域（侧重运维管理）**

```
考核领域                                 权重   核心内容举例
故障排查 (Troubleshooting)               30%   诊断节点 NotReady、Pod 启动失败、应用无响应、网络不通、存储挂载失败等问题
集群架构、安装与配置                       25%   使用 kubeadm 部署/升级集群、etcd 备份与恢复、RBAC 权限配置、节点维护（cordon/drain）
服务与网络 (Services & Networking)       20%   Service 类型、Ingress、NetworkPolicy 的基础配置
工作负载与调度 (Workloads & Scheduling)   15%   Deployment、DaemonSet、资源限额、节点亲和性等调度策略
存储 (Storage)                          10%   PV、PVC、StorageClass 的配置与管理
```

**CKS 考核领域（侧重安全加固）**

```
考核领域                      权重  核心内容举例
监控、日志与运行时安全          20%   使用 Falco 进行运行时威胁检测、AppArmor/seccomp 配置、审计日志分析
供应链安全 (Supply Chain)     20%   镜像签名与验证 (cosign)、Trivy 漏洞扫描、SBOM、OPA/Gatekeeper 准入控制
微服务漏洞最小化               20%   Pod 安全标准 (Pod Security Standards)、Secret 管理、多租户隔离、Pod 间加密
集群安装与加固                 15%   使用 CIS Benchmark 检查安全配置、限制 API 访问、Ingress TLS 设置、保护节点元数据
集群强化 (Cluster Hardening)  15%   精细化 RBAC、ServiceAccount 权限最小化、API Server 安全配置
系统强化 (System Hardening)   10%   最小化主机操作系统攻击面、限制外部网络访问、内核强化工具使用
```



## 🏁 里程碑项目

### 项目一：三层应用上云（阶段 1-6 综合）

一个应用：前端（nginx）+ 后端 API（任意语言的简单 HTTP 服务）+ 数据库（PostgreSQL StatefulSet）。

要求：

- 命名空间隔离；前端/后端用 Deployment，数据库用 StatefulSet + PVC
- 配置全部走 ConfigMap/Secret（数据库密码不写死在镜像里）
- 每个容器配 `resources` + 三种探针
- 服务间通过 Service 名互相访问；外部通过 Ingress 访问前端
- 用 `kubectl port-forward` 或端口映射验证完整链路
- 交付物：一个 `manifests/` 目录 + 一份 README，能从零 `kubectl apply -f` 起来

### 项目二：多环境发布与回滚（阶段 3 + 10 综合）

- 用 Kustomize（base + dev/prod overlay）或 Helm（多 values 文件）管理两套环境
- 演练：发布 v2 → 观察滚动更新 → 发现异常 → `rollout undo` / `helm rollback`
- 要求：记录每一次操作的命令和输出，形成一份"发布手册"
- 加分：给 Deployment 加 `checksum/config` 注解，改 ConfigMap 自动触发发布

### 项目三：可观测 + 安全加固（阶段 8 + 9 综合）

- 装 metrics-server，配一个 HPA，用压力工具观察自动扩容
- 给应用配最小权限 ServiceAccount（只读自己命名空间的 ConfigMap）
- 命名空间打 `pod-security.kubernetes.io/enforce: restricted` 标签，把不符合的应用改到合规
- 故意注入 5 种故障（ImagePullBackOff / CrashLoopBackOff / Pending / OOMKilled / Service 无端点），每种写下排查过程和根因
- 交付物：《故障演练报告》
