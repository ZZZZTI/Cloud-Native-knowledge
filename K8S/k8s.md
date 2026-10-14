> Kubernetes（K8s）是一个开源的容器编排平台，用于自动化部署、扩缩容和管理容器化应用，保障其高可用与弹性运行。

------

### kubectl命令

```Shell
# ========== 基础信息 ==========
kubectl version --client                 # 查看客户端版本
kubectl cluster-info                     # 查看集群信息
kubectl api-resources                    # 查看支持的资源类型
kubectl explain pod.spec                 # 查看资源字段说明
kubectl config get-contexts              # 查看上下文
kubectl config use-context <ctx>         # 切换上下文
kubectl config set-context --current --namespace=<ns>  # 切换默认命名空间

# ========== 查看资源（etcd 里的期望状态） ==========
kubectl get nodes                        # 查看节点
kubectl get ns                           # 查看命名空间
kubectl get pods                         # 查看当前命名空间 Pod
kubectl get pods -A                      # 查看所有命名空间 Pod
kubectl get pods -n <ns> -o wide         # 查看 Pod，含 IP/节点
kubectl get all -n <ns>                  # 查看常用资源
kubectl get svc,deploy,rs,po -n <ns>     # 查看多种资源
kubectl get pod <pod> -n <ns> -o yaml    # 导出 YAML
kubectl get pod <pod> -n <ns> -o json    # 导出 JSON
kubectl get pods -l app=nginx            # 按标签筛选
kubectl get pods --field-selector status.phase=Running
kubectl get events --sort-by=.metadata.creationTimestamp

# ========== 描述与排查（实际状态） ==========
kubectl describe pod <pod> -n <ns>       # 查看详情和事件
kubectl describe node <node>             # 查看节点详情
kubectl logs <pod> -n <ns>               # 查看日志
kubectl logs -f <pod> -n <ns>            # 实时日志
kubectl logs <pod> -c <container> -n <ns>
kubectl logs <pod> --previous -n <ns>    # 查看上次崩溃日志
kubectl exec -it <pod> -n <ns> -- /bin/sh
kubectl exec -it <pod> -c <container> -n <ns> -- bash
kubectl cp <ns>/<pod>:/tmp/foo ./foo     # 从 Pod 拷贝文件
kubectl cp ./foo <ns>/<pod>:/tmp/foo     # 拷贝文件到 Pod

# ========== 声明：创建、更新、删除 pods ==========
kubectl apply -f app.yaml                # 声明式创建/更新
kubectl create -f app.yaml               # 创建资源
kubectl delete -f app.yaml               # 删除资源
kubectl delete pod <pod> -n <ns>
kubectl delete pod <pod> -n <ns> --force --grace-period=0  # 强制删除，慎用
kubectl edit deploy/<name> -n <ns>       # 在线编辑
kubectl patch deploy/<name> -n <ns> --type='json' -p='[{"op":"replace","path":"/spec/replicas","value":3}]'
kubectl label pod <pod> -n <ns> env=prod
kubectl annotate pod <pod> -n <ns> owner=team-a
kubectl create configmap app-config --from-literal=APP_ENV=prod  # 命令创建cm

# ========== 扩缩容与滚动更新 ==========
kubectl scale deploy/<name> -n <ns> --replicas=3
kubectl autoscale deploy/<name> -n <ns> --min=2 --max=10 --cpu-percent=80
kubectl set image deploy/<name> <container>=nginx:1.25 -n <ns>
kubectl rollout status deploy/<name> -n <ns>
kubectl rollout history deploy/<name> -n <ns>
kubectl rollout undo deploy/<name> -n <ns>
kubectl rollout restart deploy/<name> -n <ns>

# ========== 网络与端口 ==========
kubectl expose deploy/<name> -n <ns> --port=80 --target-port=8080
kubectl port-forward svc/<svc> 8080:80 -n <ns>
kubectl port-forward pod/<pod> 8080:80 -n <ns>

# ========== 节点维护 ==========
kubectl cordon <node>                    # 标记不可调度
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>                  # 恢复调度
kubectl taint nodes <node> key=value:NoSchedule
kubectl top nodes                        # 节点资源使用
kubectl top pods -n <ns>                 # Pod 资源使用

# ========== 权限与调试 ==========
kubectl auth can-i get pods -n <ns>
kubectl auth can-i '*' '*' --all-namespaces
kubectl proxy                            # 本地代理 API Server


-n <ns>              # 指定命名空间
-A                   # 所有命名空间
-o wide|yaml|json    # 输出格式
-o jsonpath=...      # 提取字段
-l app=nginx         # 标签选择器
--watch / -w         # 监听实时变化
--help               # 查看帮助
```

