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

### item

```Shell
# 简单任务
Freestyle Project（自由风格项目）
这是最经典、最常用的类型，适合大多数简单到中等复杂度的构建任务。
特点是通过 Web UI 配置，几乎不用写代码。
可配置的内容包括：源码管理（Git、SVN 等）、构建触发器（定时、SCM 变更、Webhook 等）、构建步骤（执行 Shell、Windows 批处理、调用 Maven 或 Gradle 等）、构建后操作（归档产物、发邮件、触发下游任务）。
适用场景是常规编译、打包、部署、定时任务。

# 需要版本化、复杂流程
Pipeline（流水线）
用代码（Groovy DSL）定义整个构建流程，是现代 Jenkins 的主流推荐方式。
分为两种写法。Declarative Pipeline 是结构化语法，用 pipeline { } 包裹，易读易维护，推荐新手使用。Scripted Pipeline 是更灵活的 Groovy 脚本，用 node { } 包裹，适合复杂逻辑。
特点是流程即代码，可以纳入版本控制，也就是 Jenkinsfile。
优势是支持阶段（stage）、并行、条件判断、错误处理、共享库。
适用场景是 CI/CD 全流程、多阶段构建、复杂编排。

# 多分支开发
Multibranch Pipeline（多分支流水线）
自动为代码仓库中的每个分支或 PR 创建一条流水线。
特点是扫描仓库，发现含 Jenkinsfile 的分支就自动建 Job。
优势是分支增删自动同步，适合 Git Flow 或 PR 流程。
适用场景是多分支并行开发、Pull Request 构建。

# 整个组织统一管理
Organization Folder（组织文件夹）
这是多分支流水线的升级版，扫描整个 GitHub、GitLab 组织或 Bitbucket 团队。
特点是自动发现组织下所有仓库，为每个仓库再创建多分支流水线。
适用场景是统一管理一个团队或组织的所有项目。

# 大量 Job 需要分类
Folder（文件夹）
它不是构建任务，而是用来组织归类其他 Item 的容器。
特点是支持嵌套，可以做权限隔离
适用场景是按团队、项目、环境分组管理大量 Job。
```

### Pipeline：groovy语法

```groovy
pipeline {
    // 指定流水线运行的代理节点，可以是 any、none 或具体标签
    agent any
    // 环境变量，可在所有阶段中使用
    environment {
        APP_NAME = 'my-app'
        BUILD_TOOL = 'maven'
    }
    // 构建参数，运行时由用户输入
    parameters {
        string(name: 'BRANCH', defaultValue: 'main', description: '要构建的分支')
        choice(name: 'ENV', choices: ['dev', 'test', 'prod'], description: '部署环境')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: '是否运行测试')
    }
    // 流水线触发器，例如定时或轮询
    triggers {
        cron('H 2 * * *') // 每天凌晨2点触发
    }
    // 全局选项
    options {
        timestamps()           // 日志添加时间戳
        buildDiscarder(logRotator(numToKeepStr: '10')) // 保留最近10次构建
        timeout(time: 1, unit: 'HOURS') // 超时时间
        disableConcurrentBuilds() // 禁止并发构建
    }
    // 工具自动安装，比如 Maven、JDK
    tools {
        maven 'M3'
        jdk 'JDK11'
    }
    stages {
        // 阶段1：拉取代码
        stage('Checkout') {
            steps {
                script {
                    echo "正在拉取分支: ${params.BRANCH}"
                }
                git branch: "${params.BRANCH}", url: 'https://github.com/example/repo.git'
            }
        }
        // 阶段2：构建
        stage('Build') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
            post {
                success {
                    echo '构建成功'
                }
                failure {
                    echo '构建失败'
                }
            }
        }
        // 阶段3：测试（根据参数决定是否运行）
        stage('Test') {
            when {
                expression { params.RUN_TESTS == true }
            }
            steps {
                sh 'mvn test'
            }
        }
        // 阶段4：并行部署到不同环境
        stage('Deploy') {
            parallel {
                stage('Deploy to Dev') {
                    when {
                        expression { params.ENV == 'dev' }
                    }
                    steps {
                        echo '部署到开发环境'
                        sh './deploy.sh dev'
                    }
                }
                stage('Deploy to Test') {
                    when {
                        expression { params.ENV == 'test' }
                    }
                    steps {
                        echo '部署到测试环境'
                        sh './deploy.sh test'
                    }
                }
                stage('Deploy to Prod') {
                    when {
                        expression { params.ENV == 'prod' }
                    }
                    steps {
                        // 生产环境需要手动确认
                        input message: '确认部署到生产环境？', ok: '确认'
                        echo '部署到生产环境'
                        sh './deploy.sh prod'
                    }
                }
            }
        }
    }
    // 后置处理，无论成功失败都会执行
    post {
        always {
            echo '流水线执行完毕'
            junit 'target/surefire-reports/*.xml' // 收集测试报告
            archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: true
        }
        success {
            echo '流水线成功完成'
            // 可发送通知，如邮件、Slack等
        }
        failure {
            echo '流水线失败'
        }
        unstable {
            echo '流水线不稳定'
        }
        cleanup {
            echo '工作空间已清理'
        }
    }
}
```

