> 第 12 步：网络。运维脚本大多在跟 HTTP API 打交道：查监控、调云平台、触发发布、探活。
> 这一章的重点不是「能发请求」，而是「发得稳」。
>
> socket 探活，requests，Session 复用，重试，httpx 异步，认证，分页与限流

------

## 1. 从 TCP 开始：端口探活

```python
import socket

def port_open(host: str, port: int, timeout: float = 2.0) -> bool:
    """检查端口是否可连。"""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(timeout)          # ⚠️ 必须设，否则可能挂几十秒
        # connect_ex 返回错误码而不是抛异常，批量探测更顺手
        return s.connect_ex((host, port)) == 0

for port in (22, 6443, 9100):
    print(port, "open" if port_open("10.0.0.1", port) else "closed")
```

**`connect_ex` 为什么好用**：返回 `0` 表示成功，非 0 是 errno（`111` 拒绝连接、`110` 超时）。不抛异常就不用每个都包 try。

----- 

## 2. requests：同步场景的默认选择

```python
import requests

r = requests.get(
    "https://api.example.com/v1/pods",
    params={"namespace": "prod", "limit": 100},        # 自动拼接成 query string
    headers={"Authorization": "Bearer xxx"},
    timeout=(3.05, 10),                                # (连接超时, 读取超时)
)
r.raise_for_status()          # 4xx/5xx 抛异常，别只判断 status_code
data = r.json()

print(r.status_code)          # 200
print(r.elapsed.total_seconds())
print(r.headers.get("Content-Type"))
```

### 必须先判状态码再解析

```python
r = requests.get(url, timeout=10)

if r.status_code != 200:
    # 4xx/5xx 的响应体通常不是你要的 JSON
    print("非预期状态:", r.status_code, r.text[:200])
    raise RuntimeError("请求失败")

try:
    data = r.json()
except ValueError:
    print("返回的不是 JSON:", r.text[:200])
    data = {}
```

### 复用连接：批量调用必须用 Session

```python
# ❌ 每次新建连接：TCP + TLS 握手开销，慢一个数量级
for ns in namespaces:
    requests.get(f"https://api.example.com/pods?ns={ns}", timeout=10)

# ✅ 复用连接池
with requests.Session() as s:
    s.headers.update({"Authorization": "Bearer xxx"})
    for ns in namespaces:
        r = s.get("https://api.example.com/pods", params={"ns": ns}, timeout=10)
        r.raise_for_status()
```

----- 

## 3. 重试：网络抖动必须自动处理

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def make_session() -> requests.Session:
    s = requests.Session()
    retry = Retry(
        total=5,                                      # 总重试次数
        backoff_factor=0.5,                           # 退避：0.5,1,2,4s
        status_forcelist=[429, 500, 502, 503, 504],   # 这些状态码触发重试
        allowed_methods=["GET", "HEAD", "PUT", "DELETE"],   # ⚠️ 幂等方法才重试
        raise_on_status=False,
    )
    adapter = HTTPAdapter(max_retries=retry, pool_maxsize=50)
    s.mount("https://", adapter)
    s.mount("http://", adapter)
    return s
```

**为什么只对幂等方法重试**：`POST` 重试可能创建出两个资源。要重试 `POST`，得靠**幂等键**（request id）来去重。

----- 

## 4. httpx：需要异步时用它

```python
import httpx

# 同步用法和 requests 几乎一致
with httpx.Client(base_url="https://api.example.com", timeout=10) as c:
    r = c.get("/v1/pods", headers={"Authorization": "Bearer xxx"})
    r.raise_for_status()
```

```python
# 异步：配合 asyncio 做高并发
import asyncio, httpx

async def main():
    async with httpx.AsyncClient(base_url="https://api.example.com", timeout=10) as c:
        sem = asyncio.Semaphore(20)

        async def fetch(ns):
            async with sem:
                r = await c.get(f"/v1/pods/{ns}")
                return ns, r.json()

        results = await asyncio.gather(
            *(fetch(ns) for ns in ("dev", "test", "prod"))
        )
        for ns, data in results:
            print(ns, len(data.get("items", [])))

asyncio.run(main())
```

```
            requests  httpx
同步        ✅        ✅
异步        ❌        ✅
HTTP/2      需额外包  ✅ 内置
生态成熟度  最成熟    较新但够用
```

**结论**：只做同步用 `requests`；要并发拉几百个接口用 `httpx.AsyncClient`。

----- 

## 5. 认证方式

```python
# Bearer Token（最常见）
headers = {"Authorization": f"Bearer {token}"}

