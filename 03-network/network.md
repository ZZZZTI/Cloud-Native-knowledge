# 网络基础理论

> 覆盖：网络模型、IP/子网/端口、TCP/UDP、HTTP/HTTPS、DNS、ARP/ICMP/路由/NAT。
> 用法：按章节顺序看，每节末尾“面试怎么问”自测。

------

## 一、网络模型与分层

### 1.1 OSI 七层与 TCP/IP 四层

| OSI 层 | TCP/IP 层 | PDU | 典型设备 | 典型协议 | 排障关注点 |
|---|---|---|---|---|---|
| 应用层 | 应用层 | 数据 | 代理、网关 | HTTP、DNS、SSH、SMTP | 状态码、域名、证书 |
| 表示层 | 应用层 | 数据 | — | TLS/SSL、JPEG、ASCII | 编码、加密、证书 |
| 会话层 | 应用层 | 数据 | — | RPC、NetBIOS | 会话保持、超时 |
| 传输层 | 传输层 | 段（TCP）/数据报（UDP） | L4 负载均衡、防火墙 | TCP、UDP | 端口、连接状态、重传 |
| 网络层 | 网际层 | 包 | 路由器、L3 交换机 | IP、ICMP、OSPF、BGP | IP、路由、ping |
| 数据链路层 | 网络接口层 | 帧 | 交换机、网桥 | Ethernet、ARP、VLAN | MAC、ARP、VLAN |
| 物理层 | 网络接口层 | 比特 | 集线器、中继器、网线 | Ethernet PHY | 网卡、光模块、链路 |

```text
记忆：
OSI 七层从下到上：物、链、网、传、会、表、应。
TCP/IP 四层从下到上：网络接口、网际、传输、应用。

注意：
TLS/SSL 在 OSI 里常被放在表示层/会话层，实际按 TCP/IP 习惯多归到应用层。
ARP 处在网络层和数据链路层之间，常被叫作“L2.5”。
```

### 1.2 封装与解封装

```text
发送方（封装）：
应用数据
  → TCP 头：源端口、目的端口、seq、ack、flags、窗口
  → IP 头：源 IP、目的 IP、TTL、协议号、分片信息
  → 以太网头：源 MAC、目的 MAC、类型
  → 物理层：比特流

接收方（解封装）：
比特流 → 帧 → 去以太网头 → 包 → 去 IP 头 → 段 → 去 TCP 头 → 应用数据
```

```text
面试追问：为什么需要端口？
IP 只能找到主机，端口才能找到主机上的具体进程。
一个 IP 上可以同时跑 SSH(22)、HTTP(80)、MySQL(3306)，靠“IP + 协议 + 端口”区分连接。
```

### 1.3 按层排障

```text
L1/L2：网卡 up 吗、网线/光模块、MAC、VLAN、ARP
L3：IP/掩码/网关、路由、ping、TTL
L4：端口监听、防火墙、TCP 状态、重传
L7：HTTP 状态码、DNS、TLS、应用日志

常用顺序：
ip link → ip addr → ip route → ping 网关 → ping 目标 → ss -lntp → 防火墙 → tcpdump → 应用日志
```

### 1.4 面试怎么问

```text
Q：OSI 七层和 TCP/IP 四层怎么对应？
A：应用/表示/会话对应应用层，传输层不变，网络层对应网际层，数据链路/物理对应网络接口层。

Q：数据从浏览器发出，经过哪些封装？
A：HTTP 数据 → TCP 段 → IP 包 → 以太网帧 → 比特流；接收方反向解封装。

Q：ping 不通，怎么按层排查？
A：先看本机网卡/IP/路由，再看网关和 ARP，再看目标 IP 和中间链路，最后看 ICMP 是否被防火墙禁掉。
```

------

## 二、IP 地址、子网、端口与常见协议

### 2.1 IPv4 地址结构

```text
IPv4 是 32 位，写成 4 个十进制数，每段 0~255：
192.168.1.100
二进制：
11000000.10101000.00000001.01100100

IP 地址 = 网络号 + 主机号
网络号由子网掩码决定：
192.168.1.100/24
掩码 255.255.255.0
网络号 192.168.1.0
主机号 100
```

### 2.2 子网掩码与 CIDR

