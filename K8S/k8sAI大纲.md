# Kubernetes 学习大纲（macOS + kind 实战版）

> 本大纲配套的实验环境**已经在你这台 Mac 上装好并验证过**（Apple Silicon / macOS 14.8.2）。
> 全程本地运行，不需要云账号、不需要信用卡。所有实验都在 `k8s-lab/` 目录里。

---

## 0. 怎么用这份大纲

| 项目     | 建议                                                         |
| -------- | ------------------------------------------------------------ |
| 总周期   | 8～12 周，每天 1.5～2 小时；或 4 周全天投入                  |
| 学习方式 | **每个阶段动手 > 看文档**。看懂 ≠ 会，敲一遍才算数           |
| 节奏     | 阶段 1-6 是地基，不要跳；阶段 7 之后可按需取舍               |
| 检验标准 | 每阶段的"自检问题"能不看资料口头讲清楚，才算过关             |
| 核心心法 | K8s 是**声明式**的：你写"期望状态"，控制器负责把现实拉过去。学任何对象都问三句：**期望状态是什么？谁来负责？怎么验证？** |

**实验目录结构**

```
k8s-lab/
├── colima.yaml              # 虚拟机配置（4C/8G/60G，镜像加速已配好）
├── scripts/
│   ├── 01-install-toolchain.sh   # 工具链安装（已执行过）
│   ├── 02-start-colima.sh        # 启动 docker 运行环境
│   └── 03-create-cluster.sh      # 创建 kind 集群
├── kind/
│   ├── kind-single.yaml          # 单节点集群（默认用这个）
│   └── kind-multinode.yaml       # 1 控制面 + 2 工作节点（练调度用）
└── manifests/                    # 配套实验 YAML（按主题编号）
```

---

## 1. 本机环境说明

### 1.1 架构：三层套娃，先理解它就不迷路

```
你的 Mac (macOS 14, arm64)
│
├── kubectl / helm / kind / docker CLI / k9s     ← 你在终端敲的命令
│
└── colima 虚拟机 (Apple Virtualization.framework, 4C/8G)
    │   ← 这里跑着 docker daemon，docker CLI 通过 socket 连它
    │
    └── kind 集群 "lab"（节点 = docker 容器）
        ├── lab-control-plane 容器  ← 里面跑 kubelet/containerd/apiserver/etcd
        └── 由它再拉起的 Pod（nginx 等）
```

**关键认知**：

- kind 的"节点"不是虚拟机，就是一个普通 docker 容器，里面装了 kubelet + containerd。
- 所以 `docker ps` 能看到节点，`docker exec -it lab-control-plane bash` 能进"节点"。
- Pod 是容器里的容器（三层嵌套），调试链路要一层层往下走。

### 1.2 已安装组件

| 组件                     | 版本           | 作用                                        |
| ------------------------ | -------------- | ------------------------------------------- |
| kubectl                  | v1.37.1        | 集群操作客户端                              |
| kind                     | 0.33.0         | 用容器跑 K8s 集群                           |
| colima + lima            | 0.10.3 / 2.2.1 | 提供 docker daemon（轻量、无 GUI、免 sudo） |
| docker CLI               | 29.8.2         | 容器操作                                    |
| helm                     | 4.3.0          | 包管理                                      |
| k9s                      | 0.51.0         | 终端 UI（强烈推荐，看图比看命令快）         |
| kubectx / kubens         | 0.11.0         | 快速切集群/命名空间                         |
| metrics-server / ingress | 未安装         | 阶段 8 / 阶段 4 按需安装                    |

集群创建后**自动就有**、不用自己装的组件：

| 内置组件                                               | 作用                                                         |
| ------------------------------------------------------ | ------------------------------------------------------------ |
| CoreDNS                                                | 集群内 DNS（`kube-system` 下的 `coredns-*`）                 |
| kindnet                                                | 默认 CNI，负责 Pod 网络，**已实测会执行 NetworkPolicy**      |
| kube-proxy                                             | 把 Service 规则翻译成节点上的转发规则                        |
| local-path-provisioner + StorageClass `standard`(默认) | **自带默认 StorageClass**，PVC 可直接动态供给（kind 0.33 新增，很多老教程没提） |

### 1.3 日常启停（背下来）

```bash
# —— 开工 ——
colima start                 # 启动 docker 运行环境（首次或重启后）
colima status                # 看状态
docker info                  # 确认 daemon 可用
kind get clusters            # 看有哪些集群
kubectl get nodes            # 看节点

# —— 收工（省电）——
colima stop                  # 停虚拟机，集群和镜像都保留

# —— 彻底重来 ——
kind delete cluster --name lab
colima delete                # 删除虚拟机（镜像全没，需重新拉）
```

### 1.4 本机网络特殊性（**很重要，别的教程没有**）

你这台机器 `registry-1.docker.io`（Docker Hub 直连）和 `github.com` **不通**。已经做的处理：

1. **docker daemon 配了镜像加速** → `docker pull nginx` 这类命令会走 `docker.m.daocloud.io`。
2. **kind 集群内的 containerd 也配了加速**（`containerdConfigPatches`）→ Pod 拉镜像也能成功。
3. `registry.k8s.io`、`quay.io`、`ghcr.io` 是通的，正常用。

> 因此：写 YAML 时**直接用官方镜像名**（`nginx:1.27`），不要手写加速域名。
> 如果哪天拉镜像报 `ImagePullBackOff`，先看第 15 号实验的排查手册。

### 1.5 常用镜像加速说明

```bash
# 查看加速配置是否生效
docker info | grep -A3 'Registry Mirrors'

# 万一加速源挂了，可以临时指定
docker pull dockerproxy.net/library/nginx:1.27
docker tag  dockerproxy.net/library/nginx:1.27 nginx:1.27
```

---

## 2. 学习路线总览

