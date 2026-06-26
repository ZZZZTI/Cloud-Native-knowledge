> git：版本管理工具

------

### git配置和操作

```Shell
# 本地仓库配置
user.name=ZZZZTI
user.email=19375928071@163.com
credential.helper=store
-- 查看git配置
git config --global --list

# Github远程仓库配置(ssh密钥)
仓库地址:git@github.com:ZZZZTI/learn.git
查看公钥:cat ~/.ssh/id_rsa.pub

# 修改
-- 查看文件状态
git status
-- 查看日志
git log (--oneline --graph --all)
-- 查看远程仓库
git remote -v
-- 查看差异(工作区/暂存区/分支)
git diff HEAD/-staged/main..xxx
-- 查看分支
git branch (-r/-a/-v)
-- 临时保存当前修改
git stash
-- 增删文件
git add/rm file.txt/.

# 创建忽略文件
xxx.gitignore
target/ # 编译输出
*.class
*.jar
.idea/ # IDE
*.iml
.DS_Store
data/  # 数据文件（重要）
*.csv        
*.parquet
application-prod.properties # 配置文件（敏感）
*.key
*.pem

# 仓库
-- 添加远程仓库
git remote <仓库别名> <仓库地址>
-- 克隆远程仓库到一个新的本地仓库
git clone <仓库地址>
-- 为commit打标签
git tag v1.0.0 [版本号]
-- 提交到本地仓库               
git commit
-- 获取远程仓库更新
git fetch （仓库）（分支）/(-all)
-- 拉取远程仓库,自动合并到当前分支
git pull
-- 本地仓库推送到远程仓库[选择分支]
git push [-u gitxx feat1]
```

### 管理版本和分支

```Shell
# 分支
-- 切换分支
git switch feat1
-- 把feat1分支合并在main前面，线性（最后合并）
git rebase main
-- main创建合并提交，保留feat2分支，方便查看历史（自己提交）
git merge feat2
-- 回退分支
git reset --mixed/soft/head 版本ID 
```

