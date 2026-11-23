> 高频实战场景：502、504、413、499、500、503、403/404。
>

-----

## 场景 1：Nginx 502

**现象**：浏览器返回 `502 Bad Gateway`，Nginx 错误日志出现 `connect() failed` 或 `upstream prematurely closed connection`。

**可能原因**：

- 上游服务未启动或端口不对
- 上游进程崩溃、连接被 reset
- 上游 DNS 解析失败
- 请求头/响应头过大
- SELinux 阻止 Nginx 访问上游

**排查命令**：

```bash
tail -f /var/log/nginx/error.log  # 实时跟踪日志
curl -vI http://127.0.0.1:8080/  # 带调试信息检查 HTTP 响应
ss -lntp | grep ':8080'  # 查看 TCP 监听端口
nginx -t  # 检查 Nginx 配置
getenforce  # 查看 SELinux 模式
ausearch -m avc -ts recent  # 查询审计日志
```

**处理命令**：

```bash
systemctl start <upstream>  # 启动服务
# 修正 proxy_pass / upstream 地址
nginx -t && nginx -s reload  # 检查配置并平滑重载
```

**注意**：502 是“网关收到无效响应”，不是“上游超时”；504 才是超时。

------

## 场景 2：Nginx 504

**现象**：浏览器返回 `504 Gateway Timeout`，Nginx 日志出现 `upstream timed out`。

**可能原因**：

- 上游应用处理慢
- 数据库慢查询、锁等待
- `proxy_read_timeout` 太短
- 网络丢包、上游负载高

**排查命令**：

```bash
tail -f /var/log/nginx/error.log  # 实时跟踪日志
curl -o /dev/null -s -w '%{http_code} %{time_total}\n' http://127.0.0.1:8080/slow  # 只输出状态码和耗时
nginx -T | grep -E 'proxy_(connect|read|send)_timeout'  # 查看代理超时配置
# 应用侧
top  # 实时查看系统资源
jstack <PID>  # 导出 Java 线程栈
# MySQL
SHOW PROCESSLIST;  # 执行 MySQL 查询
```

**处理命令**：

```bash
# 先优化应用和数据库，再考虑调整超时
proxy_connect_timeout 5s;  # Nginx 代理超时配置
proxy_read_timeout 60s;  # Nginx 代理超时配置
proxy_send_timeout 60s;  # Nginx 代理超时配置

nginx -t && nginx -s reload  # 检查配置并平滑重载
```

**注意**：单纯调大超时会把问题拖得更久，先确认上游为什么慢。

------

## 场景 3：Nginx 413 Request Entity Too Large

**现象**：上传文件或 POST 大请求时返回 `413 Request Entity Too Large`，error.log 出现 `client intended to send too large body`。

**可能原因**：

- `client_max_body_size` 太小（默认 1m）
- 请求体超过上游/应用自己的限制
- 经过多层代理，某一层限制更小
- `client_body_buffer_size` 不是限制，别混淆

**排查命令**：

```bash
nginx -T | grep -E 'client_max_body_size|client_body_buffer_size'  # 查看限制
tail -n 50 /var/log/nginx/error.log  # 看 413 记录
curl -v -F 'file=@big.iso' http://127.0.0.1/upload  # 复现
```

**处理命令**：

```bash
# http/server/location 任一上下文
client_max_body_size 20m;  # 按业务调整
nginx -t && nginx -s reload  # 检查并重载
```

**注意**：413 也可能来自上游应用/网关，不一定是 Nginx；看 `$upstream_status` 和应用日志。

------

## 场景 4：Nginx 499 Client Closed Request

**现象**：access.log 出现 499，客户端提前断开，后端可能仍在处理。

**可能原因**：

- 上游响应慢，客户端超时/主动取消
- `proxy_read_timeout` 太长或太短
- 大响应/慢网络
- 客户端/浏览器/APP 设置了短超时

**排查命令**：

```bash
tail -f /var/log/nginx/access.log  # 看 499 和 request_time
nginx -T | grep -E 'proxy_(connect|read|send)_timeout'  # 超时配置
curl -o /dev/null -s -w '%{http_code} %{time_total}\n' --max-time 5 http://127.0.0.1/slow  # 模拟客户端超时
```