| 阶段 | 主题                             | 建议时长  | 产出/里程碑                         |
| ---- | -------------------------------- | --------- | ----------------------------------- |
| 1    | 心智模型 + kubectl 基本功        | 2-3 天    | 能读懂任意 YAML 的结构              |
| 2    | Pod 深入（生命周期/探针/多容器） | 3-4 天    | 能解释 CrashLoopBackOff 的每个原因  |
| 3    | 工作负载控制器                   | 3-4 天    | 会做滚动更新与回滚                  |
| 4    | 服务发现与网络                   | 4-5 天    | 能从零打通 外部→Ingress→Service→Pod |
| 5    | 配置与密钥                       | 2 天      | 配置与镜像解耦                      |
| 6    | 存储                             | 3-4 天    | 数据持久化 + StatefulSet 跑数据库   |
| 7    | 调度与资源管理                   | 3-4 天    | 能定位 Pod Pending 的 8 种原因      |
| 8    | 可观测性与排障                   | 3-4 天    | 有一套自己的排障决策树              |
| 9    | 安全与多租户                     | 3-4 天    | 最小权限 RBAC + 安全上下文          |
| 10   | 包管理与交付                     | 3-4 天    | 用 Helm/Kustomize 管理多环境        |
| 11   | 进阶与生产化                     | 持续      | CRD/Operator/集群运维               |
| 🏁    | 三个里程碑项目                   | 各 1-2 天 | 作品集                              |

| 阶段   | 主题                      | 用到的文件                                                   |
| :----- | :------------------------ | :----------------------------------------------------------- |
| **1**  | 心智模型 + kubectl 基本功 | **无文件**，全程用 `kubectl run` 临时对象                    |
| **2**  | Pod 深入（探针/多容器）   | `01-pod-basic.yaml`、`02-pod-probe.yaml`                     |
| **3**  | 工作负载控制器            | `03-deployment-rollout.yaml`、`07-statefulset-headless.yaml`、`08-daemonset-job.yaml` |
| **4**  | 服务发现与网络            | `04-service.yaml`、`12-networkpolicy.yaml`、`14-helm-notes.md`（装 ingress-nginx） |
| **5**  | 配置与密钥                | `05-configmap-secret.yaml`                                   |
| **6**  | 存储                      | `06-persistentvolume.yaml`、`07-statefulset-headless.yaml`（复用） |
| **7**  | 调度与资源管理            | `09-scheduling.yaml`、`10-resources-qos.yaml`、`13-quota-limitrange.yaml` |
| **8**  | 可观测性与排障            | `15-troubleshooting.md`、`14-helm-notes.md`（装 metrics-server） |
| **9**  | 安全与多租户              | `11-rbac.yaml`                                               |
| **10** | 包管理与交付              | `14-helm-notes.md`（Helm 手册）                              |
| **11** | 进阶与生产化              | 无专门文件（自己装 cert-manager 等）                         |
| 🏁      | 里程碑项目                | 综合复用以上所有                                             |

------

## 阶段 1：心智模型与 kubectl 基本功（2-3 天）

### 学习目标

建立"期望状态 vs 实际状态"的思维模型，能熟练用 kubectl 观察任意资源。

### 核心概念

1. **控制面组件**
   - `kube-apiserver`：唯一入口，所有读写都走它（REST + 认证 + 准入）
   - `etcd`：唯一数据源，存整个集群的期望状态
   - `kube-scheduler`：决定 Pod 放哪个节点（只决定，不负责启动）
   - `kube-controller-manager`：一堆控制循环（Deployment/Node/Job…）
2. **节点组件**
   - `kubelet`：节点上的"工头"，负责把 Pod 的容器真的跑起来、上报状态
   - `containerd`（CRI 运行时）：真正拉镜像、起容器
   - `kube-proxy`：把 Service 规则翻译成 iptables/IPVS 规则
3. **插件**：CoreDNS（集群内 DNS）、CNI（kindnet，负责 Pod 网络并执行 NetworkPolicy）、local-path-provisioner（默认 StorageClass）
4. **声明式 API**：`spec` 是你写的期望状态，`status` 是控制器回填的现实。**永远不要手动改 status**。
5. **对象通用结构**：`apiVersion` / `kind` / `metadata` / `spec` / `status`；用 `ownerReferences` 表达从属关系。

### 动手实验

```bash
# 1) 集群解剖：节点其实是容器
docker ps                                   # 看到 lab-control-plane
docker exec lab-control-plane crictl ps      # 节点内的容器（含 pause 沙箱）
docker exec lab-control-plane ps aux | head  # 看 kubelet/apiserver 进程

# 2) kubectl 命令族
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl api-resources | head -30             # 集群支持哪些资源
kubectl explain pod.spec.containers          # 最好的文档，离线可查
kubectl explain deploy.spec.strategy --recursive

# 3) 输出格式（排障核心技能）
kubectl get pod -n kube-system -o yaml | head -40
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
kubectl get pods -A --sort-by=.metadata.creationTimestamp
kubectl get pods -A 
-o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,NODE:.spec.nodeName'

# 4) 观察"期望状态"如何被实现
kubectl run demo --image=nginx:1.27
kubectl get pod demo -w        # 用 -w 盯着状态变化，另开一个终端
kubectl describe pod demo | tail -20   # Events 区就是控制器的"工作日志"
kubectl delete pod demo
```

### 自检问题

1. 敲下 `kubectl apply -f deploy.yaml` 后，到 Pod 真正运行，中间经过哪些组件？按顺序说出来。
2. `kubectl get pods` 的数据从哪里来的？为什么它可能比现实"慢半拍"？
3. 为什么说 etcd 挂了集群就"失忆"了，但已有的 Pod 还在跑？

### 常见坑

- 用 `kubectl create` 和 `kubectl apply` 混着用同一个对象 → 报字段冲突（`last-applied-configuration` 丢失）。**统一用 apply**。
- 忘了 `-n <namespace>`，以为资源消失了。
- 只 `get` 不 `describe`：`get` 看现象，`describe` 看原因（Events）。

---

## 阶段 2：Pod 深入（3-4 天）

### 学习目标

彻底理解 Pod 的生命周期、调度单位、探针语义，能独立诊断启动类故障。

### 核心概念

1. **Pod 是最小调度单位**：同 Pod 内的容器共享 network namespace（同一 IP、端口不能冲突）、IPC、UTS，可共享 Volume。

2. **pause 容器（沙箱）**：每个 Pod 有一个看不见的 `pause` 容器持有网络命名空间，业务容器挂在它上面。

3. **生命周期**：`Pending → Running → Succeeded/Failed`；容器级别有 `Waiting / Running / Terminated`。

