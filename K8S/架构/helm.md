> 包管理：helm，Kustomize

------

### helm

```Shell
# helm 组件
Chart	      一个应用包（目录结构：Chart.yaml + values.yaml + templates/）
Release	    Chart 的一次安装实例（每个 release 有名字，存在集群的 Secret 里）
Values	    参数值，覆盖模板里的默认值
Repository	Chart 仓库（如 Bitnami、官方 stable）

# Chart架构
testchartapp/
├── Chart.yaml          # 元数据（名称、版本、依赖）
├── charts              # 依赖的子 chart
├── templates/          # K8s YAML 模板
│   ├── _helpers.tpl    # 模板辅助函数（不渲染成资源，只定义可复用的片段）
│   ├── deployment.yaml
│   └── service.yaml
└── values.yaml         # 默认参数值（用户可覆盖）

# 模版语法
{{ .Values.xxx }}       # 引用 values.yaml 里的值
{{ .Release.Name }}	    # Release 名（helm install 时指定的名字）
{{ .Release.Namespace }}#	Release 所在 namespace
{{ .Chart.Name }}	      # chart 名（来自 Chart.yaml）
{{ .Chart.AppVersion }}	# 应用版本
{{ include "myapp.fullname" . }}	# 调用 _helpers.tpl 里定义的片段	
{{ template "myapp.fullname" . }}	# 同上，但不能用于管道	一般用 include
{{ required "msg" .Values.xxx }}	# 值不存在时渲染失败并报错
{{ toYaml .Values.resources }}	  # 把 map 转成 YAML 字符串

# _helpers.tpl写法
{{- define "myapp.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "myapp.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
{{- end -}}

# Hooks
# 在特定时机执行的Job资源类型，Helm 会在指定时机创建它、等它完成、再继续
Job.annotations:"helm.sh/hook": pre/post-upgrade,install,delete  # 执行时机
                "helm.sh/hook-weight": "-5"  # 权重（小的先执行）
                "hook-delete-policy":before-hook-creation（下次执行前删旧的）
                                     hook-succeeded（成功后删）
                                     hook-failed（失败后删）
```

### helm命令

```Shell
# ---------- 一、远程仓库管理 (Repo) ----------
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

### Kustomize

```Shell
base/                    # 公共基础
├── kustomization.yaml
├── deployment.yaml
└── service.yaml

overlays/
├── dev/                 # dev 环境
│   ├── kustomization.yaml
│   └── patch.yaml       # 覆盖 dev 特有配置
└── prod/                # prod 环境

# 创建Kustomize目录
mkdir -p kustomize/base kustomize/overlays/dev kustomize/overlays/prod
vim ./kustomization.yaml

# 构建 / 预览（不部署）
kubectl kustomize overlays/prod          # 渲染最终 YAML
kustomize build overlays/prod            # 独立二进制，版本更新
kustomize build overlays/prod -o out.yaml

# 部署
kubectl apply -k overlays/prod           # 直接应用
kubectl diff -k overlays/prod            # 先看差异
kubectl kustomize overlays/prod | kubectl apply -f -   # 管道方式
kubectl delete -k overlays/prod

# 修改 kustomization.yaml（在 overlay 目录内执行）
kustomize edit add resource ../../base
kustomize edit set namespace production
kustomize edit set nameprefix prod-
kustomize edit set nameuffix -v1
kustomize edit set image my-app=registry/my-app:v2.0.0
kustomize edit add label env:prod
kustomize edit add configmap app-config --from-literal=LOG_LEVEL=info
kustomize edit add secret db-secret --from-literal=password=xxx

# 排错
kustomize version
kubectl kustomize overlays/prod | yq 'select(.kind=="Deployment")'
```
