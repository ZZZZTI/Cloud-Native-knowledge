> Kubernetes（K8s）是一个开源的容器编排平台，用于自动化部署、扩缩容和管理容器化应用，保障其高可用与弹性运行。

------

### kubectl

```Shell
# ========== 基础信息 ==========
kubectl version --client                 # 查看客户端版本
kubectl cluster-info                     # 查看集群信息
kubectl api-resources                    # 查看支持的资源类型
kubectl explain pod.spec                 # 查看资源字段说明
kubectl config get-contexts              # 查看上下文
kubectl config use-context <ctx>         # 切换上下文
kubectl config set-context --current --namespace=<ns>  # 切换默认命名空间

# ========== 查看资源 ==========
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

# ========== 描述与排查 ==========
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

# ========== 创建、更新、删除 ==========
kubectl apply -f app.yaml                # 声明式创建/更新
kubectl create -f app.yaml               # 创建资源
kubectl delete -f app.yaml               # 删除资源
kubectl delete pod <pod> -n <ns>
kubectl delete pod <pod> -n <ns> --force --grace-period=0  # 强制删除，慎用
kubectl edit deploy/<name> -n <ns>       # 在线编辑
kubectl patch deploy/<name> -n <ns> --type='json' -p='[{"op":"replace","path":"/spec/replicas","value":3}]'
kubectl label pod <pod> -n <ns> env=prod
kubectl annotate pod <pod> -n <ns> owner=team-a

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
--watch / -w         # 监听变化
--help               # 查看帮助
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
                                       │ API 调用（HTTPS :6443）
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

| 组件              | 职责                                            | 关键点                                        |
| :---------------- | :---------------------------------------------- | :-------------------------------------------- |
| `kubelet`         | 节点代理，管理 Pod 生命周期、上报状态、执行探针 | 监听 10250；日志 `journalctl -u kubelet`      |
| `kube-proxy`      | 实现 Service 的负载均衡与转发规则               | iptables / ipvs / nftables 模式               |
| Container Runtime | 真正创建和运行容器                              | 通过 CRI 接口被 kubelet 调用；常用 containerd |

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

| 概念               | 说明                                                        |
| :----------------- | :---------------------------------------------------------- |
| Pod                | 最小调度单元，一个或多个共享 Network/Volume 的容器          |
| ReplicaSet         | 保证指定数量的 Pod 副本（一般由 Deployment 托管，不直接用） |
| Deployment         | 无状态工作负载，支持滚动更新与回滚                          |
| StatefulSet        | 有状态工作负载，Pod 有稳定序号、网络标识和独立存储          |
| DaemonSet          | 每个（或指定）节点运行一个 Pod，用于日志/监控/网络插件      |
| Job / CronJob      | 一次性任务 / 定时任务                                       |
| Service            | 为一组 Pod 提供稳定 VIP 与负载均衡                          |
| Ingress            | 七层 HTTP/HTTPS 路由                                        |
| ConfigMap / Secret | 配置与敏感信息注入                                          |
| Volume / PV / PVC  | 存储抽象                                                    |
| Namespace          | 逻辑隔离与资源配额边界                                      |
| Label / Selector   | 松耦合的关联机制，Service/Deployment 都靠它找 Pod           |
| Annotation         | 非标识性元数据，供工具使用                                  |
| ServiceAccount     | Pod 访问 apiserver 的身份                                   |
| RBAC 四件套        | Role / ClusterRole / RoleBinding / ClusterRoleBinding       |

**期望状态 vs 实际状态**：`kubectl get` 看到的是 etcd 里的期望状态，`kubectl describe` 里的 Events 与容器状态才是实际状态。排障就是找这两者的差异。
