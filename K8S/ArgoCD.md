> ArgoCD 是基于 GitOps 的 Kubernetes 持续交付工具：监听 Git 仓库中的声明式配置，把集群状态持续同步到期望状态。
>
> 概念，架构，部署，Application，同步策略，AppProject 与 RBAC，Sync Waves 与 Hooks，CLI，排障

------

### 概念

一、推模型 vs 拉模型

传统 CI/CD 是「推模型」：CI 构建镜像后拿集群 kubeconfig 直接 `kubectl apply`。问题是 CI 持有生产集群完整权限，且有人手动改集群时 CI 无感知。

GitOps 是「拉模型」：Git 是唯一事实来源，集群内 Agent 持续比对 Git 与集群实际状态并自动修复。CI 只需 Git 写权限，变更走 PR 审查，审计日志天然在 Git log 里。

| 对比项 | 推模型 | 拉模型 |
| :-- | :-- | :-- |
| 触发 | CI 事件，推完即止 | 轮询 Git，持续协调 |
| 凭据 | CI 持 kubeconfig | CI 只需 Git 写权限 |
| 手动改动 | 不可见 | `selfHeal` 自动改回 |
| 回滚 | 重跑流水线 | `git revert` / `argocd app rollback` |

二、Application 与双状态

Application 描述「从哪个 Git 仓库的哪个路径，把资源部署到哪个集群的哪个命名空间」。

- **Sync**：`Synced`（与 Git 一致）/ `OutOfSync`（有差异）
- **Health**：`Healthy` / `Progressing` / `Degraded` / `Suspended` / `Missing` / `Unknown`

两者正交：**可以 Synced 但 Degraded** —— 配置与 Git 完全一致，但镜像有问题跑不起来。排障必须分开看。

------

### 架构

```Shell
# 组件
argocd-server                  # API + Web UI + gRPC，对外入口（443/8080）
argocd-repo-server             # clone Git、把 Helm/Kustomize 渲染成纯 YAML（8081）
argocd-application-controller  # 核心协调器（StatefulSet），比对 Git 与集群并执行 sync
argocd-redis                   # 缓存，提升比对性能
argocd-dex-server              # 内置 SSO（OIDC/LDAP/GitHub）
argocd-notifications-controller # 通知（Slack/邮件/webhook）
argocd-applicationset-controller # ApplicationSet 控制器

# 一次同步
controller 发现 OutOfSync
  → 向 repo-server 请求渲染（clone Git → helm template / kustomize build）
  → 与集群实际清单做三方 diff（last-applied / live / desired）
  → 调 kube-apiserver 执行 apply / prune
  → 更新 Application.status（sync + health + operationState）
```

关键点：**repo-server 不碰集群，controller 不碰 Git**，职责分离后可各自扩缩容。

------

### 部署

```bash
# 安装（标准版；高可用版把 install.yaml 换成 ha/install.yaml）
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Helm 方式（生产推荐，便于固化版本）
helm repo add argo https://argoproj.github.io/argo-helm && helm repo update
helm install argocd argo/argo-cd -n argocd --create-namespace

# 取初始密码（登录后立即改密并删除该 secret）
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# 访问
kubectl port-forward svc/argocd-server -n argocd 8080:443
# 浏览器 https://localhost:8080    用户 admin

# CLI
brew install argocd
argocd login localhost:8080 --username admin --password '<密码>' --insecure
argocd account update-password
```

生产对外暴露走 Ingress + TLS，不要直接 `NodePort`。

------

### Application

```Shell
# ============================================================
# Application：最小可用清单
# ============================================================
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web
  namespace: argocd                      # 必须放 argocd 命名空间
  finalizers:
    - resources-finalizer.argocd.argoproj.io   # 删 Application 时级联删资源
spec:
  project: default
  source:
    repoURL: https://github.com/ZZZZTI/Cloud-Native-knowledge.git
    targetRevision: HEAD                 # 生产建议固定 tag 或 commit SHA
    path: deploy/overlays/prod
  destination:
    server: https://kubernetes.default.svc   # in-cluster；外部集群用 cluster add 后的地址
    namespace: prod
  syncPolicy:
    automated:
      prune: true                        # Git 删掉的资源，集群也删
      selfHeal: true                     # 手动改动自动改回
      allowEmpty: false                  # 渲染为空时拒绝，防误清空命名空间
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true                   # 先应用新的，最后删旧的
      - ApplyOutOfSyncOnly=true          # 只 apply 有差异的资源
      - ServerSideApply=true             # 大 CRD 超 annotation 上限时必开
    retry:
      limit: 5
      backoff: { duration: 5s, factor: 2, maxDuration: 3m }
```

