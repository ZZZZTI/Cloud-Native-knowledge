> 第 13 步：云原生接口。K8s、etcd、OTel Collector 都是 gRPC/HTTP API；把集群和云平台当接口调，是运维自动化的关键一步。
>
> gRPC 概念与调用，健康检查，grpcurl 排障，Kubernetes client，云厂商 SDK

------

## 1. gRPC 和 REST 的区别

| 维度 | REST / JSON | gRPC |
| :-- | :-- | :-- |
| 传输 | HTTP/1.1（也可 HTTP/2） | **HTTP/2 多路复用** |
| 载荷 | 文本 JSON | **二进制 protobuf**，更小更快 |
| 接口定义 | OpenAPI（可选） | **.proto 强契约** |
| 客户端 | 手工写 | **自动生成 stub** |
| 流式 | 不支持（或 SSE/WS） | **原生双向流** |
| 排障 | `curl` | `grpcurl` |

**一句话**：服务之间内部通信用 gRPC，对外暴露用 REST。

----- 

## 2. 定义接口

```protobuf
// probe.proto
syntax = "proto3";
package probe.v1;

service Prober {
  rpc Check (CheckRequest) returns (CheckReply);      // 一元调用
  rpc Watch (WatchRequest) returns (stream Event);    // 服务端流
}

message CheckRequest {
  string target = 1;
  int32 timeout_seconds = 2;
}

message CheckReply {
  bool ok = 1;
  double latency_ms = 2;
  string message = 3;
}
```

```bash
pip install grpcio grpcio-tools

python -m grpc_tools.protoc -I. \
  --python_out=. --grpc_python_out=. probe.proto
# 生成 probe_pb2.py（消息类）和 probe_pb2_grpc.py（stub）
```

----- 

## 3. 客户端调用

```python
import grpc
import probe_pb2, probe_pb2_grpc

# channel 是长连接，要复用，不要每次调用都新建
channel = grpc.insecure_channel("collector:50051")
# 需要 TLS 时：
# creds = grpc.ssl_channel_credentials()
# channel = grpc.secure_channel("collector:443", creds)

stub = probe_pb2_grpc.ProberStub(channel)

try:
    reply = stub.Check(
        probe_pb2.CheckRequest(target="api", timeout_seconds=3),
        timeout=5,                                          # ⚠️ 必须显式设超时
        metadata=[("authorization", f"Bearer {token}")],    # 相当于 HTTP header
    )
    print(reply.ok, reply.latency_ms, reply.message)
except grpc.RpcError as e:
    print(e.code(), e.details())
```

```python
# 服务端流：边收边处理
for event in stub.Watch(probe_pb2.WatchRequest(target="api"), timeout=60):
    print(event.target, event.ok)
```

### 错误码不是 HTTP 状态码

| gRPC 码 | 含义 | 类比 HTTP |
| :-- | :-- | :-- |
| `OK` | 成功 | 200 |
| `INVALID_ARGUMENT` | 参数错 | 400 |
| `UNAUTHENTICATED` | 没认证 | 401 |
| `PERMISSION_DENIED` | 没权限 | 403 |
| `NOT_FOUND` | 不存在 | 404 |
| `DEADLINE_EXCEEDED` | **超时**（最常见） | 504 |
| `UNAVAILABLE` | 服务不可用 | 503 |
| `RESOURCE_EXHAUSTED` | 限流 | 429 |
| `UNIMPLEMENTED` | 方法未实现 | 501 |

```python
# 只对可恢复的错误重试
RETRYABLE = {grpc.StatusCode.UNAVAILABLE, grpc.StatusCode.DEADLINE_EXCEEDED}
```

----- 

## 4. 服务端与健康检查

```python
from concurrent import futures
import grpc
import probe_pb2, probe_pb2_grpc

class Prober(probe_pb2_grpc.ProberServicer):
    def Check(self, request, context):
        ok = do_probe(request.target)
        if not ok:
            # 设置错误状态，客户端会拿到 UNAVAILABLE
            context.set_code(grpc.StatusCode.UNAVAILABLE)
            context.set_details(f"{request.target} 不可达")
        return probe_pb2.CheckReply(ok=ok, latency_ms=1.2)

server = grpc.server(futures.ThreadPoolExecutor(max_workers=16))
probe_pb2_grpc.add_ProberServicer_to_server(Prober(), server)
server.add_insecure_port("[::]:50051")
server.start()
server.wait_for_termination()
```

**标准健康检查协议**（K8s 1.23+ 的 `grpc` 探针就调它）：

```python
from grpc_health.v1 import health, health_pb2_grpc

health_servicer = health.HealthServicer()
health_pb2_grpc.add_HealthServicer_to_server(health_servicer, server)
health_servicer.set("", health.HEALTH_SERVING)                    # 整体
health_servicer.set("probe.v1.Prober", health.HEALTH_SERVING)     # 单个服务
```

```yaml
# K8s 里直接用，不需要额外镜像
livenessProbe:
  grpc:
    port: 50051
    service: probe.v1.Prober     # 留空则查整体
```

----- 

## 5. 排障：grpcurl

