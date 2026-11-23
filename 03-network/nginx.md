> Nginx 是一个高性能的开源 Web 服务器和反向代理服务器，常用于负载均衡、静态资源服务和 HTTP 缓存。
>
------

### 常用命令

```Shell
nginx -t                   # 检查配置文件语法
nginx -s reload            # 重载
nginx -s stop/quit         # 停止服务
nginx -c conf/nginx.conf   # 启动配置文件
nginx -V                   # 查看编译参数和版本
nginx -T                   # 测试并打印全部配置
nginx -s reopen            # 重新打开日志文件

# 启用新站点(创建软连接)
sudo ln -s /etc/nginx/sites-available/newsite  /etc/nginx/sites-enabled/
```

### 配置文件路径

```
文件/目录 (常见路径)                   作用说明
/etc/nginx/nginx.conf               服务器全局配置
/etc/nginx/sites-available/         存放所有站点的配置
/etc/nginx/sites-available/default  站点模版
/etc/nginx/sites-enabled/           存放生效站点的软链接
/var/www/mysite/index.html          站点根目录/首页文件
/var/log/nginx/access.log           访问日志
/var/log/nginx/error.log            错误日志
```

### nginx.conf（总配置文件结构）

```conf
# 全局配置
user www-data;                         # 运行进程的用户
worker_processes auto;                 # 工作进程数
pid /run/nginx.pid;                    # 进程pid
error_log /var/log/nginx/error.log;    # 错误日志
include /path;                         # 引入其他配置文件

# 事件模型
events {
    worker_connections 1024;           # 每个进程最大连接数
    use epoll;                         # 事件驱动模型
    multi_accept on;                   # 一次事件循环尽量多接受新连接
}

# 网站协议配置
http {
    include /etc/nginx/conf.d/*.conf;  # 引入其他站点配置文件
    sendfile on;                       # 启用高效文件传输
    keepalive_timeout 65;              # 长连接超时时间
    access_log/error_log path;         # HTTP 层面的访问日志和错误日志
    gzip on;                           # 压缩 
    charset utf-8;                     # 字符

    # 安全与基础限制
    server_tokens off;                 # 隐藏响应头 Nginx 版本号
    autoindex off;                     # 禁止目录列表
    client_max_body_size 10m;          # 限制请求体大小，直接解决 413

    # 日志自定义格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for"';

    # 访问日志缓冲，减少磁盘 IO；静态资源 location 可 access_log off;
    access_log /var/log/nginx/access.log main buffer=16k;

    # 限流配置：登录、短信、搜索等接口的第一道防线
    limit_req_zone $binary_remote_addr zone=per_ip:10m rate=5r/s;
    limit_conn_zone $binary_remote_addr zone=conn_per_ip:10m;
    # rate=5r/s   稳态速率，Nginx 按毫秒级精度平滑放行
    # burst=10    允许瞬时突发的排队数
    # nodelay     突发请求也立即处理，但受速率限制约束
    # limit_conn  限制单 IP 并发连接数，抵御连接耗尽型攻击

    # 负载均衡算法（默认轮询）
    upstream backend_servers {
        ip_hash/least_conn;             # 用户粘性算法/最少连接算法
        server localhost:3001 weight=2 max_fails=3 fail_timeout=30s; # 加权算法
        server localhost:3002 weight=3 max_fails=3 fail_timeout=30s;
        server localhost:3003 backup;   # 备用服务器
        keepalive 32;                   # 与后端保持的空闲长连接数
    }

    # 一个 server 块代表一个虚拟主机 (网站)
    server {
        listen 80 default_server;       # 监听IPv4的80端口，并设为默认服务器
        listen [::]:80 default_server;  # 监听IPv6的80端口
        root/alias /var/www/mysite;     # 网站根目录[拼接/不拼接路径]
        server_name nbbro666.com;       # 网站域名
        index index.html;               # 默认首页文件
        error_page 404 /404.html;       # 自定义错误页面

        # 安全响应头，低成本高收益
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;	

        # 反向代理，请求发到后端
        location /api/ {
            try_files $uri $uri/ =404;  # 按顺序尝试文件/目录
            proxy_pass http://backend_servers;
            proxy_http_version 1.1;     # keepalive 必须用 HTTP/1.1
            proxy_set_header Connection "";  # 清除默认 close，启用长连接
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

            # 缓存配置:超时要分维度，不要全局盲目调大
            proxy_connect_timeout 5s;   # 与后端建立 TCP 连接超时
            proxy_send_timeout 30s;     # 向后端发送请求超时
            proxy_read_timeout 30s;     # 等待后端响应超时，504 常见调整点

            # 缓存配置：proxy_cache_path 放 http 上下文
            # proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m inactive=60m;
            # proxy_cache api_cache;
            # proxy_cache_valid 200 302 10m;
        }

        # 登录接口限流(location优先级：  = /path     ^~ /prefix/      ~ / ~* )
        location = /api/login { 
            limit_req zone=per_ip burst=10 nodelay;
            limit_req_status 429;
            limit_conn conn_per_ip 20;
            proxy_pass http://backend_servers;
        }
        
        # 动静分离
        location ~* \.(jpg|jpeg|png|gif|ico|svg|webp)$ {
            expires 30d;                          # 浏览器缓存 30 天
            add_header Cache-Control "public, immutable";
            access_log off;                       # 不记录日志，减少 IO
        }
        # SPA 单页应用：刷新二级路由不 404，必须有 /index.html 回落
        location / {
            try_files $uri $uri/ /index.html;
        }
    
    }
    
    server {
    ...........
    }
}
```

