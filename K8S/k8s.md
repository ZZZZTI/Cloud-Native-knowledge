> Kubernetes（K8s）是一个开源的容器编排平台，用于自动化部署、扩缩容和管理容器化应用，保障其高可用与弹性运行。

------

## 目录

- [架构](#架构)
- [核心概念](#核心概念)
- [集群安装与升级（kubeadm）](#集群安装与升级kubeadm)
- [工作负载](#工作负载)
- [配置与密钥](#配置与密钥)
- [存储](#存储)
- [网络](#网络)
- [调度](#调度)
- [安全](#安全)
- [可观测性与日志](#可观测性与日志)
- [日常运维操作](#日常运维操作)
- [etcd 备份与恢复](#etcd-备份与恢复)
- [故障排查](#故障排查)
- [生产实践清单](#生产实践清单)
- [kubectl 命令速查](#kubectl-命令速查)
- [CKA 考纲映射](#cka-考纲映射)

------

## 架构

### 整体架构图

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Control Plane（Master Node）                         │
│  ┌────────────────┐ ┌────────────────┐ ┌─────────────────┐ ┌─────────────┐  │
│  │ kube-apiserver │ │ kube-scheduler │ │kube-controller- │ │    etcd     │  │
│  │                │ │                │ │     manager     │ │ (键值存储)  │  │
│  │  集群统一入口  │ │    Pod 调度    │ │ 控制器循环/自愈 │ │存储集群状态 │  │
│  └────────────────┘ └────────────────┘ └─────────────────┘ └─────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       │ API 调用（HTTPS :6443）
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                 Worker Node                                 │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────────────────────────┐  │
│  │   kubelet    │ │  kube-proxy  │ │Container Runtime（containerd/CRI-O）│  │
│  │   节点代理   │ │   网络规则   │ │      CRI 接口，真正负责跑容器       │  │
│  └──────────────┘ └──────────────┘ └─────────────────────────────────────┘  │
│                                                                             │
│  ┌─────────────────────────────────┐   ┌─────────────────────────────────┐  │
│  │              Pod A              │   │              Pod B              │  │
│  │  ┌────────────┐ ┌────────────┐  │   │  ┌────────────┐ ┌────────────┐  │  │
│  │  │ Container1 │ │ Container2 │  │   │  │ Container1 │ │ Container2 │  │  │
│  │  └────────────┘ └────────────┘  │   │  └────────────┘ └────────────┘  │  │
│  │     共享 Network Namespace      │   │     共享 Network Namespace      │  │
│  │           共享 Volume           │   │           共享 Volume           │  │
│  └─────────────────────────────────┘   └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 控制平面组件

| 组件 | 职责 | 关键点 |
| :-- | :-- | :-- |
| `kube-apiserver` | 集群唯一入口，所有操作的 REST 网关，负责认证/授权/准入控制 | 无状态，可多实例；静态 Pod 运行在 `/etc/kubernetes/manifests/` |
| `etcd` | 保存集群全部状态（唯一持久化数据源） | 必须定期备份；奇数节点（3/5）；2379 客户端端口、2380 对等端口 |
| `kube-scheduler` | 为新 Pod 选择节点 | 两阶段：Filter（过滤）→ Score（打分） |
| `kube-controller-manager` | 运行各类控制器，持续把「期望状态」调和成「实际状态」 | 包含 Deployment/ReplicaSet/Node/Job/Endpoint 等几十个控制器 |
| `cloud-controller-manager` | 对接云厂商 API（LB、节点、路由） | 自建集群可不用 |

### 节点组件

| 组件 | 职责 | 关键点 |
| :-- | :-- | :-- |
| `kubelet` | 节点代理，管理 Pod 生命周期、上报状态、执行探针 | 监听 10250；日志 `journalctl -u kubelet` |
| `kube-proxy` | 实现 Service 的负载均衡与转发规则 | iptables / ipvs / nftables 模式 |
| Container Runtime | 真正创建和运行容器 | 通过 CRI 接口被 kubelet 调用；常用 containerd |

### 集群插件（Addons）

| 插件 | 作用 |
| :-- | :-- |
| CoreDNS | 集群内 DNS 服务发现 |
| CNI（Calico / Cilium / Flannel） | Pod 网络；**只有 Calico/Cilium/Antrea 等支持 NetworkPolicy，Flannel 不支持** |
| Ingress Controller（ingress-nginx / Traefik） | 七层入口 |
| metrics-server | 提供 `kubectl top` 与 HPA 的资源指标 |
| Dashboard | Web UI（生产慎用） |

### 设计哲学

- **声明式 API**：用户提交「期望状态」（YAML），而不是「执行步骤」。
- **控制器循环（Reconcile Loop）**：`观察实际状态 → 与期望状态比较 → 采取动作缩小差异`，永不停止。
- **一切皆对象**：所有资源都通过 apiserver 读写 etcd，没有带外状态。
- **松耦合**：组件之间只通过 apiserver 通信，不直接互相调用。

------

## 核心概念

| 概念 | 说明 |
| :-- | :-- |
| Pod | 最小调度单元，一个或多个共享 Network/Volume 的容器 |
| ReplicaSet | 保证指定数量的 Pod 副本（一般由 Deployment 托管，不直接用） |
| Deployment | 无状态工作负载，支持滚动更新与回滚 |
| StatefulSet | 有状态工作负载，Pod 有稳定序号、网络标识和独立存储 |
| DaemonSet | 每个（或指定）节点运行一个 Pod，用于日志/监控/网络插件 |
| Job / CronJob | 一次性任务 / 定时任务 |
| Service | 为一组 Pod 提供稳定 VIP 与负载均衡 |
| Ingress | 七层 HTTP/HTTPS 路由 |
| ConfigMap / Secret | 配置与敏感信息注入 |
| Volume / PV / PVC | 存储抽象 |
| Namespace | 逻辑隔离与资源配额边界 |
| Label / Selector | 松耦合的关联机制，Service/Deployment 都靠它找 Pod |
| Annotation | 非标识性元数据，供工具使用 |
| ServiceAccount | Pod 访问 apiserver 的身份 |
| RBAC 四件套 | Role / ClusterRole / RoleBinding / ClusterRoleBinding |

**期望状态 vs 实际状态**：`kubectl get` 看到的是 etcd 里的期望状态，`kubectl describe` 里的 Events 与容器状态才是实际状态。排障就是找这两者的差异。

------

## 集群安装与升级（kubeadm）

### 前置条件（所有节点）

```bash
# 1. 关闭 swap（kubelet 默认不接受 swap）
swapoff -a
sed -ri 's/.*swap.*/#&/' /etc/fstab

# 2. 加载内核模块
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay && modprobe br_netfilter

# 3. 内核参数：网桥转发 + iptables 看到桥接流量
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# 4. 时间同步
timedatectl set-timezone Asia/Shanghai
systemctl enable --now chronyd
```

### 安装容器运行时（containerd）

```bash
# containerd 必须使用 systemd cgroup 驱动，否则与 kubelet 冲突
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
# 国内环境配置 sandbox 镜像
sed -i 's#registry.k8s.io/pause#registry.aliyuncs.com/google_containers/pause#' /etc/containerd/config.toml
systemctl restart containerd
```

### 安装 kubelet / kubeadm / kubectl

```bash
# 配置国内 yum/dnf 源
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes-new/core/stable/v1.30/rpm/repodata/repomd.xml.key
EOF

dnf install -y kubelet kubeadm kubectl
systemctl enable --now kubelet   # 此时会不断重启，属正常，等 init 后就好
```

### 初始化控制平面

```bash
kubeadm init \
  --apiserver-advertise-address=192.168.1.10 \
  --control-plane-endpoint=cluster-endpoint:6443 \
  --pod-network-cidr=10.244.0.0/16 \
  --image-repository=registry.aliyuncs.com/google_containers \
  --kubernetes-version=v1.30.0 \
  --upload-certs

# 配置 kubectl
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# 安装 CNI（示例：Calico）
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

# 单节点测试时去掉控制平面的污点
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
```

### 工作节点加入

```bash
# 在 master 上生成加入命令（token 默认 24 小时过期）
kubeadm token create --print-join-command

# 在 worker 上执行
kubeadm join cluster-endpoint:6443 --token xxxxxx.xxxxxxxxxxxxxxxx \
  --discovery-token-ca-cert-hash sha256:xxxxxxxxxxxx
```

### 高可用拓扑

| 拓扑 | 说明 | 优点 | 缺点 |
| :-- | :-- | :-- | :-- |
| Stacked etcd | etcd 与控制平面同机 | 部署简单、节点少 | 一台挂了同时损失一个 etcd 成员 |
| External etcd | etcd 独立集群 | 故障域隔离、更稳 | 机器需求翻倍、运维复杂 |

控制平面前面需要一个 **VIP + 负载均衡**（keepalived + haproxy / 云 SLB），`--control-plane-endpoint` 指向它。新控制平面加入用 `kubeadm join ... --control-plane --certificate-key <key>`（key 由 `kubeadm init --upload-certs` 生成，2 小时过期）。

**注意**：生产必须 ≥3 个控制平面（etcd 需要多数派），2 个节点反而不如 1 个稳。

### 证书管理

```bash
# 查看所有证书有效期（默认 CA 10 年，其余叶子证书 1 年）
kubeadm certs check-expiration

# 续期（升级时 kubeadm 会自动续，平时可手动）
kubeadm certs renew all
systemctl restart kubelet
# 续期后记得更新 kubeconfig
cp /etc/kubernetes/admin.conf $HOME/.kube/config
```

### 升级流程（大版本一次只跨一个小版本）

```bash
# ---- 第一个控制平面节点 ----
kubectl drain <node> --ignore-daemonsets            # 1. 驱逐
dnf install -y kubeadm-1.30.x-0 --disableexcludes=kubernetes   # 2. 升级 kubeadm
kubeadm upgrade plan                                 # 3. 查看可升级版本
kubeadm upgrade apply v1.30.x                        # 4. 升级控制平面
dnf install -y kubelet-1.30.x-0 kubectl-1.30.x-0 --disableexcludes=kubernetes
systemctl daemon-reload && systemctl restart kubelet
kubectl uncordon <node>                              # 5. 恢复调度

# ---- 其他控制平面节点 ----
kubeadm upgrade node        # 注意：不是 upgrade apply

# ---- 工作节点 ----
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
dnf install -y kubeadm-1.30.x-0 kubelet-1.30.x-0 --disableexcludes=kubernetes
kubeadm upgrade node
systemctl daemon-reload && systemctl restart kubelet
kubectl uncordon <node>
```

**升级前必做**：读 Release Notes 的 Deprecated/Removed API 列表，用 `pluto` / `kubent` 扫描集群里已废弃的 API 版本；备份 etcd。

------

## 工作负载

### Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  restartPolicy: Always            # Always / OnFailure / Never
  terminationGracePeriodSeconds: 30
  serviceAccountName: web-sa
  securityContext:                 # Pod 级安全上下文
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
    seccompProfile:
      type: RuntimeDefault
  initContainers:                  # 串行执行，全部成功主容器才启动
    - name: init-db
      image: busybox:1.36
      command: ['sh', '-c', 'until nc -z db 3306; do sleep 2; done']
  containers:
    - name: app
      image: registry.example.com/web:1.2.3      # 禁用 latest
      imagePullPolicy: IfNotPresent              # Always / IfNotPresent / Never
      command: ["/app/server"]                   # 覆盖 ENTRYPOINT
      args: ["--port=8080"]                      # 覆盖 CMD
      ports:
        - name: http
          containerPort: 8080
      env:
        - name: DB_HOST
          value: "mysql.default.svc.cluster.local"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
      envFrom:
        - configMapRef:
            name: app-config
      resources:                                 # 生产必须设
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 512Mi
      startupProbe:                              # 启动慢的应用先设这个，避免被 liveness 误杀
        httpGet: { path: /healthz, port: http }
        failureThreshold: 30
        periodSeconds: 10
      livenessProbe:                             # 失败 → 重启容器
        httpGet: { path: /healthz, port: http }
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 3
        failureThreshold: 3
      readinessProbe:                            # 失败 → 摘出 Service 端点（不重启）
        httpGet: { path: /ready, port: http }
        periodSeconds: 5
      lifecycle:
        preStop:
          exec:
            command: ["sh", "-c", "sleep 5"]     # 配合优雅退出，等 kube-proxy 摘除
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
      volumeMounts:
        - name: config
          mountPath: /etc/app
          readOnly: true
        - name: cache
          mountPath: /tmp
  volumes:
    - name: config
      configMap: { name: app-config }
    - name: cache
      emptyDir: {}
```

**Pod 生命周期**：`Pending` → `Running` → `Succeeded` / `Failed`；异常时 `Unknown`（通常节点失联）。

**三种探针的分工**：

| 探针 | 失败后果 | 用途 |
| :-- | :-- | :-- |
| `startupProbe` | 重启容器 | 保护启动慢的应用，成功后 liveness 才开始计时 |
| `livenessProbe` | **重启容器** | 检测死锁/假死 |
| `readinessProbe` | 从 Service 端点摘除，**不重启** | 检测能否对外服务 |

**QoS 等级**（决定节点资源紧张时谁先被杀）：

| QoS | 条件 | 被驱逐优先级 |
| :-- | :-- | :-- |
| `Guaranteed` | 所有容器都设了 requests 且等于 limits（CPU 和内存都要） | 最低 |
| `Burstable` | 至少一个容器设了 requests 或 limits，但不满足 Guaranteed | 中 |
| `BestEffort` | 所有容器都没设 requests/limits | 最高（最先被杀） |

**静态 Pod**：由 kubelet 直接管理，放在 `/etc/kubernetes/manifests/`，不受 apiserver 控制（控制平面组件就是这么跑的）。`kubectl get pod` 能看到但删不掉。

### Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  revisionHistoryLimit: 10
  minReadySeconds: 10
  progressDeadlineSeconds: 600
  strategy:
    type: RollingUpdate                # 或 Recreate
    rollingUpdate:
      maxSurge: 25%                    # 最多超出期望副本数
      maxUnavailable: 0                # 生产建议 0，保证容量不掉
  selector:
    matchLabels: { app: web }          # 一经创建不可变
  template:
    metadata:
      labels: { app: web }
    spec:
      affinity:
        podAntiAffinity:               # 副本打散到不同节点
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                topologyKey: kubernetes.io/hostname
                labelSelector:
                  matchLabels: { app: web }
      containers:
        - name: app
          image: registry.example.com/web:1.2.3
```

```bash
kubectl rollout status deployment/web          # 等待滚动完成
kubectl rollout history deployment/web         # 查看历史版本
kubectl rollout undo deployment/web            # 回滚到上一版
kubectl rollout undo deployment/web --to-revision=2
kubectl rollout restart deployment/web         # 滚动重启（不改镜像，重新拉 Pod）
kubectl rollout pause/resume deployment/web    # 暂停/恢复
kubectl set image deployment/web app=web:1.2.4 # 触发一次更新
kubectl scale deployment/web --replicas=5
```

### StatefulSet

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql-headless        # 必须指向 Headless Service
  replicas: 3
  podManagementPolicy: OrderedReady  # 默认按序；Parallel 可并行
  selector:
    matchLabels: { app: mysql }
  template:
    metadata:
      labels: { app: mysql }
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          volumeMounts:
            - name: data
              mountPath: /var/lib/mysql
  volumeClaimTemplates:              # 每个 Pod 自动生成独立 PVC
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: fast-ssd
        resources:
          requests:
            storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
spec:
  clusterIP: None                    # Headless Service
  selector: { app: mysql }
  ports:
    - port: 3306
```

- Pod 名称固定为 `<sts>-0/1/2`，删除后会以同名重建并挂回原 PVC。
- DNS：`mysql-0.mysql-headless.default.svc.cluster.local`。
- 扩缩容按序号从大到小缩，缩容**不会删除 PVC**（要手动清）。

### DaemonSet / Job / CronJob

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata: { name: node-exporter }
spec:
  selector:
    matchLabels: { app: node-exporter }
  template:
    metadata:
      labels: { app: node-exporter }
    spec:
      tolerations:                    # 关键：容忍控制平面污点，否则不落在 master
        - operator: Exists
      hostNetwork: true
      hostPID: true
      containers:
        - name: node-exporter
          image: prom/node-exporter:v1.8.0
          ports: [{ containerPort: 9100 }]
---
apiVersion: batch/v1
kind: Job
metadata: { name: db-migrate }
spec:
  completions: 1
  parallelism: 1
  backoffLimit: 6                  # 失败重试次数
  activeDeadlineSeconds: 600       # 整个 Job 超时
  ttlSecondsAfterFinished: 3600    # 完成后 1 小时自动清理
  template:
    spec:
      restartPolicy: OnFailure     # Job 只能是 OnFailure / Never
      containers:
        - name: migrate
          image: registry.example.com/migrate:1.0
---
apiVersion: batch/v1
kind: CronJob
metadata: { name: backup }
spec:
  schedule: "0 3 * * *"                    # 分 时 日 月 周
  timeZone: "Asia/Shanghai"                # 1.27+ 支持
  concurrencyPolicy: Forbid                # Allow / Forbid / Replace
  startingDeadlineSeconds: 300
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 1
  suspend: false
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: backup
              image: registry.example.com/backup:1.0
```

### HPA / PDB

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: web }
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: { type: Utilization, averageUtilization: 70 }
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300     # 避免抖动
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata: { name: web-pdb }
spec:
  minAvailable: 2                       # 或 maxUnavailable: 1
  selector:
    matchLabels: { app: web }
```

HPA 依赖 metrics-server；`kubectl get hpa` 显示 `<unknown>` 就是 metrics 拿不到。

------

## 配置与密钥

### ConfigMap

```bash
kubectl create configmap app-config \
  --from-literal=LOG_LEVEL=info \
  --from-file=application.yaml \
  --from-env-file=.env
kubectl get configmap app-config -o yaml
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata: { name: app-config }
immutable: false            # true 则不可修改，性能更好、防止误改
data:
  LOG_LEVEL: "info"
  application.yaml: |
    server:
      port: 8080
```

三种注入方式：

| 方式 | 是否自动更新 | 说明 |
| :-- | :-- | :-- |
| `env` / `envFrom` | ❌ 不更新 | 必须重启 Pod 才生效 |
| `volumeMounts`（整目录） | ✅ 会更新 | 延迟 ≈ kubelet 同步周期 + 缓存 TTL（默认各 1 分钟） |
| `volumeMounts` + `subPath` | ❌ 不更新 | 常见坑：用 subPath 挂单个文件就失去了热更新 |

### Secret

```bash
kubectl create secret generic db-secret \
  --from-literal=password='S3cr3t!' \
  --from-literal=username=app

kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=robot \
  --docker-password='xxx' \
  --docker-email=ops@example.com

kubectl create secret tls web-tls --cert=tls.crt --key=tls.key
```

| 类型 | 用途 |
| :-- | :-- |
| `Opaque` | 通用键值（默认） |
| `kubernetes.io/dockerconfigjson` | 私有镜像仓库凭据，配 `imagePullSecrets` |
| `kubernetes.io/tls` | Ingress 证书 |
| `kubernetes.io/service-account-token` | SA 令牌 |
| `kubernetes.io/basic-auth` / `ssh-auth` | 基础认证 / SSH |

**关键认知**：

- Secret 只是 **base64 编码，不是加密**。有 etcd 读权限或 `get secret` 权限的人都能还原明文。
- 生产必须开启 **静态加密**：apiserver 加 `--encryption-provider-config`，provider 可选 `aescbc` / `aesgcm` / `secretbox` / `kms`（KMS 最安全，密钥在外部）。
- 更彻底的做法是外部密钥管理：Sealed Secrets / External Secrets Operator / Vault + CSI Driver。
- 用 `stringData` 可以直接写明文，apiserver 会帮忙编码（写入后 `data` 里是 base64）。

### Downward API

把 Pod 自身的元数据注入容器，无需调用 apiserver：

```yaml
env:
  - name: POD_NAME
    valueFrom: { fieldRef: { fieldPath: metadata.name } }
  - name: NODE_NAME
    valueFrom: { fieldRef: { fieldPath: spec.nodeName } }
  - name: CPU_LIMIT
    valueFrom: { resourceFieldRef: { containerName: app, resource: limits.cpu } }
```

------

## 存储

### Volume 类型

| 类型 | 生命周期 | 典型用途 |
| :-- | :-- | :-- |
| `emptyDir` | 随 Pod 销毁 | 临时缓存、多容器共享目录 |
| `hostPath` | 绑定节点目录 | **危险**，Pod 漂移后数据不跟随；仅用于 DaemonSet 类 |
| `configMap` / `secret` | 随 Pod | 配置文件注入 |
| `downwardAPI` | 随 Pod | 元数据注入 |
| `projected` | 随 Pod | 把多个来源合成一个目录（SA token + configmap + secret） |
| `persistentVolumeClaim` | 独立于 Pod | 生产持久化数据的唯一正确选择 |
| `csi` | 由驱动决定 | 云盘/NFS/对象存储，现代存储接入方式 |

### PV / PVC / StorageClass

```yaml
# StorageClass：定义「用哪种存储、怎么供应」
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata: { name: fast-ssd }
provisioner: ebs.csi.aws.com
parameters: { type: gp3 }
reclaimPolicy: Delete                    # Retain 保留数据（生产重要数据选它）
allowVolumeExpansion: true               # 允许在线扩容 PVC
volumeBindingMode: WaitForFirstConsumer  # 等 Pod 调度后再创建卷（多可用区必须）
---
# PVC：用户的存储申请
apiVersion: v1
kind: PVC
metadata: { name: data }
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: fast-ssd
  resources:
    requests: { storage: 20Gi }
```

**绑定流程**：

- 静态供应：管理员先建 PV → PVC 按 `capacity` + `accessModes` + `storageClassName` 匹配 → 绑定。
- 动态供应：StorageClass 里有 provisioner → 创建 PVC 时自动生成 PV。
- PVC 处于 `Pending` 一般是：没有匹配的 PV / StorageClass 不存在 / `WaitForFirstConsumer` 但还没有 Pod 用它。

**Access Modes**：

| 模式 | 缩写 | 说明 |
| :-- | :-- | :-- |
| ReadWriteOnce | RWO | 单节点读写（云盘基本都是这个，**不是单 Pod**） |
| ReadOnlyMany | ROX | 多节点只读 |
| ReadWriteMany | RWX | 多节点读写（需要 NFS/CephFS 等共享存储） |
| ReadWriteOncePod | RWOP | 单 Pod 读写（1.22+，最严格） |

**Reclaim Policy**：`Delete`（默认动态供应）删 PVC 就删数据；`Retain` 保留卷需手动清理。**生产重要数据务必确认是 Retain**。

```bash
kubectl get pv,pvc -A
kubectl describe pvc data
kubectl get storageclass
# 扩容（需 StorageClass 允许）
kubectl patch pvc data -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

------

## 网络

### Pod 网络模型

三条铁律：

1. 每个 Pod 有独立 IP，所有 Pod 之间可直连（无 NAT）。
2. 所有节点与 Pod 之间可直连（无 NAT）。
3. Pod 看到的自己的 IP 和别人看到的一样。

由 **CNI 插件**负责实现，跨节点 Pod 通信方案分 Overlay（VXLAN/IPIP，如 Flannel）和 Underlay/BGP（如 Calico BGP 模式）。

### Service

```yaml
apiVersion: v1
kind: Service
metadata: { name: web }
spec:
  type: ClusterIP              # ClusterIP / NodePort / LoadBalancer / ExternalName
  selector: { app: web }       # 靠这个选 Pod，写错就 0 端点
  ports:
    - name: http
      port: 80                 # Service 端口
      targetPort: http         # 容器端口（名字或数字）
      protocol: TCP
      nodePort: 30080          # NodePort 类型可指定，范围 30000-32767
  sessionAffinity: None        # 或 ClientIP
  externalTrafficPolicy: Local # LoadBalancer/NodePort：Local 保留源 IP
```

| 类型 | 访问范围 | 说明 |
| :-- | :-- | :-- |
| `ClusterIP` | 集群内 | 默认，虚拟 IP |
| `NodePort` | 集群外（节点 IP + 端口） | 在 ClusterIP 基础上每节点开一个端口 |
| `LoadBalancer` | 集群外（云 LB） | 依赖 cloud-controller-manager 或 MetalLB |
| `ExternalName` | — | 只做 DNS CNAME，无代理 |
| Headless（`clusterIP: None`） | 集群内 | DNS 直接返回 Pod IP 列表，StatefulSet 依赖它 |

**kube-proxy 模式**：

| 模式 | 特点 |
| :-- | :-- |
| `iptables` | 默认，规则多时线性增长、性能下降 |
| `ipvs` | 哈希表查找，大规模集群性能更好，支持多种调度算法 |
| `nftables` | 较新（1.31+ beta），替代 iptables |

### EndpointSlice

Service 的 `selector` 匹配到的 Pod IP 集合会被记录为 EndpointSlice（旧版是 Endpoints 对象，现已弃用）。

```bash
kubectl get endpointslices -l kubernetes.io/service-name=web
```

**Service 不通的第一件事**：看 Endpoints 是不是空的——空说明 `selector` 没匹配上 Pod，或 Pod 没 Ready（readinessProbe 失败也会摘除）。

### Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
spec:
  ingressClassName: nginx
  tls:
    - hosts: [app.example.com]
      secretName: web-tls
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix        # Prefix / Exact / ImplementationSpecific
            backend:
              service:
                name: web
                port: { number: 80 }
```

Ingress 只是**路由规则**，必须有一个 Ingress Controller（ingress-nginx / Traefik / HAProxy）在跑才会生效——这是新手最常见的误区。Gateway API 是 Ingress 的下一代替代，表达力更强。

### NetworkPolicy

Pod 防火墙，**默认全通**，一旦某 Pod 被任何 NetworkPolicy 选中，就变成「只有明确允许的才通」。

```yaml
# 1) 命名空间默认拒绝所有入站和出站
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-all }
spec:
  podSelector: {}                # 空 = 选中本命名空间所有 Pod
  policyTypes: [Ingress, Egress]
---
# 2) 只放行指定流量
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: web-allow }
spec:
  podSelector:
    matchLabels: { app: web }
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels: { kubernetes.io/metadata.name: ingress-nginx }
        - podSelector:
            matchLabels: { app: frontend }
      ports:
        - { protocol: TCP, port: 8080 }
  egress:
    - to:
        - podSelector:
            matchLabels: { app: db }
      ports:
        - { protocol: TCP, port: 3306 }
    - to:                        # 放行 DNS，否则域名全解析不了
        - namespaceSelector: {}
          podSelector:
            matchLabels: { k8s-app: kube-dns }
      ports:
        - { protocol: UDP, port: 53 }
```

**加默认拒绝策略时最容易踩的坑**：忘了放行 DNS 的 53 端口出站，导致所有域名解析失败。

### DNS

| 目标 | FQDN |
| :-- | :-- |
| Service（同命名空间） | `web` |
| Service（跨命名空间） | `web.other-ns` |
| Service（完整） | `web.other-ns.svc.cluster.local` |
| StatefulSet Pod | `mysql-0.mysql-headless.default.svc.cluster.local` |
| Pod（需 Headless） | `10-244-1-5.default.pod.cluster.local` |

Pod 内 `/etc/resolv.conf` 的 `search` 域决定了短名称能展开成什么，`ndots:5` 意味着少于 5 个点的域名会先尝试拼接 search 域，这曾是 DNS 查询放大的常见原因。CoreDNS 配置在 `kube-system/coredns` 这个 ConfigMap 里。

```bash
# DNS 排障标准动作
kubectl run tmp --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default
kubectl -n kube-system get pod -l k8s-app=kube-dns -o wide
kubectl -n kube-system logs -l k8s-app=kube-dns
```

------

## 调度

### 节点选择

| 机制 | 写法 | 特点 |
| :-- | :-- | :-- |
| `nodeSelector` | 精确匹配标签 | 最简单，硬性要求 |
| `nodeAffinity` | `requiredDuring...` / `preferredDuring...` | 支持操作符与软硬两种 |
| `podAffinity` | 与某些 Pod 靠拢 | 需指定 `topologyKey` |
| `podAntiAffinity` | 与某些 Pod 远离 | **多副本打散的关键** |
| `topologySpreadConstraints` | 按拓扑域均匀分布 | 比反亲和更精细 |
| `taints` + `tolerations` | 节点排斥 Pod | 用于专用节点、驱逐 |

```yaml
# 硬亲和：必须落在 SSD 节点
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: disktype
              operator: In
              values: ["ssd"]

# 拓扑打散：跨可用区均匀
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule     # 或 ScheduleAnyway
    labelSelector:
      matchLabels: { app: web }
```

### 污点与容忍

```bash
kubectl taint nodes node1 gpu=true:NoSchedule        # 加污点
kubectl taint nodes node1 gpu=true:NoSchedule-       # 删污点
```

三种效果：`NoSchedule`（不调度新 Pod）、`PreferNoSchedule`（尽量不调度）、`NoExecute`（**驱逐**已在运行的、不容忍的 Pod）。

内置污点（节点异常时 kubelet 自动打）：

| 污点 | 触发条件 |
| :-- | :-- |
| `node.kubernetes.io/not-ready` | 节点未就绪 |
| `node.kubernetes.io/unreachable` | 节点失联 |
| `node.kubernetes.io/disk-pressure` | 磁盘不足 |
| `node.kubernetes.io/memory-pressure` | 内存不足 |
| `node.kubernetes.io/pid-pressure` | PID 耗尽 |
| `node.kubernetes.io/network-unavailable` | 网络未就绪 |
| `node.kubernetes.io/unschedulable` | 被 cordon |
| `node-role.kubernetes.io/control-plane` | 控制平面默认污点 |

Pod 默认自动容忍 `not-ready` 和 `unreachable` **300 秒**（`tolerationSeconds`），这就是节点宕机后 Pod 要等 5 分钟才被重新调度的原因。

### 节点维护

```bash
kubectl cordon node1                              # 标记不可调度（不驱逐现有 Pod）
kubectl drain node1 --ignore-daemonsets \
                   --delete-emptydir-data          # 驱逐所有 Pod（含 emptyDir 数据的）
# ... 维护 ...
kubectl uncordon node1                            # 恢复调度
```

`drain` 会遵守 PodDisruptionBudget，如果 PDB 阻止驱逐会一直卡住，用 `--disable-eviction` 或 `--force` 绕过（会破坏 PDB 保证，慎用）。

### 优先级与抢占

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata: { name: high-priority }
value: 1000000
globalDefault: false
preemptionPolicy: PreemptLowerPriority
```

高优先级 Pod 调度失败时会**抢占**（驱逐）低优先级 Pod。滥用会导致关键服务被反复驱逐。

------

## 安全

### RBAC

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role                        # 命名空间级；ClusterRole 是集群级
metadata:
  namespace: dev
  name: pod-reader
rules:
  - apiGroups: [""]               # 核心组用空字符串
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: dev
  name: pod-reader-binding
subjects:
  - kind: ServiceAccount          # User / Group / ServiceAccount
    name: dev-sa
    namespace: dev
roleRef:
  kind: Role                      # Role 或 ClusterRole
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io
```

常用 verbs：`get` `list` `watch` `create` `update` `patch` `delete` `deletecollection`；特殊资源：`pods/exec`、`pods/portforward`、`pods/log`。

```bash
# 权限自检（排障必备）
kubectl auth can-i create pods
kubectl auth can-i --list
kubectl auth can-i get secrets --as=system:serviceaccount:dev:dev-sa
kubectl create role x --verb=get --resource=pods --dry-run=client -o yaml
kubectl create clusterrolebinding x --clusterrole=view --serviceaccount=dev:dev-sa
```

**最小权限要点**：不要给 SA 绑 `cluster-admin`；`view` 角色能看 Secret，慎用；禁止匿名访问（`--anonymous-auth=false`）；定期审计 `system:authenticated` 组的绑定。

### ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata: { name: app-sa, namespace: dev }
automountServiceAccountToken: false      # 不需要访问 apiserver 就关掉，减小攻击面
```

现代版本用 **Bound Service Account Token**（有有效期、受众绑定、自动轮换），不再是永不过期的静态 Secret。

### Pod 安全上下文

```yaml
securityContext:
  runAsNonRoot: true                 # 拒绝以 root 运行
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 2000                      # 挂载卷的属组
  allowPrivilegeEscalation: false    # 禁止提权（防 setuid）
  readOnlyRootFilesystem: true       # 只读根文件系统
  capabilities:
    drop: ["ALL"]                    # 丢弃所有能力
    add: ["NET_BIND_SERVICE"]        # 按需最小添加
  seccompProfile:
    type: RuntimeDefault             # 系统调用过滤
```

### Pod Security Admission（PSA）

1.25 起 GA，取代废弃的 PodSecurityPolicy。给命名空间打标签即可：

```bash
kubectl label ns dev \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=baseline \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/enforce-version=v1.30
```

| 级别 | 限制 |
| :-- | :-- |
| `privileged` | 无限制 |
| `baseline` | 禁止特权容器、hostNetwork/hostPID、危险 capabilities；允许 root |
| `restricted` | 最严：必须 runAsNonRoot、禁提权、必须 drop ALL、必须 seccomp |

### 认证与授权链路

```
请求 → 认证（证书 / Bearer Token / OIDC / Webhook）
     → 授权（Node / RBAC / Webhook / ABAC）
     → 准入控制（MutatingAdmissionWebhook → 校验 → ValidatingAdmissionWebhook / ValidatingAdmissionPolicy）
     → 写入 etcd
```

**准入控制器**是安全策略的落点：`NamespaceLifecycle`、`LimitRanger`、`ResourceQuota`、`PodSecurity`、`MutatingAdmissionWebhook`、`ValidatingAdmissionWebhook`、`ValidatingAdmissionPolicy`（CEL 表达式，1.30 GA）。可以挂 OPA Gatekeeper / Kyverno 做策略即代码。

### 审计日志

apiserver 开启：`--audit-policy-file`、`--audit-log-path`、`--audit-log-maxage` / `--audit-log-maxbackup` / `--audit-log-maxsize`。

审计级别：`None` < `Metadata` < `Request` < `RequestResponse`。生产建议：普通资源用 Metadata，Secret/exec 用 RequestResponse。

------

## 可观测性与日志

### 分层监控栈

| 层 | 组件 | 采集内容 |
| :-- | :-- | :-- |
| 节点 | node-exporter（DaemonSet） | CPU/内存/磁盘/网络 |
| 容器 | cAdvisor（kubelet 内置） | 容器资源用量 |
| K8s 对象 | kube-state-metrics | Deployment/Pod/Node 状态类指标 |
| 控制平面 | 各组件 `/metrics` | apiserver/scheduler/etcd |
| 应用 | 应用自身暴露 | 业务指标（4 个黄金信号） |

`metrics-server` 只提供资源指标（给 `kubectl top` 和 HPA 用），不做长期存储，不能替代 Prometheus。

### 关键指标

```promql
# Pod 状态
kube_pod_status_phase{phase="Failed"}
# 容器重启次数（突增说明 CrashLoop）
increase(kube_pod_container_status_restarts_total[1h]) > 3
# 期望副本 vs 可用副本（不等就说明发布卡住）
kube_deployment_status_replicas_available / kube_deployment_spec_replicas < 1
# 容器内存接近 limit（OOM 前兆）
container_memory_working_set_bytes / kube_pod_container_resource_limits{resource="memory"} > 0.9
# 节点状态
kube_node_status_condition{condition="Ready",status="true"} == 0
# apiserver 延迟与错误
histogram_quantile(0.99, sum by (le,verb) (rate(apiserver_request_duration_seconds_bucket[5m])))
rate(apiserver_request_total{code=~"5.."}[5m])
# etcd 健康（fsync 高就是磁盘慢）
histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m]))
etcd_server_leader_changes_seen_total
# PVC 使用率
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.85
```

### 日志

容器日志必须打到 **stdout/stderr**，不要写文件：

```bash
kubectl logs <pod>                          # 当前日志
kubectl logs <pod> -c <container>           # 多容器指定
kubectl logs -f <pod>                       # 实时跟随
kubectl logs <pod> --previous               # 上次崩溃前的日志（CrashLoop 必备）
kubectl logs <pod> --since=1h --tail=100
kubectl logs -l app=web --all-containers=true --prefix
```

节点上的落盘位置：

| 路径 | 说明 |
| :-- | :-- |
| `/var/log/pods/<ns>_<pod>_<uid>/<container>/0.log` | 真实文件 |
| `/var/log/containers/*.log` | 指向上面的软链接，采集器一般读这里 |
| `journalctl -u kubelet` | kubelet 自身日志 |

生产用 DaemonSet 采集（Fluent Bit / Filebeat / Promtail）→ Loki / ES。**注意配置 logrotate 与 `containerLogMaxSize`/`containerLogMaxFiles`**，否则日志会撑爆节点磁盘。

### 事件与健康

```bash
kubectl get events -A --sort-by=.lastTimestamp      # 事件默认只保留 1 小时
kubectl get --raw /healthz                          # apiserver 健康
kubectl get --raw /livez
kubectl get --raw /readyz?verbose
kubectl cluster-info
```

`kubectl get events` 是排查 Pod 问题的**第一现场**，比日志更早暴露原因（调度失败、镜像拉取失败、探针失败）。

------

## 日常运维操作

### 资源配额与限制

```yaml
apiVersion: v1
kind: ResourceQuota
metadata: { name: dev-quota, namespace: dev }
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
    services: "20"
    persistentvolumeclaims: "10"
    count/deployments.apps: "20"
---
apiVersion: v1
kind: LimitRange
metadata: { name: dev-limits, namespace: dev }
spec:
  limits:
    - type: Container
      default:          { cpu: 500m, memory: 512Mi }   # 未设 limits 时的默认值
      defaultRequest:   { cpu: 100m, memory: 128Mi }   # 未设 requests 时的默认值
      max:              { cpu: "4", memory: 8Gi }
      min:              { cpu: 10m, memory: 16Mi }
      maxLimitRequestRatio: { cpu: "10" }              # 限制 limit/request 比值，防超卖
```

**注意**：命名空间一旦有 ResourceQuota 且包含 `requests.cpu`，之后创建 Pod 就**必须**显式声明 requests，否则被拒。LimitRange 可以兜底。

### 日常巡检与操作

```bash
# 集群全景
kubectl get nodes -o wide
kubectl get pod -A -o wide --field-selector status.phase!=Running
kubectl get pod -A --sort-by=.status.startTime
kubectl top node && kubectl top pod -A --sort-by=memory

# 资源水位（看节点已分配量，而非真实使用量）
kubectl describe node <node> | sed -n '/Allocated resources/,/Events/p'

# 批量操作
kubectl get pod -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'
kubectl delete pod -n dev --field-selector status.phase=Succeeded
kubectl get deploy -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[*].image'
```

### 命名空间卡在 Terminating

```bash
kubectl get ns <ns> -o json | jq '.spec.finalizers'
# 找出残留的命名空间级资源
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n1 -I{} sh -c 'kubectl get {} -n <ns> --no-headers 2>/dev/null | head -3'
# 最后手段（确认无残留资源后）
kubectl get ns <ns> -o json | jq '.spec.finalizers=[]' | kubectl replace --raw /api/v1/namespaces/<ns>/finalize -f -
```

### 调试容器

```bash
# 临时容器（镜像里没有 shell 时的救星，会共享目标容器的进程命名空间）
kubectl debug -it <pod> --image=busybox:1.36 --target=app -- sh

# 复制一个改造过的 Pod 来调试（可改 command/加特权）
kubectl debug <pod> -it --copy-to=debug-pod --container=app -- sh

# 直接进节点命名空间
kubectl debug node/<node> -it --image=busybox:1.36
# 进入后 nsenter --target 1 --mount --uts --ipc --net --pid -- bash

# 运行时层（节点上直接操作容器）
crictl ps -a
crictl logs <container-id>
crictl inspect <container-id>
crictl images
crictl rmi --prune
```

------

## etcd 备份与恢复

etcd 是集群的**唯一真相来源**，丢了就全丢了。生产必须做到「定期自动备份 + 定期恢复演练」。

### 备份

```bash
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /backup/etcd-$(date +%F-%H%M).db

# 校验快照完整性
etcdctl snapshot status /backup/etcd-2026-10-09.db -w table
```

用 CronJob 或系统 cron 每天备份，并同步到异地/对象存储。

### 恢复

```bash
# 1. 停掉控制平面（把 manifest 移走，静态 Pod 就停了）
mkdir -p /tmp/manifests && mv /etc/kubernetes/manifests/* /tmp/manifests/

# 2. 从快照恢复到一个新数据目录
ETCDCTL_API=3 etcdctl snapshot restore /backup/etcd-2026-10-09.db \
  --data-dir=/var/lib/etcd-restore

# 3. 让 etcd 使用新数据目录（改 etcd manifest 的 hostPath / --data-dir）
#    单节点：直接改 /etc/kubernetes/manifests/etcd.yaml
#    多节点：需要 --initial-cluster 与 --initial-cluster-token 保持一致

# 4. 恢复 manifest，验证
mv /tmp/manifests/* /etc/kubernetes/manifests/
etcdctl endpoint health --endpoints=https://127.0.0.1:2379 \
  --cacert=... --cert=... --key=...
kubectl get nodes
```

### 其他运维点

```bash
etcdctl endpoint status -w table        # 看 leader、DB 大小、raft index
etcdctl endpoint health
etcdctl member list -w table
etcdctl defrag                          # 碎片整理（会阻塞，逐个成员做）
etcdctl compact <revision>              # 压缩历史版本，释放空间
```

**告警阈值**：DB 大小超过 **8 GB**（默认 quota 上限）会进入只读告警且无法写入；`etcd_disk_wal_fsync_duration_seconds` 的 P99 应 < 10ms（超过说明磁盘太慢，用 SSD）。

应用层备份用 **Velero**（备份 PV + K8s 对象，支持跨集群恢复）。

------

## 故障排查

### 通用排障链路

```
1. kubectl get pod -o wide          → 看状态、所在节点、重启次数
2. kubectl describe pod             → 看 Events、Conditions、Last State
3. kubectl logs --previous          → 看崩溃前日志
4. kubectl exec -it -- sh           → 进去看进程/网络/配置
5. kubectl get events -A            → 看集群级事件
6. 节点层：journalctl -u kubelet / crictl / dmesg
```

**核心心法**：`Status` 说现象，`Events` 说原因。九成问题看完 `describe` 的 Events 就有答案。

### Pod 常见异常

| 状态 | 根因 | 排查动作 |
| :-- | :-- | :-- |
| `Pending` | 资源不足 / 无节点满足亲和 / 有污点不容忍 / PVC 未绑定 / 超配额 | `describe pod` 看 Events；`describe node` 看 Allocated resources |
| `ContainerCreating` | 拉镜像中 / CNI 未就绪 / 卷挂载失败 / ConfigMap 或 Secret 不存在 | `describe pod`；检查 `mount` 与 CNI Pod |
| `ImagePullBackOff` / `ErrImagePull` | 镜像名或 tag 错 / 私有仓库没配 `imagePullSecrets` / 网络不通 / 限流 | `crictl pull <image>` 在节点上手动试拉 |
| `CrashLoopBackOff` | 应用启动即退出：配置错、依赖不通、命令错、探针误杀、OOM | `logs --previous`；检查 liveness 阈值是否过严 |
| `OOMKilled` | 内存超 limit（退出码 **137**） | `describe pod` 的 Last State Reason；`kubectl top pod`；调大 limit 或查内存泄漏 |
| `Evicted` | 节点磁盘/内存压力触发 kubelet 驱逐 | `describe node` 看 Conditions 与 kubelet 驱逐阈值 |
| `Terminating` 卡住 | finalizer 未清 / 节点失联 / kubelet 挂了 | 先查节点；确认无 finalizer 后 `kubectl delete pod --force --grace-period=0` |
| `Unknown` | 节点失联 | 查节点状态与网络 |
| `Completed` | 正常结束（Job/Pod） | 无需处理 |

**容器退出码速记**：`0` 正常；`1` 应用报错；`137` = 128+9 SIGKILL（**OOM 或被强杀**）；`143` = 128+15 SIGTERM（被优雅终止）；`126` 不可执行；`127` 命令不存在。

### Service / 网络不通

```bash
# 1. 看端点（最常见原因就是空）
kubectl get endpointslices -l kubernetes.io/service-name=web
kubectl get pod -l app=web --show-labels          # selector 是否匹配

# 2. 看 Service 定义
kubectl get svc web -o yaml                       # targetPort 是否对

# 3. 从 Pod 内部验证
kubectl run tmp --image=busybox:1.36 --rm -it --restart=Never -- sh
#   wget -qO- http://web.default.svc.cluster.local
#   nc -zv web 80

# 4. 检查 kube-proxy
kubectl -n kube-system get pod -l k8s-app=kube-proxy
kubectl -n kube-system logs -l k8s-app=kube-proxy

# 5. 检查 NetworkPolicy 是否拦了
kubectl get networkpolicy -A
```

排查顺序：**Service selector → Endpoints 是否为空 → targetPort → NetworkPolicy → kube-proxy → CNI**。

### DNS 不通

```bash
kubectl -n kube-system get pod -l k8s-app=kube-dns
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=50
kubectl -n kube-system get configmap coredns -o yaml
kubectl run tmp --image=busybox:1.28 --rm -it --restart=Never -- nslookup kubernetes.default
# Pod 内看 resolv.conf
kubectl exec -it <pod> -- cat /etc/resolv.conf
```

常见原因：CoreDNS Pod 不 Ready、ConfigMap 写错、NetworkPolicy 拦了 53 端口、`ndots` 配置引发超时、上游 DNS 不可达。

### 节点 NotReady

```bash
kubectl describe node <node>            # 看 Conditions 与 Events
ssh <node>
systemctl status kubelet                # kubelet 是否活着
journalctl -u kubelet -f --no-pager     # 实时看错误
systemctl status containerd             # 运行时是否活着
df -h && free -h                        # 磁盘/内存压力
crictl ps -a                            # 容器状态
swapoff -a                              # 确认 swap 没被打开
kubeadm certs check-expiration          # 证书是否过期
```

高频原因：**磁盘满**（最常见）、内存压力、kubelet 证书过期、容器运行时崩溃、时间不同步、swap 被重新启用。

### 控制平面异常

```bash
# 静态 Pod 状态
crictl ps -a | grep -E 'kube-apiserver|etcd|scheduler|controller'
crictl logs <apiserver-container-id>
journalctl -u kubelet | grep -i apiserver

# etcd
etcdctl endpoint health --endpoints=https://127.0.0.1:2379 --cacert=... --cert=... --key=...
etcdctl endpoint status -w table

# apiserver 就绪
kubectl get --raw /readyz?verbose
```

**etcd 空间告警**（`etcdserver: mvcc: database space exceeded`）处理：`compact` → `defrag` → 若仍满则 `--etcd-quota-backend-mb` 调整（不建议超过 8 GB）。

### 镜像与运行时

```bash
crictl images                       # 节点上已有镜像
crictl pull registry.example.com/web:1.2.3
crictl ps -a
crictl inspect <id> | jq '.status'
crictl rmi --prune                  # 清理未使用镜像
systemctl restart containerd        # 运行时重启（会短暂影响节点上容器）
```

### 磁盘与资源清理

```bash
# 节点磁盘满了
df -h /var/lib/kubelet /var/lib/containerd
du -sh /var/lib/containerd/* | sort -rh | head
crictl rmi --prune
journalctl --vacuum-size=500M
kubectl get pod -A --field-selector status.phase=Succeeded   # 清理已完成 Pod
# kubelet 垃圾回收阈值：imageGCHighThresholdPercent / evictionHard
```

------

## 生产实践清单

### 工作负载

- [ ] 所有容器设 `requests` 和 `limits`（不设等于埋雷）
- [ ] `livenessProbe` + `readinessProbe` 必配，启动慢的加 `startupProbe`
- [ ] 镜像用固定 tag 或 digest，**禁止 `latest`**；配 `imagePullPolicy: IfNotPresent`
- [ ] 多副本 + `podAntiAffinity` / `topologySpreadConstraints` 打散
- [ ] 关键服务配 `PodDisruptionBudget`
- [ ] 配 `preStop` + 合理的 `terminationGracePeriodSeconds` 做优雅退出
- [ ] `resources` 与 HPA 联动，别让 HPA 和固定副本数打架

### 安全

- [ ] 命名空间打上 PSA 标签（至少 `baseline`，推荐 `restricted`）
- [ ] `runAsNonRoot` + `allowPrivilegeEscalation: false` + `drop: ALL` + `seccompProfile: RuntimeDefault`
- [ ] Secret 开启静态加密或接外部 KMS / Vault
- [ ] NetworkPolicy 默认拒绝，按需放行（**记得放行 DNS**）
- [ ] RBAC 最小权限，禁止给工作负载绑 `cluster-admin`
- [ ] 不需要访问 apiserver 的 SA 设 `automountServiceAccountToken: false`
- [ ] 私有仓库用 `imagePullSecrets`，凭据别硬编码在 YAML
- [ ] 开启审计日志，重点关注 `exec`、`secret` 访问、RBAC 变更

### 集群

- [ ] 控制平面 ≥ 3 节点，etcd 用 SSD，独立数据盘
- [ ] etcd 每日自动备份 + 异地存储 + **定期恢复演练**
- [ ] 关注证书有效期（`kubeadm certs check-expiration`），配置自动轮换
- [ ] 节点分池：系统组件与业务负载隔离，用污点 + 亲和
- [ ] 配 `ResourceQuota` + `LimitRange` 做多租户隔离
- [ ] 至少两个节点池跨可用区，防止单 AZ 故障
- [ ] 控制平面与节点监控告警（etcd fsync、apiserver 延迟、节点 NotReady）
- [ ] 升级前读 Release Notes、扫描废弃 API、先备份 etcd、先在测试集群验证
- [ ] 所有清单用 GitOps 管理（Argo CD / Flux），禁止手工 `kubectl edit` 生产

### 可观测性

- [ ] 日志统一采集到 Loki / ES，容器日志配 `containerLogMaxSize`
- [ ] 监控四层：节点 / 容器 / K8s 对象 / 应用
- [ ] 告警覆盖：Pod 重启、副本数不足、节点 NotReady、磁盘水位、证书到期、etcd 健康
- [ ] 保留 Prometheus + Grafana + Alertmanager，告警要有人接

------

## kubectl 命令速查

### 查看

```bash
kubectl get nodes -o wide
kubectl get pod -A -o wide
kubectl get all -n dev
kubectl get pod web-xxx -o yaml
kubectl get pod -l app=web,tier=frontend
kubectl get pod --field-selector spec.nodeName=node1
kubectl get pod --sort-by=.status.startTime
kubectl get deploy -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas'
kubectl get pod -o jsonpath='{.items[*].status.podIP}'
kubectl describe pod web-xxx
kubectl explain pod.spec.containers.resources
kubectl api-resources
kubectl api-versions
kubectl cluster-info
kubectl config view
kubectl config get-contexts && kubectl config use-context prod
```

### 创建与修改

```bash
kubectl apply -f app.yaml
kubectl apply -f ./dir/ --recursive
kubectl apply -k ./overlays/prod                 # Kustomize
kubectl create deployment web --image=nginx --dry-run=client -o yaml > web.yaml
kubectl diff -f app.yaml                          # 先看会改什么
kubectl edit deployment web
kubectl patch deployment web -p '{"spec":{"replicas":5}}'
kubectl set image deployment/web app=web:1.2.4
kubectl label pod web-xxx env=prod
kubectl annotate pod web-xxx owner=team-a
kubectl delete -f app.yaml
kubectl delete pod web-xxx --grace-period=0 --force
```

### 交互与转发

```bash
kubectl exec -it web-xxx -- bash
kubectl exec -it web-xxx -c sidecar -- sh
kubectl cp web-xxx:/var/log/app.log ./app.log
kubectl port-forward pod/web-xxx 8080:80
kubectl port-forward svc/web 8080:80
kubectl attach -it web-xxx
kubectl run tmp --image=busybox:1.36 --rm -it --restart=Never -- sh
```

### 集群运维

```bash
kubectl top node
kubectl top pod -A --sort-by=memory
kubectl cordon node1
kubectl drain node1 --ignore-daemonsets --delete-emptydir-data
kubectl uncordon node1
kubectl taint node node1 key=value:NoSchedule
kubectl rollout status deployment/web
kubectl rollout restart deployment/web
kubectl scale statefulset mysql --replicas=5
kubectl auth can-i --list
kubectl get events -A --sort-by=.lastTimestamp
kubectl debug -it web-xxx --image=busybox:1.36 --target=app
```

------

## CKA 考纲映射

按 `CKA.md` 的考试域对应到本文档章节：

| 考试域（权重） | 对应章节 | 必练 |
| :-- | :-- | :-- |
| 故障排查（30%） | [故障排查](#故障排查) | Pod 状态机全部异常、Service 端点、DNS、节点 NotReady、日志三连 |
| 集群架构/安装/配置（25%） | [架构](#架构)、[集群安装与升级](#集群安装与升级kubeadm)、[etcd 备份与恢复](#etcd-备份与恢复) | `kubeadm` init/join/upgrade、etcd 备份恢复、RBAC、HA 拓扑 |
| 服务与网络（20%） | [网络](#网络) | Service 四种类型、Ingress、NetworkPolicy、CoreDNS 排错 |
| 工作负载与调度（15%） | [工作负载](#工作负载)、[调度](#调度) | 滚动更新与回滚、亲和/反亲和、污点容忍、配额、HPA |
| 存储（10%） | [存储](#存储) | PV/PVC/StorageClass、绑定排错、挂载到 Pod |

**CKA 实操高频题**：升级集群、etcd 备份恢复、创建 NetworkPolicy、修一个 `CrashLoopBackOff`、把 Pod 调度到指定节点、创建 PVC 并挂载、RBAC 授权、暴露 Service。建议全部练到不看文档能敲完。

------

## 参考

- 官方文档：https://kubernetes.io/docs/
- 官方 API 参考：https://kubernetes.io/docs/reference/kubernetes-api/
- kubeadm 升级：https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
- etcd 灾备：https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
- PSA：https://kubernetes.io/docs/concepts/security/pod-security-admission/
