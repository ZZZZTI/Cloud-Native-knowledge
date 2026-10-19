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

