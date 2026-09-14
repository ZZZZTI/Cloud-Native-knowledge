> 一个Web服务器、反向代理、负载均衡器、API网关

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

| 文件/目录 (常见路径)                     | 作用说明             |
| :--------------------------------------- | :------------------- |
| **`/etc/nginx/nginx.conf`**              | 服务器全局配置       |
| **`/etc/nginx/sites-available/`**        | 存放所有站点的配置   |
| **`/etc/nginx/sites-available/default`** | 站点模版             |
| **`/etc/nginx/sites-enabled/`**          | 存放生效站点的软链接 |
| `/var/www/mysite/index.html`             | 网页配置文件         |

### 文件配置结构

```nginx
# 全局配置
user www-data;                         # 运行进程的用户
worker_processes auto;                 # 工作进程数
pid /run/nginx.pid;                    # 进程pid
error_log /var/log/nginx/error.log;    # 错误日志

# 事件模型
events {
    worker_connections 1024;           # 每个进程最大连接数
    use epoll;                         # 事件驱动模型
}

# 网站协议配置
http {
    include /etc/nginx/conf.d;         # 引入其他站点配置文件
    sendfile on;                       # 启用高效文件传输
    keepalive_timeout 65;              # 长连接超时时间
    access_log/error_log;              # HTTP 层面的访问日志和错误日志
    gzip on;                           # 压缩 
    charset utf-8;                     # 字符

    # 日志自定义格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for"';

    # 负载均衡算法（默认轮询）
    upstream backend_servers {
        ip_hash/least_conn;             # 用户粘性算法/最少连接算法
        server localhost:3001 weight=2; # 加权算法
        server localhost:3002 weight=3;
        server localhost:3003 backup;   # 备用服务器
    }

    # 一个 server 块代表一个虚拟主机 (网站)
    server {
        listen 80 default_server;       # 监听IPv4的80端口，并设为默认服务器
        listen [::]:80 default_server;  # 监听IPv6的80端口
        root/alias /var/www/mysite;     # 网站根目录[拼接/不拼接路径]
        server_name nbbro666.com;       # 网站域名
        index index.html;               # 默认首页文件
        error_page 404 /404.html;       # 自定义错误页面	

        # 反向代理，请求发到后端
        location /api/ {
            try_files $uri $uri/ =404;  # 按顺序尝试文件/目录
            proxy_pass http://127.0.0.1:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr; 
            # 缓存配置
            proxy_cache...
        }
        # 动静分离
        location ~* \.(jpg|jpeg|png|gif|ico|svg|webp)$ {
            expires 30d;                          # 浏览器缓存 30 天
            add_header Cache-Control "public, immutable";
            access_log off;                       # 不记录日志，减少 IO
        }
        location / {
            try_files $uri $uri/ =404;
        }
    
    }
    
    server {
    ...........
    }
}
```

------

### 架构

