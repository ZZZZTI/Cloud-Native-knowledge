> homebrew 相当于 MACos 上的 apt 包管理器

------

### 常用命令

```shell
# ========== 基础操作 ==========
brew install <包名>           # 安装一个软件包
brew uninstall <包名>         # 卸载一个软件包
brew search <关键词>          # 搜索可用的软件包
brew info <包名>              # 查看软件包的详细信息
brew list                    # 列出所有已安装的软件包
brew list --cask             # 列出已安装的图形界面应用（Cask）

# ========== 更新与维护 ==========
brew update                  # 更新 Homebrew 自身及软件包列表
brew outdated                # 列出所有可升级的软件包
brew upgrade                 # 升级所有可升级的软件包
brew upgrade <包名>           # 仅升级指定的软件包
brew cleanup                 # 清理旧版本软件包及缓存
brew cleanup -n              # 预览可清理的内容（不实际执行）
brew doctor                  # 诊断 Homebrew 环境问题

# ========== 服务管理 ==========
brew services list            # 列出所有由 brew 管理的服务及状态
brew services start <服务名>   # 启动一个服务
brew services stop <服务名>    # 停止一个服务
brew services restart <服务名> # 重启一个服务

# ========== 备份与恢复 ==========
brew bundle dump --file=Brewfile      # 导出已安装软件包到 Brewfile
brew bundle install --file=Brewfile   # 根据 Brewfile 批量安装软件

# ========== 进阶技巧 ==========
brew pin <包名>              # 锁定版本，禁止被 upgrade
brew unpin <包名>            # 解锁版本
brew deps --tree <包名>      # 树形显示某个包的依赖关系
```

