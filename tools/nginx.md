> 一个Web服务器、反向代理、负载均衡器、API网关

------

### 常用命令

```Shell
nginx -c conf/nginx.conf         # 启动配置文件
nginx -t                         # 检查配置文件语法
nginx -s quit/reload             # 结束/重载
nginx -V                         # 查看编译参数和版本

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
    access_log/error_log               # HTTP 层面的访问日志和错误日志

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
        root /var/www/mysite;           # 网站根目录
        server_name nbbro666.com;       # 网站域名
        index index.html;               # 默认首页文件
        error_page 404 /404.html;       # 自定义错误页面	

        # 定义URL路由规则
        location / {
            try_files $uri $uri/ =404;      # 按顺序尝试文件/目录
            # 反向代理，请求发到后端
            proxy_pass http://127.0.0.1:3000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr; 
            # 缓存配置
            proxy_cache...
        }
    }
    
    server {
    ...........
    }
}
```

------

### 核心功能

```Shell
- 3.1 web静态资源服务
  - root / alias 区别
  - index、autoindex 配置
  - 静态文件缓存头（expires、Cache-Control）
  - Gzip 压缩（gzip on、gzip_types）
  
- 3.2 反向代理
  - proxy_pass 指令
  - 代理头设置（X-Real-IP、X-Forwarded-For）
  - 代理缓冲区设置（proxy_buffering、proxy_buffer_size）
  - 代理超时控制（proxy_connect_timeout、proxy_read_timeout）
  
- 3.3 负载均衡
  - upstream 定义后端服务器池
  - 负载均衡算法：轮询、加权轮询、least_conn、ip_hash、hash
  - 健康检查（被动：max_fails/fail_timeout；主动：健康检查模块）
  - 服务器状态标记：down、backup、max_conns
  
- 3.4 HTTPS 与 SSL/TLS
  - 证书配置（ssl_certificate、ssl_certificate_key）
  - 安全协议与加密套件（ssl_protocols、ssl_ciphers）
  - 强制跳转 HTTPS（return 301 https://$server_name$request_uri;）
  - HSTS 配置
  - OCSP Stapling 优化
  
- 3.5 四层代理（stream 模块）
  - TCP/UDP 转发
  - SNI 路由转发
```

### 核心架构

#### 1. 事件驱动模型（epoll）

这是Nginx高性能的基石。不同于传统的**同步阻塞（BIO）**模型（每个连接占用一个线程，大量线程切换消耗CPU），Nginx采用**事件驱动**机制：

- **工作流程**：Nginx的Worker进程通过`epoll`（Linux下最高效的I/O多路复用接口）监听大量Socket文件描述符。
- **边缘触发（ET）**：当Socket状态发生变化（如数据到达）时，`epoll`仅通知一次。Nginx会在该次通知中循环读取所有可用数据，直到`EAGAIN`错误，确保一次唤醒处理完所有事件，避免了频繁的系统调用。
- **与传统Select/Poll对比**：`epoll`采用红黑树管理百万级连接，时间复杂度为O(1)，且返回的是**就绪事件**列表，无需遍历所有连接，解决了C10K问题中的“遍历开销”。

#### 2. 异步非阻塞 I/O

这是与事件驱动相辅相成的核心特性，深刻影响了对慢客户端的处理：

- **阻塞 vs 非阻塞**：当Nginx试图读取请求体但数据未到达时，**非阻塞**模式下调用`read`会立即返回`EAGAIN`错误，而不会挂起进程。
- **异步机制**：Nginx不会在原地轮询等待数据。它会将该Socket事件注册到`epoll`中，然后立即切换去处理其他请求。当操作系统内核将数据拷贝到用户缓冲区完毕后，`epoll`会触发可读事件，Nginx再回来继续处理。
- **吞吐量优势**：这使得Nginx能用极少的线程处理海量慢速连接（如移动端弱网环境），内存占用仅随连接数线性增长，而不是像Apache那样每个连接占用1-2MB内存。

#### 3. 多进程模型（Master-Worker）

该模型结合了稳定性与多核CPU利用率的优势：

- **Master进程（管理员）**：不处理用户请求，专职管理。负责读取配置文件、绑定特权端口（80/443）、创建和监控Worker进程的健康状态（若Worker异常退出，Master会迅速拉起新进程）。
- **Worker进程（工人）**：通常设置为与CPU核心数相等。每个Worker独立监听同一个端口（通过`SO_REUSEPORT`或在Master `accept`后分发）。
- **惊群问题解决**：早期Nginx通过`accept_mutex`锁避免多个Worker被同一新连接同时唤醒。现代Linux内核支持`SO_REUSEPORT`，允许内核层面将连接请求均衡分发至各个Worker，彻底消除惊群，提升多核扩展性。
- **热部署**：Master收到重载信号后，启动新版本的Worker处理新请求，同时优雅地通知旧Worker处理完当前请求后退出，实现零停机更新。

#### 4. C10K 问题解决方案（系统性总结）

C10K指单机处理1万个并发连接的问题。Nginx的解决方案组合如下：

| 面临瓶颈          | Nginx解决方案                    | 具体实现                                                     |
| :---------------- | :------------------------------- | :----------------------------------------------------------- |
| **系统调用开销**  | **边缘触发 + 批量处理**          | 利用`epoll`一次通知，循环读取数据直至缓冲区空，减少用户态/内核态切换。 |
| **进程/线程切换** | **固定Worker数（通常=CPU核数）** | 避免频繁上下文切换，线程切换几乎为零（仅操作系统调度）。     |
| **内存占用**      | **分阶段内存池**                 | 请求处理完后一次性释放内存，避免频繁`malloc/free`产生内存碎片。 |
| **网络I/O等待**   | **异步非阻塞 + 事件循环**        | 请求无数据时挂载到`epoll`红黑树，进程立即处理其他就绪事件，实现“一个进程跑满CPU”。 |
| **锁竞争**        | **无共享内存（尽量）**           | Worker之间相互独立，极少使用锁；使用`SO_REUSEPORT`在内核态完成负载均衡。 |
