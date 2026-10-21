> ☁️ ：云计算服务平台，提供计算、存储、网络、数据库、安全等云产品，支持企业上云和各类应用的弹性部署。
>
> TCCLI是管理腾讯云资源的统一命令行工具，调用腾讯云 API 来管理腾讯云资源，基于 TCCLI 来做自动化和脚本。

------

### CVM,VPC,CBS,COS.......

```Shell
tccli auth login/logout [--profile user1]  # 登陆/退出账号

一、初始化配置
tccli configure
tccli configure set secretId <你的SecretId> secretKey <你的SecretKey> region ap-guangzhou output json
tccli configure list
tccli configure --profile test
tccli cvm DescribeInstances --profile test

说明：output 支持 json、table、text，默认 json。多账户用 --profile。

二、通用参数
--region 指定资源地域，例如 --region ap-shanghai
--profile 指定多账户配置，例如 --profile test
--output 输出格式，例如 --output table
--cli-unfold-argument 复杂参数用点号展开，例如 --Placement.Zone ap-guangzhou-3
--generate-cli-skeleton 生成 JSON 入参骨架
--cli-input-json 从 JSON 文件读入参数，例如 --cli-input-json file://params.json
--waiter 轮询直到状态满足条件

三、云服务器 CVM
tccli cvm DescribeInstances
tccli cvm DescribeInstances --region ap-guangzhou
tccli cvm DescribeInstances --Filters '[{"Name":"private-ip-address","Values":["10.0.0.1"]}]'
tccli cvm DescribeZones
tccli cvm DescribeImages --Filters '[{"Name":"image-type","Values":["PUBLIC_IMAGE"]}]'
tccli cvm RunInstances --InstanceChargeType POSTPAID_BY_HOUR --Placement '{"Zone":"ap-guangzhou-2"}' --InstanceType S1.SMALL1 --ImageId img-8toqc6s3 --SystemDisk '{"DiskType":"CLOUD_BASIC","DiskSize":50}' --InstanceCount 1 --InstanceName TCCLI-TEST --LoginSettings '{"Password":"TCCLI"}' --SecurityGroupIds '["sg-0rszg2vb"]'
tccli cvm StartInstances --InstanceIds '["ins-xxxxx"]'
tccli cvm StopInstances --InstanceIds '["ins-xxxxx"]'
tccli cvm DescribeInstancesStatus --region ap-hongkong --waiter "{'expr':'InstanceStatusSet[0].InstanceState','to':'RUNNING','timeout':180,'interval':5}"

说明：创建实例时，非简单类型参数用标准 JSON。轮询适合脚本等待异步操作。

四、对象存储 COS
tccli cos ListBuckets
tccli cos CreateBucket --Bucket <bucket-name> --Region <region>
tccli cos PutObject --Bucket <bucket-name> --Key <file-key> --Body <file-path>
tccli cos ls cos://<bucket-name>/ --recursive
tccli cos PutBucketAcl --Bucket <bucket-name> --AccessControlList public-read

说明：创建桶时 Region 需与目标地域一致。

五、私有网络 VPC
tccli vpc DescribeVpcs
tccli vpc DescribeSubnets
tccli vpc DescribeSecurityGroups
tccli vpc DescribeSecurityGroupPolicies --SecurityGroupId sg-xxx
tccli vpc DescribeAddresses

说明：安全组规则查询需要先拿到 SecurityGroupId。

六、云硬盘 CBS
tccli cbs DescribeDisks
tccli cbs AttachDisks --region <region> --InstanceId ins-xxxxx --DiskIds '["disk-xxxxx"]'

说明：DescribeDisks 常与 DescribeInstances 搭配使用。

七、身份与权限查询
tccli sts GetCallerIdentity
tccli cam ListAttachedUserPolicies --TargetUin <你的UIN>

说明：sts GetCallerIdentity 是验证配置是否生效的最快方式。

八、实用技巧
获取帮助：
tccli help
tccli cvm help
tccli cvm DescribeInstances help

自动补全：
complete -C 'tccli_completer' tccli

传输二进制文件：
tccli cls UploadLog --TopicId xxx < /path/to/file

降低复杂参数输入难度：
tccli cvm RunInstances --cli-unfold-argument --Placement.Zone ap-guangzhou-3 --ImageId img-8toqc6s3 --DryRun True
```

### lighthouse