4. **重启策略** `restartPolicy`：`Always`（默认）/`OnFailure`/`Never`。Pod 本身不会被"重启"，是容器被重启。

5. **三种探针**（最重要的考点）

   | 探针             | 失败后果                                            | 用途               |
   | ---------------- | --------------------------------------------------- | ------------------ |
   | `startupProbe`   | 一直重试，通过前不执行另两个探针，超时后重启容器    | 慢启动应用（Java） |
   | `livenessProbe`  | **重启容器**                                        | 死锁/假死检测      |
   | `readinessProbe` | **不重启**，只是从 Service Endpoints 摘掉，不发流量 | 流量就绪判断       |

   - 探针方式：`httpGet` / `tcpSocket` / `exec` / `grpc`；参数 `initialDelaySeconds`/`periodSeconds`/`timeoutSeconds`/`failureThreshold`/`successThreshold`。

6. **优雅终止**：`terminationGracePeriodSeconds`（默认 30s）→ 收到 SIGTERM → `preStop` 钩子 → 超时 SIGKILL。

7. **多容器模式**：init container（顺序执行、跑完即退）、sidecar（同生共死，如日志收集）、ambassador/adapter。

8. **资源**：`requests` 影响调度，`limits` 影响运行时上限；CPU 超限被限流（throttle），内存超限被 OOMKilled。

9. **QoS 类别**（决定被驱逐的优先级）：Guaranteed > Burstable > BestEffort。

### 动手实验

```bash
kubectl apply -f manifests/01-pod-basic.yaml
kubectl apply -f manifests/02-pod-probe.yaml

# 观察探针把容器打死
kubectl get pod probe-demo -w
kubectl describe pod probe-demo        # 看 Liveness probe failed / Killing

# 进入 Pod 调试
kubectl exec -it probe-demo -c web -- sh
kubectl logs probe-demo -c web --previous    # 看上一个崩溃实例的日志（关键技能）

# 人为制造 CrashLoopBackOff
kubectl run crash --image=busybox:1.36 -- sh -c 'echo boot; exit 1'
kubectl get pod crash -w
kubectl logs crash --previous
kubectl delete pod crash
```

### 自检问题

1. readiness 探针失败为什么**不**重启容器？如果它一直失败会发生什么？
2. `initialDelaySeconds` 设太大 / 太小分别有什么风险？
3. Pod 删除时，为什么流量不会立刻断？（提示：Endpoints 摘除 + preStop + 优雅期）
4. 两个容器在同一 Pod 里都想监听 8080 端口，可以吗？为什么？

### 常见坑

- liveness 探针指向了需要认证的接口 → 容器被反复重启。
- 用 `exec` 探针跑 `curl`，但镜像里没有 curl → 探针永远失败。
- 只设 `limits` 不设 `requests` → 调度时按 limit 估算，容易挤爆节点。
- 把 `readinessProbe` 和 `livenessProbe` 配成一模一样，一个慢启动就把服务打死。

---

## 阶段 3：工作负载控制器（3-4 天）

### 学习目标

掌握四类控制器的适用场景，能安全地做发布与回滚。

### 核心概念

1. **ReplicaSet**：保证副本数；一般**不要直接用**，用 Deployment 管它。
2. **Deployment**：管理 RS 的版本。
   - `strategy.rollingUpdate`：`maxSurge`（最多超出多少）/`maxUnavailable`（最多不可用多少）
   - `revisionHistoryLimit`、`progressDeadlineSeconds`
   - 关键命令：`rollout status / history / undo / restart / pause / resume`
   - 变更 `spec.template` 才触发发布；只改副本数不会。
3. **StatefulSet**：有状态应用
   - 稳定的网络标识：`pod-0.web.default.svc.cluster.local`（需 headless Service）
   - 稳定的存储：`volumeClaimTemplates` 每副本一块盘，删 Pod 不删盘
   - 有序部署/缩容（默认 `OrderedReady`），可 `podManagementPolicy: Parallel`
4. **DaemonSet**：每个（符合条件的）节点跑一份，用于日志/监控/网络插件。
5. **Job / CronJob**：批处理
   - Job：`completions`/`parallelism`/`backoffLimit`/`activeDeadlineSeconds`/`ttlSecondsAfterFinished`
   - CronJob：`schedule`（5 段式或 `@daily`）/`concurrencyPolicy`（Allow/Forbid/Replace）/`suspend`/`startingDeadlineSeconds`
6. **HPA**（`autoscaling/v2`）：基于 CPU/内存/自定义指标扩缩容；需要 metrics-server。
7. **PDB**（`policy/v1`）：自愿中断时保证最低可用副本（配合节点维护/drain）。

### 动手实验

```bash
# 滚动更新与回滚
kubectl apply -f manifests/03-deployment-rollout.yaml
kubectl rollout status deploy/web
kubectl set image deploy/web web=nginx:1.26
kubectl rollout status deploy/web
kubectl rollout history deploy/web
kubectl rollout undo deploy/web            # 回滚
kubectl describe deploy/web | grep -A5 Events

# 观察 RS 换代
kubectl get rs -w

# StatefulSet 的稳定标识
kubectl apply -f manifests/07-statefulset-headless.yaml
kubectl get pods -l app=db -o wide
kubectl exec db-0 -- hostname
kubectl run dns-test --rm -it --image=busybox:1.36 --restart=Never -- \
  nslookup db-0.db.default.svc.cluster.local

# Job / CronJob
kubectl apply -f manifests/08-daemonset-job.yaml
kubectl get jobs,cronjobs,pods
kubectl logs job/pi-calc
```

### 自检问题

1. `maxUnavailable: 0` + `maxSurge: 1` 的效果是什么？适合什么场景？
2. Deployment 和 StatefulSet 的本质区别有哪些（至少 3 条）？
3. `rollout undo` 回滚后，`revisionHistory` 里发生了什么？
4. CronJob 的 `concurrencyPolicy: Forbid` 解决什么问题？

### 常见坑

- 改了 ConfigMap 但没触发 Deployment 重启 → 配置没生效（见阶段 5）。
- `kubectl rollout undo` 回滚的是 template，不包括 ConfigMap/Secret。
- StatefulSet 缩容再扩容，PVC 还在（这是特性，但会"惊讶"）。
- Job 没设 `ttlSecondsAfterFinished`，跑完的 Pod 一直堆着。

