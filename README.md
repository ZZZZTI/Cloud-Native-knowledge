# Welcome to ZTI's Cloud-Native knowledge repository

> I'm still learning......
>

## Knowledge structure

```css
.
├── K8S
│   ├── 架构
│   │   ├── helm.md
│   │   ├── pod.md
│   │   ├── 存储.md
│   │   ├── 安全.md
│   │   ├── 网络.md
│   │   ├── 调度.md
│   │   ├── 集群.md
│   │   └── 控制器.md
│   ├── ArgoCD.md
│   ├── CKA.md
│   ├── Isito.md
│   ├── docker.md
│   └── 排障.md
├── LINUX
│   ├── SHELL
│   │   ├── SHELL.md
│   │   ├── 文件.md
│   │   └── 文本.md
│   ├── 本机
│   │   ├── 内核.md
│   │   ├── 安全.md
│   │   ├── 目录.md
│   │   ├── 管理.md
│   │   ├── 网络.md
│   │   ├── 资源.md
│   │   └── 配置.md
│   └── RHEL.md
├── PYTHON
│   ├── 库
│   │   ├── 1-CLI.md
│   │   ├── 1-日志.md
│   │   ├── 1-系统.md
│   │   ├── 2-HTTP.md
│   │   ├── 2-并发.md
│   │   ├── 2-配置文件.md
│   │   ├── SSH.md
│   │   ├── 云.md
│   │   ├── 数据.md
│   │   └── 测试.md
│   ├── 语言
│   │   ├── class.md
│   │   ├── data.md
│   │   ├── def.md
│   │   ├── error.md
│   │   ├── import.md
│   │   ├── logic.md
│   │   └── string.md
│   ├── API.md
│   ├── HTTP.md
│   ├── 工程.md
│   └── 并发.md
├── SEC
│   ├── network
│   │   └── network.md
│   └── safety
│       ├── CKS.md
│       └── safety.md
├── SRE
│   ├── CICD
│   │   ├── Ansible.md
│   │   ├── Jenkins.md
│   │   ├── Terraform.md
│   │   ├── git.md
│   │   ├── gitlab.md
│   │   ├── gitlabai大纲.md
│   │   └── tccli.md
│   └── SRE
│       ├── Observe1.md
│       ├── Observe2.md
│       ├── SRE.md
│       └── cloud.md
├── TOOL
│   ├── Mysql
│   │   ├── basis.md
│   │   ├── func.md
│   │   ├── jdbc.md
│   │   ├── lock.md
│   │   ├── sql.md
│   │   └── tools.md
│   ├── nginx.md
│   ├── redis.md
│   ├── 文件.md
│   └── 组件.md
└── README.md
```

## two big project:（两个大项目要有变化，整合不同技术栈，做一些创新）

基于 IaC 与 GitOps 的多环境云原生交付平台（自动化、工具链整合）：   

https://github.com/ZZZZTI/Cloud-Native-knowledge.git

核心链路 SLO 保障与全链路可观测性治理（稳定性、监控、应急响应）：

https://github.com/ZZZZTI/Cloud-Native-knowledge.git


## some small projects:

服务器变慢的全链路排查

MySQL 备份恢复演练

Helm chart 化三层应用

Ansible 标准化服务器初始化

Trivy 镜像漏洞扫描 + 修复闭环

......

https://github.com/ZZZZTI/Cloud-Native-knowledge.git




