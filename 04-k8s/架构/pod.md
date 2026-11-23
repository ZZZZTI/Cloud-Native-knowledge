> pod：生命周期，多容器，重启策略，探针，资源
>

------

### 核心概念

```Shell
1.pod是k8s中最小调度单位：同Pod内的容器共享 network namespace（同一IP、端口不能冲突）、IPC、UTS，Volume

2.pause 容器（沙箱）：每个 Pod 有一个看不见的 pause 容器持有网络命名空间，业务容器挂在它上面。

3.静态 Pod由 kubelet 直接管理，/etc/kubernetes/manifests/,不经过 apiserver 调度（控制平面组件）

4.资源：requests决定调度与 QoS，limits决定运行时上限；CPU 超限被 throttle，内存超限被 OOMKilled。

5.优雅终止：terminationGracePeriodSeconds（默认 30s）→ 收到 SIGTERM → 执行 preStop → 超时 SIGKILL。

# Pod 生命周期
Pod 状态	         含义	                  常见原因
Pending	          调度器还没找到节点	      资源不足 / 亲和性 / 污点 / PVC 未绑
ContainerCreating	节点已选，正在拉镜像/挂卷	 镜像拉取慢 / 卷挂载慢
Running	          至少一个容器在跑	        正常
Succeeded        	所有容器正常退出（Job）  	正常
Failed	          至少一个容器异常退出	    应用报错
CrashLoopBackOff	容器反复崩溃重启	        前台进程退出 / liveness 探针太激进 /...
ImagePullBackOff	镜像拉不下来	           tag 错 / 网络 / 架构
Terminating	      正在删除	              正常删除流程      

# 探针
探针	            作用	                失败后果	                             典型用途
startupProbe	   判断容器是否启动完成	    超过阈值后重启容器	                     慢启动应用
livenessProbe	   判断容器是否还活着	      连续失败达到failureThreshold后重启容器   进程假死、死锁
readinessProbe	 判断容器是否准备好接流量	 从ServiceEndpointSlice摘除，不重启	     依赖未就绪、临时不可用

# 多容器模式
模式	           说明	                 典型用途
Init Container	主容器启动前执行完退出 	  等待依赖、初始化数据，拉配置
Sidecar	        辅助主容器	            日志、监控、代理
Ambassador	    代理外部连接	          数据库代理、服务发现
Adapter	        转换输出格式	          日志标准化、指标暴露，转成 Prometheus 格式
```

### Pod.yaml

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web                          # Pod 名称，同 namespace 内唯一
  labels:
    app: web                         # 标签，Service/Deployment 的 selector 靠它匹配