------

### 架构与原理

```text
常见问题排查
502 Bad Gateway：后端挂了或超时，检查后端服务、proxy_pass 地址、超时配置。
504 Gateway Timeout：后端响应超时，调大 proxy_read_timeout。
413 Request Entity Too Large：请求体太大，调大 client_max_body_size。
499：客户端主动断开，一般是后端处理太慢。
403 Forbidden：权限问题，检查目录权限、index 文件、autoindex。
404 Not Found：路径不对，检查 root 或 alias、location 匹配。
跨域失败：检查 add_header 配置和 OPTIONS 处理。
```

#### 1. 为什么 Nginx 快

```text
一句话：事件驱动 + 非阻塞 I/O + 多进程 + 单线程 worker + 内存池 + 零拷贝。

1. 事件驱动：一个 worker 用 epoll 管大量连接，无需一连接一线程。
2. 非阻塞 I/O：没数据就注册事件，不空等。
3. 多进程：master 管配置/信号，worker 独立处理，利用多核、互不影响。
4. 单线程 worker：无线程切换和锁竞争。
5. 内存池：批量分配释放，减少碎片。
6. 零拷贝：sendfile 从内核页缓存直接发网卡。
7. 阶段化：请求拆 11 段，模块各管一段。
```

#### 2. master/worker 与信号

```text
master：
1. 读取/校验配置。
2. bind/listen 端口，把监听 fd 传给 worker。
3. 管理 worker：fork、监控、平滑重启、二进制升级。
4. 不处理请求。

worker：
1. accept、读请求、解析、匹配 location。
2. 访问静态文件或转发上游。
3. 写响应、记日志，单线程事件循环处理大量连接。
```

```text
常用信号：
HUP    重新加载配置（nginx -s reload）
USR1   重新打开日志文件（nginx -s reopen）
USR2   平滑升级二进制，启动新 master
WINCH  优雅关闭旧 worker（升级时用）
QUIT   优雅关闭（nginx -s quit）
TERM   快速关闭（nginx -s stop）
INT    快速关闭（Ctrl+C）

平滑升级：
kill -USR2 <old-master>
kill -WINCH <old-master>
kill -QUIT <old-master>
```