目录树
```css
sre-knowledge/
├── README.md                          仓库说明、目录导航、阅读顺序
│
├── 00-索引/
│   ├── 学习路线.md                     12 周计划：每周读哪几篇 + 做什么练习
│   ├── 面试映射.md                     每个考点 → 对应文件 → 必背要点
│   └── 术语表.md                       缩写速查：SLO/RBAC/CNI/CSI/PVC/PSA…一句话解释
│
├── 01-Linux/                          ★★★ 必考
│   ├── 01-系统基础.md                  发行版差异、启动流程（BIOS→GRUB→systemd）、运行级别、systemd 单元
│   ├── 02-文件与目录.md                FHS 目录规范、inode、硬链接与软链接、find/locate、文件属性
│   ├── 03-用户与权限.md                用户组、rwx、SUID/SGID/Sticky、umask、sudo、ACL
│   ├── 04-进程与服务.md                ps/top、进程状态与父子关系、信号、systemctl 管理服务
│   ├── 05-资源与性能.md                CPU/内存/IO 指标、load 与核数关系、free 的 buff/cache、vmstat/iostat
│   ├── 06-存储与文件系统.md            分区、LVM 扩容、ext4 vs xfs、挂载、RAID、inode 耗尽
│   ├── 07-内核参数与限制.md            sysctl（net.*/vm.*）、ulimit、文件句柄、TIME_WAIT 调优
│   └── 08-系统排障手册.md              故障剧本：磁盘满、CPU 飙高、OOM、打开文件失败、登录慢
│
├── 02-Shell/                          ★★★ 必考
│   ├── 01-语法与变量.md                变量与引用、数组、参数展开、$?/$!/$@、单双引号区别
│   ├── 02-流程控制与函数.md            if/case/for/while、函数、返回值与退出码约定
│   ├── 03-文本三剑客.md                grep 参数、sed 增删改查、awk 字段统计与聚合
│   ├── 04-命令速查.md                  按场景组织：查日志/查端口/查磁盘/查进程/批量远程
│   └── 05-脚本规范与调试.md            set -euo pipefail、shellcheck、trap 清理、日志函数
│
├── 03-网络/                           ★★★ 必考
│   ├── 01-TCP-IP基础.md                OSI/TCP-IP、封装解封装、三次握手四次挥手、状态机、拥塞控制
│   ├── 02-HTTP与HTTPS.md               报文结构、方法、状态码、常用头、HTTP/1.1 vs 2、TLS 握手
│   ├── 03-DNS.md                       解析流程、记录类型、递归与迭代、解析慢与污染的排查
│   ├── 04-nginx与负载均衡.md           配置结构、反向代理、upstream、健康检查、L4 vs L7、502/504 成因
│   ├── 05-抓包与排障.md                tcpdump/wireshark、ss/netstat、连通性逐层排查路径
│   └── 06-网络面试题.md                输入 URL 到页面、TIME_WAIT 过多、粘包、跨网段通信过程
│
├── 04-容器/                           ★★★ 必考
│   ├── 01-Docker基础.md                镜像/容器/仓库、namespace 与 cgroup、生命周期、常用命令
│   ├── 02-镜像与Dockerfile.md          分层机制、多阶段构建、精简镜像、构建缓存
│   ├── 03-网络与存储.md                bridge/host/none、端口映射、volume 与 bind mount 区别
│   ├── 04-Compose.md                   单机多容器编排、depends_on、环境变量与 override
│   └── 05-容器排障.md                  起不来、退出码含义、日志、资源限制、进容器调试
│
├── 05-Kubernetes/                     ★★★★ 权重最高
│   ├── 01-架构与组件.md                apiserver/etcd/scheduler/controller-manager/kubelet/kube-proxy、CRI/CNI/CSI
│   ├── 02-集群部署.md                  kubeadm 单机与 HA（keepalived+VIP）、CIDR 规划、证书、版本升级
│   ├── 03-核心对象.md                  Pod、Namespace、ConfigMap/Secret、Label/Selector、OwnerReference
│   ├── 04-控制器.md                    Deploy/RS/StatefulSet/DaemonSet/Job/CronJob、滚动更新、HPA
│   ├── 05-Service与网络.md             ClusterIP/NodePort/LB、kube-proxy 模式、Ingress、CoreDNS、CNI
│   ├── 06-存储.md                      emptyDir/hostPath/PV/PVC/StorageClass/CSI、三种访问模式
│   ├── 07-调度.md                      资源请求与限制、亲和反亲和、污点容忍、QoS、驱逐
│   ├── 08-安全与RBAC.md                ServiceAccount、Role/ClusterRole、PSA、NetworkPolicy、Secret 管理
│   ├── 09-Helm与Kustomize.md           Chart 结构、values 覆盖、模板语法、两者取舍
│   ├── 10-集群运维.md                  etcd 备份恢复、节点扩缩容、证书轮换、etcd 性能与监控
│   └── 11-故障排查.md                  Pod 各状态逐一排、Service 不通、节点 NotReady、事件含义速查
│
├── 06-CI-CD/                          ★★ 会问
│   ├── 01-git.md                       常用命令、分支模型、rebase vs merge、冲突解决、撤销操作
│   ├── 02-GitLab-CI.md                 .gitlab-ci.yml 结构、stage/job、runner、变量与缓存、制品
│   ├── 03-Jenkins.md                   Pipeline 语法、agent、凭据管理、插件、与 GitLab CI 取舍
│   ├── 04-ArgoCD与GitOps.md            Application/AppProject、同步策略、Sync Waves/Hooks、漂移检测
│   └── 05-发布策略与回滚.md            滚动/蓝绿/金丝雀、流量切分、回滚与应急
│
├── 07-可观测性/                       ★★★ 必考
│   ├── 01-监控体系设计.md              黄金信号/RED/USE、指标+日志+链路三支柱、采集方式
│   ├── 02-Prometheus.md                架构、抓取配置、服务发现、四种指标类型、exporter
│   ├── 03-PromQL.md                    选择器、聚合、rate/increase、直方图与分位数、查询模板
│   ├── 04-Grafana.md                   面板设计、变量、常用图表、告警与看板分工
│   ├── 05-日志系统.md                  Promtail/LogQL、采集与切分、日志规范、成本控制
│   ├── 06-链路追踪.md                  Trace/Span、OTel 接入、Tempo、跨服务问题定位
│   └── 07-告警设计.md                  Alertmanager 路由/分组/抑制/静默、降噪、分级与值班
│
├── 08-数据存储/                       ★★ 会问
│   ├── 01-MySQL基础.md                 SQL、索引原理、执行计划、事务与隔离级别、锁
│   ├── 02-MySQL运维.md                 备份恢复、主从复制、慢查询优化、连接数、高可用方案
│   ├── 03-Redis.md                     数据类型与场景、持久化、主从/哨兵/集群、缓存三大问题
│   ├── 04-消息队列.md                  Kafka/RabbitMQ 模型、消费组、积压处理、运维要点
│   └── 05-数据可靠性.md                备份策略（3-2-1）、RPO/RTO、容量估算
│
├── 09-云与IaC/                        ★★ 会问
│   ├── 01-云平台基础.md                IaaS/PaaS、VPC/子网/安全组、SLB、对象存储、计费模型
│   ├── 02-云CLI与SDK.md                认证方式、常用资源查询、批量操作与限流
│   ├── 03-Terraform.md                 HCL、state 管理、plan/apply、模块化、多环境
│   └── 04-Ansible.md                   inventory、playbook、role、幂等、与 Terraform 的分工
│
├── 10-编程/                           ★★ 会写脚本
│   ├── 01-Python语言.md                类型/容器/函数/异常/类、高频易错点
│   ├── 02-Python标准库.md              os/sys/subprocess/shutil/pathlib/json/argparse/logging
│   ├── 03-Python运维库.md              requests/paramiko/psutil/kubernetes/prometheus-client
│   └── 04-Python工程化.md              并发模型、测试、日志规范、打包分发
│
├── 11-安全/                           ★ 加分项
│   ├── 01-安全基础.md                  等保、OWASP Top10、密码学基础、认证与授权
│   ├── 02-主机与网络安全.md            加固基线、防火墙、SSH 安全、入侵排查
│   ├── 03-容器与K8s安全.md             RBAC 加固、PSA、NetworkPolicy、运行时安全
│   └── 04-供应链安全.md                镜像扫描（Trivy）、SBOM、签名、CI 安全门禁
│
└── 12-SRE方法论/                      ★★ 必考（区分度最高）
    ├── 01-SRE是什么.md                 SRE vs 传统运维、Google SRE 核心实践
    ├── 02-SLI-SLO-SLA.md               指标设计、错误预算、燃尽率、怎么定 SLO
    ├── 03-故障处理流程.md              分级、响应、止损、沟通、无责复盘
    ├── 04-容量与成本.md                容量评估、压测、弹性、成本优化
    └── 05-变更管理.md                  变更风险分级、灰度、回滚、变更窗口
```
