> GitLab 是 构建在 Git 之上的一体化的、可自托管的 DevSecOps 平台
>
> gitlab的CLI命令行工具，用于仓库操作，议题管理，拉取请求，cicd，发布，自动化

------

### glab 常用命令速查表

```Shell
# 语法结构：glab <command> <subcommand> [flags]

# ------------------------------------------------------------
# 认证管理（首次使用必须先登录）
# ------------------------------------------------------------
glab auth login                          # 交互式登录（默认 GitLab.com）
glab auth login --hostname gitlab.example.com   # 登录自建 GitLab 实例
glab auth login --stdin < token.txt      # 从文件读取 Personal Access Token 登录
glab auth status                         # 查看当前认证状态和登录用户
glab auth logout                         # 退出当前认证

# ------------------------------------------------------------
# 仓库操作（repo / project）
# ------------------------------------------------------------
glab repo clone group/project            # 克隆仓库到本地
glab repo create my-project --private    # 创建私有仓库（--public 为公开）
glab repo fork group/project             # Fork 仓库到自己的账户下
glab repo view                           # 查看当前仓库信息
glab repo view group/project             # 查看指定仓库信息
glab repo view --web                     # 在浏览器中打开仓库页面
glab repo list                           # 列出你有权限访问的仓库
glab repo search "keyword"               # 搜索仓库
glab repo archive group/project          # 下载仓库归档文件

# ------------------------------------------------------------
# 合并请求（MR）——最常用的模块
# ------------------------------------------------------------
glab mr create                           # 交互式创建 MR
glab mr create --fill                    # 根据当前分支和提交信息自动填充 MR 内容
glab mr create --title "feat: xxx" --description "描述" \
  --target-branch develop                # 指定标题、描述和目标分支
glab mr create --draft --title "WIP: xxx"  # 创建草稿 MR（Draft）
glab mr create --push                    # 推送当前分支并同时创建 MR
glab mr list                             # 列出当前仓库的 MR
glab mr list --assignee=@me              # 列出分配给你的 MR
glab mr list --reviewer=@me              # 列出需要你审查的 MR
glab mr list --state merged              # 列出已合并的 MR（opened/closed 同理）
glab mr view 123                         # 查看 MR #123 详情
glab mr view 123 --web                   # 在浏览器中打开 MR #123
glab mr diff 123                         # 查看 MR #123 的代码变更
glab mr checkout 123                     # 检出 MR #123 的分支到本地
glab mr approve 123                      # 批准 MR #123
glab mr merge 123                        # 合并 MR #123
glab mr merge 123 --squash --remove-source-branch  # 压缩合并并删除源分支
glab mr note 123 -m "评论内容"            # 为 MR #123 添加评论
glab mr close 123                        # 关闭 MR #123
glab mr reopen 123                       # 重新打开 MR #123
glab mr update 123 --title "新标题"       # 修改 MR 标题
glab mr update 123 --add-label bug       # 为 MR 添加标签
glab mr update 123 --ready               # 将草稿 MR 标记为就绪

# ------------------------------------------------------------
# 议题（Issue）
# ------------------------------------------------------------
glab issue create                        # 交互式创建 Issue
glab issue create --title "Bug: xxx" --label bug   # 带标题和标签创建
glab issue create --title "xxx" --assignee @me     # 创建并分配给自己
glab issue list                          # 列出当前仓库的 Issue
glab issue list --assignee @me           # 列出分配给你的 Issue
glab issue list --label "bug"            # 按标签筛选
glab issue list --search "关键词"         # 按关键词搜索
glab issue view 123                      # 查看 Issue #123 详情
glab issue view 123 --web                # 在浏览器中打开 Issue #123
glab issue note 123 -m "评论内容"         # 为 Issue #123 添加评论
glab issue close 123                     # 关闭 Issue #123
glab issue reopen 123                    # 重新打开 Issue #123
glab issue update 123 --title "新标题"    # 修改 Issue 标题
glab issue update 123 --add-label "in-progress"  # 为 Issue 添加标签

# ------------------------------------------------------------
# CI/CD 流水线与作业
# ------------------------------------------------------------
glab ci status                           # 查看当前分支流水线状态
glab ci list                             # 列出最近的流水线
glab ci list --status=failed             # 只列出失败的流水线
glab ci view                             # 交互式查看流水线（可执行操作）
glab ci view main                        # 查看指定分支的流水线
glab ci trace                            # 交互式选择作业并实时流式输出日志
glab ci trace build                      # 流式输出指定作业的日志
glab ci retry <job-name或id>             # 重试失败的作业
glab ci cancel pipeline                  # 取消正在运行的流水线
glab ci run                              # 手动触发一条新的流水线
glab ci run --variables-file /tmp/vars.json  # 触发流水线并传入变量文件

# ------------------------------------------------------------
# 全局常用标志（适用于大多数命令）
# ------------------------------------------------------------
-R, --repo OWNER/REPO    # 指定操作仓库（默认当前目录关联的仓库）
--help                   # 查看命令帮助
--web, -w                # 在浏览器中打开结果（view/list 等命令常用）

# ------------------------------------------------------------
# 实用技巧
# ------------------------------------------------------------
glab alias set mr glab mr                # 设置命令别名，简化输入
glab api projects/123                    # 直接调用任意 GitLab API 端点
glab config set host gitlab.example.org --global  # 全局设置默认 GitLab 主机
export GITLAB_TOKEN="your-token"         # 通过环境变量注入 Token，避免交互登录
```

### Gitlab CI

```Shell

```