#### 3. 事件驱动与连接数

```text
Linux：epoll（边缘触发 + 非阻塞）
FreeBSD：kqueue
其他：select/poll（连接数大时性能差）

关键参数：
worker_processes auto;          # 一般等于 CPU 核数
worker_connections 1024;        # 每个 worker 的最大连接数
worker_rlimit_nofile 65535;     # 每个 worker 可打开的文件句柄
multi_accept on;                # 一次事件循环尽量多 accept
use epoll;                      # Linux 推荐

理论最大连接：
worker_processes * worker_connections

反向代理要占两条连接（客户端 + 上游），所以实际客户端数约为一半。
```

```Shell
ss -s
cat /proc/<worker-pid>/limits
ulimit -n
sysctl fs.file-max
sysctl net.core.somaxconn
```

#### 4. server_name 与 location 匹配

```text
server_name 匹配顺序：
1. 精确匹配：server_name example.com;
2. 最长通配符开头：server_name *.example.com;
3. 最长通配符结尾：server_name www.example.*;
4. 第一个正则：server_name ~^www\d+\.example\.com$;
5. 都没匹配：default_server。
```

```text
location 匹配：
1. 先找精确匹配 =，命中就停。
2. 再找最长前缀（普通前缀或 ^~），记住它。
3. 如果最长前缀带 ^~，直接用，不再看正则。
4. 否则按配置顺序匹配正则 ~ / ~*，第一个命中就用。
5. 正则都不中，用刚才记住的最长前缀。
6. 都没有，404。

优先级速记：
=  >  ^~  >  正则（按顺序）  >  普通前缀（最长）
```

#### 5. upstream 与负载均衡

```text
调度算法：
round-robin   默认轮询
weight        加权
ip_hash       按客户端 IP 固定后端
least_conn    最少连接
hash          按变量哈希，可加 consistent 一致性哈希
fair/url_hash 第三方模块
```

```text
被动健康检查：
max_fails=3          连续失败 3 次标记不可用
fail_timeout=30s     标记后 30 秒内不再选它
backup               备用，主后端都不可用才用
down                 手动下线

失败切换：
proxy_next_upstream error timeout http_502 http_503 http_504;
proxy_next_upstream_tries 2;
proxy_next_upstream_timeout 10s;

注意：默认只对 error/timeout 重试；POST 等非幂等请求要谨慎。
```

```text
upstream keepalive：
upstream backend {
    server 127.0.0.1:8080;
    keepalive 32;                 # 保持 32 条空闲长连接
    keepalive_requests 1000;      # 每条连接最多处理 1000 个请求
    keepalive_timeout 60s;        # 空闲超时
}

location / {
    proxy_pass http://backend;
    proxy_http_version 1.1;       # keepalive 必须 1.1
    proxy_set_header Connection "";
}
```

#### 6. 缓冲、缓存与限流

```text
缓冲：
proxy_buffering on;                 # 默认开，先收上游响应再慢慢发给客户端
proxy_buffers 8 16k;                # 每个连接 8 个 16k 缓冲
proxy_buffer_size 16k;              # 响应头缓冲
proxy_busy_buffers_size 32k;        # 忙碌缓冲上限
proxy_max_temp_file_size 1024m;     # 超过内存写临时文件
proxy_request_buffering on;         # 先收完客户端请求体再转上游

大请求体：
client_max_body_size 20m;           # 超过返回 413
client_body_buffer_size 128k;       # 请求体内存缓冲
```

```text
代理缓存（http 块定义）：
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m
                 max_size=1g inactive=60m use_temp_path=off;

proxy_cache api_cache;
proxy_cache_key "$scheme$request_method$host$request_uri";
proxy_cache_valid 200 302 10m;
proxy_cache_valid 404 1m;
proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
proxy_cache_lock on;
add_header X-Cache-Status $upstream_cache_status;

$upstream_cache_status：HIT/MISS/BYPASS/EXPIRED/STALE/UPDATING
```