```text
CIDR 用“/前缀长度”表示掩码中 1 的个数：
/8   255.0.0.0
/16  255.255.0.0
/24  255.255.255.0
/25  255.255.255.128
/26  255.255.255.192
/27  255.255.255.224
/28  255.255.255.240
/30  255.255.255.252

主机位 = 32 - 前缀
总地址 = 2^主机位
可用主机 = 总地址 - 2（网络地址 + 广播地址）
```

| 前缀 | 掩码 | 总地址 | 可用主机 | 典型用途 |
|---|---|---:|---:|---|
| /24 | 255.255.255.0 | 256 | 254 | 普通局域网 |
| /25 | 255.255.255.128 | 128 | 126 | 对半拆子网 |
| /26 | 255.255.255.192 | 64 | 62 | 小型子网 |
| /27 | 255.255.255.224 | 32 | 30 | 小部门/管理网 |
| /28 | 255.255.255.240 | 16 | 14 | 很小的网段 |
| /30 | 255.255.255.252 | 4 | 2 | 点对点互联 |
| /31 | 255.255.255.254 | 2 | 0（RFC 3021 可用于点对点） | 特殊场景 |
| /32 | 255.255.255.255 | 1 | 1 | 单主机/环回 |

### 2.3 子网计算示例

```text
例：192.168.1.130/26

掩码 /26 = 255.255.255.192
块大小 = 256 - 192 = 64
子网起点：0、64、128、192
130 落在 128~191 之间

网络地址：192.168.1.128
广播地址：192.168.1.191
可用主机：192.168.1.129 ~ 192.168.1.190
可用数量：2^(32-26) - 2 = 64 - 2 = 62
```

```text
例：10.0.0.1/24 和 10.0.1.1/24 是否同网段？

10.0.0.1 & 255.255.255.0 = 10.0.0.0
10.0.1.1 & 255.255.255.0 = 10.0.1.0
网络号不同，不同网段，需要经过路由器。
```

```text
判断同网段：
(ip1 & mask) == (ip2 & mask)
```

### 2.4 私有 IP、公网 IP 与特殊地址

```text
私有地址（不能在公网路由，需要 NAT）：
A 类：10.0.0.0/8
B 类：172.16.0.0/12（172.16~172.31）
C 类：192.168.0.0/16

特殊地址：
0.0.0.0/0          默认路由/所有地址
0.0.0.0            本机所有网卡（服务监听）
127.0.0.0/8        环回，127.0.0.1 是本机
169.254.0.0/16     链路本地，DHCP 失败时常见
100.64.0.0/10     运营商级 NAT（CGNAT）
224.0.0.0/4        组播
255.255.255.255    本地广播
```

### 2.5 网关与跨网段通信

```text
同网段：直接 ARP 找对方 MAC，帧直接发给对方。
跨网段：主机发现目的 IP 不在本网段，就把包发给默认网关；网关查路由，逐跳转发。

默认网关必须和本机在同一个网段，否则本机无法 ARP 到网关。
```

```text
面试追问：两台主机能 ping 通，需要哪些条件？
1. 双方 IP/掩码正确，能判断是否同网段。
2. 同网段能 ARP 到对方；跨网段能 ARP 到网关，且网关有路由。
3. 中间链路/防火墙允许 ICMP。
4. 回程路由存在。
```

### 2.6 端口范围

```text
0~1023       知名端口（well-known），通常需要 root 才能监听
1024~49151   注册端口（registered），普通应用使用
49152~65535  动态/临时端口（ephemeral），客户端发起连接时由内核分配

Linux 查看/调整临时端口范围：
sysctl net.ipv4.ip_local_port_range
# 默认常见 32768 60999
```

### 2.7 常用端口表

