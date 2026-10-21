> github的CLI命令行工具，用于仓库操作，议题管理，拉取请求，cicd，发布，自动化

------

### gh

```Shell
gh --version                            # 查看版本
gh auth login                           # 交互式登录（浏览器）
gh auth login --with-token < token.txt  # 使用 Token 登录
gh auth status                          # 查看当前认证状态
gh auth switch                          # 切换账户
gh auth logout                          # 登出
gh auth setup-git                       # 配置 git 使用 gh 作为凭据助手
gh auth token                           # 查看当前 Token
gh auth refresh --scopes repo,read:org  # 刷新认证 scope


# ------------------------------------------------------------
# 2. 仓库管理 (gh repo)
# ------------------------------------------------------------
gh repo create my-repo                  # 交互式创建仓库
gh repo create my-repo --public         # 创建公开仓库
gh repo create my-repo --private --description "My project"   # 创建私有仓库并附描述
gh repo create my-repo --public --clone # 创建并克隆到本地
gh repo create my-repo --public --add-readme --license mit   # 创建时初始化 README 和 LICENSE
gh repo create my-repo --template owner/template-repo         # 基于模板创建

gh repo clone owner/repo                # 克隆仓库
gh repo clone owner/repo my-directory   # 克隆到指定目录
gh repo fork owner/repo                 # Fork 仓库
gh repo fork owner/repo --clone         # Fork 并克隆

gh repo view                            # 查看当前仓库信息
gh repo view owner/repo                 # 查看指定仓库信息
gh repo view --web                      # 在浏览器中打开当前仓库
gh repo list                            # 列出当前用户的仓库
gh repo list my-org --limit 50          # 列出组织的仓库（限制数量）
gh repo list --language go --limit 20   # 按语言过滤

gh repo sync owner/fork                 # 同步 fork 与上游仓库
gh repo set-default owner/repo          # 设置当前目录的默认仓库
gh repo edit --default-branch main      # 修改默认分支
gh repo edit --visibility private       # 修改仓库可见性
gh repo archive owner/repo              # 归档仓库
gh repo delete owner/repo --yes         # 删除仓库（谨慎操作）
gh repo rename new-name                 # 重命名仓库


# ------------------------------------------------------------
# 3. 拉取请求 (gh pr)
# ------------------------------------------------------------
gh pr create                            # 交互式创建 PR
gh pr create --title "Fix login" --body "Description here"   # 指定标题和正文
gh pr create --base main --head feature-branch                # 指定基分支和头分支
gh pr create --draft                    # 创建草稿 PR
gh pr create --reviewer user1,user2     # 指定审查者
gh pr create --assignee @me             # 分配给自己
gh pr create --label "bug,priority:high" # 添加标签
gh pr create --fill                     # 从 commit 信息自动填充
gh pr create --web                      # 创建后在浏览器中打开

gh pr list                              # 列出打开的 PR
gh pr list --state closed               # 已关闭的 PR
gh pr list --state merged               # 已合并的 PR
gh pr list --author @me                 # 自己创建的 PR
gh pr list --label bug                  # 按标签过滤
gh pr list --base main                  # 按基分支过滤

gh pr view 123                          # 查看 PR 详情
gh pr view 123 --web                    # 在浏览器中打开 PR
gh pr diff 123                          # 查看 PR 的代码差异
gh pr checks 123                        # 查看 PR 的 CI 检查状态
gh pr status                            # 查看与自己相关的 PR 状态

gh pr checkout 123                      # 检出 PR 到本地
gh pr merge 123                         # 合并 PR（交互式）
gh pr merge 123 --squash                # 压缩合并
gh pr merge 123 --rebase                # 变基合并
gh pr close 123                         # 关闭 PR
gh pr reopen 123                        # 重新打开 PR
gh pr comment 123 --body "LGTM!"        # 发表评论
gh pr review 123 --approve              # 批准 PR
gh pr edit 123 --add-label "bug"        # 编辑 PR（添加标签等）


# ------------------------------------------------------------
# 4. Issue 管理 (gh issue)
# ------------------------------------------------------------
gh issue list                           # 列出打开的 Issue
gh issue list --state closed            # 已关闭的 Issue
gh issue list --assignee @me            # 分配给我的 Issue
gh issue list --label "bug,high-priority" # 按标签过滤
gh issue list --repo OWNER/REPO         # 指定仓库

gh issue view 123                       # 查看 Issue 详情
gh issue view 123 --comments            # 同时查看评论
gh issue view 123 --web                 # 在浏览器中打开

gh issue create                         # 交互式创建 Issue
gh issue create --title "Bug report" --body "Description"    # 指定标题和正文
gh issue create --title "Bug" --body-file body.md            # 从文件读取正文
gh issue close 123                      # 关闭 Issue
gh issue close 123 --comment "Resolved" # 关闭并附带说明
gh issue reopen 123                     # 重新打开 Issue
gh issue comment 123 --body "Confirmed" # 添加评论
gh issue edit 123 --add-label "bug" --remove-label "stale"   # 修改标签
gh issue status                         # 查看与自己相关的 Issue 摘要


# ------------------------------------------------------------
# 5. GitHub Actions (gh run / gh workflow)
# ------------------------------------------------------------
gh run list                             # 列出工作流运行记录
gh run view <run-id>                    # 查看某次运行详情
gh run view <run-id> --log             # 查看运行日志
gh run watch                            # 实时监控运行状态
gh run rerun <run-id>                   # 重新运行失败的任务
gh run cancel <run-id>                  # 取消运行

gh workflow list                        # 列出工作流
gh workflow view <workflow-id>          # 查看工作流详情
gh workflow run <workflow-id>           # 手动触发工作流


# ------------------------------------------------------------
# 6. Release 管理 (gh release)
# ------------------------------------------------------------
gh release list                         # 列出发布版本
gh release view <tag>                   # 查看发布详情
gh release create <tag>                 # 创建发布（交互式）
gh release create <tag> --title "v1.0" --notes "Release notes"   # 指定标题和说明
gh release delete <tag> --yes           # 删除发布


# ------------------------------------------------------------
# 7. 其他常用命令
# ------------------------------------------------------------
gh browse                               # 在浏览器中打开当前仓库
gh browse --settings                    # 打开仓库设置页
gh browse <file>                        # 在浏览器中打开特定文件

gh gist list                            # 列出 Gist
gh gist create <file>                   # 创建 Gist
gh gist view <gist-id>                  # 查看 Gist

gh alias set co 'pr checkout'           # 设置命令别名（示例：gh co 123）
gh alias list                           # 列出已设置的别名

gh search repos "keyword"               # 搜索仓库
gh search issues "keyword"              # 搜索 Issue
gh search prs "keyword"                 # 搜索 PR

gh config list                          # 查看当前配置
gh config set editor vim                # 设置默认编辑器
```

