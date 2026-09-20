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
```

### 块的配置示例

```Shell
# ============================================================
# 1. terraform 块 —— 配置 Terraform 自身（版本、Provider 来源、backend）
# ============================================================
terraform {                                              # 声明 terraform 块，全局唯一
  required_version = ">= 1.5.0"                          # 要求 Terraform 版本不低于 1.5.0

  required_providers {                                   # 声明本配置依赖的 Provider
    aws = {                                              # Provider 本地键名为 aws
      source  = "hashicorp/aws"                          # Provider 来源地址（Registry）
      version = "~> 5.0"                                 # 版本约束：5.x 最新版
    }
  }

  backend "s3" {                                         # 配置远端 state 存储
    bucket         = "my-terraform-state"                # state 存放的 S3 桶
    key            = "prod/terraform.tfstate"            # state 文件在桶内的路径
    region         = "us-west-2"                         # S3 桶所在区域
    dynamodb_table = "terraform-lock"                    # 用 DynamoDB 表实现状态锁
    encrypt        = true                                # 启用服务端加密
  }
}

# ============================================================
# 2. provider 块 —— 配置云厂商连接与认证
# ============================================================
provider "aws" {                                         # 声明 AWS Provider
  region  = var.region                                   # 区域由变量传入
  profile = "default"                                    # 使用本地 AWS CLI 的 default profile

  default_tags {                                         # 为所有资源自动附加默认标签
    tags = {
      Environment = var.env                              # 标签：环境
      ManagedBy   = "terraform"                          # 标签：管理工具
    }
  }
}

provider "aws" {                                         # 第二个同类型 Provider
  alias  = "east"                                        # 别名 east，用于多区域场景
  region = "us-east-1"                                   # 该别名指向 us-east-1
}

# ============================================================
# 3. variable 块 —— 声明输入变量
# ============================================================
variable "region" {                                      # 声明变量 region
  type        = string                                   # 类型为字符串
  default     = "us-west-2"                              # 默认值
  description = "AWS 区域"                               # 变量说明
}

variable "env" {                                         # 声明变量 env
  type        = string                                   # 类型为字符串
  default     = "dev"                                    # 默认值
  sensitive   = false                                    # 是否在输出中隐藏
  nullable    = false                                    # 禁止传 null

  validation {                                           # 变量校验块
    condition     = contains(["dev", "prod"], var.env)   # 校验条件：只能是 dev 或 prod
    error_message = "env 必须是 dev 或 prod。"           # 校验失败提示
  }
}

variable "instance_type" {                               # 声明变量 instance_type
  type    = string                                       # 类型为字符串
  default = "t3.micro"                                   # 默认值
}

# ============================================================
# 4. locals 块 —— 定义模块内部复用的局部值
# ============================================================
locals {                                                 # 声明 locals 块（可多个，会合并）
  common_tags = {                                        # 定义局部值 common_tags
    Project     = "myapp"                                # 标签：项目名
    Environment = var.env                                # 标签：引用变量 env
    ManagedBy   = "terraform"                            # 标签：管理工具
  }

  name_prefix = "${var.env}-myapp"                       # 定义局部值 name_prefix，字符串插值
}

# ============================================================
# 5. data 块 —— 读取已有资源信息（只读，不创建）
# ============================================================
data "aws_ami" "ubuntu" {                                # 声明数据源 aws_ami，本地名 ubuntu
  most_recent = true                                     # 只取最新的一条结果

  filter {                                               # 过滤条件块
    name   = "name"                                      # 过滤字段：name
    values = ["ubuntu/images/hvm-ssd/*"]                 # 匹配的取值列表
  }

  owners = ["099720109477"]                              # 限制镜像所有者（Canonical）
}

# ============================================================
# 6. module 块 —— 引用可复用的子模块
# ============================================================
module "vpc" {                                           # 声明模块实例，本地名 vpc
  source  = "terraform-aws-modules/vpc/aws"              # 模块来源（必须是字面字符串）
  version = "5.0.0"                                      # 模块版本约束

  name = "${local.name_prefix}-vpc"                      # 传给子模块 variable：name
  cidr = "10.0.0.0/16"                                   # 传给子模块 variable：cidr
  azs  = ["us-west-2a", "us-west-2b"]                    # 传给子模块 variable：azs

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]       # 传给子模块 variable：私有子网
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]   # 传给子模块 variable：公有子网

  providers = {                                          # 将 Provider 配置传给子模块
    aws = aws.east                                       # 子模块使用别名为 east 的 Provider
  }

  depends_on = [aws_iam_role_policy.example]             # 显式声明模块依赖
}

# ============================================================
# 7. resource 块 —— 创建和管理基础设施资源
# ============================================================
resource "aws_instance" "web" {                          # 声明资源 aws_instance，本地名 web
  ami           = data.aws_ami.ubuntu.id                 # 参数：引用 data 块的属性
  instance_type = var.instance_type                      # 参数：引用变量
  subnet_id     = module.vpc.public_subnets[0]           # 参数：引用模块输出
  count         = var.env == "prod" ? 3 : 1              # 元参数 count：条件表达式决定数量
  provider      = aws.east                               # 元参数 provider：指定使用别名 Provider

  tags = merge(local.common_tags, { Name = "web" })      # 参数：调用函数合并局部值

  user_data = <<-EOT                                     # 参数：Heredoc 多行字符串
    #!/bin/bash
    echo "Hello, ${var.env}"
  EOT

  lifecycle {                                            # 嵌套块：控制资源生命周期
    create_before_destroy = true                         # 先建新再删旧，实现零停机
    prevent_destroy       = false                        # 是否阻止销毁
    ignore_changes        = [tags]                       # 忽略 tags 的外部变更
    replace_triggered_by  = [aws_security_group.web.id]  # 安全组变更时触发替换

    precondition {                                       # 前置条件校验
      condition     = var.instance_type != ""            # 校验条件
      error_message = "instance_type 不能为空。"         # 失败提示
    }

    postcondition {                                      # 后置条件校验
      condition     = self.public_ip != ""               # 校验资源创建结果
      error_message = "实例未分配公网 IP。"              # 失败提示
    }
  }
}

resource "aws_security_group" "web" {                    # 声明安全组资源
  name   = "${local.name_prefix}-sg"                     # 参数：引用局部值
  vpc_id = module.vpc.vpc_id                             # 参数：引用模块输出

  ingress {                                              # 嵌套块：入站规则
    from_port   = 80                                     # 起始端口
    to_port     = 80                                     # 结束端口
    protocol    = "tcp"                                  # 协议
    cidr_blocks = ["0.0.0.0/0"]                          # 允许的来源网段
  }

  egress {                                               # 嵌套块：出站规则
    from_port   = 0                                      # 起始端口
    to_port     = 0                                      # 结束端口
    protocol    = "-1"                                   # -1 表示全部协议
    cidr_blocks = ["0.0.0.0/0"]                          # 允许的目标网段
  }
}

# ============================================================
# 8. output 块 —— 声明对外输出的值
# ============================================================
output "instance_id" {                                   # 声明输出 instance_id
  value       = aws_instance.web.id                      # 必需：输出值（引用资源属性）
  description = "EC2 实例 ID"                            # 输出说明
  sensitive   = false                                    # 是否在 CLI 输出中隐藏
}

output "vpc_id" {                                        # 声明输出 vpc_id
  value = module.vpc.vpc_id                              # 引用模块输出
}
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