| 端口 | 协议 | 服务 | 说明 |
|---:|---|---|---|
| 20/21 | TCP | FTP | 数据/控制 |
| 22 | TCP | SSH | 远程登录、scp/sftp |
| 23 | TCP | Telnet | 明文远程登录，不安全 |
| 25 | TCP | SMTP | 邮件发送 |
| 53 | UDP/TCP | DNS | 域名解析，区域传送用 TCP |
| 67/68 | UDP | DHCP | 服务端/客户端 |
| 69 | UDP | TFTP | 简单文件传输 |
| 80 | TCP | HTTP | Web |
| 110 | TCP | POP3 | 收邮件 |
| 123 | UDP | NTP | 时间同步 |
| 143 | TCP | IMAP | 收邮件 |
| 161/162 | UDP | SNMP | 监控/告警 |
| 389 | TCP/UDP | LDAP | 目录服务 |
| 443 | TCP | HTTPS | 加密 Web |
| 445 | TCP | SMB | Windows 文件共享 |
| 465/587 | TCP | SMTP | 加密/提交 |
| 514 | UDP/TCP | Syslog | 日志 |
| 873 | TCP | rsync | 文件同步 |
| 993/995 | TCP | IMAPS/POP3S | 加密收发邮件 |
| 1080 | TCP | SOCKS | 代理 |
| 1521 | TCP | Oracle | 数据库 |
| 2049 | TCP/UDP | NFS | 网络文件系统 |
| 2379/2380 | TCP | etcd | 客户端/集群通信 |
| 3000 | TCP | Grafana | 监控面板 |
| 3306 | TCP | MySQL | 数据库 |
| 3389 | TCP | RDP | Windows 远程桌面 |
| 5432 | TCP | PostgreSQL | 数据库 |
| 5601 | TCP | Kibana | 日志面板 |
| 5672 | TCP | RabbitMQ | 消息队列 |
| 6379 | TCP | Redis | 缓存 |
| 6443 | TCP | Kubernetes API | 集群 API |
| 8080 | TCP | HTTP Alt | Tomcat、代理、测试 |
| 9090 | TCP | Prometheus | 监控 |
| 9092 | TCP | Kafka | 消息队列 |
| 9200 | TCP | Elasticsearch | 搜索/日志 |
| 11211 | TCP/UDP | Memcached | 缓存 |
| 27017 | TCP | MongoDB | 数据库 |

```text
记忆优先级：
面试最常问：22、53、80、443、3306、6379、8080。
运维常查：67/68、123、161、514、2049、2379、6443、9090、9092、9200。
```

### 2.8 面试怎么问

```text
Q：192.168.1.130/26 的网络地址、广播地址、可用主机数？
A：网络地址 192.168.1.128，广播 192.168.1.191，可用 129~190，共 62 个。

Q：10.0.0.1/24 和 10.0.1.1/24 同网段吗？
A：不同，网络号分别是 10.0.0.0 和 10.0.1.0，需要路由器。

Q：/30 为什么只有 2 个可用地址？
A：4 个地址里去掉网络地址和广播地址，剩 2 个，常用于点对点链路。

Q：私有 IP 有哪些？为什么需要 NAT？
A：10/8、172.16/12、192.168/16；私网地址不能在公网路由，NAT 做地址转换复用公网 IP。

Q：端口范围怎么划分？
A：0~1023 知名端口，1024~49151 注册端口，49152~65535 动态端口。

Q：怎么查 8080 被谁占用？
A：ss -lntp | grep ':8080'，或 lsof -i :8080，或 fuser -v 8080/tcp。

Q：服务监听 127.0.0.1 和 0.0.0.0 有什么区别？
A：127.0.0.1 只接受本机回环访问；0.0.0.0 监听所有网卡，外部可达（还要看防火墙/安全组）。
```

------

## 三、TCP 与 UDP

### 3.1 TCP 报文关键字段

```text
源端口/目的端口     16 位，定位进程
seq               32 位，本报文段第一个字节的序号
ack               32 位，期望收到的下一个字节序号
数据偏移           首部长度
flags             URG/ACK/PSH/RST/SYN/FIN
window            接收窗口，做流量控制
checksum          校验和
options           MSS、窗口扩大、SACK、时间戳
```

### 3.2 三次握手

```text
客户端 → 服务端：SYN，seq=x
服务端 → 客户端：SYN+ACK，seq=y，ack=x+1
客户端 → 服务端：ACK，seq=x+1，ack=y+1

为什么三次：
1. 两次无法确认客户端能收到服务端的包。
2. 三次能同步双方初始序列号，确认双方收发能力。
3. 防止历史重复 SYN 导致服务端误建连接。
```

```text
半连接队列/全连接队列：
SYN 队列（半连接）：收到 SYN，服务端回 SYN+ACK，等待客户端 ACK。
accept 队列（全连接）：三次握手完成，等待应用 accept()。

相关参数：
net.core.somaxconn               accept 队列上限
net.ipv4.tcp_max_syn_backlog     SYN 队列上限
应用 listen(backlog)             也受 somaxconn 限制

查看：
ss -lnt
# LISTEN 状态下：Recv-Q 是当前 accept 队列长度，Send-Q 是 backlog 上限
```