```Shell
一、实例管理

查看实例列表
tccli lighthouse DescribeInstances
tccli lighthouse DescribeInstances --region ap-guangzhou
tccli lighthouse DescribeInstances --InstanceIds '["lhins-xxxxxxxx"]'
tccli lighthouse DescribeInstances --Filters '[{"Name":"instance-name","Values":["zhangsan"]}]' --Offset 0 --Limit 100

启动实例（仅 STOPPED 状态可操作）
tccli lighthouse StartInstances --InstanceIds '["lhins-xxxxxxxx"]'

停止实例（仅 RUNNING 状态可操作）
tccli lighthouse StopInstances --InstanceIds '["lhins-xxxxxxxx"]'

重启实例（仅 RUNNING 状态可操作）
tccli lighthouse RebootInstances --InstanceIds '["lhins-xxxxxxxx"]'

重置实例密码（建议先关机再操作）
tccli lighthouse ResetInstancesPassword --InstanceIds '["lhins-xxxxxxxx"]' --Password 'YourPassword@123'

说明：实例 ID 以 lhins- 开头。批量操作时用逗号分隔多个 ID，每次请求上限为 100 个实例。[reference:0][reference:1][reference:2][reference:3][reference:4]

二、防火墙规则

查看防火墙规则
tccli lighthouse DescribeFirewallRules --InstanceId lhins-xxxxxxxx

创建防火墙规则（开放 HTTP 80 端口）
tccli lighthouse CreateFirewallRules --InstanceId lhins-xxxxxxxx --FirewallRules '[{"Protocol":"TCP","Port":"80","Action":"ACCEPT"}]'

使用点号展开方式开放端口
tccli lighthouse CreateFirewallRules --region ap-guangzhou --cli-unfold-argument --InstanceId lhins-xxxxxxxx --FirewallRules.0.Protocol TCP --FirewallRules.0.Port 80 --FirewallRules.0.Action ACCEPT

说明：Protocol 支持 TCP、UDP；Action 支持 ACCEPT、DROP。开放 443 端口时只需将 Port 改为 443。[reference:5][reference:6]

三、快照管理

查看快照列表
tccli lighthouse DescribeSnapshots --region ap-guangzhou

创建实例快照（备份系统盘）
tccli lighthouse CreateInstanceSnapshot --InstanceId lhins-xxxxxxxx --SnapshotName "backup-linux-$(date +%Y%m%d)"

说明：CreateInstanceSnapshot 用于创建系统盘快照，SnapshotName 可选，建议加上日期标识便于后续查找。快照可用于后续恢复或创建自定义镜像。[reference:7][reference:8]

四、镜像与套餐

查看套餐列表（选择实例规格）
tccli lighthouse DescribeBundles --region ap-guangzhou

查看应用镜像（WordPress、宝塔、LAMP 等）
tccli lighthouse DescribeBlueprints --region ap-guangzhou

说明：DescribeBundles 返回可购买的套餐规格，DescribeBlueprints 返回可用镜像列表，包括公共镜像、自定义镜像、共享镜像等类型。[reference:9][reference:10]

五、流量包查询

查看实例流量包详情
tccli lighthouse DescribeInstancesTrafficPackages --InstanceIds '["lhins-xxxxxxxx"]'

提取已用流量（单位字节）
tccli lighthouse DescribeInstancesTrafficPackages --InstanceIds '["lhins-xxxxxxxx"]' --filter 'InstanceTrafficPackageSet[0].TrafficPackageSet[0].TrafficUsed'

说明：流量包详情包含总量、已用量、剩余量。可用于脚本中实现流量监控和告警。[reference:11][reference:12]

六、监控数据

查询 CPU 利用率（需使用 monitor 服务）
tccli monitor GetMonitorData --Namespace QCE/LIGHT_HOUSE --MetricName cpu_usage --Instances '[{"Dimensions":[{"Name":"instanceId","Value":"lhins-xxxxxxxx"}]}]'

说明：Lighthouse 的监控命名空间为 QCE/LIGHT_HOUSE，常用指标包括 cpu_usage、mem_usage 等。[reference:13]

七、完整操作示例：查询并批量重启实例

第一步：查询实例列表并提取实例 ID
tccli lighthouse DescribeInstances --cli-unfold-argument --region ap-guangzhou --Filters.0.Name instance-name --Filters.0.Values zhangsan --Offset 0 --Limit 100 --filter 'InstanceSet[*].{id:InstanceId}' --output text > /root/insid.txt

第二步：批量重启（读取上一步生成的实例 ID 文件）
tccli lighthouse RebootInstances --InstanceIds $(cat /root/insid.txt)

说明：--filter 参数用于提取指定字段，--output text 输出纯文本，便于脚本处理。[reference:14]

八、帮助命令

查看 Lighthouse 所有可用接口
tccli lighthouse help

查看具体接口的参数说明
tccli lighthouse DescribeInstances help

说明：tccli 的 API 参数可能随版本更新，执行前建议先用 help 确认最新参数格式。[reference:15]
```

------

### 资源与网络

CVM,Lighthouse,TKE,AS,VPC,ACL,NAT,安全组,CLB,CCN