---

## 阶段 4：服务发现与网络（4-5 天）

### 学习目标

能独立构建"集群外 → Ingress → Service → Pod"的完整链路，并排查每一段。

### 核心概念

1. **Pod IP 是易变的** → 需要 Service 提供稳定虚拟 IP（VIP）。
2. **Service 四种类型**
   - `ClusterIP`（默认）：集群内 VIP
   - `NodePort`：在每个节点上开一个端口（默认 30000-32767）
   - `LoadBalancer`：需云厂商/`MetalLB` 支持
   - `ExternalName`：CNAME 到外部域名
3. **Endpoints / EndpointSlice**：Service 的 `selector` 匹配到的 Pod IP 列表 = 真实后端。
   - **没有 Endpoints = Service 不可用**，这是最常见的排查点（selector 不匹配 / Pod 没 Ready）。
4. **kube-proxy**：把 Service VIP:Port 翻译成 iptables/IPVS 规则实现转发（不是进程代理）。
5. **Headless Service**（`clusterIP: None`）：不做 VIP，直接返回所有 Pod IP，供 StatefulSet 用。
6. **DNS**：CoreDNS 提供
   - Service：`<svc>.<ns>.svc.cluster.local`
   - Pod：`<pod-ip-dashed>.<ns>.pod.cluster.local`
   - SRV 记录用于发现端口；`/etc/resolv.conf` 里的 `search` 与 `ndots:5` 决定了解析顺序
7. **Ingress**：L7 HTTP 路由（需要 Ingress Controller 才生效，kind 默认没有）
   - `ingressClassName`、`pathType: Prefix/Exact`、`tls`、注解（rewrite、超时、限流）
8. **NetworkPolicy**：Pod 级防火墙，**默认全通**，加了策略才隔离。
   - ✅ **本集群实测：kindnet 会真实执行策略**（kind 0.33 + k8s 1.37）：无策略时连通，加 deny-all 后不通，再加白名单标签后有标签通、无标签不通。网上"kind 默认 CNI 不支持 NetworkPolicy"的说法已经过时；但结论取决于 CNI 实现与版本，**务必亲手实验确认**（通=没强制，不通=真强制）。
9. **CNI 插件**：负责给 Pod 分配 IP、打通跨节点网络。

### 动手实验

```bash
# 1) 打通 ClusterIP → Pod
kubectl apply -f manifests/04-service.yaml
kubectl get svc,endpoints
kubectl run curl --rm -it --image=curlimages/curl --restart=Never -- \
  curl -s http://web-svc/ | head -3

# 2) 故意打破 selector，观察 Endpoints 变空（极重要）
kubectl patch svc web-svc -p '{"spec":{"selector":{"app":"wrong"}}}'
kubectl get endpoints web-svc        # <none>
kubectl describe svc web-svc
kubectl patch svc web-svc -p '{"spec":{"selector":{"app":"web"}}}'

# 3) 集群内 DNS 实验
kubectl run dnstest --rm -it --image=busybox:1.36 --restart=Never -- sh
#   容器里执行：
#   cat /etc/resolv.conf
#   nslookup web-svc
#   nslookup web-svc.default.svc.cluster.local
#   wget -qO- http://web-svc

# 4) 安装 Ingress Controller（用 helm，镜像走加速）
#    本集群已给控制面节点打上 ingress-ready=true 标签，并把节点 80/443
#    映射到 Mac 的 8080/8443（见 kind/kind-single.yaml），所以用 hostPort 模式最省事。
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.hostPort.enabled=true \
  --set controller.service.type=ClusterIP \
  --set controller.nodeSelector."ingress-ready"=true
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=300s
curl -s -o /dev/null -w 'ingress 入口 HTTP %{http_code}\n' http://localhost:8080   # 期望 404（还没建 Ingress 规则）
cat manifests/14-helm-notes.md      # 里面有更完整的 helm 手册（含 metrics-server 等）

# 5) 验证 NetworkPolicy 到底有没有生效（本集群：会真实拦截）
kubectl apply -f manifests/12-networkpolicy.yaml   # 按文件内第 ④ 步做连通性实验
# 实测结论（kind 0.33 + k8s 1.37 + kindnet）：
#   无策略 -> 连通；加 deny-all -> 不通；再加白名单标签 -> 有标签通、无标签不通
```

### 自检问题

1. Service 的 ClusterIP 是 ping 得通的吗？为什么？（提示：它是 iptables 规则，不是真实接口）
2. `kubectl get endpoints` 为空，列出至少 4 种可能原因。
3. NodePort 和 LoadBalancer 的区别？LoadBalancer 在没有云的环境怎么实现？
4. 为什么 StatefulSet 必须配 Headless Service？

### 常见坑

- Ingress 创建了但 404 → 没装 Controller，或 `ingressClassName` 不匹配。
- NodePort 在 macOS + kind 上**默认从宿主机访问不到**（节点容器端口没发布到宿主）。用 `kubectl port-forward`，或按 `kind-single.yaml` 里的 `extraPortMappings` 预映射端口。
- 误以为 NetworkPolicy 不生效就不写 → 本集群会**真实拦截**，中间件调用链很容易被自己写的策略误伤（改完策略一定回归验证）。
- Service 的 `targetPort` 写错（写成 Service 自己的 port）。

---

## 阶段 5：配置与密钥（2 天）

### 学习目标

把配置从镜像里彻底剥离出来，理解"改了配置为什么没生效"。

### 核心概念

1. **ConfigMap**：非敏感配置。创建方式：`--from-literal` / `--from-file` / `--from-env-file` / YAML。

2. **Secret**：敏感配置。类型 `Opaque`/`kubernetes.io/tls`/`kubernetes.io/dockerconfigjson`。

   - ⚠️ **Secret 默认只是 base64 编码，不是加密**，任何有读权限的人都能解出来。
   - 真正的保护：RBAC + etcd 静态加密（`EncryptionConfiguration`）+ 外部密钥管理（Vault/ESO）。

3. **三种消费方式**

   | 方式              | 是否热更新          | 说明                                         |
   | ----------------- | ------------------- | -------------------------------------------- |
   | `env` / `envFrom` | ❌ 不会              | 进程启动时读取，改了要重启 Pod               |
   | volume 挂载       | ✅ 会（约 1 分钟内） | kubelet 定期同步；`subPath` 挂载**不会**更新 |
   | 命令行参数        | ❌                   | 同上                                         |