spec:
  restartPolicy: Always              # 容器退出后重启策略：Always / OnFailure / Never；Job 用 OnFailure/Never
  terminationGracePeriodSeconds: 30  # 发 SIGTERM 后给容器优雅退出的秒数，超时 SIGKILL
  serviceAccountName: web-sa         # Pod 使用的 ServiceAccount，决定访问 apiserver 的 RBAC 权限
  automountServiceAccountToken: false # 不挂载 SA token；不访问 apiserver 就关掉，减小攻击面
  imagePullSecrets:                  # 拉私有镜像用的凭据（docker-registry 类型 Secret）
    - name: regcred
  securityContext:                   # Pod 级安全上下文，对本 Pod 所有容器生效（容器级可覆盖）
    runAsNonRoot: true               # 强制非 root 运行；镜像 USER 是 root 会直接启动失败
    runAsUser: 1000                  # 指定运行 UID
    fsGroup: 2000                    # 挂载卷的属组；只对支持它的卷类型生效（emptyDir/PVC 等）
    seccompProfile:
      type: RuntimeDefault           # 使用运行时默认 seccomp 白名单，削减系统调用攻击面
  initContainers:                    # 初始化容器：串行执行，全部成功主容器才启动
    - name: init-db
      image: busybox:1.36
      command: ['sh', '-c', 'until nc -z db 3306; do sleep 2; done']  # 等 db:3306 可连再继续
  containers:
    - name: app
      image: registry.example.com/web:1.2.3   # 禁用 latest，写全 registry + 明确 tag
      imagePullPolicy: IfNotPresent           # Always / IfNotPresent / Never；latest 时默认 Always
      command: ["/app/server"]                # 覆盖镜像 ENTRYPOINT
      args: ["--port=8080"]                   # 覆盖镜像 CMD，作为 command 的参数
      ports:
        - name: http                          # 命名端口，探针/Service 可用名字引用
          containerPort: 8080                 # 声明监听端口（仅信息性，不拦截流量）
      env:                                    # 单个环境变量
        - name: DB_HOST
          value: "mysql.default.svc.cluster.local"  # 集群内 Service 的 FQDN
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:                     # 从 Secret 取值，避免明文写进 YAML/镜像
              name: db-secret
              key: password
      envFrom:                                # 批量注入：ConfigMap 每个 key 变成一个环境变量
        - configMapRef:
            name: app-config
      # 资源设置（requests==limits 时 QoS=Guaranteed 最稳）
      resources:                              # 资源请求/限制；生产必须设
        requests:                             # 调度依据，保证的最小资源
          cpu: 100m
          memory: 128Mi
        limits:                               # 上限：超 CPU 被限流，超内存被 OOMKill
          cpu: 500m
          memory: 512Mi
      # 探针设置
      startupProbe:                           # 启动探针：成功前 liveness/readiness 不生效，防慢启动被误杀
        httpGet: { path: /healthz, port: http }
        failureThreshold: 30                  # 最多容忍 30 次失败
        periodSeconds: 10                     # 每 10s 一次 → 最长给 300s 启动时间
      livenessProbe:                          # 存活探针：失败 → 重启容器
        httpGet: { path: /healthz, port: http }
        initialDelaySeconds: 10
        periodSeconds: 10
        timeoutSeconds: 3
        failureThreshold: 3                   # 连续 3 次失败才重启，避免抖动
      readinessProbe:                         # 就绪探针：失败 → 从 Service Endpoints 摘除（不重启）
        httpGet: { path: /ready, port: http }
        periodSeconds: 5
      lifecycle:
        preStop:
          exec:
            command: ["sh", "-c", "sleep 5"]  # 先 sleep 等 kube-proxy/Ingress 摘除端点，再收 SIGTERM
      securityContext:                        # 容器级安全上下文，覆盖 Pod 级
        allowPrivilegeEscalation: false       # 禁止 setuid 等提权
        readOnlyRootFilesystem: true          # 根文件系统只读；需写入的目录必须挂 volume
        capabilities:
          drop: ["ALL"]                       # 丢弃全部 Linux capabilities，按需再加
      volumeMounts:                           # 容器内挂载点
        - name: config
          mountPath: /etc/app
          readOnly: true                      # 配置只读挂载
        - name: cache
          mountPath: /tmp                     # 根文件系统只读后，临时目录必须挂出来
  volumes:                                    # Pod 级卷定义，供容器挂载
    - name: config
      configMap: { name: app-config }         # 把 ConfigMap 以文件形式挂载
    - name: cache
      emptyDir: {}                            # 节点本地临时目录，Pod 删除即清空


  # ===== 特殊字段 =====
  hostNetwork: true                   # 用宿主机网络栈；排障/网络插件常用，普通业务慎用
  hostPID: true                       # 共享宿主机 PID namespace，能看到宿主机所有进程（node-exporter 类）
  hostIPC: true                       # 共享宿主机 IPC namespace
  dnsPolicy: ClusterFirstWithHostNet  # hostNetwork 时必须配，否则解析不到 Service
  # 可选值：ClusterFirst（默认）/ Default（用宿主机 resolv.conf）
  #        ClusterFirstWithHostNet / None（必须自己配 dnsConfig）
  shareProcessNamespace: true         # 同 Pod 内容器互相看到进程（默认每容器独立 PID namespace）
  hostAliases:                        # 往 /etc/hosts 加记录，不想动 DNS 时用
    - ip: "10.0.0.10"
      hostnames: ["db.internal", "db"]
  hostname: web-0                     # 容器内 hostname；与 StatefulSet 的 Pod 名一致才有稳定 DNS 意义
  subdomain: web-headless             # 配合 headless Service，解析为 web-0.web-headless.<ns>.svc.cluster.local
  priorityClassName: high-priority    # 优先级，配合抢占；高优先级可驱逐低优先级 Pod
  runtimeClassName: nvidia            # 指定 RuntimeClass，GPU 场景选 nvidia 运行时
  activeDeadlineSeconds: 3600         # Pod 运行超时被终止（一般配合 Job 使用）
```

### Namespace.yaml

```Shell
# 命名空间：逻辑隔离集群资源，方便多团队/多环境管理
apiVersion: v1
kind: Namespace
metadata:
  name: demo-namespace
```

