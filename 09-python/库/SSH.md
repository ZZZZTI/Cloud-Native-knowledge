> 第 2 类：远程执行与批量操作。从「一台一台敲 ssh」到「几百台一次跑完」。
>

------

## 1. Paramiko ★★★ —— 底层 SSHv2：远程命令、SFTP 传输

SSH 的底层实现。**Fabric 是它的高层封装**，想做细粒度控制（多跳、转发、keepalive）就得用 Paramiko。

### SSHClient 常用参数

```
SSHClient()
client.set_missing_host_key_policy(AutoAddPolicy())   首次连接自动信任主机
                                                      生产建议 RejectPolicy + 预置 known_hosts
client.connect(
    hostname, port=22, username="root",
    password=None,
    key_filename="/root/.ssh/id_rsa",   私钥路径
    passphrase=None,                    私钥密码
    timeout=10,                         连接超时
    banner_timeout=10,                  握手超时
    auth_timeout=10,                    认证超时
    look_for_keys=False,                是否自动找 ~/.ssh 下的key
    allow_agent=False,                  是否用 ssh-agent
)
client.exec_command(cmd, timeout=30)    → (stdin, stdout, stderr)
client.close()
```

### 返回值怎么读

```
stdin, stdout, stderr = client.exec_command("df -h")
stdout.read()               一次读完（bytes）
stdout.readline()           逐行读
stdout.channel.recv_exit_status()   退出码（必须在读完之后调用）
stderr.read()               错误输出
```

⚠️ `recv_exit_status()` 会**阻塞直到命令结束**，且如果先读 stdout 读到 EOF 再调用是安全的；顺序搞反可能死锁。

### SFTP

```
sftp = client.open_sftp()
sftp.put(local, remote)                       上传
sftp.get(remote, local)                       下载
sftp.listdir(path)                            列目录（只有名字）
sftp.listdir_attr(path)                       带属性（st_size / st_mtime）
sftp.stat(path)                               单文件属性
sftp.mkdir(path) / sftp.rmdir(path)
sftp.remove(path)                             删文件
sftp.rename(old, new)
sftp.chmod(path, 0o644)
sftp.close()
```

### 密钥类

```
from paramiko import RSAKey, Ed25519Key, ECDSAKey
key = RSAKey.from_private_key_file("/root/.ssh/id_rsa", password=None)
client.connect(..., pkey=key)     比 key_filename 更可控
```

```Python
import paramiko

def run(host: str, cmd: str, user: str = "root", timeout: int = 10) -> tuple[int, str, str]:
    """在远程执行一条命令，返回 (退出码, stdout, stderr)。"""
    client = paramiko.SSHClient()
    # 生产环境应该用 RejectPolicy 并提前写好 known_hosts，避免中间人
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(
            hostname=host,
            port=22,
            username=user,
            key_filename="/root/.ssh/id_rsa",
            timeout=timeout,
            banner_timeout=timeout,
            auth_timeout=timeout,
        )
        stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
        # 先读完输出，再取退出码
        out = stdout.read().decode("utf-8", errors="replace")
        err = stderr.read().decode("utf-8", errors="replace")
        code = stdout.channel.recv_exit_status()
        return code, out, err
    finally:
        client.close()          # 一定要关，否则 fd 泄漏

# ==== 用法 ====
code, out, err = run("10.0.0.1", "df -h / | tail -1")
print(code, out.strip())

# ==== SFTP 传文件 ====
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect("10.0.0.1", username="root", key_filename="/root/.ssh/id_rsa")
try:
    with client.open_sftp() as sftp:
        sftp.put("./app.tar.gz", "/opt/app.tar.gz")
        # 列目录并挑出大于 100MB 的文件
        for attr in sftp.listdir_attr("/var/log"):
            if attr.st_size > 100 * 1024**2:
                print(attr.filename, attr.st_size)
finally:
    client.close()
```

⚠️ 坑：

- `AutoAddPolicy` 会信任任何主机密钥，**有中间人风险**；生产要预置 `known_hosts`
- 不设 `timeout` 系列参数，连不通的机器会卡很久
- 每次 `exec_command` 都是独立 shell，**`cd` 不会保持**：要写 `cd /app && ./run.sh`
- 命令里的环境变量也不会继承登录 shell 的，`PATH` 可能和交互式登录不一样

------

## 2. shlex / socket ★★ —— 安全拆分命令、端口探测