4. **immutable**：设 `immutable: true` 后不能改，只能删了重建（性能更好，防误改）。

5. **配置版本化**：常见做法是 ConfigMap 名字带 hash（Helm/Kustomize 的 checksum 注解），改配置就换名字 → 自动触发滚动更新。

### 动手实验

```bash
kubectl apply -f manifests/05-configmap-secret.yaml
kubectl get cm,secret
kubectl describe cm app-config
kubectl get secret app-secret -o jsonpath='{.data.DB_PASSWORD}' | base64 -d; echo

# 验证热更新差异（关键实验）
kubectl exec config-demo -- cat /etc/config/app.properties      # volume 挂载
kubectl edit cm app-config                                       # 改一个值
sleep 60
kubectl exec config-demo -- cat /etc/config/app.properties      # 变了！
kubectl exec config-demo -- printenv APP_MODE                    # env 方式：没变
```

### 自检问题

1. 为什么 ConfigMap 改了，用 `envFrom` 注入的环境变量不会变？怎么让它生效？
2. `subPath` 挂载的 ConfigMap 为什么不会热更新？
3. Secret 和 ConfigMap 在实现上有本质区别吗？

### 常见坑

- 把 Secret 提交进 Git。用 SealedSecrets / SOPS / External Secrets。
- volume 更新延迟被误判为"没生效"。
- `envFrom` 时 ConfigMap 的 key 不符合环境变量命名规范（含 `-` 或 `.`）被静默跳过。

---

## 阶段 6：存储（3-4 天）

### 学习目标

理解 PV/PVC/StorageClass 的责任划分，能给有状态应用配持久化。

### 核心概念

1. **卷的类型谱系**
   - 临时：`emptyDir`（Pod 删除即丢，容器崩溃不丢）
   - 节点本地：`hostPath`（**危险**，仅实验用）、`local`
   - 配置：`configMap`/`secret`/`projected`/`downwardAPI`
   - 持久：`persistentVolumeClaim`
2. **PV / PVC / StorageClass 三角关系**
   - PVC 是"用户的申请单"（要多大、什么访问模式），PV 是"实际的盘"。
   - 绑定条件：容量 ≥ 申请、accessModes 匹配、storageClassName 一致、selector 匹配。
   - `accessModes`：`ReadWriteOnce`（单节点读写，最常用）/`ReadOnlyMany`/`ReadWriteMany`（需 NFS/CephFS 等）/`ReadWriteOncePod`。
   - `persistentVolumeReclaimPolicy`：`Retain`/`Delete`/`Recycle`。
3. **静态供给 vs 动态供给**
   - 静态：管理员先建 PV，PVC 去匹配。
   - 动态：PVC 指定 `storageClassName`，provisioner 自动建 PV（生产主流）。
   - `volumeBindingMode: WaitForFirstConsumer`：等 Pod 调度后再建盘（解决本地盘拓扑问题）。
4. **CSI**：容器存储接口，K8s 只定义接口，具体实现由厂商提供。
5. **StatefulSet + volumeClaimTemplates**：每个副本独立 PVC（`data-db-0`、`data-db-1`）。

### 动手实验

```bash
kubectl apply -f manifests/06-persistentvolume.yaml
kubectl get pv,pvc
kubectl describe pvc app-pvc            # 看绑定的 PV

# 数据持久性验证（核心实验）
kubectl exec pvc-demo -- sh -c 'date > /data/timestamp; cat /data/timestamp'
kubectl delete pod pvc-demo
kubectl apply -f manifests/06-persistentvolume.yaml
kubectl exec pvc-demo -- cat /data/timestamp    # 数据还在 → 持久化成立

# 动态供给：本集群自带默认 StorageClass `standard`（local-path），开箱即用
# PVC 里不写 storageClassName（或写 standard），apply 后会自动生成 PV 并 Bound
```

### 自检问题

1. PVC 一直 `Pending`，列出可能原因（至少 4 条）。
2. 删掉 PVC 后 PV 会怎样？取决于哪个字段？
3. 为什么 `hostPath` 不适合生产？它在 kind 里为什么能用？
4. `emptyDir` 在容器崩溃和 Pod 删除时分别会怎样？

### 常见坑

- `accessModes: ReadWriteMany` 在自己搭的环境里做不到（先确认 provisioner 是否支持）。
- PVC 和 Pod 在不同 namespace → 引用不到。
- 删了 Pod 但 PVC 还在，占着盘（`kubectl get pvc -A` 定期清理）。
- StatefulSet 缩容后 PVC 不删除，重装时数据"意外地还在"。

---

## 阶段 7：调度与资源管理（3-4 天）

### 学习目标

能精确控制 Pod 落在哪个节点，并解决资源相关的所有异常。

### 核心概念

1. **调度流程**：`过滤（Filter）`→ 排除不满足条件的节点 → `打分（Score）`→ 选最高分 → 绑定（Bind）。失败则 Pod 停在 `Pending`。
2. **影响调度的因素**
   - `resources.requests`（硬约束：节点剩余可分配资源）
   - `nodeSelector`（最简单）
   - `nodeAffinity`：`requiredDuringSchedulingIgnoredDuringExecution`（硬）/`preferred...`（软）
   - `podAffinity` / `podAntiAffinity`：按 `topologyKey` 和已有 Pod 的标签聚散
   - `topologySpreadConstraints`：均匀分布（比反亲和更精细）
3. **Taint / Toleration**
   - `NoSchedule` / `PreferNoSchedule` / `NoExecute`（后者会驱逐不容忍的 Pod）
   - 控制面节点默认有 `node-role.kubernetes.io/control-plane:NoSchedule`（单节点 kind 为了让 addon 跑起来移除了部分 taint）
4. **优先级与抢占**：`PriorityClass`；高优先级 Pod 可以抢占低优先级的。
5. **资源与运行时**
   - CPU：可压缩资源，超 `limits` 被 **throttle**（`container_cpu_cfs_throttled_seconds_total`）
   - 内存：不可压缩，超 `limits` 被 **OOMKilled**（`describe pod` 看 `Reason: OOMKilled`，退出码 137）
   - `requests` 决定 QoS 与调度；`limits` 决定上限