### 3.3 四次挥手

```text
主动关闭方 → 被动方：FIN
被动方 → 主动方：ACK
被动方 → 主动方：FIN
主动方 → 被动方：ACK

为什么四次：
TCP 是全双工，两个方向要分别关闭。
被动方收到 FIN 后可能还有数据要发，所以 ACK 和 FIN 通常不能合并。
```

### 3.4 TCP 状态机

| 状态 | 含义 | 常见场景 |
|---|---|---|
| CLOSED | 关闭 | 初始/最终状态 |
| LISTEN | 监听 | 服务端等待连接 |
| SYN_SENT | 已发 SYN | 客户端发起连接 |
| SYN_RECV | 收到 SYN | 服务端半连接 |
| ESTABLISHED | 连接建立 | 正常数据传输 |
| FIN_WAIT_1 | 已发 FIN | 主动关闭方 |
| FIN_WAIT_2 | 收到对方 ACK | 等待对方 FIN |
| CLOSE_WAIT | 收到对方 FIN | 被动关闭方，等应用 close |
| CLOSING | 双方同时关闭 | 较少见 |
| LAST_ACK | 已发 FIN | 被动关闭方等最后 ACK |
| TIME_WAIT | 等待 2MSL | 主动关闭方最后状态 |

```text
迁移主线：
CLOSED → SYN_SENT → ESTABLISHED → FIN_WAIT_1 → FIN_WAIT_2 → TIME_WAIT → CLOSED
CLOSED → LISTEN → SYN_RECV → ESTABLISHED → CLOSE_WAIT → LAST_ACK → CLOSED

查看：
ss -tan
ss -tan state time-wait
ss -tan state close-wait
ss -tan state syn-recv
ss -s
```

### 3.5 TIME_WAIT、CLOSE_WAIT、SYN_RECV、RST

```text
TIME_WAIT：
主动关闭方等待 2MSL（Linux 约 60 秒）。
作用：确保最后一个 ACK 到达；让旧连接的数据包在网络中过期。
大量短连接会堆积，处理靠连接池、keep-alive，减少短连接。

CLOSE_WAIT：
被动关闭方收到 FIN，但应用没有调用 close()。
通常是应用 bug、连接泄漏、线程阻塞、连接池只借不还。
调内核参数没用，要修应用。

SYN_RECV：
收到 SYN，回了 SYN+ACK，还没收到 ACK。
大量堆积可能是 SYN flood、backlog 太小、应用 accept 太慢。
可开 tcp_syncookies，调大 somaxconn/tcp_max_syn_backlog，并查攻击流量。

RST：
连接被重置。常见于端口没监听、防火墙 reject、应用崩溃、SO_LINGER=0。
```

```text
注意：
tcp_tw_recycle 已被移除，不要用。
tcp_tw_reuse 只适合客户端场景，服务端滥用可能带来旧包问题。
```

### 3.6 TCP 可靠传输与流量/拥塞控制

```text
可靠传输：
1. 序列号 + 确认应答：每个字节都有序号，接收方 ACK 期望的下一个序号。
2. 超时重传：RTO 到期没收到 ACK 就重发。
3. 快速重传：连续收到 3 个重复 ACK，不等超时直接重发。
4. SACK：告诉发送方哪些段已收到，减少不必要的重传。
5. 校验和：发现数据损坏。

流量控制：
接收方通过 window 告诉发送方还能收多少，防止接收缓冲区溢出。
窗口扩大选项解决高带宽高延迟链路窗口太小的问题。

拥塞控制：
慢启动：cwnd 从很小开始，每 RTT 翻倍。
拥塞避免：到 ssthresh 后线性增长。
快重传/快恢复：丢包时快速重传并调整 cwnd。
现代算法：CUBIC（Linux 默认常见）、BBR。
```

```Shell
ss -ti                              # 看 rtt、cwnd、retrans、ssthresh
nstat -az | grep -i retrans         # 看重传统计
tcpdump -i any -nn 'tcp[tcpflags] & (tcp-syn) != 0'  # 抓 SYN
```

### 3.7 TCP 与 UDP 对比