### shlex：安全拆分命令

```
shlex.split(s)         按 shell 规则拆成列表（能正确处理引号）
shlex.join(list)       列表拼回 shell 字符串（自动加引号）
shlex.quote(s)         给单个参数加引号，防注入
```

```Python
import shlex

# ==== 为什么需要它 ====
cmd = 'kubectl get pods -l "app=web,env=prod"'
cmd.split()                     # ❌ ['...', '-l', '"app=web,env=prod"'] 引号还在
shlex.split(cmd)                # ✅ ['...', '-l', 'app=web,env=prod']

# ==== 用户输入的参数拼进命令 ====
user_path = "/tmp/my file; rm -rf /"
safe = shlex.quote(user_path)   # 变成 '/tmp/my file; rm -rf /'（整体被单引号包住）
# 但仍然优先「列表传参 + 不用 shell=True」，那才是根治
```

### socket：端口探测

```
socket.socket(family, type)           建套接字
s.settimeout(2)                       超时（必设）
s.connect((host, port))               连接，失败抛异常
s.connect_ex((host, port))            返回错误码，0 表示成功（批量探测更顺手）
socket.create_connection((h, p), timeout=2)   建连接并返回套接字
socket.gethostbyname(name)            域名 → IPv4
socket.gethostbyaddr(ip)              IP → (域名, 别名, 地址列表)
socket.getaddrinfo(host, port)        查地址（支持 IPv6，返回结构复杂）
socket.gethostname()                  本机主机名
```

```Python
import socket

def port_open(host: str, port: int, timeout: float = 2.0) -> bool:
    """TCP 端口探活。"""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(timeout)                 # ⚠️ 不设可能挂几十秒
        return s.connect_ex((host, port)) == 0   # 不抛异常，好批量处理

for port in (22, 6443, 9100):
    print(port, "open" if port_open("10.0.0.1", port) else "closed")

# ==== 域名解析（判断 DNS 是否正常）====
try:
    print(socket.gethostbyname("api.example.com"))
except socket.gaierror as e:
    print("解析失败:", e)
```

⚠️ `connect_ex` 只能判断 TCP 端口，UDP 端口探测要发数据包，不能用它。

------

## 3. Fabric ★★ —— 基于 Paramiko 的高层封装，批量命令

Paramiko 的高层封装，写批量任务最省事。

### Connection 常用参数

```
from fabric import Connection

Connection(
    host="10.0.0.1",
    user="root",
    port=22,
    connect_kwargs={"key_filename": "/root/.ssh/id_rsa", "timeout": 10},
)
conn.run(cmd, warn=False, hide=False, pty=False)   执行命令
conn.sudo(cmd, password=None)                       sudo 执行
conn.put(local, remote) / conn.get(remote, local)   传文件
conn.open_sftp()                                    拿 SFTP
conn.local(cmd)                                     在本地执行

with conn.cd("/app"):       切换目录（上下文内有效）
    conn.run("./deploy.sh")

with conn.prefix("source /etc/profile && "):   给每条命令加前缀
    conn.run("echo $PATH")
```

### 结果对象 Result

```
r.ok           是否成功（return_code == 0）
r.failed       是否失败
r.return_code  退出码
r.stdout       标准输出（str）
r.stderr       标准错误
r.command      执行的命令
```

### 批量

```
from fabric import SerialGroup, ThreadingGroup

SerialGroup("h1", "h2", user="root")       串行
ThreadingGroup("h1", "h2", user="root")    并发
results = group.run("uptime")          GroupResult，本质是 {Connection: Result}
results.items()                        逐个看结果（3.x 必须用 items()）
for conn, result in results.items():
    print(conn.host, result.ok)
```

```Python
from fabric import Connection, ThreadingGroup

# ==== 单机操作 ====
with Connection("10.0.0.1", user="root",
                connect_kwargs={"key_filename": "/root/.ssh/id_rsa",
                                "timeout": 10}) as conn:
    r = conn.run("systemctl is-active nginx", warn=True)   # warn=True：失败不抛异常
    print(r.ok, r.stdout.strip())

    with conn.cd("/opt/app"):          # cd 只在 with 内有效
        conn.run("./backup.sh")

# ==== 批量并发 ====
hosts = [f"10.0.0.{i}" for i in range(1, 4)]
group = ThreadingGroup(*hosts, user="root",
                       connect_kwargs={"key_filename": "/root/.ssh/id_rsa"})
results = group.run("df -h / | tail -1", warn=True)
for host, r in results.items():
    print(f"{host}: {r.stdout.strip() if r.ok else 'FAIL ' + str(r.stderr)}")
```

