### 

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

### 自检问题

1. 敲下 `kubectl apply -f deploy.yaml` 后，到 Pod 真正运行，中间经过哪些组件？按顺序说出来。
2. `kubectl get pods` 的数据从哪里来的？为什么它可能比现实"慢半拍"？
3. 为什么说 etcd 挂了集群就"失忆"了，但已有的 Pod 还在跑？

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

### 自检问题

1. readiness 探针失败为什么**不**重启容器？如果它一直失败会发生什么？
2. `initialDelaySeconds` 设太大 / 太小分别有什么风险？
3. Pod 删除时，为什么流量不会立刻断？（提示：Endpoints 摘除 + preStop + 优雅期）
4. 两个容器在同一 Pod 里都想监听 8080 端口，可以吗？为什么？

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

### 自检问题

1. `maxUnavailable: 0` + `maxSurge: 1` 的效果是什么？适合什么场景？
2. Deployment 和 StatefulSet 的本质区别有哪些（至少 3 条）？
3. `rollout undo` 回滚后，`revisionHistory` 里发生了什么？
4. CronJob 的 `concurrencyPolicy: Forbid` 解决什么问题？

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

### 自检问题

1. Service 的 ClusterIP 是 ping 得通的吗？为什么？（提示：它是 iptables 规则，不是真实接口）
2. `kubectl get endpoints` 为空，列出至少 4 种可能原因。
3. NodePort 和 LoadBalancer 的区别？LoadBalancer 在没有云的环境怎么实现？
4. 为什么 StatefulSet 必须配 Headless Service？

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

### 自检问题

1. 为什么 ConfigMap 改了，用 `envFrom` 注入的环境变量不会变？怎么让它生效？
2. `subPath` 挂载的 ConfigMap 为什么不会热更新？
3. Secret 和 ConfigMap 在实现上有本质区别吗？

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

### 自检问题

1. PVC 一直 `Pending`，列出可能原因（至少 4 条）。
2. 删掉 PVC 后 PV 会怎样？取决于哪个字段？
3. 为什么 `hostPath` 不适合生产？它在 kind 里为什么能用？
4. `emptyDir` 在容器崩溃和 Pod 删除时分别会怎样？

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

### 自检问题

1. Pod `Pending` 的所有可能原因，按"资源/约束/存储/配额"四类各举一条。
2. `requests` 和 `limits` 对调度和运行时分别有什么影响？
3. `NoExecute` 和 `NoSchedule` 的区别？
4. 为什么 CPU 不会被 OOMKilled，而内存会？

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