### 声明资源的 yaml 配置

```Shell
# ============================================================
# 单个pod （测试）
# ============================================================
apiVersion: v1     # API 版本
kind: Pod          # 资源类型
metadata:          # 元数据：用于标识和描述资源
  name: basic-demo      # Pod 名称，必须在当前命名空间内唯一
  labels:               # 标签：键值对，用于 Service、Deployment 等资源通过 selector 关联此 Pod
    app: basic
spec:              # 期望状态：描述 Pod 的规格，包含容器、卷、网络等配置
  containers:           # 容器列表：一个 Pod 可以包含一个或多个容器（共享网络和存储）
    - name: web           # 容器名称，在 Pod 内必须唯一
      image: nginx:1.27   # 镜像地址
      ports:              # 端口声明
        - containerPort: 80
      resources:          # 资源配额：用于调度和限制容器资源使用
        requests:           # requests（请求资源）：调度器据此选择节点，容器启动时保留该资源
          cpu: 100m             # 100 毫核 = 0.1 核 CPU
          memory: 64Mi          # 64 MiB 内存
        limits:             # limits（限制资源）：容器最多能使用的资源上限
          cpu: 200m             # 最多使用 0.2 核 CPU，超出会被限流（throttle）
          memory: 128Mi         # 最多使用 128 MiB 内存，超出会被 OOM Killer 终止
          
      startupProbe:       # 启动探针
      livenessProbe:      # 存活探针
      readinessProbe:     # 就绪探针

---

# ============================================================
# Deployment 无状态工作负载
# 作用：管理 Pod 的副本数、滚动更新、自愈
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  namespace: demo-namespace
  labels:
    app: web
spec:
  replicas: 3              # 期望的 Pod 副本数
  selector:                # 标签选择器，必须匹配 template.metadata.labels
    matchLabels:
      app: web
  # 更新策略
  strategy:                
    type: RollingUpdate    # 滚动更新（默认），另一个是 Recreate（先全部删再建）
    rollingUpdate:
      maxSurge: 1          # 更新时最多超出期望副本数的 Pod 数量（可以是数字或百分比）
      maxUnavailable: 0    # 更新时最多不可用的 Pod 数量（0 表示保证服务不中断）
  # Pod 模板
  template:                
    metadata:
      labels:
        app: web           # 必须与 selector.matchLabels 匹配
    spec:
      # ---- 调度相关 ----
      nodeSelector:        # 节点选择器，将 Pod 调度到带特定标签的节点
        disktype: ssd
      tolerations:         # 容忍度，允许 Pod 调度到带污点（Taint）的节点
        - key: "dedicated"
          operator: "Equal"
          value: "web"
          effect: "NoSchedule"
      affinity:            # 亲和性（此处省略详细配置，生产中常用于 Pod 反亲和）
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: web
                topologyKey: kubernetes.io/hostname

      # ---- 容器配置 ----
      containers:
        - name: web
          image: nginx:1.27
          imagePullPolicy: IfNotPresent  # Always, IfNotPresent, Never
          
          # 端口声明
          ports:
            - name: http
              containerPort: 80
              protocol: TCP
          
          # 环境变量：从 ConfigMap 和 Secret 注入
          envFrom:
            - configMapRef:
                name: app-config
            - secretRef:
                name: app-secret
          
          # 单个环境变量（优先级更高）
          env:
            - name: MY_POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
                  optional: true    # 缺失时不报错，注入空值
          
          # 资源配额
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
          
          # 挂载卷
          volumeMounts:
            - name: config-vol
              mountPath: /etc/nginx/conf.d
              readOnly: true
            - name: data-vol
              mountPath: /usr/share/nginx/html/data
          
          # ---- 探针配置 ----
          startupProbe:       # 启动探针：判断应用是否启动成功
            httpGet:
              path: /
              port: 80
            failureThreshold: 30
            periodSeconds: 2
          livenessProbe:      # 存活探针：判断应用是否假死，失败则重启容器
            httpGet:
              path: /healthz
              port: 80
            initialDelaySeconds: 5  # 容器启动后等多久才开始探测
            periodSeconds: 10       # 每隔多久探一次
            failureThreshold: 3     # 连续失败几次算失败   
            # failureThreshold × periodSeconds ≥ 应用最坏启动时间
          readinessProbe:     # 就绪探针：判断应用是否准备好接收流量
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 3
            periodSeconds: 5
            failureThreshold: 2
      
      # ---- 卷定义 ----
      volumes:
        - name: config-vol
          configMap:
            name: app-config
            items:
              - key: nginx.conf
                path: default.conf
        - name: data-vol
          persistentVolumeClaim:
            claimName: app-pvc

---

# ============================================================
# Namespace 命名空间
# 作用：逻辑隔离集群资源，方便多团队/多环境管理
# ============================================================
apiVersion: v1
kind: Namespace
metadata:
  name: demo-namespace

---

# ============================================================
# ConfigMap 配置字典
# 作用：存储非敏感的配置数据，与 Pod 解耦
# ============================================================
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: demo-namespace
data:
  # 直接键值对
  APP_ENV: "production"
  LOG_LEVEL: "info"
  # 也可以存整个文件内容
  nginx.conf: |
    server {
      listen 80;
      location / {
        root /usr/share/nginx/html;
      }
    }

---

# ============================================================
# Secret 密钥
# 作用：存储敏感信息（密码、Token、证书）
# 注意：data 中的值必须是 base64 编码，stringData 则可以直接写明文
# ============================================================
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: demo-namespace
type: Opaque  # 默认类型，Opaque 表示通用的键值对
data:
  # base64 编码后的值，例如 echo -n 'admin' | base64 得到 YWRtaW4=
  DB_USER: YWRtaW4=
  DB_PASS: cGFzc3dvcmQ=
stringData:
  # stringData 允许直接写明文，K8s 会自动将其转换为 base64 存入 data
  API_KEY: "my-super-secret-key"

---

# ============================================================
# PersistentVolumeClaim (PVC) 持久化存储声明
# 作用：为 Pod 申请持久化存储，与底层 PV 绑定
# ============================================================
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-pvc
  namespace: demo-namespace
spec:
  accessModes:
    - ReadWriteOnce    # RWO：单节点读写；ROX：多节点只读；RWX：多节点读写
  resources:
    requests:
      storage: 1Gi     # 申请 1GiB 存储空间
  storageClassName: standard  # 指定存储类，取决于集群环境（如 local-path, nfs-client 等）

---

# ============================================================
# Service 服务
# 作用：为一组 Pod 提供稳定的访问入口和负载均衡
# ============================================================
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: demo-namespace
  labels:
    app: web
spec:
  type: ClusterIP          # ClusterIP（默认，集群内）, NodePort, LoadBalancer, ExternalName
  selector:
    app: web               # 选择带有 app=web 标签的 Pod 作为后端
  ports:
    - name: http
      port: 80             # Service 暴露的端口
      targetPort: 80       # 容器监听的端口（对应 containerPort）
      protocol: TCP
      # nodePort: 30080    # 当 type=NodePort 时，可指定节点端口（30000-32767）
  sessionAffinity: None    # 会话保持策略，None 或 ClientIP

---

# ============================================================
# Ingress 七层路由
# 作用：提供 HTTP/HTTPS 外部访问入口，需要 Ingress Controller
# ============================================================
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: demo-namespace
  annotations:
    # 常用 Nginx Ingress Controller 注解
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  ingressClassName: nginx  # 指定 Ingress Controller 类型（如 nginx, traefik）
  rules:
    - host: demo.example.com  # 域名，如果为空则匹配所有
      http:
        paths:
          - path: /
            pathType: Prefix  # Prefix（前缀匹配）, Exact（精确匹配）
            backend:
              service:
                name: web-service
                port:
                  number: 80
  # TLS 配置（需要 Secret 中存放证书）
  # tls:
  #   - hosts:
  #       - demo.example.com
  #     secretName: tls-secret

---

# ============================================================
# HorizontalPodAutoscaler (HPA) 水平自动扩缩容
# 作用：根据 CPU/内存等指标自动调整 Deployment 的副本数
# ============================================================
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
  namespace: demo-namespace
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-deployment
  minReplicas: 2           # 最小副本数
  maxReplicas: 10          # 最大副本数
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80  # CPU 使用率超过 80% 时触发扩容
  behavior:                # 扩缩容行为控制（可选）
    scaleDown:
      stabilizationWindowSeconds: 300  # 缩容冷却时间，避免抖动
# ============================================================
# 控制器的资源类型：StatefulSet，DaemonSet，Job，CronJob，PodDisruptionBudget（PHB），NetworkPolicy
# ============================================================
```