| 维度 | TCP | UDP |
|---|---|---|
| 连接 | 面向连接 | 无连接 |
| 可靠性 | 可靠，确认/重传 | 不可靠，尽力而为 |
| 顺序 | 有序 | 不保证顺序 |
| 首部 | 20 字节起 | 8 字节 |
| 流量/拥塞控制 | 有 | 无 |
| 传输方式 | 字节流 | 数据报 |
| 广播/组播 | 不支持 | 支持 |
| 典型场景 | HTTP、SSH、MySQL | DNS、DHCP、视频、游戏、日志 |

### 3.8 面试怎么问

```text
Q：为什么三次握手，不是两次/四次？
A：三次才能确认双方收发能力并同步序列号；两次无法确认客户端收到服务端包，四次多余。

Q：为什么四次挥手？
A：全双工，两个方向分别关闭；被动方收到 FIN 后可能还有数据要发，ACK 和 FIN 不能合并。

Q：TIME_WAIT 和 CLOSE_WAIT 的区别？
A：TIME_WAIT 是主动关闭方等 2MSL；CLOSE_WAIT 是被动关闭方收到 FIN 但应用没 close。

Q：大量 SYN_RECV 怎么处理？
A：先确认是否 SYN flood；再看 somaxconn、tcp_max_syn_backlog、应用 accept 速度；可开 syncookies。

Q：TCP 怎么保证可靠？
A：序列号/确认、超时重传、快速重传、SACK、校验和、滑动窗口、拥塞控制。
```

------

## 四、HTTP 与 HTTPS

### 4.1 HTTP 报文

```text
请求：
GET /api/users?id=1 HTTP/1.1
Host: example.com
User-Agent: curl/8.0
Accept: application/json

响应：
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 123
Cache-Control: max-age=60

{"id":1,"name":"tom"}
```

### 4.2 常用方法

| 方法 | 作用 | 安全 | 幂等 | 常见状态码 |
|---|---|---|---|---|
| GET | 获取资源 | 是 | 是 | 200/304/404 |
| HEAD | 只要响应头 | 是 | 是 | 200/404 |
| POST | 提交/创建 | 否 | 否 | 201/400/409 |
| PUT | 全量更新/创建 | 否 | 是 | 200/201/204 |
| PATCH | 部分更新 | 否 | 不一定 | 200/204 |
| DELETE | 删除 | 否 | 是 | 204/404 |
| OPTIONS | 预检/能力查询 | 是 | 是 | 204/200 |
| CONNECT | 代理隧道 | — | — | 200 |

```text
安全：不改资源。
幂等：执行一次和执行多次，结果一样（GET/PUT/DELETE 通常幂等，POST 不幂等）。
```

### 4.3 常见状态码

| 状态码 | 含义 | 典型原因 |
|---:|---|---|
| 200 | OK | 正常 |
| 201 | Created | 创建成功 |
| 204 | No Content | 成功但无响应体 |
| 206 | Partial Content | 断点续传/范围请求 |
| 301 | Moved Permanently | 永久重定向，SEO 会传递 |
| 302 | Found | 临时重定向 |
| 303 | See Other | 重定向到 GET |
| 304 | Not Modified | 缓存有效 |
| 307 | Temporary Redirect | 临时重定向，保持方法 |
| 308 | Permanent Redirect | 永久重定向，保持方法 |
| 400 | Bad Request | 参数/格式错误 |
| 401 | Unauthorized | 未认证/凭证无效 |
| 403 | Forbidden | 已认证但无权限 |
| 404 | Not Found | 资源不存在 |
| 405 | Method Not Allowed | 方法不允许 |
| 408 | Request Timeout | 请求超时 |
| 409 | Conflict | 冲突（重复创建/版本冲突） |
| 413 | Payload Too Large | 请求体太大 |
| 429 | Too Many Requests | 限流 |
| 499 | Client Closed Request | Nginx 特有，客户端主动断开 |
| 500 | Internal Server Error | 应用异常 |
| 501 | Not Implemented | 不支持 |
| 502 | Bad Gateway | 网关收到上游无效响应 |
| 503 | Service Unavailable | 服务不可用/过载/维护 |
| 504 | Gateway Timeout | 网关等上游超时 |

```text
易混：
401 vs 403：401 是“你是谁”，403 是“我知道你是谁，但你不能看”。
301 vs 302：永久 vs 临时；307/308 会保持原请求方法，301/302 历史上可能被改成 GET。
502 vs 503 vs 504：502 上游响应无效；503 服务不可用；504 上游超时。
499：Nginx 记录到“客户端提前断开”，通常是后端太慢，客户端不等了。
```

