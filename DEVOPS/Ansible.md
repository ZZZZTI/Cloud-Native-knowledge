> 在控制节点上安装的IT自动化运维引擎，用于配置管理，应用部署多台远程服务器

------

### inventory.ini(主机清单)

```shell
# 第一个组
[webservers]
web1 ansible_host=Web1服务器IP ansible_user=root [ansible_port=22]
web2 ansible_host=Web2服务器IP ansible_user=root
# 第二个组
[dbservers]
db1 ansible_host=数据库服务器IP ansible_user=root

# 定义父组，包含子组
[web_servers:children]
webservers
dbservers

# 组变量
[webservers:vars]
ansible_user=deploy
ansible_python_interpreter=/usr/bin/python3.12

[dbservers:vars]
ansible_user=dbadmin
ansible_python_interpreter=/usr/bin/python3.11

# 所有主机的通用变量
[all:vars]
ansible_ssh_private_key_file=~/.ssh/id_rsa
ansible_python_interpreter=/usr/bin/python3.12
```

### ansible.cfg(配置文件)

```shell
[defaults]
# 主机清单文件
inventory = inventory.ini
# SSH 连接超
timeout = 30
# 禁用主机密钥检查
host_key_checking = False
# 显示警告
display_warnings = False
# Python 解释器路径
interpreter_python = /usr/bin/python3.12
# 日志文件
log_path = ./ansible.log
# 并行进程数
forks = 5
# 使用更快的SSH连接方式
[ssh_connection]
pipelining = True
control_path = /tmp/ansible-%%h-%%p
```

### Ad-Hoc命令(临时)

```Shell
ansible [-i inventory.ini] [all/特定组] [模块] [--limit ip]  [-v]    [-b]     [> txt]
          指定清单            执行对象            限制主机      信息  root权限   结果写入文件

模块：
# 简单命令/shell命令/原始命令/服务管理命令/包管理命令/用户管理
-m command/shell/raw/systemd/apt/user -a "命令"  

-m setup -a "filter=过滤信息"   # 查看系统信息
-m script -a "script.sh"      # 执行脚本
-m copy -a "txt1 txt2"        # 复制文件
-m file	-a "path= state= "    # 管理文件和目录属性

name=对象/服务名
state=present(安装)/absent(卸载)/latest(更新到最新版)
```

### playbook.yml(可重复执行)

```shell
# 执行playbook
ansible-playbook playbook01.yml [--check(检查语法)] [-v] [--tags 标记]

# playbook文件格式
---
- name: playbook1             # 描述这个Play要做什么
  hosts: webservers           # 目标主机组
  become: yes                 # 是否提权（sudo）
  gather_facts: yes           # 在任务前自动执行 setup 模块
  # 定义变量  vars_files/vars_prompt->外部变量文件/交互式变量
  vars:                      
    app_port: 8080
  
  
  # 引入roles
  roles:                      
    - role: nginx
      vars:                   # 给role传递变量
        nginx_port: 8080
        nginx_server_name: example.com
  # 任务列表（核心）  pre_tasks/post_tasks->前置任务/后续任务
  tasks:                      
    - name: 任务描述
      模块名:
        参数: 值
    - name: 另一个任务
      模块名:
        参数: 值
  # 触发器（只有任务变更时才执行）
  handlers:                   
    - name: 重启Nginx
      systemd:
        name: nginx
        state: restarted





执行顺序：pre_tasks → roles → tasks → post_tasks → handlers
  
# 使用变量
"应用 {{ app_name }} 运行在端口 {{ app_port }}"
# Facts（自动收集的主机信息）
"CPU核心数 {{ ansible_processor_cores }}"
# Register（保存任务的结果
register: hostname_result


# 控制流
when: ansible_os_family == "Debian"    # 条件
  loop:                                # 循环
    - nginx
    - mysql-server
    - python3
    - git

# 模块：
setup    filter过滤
debug    msg/var打印
assert   that断言验证
file     path路径/state创建的类型/owner,group设定/mode权限
copy     src/dest路径/content内容
template 
fecth    flat
stat
systemd  enable:yes开机自启
user
# 参数:值
path/src/dest: /usr/bin/python3 # 路径
tags: [nginx, install]   # 标记
force:yes  # 强制操作
backup:yes # 备份
recurse:yes# 递归
state:file/directory/link/hard/touch/absent# 创建普通文件/目录/软链接/硬链接/空文件/删除[file]
state:present/absent/latest                # 安装/卸载/更新到最新版[apt]
state:started/stopped/reloaded/restarted   # [systemd]
```