# Basic Auth
r = requests.get(url, auth=("user", "password"), timeout=10)

# 自定义 Header（很多云平台）
headers = {
    "X-Auth-Token": token,
    "Content-Type": "application/json",
}

# 云厂商签名（AWS SigV4、腾讯云 TC3）
# ❌ 不要自己实现；✅ 用官方 SDK
```

**凭据从哪来**：

```python
import os

token = os.environ["API_TOKEN"]        # 必需项：缺失就 KeyError，早失败
timeout = int(os.environ.get("API_TIMEOUT", "10"))   # 可选项：给默认值
```

禁止把 token 写进代码、更不要提交进仓库。`git log` 里出现过一次的密钥就等于泄露。

----- 

## 6. 分页：不要假设一页能拿完

```python
def iter_all(session, url: str, page_size: int = 100):
    """通用游标分页：逐页产出，不一次性加载全部。"""
    params = {"limit": page_size}
    while True:
        r = session.get(url, params=params, timeout=10)
        r.raise_for_status()
        body = r.json()

        yield from body.get("items", [])

        cursor = body.get("next") or body.get("continue")
        if not cursor:
            break
        params["cursor"] = cursor
```

```python
# 使用
with make_session() as s:
    pods = list(iter_all(s, "https://api.example.com/v1/pods"))
print("总条数:", len(pods))
```

两种常见分页模型：

```
模型                     参数                判断结束
游标（cursor/continue）  cursor=xxx          返回为空
偏移（offset/limit）     offset=n&limit=100  返回条数 < limit
```

⚠️ 偏移分页在数据变动时**会漏或重复**，能用游标就别用偏移。

----- 

## 7. 限流：429 要按对方要求等

```python
import time

def get_with_backoff(session, url, **kw):
    for attempt in range(5):
        r = session.get(url, **kw)
        if r.status_code != 429:
            return r
        wait = int(r.headers.get("Retry-After", 2 ** attempt))   # 优先听对方的
        print(f"被限流，{wait}s 后重试")
        time.sleep(wait)
    raise RuntimeError("重试耗尽")
```

**不要让固定 `sleep(1)` 变成主要策略**：遵守 `Retry-After` 才是对上游友好、也最不容易被封的做法。

----- 

## 8. 实战：服务健康检查脚本

```python
#!/usr/bin/env python3
"""检查多个服务，任一异常则退出码 1。"""
import sys
import requests

CHECKS = [
    ("api",  "https://api.example.com/healthz"),
    ("web",  "https://www.example.com/"),
    ("docs", "https://docs.example.com/"),
]

def check(name: str, url: str) -> bool:
    try:
        r = requests.get(url, timeout=5)
        ok = r.status_code == 200
        print(f"[{'OK' if ok else 'FAIL'}] {name}: "
              f"{r.status_code} {r.elapsed.total_seconds():.2f}s")
        return ok
    except requests.Timeout:
        print(f"[FAIL] {name}: 超时")
    except requests.RequestException as e:
        print(f"[FAIL] {name}: {e.__class__.__name__}")
    return False

def main() -> int:
    results = {name: check(name, url) for name, url in CHECKS}
    failed = [n for n, ok in results.items() if not ok]
    if failed:
        print("失败服务:", ", ".join(failed))
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
```

**退出码决定监控是否告警**：成功 0、失败非 0。总是 `exit(0)` 的脚本接进监控等于没接。

----- 

## 9. 本章检查清单

```python
# 1. 给请求加超时
requests.get(url, timeout=(3.05, 10))

# 2. 批量调用不要每次新建连接
with requests.Session() as s: ...

# 3. 只对幂等方法重试
allowed_methods=["GET", "HEAD", "PUT", "DELETE"]

# 4. 先判状态码再 .json()
r.raise_for_status()

# 5. 429 听 Retry-After
```

----- 

## 核心概念

1. **所有请求必须有 `timeout`**，`(连接, 读取)` 元组最稳。
2. **批量调用用 `Session`/`Client` 复用连接**，性能差一个数量级。
3. **重试只对幂等方法开**，`POST` 重试会造成重复创建。
4. **先 `raise_for_status()` 再 `.json()`**，否则错误页会解析失败。
5. **分页用 while + 游标**，不要假设一页拿完；能用游标就别用偏移。
6. **429 按 `Retry-After` 退避**，固定 sleep 不是好策略。
7. **凭据从环境变量读**，绝不写死在代码里。
8. **退出码要反映结果**，这是接入监控的前提。