**处理命令**：

```bash
# 先优化上游，不要只调大超时
proxy_read_timeout 60s;  # 按业务调整
proxy_ignore_client_abort on;  # 客户端断开后继续等上游，谨慎使用
nginx -t && nginx -s reload
```

**注意**：499 是客户端主动断开，不是 Nginx 的错；重点查上游耗时和客户端超时。

------

## 场景 5：Nginx 500 Internal Server Error

**现象**：返回 500，error.log 可能有 `Internal Server Error`，或上游返回 500 被透传。

**可能原因**：

- 应用异常/未捕获错误
- Nginx 配置/模块错误（Lua、SSI、auth_request）
- 权限/SELinux
- `error_page` 递归/内部跳转失败
- 上游返回 500 被透传

**排查命令**：

```bash
tail -n 100 /var/log/nginx/error.log  # 看错误
curl -v http://127.0.0.1/api/  # 看响应头/上游
nginx -t  # 检查配置
grep -E 'upstream_status|request_time' /var/log/nginx/access.log | tail  # 看上游状态
```

**处理命令**：

```bash
# 修应用/配置；必要时自定义错误页
error_page 500 502 503 504 /50x.html;
location = /50x.html { root /usr/share/nginx/html; }
nginx -t && nginx -s reload
```

**注意**：500 可能是上游返回的，先看 `$upstream_status`，不要只盯 Nginx。

------

## 场景 6：Nginx 503 Service Temporarily Unavailable

**现象**：返回 503，error.log 出现 `no live upstreams` 或 `limiting connections`。

**可能原因**：

- 所有 upstream 被标记 down（max_fails/fail_timeout）
- 上游全挂/端口错
- `limit_conn`/`limit_req` 触发（如果状态码设为 503）
- worker_connections 耗尽
- 维护/灰度下线

**排查命令**：

```bash
tail -n 100 /var/log/nginx/error.log  # 看 no live upstreams/limiting
nginx -T | grep -E 'max_fails|fail_timeout|limit_conn|limit_req|proxy_next_upstream'  # 看健康检查/限流
curl -v http://127.0.0.1:8080/  # 直连上游
ss -lntp | grep ':8080'  # 看上游端口
```

**处理命令**：

```bash
systemctl start <upstream>  # 恢复上游
# 调整健康检查/限流
# upstream 块内
server 127.0.0.1:8080 max_fails=3 fail_timeout=30s;
limit_conn_status 503;
nginx -t && nginx -s reload
```

**注意**：503 可能是 Nginx 自己产生的（no live upstreams/限流），也可能是上游返回；看 `$upstream_status`。

------

## 场景 7：Nginx 403/404（静态资源）

**现象**：静态文件返回 403 Forbidden 或 404 Not Found，但文件明明存在。

**可能原因**：

- `root`/`alias` 路径拼错，`alias` 末尾斜杠问题
- 文件权限/属主不对，Nginx worker 读不了
- SELinux 上下文不对
- `index` 缺失、`autoindex off`
- `try_files`/SPA 回落没配
- 符号链接被 `disable_symlinks` 限制

**排查命令**：

```bash
nginx -T | grep -E 'root|alias|try_files|index|autoindex'  # 看路径配置
ls -l /var/www/site/index.html  # 看权限
namei -l /var/www/site/index.html  # 逐级看权限
curl -I http://127.0.0.1/index.html  # 看状态
tail -n 50 /var/log/nginx/error.log  # 看 Permission denied
getenforce; ls -Z /var/www/site  # SELinux
```

**处理命令**：

```bash
chown -R nginx:nginx /var/www/site  # 按发行版用户调整，Debian 是 www-data
chmod -R 755 /var/www/site
restorecon -Rv /var/www/site  # SELinux
# SPA 回落
location / { try_files $uri $uri/ /index.html; }
nginx -t && nginx -s reload
```

**注意**：403 是“拒绝访问”，404 是“找不到”；先区分是权限还是路径。`alias` 末尾斜杠很容易错。