### 概念

```Shell
# 探针
探针	           作用	                  失败后果	                            典型用途
startupProbe	   判断容器是否启动完成	    超过阈值后重启容器	                     慢启动应用
livenessProbe	   判断容器是否还活着	     连续失败达到failureThreshold后重启容器  进程假死、死锁
readinessProbe	 判断容器是否准备好接流量	 从ServiceEndpointSlice摘除，不重启	   依赖未就绪、临时不可用

# Qos class（服务质量）：是 K8s 用来决定 Pod 在节点资源紧张时优先级的一种机制。
1.Guaranteed（保证型）：资源分配最稳定，最不容易被驱逐。
条件：Pod 中每一个容器的 requests 必须严格等于 limits
2.Burstable（突发型）：允许容器在空闲时突发使用超出 requests 的资源，但不能超过 limits
条件：Pod 中至少有一个容器设置了 requests 或 limits。
3.BestEffort（尽力而为型）：一旦节点资源紧张，这类 Pod 会被最先杀掉。
条件：Pod 中所有容器都没有设置任何 requests 和 limits。

# 多容器模式
模式	           说明	                典型用途
Init Container	主容器启动前执行完退出 	等待依赖、初始化数据，拉配置
Sidecar	        辅助主容器	            日志、监控、代理
Ambassador	    代理外部连接	         数据库代理、服务发现
Adapter	        转换输出格式	         日志标准化、指标暴露，转成 Prometheus 格式

# 控制器
对象	       职责	                       典型场景
Deployment	管无状态应用，更新和回滚（无序） Web 服务、API
ReplicaSet  保证副本数（几乎不直接用）
StatefulSet	管有状态应用的标识与存储（有序） 数据库、消息队列
DaemonSet  	每个节点跑一份	               日志/监控采集器、CNI
Job	        跑一次就结束	                数据迁移、批处理
CronJob	    按 cron 周期创建 Job	         定时巡检、报表
HPA / PDB	  副本弹性 / 可用性保护	        自动扩缩、节点维护

# service类型
类型     	 访问范围	           关键字段	            典型用途
ClusterIP	仅集群内	          clusterIP 自动分配	 东西向服务调用
NodePort	集群外，通过         NodeIP:nodePort	  nodePort 30000–32767	开发测试、临时暴露
Headless	集群内，不做负载均衡	clusterIP: None	   StatefulSet 稳定 DNS

# 网络通信
特性	   Service	        Ingress	                NetworkPolicy
工作层级	四层（TCP/UDP）	  七层（HTTP/HTTPS） 	     三层/四层（IP/端口）
核心作用	服务发现、负载均衡	 外部 HTTP 路由、TLS	     网络隔离、访问控制
依赖组件	kube-proxy	     Ingress Controller	    CNI 插件（如 Calico）
典型场景	微服务互调	       生产环境对外暴露 Web 服务	多租户隔离、安全加固

Ingress（外部流量入口）->Service（四层负载均衡）-> CoreDNS，Endpoints ->NetworkPolicy（防火墙）->Pod
```









