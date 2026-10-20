> pod，探针，多容器







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
```



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
```



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

| 探针             | 失败后果                        | 用途                                         |
| :--------------- | :------------------------------ | :------------------------------------------- |
| `startupProbe`   | 重启容器                        | 保护启动慢的应用，成功后 liveness 才开始计时 |
| `livenessProbe`  | **重启容器**                    | 检测死锁/假死                                |
| `readinessProbe` | 从 Service 端点摘除，**不重启** | 检测能否对外服务                             |

**QoS 等级**（决定节点资源紧张时谁先被杀）：

| QoS          | 条件                                                     | 被驱逐优先级     |
| :----------- | :------------------------------------------------------- | :--------------- |
| `Guaranteed` | 所有容器都设了 requests 且等于 limits（CPU 和内存都要）  | 最低             |
| `Burstable`  | 至少一个容器设了 requests 或 limits，但不满足 Guaranteed | 中               |
| `BestEffort` | 所有容器都没设 requests/limits                           | 最高（最先被杀） |

**静态 Pod**：由 kubelet 直接管理，放在 `/etc/kubernetes/manifests/`，不受 apiserver 控制（控制平面组件就是这么跑的）。`kubectl get pod` 能看到但删不掉。