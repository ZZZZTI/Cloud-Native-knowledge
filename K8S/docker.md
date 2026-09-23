> 容器化平台，用来构建，部署，运行应用

------

### 容器和镜像管理

```bash
docker ps -a/l/g                     # 查看运行的容器[已停止/最近创建/只显示容器ID]
docker stop <容器ID>                  # 停止容器
docker start/restart <容器ID>         # 开启/重启容器
docker kill <容器ID>                  # 强制停止容器
docker rm <容器ID>                    # 删除容器
docker logs [-f] <容器名或ID>          # 查看日志
docker stats <容器ID>                  # 查看容器资源占用
docker stop $(docker ps -q)           # 停止所有运行中的容器
docker container prune -f             # 删除所有已停止的容器
docker exec -it <容器名或ID> bash      # 在容器中执行命令
docker cp [容器] [主机]/[主机] [容器]   # 复制文件到主机


docker images               # 查看本地镜像
docker pull/push <镜像名>    # 拉取/推送镜像到dockerhub
docker rmi <镜像名>          # 删除镜像
docker build -t <镜像名> .   # 构建镜像，. 表示当前目录


docker run [选项] <镜像名>    # 用镜像创建并启动容器
-d   # 后台运行
-rm  # 退出自动删除
-p <主机端口>:<容器端口>
--name <容器起名>
--network host/none/container:web # 通过网络来运行
-v <主机路径>:<容器路径>
-e <变量名>=<值>
docker system prune -a      # 清理所有停止的容器、未使用的网络和镜像
```

### Dockerfile

```dockerfile
vim Dockerfile

FROM python:3.11-slim                 # 使用源镜像来创建镜像
LABEL maintainer="you@example.com"    # 维护者信息
ENV APP_HOME=/app                     # 设置环境变量
WORKDIR /app                          # 设置工作目录
COPY app.py .                         # 把当前目录下的 app.py 复制到镜像的 /app 下
EXPOSE 3000                           # 声明监听端口
CMD ["python", "app.py"]              # 容器启动时运行
```

### Docker Compose

```yaml
docker-compose up -d [--build] # 启动所有服务[代码修改后]
docker-compose start           # 启动已停止的服务
docker-compose exec web sh     # 进入某个服务的容器
docker-compose config          # 查看生成的配置
docker-compose ps              # 查看运行状态
docker-compose logs [-f web]   # 查看日志
docker-compose top             # 查看资源占用
docker-compose stop            # 停止服务（保留容器）
docker-compose down            # 停止并删除所有容器、网络（保留卷）
docker-compose down -v         # 停止并删除容器、网络、卷

vim docker-compose.yml

version: '3.8'  # Compose 文件版本
services:       # 定义服务
    web:        # 容器一（网络服务）
        image: nginx:alpine    # 镜像来源：image现成镜像/build从Dockerfile构建
        ports:
            - "8080:80"        # "宿主机:容器"
       #depends_on:            # 依赖关系
        volumes:
            - ./html:/usr/share/nginx/html
        networks:
            - my-network
    db:         # 容器二（数据库）
        image: mysql:8.0
        environment:           # 环境变量
            MYSQL_ROOT_PASSWORD: 123456
        #healthcheck:          # 健康检查
            test:.../interval: 10s/timeout: 3/sretries: 5/start_period: 30s
        volumes:
            - db-data:/var/lib/mysql
        networks:
            - my-network
networks:       # 定义自定义网络
  my-network:     
volumes:        # 定义命名卷
  db-data:            
```

### 数据持久化

```Shell
docker volume create my-data                # 创建卷
docker run -v my-data:/container/path 镜像名 # 使用卷
docker volume ls                            # 查看所有卷
docker volume inspect my-data               # 查看卷路径（宿主机上的实际存储位置）
docker volume rm my-data                    # 删除卷（需先停止并删除使用该卷的容器）
docker volume prune                         # 删除所有未使用的卷
```

### 网络

```Shell
docker network ls                    # 查看网络
docker network inspect my-network    # 查看网络详情（可查看容器IP、网关等）
docker exec app2 ping <app1:IP>      # 从 app2 访问 app1（默认 bridge 网络，需用 IP）
docker network create my-network     # 创建 bridge 类型的自定义网络
docker network rm 网络名              # 删除网络
docker network prune                 # 删除未使用的网络
docker network connect/disconnect my-network 容器名  # 将已运行的容器连接/断开到网络
```

### 架构