6. **配额与限制**：`ResourceQuota`（命名空间总量）、`LimitRange`（单个对象的默认值/上下限）
7. **弹性**：HPA（副本数）/ VPA（资源大小）/ Cluster Autoscaler（节点数）

### 动手实验

```bash
kubectl apply -f manifests/09-scheduling.yaml
kubectl apply -f manifests/10-resources-qos.yaml
kubectl get pods -o wide
kubectl get pod qos-guaranteed -o jsonpath='{.status.qosClass}'; echo

# 制造 Pending（超出租户配额 / 节点放不下）
kubectl run big --image=nginx:1.27 --requests=cpu=100
kubectl get pod big                # Pending
kubectl describe pod big | tail -5 # 0/1 nodes are available: Insufficient cpu
kubectl delete pod big

# taint / toleration
kubectl taint nodes lab-control-plane demo=true:NoSchedule
kubectl apply -f manifests/09-scheduling.yaml     # toleration 的 Pod 能上去
kubectl taint nodes lab-control-plane demo=true:NoSchedule-

# 制造 OOMKilled
kubectl run oom --image=busybox:1.36 --restart=Never --limits=memory=32Mi -- \
  sh -c 'dd if=/dev/zero of=/dev/null bs=1M count=2000 & sleep 3; head -c 200m /dev/zero | tail -c 1 > /dev/null; sleep 30'
kubectl describe pod oom | grep -iE 'oom|exit code'

# 配额
kubectl apply -f manifests/13-quota-limitrange.yaml
kubectl get resourcequota,limitrange -n team-a
```

### 自检问题

1. Pod `Pending` 的所有可能原因，按"资源/约束/存储/配额"四类各举一条。
2. `requests` 和 `limits` 对调度和运行时分别有什么影响？
3. `NoExecute` 和 `NoSchedule` 的区别？
4. 为什么 CPU 不会被 OOMKilled，而内存会？

### 常见坑

- 节点 `Allocatable` 比 `Capacity` 小（系统预留），按 Capacity 估算会放不下。
- 只写 `limits` 不写 `requests` → K8s 会把 requests 设成等于 limits（QoS 变 Guaranteed，可能浪费）。
- 反亲和的 `topologyKey` 写错，导致策略失效或全挤一个节点。
- HPA 目标 Deployment 没设 `requests` → HPA 算不出利用率，报 `<unknown>`。

---

## 阶段 8：可观测性与排障（3-4 天）

### 学习目标

形成自己的排障决策树，看到报错能 3 步内定位。

### 核心概念

1. **三件套**：`get`（现状）→ `describe`（Events/配置）→ `logs`（应用）。
2. **事件**：`kubectl get events --sort-by=.lastTimestamp`；默认只保留 1 小时。
3. **指标**：metrics-server 提供 `kubectl top`（HPA 也依赖它）。生产用 Prometheus + Grafana。
4. **日志**：容器日志在节点上（`/var/log/pods`）；`kubectl logs -f`、`--previous`、`--all-containers`、`--since`。
   - 日志架构三选一：节点 Agent（DaemonSet）/ Sidecar / 直接推远端。
5. **调试利器**
   - `kubectl debug`（临时容器）—— 镜像里没有 shell 也能救
   - `kubectl debug node/<node>` —— 起一个特权 Pod 挂宿主机根目录
   - `kubectl port-forward` / `kubectl cp` / `kubectl exec`
   - **k9s**：图形化看事件、日志、资源，效率倍增（`k9s` 直接敲）
6. **节点级排障**：`crictl ps/logs`、`journalctl -u kubelet`、`systemctl status containerd`（在 kind 节点容器里执行）。

### 动手实验

```bash
# 1) 安装 metrics-server
helm upgrade --install metrics-server metrics-server \
  --repo https://kubernetes-sigs.github.io/metrics-server \
  -n kube-system --set args={--kubelet-insecure-tls}
kubectl top nodes
kubectl top pods -A

# 2) 临时容器调试"无 shell 镜像"
kubectl run distroless --image=gcr.io/distroless/static-debian12
kubectl debug -it distroless --image=busybox:1.36 --target=distroless
#   在临时容器里可以看到目标容器的进程命名空间

# 3) 节点级调试
kubectl debug node/lab-control-plane -it --image=busybox:1.36
#   chroot /host  之后就是节点本身

# 4) 全链路排障演练（重点）
kubectl apply -f manifests/04-service.yaml
kubectl run curl --rm -it --image=curlimages/curl --restart=Never -- sh
#   依次验证：DNS → Service → Endpoints → Pod → 容器内端口
```

### 排障决策树（背下来）

| 现象                         | 第一步                               | 常见原因                                                     |
| ---------------------------- | ------------------------------------ | ------------------------------------------------------------ |
| `ImagePullBackOff`           | `describe pod` 看 Events             | 镜像名/标签错、私有仓库缺 imagePullSecret、**网络不通/加速失效** |
| `CrashLoopBackOff`           | `logs --previous`                    | 应用配置错、依赖服务连不上、探针太激进、命令写错             |
| `Pending`                    | `describe pod` 看 Events             | 资源不足、亲和性/污点不满足、PVC Pending、超配额             |
| `OOMKilled`                  | `describe pod` 看 Last State         | `limits` 太小、内存泄漏、JVM 堆未设上限                      |
| `Running` 但 Service 不通    | `get endpoints`                      | selector 不匹配、Pod 未 Ready、targetPort 错                 |
| `CreateContainerConfigError` | `describe pod`                       | 引用的 ConfigMap/Secret 不存在或 key 缺失                    |
| `Evicted`                    | `describe node` / `get events`       | 节点磁盘/内存压力，`kubelet` 驱逐                            |
| 无法访问 Ingress             | `describe ingress` + Controller 日志 | 没装 Controller、ingressClassName 错、后端 Service 名错      |

### 自检问题

1. `CrashLoopBackOff` 的排查步骤，完整说一遍。
2. 容器退出码 137 和 143 分别代表什么？
3. `kubectl logs` 说 `previous terminated container not found` 是什么意思？
4. 怎么判断是"应用问题"还是"集群问题"？

---

## 阶段 9：安全与多租户（3-4 天）

