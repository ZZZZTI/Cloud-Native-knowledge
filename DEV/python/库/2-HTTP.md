> 第 3 类：HTTP / API 与告警集成。运维脚本 90% 的外部交互都走这里——调监控、发告警、查 CMDB。
>

------

## 1. requests ★★★ —— 调各类 HTTP API 的首选

默认选择。核心是四件事：**超时、Session 复用、状态码判断、重试**。

### 常用请求参数

```
requests.get/post/put/delete/patch(url, **kw)

url              完整地址
params={...}     拼到 query string（自动 urlencode，会覆盖 url 里已有的同名参数）
data={...}       表单提交（application/x-www-form-urlencoded）
json={...}       JSON 提交（自动带 Content-Type: application/json）
headers={...}    请求头
cookies={...}    Cookie
auth=(user, pwd) Basic 认证
timeout=10       超时秒数；推荐用元组 (连接超时, 读取超时)
allow_redirects  是否跟随重定向（默认 True）
verify=True      TLS 校验，False 关闭（不要在生产用）
cert=("/path/c.pem", "/path/k.pem")   客户端证书
proxies={"https": "http://proxy:8080"}
stream=True      流式下载大文件
```

### 响应对象

```
r.status_code        状态码
r.ok                 等价于 status_code < 400
r.headers            响应头（大小写不敏感）
r.text               解码后的文本
r.content            原始字节
r.json()             解析 JSON（失败抛 ValueError）
r.url                最终 URL（跟随重定向后）
r.elapsed.total_seconds()   耗时
r.cookies            响应 Cookie
r.history            重定向历史
r.raise_for_status() 4xx/5xx 抛 HTTPError
r.iter_content(chunk_size=8192)   流式读取块
```

```Python
import requests

# ==== 标准写法：四件事一个都不能少 ====
try:
    r = requests.get(
        "https://api.example.com/v1/pods",
        params={"namespace": "prod", "limit": 100},
        headers={"Authorization": f"Bearer {token}"},
        timeout=(3.05, 10),        # 连接 3 秒，读取 10 秒
    )
    r.raise_for_status()           # 先判状态码，再解析
    data = r.json()
except requests.Timeout:
    print("超时")
except requests.HTTPError as e:
    print(f"HTTP {e.response.status_code}: {e.response.text[:200]}")
except requests.RequestException as e:
    print(f"请求失败: {e.__class__.__name__}")
```

### Session：批量调用必须用

```Python
# ❌ 每次新建连接，TCP + TLS 握手开销，慢一个数量级
for ns in namespaces:
    requests.get(f"https://api.example.com/pods?ns={ns}", timeout=10)

# ✅ 复用连接池
with requests.Session() as s:
    s.headers.update({"Authorization": f"Bearer {token}"})   # 公共头设一次
    for ns in namespaces:
        r = s.get("https://api.example.com/pods", params={"ns": ns}, timeout=10)
        r.raise_for_status()
```

### 重试：交给 urllib3 的 Retry

```Python
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def make_session(token: str) -> requests.Session:
    s = requests.Session()
    s.headers.update({"Authorization": f"Bearer {token}"})
    retry = Retry(
        total=5,                                   # 总重试次数
        backoff_factor=0.5,                        # 退避：0.5, 1, 2, 4 秒
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET", "HEAD", "PUT", "DELETE"],   # 只对幂等方法重试
        raise_on_status=False,
    )
    adapter = HTTPAdapter(max_retries=retry, pool_maxsize=50)
    s.mount("https://", adapter)
    s.mount("http://", adapter)
    return s
```

⚠️ 坑：

- **所有请求必须有 `timeout`**，requests 默认没有超时，会永久挂住
- `POST` 不要重试，可能创建出两份资源；要重试得靠幂等键
- `r.json()` 前先 `raise_for_status()`，否则错误页也会去解析
- `verify=False` 会带来中间人风险，只用于临时排查
- 大文件必须 `stream=True` + `iter_content`，否则整个读进内存