```Shell
云服务器 CVM：这是运维的“主机”。需要掌握实例生命周期管理、镜像管理（自定义镜像）、快照与备份策略，以及通过自动化助手 TAT 批量执行命令。
lighthouse

负载均衡CLB，弹性伸缩

腾讯K8S引擎 TKE：前置授权，创建集群，部署应用

网络基础概念：理解 VPC（私有网络）、子网、路由表。安全组（实例级防火墙）和网络 ACL（子网级防火墙）是重点，必须掌握其区别与配置逻辑。
NAT

成本治理：从组织、预算、资源三个维度做前置成本规划，预测未来成本走势，清理僵尸资源，检查预留实例使用率，审查带宽费用
```

### 安全与可观测

TCOP,CLS,APM,cloudQ,DDos,CAM,ufw

```Shell
责任共担模型：明确腾讯云负责底层基础设施安全，你负责云上业务、数据、权限和网络配置。这是云安全的基石。

访问控制与账号安全：理解主账号与子账号（CAM）的区别。生产环境应使用子账号并启用 MFA（多因素认证），遵循最小权限原则。

可观测平台：掌握云监控TOCP（看 CVM 等基础指标）、日志服务 CLS（一站式日志采集与检索）、应用性能监控 APM。重点学习配置合理的告警策略，避免告警风暴。

ALops：腾讯云cloudQ 用来AI智能定时巡检，主动巡检、主动诊断、主动决策

访问管理 CAM：子账号、MFA、最小权限，这是所有操作的前提。
Web 应用防火墙 WAF：如果对外提供 Web 服务，WAF 能拦截常见的 OWASP Top 10 攻击。
DDoS 防护：基础防护默认开启，高防用于应对大流量攻击。
```

### 数据库与存储

CBS,DTS,COS,CLB,快照

```Shell
块存储与快照：理解云硬盘（CBS）的扩容与性能指标。快照是数据安全的最后一道防线，需制定定期快照与跨地域复制策略

云数据库运维：掌握腾讯云 TencentDB for MySQL/PostgreSQL/Redis 的日常运维。重点包括参数调优、备份恢复演练，以及利用 DBbrain 进行慢 SQL 分析和故障诊断。

数据传输服务 DTS：用于数据库云上迁移、同步，备份与导出。需要掌握迁移流程与数据一致性校验。

对象存储 COS：用于存放静态资源、日志备份等。重点掌握存储桶权限管理、生命周期管理及监控关键指标。

负载均衡 CLB：当业务扩展到多台服务器时，CLB 负责流量分发。你需要关注健康检查配置和访问日志分析。
```

### ACP考试

```Shell
基础云应用架构（35%）：这是占比最大的模块，也是你六阶段里接触最多的。考核点包括：根据业务场景选择计算、存储、数据库服务；构建分层架构方案；完成基础架构的部署和配置；使用云监控完成资源监控。对应的阿里云产品是 ECS（云服务器）、OSS（对象存储）、RDS（云数据库）等。

复杂云网络架构（25%）：考核 VPC（专有网络）的规划和构建、NAT 网关、负载均衡 SLB、弹性公网 IP、云企业网 CEN、VPN 网关、高速通道等互联互通方案。你之前学的腾讯云 VPC、安全组、CLB 在这里可以直接迁移——概念是通的，只是产品名和操作界面不同。

云上高可用、高性能架构（25%）：考核跨地域、跨可用区资源规划，负载均衡配置，故障转移机制，以及根据业务需求设计高可用方案。

云上安全体系架构（15%）：考核 DDoS 防护、WAF、安全审计、访问控制（RAM）、安全组策略等。
```

| 服务类别       | 腾讯云                    | 阿里云              | AWS                        |
| :------------- | :------------------------ | :------------------ | :------------------------- |
| 云服务器       | **云服务器 CVM**          | **云服务器 ECS**    | **Amazon EC2**             |
| 轻量应用服务器 | 轻量应用服务器 Lighthouse | 轻量应用服务器 SWAS | Amazon Lightsail           |
| 弹性伸缩       | 弹性伸缩 AS               | 弹性伸缩 ESS        | EC2 Auto Scaling           |
| K8s 容器服务   | **容器服务 TKE**          | **容器服务 ACK**    | **Amazon EKS**             |
| 对象存储       | **对象存储 COS**          | **对象存储 OSS**    | **Amazon S3**              |
| 块存储         | 云硬盘 CBS                | 块存储 EBS          | Amazon EBS                 |
| 文件存储       | 文件存储 CFS              | 文件存储 NAS        | Amazon EFS                 |
| 归档存储       | 归档存储 CAS              | 归档存储 OAS        | Amazon S3 Glacier          |
| 私有网络       | **私有网络 VPC**          | **专有网络 VPC**    | **Amazon VPC**             |
| 负载均衡       | 负载均衡 CLB              | 负载均衡 SLB        | Elastic Load Balancing ELB |
| 云联网         | 云联网 CCN                | 云企业网 CEN        | AWS Transit Gateway        |
| 关系型数据库   | 云数据库 TencentDB        | 云数据库 RDS        | Amazon RDS                 |
| 身份访问管理   | **访问管理 CAM**          | **访问控制 RAM**    | **AWS IAM**                |