### 学习目标

理解认证/授权/准入三段式，能给团队划命名空间并做到最小权限。

### 核心概念

1. **请求三关**：`认证（Authentication）`→`授权（Authorization）`→`准入控制（Admission）`。
2. **ServiceAccount**：Pod 的身份。现代用法是 Token 投射（`automountServiceAccountToken: false` + projected volume），不再是永久 Secret。
3. **RBAC 四件套**：`Role`（命名空间级）/`ClusterRole`（集群级）/`RoleBinding`/`ClusterRoleBinding`。
   - 规则三要素：`apiGroups` + `resources` + `verbs`
   - 常用调试：`kubectl auth can-i get pods --as=system:serviceaccount:default:app-sa -n default`
4. **SecurityContext**
   - `runAsNonRoot: true`、`runAsUser`、`fsGroup`
   - `readOnlyRootFilesystem: true`（配合 emptyDir 挂 `/tmp`）
   - `allowPrivilegeEscalation: false`、`capabilities.drop: ["ALL"]`
   - `seccompProfile.type: RuntimeDefault`
5. **Pod Security Admission（PSA）**：命名空间标签 `pod-security.kubernetes.io/enforce: restricted|baseline|privileged`（1.25+ 替代 PSP）。
6. **网络隔离**：NetworkPolicy（本集群 kindnet 已支持并执行；需要 ipBlock 等更完整特性时再上 Calico/Cilium）
7. **供应链**：镜像扫描（Trivy）、镜像签名（cosign）、`imagePullPolicy: Always` + 固定 digest。
8. **审计**：API Server audit log（思路了解即可）。

### 动手实验

```bash
kubectl apply -f manifests/11-rbac.yaml
kubectl auth can-i list pods --as=system:serviceaccount:default:app-sa -n default   # yes
kubectl auth can-i delete pods --as=system:serviceaccount:default:app-sa -n default # no

# 体验 PSA
kubectl create ns secured
kubectl label ns secured pod-security.kubernetes.io/enforce=restricted
kubectl run bad --image=nginx:1.27 -n secured      # 被拒绝，报错说明原因
kubectl label ns secured pod-security.kubernetes.io/enforce=baseline
kubectl run bad --image=nginx:1.27 -n secured      # 这次能过

# 审计自己的权限
kubectl auth can-i --list
kubectl auth whoami
```

### 自检问题

1. `Role` 和 `ClusterRole` 的区别？`RoleBinding` 能绑定 `ClusterRole` 吗？
2. 为什么说 Secret 不等于安全？
3. PSA 的 `restricted` 会拒绝哪些写法？
4. `runAsNonRoot` 和镜像里实际以 root 运行的关系是什么？

---

## 阶段 10：包管理与交付（3-4 天）

### 学习目标

能把一套应用打包并在多环境可靠发布。

### 核心概念

1. **Helm**
   - 结构：`Chart.yaml` / `values.yaml` / `templates/` / `charts/`
   - 渲染顺序、`_helpers.tpl`、`{{ .Values }}`、`{{ .Release }}`、`include`/`template`、`required`、`toYaml`
   - 生命周期：`helm install/upgrade/rollback/uninstall`、`helm template`（只渲染，不部署 —— 调试神器）、`helm diff`（插件）
   - Release 状态存为集群 Secret（`sh.helm.release.v1.*`），改名/改命名空间不生效
   - Hooks：`pre-install`/`post-upgrade`/`test`
2. **Kustomize**（kubectl 内置）
   - `base` + `overlays`（`kustomization.yaml`）
   - `patchesStrategicMerge` / `patches`（JSON6902）/ `images` / `namePrefix` / `configMapGenerator`
   - `kubectl apply -k overlays/prod`
3. **Helm vs Kustomize**：Helm 适合分发（参数化模板），Kustomize 适合内部多环境（纯 YAML 叠加）。实践中常混用。
4. **GitOps**：ArgoCD / Flux —— Git 是唯一事实源，集群自动向 Git 收敛。核心概念：Sync / Drift / Health。
5. **镜像交付**
   - `docker buildx build --platform linux/arm64`（本机就是 arm64，直接用 `docker build` 也行）
   - kind 加载本地镜像：`kind load docker-image my/app:v1 --name lab`（不会走网络）
   - CI 思路：lint → build → scan → push → 部署

### 动手实验

```bash
# 1) 自己写一个 chart
helm create myapp
helm template myapp | less                 # 渲染结果先看
helm install myapp ./myapp -n demo --create-namespace --dry-run
helm install myapp ./myapp -n demo --create-namespace
helm list -A
helm upgrade myapp ./myapp -n demo --set replicaCount=3
helm rollback myapp 1 -n demo
helm uninstall myapp -n demo

# 2) 用 Kustomize 管多环境
kubectl apply -k kustomize/overlays/dev      # （需按项目二自行创建）

# 3) 本地镜像进集群
docker build -t my/app:v1 .
kind load docker-image my/app:v1 --name lab
kubectl run my-app --image=my/app:v1 --imagePullPolicy=Never

# 4) 安装真实中间件练手
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install redis bitnami/redis --set architecture=standalone
```

### 自检问题

1. `helm upgrade` 失败了，集群里现在是什么状态？怎么回滚？
2. `helm template` 和 `helm install --dry-run` 的区别？
3. 为什么 `imagePullPolicy: Never` 配合 `kind load` 能工作？
4. GitOps 相比"本地跑 kubectl apply"解决了什么问题？

---

## 阶段 11：进阶与生产化（持续）

### 学习目标

从"会用"走向"懂原理、能运维"。

### 主题清单

1. **CRD 与 Operator**
   - CRD 给集群加新 kind；Controller 用控制循环实现它
   - 工具：`kubebuilder` / `operator-sdk`；核心库 `controller-runtime`
   - 实操：安装一个现成 Operator（如 cert-manager），观察它创建的 CR
2. **深入 API 机制**
   - `client-go` 的 informer / workqueue 模式
   - Admission Webhook（validating / mutating）、Aggregation Layer
   - Finalizer 与级联删除
3. **调度器扩展**：Scheduler Framework 插件、多调度器
4. **集群运维**
   - etcd 备份与恢复（`etcdctl snapshot save/restore`）
   - 证书轮换（`kubeadm certs renew`）
   - 版本升级（`kubeadm upgrade plan/apply`）
   - 高可用控制面（多 master + LB）
   - 节点维护：`kubectl drain/cordon/uncordon` + PDB
