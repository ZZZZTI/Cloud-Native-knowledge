> Helm 是 Kubernetes 的包管理工具，通过 Chart 将应用所需的资源清单打包、版本化并模板化，简化应用的部署与升级。

------

### 

```Shell
# ============================================================
# Helm 常用命令速查表
# ============================================================

# ---------- 一、仓库管理 (Repo) ----------
helm repo add <repo-name> <url>          # 添加仓库
helm repo add ingress-nginx https://helm-charts.itboon.top/ingress-nginx
helm repo list                           # 列出已添加的仓库
helm repo update                         # 更新仓库索引（添加新仓库后必做）
helm repo remove <repo-name>             # 移除仓库

# ---------- 二、查找与查看 (Search & Inspect) ----------
helm search repo <keyword>               # 在已添加的仓库中搜索 Chart
helm search hub <keyword>                # 在 Artifact Hub 中搜索
helm show values <repo>/<chart>          # 【重要】查看 Chart 默认的 values.yaml
helm show readme <repo>/<chart>          # 查看 Chart 的说明文档
helm show chart <repo>/<chart>           # 查看 Chart 的基本信息

# ---------- 三、安装、升级与卸载 (Install / Upgrade / Uninstall) ----------
helm install <release-name> <chart> -n <namespace>                # 安装（存在会报错）
helm upgrade --install <release> <chart> -n <namespace> -f values.yaml  # 【最常用】安装或升级
helm uninstall <release-name> -n <namespace>                      # 卸载
helm uninstall <release-name> -n <namespace> --keep-history       # 卸载但保留历史（可回滚）

# 常用参数解析：
# --install          : 不存在时自动安装
# -n <namespace>     : 指定命名空间（不存在可加 --create-namespace）
# --set key=value    : 命令行覆盖单个值（带方括号需加单引号，如 'a.b[0].c=x'）
# -f values.yaml     : 从文件读取配置
# --wait             : 等待所有资源就绪
# --timeout 10m      : 超时时间
# --atomic           : 升级失败自动回滚（生产环境强烈建议）

# ---------- 四、查看状态 (List & Status) ----------
helm list                                # 列出当前命名空间下的 Release
helm list -A                             # 列出所有命名空间的 Release
helm status <release-name> -n <namespace>               # 查看 Release 详细状态
helm get manifest <release-name> -n <namespace>         # 【排错神器】查看渲染后的 K8s YAML
helm get values <release-name> -n <namespace>           # 查看实际生效的 values

# ---------- 五、版本控制与回滚 (History & Rollback) ----------
helm history <release-name> -n <namespace>              # 查看发布历史
helm rollback <release-name> <revision> -n <namespace>  # 回滚到指定版本
helm rollback <release-name> -n <namespace>             # 回滚到上一个版本

# ---------- 六、本地开发与调试 (Template & Lint) ----------
helm create <chart-name>                 # 创建 Chart 脚手架
helm template <release-name> ./<chart> -f values.yaml   # 【极力推荐】本地渲染模板，不部署
helm lint ./<chart>                      # 检查 Chart 语法错误
helm package ./<chart>                   # 打包 Chart 为 .tgz 文件
```

