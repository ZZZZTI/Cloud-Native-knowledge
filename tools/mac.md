> mac上的组件

------

### homebrew

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

### DSH

```Shell
# ---------- 启动与 Profile ----------
dsh web                                      # 启动 Web UI，默认 http://127.0.0.1:3080
dsh --profile <name>                         # 使用指定 Profile 启动
dsh --profile headless "任务"                 # 无头模式运行一次性任务
dsh --profile <name> --from-default-profile <template>  # 基于模板初始化新 Profile

# ---------- 插件管理 ----------
dsh plugin --profile web add <包名>           # 安装 npm 插件
dsh plugin --profile web add github:owner/repo # 从 GitHub 源码安装
dsh plugin --profile web add /path/to/local/plugin  # 从本地目录安装

dsh plugin --profile web remove <包名>        # 卸载插件
dsh plugin --profile web list                 # 列出已安装插件
dsh plugin --profile web update               # 更新全部插件
dsh plugin --profile web update <包名>        # 更新指定插件
dsh plugin --profile web why <包名>           # 查看插件依赖关系

# 兼容性风险豁免示例
dsh plugin --profile web allow-version dsh-balance@0.2.7 --dsh-version 0.2.0-rc.2 --accept-risk

# ---------- 配置查看与调试 ----------
dsh --dump-default-config                     # 打印内置默认配置
dsh --dump-config                             # 打印最终生效配置
dsh --patch <file>                            # 用指定 YAML 临时覆盖启动

# ---------- 会话管理（交互模式内） ----------
/help                                         # 显示所有可用命令
/sessions                                     # 列出当前目录历史会话
/resume <id>                                  # 按 ID 恢复指定会话
/new                                          # 开始全新会话
/model [name]                                 # 切换模型
/compact                                      # 压缩上下文
/exit                                         # 保存并退出
/quit                                         # 保存并退出

# ---------- 帮助 ----------
dsh --help                                    # 启动器自身帮助
dsh --profile <name> --help                   # 指定 Profile 应用的参数帮助

# ---------- 参数顺序提醒 ----------
# 启动器参数必须写在最前面：
# 正确：dsh --profile web --port 8080
# 错误：dsh --port 8080 --profile web
```