```bash
brew install grpcurl

# 列出服务（需要服务端开反射；没开就 -proto 指定文件）
grpcurl -plaintext localhost:50051 list
grpcurl -plaintext localhost:50051 list probe.v1.Prober

# 调用方法
grpcurl -plaintext -d '{"target":"api"}' localhost:50051 probe.v1.Prober/Check

# 用 proto 文件（没开反射时）
grpcurl -plaintext -import-path . -proto probe.proto \
  -d '{"target":"api"}' localhost:50051 probe.v1.Prober/Check

# 健康检查
grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check
```

| 现象 | 原因 |
| :-- | :-- |
| `DEADLINE_EXCEEDED` | 服务端慢，或超时设太短 |
| `UNAVAILABLE` / `failed to connect to all addresses` | 地址错、端口不通、TLS 配置不符 |
| `UNIMPLEMENTED` | 方法名拼错，或客户端 proto 版本旧 |
| 偶发 `UNAVAILABLE` | 长连接被 LB 断开，需要 keepalive |

```python
# 长连接过 LB 被静默断开时，开 keepalive
channel = grpc.insecure_channel("collector:4317", options=[
    ("grpc.keepalive_time_ms", 30_000),
    ("grpc.keepalive_timeout_ms", 10_000),
    ("grpc.keepalive_permit_without_calls", 1),
])
```

----- 

## 6. Kubernetes client

```python
from kubernetes import client, config

# 在 Pod 里跑用 incluster；本地调试回退到 kubeconfig
try:
    config.load_incluster_config()
except config.ConfigException:
    config.load_kube_config()

v1 = client.CoreV1Api()

# 列出所有未运行的 Pod
pods = v1.list_pod_for_all_namespaces(field_selector="status.phase!=Running")
for p in pods.items:
    print(p.metadata.namespace, p.metadata.name, p.status.phase)

# 读日志
print(v1.read_namespaced_pod_log("web-1", "prod", tail_lines=100))

# 在容器里执行命令
out = v1.connect_get_namespaced_pod_exec(
    "web-1", "prod", container="app",
    command=["sh", "-c", "df -h /"],
    stderr=True, stdout=True, stdin=False, tty=False,
)
print(out)

# 删除（会被控制器重建，等于重启）
v1.delete_namespaced_pod("web-1", "prod", grace_period_seconds=0)
```

```python
# 批量重启 Deployment 下的 Pod
apps = client.AppsV1Api()
apps.patch_namespaced_deployment(
    "web", "prod",
    {"spec": {"template": {"metadata": {"annotations": {
        "kubectl.kubernetes.io/restartedAt": "2026-10-27T10:00:00Z"
    }}}}},
)
```

**权限**：脚本用的 ServiceAccount 需要 `pods/get`、`pods/log`、`pods/exec` 等，**只给必需的**，别图省事绑 `cluster-admin`。

----- 

## 7. 云厂商 SDK

```python
# 腾讯云
import os
from tencentcloud.common import credential
from tencentcloud.cvm.v20170312 import cvm_client, models

cred = credential.Credential(
    os.environ["TENCENTCLOUD_SECRET_ID"],
    os.environ["TENCENTCLOUD_SECRET_KEY"],
)
client = cvm_client.CvmClient(cred, "ap-guangzhou")

req = models.DescribeInstancesRequest()
req.Limit = 100
resp = client.DescribeInstances(req)
```

```python
# AWS
import boto3

ec2 = boto3.client("ec2", region_name="ap-east-1")
for r in ec2.describe_instances()["Reservations"]:
    for i in r["Instances"]:
        print(i["InstanceId"], i["State"]["Name"])
```

**共同的三件事**：

1. **分页**：几乎每个 List 接口都有 `NextToken`/`Offset`，不处理就会漏数据。
2. **限流**：`Throttling` / `RequestLimitExceeded`，用 SDK 自带的重试配置。
3. **区域**：漏传 region 会用默认值，可能查到另一个区域的资源。

----- 

## 8. 本章检查清单

```python
# 1. gRPC 调用的超时怎么设
stub.Check(req, timeout=5)

# 2. K8s client 两种加载配置的方式
config.load_incluster_config()   # 集群内
config.load_kube_config()        # 本地

# 3. 云 SDK 必须处理的两件事
#    分页 + 限流重试

# 4. grpcurl 怎么调一个方法
grpcurl -plaintext -d '{"target":"api"}' host:50051 probe.v1.Prober/Check
```

----- 

## 核心概念

1. **gRPC = HTTP/2 + protobuf + 强契约**，适合服务间通信。
2. **channel 要复用**，`timeout` 必须显式设。
3. **gRPC 错误码是它自己的一套**，`DEADLINE_EXCEEDED`/`UNAVAILABLE` 最常见。
4. **健康检查用 `grpc.health.v1`**，K8s 的 `grpc` 探针依赖它。
5. **排障用 `grpcurl`**，服务端开反射会更方便。
6. **K8s client 集群内用 incluster 配置**，SA 权限只给必需。
7. **云 SDK 必处理分页与限流**，否则大账号下必然漏数据。
