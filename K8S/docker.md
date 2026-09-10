> 容器化平台，用来构建，部署，运行应用

------

### 容器镜像管理

```dockerfile
docker ps -a/l/g            # 查看运行的容器[已停止/最近创建/只显示容器ID]
docker stop <容器ID>         # 停止容器
docker start <容器ID>        # 开启容器
docker kill <容器ID>         # 强制停止容器
docker rm <容器ID>           # 删除容器
docker logs <容器名或ID>      # 查看日志
docker stop $(docker ps -q)  # 停止所有运行中的容器
docker container prune -f    # 删除所有已停止的容器
docker exec -it <容器名或ID> bash  # 在容器中执行命令

docker images               # 查看本地镜像
docker rmi <镜像名>          # 删除镜像
docker run [选项] <镜像名>    # 运行镜像
-d   # 后台运行
-rm  # 退出自动删除
-p <主机端口>:<容器端口>
--name <容器名>
--network host
-v <主机路径>:<容器路径>
-e <变量名>=<值>
```







```Shell



# Dockerfile(要做什么)

-- 使用源镜像来创建镜像
FROM <python:3.11-slim>
-- 设置工作目录
WORKDIR /app
-- 把当前目录下的 app.py 复制到镜像的 /app 下
COPY app.py .
-- 容器启动时运行
CMD ["python", "app.py"]
-- 声明监听窗口
expose 3000
-- 构建镜像（.表示当前目录）
docker build -t my-hello .
-- 运行容器
docker run --rm my-hello


# 数据持久化

--1.挂载            主机               容器
docker run -v (/host/path:)(/container/path image)

--2.卷volume
--创建卷
docker volume create my-data
--使用卷
docker run -v (my-data:)(/container/path image)
--查看所有卷
docker volume ls
--查看卷路径
docker volume inspect my-data
--删除卷
docker volume rm my-data


# 网络

-- 查看网络
docker network ls
-- 查看网络详情
docker network inspect my-network
-- 从app2访问app1(bridge)
docker exec app2 ping [app1:IP]
-- 通过网络运行镜像
docker run --network host/none/container:web   <镜像名>
-- 创建 bridge 类型的自定义网络
docker network create my-network
-- 从mysql访问app（自定义bridge）
docker exec app ping mysql
-- 删除网络
docker network rm <名称>              
-- 删除未使用的网络
docker network prune 
```





```Shell

# Docker Compose

--docker-compose.yml文件结构

version: '3.8'  # Compose 文件版本
services:       # 定义服务
    web:        # 容器一（网络服务）
        image: nginx:alpine
        ports:
            - "8080:80"
        volumes:
            - ./html:/usr/share/nginx/html
        networks:
            - my-network
    db:         # 容器二（数据库）
        image: mysql:8.0
        environment:
            MYSQL_ROOT_PASSWORD: 123456
        volumes:
            - db-data:/var/lib/mysql
        networks:
            - my-network
volumes:  db-data:            # 定义命名卷
networks: my-network:         # 定义自定义网络


-- 常用命令

-- 启动所有服务
docker compose up -d
-- 重建并启动（代码修改后）
docker compose up -d --build
-- 启动已停止的服务
docker compose start
-- 进入某个服务的容器
docker compose exec web sh

-- 查看生成的配置
docker compose config
-- 查看运行状态
docker compose ps
-- 查看日志
docker compose logs [-f web]
-- 查看资源占用
docker compose top

-- 停止服务（保留容器）
docker compose stop
-- 停止并删除所有容器、网络（保留卷）
docker compose down
-- 停止并删除容器、网络、卷
docker compose down -v
```

### 架构

```Shell
+-------------------+               +-----------------------------+
|   Docker Client   |    <---->     |        Docker Daemon        |
|   (docker CLI)    |     API       |         (dockerd)           |
+-------------------+               +--------------+--------------+
接收用户命令，通过 API 调用 daemon      管理镜像、容器、网络、卷，接收 API                                                                          |
                                     +-------------+-------------+
                                     |                           |
                              +------v------+             +------v------+
                              | containerd  |             |   Registry  |
                              +------+------+             +-------------+
                       容器运行时管理，负责生命周期、镜像拉取     存放和分发镜像
                                     |
                              +------v------+
                              |    runc     |
                              +------+------+
                        真正创建和运行容器的 OCI 运行时
                                     |
                              +------v------+
                              |  Container  |
                              +-------------+
                                    容器
```

