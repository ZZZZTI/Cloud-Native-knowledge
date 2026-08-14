> web服务器，反向代理，负载均衡

------

### nginx

```Shell
nginx -c conf/nginx.conf         # 启动配置文件
nginx -t                         # 检查配置文件语法
nginx -s quit/reload             # 结束/重载
nginx -V                         # 查看编译参数和版本


修改nginx服务：vim /etc/nginx/nginx.conf 
user www-data;                   # 运行进程的用户
worker_processes auto;           # 工作进程数
worker_processes 1;              # 设置进程数

events {# 网络连接机制
    worker_connections 1024;     # 每个进程最大连接数
}

http {# 网站服务设置
    access_log logs/access.log;  # 访问日志
    error_log logs/error.log;    # 错误日志

    server {# 定义一个虚拟主机
        listen 8080;             # 监听端口
        server_name localhost;   # 服务器名

        location / {# 匹配根路径
            root html;           # 指定静态文件根目录
            index index.html;
        }
    }
}
```

