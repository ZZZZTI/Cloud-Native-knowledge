> ☁️

------

### 云服务器

```Shell
KVM 虚拟化的底层原理：Hypervisor 分类、执行栈、快速路径与托管路径
云服务器十大核心技术：资源、地域可用区、云硬盘、镜像、快照、弹性网卡、安全组、迁移、弹性伸缩
CVM 产品体系：计费模式、安全架构、实例选型、产品族对比与专用宿主机
AI 与云算力：从通用算力到 AI 算力的切换信号、GPU 选型矩阵、HAI 与 TI 平台
```

### 云网络服务

```Shell
云网络的本质：从传统数据中心三层架构到 Overlay/Underlay 双层解耦
VPC 核心组件：CIDR、子网、路由表、网络 ACL、安全组的协作模型
VPC 互联方案：公网服务、私网互联、混合云、可观测性的选型逻辑
负载均衡 CLB：四层/七层差异、三种分发算法、典型容灾架构
内容分发网络 CDN：架构、八大术语、网站/音视频/全站三大场景
```

| 术语     | 释义                                                      |
| :------- | :-------------------------------------------------------- |
| VPC      | Virtual Private Cloud · 私有网络，云上的隔离网络空间      |
| 子网     | VPC 内的 IP 段划分，可跨可用区                            |
| 安全组   | 实例级状态防火墙，控制入/出流量                           |
| CCN      | Cloud Connect Network · 云联网，多 VPC + IDC 互联枢纽     |
| CLB      | Cloud Load Balancer · 负载均衡，含 L4/L7 流量分发         |
| CDN      | Content Delivery Network · 内容分发网络，静态资源缓存加速 |
| NAT 网关 | 网络地址转换，多内网实例共享出口公网 IP                   |
| EIP      | Elastic IP · 弹性公网 IP，可与实例绑定/解绑               |

### 云存储服务

```Shell
云存储的基本定义、系统构成与三大形态差异
腾讯云块存储 CBS 的产品类型、快照与加密机制
腾讯云文件存储 CFS 的共享架构与挂载点/权限组
腾讯云对象存储 COS 的存储类型与三大应用场景
腾讯数据加速器 GooseFS 在存算分离架构中的加速角色
```

| 术语 | 释义                                                      |
| :--- | :-------------------------------------------------------- |
| CBS  | Cloud Block Storage · 块存储（云硬盘），单机系统盘/数据盘 |
| CFS  | Cloud File Storage · 文件存储，NFS/SMB 协议，多机共享     |
| COS  | Cloud Object Storage · 对象存储，海量非结构化数据         |
| CDM  | Cloud Data Migration · 数据迁移服务，IDC → 云、跨云       |
| CLS  | Cloud Log Service · 日志服务，采集分析检索一站式          |

### 云数据库服务

```Shell
数据库基础：结构化 / 半结构化 / 非结构化数据与关系型 / NoSQL 的本质差异
腾讯云关系型数据库：MySQL 24 万 QPS、PostgreSQL、TDSQL 金融级 HA、TDSQL-C 存算分离
NoSQL 三剑客：Redis 内存数据库、MongoDB 文档数据库、CTSDB 时序数据库
数据安全审计：TDE / SSL / SQL Insight / 内核级捕获 / 防篡改存储
智能运维与传输：DBbrain AI 诊断、DTS 近零停机迁移与 Kafka 数据订阅
```

### 容器

```Shell
容器底层原理：Namespace、Cgroups、UnionFS 三大内核特性
Kubernetes 架构：控制面与工作节点、Pod/Service/Deployment/PV/PVC 核心对象
腾讯云 TKE：托管集群、节点类型、四种网络模式、存储与插件生态
容器镜像服务 TCR：安全机制、云原生制品托管与全球分发
容器安全与运维：TCSS 镜像扫描、漏洞防御、安全基线与运行时防护
```

### 云安全服务

```Shell
信息安全威胁基础：DDoS / Web / 僵木蠕毒 / APT 四大威胁与 PDR/PPDR 模型
云网络安全：云防火墙 CFW 双机热备与会话同步
终端安全：主机安全 CWP 四阶段闭环与容器安全 TCSS 全生命周期
访问管理 CAM：身份管理、MFA、STS 临时凭证与 SSO 单点登录
应用安全 WAF：Web 基础、六步防护流程、SaaS 型与负载均衡型部署
数据安全审计 DSAudit 与云安全中心 CSC 统一运营
```

