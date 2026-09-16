> 基础设施即代码工具：安全、可重复地构建、变更和管理基础设施资源

------

### 配置文件

| 文件名         | 核心作用                                   |
| :------------- | :----------------------------------------- |
| `main.tf`      | 声明要创建和管理的基础设施资源及其期望状态 |
| `provider.tf`  | 声明使用的 Provider 名称、版本及认证方式   |
| `variables.tf` | 声明模块可接收的输入变量，提升复用性       |
| `outputs.tf`   | 声明模块执行完毕后对外输出的信息           |

### 核心

```Shell
Provider  → 跟谁对话（阿里云/AWS/本地文件/K8s）
Resource  → 要创建/管理什么（ECS、VPC、DNS 记录）
Data Source → 只读查询已有东西（现有 VPC ID、可用区列表）
State     → Terraform 记录"我管了哪些资源、它们现在啥样"的账本
```

### tf文件语法:hcl

```shell
# 块（block）：类型 + 标签 + 花括号
resource "alicloud_instance" "web" {
  # 参数（argument）：key = value
  instance_type = "ecs.t5-lc1m1.small"
  image_id      = "ubuntu_22_04_x64_20G_alibase_20240101.vhd"

  # 嵌套块
  tags = {
    Name = "web-server"
    Env  = "dev"
  }
}

# 变量类型
variable "count"    { type = number }   # 数字
variable "enabled"  { type = bool }     # 布尔
variable "name"     { type = string }   # 字符串
variable "zones"    { type = list(string) }  # 列表
variable "tags"     { type = map(string) }   # 映射
variable "server" {                      # 对象
  type = object({
    name = string
    cpu  = number
  })
}

# 字符串插值与 heredoc
locals {
  name_prefix = "dev-${var.project}"
  user_data   = <<-EOT
    #!/bin/bash
    echo "Hello ${var.project}" > /tmp/hello.txt
  EOT
}

data只读查询
# 查现有可用区，不创建任何东西
data "alicloud_zones" "available" {
  available_resource_creation = "Instance"
}

output "zone_ids" {
  value = data.alicloud_zones.available.zones[*].id
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


# 销毁所有管理的基础设施
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
```