```Shell
基础概念
Docker 是什么：容器化平台，把应用及依赖打包成镜像，在任何环境以容器运行。解决环境一致性问题。
容器 vs 虚拟机：容器共享宿主机内核，进程级隔离，秒级启动，MB 级；虚拟机独立内核，硬件级隔离，分钟级启动，GB 级。
镜像 vs 容器：镜像是只读模板，多层叠加；容器是镜像的运行实例，顶部加可写层。关系如类与对象。
架构：Client 通过 REST API 调 Docker Daemon，Daemon 管理镜像、容器、网络、卷，底层用 containerd 和 runc。


镜像原理
分层机制：镜像由多个只读层叠加，每条指令生成一层，相同层可被多镜像共享。容器启动时顶部加可写层，修改文件时写时复制。
UnionFS：联合文件系统，把多层合并成统一视图。Docker 默认用 overlay2。
分层好处：复用、缓存加速构建、分发只传差异层、节省空间。
构建缓存：指令和上下文未变则复用缓存。变化少的指令放前面，先 COPY 依赖清单再 COPY 源码。


Dockerfile
RUN vs CMD vs ENTRYPOINT：RUN 构建时执行生成新层；CMD 容器启动默认命令，可被覆盖；ENTRYPOINT 固定入口，不可覆盖，CMD 作其默认参数。
COPY vs ADD：COPY 只复制本地文件；ADD 还能自动解压 tar、下载远程 URL。优先用 COPY。
ENV vs ARG：ENV 构建和运行时都在；ARG 仅构建时，用 --build-arg 传参。
Shell vs Exec 形式：Exec 形式（JSON 数组）进程为 PID 1，能接收信号，推荐使用；Shell 形式通过 sh -c 执行，可能不转发信号。
多阶段构建：多个 FROM，用 COPY --from 只复制产物到最终镜像，不含编译工具链，体积大幅减小。
减小镜像体积：多阶段构建、alpine 或 distroless 基础镜像、合并 RUN 清理缓存、.dockerignore、只装运行时依赖。


容器原理
Namespace 隔离：PID、NET、MNT、UTS、IPC、USER、CGROUP，让容器看不到其他容器资源。
Cgroup 限制：限制 CPU、内存、磁盘 IO、网络带宽。Namespace 管看到什么，Cgroup 管能用多少。
启动快原因：共享内核无需启动 OS，无虚拟化层，本质是启动被隔离的进程。
PID 1 问题：容器第一个进程是 PID 1，负责处理信号和回收僵尸进程。若为 shell 可能不转发信号，导致 stop 超时后 kill -9。解决用 exec 形式或 tini。


存储
Volume vs Bind Mount：Volume 由 Docker 管理，在 /var/lib/docker/volumes/，易备份迁移，适合生产；Bind Mount 挂载宿主机任意路径，适合开发代码挂载。
生命周期：卷独立于容器，删容器不删卷，需 docker volume rm 删除。


网络
网络驱动：bridge 默认单机通信；host 共享宿主机网络栈；none 无网络；overlay 跨主机；macvlan 容器有独立 MAC。
默认 bridge vs 自定义 bridge：默认 bridge 不能用容器名解析；自定义 bridge 自带 DNS，可用容器名互访，支持固定 IP。推荐自定义。
容器间通信：同一自定义网络用容器名互访；不同网络需 network connect 加入同一网络。
端口映射：依赖 iptables NAT 规则，实现宿主机端口到容器端口的 DNAT。


Compose
是什么：单机多容器编排工具，用 docker-compose.yml 定义服务、网络、卷。
depends_on 问题：只保证启动顺序，不保证服务就绪，需配合 healthcheck 和 condition service_healthy。
Compose vs K8s：Compose 单机、简单、适合开发测试；K8s 集群、复杂、适合大规模生产。


高级与实战
退出码：0 正常；1 应用错误；125 Docker 命令错误；126 不可执行；127 命令未找到；137 被 SIGKILL，常见 OOM 或 kill -9；143 被 SIGTERM。
stop vs kill：stop 发 SIGTERM，默认等 10 秒后发 SIGKILL；kill 直接发 SIGKILL。
进入容器：exec 开新进程，退出不影响容器，推荐；attach 附加到 PID 1，Ctrl+C 可能停容器。
清理命令：docker system prune -a 清理所有未使用资源；container、image、volume、network prune 分别清理；docker system df 查看磁盘占用。


安全与最佳实践
安全实践：非 root 运行、精简镜像、固定版本、最小权限、扫描漏洞、不硬编码密钥、只读文件系统。
为什么不用 root：容器 root 与宿主机 root 共享内核，逃逸风险大，提权可影响宿主机。
为什么用 alpine：体积小约 5MB，减少攻击面。注意用 musl libc，某些二进制不兼容。
Dockerfile 最佳实践：用 .dockerignore、多阶段构建、合并 RUN 清理缓存、变化少的放前面、exec 形式 CMD、非 root 用户、固定基础镜像版本、一个容器一个进程、加 HEALTHCHECK。
```