### 4.4 常用请求/响应头

```text
Host                目标域名（HTTP/1.1 必需，虚拟主机靠它）
Connection          keep-alive/close
Content-Type        请求体/响应体类型
Content-Length      长度
Transfer-Encoding   chunked
Cookie / Set-Cookie 会话
Cache-Control       缓存策略
ETag / If-None-Match 协商缓存
Last-Modified / If-Modified-Since 协商缓存
Location            重定向目标
Authorization       认证信息
X-Forwarded-For     代理链路上的客户端 IP
X-Real-IP           代理传给后端的真实 IP
User-Agent          客户端标识
Referer             来源页面
```

### 4.5 HTTP 版本

```text
HTTP/1.0：默认短连接，每个请求新建 TCP；需要 Connection: keep-alive 才复用。
HTTP/1.1：默认长连接，支持管道化，但仍有队头阻塞；Host 头必需。
HTTP/2：二进制分帧、多路复用、头部压缩 HPACK、服务端推送；解决 HTTP 层队头阻塞，但 TCP 层仍有。
HTTP/3：基于 QUIC/UDP，0-RTT、连接迁移，解决 TCP 队头阻塞。
```

### 4.6 HTTPS/TLS 握手

```text
一句话：HTTPS = HTTP + TLS，先验证证书、协商密钥，再用对称加密传数据。

TLS 1.2（简化）：
1. ClientHello：版本、加密套件、随机数、SNI。
2. ServerHello：选套件、随机数；Certificate：证书链；ServerKeyExchange；ServerHelloDone。
3. ClientKeyExchange：协商预主密钥；ChangeCipherSpec；Finished。
4. 服务端 ChangeCipherSpec；Finished。

TLS 1.3（简化）：
1. ClientHello + key_share。
2. ServerHello + key_share + Certificate + Finished。
3. 客户端 Finished。
1-RTT 完成，支持 0-RTT（有重放风险）。
```

```text
证书校验：
1. 证书链能否走到受信任根 CA。
2. 域名是否匹配（SAN）。
3. 是否在有效期内。
4. 是否被吊销（OCSP/CRL）。
5. 证书用途是否正确。

SNI：一个 IP 上多个 HTTPS 域名，客户端在 ClientHello 里带域名，服务端选对应证书。
HSTS：强制浏览器后续用 HTTPS。
```

```Shell
openssl s_client -connect example.com:443 -servername example.com -showcerts </dev/null
openssl x509 -in cert.pem -noout -dates -subject -issuer -ext subjectAltName
curl -vI https://example.com/
```

### 4.7 输入 URL 到页面展示

```text
1. 解析 URL，查浏览器缓存、DNS 缓存、hosts。
2. DNS 解析域名到 IP。
3. 与服务器建立 TCP 连接（三次握手）。
4. HTTPS 还要 TLS 握手、证书校验。
5. 发送 HTTP 请求，经过 CDN/LB/Nginx。
6. 应用处理，访问缓存/数据库。
7. 返回响应，浏览器解析 HTML、加载静态资源、渲染。
8. 连接复用或关闭。
```

### 4.8 面试怎么问

```text
Q：301 和 302 的区别？
A：301 永久重定向，302 临时重定向；307/308 会保持原请求方法。

Q：401 和 403 的区别？
A：401 未认证，403 已认证但无权限。

Q：502、503、504 的区别？
A：502 网关收到上游无效响应；503 服务不可用/过载；504 网关等上游超时。

Q：HTTPS 握手做了什么？
A：协商版本/套件、验证证书、交换密钥、建立对称加密通道。

Q：HTTP/1.1 和 HTTP/2 的区别？
A：HTTP/2 二进制分帧、多路复用、头部压缩，解决 HTTP 层队头阻塞。
```

------

## 五、DNS

### 5.1 域名层级

```text
.                    根域
.com                 顶级域 TLD
example.com          权威域
www.example.com      子域/主机记录
```

### 5.2 解析过程

```text
1. 浏览器缓存
2. 操作系统缓存（systemd-resolved/nscd）
3. /etc/hosts
4. 本地 DNS 服务器（递归解析器）
5. 根服务器 → 顶级域服务器 → 权威服务器
6. 返回 A/AAAA 记录，按 TTL 缓存
```