```Shell
# 渲染方式一：Kustomize
  source:
    repoURL: https://github.com/org/repo.git
    targetRevision: main
    path: overlays/prod
    kustomize:
      namePrefix: prod-
      images: [my-app=registry.example.com/my-app:v2.0.0]

# 渲染方式二：Helm
  source:
    repoURL: https://github.com/org/repo.git
    chart: nginx                         # 用 chart 字段代替 path
    targetRevision: 1.2.3                # chart 版本
    helm:
      releaseName: web
      valueFiles: [values-prod.yaml]
      parameters: [{ name: image.tag, value: v1.2.3 }]
```

------

### 同步策略

```Shell
# 三个自动同步开关的取舍
prune: true        # 最危险也最有价值，先确认 Git 里资源确实该删
selfHeal: true     # 与运维「临时热修」冲突，需约定流程
allowEmpty: false  # 防「写错 path 导致清空整个命名空间」

# 其余常用 syncOptions
Validate=false                       # CRD 未就绪时跳过 schema 校验
SkipDryRunOnMissingResource=true     # CRD 与应用同批创建时必需
RespectIgnoreDifferences=true        # prune 时也遵守 ignoreDifferences
PrunePropagationPolicy=foreground    # background|foreground|orphan
FailOnSharedResource=true            # 同一资源被两个 App 管理时拒绝

# 忽略差异：HPA 改了 replicas，不要报 OutOfSync
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers: [/spec/replicas]
  # 或直接忽略某控制器写过的字段
  # managedFieldsManagers: [kube-controller-manager]
```

------

### AppProject 与 RBAC

```Shell
# AppProject：限定「哪些仓库 → 哪些集群/命名空间 → 哪些资源类型」，是多租户边界
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
  namespace: argocd
spec:
  sourceRepos:
    - https://github.com/org/team-a-*
  destinations:
    - server: https://kubernetes.default.svc
      namespace: team-a-*
  clusterResourceWhitelist:            # 集群级资源默认全禁，按需白名单
    - { group: "", kind: Namespace }
  namespaceResourceBlacklist:
    - { group: "", kind: ResourceQuota }
  roles:
    - name: dev
      policies:
        - "p, proj:team-a:dev, applications, get,  team-a/*, allow"
        - "p, proj:team-a:dev, applications, sync, team-a/*, allow"
      groups: ["my-org:team-a"]
```

```Shell
# RBAC：argocd-rbac-cm
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly        # 默认必须只读，不要留 role:admin
  policy.csv: |
    p, role:dev, applications, get,    */*, allow
    p, role:dev, applications, sync,   team-a/*, allow
    p, role:ops, applications, *,      */*, allow
    g, my-org:team-a, role:dev
```

权限三元组是 `p, 角色, 资源, 动作, 对象, 效果`。资源有 `applications` / `projects` / `repositories` / `clusters` / `accounts`；`applications` 的动作有 `get` `create` `update` `delete` `sync` `override`（`override` 允许绕过 Git 临时改 revision，只给 break-glass 账号）。

------

### Sync Waves 与 Hooks

```Shell
# Sync Wave：数值小的先执行
# 典型分层：CRD(-5) → Namespace(-4) → Config(-3) → DB Migration(-1)
#          → 业务负载(0) → Ingress(1) → 验收 Job(2)
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"   # 默认 0，可为负
```

```Shell
# Hook：本质是「带注解的 Job」，失败会让整次 sync 失败
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync      # PreSync|Sync|PostSync|SyncFail|Skip
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
    argocd.argoproj.io/sync-wave: "-1"
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: registry.example.com/migrate:1.0
```