⚠️ `ThreadingGroup` 里某台连不上时，其余仍会执行；失败信息在 `results` 里，不会中断整体。

------

## 4. Ansible（runner） ★★ —— 声明式配置管理、YAML Playbook

不写 Playbook 时，用 `ansible-runner` 在 Python 里跑 Ansible，拿结构化结果。

```
ansible_runner.run(
    private_data_dir="/path",   目录结构：project/ inventory/ env/
    playbook="site.yml",
    inventory="/path/inventory",  或传 dict
    extravars={"key": "value"},   传变量
    limit="group1",               限定主机
    tags="deploy",                只跑某些 tag
    forks=20,                     并发数
    quiet=True,                   少打日志
    timeout=600,                  整体超时
)
r.status         'successful' / 'failed' / 'timeout'
r.rc             返回码
r.stats          各主机统计（ok/changed/failures/unreachable）
r.events         生成器，逐条事件（可拿 stdout 行）
r.stdout         全部输出
```

```Python
import ansible_runner

r = ansible_runner.run(
    private_data_dir="/opt/ansible",     # 里面要有 project/ 和 inventory/
    playbook="deploy.yml",
    extravars={"version": "v1.2.3", "env": "prod"},
    limit="webservers",
    forks=20,
    quiet=True,
    timeout=600,
)
print(r.status, r.rc)
print(r.stats)          # {'webservers': {'ok': 12, 'changed': 3, 'failures': 0}}

# 失败时把 stdout 打出来定位
if r.status != "successful":
    for ev in r.events:
        if ev.get("event") == "runner_on_failed":
            print(ev["stdout"])
```

⚠️ `private_data_dir` 的结构要求很死：`project/` 放 playbook、`inventory/` 放主机清单，放错就报「找不到 playbook」。

------

## 5. pexpect ★ —— 自动化交互式程序（密码提示等）

驱动**交互式**程序（要输密码、要回答 y/n）。Fabric/Paramiko 处理不了这种。

```
pexpect.spawn(cmd, timeout=30)   起一个交互进程
child.expect(pattern)            等输出匹配（字符串/正则/列表）
child.before / child.after       匹配前 / 匹配到的内容
child.sendline("text")           发一行（自动加 \n）
child.send("text")               发内容不加换行
child.expect(pexpect.EOF)        等到结束
child.close()                    关闭
child.exitstatus                 退出码
```

```Python
import pexpect

# ==== 自动回答 ssh 密码提示 ====
child = pexpect.spawn("ssh root@10.0.0.1", timeout=10)
i = child.expect(["password:", "yes/no", pexpect.EOF])
if i == 1:                       # 首次连接要确认指纹
    child.sendline("yes")
    child.expect("password:")
child.sendline("my-password")
child.expect(r"\$")              # 等 shell 提示符
child.sendline("uptime")
child.expect(r"\$")
print(child.before.decode())
child.close()
```

⚠️ 密码写死在脚本里是安全隐患；能用密钥就用密钥。`pexpect` 适合偶尔救急，不要作为主力方案。

------

## 6. pyinfra ★ —— 轻量基础设施自动化

用纯 Python 写「声明式」部署，语法接近 Ansible 但不用 YAML。

```Python
# deploy.py —— 用 pyinfra 命令执行：pyinfra inventory.py deploy.py
from pyinfra.operations import apt, server, files

apt.packages(
    name="安装 nginx",
    packages=["nginx"],
    update=True,
)

files.template(
    name="下发配置",
    src="templates/nginx.conf.j2",
    dest="/etc/nginx/nginx.conf",
)

server.service(
    name="启动 nginx",
    service="nginx",
    running=True,
    enabled=True,
)
```

定位：当你想「不用 YAML、直接写 Python」做配置管理时可以选它；生态和资料远不如 Ansible。

------

### 检查清单

```
□ 知道 shlex.split 和 str.split 的区别
□ 会用 connect_ex 做批量端口探测
□ Paramiko：记得关连接、先读输出再取 recv_exit_status
□ Paramiko：知道 exec_command 的 cd 不保持
□ Fabric：会用 warn=True 让失败不抛异常
□ ansible-runner：知道 private_data_dir 的目录结构
```