```Python
# ==== 大文件下载 ====
with requests.get(url, stream=True, timeout=(5, 60)) as r:
    r.raise_for_status()
    with open("big.tar.gz", "wb") as f:
        for chunk in r.iter_content(chunk_size=1 << 20):   # 1MB 一块
            f.write(chunk)
```

------

## 2. httpx ★★ —— 同步+异步 HTTP

同步用法和 requests 几乎一样，**真正的价值是 `AsyncClient`**。

```
httpx.Client(base_url=, timeout=, headers=, follow_redirects=, limits=, http2=)
httpx.AsyncClient(...)             同上，可 await
client.get/post/...(...)           同 requests
client.stream("GET", url)          流式
httpx.Timeout(connect=, read=, write=, pool=)
httpx.Limits(max_connections=, max_keepalive_connections=)
```

```Python
import asyncio
import httpx

async def fetch_all(namespaces: list[str]) -> dict:
    """并发拉多个命名空间。"""
    # 连接池上限 + 超时在这里统一设
    limits = httpx.Limits(max_connections=20, max_keepalive_connections=10)
    timeout = httpx.Timeout(connect=3.0, read=10.0, write=10.0, pool=5.0)

    async with httpx.AsyncClient(
        base_url="https://api.example.com",
        headers={"Authorization": f"Bearer {token}"},
        timeout=timeout,
        limits=limits,
        follow_redirects=True,
    ) as client:
        sem = asyncio.Semaphore(10)          # 限流

        async def one(ns: str):
            async with sem:
                r = await client.get(f"/v1/pods/{ns}")
                r.raise_for_status()
                return ns, r.json()

        results = await asyncio.gather(
            *(one(ns) for ns in namespaces),
            return_exceptions=True,          # 一个失败不影响其他
        )
    return {ns: data for ns, data in results if isinstance(results, list)}

asyncio.run(fetch_all(["dev", "test", "prod"]))
```

```
选型              用 requests       用 httpx
同步                 ✅                ✅
异步                 ❌                ✅
HTTP/2              需额外包          内置
生态成熟度          最成熟            够用
```

------

## 3. urllib.request / parse / http.client ★★ —— 标准库 HTTP，简单场景不引第三方

不装第三方时的兜底（如目标机器不能联网装包）。

```
urllib.request.urlopen(url, timeout=5, data=None, headers={})
urllib.request.Request(url, data=, headers=, method="POST")
urllib.parse.urlencode({...})        dict → query string
urllib.parse.quote(s) / unquote(s)   URL 编码 / 解码
urllib.parse.urlparse(url)           拆解 URL（scheme/netloc/path/query）
urllib.parse.parse_qs(query)         query string → dict（值是 list）
urllib.error.HTTPError               4xx/5xx（也是响应对象，有 .read()）
urllib.error.URLError                连不上、DNS 失败等
```

```Python
import json
import urllib.error
import urllib.parse
import urllib.request

url = "https://api.example.com/v1/pods?" + urllib.parse.urlencode({"namespace": "prod"})
req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})

try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        body = json.loads(resp.read().decode("utf-8"))
        print(resp.status, body)
except urllib.error.HTTPError as e:
    print(e.code, e.read()[:200])       # 错误响应体在 e 上
except urllib.error.URLError as e:
    print("连接失败:", e.reason)

# POST JSON
data = json.dumps({"name": "web"}).encode()
req = urllib.request.Request(
    "https://api.example.com/v1/deploy",
    data=data,
    headers={"Content-Type": "application/json"},
    method="POST",
)
```

⚠️ `parse_qs` 返回值是 `{"k": ["v"]}`，取值要 `d["k"][0]`。

------

## 4. smtplib / email ★★ —— 邮件告警

```
smtplib.SMTP(host, port)            明文（通常 25）
smtplib.SMTP_SSL(host, port)        直接 TLS（通常 465）
smtp.starttls()                     升级到 TLS（通常 587，先 connect 再 starttls）
smtp.login(user, password)          登录（授权码，不是邮箱密码）
smtp.send_message(msg)              发 EmailMessage
smtp.sendmail(from, to_list, raw)   发原始字符串
smtp.quit()

email.message.EmailMessage()        构造邮件（推荐）
msg["From"] / ["To"] / ["Cc"] / ["Subject"]
msg.set_content(text)               纯文本正文
msg.add_alternative(html, subtype="html")   加 HTML 版本
msg.add_attachment(data, maintype=, subtype=, filename=)   加附件
```

