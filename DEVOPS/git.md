> 版本管理工具

------

### 配置和查看

```shell
# ===== 本地仓库配置 =====
git config --global user.name "ZZZZTI"                # 配置用户名
git config --global user.email "19375928071@163.com"  # 配置邮箱
git config --global credential.helper store           # 配置凭证存储（记住密码，避免每次输入）
git config --global --list                            # 查看全局配置
git config --local --list                             # 查看当前仓库配置


# ===== GitHub 远程仓库配置（SSH 密钥） =====
ssh-keygen -t ed25519 -C "19375928071@163.com"        # 生成 SSH 密钥对（推荐 ed25519）
cat ~/.ssh/id_rsa.pub                                 # 查看 RSA 公钥
cat ~/.ssh/id_ed25519.pub                             # 查看 ed25519 公钥
ssh -T git@github.com                                 # 测试 SSH 连接
# 仓库地址示例：git@github.com:ZZZZTI/learn.git
git remote add origin git@github.com:ZZZZTI/learn.git # 添加远程仓库


# ===== 查看 =====
git status                        # 查看文件状态（工作区/暂存区）
git log                           # 查看提交日志
git log --oneline                 # 查看简洁日志（单行显示）
git log --oneline --graph --all   # 查看图形化日志（含所有分支）
git remote -v                     # 查看远程仓库
git diff                          # 查看差异（工作区 vs 暂存区）
git diff --staged                 # 查看差异（暂存区 vs 最新提交）
git diff --cached                 # 查看差异（暂存区 vs 最新提交）
git diff HEAD                     # 查看差异（工作区 vs 最新提交）
git diff main..xxx                # 查看差异（当前分支 vs main 分支）
git branch                        # 查看本地分支
git branch -r                     # 查看远程分支
git branch -a                     # 查看所有分支（本地+远程）
git branch -v                     # 查看分支详情（含最后一次提交）
git stash                         # 临时保存当前修改（用于切换分支）
git stash list                    # 查看 stash 列表
git stash pop                     # 恢复最近的 stash 并删除记录
git stash apply                   # 恢复最近的 stash 但保留记录
git stash drop stash@{0}          # 删除指定 stash
```

### 仓库操作

```Shell
# ===== 增删文件 =====
git add file.txt                  # 添加单个文件到暂存区
git add .                         # 添加所有修改和新文件
git add *.java                    # 添加指定类型文件
git rm file.txt                   # 删除文件并加入暂存区
git rm --cached file.txt          # 只从 Git 移除，保留本地文件


# ===== 仓库操作 =====
git remote add <仓库别名> <仓库地址>                    # 添加远程仓库
git remote add origin git@github.com:                # 示例：添加 origin 远程仓库
git remote set-url origin git@github.com:            # 修改远程仓库地址
git remote remove origin                             # 删除远程仓库关联
git clone <仓库地址>                                  # 克隆远程仓库到本地
git clone -b 分支名 <仓库地址>                         # 克隆指定分支
git tag v1.0.0                                       # 为 commit 打标签
git tag -a v1.0.0 -m "版本1.0.0发布"                  # 打带注释的标签
git tag                                              # 查看所有标签
git push origin v1.0.0                               # 推送标签到远程
git push origin --tags                               # 推送所有标签
git tag -d v1.0.0                                    # 删除本地标签
git push origin :refs/tags/v1.0.0                    # 删除远程标签


# ===== 提交 =====
git commit                        # 提交到本地仓库（会打开编辑器输入提交信息）
git commit -m "提交说明"           # 提交并直接写提交信息
git commit -am "提交说明"          # 添加所有已跟踪文件并提交
git commit --amend                # 修改最后一次提交（提交信息或补充文件）


# ===== 远程同步 =====
git fetch                         # 获取远程仓库更新（不自动合并）
git fetch origin                  # 获取指定远程仓库的更新
git fetch --all                   # 获取所有远程仓库的更新
git fetch origin main             # 获取指定分支更新
git pull                          # 拉取远程仓库并自动合并到当前分支
git pull origin main              # 拉取指定远程分支并合并
git pull --rebase                 # 拉取时使用 rebase（保持线性历史）
git push                          # 本地仓库推送到远程仓库
git push -u origin main           # 首次推送并关联远程分支（-u 设置上游分支）
git push origin feat1             # 推送指定分支
git push --all                    # 推送所有分支
git push -f                       # 强制推送（危险，会覆盖远程历史）


# ===== 分支管理 =====
git branch feat1                  # 创建分支
git checkout -b feat1             # 创建并切换到新分支
git switch -c feat1               # 创建并切换到新分支（新语法）
git checkout main                 # 切换分支
git switch main                   # 切换分支（新语法）
git merge feat1                   # 合并分支到当前分支
git branch -d feat1               # 删除本地分支
git branch -D feat1               # 强制删除本地分支
git push origin --delete feat1    # 删除远程分支
git checkout -b feat1 origin/feat1# 拉取远程分支到本地


# ===== 撤销与回退 =====
git checkout -- file.txt          # 撤销工作区修改（未 add）
git restore file.txt              # 撤销工作区修改（新语法）
git reset HEAD file.txt           # 撤销暂存区修改（已 add，未 commit）
git restore --staged file.txt     # 撤销暂存区修改（新语法）
git reset --soft HEAD~1           # 回退到上一个提交（保留修改）
git reset --mixed HEAD~1          # 回退到上一个提交（保留工作区，取消暂存）
git reset --hard HEAD~1           # 回退到上一个提交（丢弃所有修改，危险）
git reset --hard <commit-id>      # 回退到指定 commit
git revert <commit-id>            # 反做某次提交（生成新提交，安全）
```

### 忽略文件（.gitignore）

```Shell
# 示例 .gitignore 内容：

# 编译输出
target/
*.class
*.jar

# IDE 配置
.idea/
*.iml

# 系统文件
.DS_Store

# 数据文件（重要）
data/
*.csv
*.parquet

# 配置文件（敏感）
application-prod.properties
*.key
*.pem
```

