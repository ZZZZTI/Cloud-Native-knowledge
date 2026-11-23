>Trivy 是用一个工具、一个二进制文件，覆盖尽可能多的扫描目标与安全问题类型的软件供应链安全扫描器。
>

### 常用命令
```bash
# 通用语法：trivy <目标子命令> [标志] <扫描对象>

docker run aquasec/trivy

# ---------- 1. 扫描容器镜像（最常用） ----------
trivy image nginx:1.25                         # 基本扫描镜像
trivy image --severity HIGH,CRITICAL nginx:1.25 # 只看高危和严重漏洞
trivy image myapp:dev                          # 扫描本地构建的镜像
trivy image --input myapp.tar                  # 扫描 docker save 导出的镜像 tar 包
trivy image --image-config-scanners misconfig,secret myapp:v1 # 扫描镜像配置中的错误配置和密钥

# ---------- 2. 扫描本地文件系统 / 项目目录 ----------
trivy fs --scanners vuln,secret,misconfig .    # 扫描当前目录：漏洞+密钥+配置错误
trivy fs --scanners secret .                   # 只扫描硬编码密钥
trivy fs --scanners misconfig .                # 只扫描 IaC/配置文件错误配置
trivy fs /path/to/project                      # 扫描指定目录

# ---------- 3. 扫描 IaC / 配置文件 ----------
trivy config ./infra                           # 扫描 Terraform/K8s/Dockerfile 等 IaC 配置
trivy config ./deploy/k8s                      # 扫描 K8s 清单目录

# ---------- 4. 扫描远程 Git 仓库 ----------
trivy repo https://github.com/org/repo         # 直接扫描远程仓库
trivy repo --severity HIGH,CRITICAL https://github.com/org/repo # 只关注高危和严重问题

# ---------- 5. 扫描 Kubernetes 集群 ----------
trivy k8s --report summary cluster             # 集群摘要扫描
trivy k8s -n kube-system --report summary all  # 指定命名空间
trivy k8s --kubeconfig ~/.kube/config2 --report summary cluster # 指定 kubeconfig
trivy k8s --scanners=config --report=summary cluster # 只做配置合规检查

# ---------- 6. 扫描 SBOM 文件 ----------
trivy sbom sbom.cdx.json                       # 基于 CycloneDX/SPDX SBOM 扫描漏洞和许可证

# ---------- 7. 其他扫描目标 ----------
trivy rootfs /mnt/rootfs                       # 扫描解包后的 rootfs
trivy vm ami:ami-0123                          # 扫描虚拟机镜像（实验性）

# ---------- 8. 常用全局标志 ----------
# --severity        按严重级别过滤，如 HIGH,CRITICAL
# --scanners        选择扫描器：vuln,secret,misconfig,license
# --ignore-unfixed  忽略暂无修复版本的漏洞
# --exit-code       有发现时返回非零退出码，用于 CI 门禁
# --format / -f     输出格式：json、sarif、cyclonedx、spdx-json
# --output / -o     写入文件
# --input           扫描镜像 tar 包而非 registry 引用
# --ignorefile      指定忽略文件，默认 .trivyignore

# ---------- 9. 输出格式与 CI 门禁 ----------
trivy image -f json -o trivy-report.json myapp:v1          # 输出 JSON 报告
trivy image -f sarif -o trivy.sarif myapp:v1               # 输出 SARIF，接入 GitHub Code Scanning
trivy image --format cyclonedx --output sbom.cdx.json nginx:latest # 生成 CycloneDX SBOM
trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 myapp:latest # CI 门禁：严重且可修复漏洞时失败
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 myapp:latest # 更严格的门禁

# ---------- 10. 数据库与缓存管理 ----------
trivy image --download-db-only                 # 预下载漏洞数据库，适合 CI 缓存或离线准备
trivy image --skip-db-update --offline-scan myimage:latest # 离线环境跳过数据库更新
trivy clean                                    # 清理缓存
# 建议 CI 中缓存 ~/.cache/trivy，或用 --cache-dir 指定持久化缓存目录
# trivy image --cache-dir /path/to/cache myapp:v1

# ---------- 11. 最核心的几条快速参考 ----------
# trivy image <镜像>                                              # 扫镜像
# trivy fs --scanners vuln,secret,misconfig .                     # 扫项目目录
# trivy config <目录>                                             # 扫 IaC
# trivy repo <URL>                                                # 扫远程仓库
# trivy k8s --report summary cluster                              # 扫 K8s 集群
# trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 <镜像> # CI 门禁
# trivy image -f cyclonedx -o sbom.json <镜像>                    # 生成 SBOM
```