```Python
import smtplib
from email.message import EmailMessage

def send_alert(subject: str, body: str, to: list[str]) -> None:
    msg = EmailMessage()
    msg["From"] = "ops@example.com"
    msg["To"] = ", ".join(to)
    msg["Subject"] = subject
    msg.set_content(body)                    # 纯文本

    # 587 端口：先建连接，再 starttls
    with smtplib.SMTP("smtp.example.com", 587, timeout=10) as smtp:
        smtp.starttls()                      # 加密
        smtp.login("ops@example.com", "授权码")   # ⚠️ 不要写死在代码里
        smtp.send_message(msg)

send_alert("磁盘告警", "k8s-01 /data 使用率 92%", ["oncall@example.com"])
```

⚠️ 坑：

- 465 用 `SMTP_SSL`，587 用 `SMTP` + `starttls()`，端口和方式搞混会卡住
- `login` 用的是**授权码**，不是登录密码
- 密码从环境变量读，绝不能提交进仓库

------

## 5. prometheus-client ★★ —— 暴露自定义指标供 Prometheus 抓取

给脚本加 `/metrics`，让 Prometheus 来抓。**指标类型选错，监控就没意义。**

```
Counter(name, doc, labelnames=)        只增不减（名字以 _total 结尾）
Gauge(name, doc, labelnames=)          可增可减
Histogram(name, doc, buckets=)         分桶统计（能算 P99，可跨实例聚合）
Summary(name, doc)                     客户端分位（不能跨实例聚合）

m.labels(target="api").inc()           Counter +1
m.labels(target="api").inc(2.5)        加 2.5
m.labels(target="api").set(1)          Gauge 赋值
m.labels(target="api").observe(0.12)   Histogram 记录一次观测

start_http_server(9101)                起一个 HTTP 服务暴露 /metrics
generate_latest(REGISTRY)              拿文本（自己做 web 服务时用）
```

```Python
import time
from prometheus_client import Counter, Gauge, Histogram, start_http_server

# ==== 选对类型 ====
PROBES = Counter(                        # 累计次数 → Counter
    "probe_requests_total", "探测总次数",
    ["target", "result"],                # label 基数要小，别放 IP/时间戳
)
UP = Gauge(                              # 当前状态 → Gauge
    "probe_up", "目标是否可达", ["target"],
)
LATENCY = Histogram(                     # 延迟分布 → Histogram
    "probe_latency_seconds", "探测耗时", ["target"],
    buckets=(.05, .1, .25, .5, 1, 2.5, 5, 10),
)

def probe(target: str) -> None:
    start = time.perf_counter()
    ok = check(target)
    PROBES.labels(target=target, result="ok" if ok else "fail").inc()
    UP.labels(target=target).set(1 if ok else 0)
    LATENCY.labels(target=target).observe(time.perf_counter() - start)

if __name__ == "__main__":
    start_http_server(9101)              # 暴露 :9101/metrics
    while True:
        for t in ("api", "web", "db"):
            probe(t)
        time.sleep(15)
```

```Shell
# 验证
curl -s localhost:9101/metrics | grep probe_
```

⚠️ 坑：

- **label 基数爆炸**是监控杀手：绝不要拿 IP、URL 全路径、时间戳当 label
- `Summary` 不能跨实例聚合，要算全局 P99 必须用 `Histogram`
- Counter 名字以 `_total` 结尾是约定，client 会自动处理
- 同一个指标名在同一进程里只能注册一次，重复 `Counter(...)` 会抛 `Duplicated timeseries`

------

### 检查清单

```
□ requests 四个必备：timeout / Session / raise_for_status / Retry
□ 知道 POST 不该重试
□ 会写 AsyncClient + Semaphore 限流
□ 知道 465 vs 587 的区别
□ 能说清 Counter / Gauge / Histogram 的适用场景
□ 记得 label 基数不能爆炸
```
