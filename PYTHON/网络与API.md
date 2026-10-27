> SRE 的脚本大多在跟 HTTP API 打交道：查监控、调云平台、触发发布、探活。这一篇讲怎么写得稳。
>
> 端口探测，requests，httpx，重试，认证，分页与限流，健康检查

------

### 先看 TCP 层：脚本探活

```python
import socket

def port_open(host: str, port: int, timeout: float = 2.0) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(timeout)          # 必须有，否则可能挂几分钟
        return s.connect_ex((host, port)) == 0

for host in ["10.0.0.1", "10.0.0.2"]:
    for port in (22, 6443, 9100):
        print(host, port, "open" if port_open(host, port) else "closed")
```

`connect_ex` 返回错误码而不是抛异常，批量探测时更顺手。

### requests：同步场景的默认选择

```python
import requests

# 一定要设 timeout：单值作用于连接+读取，元组分别设置
r = requests.get("https://api.example.com/v1/pods",
                 params={"namespace": "prod", "limit": 100},
                 headers={"Authorization": f"Bearer {TOKEN}"},
                 timeout=(3.05, 10))
r.raise_for_status()                 # 4xx/5xx 抛异常，别只判断 status_code
data = r.json()
```

```python
# 复用连接：批量调用必须用 Session，否则每次重建 TCP + TLS，慢一个数量级
with requests.Session() as s:
    s.headers.update({"Authorization": f"Bearer {TOKEN}"})
    for ns in ["dev", "test", "prod"]:
        r = s.get(f"https://api.example.com/v1/pods", params={"namespace": ns}, timeout=10)
        r.raise_for_status()
```

### 重试：网络抖动必须自动处理

```python
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def make_session() -> requests.Session:
    s = requests.Session()
    retry = Retry(
        total=5,
        backoff_factor=0.5,                       # 0.5s,1s,2s,4s...
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET", "HEAD", "PUT", "DELETE"],   # 幂等方法才重试
        raise_on_status=False,
    )
    s.mount("https://", HTTPAdapter(max_retries=retry, pool_maxsize=50))
    s.mount("http://",  HTTPAdapter(max_retries=retry, pool_maxsize=50))
    return s
```

**只对幂等操作重试**：`GET`/`PUT`/`DELETE` 可以，`POST` 可能重复创建资源。

### httpx：需要异步时用它

```python
import httpx

# 同步用法和 requests 几乎一样
with httpx.Client(base_url="https://api.example.com", timeout=10) as c:
    r = c.get("/v1/pods", headers={"Authorization": f"Bearer {TOKEN}"})
    r.raise_for_status()

# 异步：配合 asyncio 做高并发
import asyncio

async def main():
    async with httpx.AsyncClient(base_url="https://api.example.com", timeout=10) as c:
        rs = await asyncio.gather(*[c.get(f"/v1/ns/{ns}") for ns in ("dev","test","prod")])
        for r in rs:
            print(r.status_code, len(r.json()))

asyncio.run(main())
```

### 认证方式

```python
# Bearer Token（最常见）
headers = {"Authorization": f"Bearer {token}"}

# Basic
r = requests.get(url, auth=("user", "pass"), timeout=10)

# 自定义 Header（很多云平台用）
headers = {"X-Auth-Token": token, "Content-Type": "application/json"}

# 云厂商签名（AWS SigV4 等）
# 不要自己实现，用官方 SDK
```

**凭据来源**：优先环境变量或密钥管理服务，禁止硬编码进脚本、更不要提交进仓库。

```python
import os
token = os.environ["API_TOKEN"]        # KeyError 好过静默用空值
```

### 分页与限流

```python
def list_all(session, url, page_size=100):
    """通用游标分页拉取。"""
    params = {"limit": page_size}
    while True:
        r = session.get(url, params=params, timeout=10)
        r.raise_for_status()
        body = r.json()
        yield from body.get("items", [])
        cursor = body.get("next")
        if not cursor:
            return
        params["cursor"] = cursor
```

碰到 429 时**看 `Retry-After` 头**再等，不要固定 sleep：

```python
if r.status_code == 429:
    time.sleep(int(r.headers.get("Retry-After", 5)))
```

### 实战：服务健康检查

```python
import requests, sys

CHECKS = [
    ("api",    "https://api.example.com/healthz"),
    ("web",    "https://www.example.com/"),
]

def check(name: str, url: str) -> bool:
    try:
        r = requests.get(url, timeout=5)
        ok = r.status_code == 200
    except requests.RequestException as e:
        print(f"[FAIL] {name}: {e.__class__.__name__}")
        return False
    print(f"[{'OK' if ok else 'FAIL'}] {name}: {r.status_code} {r.elapsed.total_seconds():.2f}s")
    return ok

if __name__ == "__main__":
    results = {name: check(name, url) for name, url in CHECKS}
    sys.exit(0 if all(results.values()) else 1)   # 退出码给监控系统用
```

**脚本的退出码决定监控是否告警**：成功返回 0，失败返回非 0，别总是 `exit(0)`。

### 常见坑

```python
# ❌ 不设 timeout：默认无限等，一次网络故障就能挂死整个巡检
requests.get(url)

# ❌ 直接 r.json()：返回 HTML 错误页时抛 JSONDecodeError
r.json()

# ✅ 先判内容类型或做异常兜底
try:
    data = r.json()
except ValueError:
    data = {"raw": r.text[:500]}

# ❌ 关掉证书校验
requests.get(url, verify=False)        # 只应出现在离线测试

# ❌ 每次循环新建 Session
for u in urls:
    requests.get(u)                    # 连接不复用，慢且耗 fd
```

### 核心概念

1. **所有请求必须有 `timeout`**，单值或 `(连接, 读取)` 元组都行，就是不能没有。
2. **批量调用用 `Session`/`Client` 复用连接**，性能差一个数量级。
3. **重试只对幂等方法开**，`POST` 重试可能造成重复资源。
4. **先 `raise_for_status()` 或显式判状态码**，再解析 body。
5. **分页用 `while` + 游标**，不要假设一页能拿完。
6. **429 按 `Retry-After` 退避**，不要硬编码 sleep。
7. **凭据从环境变量/密钥服务读**，绝不写死在代码里。
8. **脚本退出码要能反映结果**，这是接入监控的前提。