```text
递归查询：客户端 → 本地 DNS，本地 DNS 负责查到底，返回最终结果。
迭代查询：本地 DNS → 根/TLD/权威，逐级返回“下一台该问谁”。
```

### 5.3 常见记录类型

| 类型 | 作用 | 示例 |
|---|---|---|
| A | IPv4 地址 | `www.example.com. 60 IN A 192.0.2.10` |
| AAAA | IPv6 地址 | `www.example.com. 60 IN AAAA 2001:db8::10` |
| CNAME | 别名 | `blog.example.com. IN CNAME www.example.com.` |
| MX | 邮件服务器 | `example.com. IN MX 10 mail.example.com.` |
| NS | 权威服务器 | `example.com. IN NS ns1.example.com.` |
| PTR | 反向解析 | `10.2.0.192.in-addr.arpa. IN PTR www.example.com.` |
| TXT | 文本/验证 | SPF、DKIM、域名验证 |
| SRV | 服务位置 | `_http._tcp.example.com. IN SRV 10 5 80 www.example.com.` |
| SOA | 区域起始授权 | 主 NS、管理员、序列号、TTL |
| CAA | 证书颁发机构限制 | 限制哪些 CA 能签发 |

### 5.4 DNS 配置

```text
/etc/resolv.conf
nameserver 8.8.8.8
nameserver 114.114.114.114
search example.com
options ndots:5

/etc/hosts
127.0.0.1 localhost
192.168.1.10 db.example.com

/etc/nsswitch.conf
hosts: files dns
# 先查 /etc/hosts，再查 DNS
```

```text
注意：
NetworkManager、systemd-resolved、cloud-init 都可能覆盖 /etc/resolv.conf。
排查时先看 resolvectl status 或 nmcli，不要只改文件。
```

### 5.5 常见 DNS 故障

```text
NXDOMAIN      域名不存在/记录没配
SERVFAIL      DNS 服务器故障、DNSSEC 校验失败、上游超时
Timeout       DNS 服务器不可达、防火墙拦 53、网络不通
解析到错 IP   缓存、hosts、split-horizon、DNS 劫持
内网域名失败   search 域、ndots、VPN/DNS 配置
```

### 5.6 面试怎么问

```text
Q：DNS 解析过程？
A：浏览器缓存 → 系统缓存 → hosts → 本地 DNS → 根/TLD/权威 → 返回并缓存。

Q：递归和迭代的区别？
A：递归是“你帮我查到底”；迭代是“你告诉我下一台问谁”，本地 DNS 对根/TLD/权威是迭代。

Q：A 和 CNAME 的区别？
A：A 直接指向 IPv4；CNAME 指向另一个域名，最终还要继续解析。

Q：DNS 解析失败怎么排查？
A：getent hosts 看系统解析，dig 看 DNS，dig +trace 看链路，查 resolv.conf/nsswitch.conf/hosts/防火墙。
```

------

## 六、ARP、ICMP、路由与 NAT

### 6.1 ARP

```text
作用：同一局域网内，把 IP 解析成 MAC。

过程：
1. 主机 A 查 ARP 缓存，没有 192.168.1.1 的 MAC。
2. A 广播 ARP 请求：“谁是 192.168.1.1？”
3. 网关收到后单播回复自己的 MAC。
4. A 缓存 IP-MAC 映射，再发数据帧。

查看/清理：
ip neigh
ip neigh del 192.168.1.1 dev eth0
arping -I eth0 192.168.1.1
```

```text
ARP 欺骗：攻击者伪造 ARP 应答，把网关 IP 映射到自己的 MAC，流量被劫持。
防护：动态 ARP 检测、端口安全、静态 ARP、arpwatch。
IPv6 用 ND（邻居发现）替代 ARP。
```

### 6.2 ICMP

```text
ICMP 常见类型：
0   Echo Reply        ping 回复
3   Destination Unreachable  目标不可达
8   Echo Request      ping 请求
11  Time Exceeded     TTL 到期，traceroute 用

ping：发 ICMP Echo Request，等 Echo Reply。
traceroute：逐步增大 TTL，让每一跳返回 Time Exceeded，从而画出路径。
mtr：结合 ping 和 traceroute，持续看每跳延迟/丢包。
```