### Jinja2模版(动态生成配置文件)

```Shell
# templates/nginx.conf.j2
user {{ nginx_user | default('www-data') }};
worker_processes {{ ansible_processor_cores * 2 }};
pid /run/nginx.pid;

events {
    worker_connections {{ worker_connections | default(1024) }};
}

http {
    server {
        listen {{ app_port | default(80) }};
        server_name {{ server_name | default('_') }};
        root /var/www/{{ app_name }};
        
        location / {
            try_files $uri $uri/ /index.html;
        }
    }
}
```

### Role(在playbook上引用)

```Shell
# 搜索Nginx相关的Role
ansible-galaxy search nginx

# 查看某个Role的详细信息
ansible-galaxy info geerlingguy.nginx

# 安装到项目目录 roles/
ansible-galaxy install geerlingguy.nginx -p roles/

# 初始化一个Role
ansible-galaxy init <nginx>

# role的目录结构
roles/
└── nginx/                    # Role名称
    ├── tasks/
    │   └── main.yml          # 主任务文件（必需）
    ├── handlers/
    │   └── main.yml          # 触发器
    ├── templates/            # Jinja2模板文件
    │   └── nginx.conf.j2
    ├── files/                # 静态文件（copy模块用）
    │   └── index.html
    ├── vars/
    │   └── main.yml          # 变量（优先级高）
    ├── defaults/
    │   └── main.yml          # 默认变量（优先级最低，推荐放这里）
    ├── meta/
    │   └── main.yml          # Role的依赖关系
    └── README.md             # 说明文档
```

### 架构

```Shell
基础概念
Ansible 是什么：开源自动化运维工具，用于配置管理、应用部署、任务执行。基于 Python，无 Agent，通过 SSH 通信。
核心特点：无 Agent、SSH 连接、YAML 编写、幂等性、模块化、简单易学。
和其他工具区别：比 Puppet、Chef 轻量无 Agent；比 SaltStack 简单；比 Shell 脚本规范、幂等、可复用。


核心组件
Inventory：主机清单，定义被管理主机，可分组，默认 /etc/ansible/hosts。
Playbook：YAML 剧本，定义任务序列，是核心。
Module：模块，执行具体操作。
Task：任务，调用模块的最小单元。
Role：角色，把任务、变量、文件、模板组织成可复用结构。
Handler：处理器，被 notify 触发，任务 changed 时执行，常用于重启服务。
Variable：变量。
Fact：Ansible 自动收集的被控端信息。
Template：Jinja2 模板，动态生成配置文件。


幂等性
多次执行同一任务结果一致，不会重复改变状态。靠模块内部判断当前状态，只在需要时改变。好处是安全可重复。


Inventory
INI 或 YAML 格式，中括号定义组，可设主机变量和组变量。
常用变量：ansible_host、ansible_port、ansible_user、ansible_password、ansible_ssh_private_key_file。
动态 Inventory：从云平台或 CMDB 动态获取


Playbook 结构
每个 play 含 hosts、become、vars、tasks、handlers、roles。
hosts 目标主机，become 提权，vars 变量，tasks 任务列表，handlers 处理器，roles 引用角色。


错误处理
ignore_errors 忽略错误，failed_when 自定义失败，changed_when 自定义 changed，block、rescue、always 错误块，retries、until 重试。


性能优化
pipelining 减少 SSH 连接，facts 缓存，strategy free 并行，加大 forks，async 异步，关闭 gather_facts，SSH 长连接 ControlPersist。
```

