> 基础设施即代码工具：安全、可重复地构建、变更和管理基础设施资源

------

### 配置文件

|       文件名        | 内容              |
| :-----------------: | :---------------- |
|      `main.tf`      | 核心资源配置      |
|    `provider.tf`    | Provider 声明     |
|   `variables.tf`    | 接收的输入变量    |
|    `outputs.tf`     | 执行后的对外输出  |
| **`terraform.tf`**  | Terraform自身设置 |
| `terraform.tfstate` | 状态文件          |

### tf文件语法：HCL（声明式）

```shell
# 一个块的格式
块类型 "标签1" "标签2" {
   参数名 = 表达式
   参数名 = {  # 嵌套
     ...
   }
 }

# 块类型 "标签1" "标签2"
resource "资源类型" "本地名称" {}   # 声明要创建和管理的基础设施资源（如虚拟机、网络、数据库）	
data	   "数据类型" "本地名称" {}   # 读取已有资源的信息，不创建或管理
variable  "变量名"  {}	           # 声明模块的输入变量，实现参数化	
output	  "输出名"  {}            # 声明模块或根配置对外输出的值
provider	"云厂商"  {}            # 配置云厂商的连接和认证（区域、凭证等）
module	  "子模块"  {}            # 引用可复用的子模块
terraform	{}                     # 配置 Terraform 自身（版本要求、backend 后端）
locals    {}                     # 定义模块内部复用的局部值
lifecycle	{}                     # 嵌套块，控制资源的生命周期行为（如创建前销毁、忽略变更）	


 # 参数名 = 表达式（字面量，引用变量，函数，运算）
引用变量：resource.类型.名称.属性
。。。
```

### 命令

```shell
# 初始化工作目录，下载 provider、初始化 backend、安装模块
terraform init [选项]
-upgrade        # 升级 provider 和模块到允许的最新版本
-reconfigure    # 忽略已有 backend 配置，重新配置
-migrate-state  # 迁移已有 state 到新的 backend


terraform fmt [-recursive递归]  # 格式化 .tf 文件（统一缩进、对齐）
terraform validate             # 校验语法和配置合法性（不访问远端）


# 预览将要执行的操作（最重要，先看再改）
terraform plan [选项]
-out=tfplan               # 把计划保存到文件，供 apply 使用
-var="key=value"          # 传入变量
-var-file="prod.tfvars"   # 使用变量文件
-target=aws_instance.web  # 只针对指定资源做计划
-destroy                  # 预览销毁操作


# 执行变更（会再次确认）
terraform apply [选项]
-auto-approve             # 跳过确认，直接执行（CI/CD 常用）
tfplan                    # 执行之前保存的计划文件
-target=aws_instance.web  # 只应用指定资源
-refresh-only             # 刷新 state 与真实资源同步


# 销毁所有管理的基础设施（⚠️不然烧钱）
terraform destroy [选项]
-auto-approve             # 跳过确认销毁
-target=aws_instance.web  # 只销毁指定资源


# 查看当前 state 内容
terraform show [选项]
list                      # 列出 state 中所有资源
show <资源地址>            # 查看某个资源详情
mv <源> <目标>             # 重命名/移动资源（重构用）
rm <资源地址>              # 从 state 移除（不删除真实资源）
pull/push                 # 拉取/推送远端 state 到本地


terraform import <资源地址> <资源ID>  # 把已有资源导入 state
terraform output <名称> [-json输出]  # 查看 output


terraform workspace list          # 列出所有工作区
terraform workspace new <名称>     # 创建工作区
terraform workspace select <名称>  # 切换工作区
terraform workspace show          # 显示当前工作区
terraform workspace delete <名称>  # 删除工作区


terraform providers            # 列出当前配置使用的 provider
terraform providers lock       # 生成依赖锁文件 .terraform.lock.hcl
terraform graph                # 输出资源依赖图（DOT 格式）
terraform console              # 交互式控制台，测试表达式/函数
terraform version              # 查看版本
terraform -help                # 查看帮助
TF_LOG=DEBUG terraform apply   # 开启调试日志
```

### 架构

```Shell
┌─────────────────────────────────────────────┐
│              Terraform Core                 │
│  ┌─────────────┐  ┌─────────────┐           │
│  │ 配置解析     │  │ 依赖图引擎    │           │
│  │ (HCL)       │  │ (Graph)     │           │
│  └─────────────┘  └─────────────┘           │
│  ┌─────────────┐  ┌─────────────┐           │
│  │ State 管理   │  │ 执行计划引擎  │           │
│  └─────────────┘  └─────────────┘           │
└───────────────┬─────────────────────────────┘
                │ gRPC / 插件协议
    ┌───────────┼───────────┬───────────┐
    ▼           ▼           ▼           ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│ AWS    │ │ Azure  │ │ GCP    │ │ K8s    │
│Provider│ │Provider│ │Provider│ │Provider│
└────────┘ └────────┘ └────────┘ └────────┘
    │           │           │           │
    ▼           ▼           ▼           ▼
 云 API      云 API      云 API      K8s API
 
Provider  → 跟谁对话（阿里云/AWS/本地文件/K8s）
Resource  → 要创建/管理什么（ECS、VPC、DNS 记录）
Data Source → 只读查询已有东西（现有 VPC ID、可用区列表）
State     → Terraform 记录"我管了哪些资源、它们现在啥样"的账本
```

