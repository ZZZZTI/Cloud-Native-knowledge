> 自动化服务器，用于持续集成和持续交付，自动构建、测试和部署代码。

------

### 配置文件

| `.jenkins/`  | JENKINS_HOME 目录         |
| ------------ | ------------------------- |
| `jobs/`      | 所有 Job 的配置与构建记录 |
| `workspace/` | 构建工作目录              |
| `plugins/`   | 已安装插件                |
| `secrets/`   | 初始密码等敏感信息        |
| `logs/`      | 日志                      |
| `config.xml` | 全局配置                  |

### 

```Shell
# 启动命令
java -jar /opt/jenkins/jenkins.war --httpPort=8080
```

### jenkins网页界面

```Shell

```