### Configure

```Shell
General（通用设置）
这是最基础的配置区域。可以填写项目描述，方便团队协作时了解用途。Discard old builds 用于控制构建历史保留策略，可按天数或数量限制，避免磁盘被占满。This project is parameterized 勾选后可以定义构建参数，支持字符串、布尔值、密码、选项等多种类型，构建时用户可以输入或选择。Throttle builds 设置构建之间的最小间隔和并发数量上限。Disable this project 可以临时停用这个 Job。此外还有并发构建控制、静默期设置、限制运行节点等选项。


Source Code Management（源码管理）
这里配置代码仓库地址，选择 None 表示不使用 SCM。常用的有 Git 和 SVN。以 Git 为例，需要填写仓库 URL、凭据、分支说明符等。如果在 General 中定义了参数，这里也可以引用参数来动态指定仓库路径或分支。


Build Triggers（构建触发器）
定义什么情况下自动开始构建。常见方式包括：外部通过 URL 远程触发、在其他项目构建完成后触发、Build periodically 按 cron 表达式定时触发、Poll SCM 定时轮询代码变更后触发。如果安装了对应插件，还可以使用 GitHub hook 等 Webhook 方式触发。


Build Environment（构建环境）
用于准备构建所需的运行环境。Delete workspace before build starts 可以在构建前清理工作空间。Abort the build if it‘s stuck 设置超时策略，防止卡死的构建一直占用资源。Use secret text(s) or file(s) 用于安全地传入密钥、证书等敏感信息。如果父文件夹配置了 Folder Properties，Freestyle 项目需要在这里启用相应的包装器才能继承那些属性。


Build（构建步骤）
这是核心执行区域。Freestyle 项目可以添加多个构建步骤，如执行 Shell、Windows 批处理、调用 Maven 目标、执行 Gradle 任务等。步骤按顺序串行执行，前一步失败后后续步骤通常不会继续。对于 Pipeline 类型的 Item，这个位置会变成 Pipeline 脚本的定义区域，可以选择内联编写，也可以从 SCM 中读取 Jenkinsfile。


Post-build Actions（构建后操作）
构建结束后触发的操作。常见的包括：归档构建产物（jar、war、报告等）、发送邮件通知、发布测试结果、触发下游 Job、记录构建指纹等。这些操作无论构建成功还是失败都可以配置执行，具体可用选项取决于安装的插件。


Pipeline 相关配置
如果是 Pipeline 类型的 Item，Configure 页面会额外包含 Pipeline 区块。可以选择 Pipeline script 直接粘贴脚本，或者选择 Pipeline script from SCM 从仓库读取 Jenkinsfile。使用 SCM 方式时可以指定 Jenkinsfile 的路径和是否使用轻量级检出。


Multibranch Pipeline 特有配置
Multibranch Pipeline 的 Configure 页面主要围绕分支发现和行为策略展开。Branch Sources 配置仓库地址和凭据，Property strategy 控制参数如何应用到分支——可以选择所有分支使用相同属性，也可以按正则表达式过滤特定分支。参数可以在文件夹层级集中定义，避免每个分支的 Jenkinsfile 都重复配置。


Maven Project 特有配置
Maven Project 类型有专门的 Maven 配置区块。可以指定根 POM 文件的路径（默认 pom.xml）、要执行的 Maven 目标（如 clean install deploy）、使用的 Maven 安装版本、是否启用增量构建、是否自动归档产物等。


Matrix Project 特有配置
Matrix Project（多配置项目）的核心是 Configuration Matrix 区块。可以添加多个轴（Axis），比如操作系统、JDK 版本、目标环境，每个轴定义一组值。Jenkins 会自动为轴的每个组合创建一个独立的构建配置来执行。执行策略中可以设置组合过滤器、是否顺序执行、以及 Touchstone 构建（先用一个配置验证，通过后再跑全部）。
```

