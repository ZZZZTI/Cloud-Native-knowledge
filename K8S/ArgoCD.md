> ArgoCD 是一个基于 GitOps 理念的 Kubernetes 持续交付工具，通过监听 Git 仓库中的声明式配置，自动将集群状态同步到期望状态。

------

### 概念

```Shell
一、GitOps 概念：理解“拉模型”与“持续协调”
传统 CI/CD 通常是“推模型”：CI 流水线构建镜像后，直接拿着集群的 kubeconfig 执行 kubectl apply 把应用推到集群里。这种方式的问题在于 CI 工具持有生产集群的完整操作权限，安全风险集中，而且如果有人在集群里手动改了配置，CI 并不知道。
GitOps 用的是“拉模型”：Git 仓库是唯一的事实来源，集群内部运行着一个 Agent（Argo CD），它持续监控 Git 仓库和集群实际状态，发现差异就自动修复。这样 CI 只需要有 Git 仓库的写权限，不需要碰集群 kubeconfig；所有变更都经过 Git PR 审查，审计日志天然存在 Git log 里。
核心区别可以总结为：推模型是“事件触发，推一次就结束”，拉模型是“持续轮询，一直在协调”。


二、Argo CD 核心概念：Application 与同步状态
Argo CD 中最核心的对象是 Application。它描述了一件事：“从哪个 Git 仓库的哪个路径，把资源部署到哪个集群的哪个命名空间”。
你需要理解两个关键状态字段：
Sync Status（同步状态）：Synced 表示集群实际状态与 Git 期望状态一致；OutOfSync 表示有差异，可能是 Git 变了还没同步，也可能是有人手动改了集群资源。
Health Status（健康状态）：Healthy 表示所有资源运行正常；Degraded 表示有 Pod 崩溃或 Job 失败；Progressing 表示正在创建或更新中。
注意：一个应用可以同时是 Synced 但 Degraded——集群配置和 Git 完全一致，但应用本身跑不起来（比如镜像有问题）。
```