5. **Gateway API**：Ingress 的继任者（HTTPRoute/GRPCRoute）
6. **服务网格**：Istio/Linkerd 的 mTLS、流量切分、可观测性
7. **多集群**：Cluster API、Karmada、GitOps 多集群
8. **成本与性能**：requests 优化、VPA 建议、bin-packing、节点池

### 动手实验（选做）

```bash
# cert-manager（体验 Operator 模式）
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager -n cert-manager --create-namespace \
  --set crds.enabled=true
kubectl get crd | grep cert-manager
kubectl get pods -n cert-manager

# 节点维护演练
kubectl apply -f manifests/03-deployment-rollout.yaml
kubectl drain lab-control-plane --ignore-daemonsets --delete-emptydir-data
kubectl get pods -o wide
kubectl uncordon lab-control-plane
```

---

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

---

## 附录 A：kind 速查

```bash
# 集群生命周期
kind create cluster --name lab --config kind/kind-single.yaml
kind create cluster --name multi --config kind/kind-multinode.yaml
kind get clusters
kind delete cluster --name lab
kind export kubeconfig --name lab          # 导出 kubeconfig
kind get kubeconfig --name lab > /tmp/lab.kubeconfig

# 节点（本质是 docker 容器）
docker ps --filter name=lab-
docker exec -it lab-control-plane bash
docker exec lab-control-plane crictl ps
docker exec lab-control-plane crictl logs <container-id>
docker logs lab-control-plane 2>&1 | tail -50     # 节点启动/异常日志

# 镜像
kind load docker-image my/app:v1 --name lab        # 本地镜像进集群
kind load image-archive images.tar --name lab

# 端口
kubectl port-forward svc/web-svc 8080:80
kubectl port-forward pod/web-xxx 8080:80

# 多集群上下文
kubectl config get-contexts
kubectx kind-lab          # 切换
kubens default            # 切换命名空间
```

## 附录 B：kubectl 速查（高频）

```bash
# 查
kubectl get all -n <ns>
kubectl get pods -A -o wide --sort-by=.metadata.creationTimestamp
kubectl get events -A --sort-by=.lastTimestamp | tail -30
kubectl describe pod <pod>
kubectl logs <pod> -c <container> --previous --tail=100
kubectl explain <resource>.<field> --recursive

# 改
kubectl apply -f x.yaml
kubectl edit deploy/web
kubectl patch deploy/web -p '{"spec":{"replicas":5}}'
kubectl scale deploy/web --replicas=5
kubectl set image deploy/web web=nginx:1.26
kubectl rollout restart deploy/web

# 删
kubectl delete -f x.yaml
kubectl delete pod <pod> --grace-period=0 --force   # 慎用
kubectl delete all --all -n <ns>

# 临时
kubectl run tmp --rm -it --image=busybox:1.36 --restart=Never -- sh
kubectl run tmp --rm -it --image=curlimages/curl --restart=Never -- sh
kubectl debug -it <pod> --image=busybox:1.36 --target=<container>
kubectl debug node/<node> -it --image=busybox:1.36

# 权限/诊断
kubectl auth can-i --list
kubectl auth whoami
kubectl cluster-info dump | less
kubectl api-resources --verbs=list --namespaced -o name | xargs -n1 kubectl get --show-kind --ignore-not-found -n <ns>
```

## 附录 C：本机环境特别事项

| 事项                | 说明                                                         |
| ------------------- | ------------------------------------------------------------ |
| Docker Hub 直连不通 | 已配 registry 加速；YAML 里用官方镜像名即可                  |
| GitHub 主站不通     | 装工具时可能需要走 `api.github.com` 下载 release 资产        |
| colima 资源调整     | `colima stop && colima start --cpu 6 --memory 10`（内存可改，`arch`/`vmType`/`disk` 创建后不可改，`disk` 只能增） |
| colima 进虚拟机     | `colima ssh`（进去后可 `sudo`，宿主机不需要 sudo）           |
| 虚拟机镜像          | `~/Library/Caches/colima-images/` 保留着官方 qcow/raw 镜像，删掉后重建集群需要重新下载 |
| 端口访问            | 已把节点 80/443 映射到 Mac 的 8080/8443；NodePort 需用 `kubectl port-forward` |
| 性能建议            | 首次拉镜像慢属正常；`colima start` 后不要立刻 `kind create`，等 `docker info` 稳定 |
| 磁盘占用            | 镜像在虚拟机里，`colima delete` 才会真正释放；查看 `colima list` |

## 附录 D：推荐学习资源

| 类型       | 推荐                                                         |
| ---------- | ------------------------------------------------------------ |
| 官方文档   | kubernetes.io/docs（`kubectl explain` 是第一手文档）         |
| 交互式教程 | Killercoda、KodeKloud 免费实验                               |
| 视频       | 《Kubernetes 基础》系列、CNCF 官方频道                       |
| 深度书籍   | 《Kubernetes 权威指南》《Kubernetes in Action》《Production Kubernetes》 |
| 源码/Spec  | kubernetes/kubernetes、KEP、API 参考                         |
| 社区       | CNCF Slack、Kubernetes 中文社区、r/kubernetes                |
| 认证路径   | CKA（管理员）→ CKAD（开发者）→ CKS（安全）；kind 环境足以覆盖 CKA 80% 的实验 |
| 排错练习   | 在 kind 里主动注入故障，比看教程有效 10 倍                   |

---

## 最后的建议

1. **不要先读完整本书再动手**。每学一个概念，就在 `k8s-lab/manifests/` 里加一个 YAML，apply 一遍，`describe` 一遍。
2. **养成看 Events 的习惯**。90% 的问题答案在 `kubectl describe` 的 Events 里。
3. **主动制造故障**。把 Pod 弄挂、把 selector 改错、把 limits 调小 —— 排障能力是 K8s 分水岭。
4. **画图**。每学完一个阶段，画出"请求从外部到容器"的完整链路（含 DNS、Service、iptables、Pod）。
5. **用 k9s**。它能让你"看见"集群，学习效率翻倍：终端直接敲 `k9s`。