### jenkins CLI

```Shell
java -jar /opt/jenkins/jenkins.war --httpPort=8080   # 启动 Jenkins 服务，HTTP 端口 8080
ssh -l admin -p 2222 129.204.28.181                  # SSH 连接 Jenkins 服务器
# 前置：在 Mac 的 ~/.ssh/config 中添加以下配置（只需一次）
# Host jenkins
#     HostName 129.204.28.181
#     Port 2222
#     User admin



# ===== 基础 / 身份 =====
ssh jenkins help                        # 列出所有可用命令，或查看某个命令的详细说明
ssh jenkins help build                  # 查看某个具体命令的详细用法（例如 build）
ssh jenkins version                     # 输出当前 Jenkins 版本
ssh jenkins session-id                  # 输出当前会话 ID（每次 Jenkins 重启后会变化）
ssh jenkins who-am-i                    # 报告当前登录身份和拥有的权限


# ===== Job 查看 =====
ssh jenkins list-jobs                             # 列出所有 Job（不填视图则列出全部）
ssh jenkins list-jobs <视图名称>                   # 列出某个视图下的 Job
ssh jenkins get-job <Job名称>                      # 导出某个 Job 的配置 XML 到标准输出
ssh jenkins console <Job名称>                      # 查看某个 Job 最新一次构建的控制台输出
ssh jenkins console <Job名称> <构建号>              # 查看指定构建的控制台输出
ssh jenkins list-changes <Job名称>                 # 导出指定构建的变更日志（changelog）
ssh jenkins list-changes <Job名称> <构建号>         # 导出指定构建号的变更日志


# ===== Job 构建 =====
ssh jenkins build <Job名称>                                    # 触发某个 Job 的构建（不等待完成）
ssh jenkins build <Job名称> -f -v                              # 触发构建并等待完成，同时输出构建日志
ssh jenkins build <Job名称> -p <参数名>=<参数值>                 # 触发构建并传入参数（-p 指定参数）
ssh jenkins stop-builds <Job名称>                              # 停止某个 Job 所有正在运行的构建
ssh jenkins set-build-description <Job名称> <构建号> "<描述内容>"# 设置某次构建的描述信息
ssh jenkins set-build-display-name <Job名称> <构建号> "<显示名>" # 设置某次构建的显示名称
ssh jenkins keep-build <Job名称> <构建号>                       # 将某次构建标记为永久保留
ssh jenkins delete-builds <Job名称> <构建号范围>                 # 删除某个 Job 的构建记录（可指定构建号范围）


# ===== Job 管理 =====
ssh jenkins create-job <Job名称> < <配置文件.xml>        # 通过标准输入读取 XML 配置来创建新 Job
ssh jenkins update-job <Job名称> < <配置文件.xml>        # 通过标准输入读取 XML 配置来更新已有 Job
ssh jenkins reload-job <Job名称>                        # 从磁盘重新加载某个 Job 的配置
ssh jenkins copy-job <源Job名称> <新Job名称>             # 复制一个已有 Job
ssh jenkins delete-job <Job名称>                        # 删除一个或多个 Job
ssh jenkins enable-job <Job名称>                        # 启用某个 Job
ssh jenkins disable-job <Job名称>                       # 禁用某个 Job


# ===== 视图（View）管理 =====
ssh jenkins create-view <视图名称> < <视图配置.xml>          # 通过标准输入读取 XML 配置来创建视图
ssh jenkins get-view <视图名称>                             # 导出某个视图的配置 XML
ssh jenkins update-view <视图名称> < <视图配置.xml>          # 通过标准输入读取 XML 配置来更新视图
ssh jenkins delete-view <视图名称>                           # 删除一个或多个视图
ssh jenkins add-job-to-view <视图名称> <Job名称>              # 向视图中添加 Job
ssh jenkins remove-job-from-view <视图名称> <Job名称>         # 从视图中移除 Job


# ===== 节点（Node）管理 =====
ssh jenkins create-node <节点名称> < <节点配置.xml>       # 通过标准输入读取 XML 配置来创建节点
ssh jenkins get-node <节点名称>                          # 导出某个节点的配置 XML
ssh jenkins update-node <节点名称> < <节点配置.xml>       # 通过标准输入读取 XML 配置来更新节点
ssh jenkins delete-node <节点名称>                       # 删除一个或多个节点
ssh jenkins connect-node <节点名称>                      # 重新连接某个节点
ssh jenkins disconnect-node <节点名称>                   # 断开某个节点
ssh jenkins offline-node <节点名称>                      # 将节点临时下线（停止用于构建）
ssh jenkins online-node <节点名称>                       # 将节点恢复上线
ssh jenkins wait-node-offline <节点名称>                 # 等待节点变为离线状态
ssh jenkins wait-node-online <节点名称>                  # 等待节点变为在线状态


# ===== 凭证（Credentials）管理 =====
ssh jenkins list-credentials <store>                              # 列出指定存储中的凭证（需指定 store 的上下文）
ssh jenkins list-credentials-as-xml <store>                       # 将凭证导出为 XML（敏感信息会被脱敏）
ssh jenkins list-credentials-context-resolvers                    # 列出凭证上下文解析器
ssh jenkins list-credentials-providers                            # 列出凭证提供者
ssh jenkins create-credentials-by-xml <store> <domain> < <凭证.xml>  # 通过 XML 创建凭证
ssh jenkins get-credentials-as-xml <store> <domain> <凭证ID>       # 获取某个凭证的 XML（敏感信息脱敏）
ssh jenkins import-credentials-as-xml <store> < <凭证.xml>         # 通过 XML 导入凭证
ssh jenkins update-credentials-by-xml <store> <domain> <凭证ID> < <凭证.xml>  # 通过 XML 更新凭证
ssh jenkins delete-credentials <store> <domain> <凭证ID>           # 删除某个凭证
ssh jenkins get-credentials-domain-as-xml <store> <domain>         # 获取某个凭证域的 XML
ssh jenkins create-credentials-domain-by-xml <store> < <域配置.xml>  # 通过 XML 创建凭证域
ssh jenkins update-credentials-domain-by-xml <store> <域名称> < <域配置.xml>  # 通过 XML 更新凭证域
ssh jenkins delete-credentials-domain <store> <域名称>              # 删除某个凭证域


# ===== 插件（Plugin）管理 =====
ssh jenkins list-plugins                       # 列出已安装的插件
ssh jenkins install-plugin <插件名或URL>        # 安装插件（可从文件、URL 或更新中心安装）
ssh jenkins enable-plugin <插件名>              # 启用一个或多个插件（含依赖）
ssh jenkins disable-plugin <插件名>             # 禁用一个或多个插件


# ===== Pipeline / Groovy =====
ssh jenkins declarative-linter < Jenkinsfile           # 校验一段 Declarative Pipeline 脚本（从标准输入读取）
ssh jenkins groovy <脚本文件>                            # 执行指定的 Groovy 脚本
ssh jenkins groovy = < <脚本文件>                        # 从标准输入执行 Groovy 脚本
ssh jenkins groovysh                                    # 启动交互式 Groovy Shell
ssh jenkins replay-pipeline <Job名称> < <脚本文件>        # 用编辑后的脚本重放某次 Pipeline 构建（从标准输入读取脚本）


# ===== 系统 / 维护 =====
ssh jenkins quiet-down                                   # 让 Jenkins 进入静默模式，准备重启（不启动新构建）
ssh jenkins cancel-quiet-down                            # 取消静默模式
ssh jenkins clear-queue                                  # 清空构建队列
ssh jenkins reload-configuration                         # 丢弃内存中已加载的数据，从文件系统重新加载全部配置
ssh jenkins restart                                      # 重启 Jenkins
ssh jenkins safe-restart                                 # 安全重启 Jenkins（等待已有构建完成）
ssh jenkins safe-shutdown                                # 将 Jenkins 置于静默模式，等待现有构建完成后关闭
ssh jenkins shutdown                                     # 立即关闭 Jenkins 服务器
ssh jenkins restart-from-stage <Job名称> <构建号> <阶段名>  # 从某个已完成的 Declarative Pipeline 构建的指定阶段重新开始


# ===== 邮件 =====
ssh jenkins mail < <邮件内容.txt>                         # 从标准输入读取内容并作为邮件发送
```