| Hook | 用途 |
| :-- | :-- |
| `PreSync` | 数据库迁移、备份、生成配置 |
| `Sync` | 与业务资源同批（不写 hook 的资源都在此阶段） |
| `PostSync` | 冒烟测试、通知、刷新 CDN |
| `SyncFail` | 失败时的清理与告警 |

------

### CLI 速查

```bash
# 查看
argocd app list [-p 项目] [-o wide]
argocd app get <app>                  # 状态+资源树+事件，排障第一入口
argocd app get <app> --refresh        # 强制重新拉 Git 比对
argocd app diff <app>                 # Git 与集群差异
argocd app manifests <app>            # 渲染后的清单
argocd app history <app>

# 操作
argocd app create <app> --repo <url> --path <p> \
  --dest-server https://kubernetes.default.svc --dest-namespace <ns> \
  --sync-policy automated --auto-prune --self-heal
argocd app sync <app> [--dry-run] [--prune] [--force] [--resource <g:k:n>]
argocd app wait <app> --health --sync
argocd app rollback <app> <history-id>
argocd app terminate-op <app>          # 终止卡住的同步
argocd app delete <app> --cascade      # 不加 --cascade 只删 Application 对象

# 仓库 / 集群 / 项目
argocd repo add <url> --username <u> --password <token>
argocd repo add git@github.com:org/r.git --ssh-private-key-path ~/.ssh/id_ed25519
argocd cert add-tls <host> --from ca.crt      # 自签 HTTPS 仓库
argocd cluster add <context>            # 注册外部集群
argocd proj create <p> / add-source / add-destination
```

多集群多环境用 **ApplicationSet** 批量生成，常用生成器：`list`（手写）、`git`（扫目录/读 values，最常用）、`cluster`（遍历已注册集群）、`matrix`（环境 × 集群笛卡尔积）、`pullRequest`（每个 PR 一套预览环境）。

------

### 排障

```Shell
# 1) OutOfSync 但 diff 看不到差异
#    → controller 写入的字段（HPA 改 replicas、Service 补 clusterIP）
#    → 用 ignoreDifferences 或 managedFieldsManagers 抑制

# 2) 同步失败
argocd app get <app> --show-operation            # 看 operationState.message
kubectl -n argocd logs deploy/argocd-repo-server --tail=100
kubectl -n argocd logs statefulset/argocd-application-controller --tail=100

# 3) 仓库连不上 / 认证失败
argocd repo list                                 # 看 STATUS 列
kubectl -n argocd get secret -l argocd.argoproj.io/secret-type=repository

# 4) 渲染报错
argocd app manifests <app>                       # 直接暴露渲染错误
helm template <release> ./chart -f values.yaml   # 本地复现
kubectl kustomize overlays/prod

# 5) 卡 Progressing / Terminating
kubectl -n <ns> describe pod <pod>
kubectl -n <ns> get <res> -o json | jq '.metadata.finalizers'

# 刷新级别
normal refresh   # 用缓存，默认每 3 分钟一次
hard refresh     # 重新 clone + 重新渲染
argocd app get <app> --refresh
kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard --overwrite
```

------

### 核心概念

1. **GitOps 拉模型**：Git 是唯一事实来源，Agent 持续协调；相比推模型，凭据边界更干净且能自动纠正漂移。
2. **Application 四要素**：`source`（仓库+路径/渲染方式）、`destination`（集群+命名空间）、`project`、`syncPolicy`。
3. **sync 与 health 正交**，`Synced + Degraded` 完全合法；排障先分清是「不一致」还是「跑不起来」。
4. **同步策略**：`prune` 删多余、`selfHeal` 纠漂移、`allowEmpty: false` 防误清空；三个最常踩的 `syncOptions` 是 `ServerSideApply`、`SkipDryRunOnMissingResource`、`PruneLast`。
5. **AppProject 是四维白名单**（仓库/集群/命名空间/资源类型），RBAC 的 `policy.default` 必须设 `role:readonly`。
6. **wave 管顺序、hook 管时机**；hook 是带注解的 Job，失败即 sync 失败。
7. **与 CI 的分工**：CI 构建镜像并把新 tag 写回 Git；ArgoCD 只负责把 Git 同步到集群。需要金丝雀/蓝绿接 **Argo Rollouts**。
