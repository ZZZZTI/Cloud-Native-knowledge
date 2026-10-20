> Kubernetes 管理员认证

------

### 

```Shell
故障排除（30%）：权重最高。重点考察排查节点 NotReady、Pod 启动失败（CrashLoopBackOff）、网络不通等问题的能力，需熟练使用 kubectl describe、logs、exec。

集群架构、安装与配置（25%）：重点包括使用 kubeadm 安装/升级集群、etcd 备份与恢复、RBAC 权限配置以及管理高可用集群。

服务与网络（20%）：考察 Service 类型配置、Ingress 规则、Network Policy 以及 CoreDNS 的配置与排错。
工作负载与调度（15%）：涉及 Deployment 的滚动更新与回滚、Pod 调度策略（亲和性/污点）、资源配额及 HPA 配置。

存储（10%）：主要考察 PV/PVC/StorageClass 的创建与绑定，以及将存储挂载到 Pod 中。
```

## CKA 考纲映射

按 `CKA.md` 的考试域对应到本文档章节：

| 考试域（权重）            | 对应章节                                                     | 必练                                                         |
| :------------------------ | :----------------------------------------------------------- | :----------------------------------------------------------- |
| 故障排查（30%）           | [故障排查](#故障排查)                                        | Pod 状态机全部异常、Service 端点、DNS、节点 NotReady、日志三连 |
| 集群架构/安装/配置（25%） | [架构](#架构)、[集群安装与升级](#集群安装与升级kubeadm)、[etcd 备份与恢复](#etcd-备份与恢复) | `kubeadm` init/join/upgrade、etcd 备份恢复、RBAC、HA 拓扑    |
| 服务与网络（20%）         | [网络](#网络)                                                | Service 四种类型、Ingress、NetworkPolicy、CoreDNS 排错       |
| 工作负载与调度（15%）     | [工作负载](#工作负载)、[调度](#调度)                         | 滚动更新与回滚、亲和/反亲和、污点容忍、配额、HPA             |
| 存储（10%）               | [存储](#存储)                                                | PV/PVC/StorageClass、绑定排错、挂载到 Pod                    |

**CKA 实操高频题**：升级集群、etcd 备份恢复、创建 NetworkPolicy、修一个 `CrashLoopBackOff`、把 Pod 调度到指定节点、创建 PVC 并挂载、RBAC 授权、暴露 Service。建议全部练到不看文档能敲完。