```Shell
ping -c 4 8.8.8.8
ping -I eth0 -c 4 8.8.8.8          # 指定源网卡
ping -M do -s 1472 -c 3 8.8.8.8    # 测 MTU：1500 - 20(IP) - 8(ICMP) = 1472
traceroute -n 8.8.8.8
mtr -rw 8.8.8.8
```

```text
注意：
ping 通不代表端口通；ping 不通也不代表服务不可用，ICMP 可能被防火墙禁掉。
```

### 6.3 路由表

```text
字段：
目的网络/掩码、网关、接口、metric、flags

查看：
ip route
ip route get 8.8.8.8

默认路由：
0.0.0.0/0 via 192.168.1.1 dev eth0

最长前缀匹配：
目的地址匹配多条路由时，掩码最长（最具体）的优先。
metric 小的优先；Linux 还会参考路由来源（proto）和内核规则。
```

```Shell
ip route
ip route get 8.8.8.8
ip route add 10.10.0.0/16 via 192.168.1.1
ip route del 10.10.0.0/16
ip route replace default via 192.168.1.1

sysctl net.ipv4.ip_forward        # 1 表示开启转发
```

```text
静态路由：手动配置，适合小网络/固定拓扑。
动态路由：RIP、OSPF、BGP，自动学习和收敛。
策略路由：ip rule 按源地址、标记等选择不同路由表。
```

### 6.4 跨网段通信过程

```text
1. 主机 A 用掩码判断目的 IP 不在本网段。
2. A 查路由表，找到默认网关。
3. A 用 ARP 获取网关 MAC。
4. A 把 IP 包封装成帧，目的 MAC 是网关，目的 IP 是目标主机。
5. 网关收包，查路由，TTL 减 1，转发到下一跳。
6. 逐跳转发，直到目标网段。
7. 目标主机回复，走回程路由。
```

### 6.5 NAT 类型

```text
SNAT：源地址转换，内网访问公网。
  iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o eth0 -j MASQUERADE

DNAT：目的地址转换，公网访问内网服务/端口映射。
  iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.1.100:80

PAT：端口地址转换，多内网共享一个公网 IP，靠端口区分连接。
```

```text
conntrack：连接跟踪，NAT 和状态防火墙依赖它。
查看：
cat /proc/sys/net/netfilter/nf_conntrack_count
cat /proc/sys/net/netfilter/nf_conntrack_max
conntrack -S
dmesg -T | grep -i conntrack

表满会丢包：nf_conntrack: table full, dropping packet。
```

### 6.6 常见攻击与防护

```text
SYN flood：大量半连接占满 SYN 队列。
  防护：tcp_syncookies=1、调大 backlog、防火墙限速/清洗。

ARP 欺骗：伪造 ARP 映射劫持流量。
  防护：动态 ARP 检测、端口安全、静态 ARP。

DDoS：流量型/连接型/应用型。
  防护：云清洗、限流、CDN、WAF。

反射放大：DNS/NTP 等 UDP 反射。
  防护：关闭开放递归、限制 UDP、入口过滤。
```

### 6.7 面试怎么问

```text
Q：ARP 的作用？
A：同一局域网内把 IP 解析成 MAC；跨网段时解析的是网关 MAC。

Q：ping 的原理？
A：发 ICMP Echo Request，收 Echo Reply；只能证明网络层可达，不代表端口通。

Q：traceroute 的原理？
A：逐步增大 TTL，让每跳路由器返回 Time Exceeded，从而得到路径。

Q：两台主机不同网段怎么通信？
A：主机把包发给默认网关，网关查路由逐跳转发；回程也要有路由。

Q：路由怎么选？
A：最长前缀匹配优先；再比较 metric，metric 相同再看路由来源和内核规则。

Q：SNAT 和 DNAT 的区别？
A：SNAT 改源地址，内网出公网；DNAT 改目的地址，公网访问内网服务。

Q：NAT 和 PAT 的区别？
A：NAT 是地址转换的总称；PAT 是带端口复用的 NAT，多内网共享一个公网 IP。

Q：iptables 四表五链？
A：filter/nat/mangle/raw；PREROUTING/INPUT/FORWARD/OUTPUT/POSTROUTING。

Q：conntrack 表满会怎样？
A：新连接被丢，日志出现 table full, dropping packet；要调大上限并查短连接/NAT 规则。
```


