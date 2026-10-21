> Kubernetes 管理员认证

------

### 

```Shell
故障排除（30%）：权重最高。重点考察排查节点 NotReady、Pod 启动失败（CrashLoopBackOff）、网络不通等问题的能力，需熟练使用 kubectl describe、logs、exec。

集群架构、安装与配置（25%）：重点包括使用 kubeadm 安装/升级集群、etcd 备份与恢复、RBAC 权限配置以及管理高可用集群。

服务与网络（20%）：考察 Service 类型配置、Ingress 规则、Network Policy 以及 CoreDNS 的配置与排错。
工作负载与调度（15%）：涉及 Deployment 的滚动更新与回滚、Pod 调度策略（亲和性/污点）、资源配额及 HPA 配置。

存储（10%）：主要考察 PV/PVC/StorageClass 的创建与绑定，以及将存储挂载到 Pod 中。
```

## CKA 

| 考试域（权重）            | 必练                                                         |
| :------------------------ | :----------------------------------------------------------- |
| 故障排查（30%）           | Pod 状态机全部异常、Service 端点、DNS、节点 NotReady、日志三连 |
| 集群架构/安装/配置（25%） | `kubeadm` init/join/upgrade、etcd 备份恢复、RBAC、HA 拓扑    |
| 服务与网络（20%）         | Service 四种类型、Ingress、NetworkPolicy、CoreDNS 排错       |
| 工作负载与调度（15%）     | 滚动更新与回滚、亲和/反亲和、污点容忍、配额、HPA             |
| 存储（10%）               | PV/PVC/StorageClass、绑定排错、挂载到 Pod                    |

**CKA 实操高频题**：升级集群、etcd 备份恢复、创建 NetworkPolicy、修一个 `CrashLoopBackOff`、把 Pod 调度到指定节点、创建 PVC 并挂载、RBAC 授权、暴露 Service。建议全部练到不看文档能敲完。







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
