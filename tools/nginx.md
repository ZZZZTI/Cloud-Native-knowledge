> web服务器，反向代理，负载均衡

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

### 文件配置结构

```Shell
# 全局配置
user www-data;                         # 运行进程的用户
worker_processes auto;                 # 工作进程数
pid /run/nginx.pid;                    # 进程pid
error_log /var/log/nginx/error.log;    # 错误日志


# 事件模型
events {
    worker_connections 1024;     # 每个进程最大连接数
    use epoll;                   # 事件驱动模型
}


# 网站协议配置
http {
    include /etc/nginx/conf.d/*.conf;  # 引入其他站点配置文件
    sendfile on;                       # 启用高效文件传输
    keepalive_timeout 65;              # 长连接超时时间
    access_log/error_log               # HTTP 层面的访问日志和错误日志

    # 日志自定义格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                '$status $body_bytes_sent "$http_referer" '
                '"$http_user_agent" "$http_x_forwarded_for"';

    # 负载均衡算法:默认轮询
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
}
```