```Shell
基础概念
Nginx 是什么：高性能的 HTTP 和反向代理服务器，也是 IMAP/POP3/SMTP 代理服务器。特点是高并发、低内存、异步非阻塞、事件驱动。
Nginx 优点：高并发连接、内存消耗少、配置简单、支持热部署、跨平台、稳定性高、开源免费。
Nginx 应用场景：静态资源服务、反向代理、负载均衡、动静分离、API 网关、缓存服务、限流。
Nginx vs Apache：Nginx 事件驱动异步非阻塞，适合高并发静态和代理；Apache 进程或线程模型，模块丰富，适合动态处理。Nginx 内存占用低，Apache 配置更灵活。


进程模型
Nginx 启动后有两个进程：master 和 worker。
master 进程：管理 worker，读取配置，处理信号，平滑重启，不处理请求。
worker 进程：处理实际请求，数量一般设为 CPU 核数，每个 worker 独立处理连接。
多进程好处：一个 worker 崩溃不影响其他，稳定性高，能利用多核。
worker 数量设置：一般等于 CPU 核数，worker_processes auto 自动检测。
worker 连接数：worker_connections 单个 worker 最大连接数，总连接数等于 worker 数乘连接数。最大并发还受文件描述符限制
事件驱动：Linux 下用 epoll，FreeBSD 用 kqueue，高效处理大量并发连接。


配置文件结构
全局块：worker_processes、user、pid、error_log。
events 块：worker_connections、use epoll、multi_accept。
http 块：包含 server，可配 mime.types、log_format、gzip、keepalive_timeout、sendfile、client_max_body_size。
server 块：一个虚拟主机，配 listen、server_name、root、index。
location 块：匹配 URI，配 root、alias、proxy_pass、rewrite、try_files。


请求处理流程
Nginx 接收请求，匹配 server_name 找到虚拟主机，再匹配 location，然后按配置处理：返回静态文件、转发给后端、重定向等。
location 匹配规则
精确匹配：等于号，优先级最高。
前缀匹配：无修饰符，普通前缀。
正则匹配：波浪号区分大小写，波浪号星号不区分大小写。
非正则前缀：上尖号波浪号，匹配后不再查正则。
优先级：等于号最高，然后上尖号波浪号，然后正则按顺序，最后普通前缀最长匹配。


root vs alias
root：拼接 location 路径，如 location /img/ 配 root /data，访问 /img/a.jpg 找 /data/img/a.jpg。
alias：替换 location 路径，如 location /img/ 配 alias /data/，访问 /img/a.jpg 找 /data/a.jpg。
区别：root 是拼接，alias 是替换。alias 末尾斜杠要注意。


反向代理
proxy_pass：把请求转发给后端。如 proxy_pass http://127.0.0.1:8080。
代理时常用头：proxy_set_header Host、X-Real-IP、X-Forwarded-For、X-Forwarded-Proto。
proxy_pass 带斜杠区别：location /api/ 配 proxy_pass http://backend/，会去掉 /api/；配 proxy_pass http://backend，会保留 /api/。


负载均衡
upstream 定义后端服务器组。
常见策略：轮询默认、weight 权重、ip_hash 按 IP 固定、least_conn 最少连接、fair 第三方按响应时间、url_hash 按 URL。
健康检查：max_fails 失败次数、fail_timeout 失败超时、backup 备用、down 下线。
示例：upstream backend 里写 server 127.0.0.1:8080 weight 等于 3，server 127.0.0.1:8081。


动静分离
静态资源由 Nginx 直接返回，动态请求转发给后端。好处是减轻后端压力，提高响应速度。
配置：location 匹配静态后缀，如 jpg、png、css、js，配 root 或 alias 和 expires 缓存。


缓存
proxy_cache：缓存后端响应。配 proxy_cache_path 定义缓存路径和参数，proxy_cache 启用，proxy_cache_valid 设缓存时间。
expires：设浏览器缓存时间，如 expires 7d。
动静分离时静态资源常配 expires。


压缩
gzip on 开启压缩，gzip_types 指定压缩类型，gzip_min_length 最小压缩长度，gzip_comp_level 压缩级别。
好处是减少传输体积，加快加载。


限流
limit_req：限制请求速率。配 limit_req_zone 定义共享内存和速率，limit_req 启用，burst 允许突发，nodelay 不延迟。
limit_conn：限制并发连接数。配 limit_conn_zone 和 limit_conn。


重写与重定向
rewrite：重写 URI，配正则和替换，flag 有 last、break、redirect、permanent。
return：直接返回状态码或 URL，如 return 301 https://example.com。
if 判断：少用，影响性能。
常见场景：HTTP 跳 HTTPS、www 跳非 www、旧域名跳新域名。


HTTPS 配置
ssl_certificate 配证书，ssl_certificate_key 配私钥，listen 443 ssl。
常用优化：ssl_protocols 用 TLSv1.2 和 TLSv1.3，ssl_ciphers 配加密套件，ssl_session_cache 会话缓存，ssl_session_timeout。
HTTP 跳 HTTPS：server 监听 80，return 301 https://$host$request_uri。


跨域
add_header Access-Control-Allow-Origin 配允许来源，Access-Control-Allow-Methods 配方法，Access-Control-Allow-Headers 配头。
OPTIONS 预检请求可直接 return 204。


平滑重启原理
nginx -s reload 时，master 读新配置，启新 worker，通知旧 worker 停止接收新连接，处理完现有请求后退出。不断连接，不丢请求。


常见问题排查
502 Bad Gateway：后端挂了或超时，检查后端服务、proxy_pass 地址、超时配置。
504 Gateway Timeout：后端响应超时，调大 proxy_read_timeout。
413 Request Entity Too Large：请求体太大，调大 client_max_body_size。
499：客户端主动断开，一般是后端处理太慢。
403 Forbidden：权限问题，检查目录权限、index 文件、autoindex。
404 Not Found：路径不对，检查 root 或 alias、location 匹配。
跨域失败：检查 add_header 配置和 OPTIONS 处理。
```