### 架构

```Shell
┌─────────────────────────────────────────────────────────────────────────────┐
│                      控制平面  Control Plane（Master Node）                   │
│  ┌────────────────┐ ┌────────────────┐ ┌─────────────────┐ ┌─────────────┐  │
│  │ kube-apiserver │ │ kube-scheduler │ │kube-controller- │ │    etcd     │  │
│  │                │ │                │ │     manager     │ │ (键值存储)   │  │
│  │  集群统一入口    │ │    Pod 调度器   │ │ 控制器循环/自愈   │ │存储集群状态   │  │
│  └────────────────┘ └────────────────┘ └─────────────────┘ └─────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       │ API 调用（network：HTTPS :6443）
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                 Worker Node 节点                             │
│  ┌──────────────┐ ┌──────────────┐ ┌─────────────────────────────────────┐  │
│  │   kubelet    │ │  kube-proxy  │ │Container Runtime（containerd/CRI-O） │  │
│  │   节点代理    │ │   网络规则     │ │      CRI 接口，真正负责跑容器          │  │
│  └──────────────┘ └──────────────┘ └─────────────────────────────────────┘  │
│                                                                             │
│  ┌─────────────────────────────────┐   ┌─────────────────────────────────┐  │
│  │              Pod A              │   │              Pod B              │  │
│  │  ┌────────────┐ ┌────────────┐  │   │  ┌────────────┐ ┌────────────┐  │  │
│  │  │ Container1 │ │ Container2 │  │   │  │ Container1 │ │ Container2 │  │  │
│  │  └────────────┘ └────────────┘  │   │  └────────────┘ └────────────┘  │  │
│  │     共享 Network Namespace       │   │     共享 Network Namespace       │  │
│  │           共享 Volume            │   │           共享 Volume            │  │
│  └─────────────────────────────────┘   └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 控制平面组件

| 组件                       | 职责                                                       | 关键点                                                       |
| :------------------------- | :--------------------------------------------------------- | :----------------------------------------------------------- |
| `kube-apiserver`           | 集群唯一入口，所有操作的 REST 网关，负责认证/授权/准入控制 | 无状态，可多实例；静态 Pod 运行在 `/etc/kubernetes/manifests/` |
| `etcd`                     | 保存集群全部状态（唯一持久化数据源）                       | 必须定期备份；奇数节点（3/5）；2379 客户端端口、2380 对等端口 |
| `kube-scheduler`           | 为新 Pod 选择节点                                          | 两阶段：Filter（过滤）→ Score（打分）                        |
| `kube-controller-manager`  | 运行各类控制器，持续把「期望状态」调和成「实际状态」       | 包含 Deployment/ReplicaSet/Node/Job/Endpoint 等几十个控制器  |
| `cloud-controller-manager` | 对接云厂商 API（LB、节点、路由）                           | 自建集群可不用                                               |

### 节点组件

| 组件              | 职责                                            | 关键点                                          |
| :---------------- | :---------------------------------------------- | :---------------------------------------------- |
| `kubelet`         | 节点代理，管理 Pod 生命周期、上报状态、执行探针 | 监听 10250；日志 `journalctl -u kubelet`        |
| `kube-proxy`      | 实现 Service 的负载均衡与转发规则               | iptables / ipvs / nftables 模式                 |
| `pod`             | 最小的调度单元，包含一个或多个容器              | 隐藏的pause容器：共享 Network Namespace，Volume |
| Container Runtime | 真正创建和运行容器                              | 通过 CRI 接口被 kubelet 调用；常用 containerd   |

### 集群插件（Addons）

| 插件                                          | 作用                                                         |
| :-------------------------------------------- | :----------------------------------------------------------- |
| CoreDNS                                       | 集群内 DNS 服务发现                                          |
| CNI（Calico / Cilium / Flannel）              | Pod 网络；**只有 Calico/Cilium/Antrea 等支持 NetworkPolicy，Flannel 不支持** |
| Ingress Controller（ingress-nginx / Traefik） | 七层入口                                                     |
| metrics-server                                | 提供 `kubectl top` 与 HPA 的资源指标                         |
| Dashboard                                     | Web UI（生产慎用）                                           |

### 设计哲学

- **声明式 API**：用户提交「期望状态」（YAML），而不是「执行步骤」。
- **控制器循环（Reconcile Loop）**：`观察实际状态 → 与期望状态比较 → 采取动作缩小差异`，永不停止。
- **一切皆对象**：所有资源都通过 apiserver 读写 etcd，没有带外状态。
- **松耦合**：组件之间只通过 apiserver 通信，不直接互相调用。

------

## 核心概念

| 概念               | 说明                                                         |
| :----------------- | :----------------------------------------------------------- |
| Pod                | 最小调度单元，用完即弃                                       |
| ReplicaSet         | 保证指定数量的 Pod 副本（一般由 Deployment 托管，不直接用）  |
| Deployment         | **基于声明式定义副本数，实现 Pod 的自动维持与故障自愈**      |
| StatefulSet        | 有状态工作负载，Pod 有稳定序号、网络标识和独立存储           |
| DaemonSet          | 每个（或指定）节点运行一个 Pod，用于日志/监控/网络插件       |
| Job / CronJob      | 一次性任务 / 定时任务                                        |
| Service            | **为一组动态变化的 Pod 提供稳定入口，并实现流量的负载均衡。** |
| Ingress            | **七层 HTTP/HTTPS 路由**                                     |
| ConfigMap / Secret | **配置与敏感信息注入**                                       |
| Volume / PV / PVC  | **存储抽象**                                                 |
| Namespace          | 逻辑隔离与资源配额边界                                       |
| Label / Selector   | 松耦合的关联机制，Service/Deployment 都靠它找 Pod            |
| Annotation         | 非标识性元数据，供工具使用                                   |
| ServiceAccount     | Pod 访问 apiserver 的身份                                    |
| RBAC 四件套        | Role / ClusterRole / RoleBinding / ClusterRoleBinding        |
