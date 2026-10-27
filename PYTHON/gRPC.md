> gRPC 在云原生栈里越来越常见：OTel Collector、etcd、Envoy xDS、K8s CRI 都是 gRPC 接口。SRE 至少要会调、会探活、会排障。
>
> 协议，proto，客户端，服务端，超时与重试，健康检查，排障

------

### 和 REST 的区别

| 维度 | REST / JSON | gRPC |
| :-- | :-- | :-- |
| 传输 | HTTP/1.1（也可 HTTP/2） | **HTTP/2**（多路复用） |
| 载荷 | 文本 JSON | **二进制 protobuf**（更小更快） |
| 接口定义 | OpenAPI（可选） | **.proto 强契约** |
| 代码生成 | 一般手工写客户端 | **自动生成 stub** |
| 流式 | 不支持（或 SSE/WS） | **原生支持双向流** |
| 浏览器直连 | 天然支持 | 需 grpc-web 代理 |
| 排障 | `curl` | `grpcurl` |

一句话：**服务间内部通信用 gRPC，对外暴露用 REST**。

### 定义接口

```protobuf
// probe.proto
syntax = "proto3";
package probe.v1;

service Prober {
  rpc Check (CheckRequest) returns (CheckReply);
  rpc Watch (WatchRequest) returns (stream Event);   // 服务端流
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

message WatchRequest { string target = 1; }
message Event { string target = 1; bool ok = 2; }
```

```bash
python -m grpc_tools.protoc -I. \
  --python_out=. --grpc_python_out=. probe.proto
# 生成 probe_pb2.py（消息）和 probe_pb2_grpc.py（stub）
```

### 客户端

```python
import grpc
import probe_pb2, probe_pb2_grpc

# 1. 建 channel（长连接，复用）
channel = grpc.insecure_channel("collector:4317")
# TLS：
# channel = grpc.secure_channel("host:443", grpc.ssl_channel_credentials())

stub = probe_pb2_grpc.ProberStub(channel)

# 2. 调用：超时必须设，单位秒
try:
    reply = stub.Check(
        probe_pb2.CheckRequest(target="api", timeout_seconds=3),
        timeout=5,                              # 客户端超时
        metadata=[("authorization", f"Bearer {token}")],   # 相当于 HTTP header
    )
    print(reply.ok, reply.latency_ms, reply.message)
except grpc.RpcError as e:
    print(e.code(), e.details())                # 错误码 + 描述
```

```python
# 服务端流：边收边处理
for event in stub.Watch(probe_pb2.WatchRequest(target="api"), timeout=60):
    print(event.target, event.ok)
```

**gRPC 的错误码不是 HTTP 状态码**，常见几个：

| 码 | 含义 | 类比 HTTP |
| :-- | :-- | :-- |
| `OK` | 成功 | 200 |
| `INVALID_ARGUMENT` | 参数错 | 400 |
| `UNAUTHENTICATED` | 没认证 | 401 |
| `PERMISSION_DENIED` | 没权限 | 403 |
| `NOT_FOUND` | 不存在 | 404 |
| `DEADLINE_EXCEEDED` | **超时**（最常见） | 504 |
| `UNAVAILABLE` | 服务不可用 | 503 |
| `RESOURCE_EXHAUSTED` | 限流 | 429 |

```python
# 重试：只对可恢复的错误码重试
RETRYABLE = {grpc.StatusCode.UNAVAILABLE, grpc.StatusCode.DEADLINE_EXCEEDED}
```

### 服务端

```python
from concurrent import futures
import grpc, probe_pb2, probe_pb2_grpc

class Prober(probe_pb2_grpc.ProberServicer):
    def Check(self, request, context):
        ok = do_probe(request.target)
        if not ok:
            context.set_code(grpc.StatusCode.UNAVAILABLE)
            context.set_details(f"{request.target} 不可达")
        return probe_pb2.CheckReply(ok=ok, latency_ms=1.2)

server = grpc.server(futures.ThreadPoolExecutor(max_workers=16))
probe_pb2_grpc.add_ProberServicer_to_server(Prober(), server)
server.add_insecure_port("[::]:50051")
server.start(); server.wait_for_termination()
```

### 健康检查（K8s 探针会用）

gRPC 有标准健康检查协议 `grpc.health.v1.Health`，K8s 1.23+ 的 `grpc` 探针就是调它。

```python
from grpc_health.v1 import health, health_pb2_grpc

health_servicer = health.HealthServicer()
health_pb2_grpc.add_HealthServicer_to_server(health_servicer, server)
health_servicer.set("", health.HEALTH_SERVING)        # 整体状态
health_servicer.set("probe.v1.Prober", health.HEALTH_SERVING)  # 单个服务
```

```yaml
# K8s 里直接用 grpc 探针，不需要额外镜像
livenessProbe:
  grpc:
    port: 50051
    service: probe.v1.Prober      # 留空则查整体
```

老版本集群没有 grpc 探针时，用 `grpc_health_probe` 二进制做 exec 探针。

### 排障

```bash
# 装 grpcurl（gRPC 界的 curl）
brew install grpcurl

# 列出服务（需服务端开反射；没开就 -proto 指定文件）
grpcurl -plaintext localhost:50051 list
grpcurl -plaintext localhost:50051 list probe.v1.Prober

# 调方法
grpcurl -plaintext -d '{"target":"api"}' localhost:50051 probe.v1.Prober/Check

# 用 proto 文件（没开反射）
grpcurl -plaintext -import-path . -proto probe.proto \
  -d '{"target":"api"}' localhost:50051 probe.v1.Prober/Check

# 健康检查
grpcurl -plaintext localhost:50051 grpc.health.v1.Health/Check
```

常见故障对照：

| 现象 | 原因 |
| :-- | :-- |
| `DEADLINE_EXCEEDED` | 服务端处理慢，或超时设太短 |
| `UNAVAILABLE` | 连接不上：端口、TLS、服务未启动 |
| `UNIMPLEMENTED` | 方法名/服务名拼错，或客户端 proto 版本旧 |
| `failed to connect to all addresses` | 地址错或 DNS 解析失败 |
| 偶发 `UNAVAILABLE` | 长连接被 LB 断开，需配 keepalive |

```python
# 长连接被中间设备断开时，开 keepalive
channel = grpc.insecure_channel(
    "collector:4317",
    options=[
        ("grpc.keepalive_time_ms", 30_000),
        ("grpc.keepalive_timeout_ms", 10_000),
        ("grpc.keepalive_permit_without_calls", 1),
    ],
)
```

### 核心概念

1. **gRPC = HTTP/2 + protobuf + 强契约**，适合服务间通信，不适合浏览器直连。
2. **channel 要复用**，每次调用都新建 channel 会白白握手。
3. **`timeout` 必须显式设**，默认没有超时，会一直等。
4. **错误码是 gRPC 自己的**，不要照 HTTP 状态码理解；`DEADLINE_EXCEEDED` 和 `UNAVAILABLE` 最常见。
5. **健康检查用 `grpc.health.v1`**，K8s 的 `grpc` 探针依赖它。
6. **排障用 `grpcurl`**，服务端开反射会更方便。
7. **长连接要配 keepalive**，否则过 LB 时会被静默断开。