```text
限流（漏桶，http 块定义 zone）：
limit_req_zone $binary_remote_addr zone=per_ip:10m rate=5r/s;
limit_req zone=per_ip burst=10 nodelay;
limit_req_status 429;

limit_conn_zone $binary_remote_addr zone=conn_per_ip:10m;
limit_conn conn_per_ip 20;
limit_conn_status 503;

burst 是允许排队的突发数；nodelay 让突发也立即处理，但仍受速率约束。
```

#### 7. 静态文件、TLS 与真实 IP

```text
静态文件：
root /var/www/site;                 # 拼接 location
alias /data/static/;                # 替换 location，注意末尾斜杠
try_files $uri $uri/ /index.html;   # SPA 回落
expires 30d;                        # 浏览器缓存
open_file_cache max=10000 inactive=60s;  # 缓存文件句柄/元数据
sendfile on;                        # 零拷贝
tcp_nopush on;                      # 配合 sendfile 打包
tcp_nodelay on;                     # 长连接小包低延迟
gzip on;                            # 文本压缩
gzip_static on;                     # 直接发预压缩的 .gz
```

```text
TLS 终止：
listen 443 ssl;
http2 on;                           # 新版写法；旧版 listen 443 ssl http2;
ssl_certificate /etc/nginx/ssl/fullchain.pem;
ssl_certificate_key /etc/nginx/ssl/privkey.pem;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 valid=300s;        # OCSP 需要
add_header Strict-Transport-Security "max-age=31536000" always;
```

```text
真实 IP（在 LB/CDN 后面）：
set_real_ip_from 10.0.0.0/8;
set_real_ip_from 192.168.0.0/16;
real_ip_header X-Forwarded-For;
real_ip_recursive on;

只信任已知代理，否则 X-Forwarded-For 可伪造。
```

#### 8. 性能与容量

```text
容量估算：
最大连接 = worker_processes * worker_connections
反向代理客户端数 ≈ 最大连接 / 2
还要留出 upstream keepalive、日志、健康检查的 fd。

示例：
4 worker * 4096 connections = 16384 连接
反向代理大约 8000 个客户端
worker_rlimit_nofile 至少 16384（实际建议 2~3 倍）

调优优先级：
1. worker_processes auto
2. worker_connections / worker_rlimit_nofile
3. upstream keepalive
4. open_file_cache + sendfile
5. gzip（文本）
6. proxy_cache
7. 限流保护
8. 避免热路径正则/if/rewrite
```

```text
监控配置：
location = /nginx_status {
    stub_status;
    allow 127.0.0.1;
    deny all;
}
```

```Shell
nginx -T | grep -E 'worker_processes|worker_connections|worker_rlimit_nofile|keepalive'
ss -s
curl -s http://127.0.0.1/nginx_status  # 需先配上面的 stub_status
```

#### 9. 常见架构与选型

```text
静态资源服务器：root/alias + expires + gzip + sendfile
反向代理：proxy_pass + X-Forwarded-* + keepalive
负载均衡：upstream + 健康检查 + keepalive
API 网关：路由 + 鉴权 + 限流 + 日志
缓存层：proxy_cache + stale
WAF/安全：ModSecurity/OpenResty + 限流 + IP 黑白名单
K8s Ingress：Nginx Ingress Controller
```

```text
Nginx vs Apache：
Nginx 事件驱动、静态/代理强；Apache 模块多、动态成熟。

Nginx vs HAProxy：
Nginx 是 Web 服务器 + 反代 + 缓存；HAProxy 专注 L4/L7 负载均衡；LVS 是内核 L4，性能最高。

选型：
静态/反向代理/缓存/网关 -> Nginx
纯 TCP/HTTP 负载均衡、大量后端 -> HAProxy/LVS
```