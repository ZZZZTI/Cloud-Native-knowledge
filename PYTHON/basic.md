> py项目结构

------

### 项目结构

```Shell
pyapp/
├── src/pyapp/      代码
├── tests/          测试
├── examples/       示例数据
├── docs/           文档
├── .vscode/        编辑器配置
├── pyproject.toml  项目配置总入口
└── Makefile        常用命令
```

### 关键约定

### 1. 一个包 = 一个目录 + `__init__.py`

`src/pyapp/` 之所以是个包，是因为里面有 `__init__.py`。
`import pyapp` 时，Python 找的就是这个目录。

### 2. `src` 布局

代码放在 `src/` 下的子目录里，而不是直接摊在项目根目录。

原因：在根目录直接运行 Python 时，当前目录会被自动加进模块搜索路径。
如果你把 `pyapp/` 放在根目录，那么「忘了安装也能 import 成功」——
这种假象会掩盖打包配置的错误，等到别人装你的包时才炸。

放进 `src/` 后，**没装就 import 不到**，问题立刻暴露。

### 3. 一个模块 = 一件小事

| 文件 | 职责 |
| --- | --- |
| `cli.py` | 只处理「命令行」相关：参数、输入、输出 |
| `stats.py` | 只处理「计算」相关：输入文本、输出统计结果 |

判断标准很简单：**这个文件能不能在没有终端、没有文件系统的情况下工作？**
`stats.py` 可以，`cli.py` 不行。这就是它们该分开的信号。

### 4. 测试目录镜像源码

`tests/test_stats.py` 测 `src/pyapp/stats.py`，`tests/test_cli.py` 测 `src/pyapp/cli.py`。
文件命名保持一一对应，看名字就知道测的是谁。

### 5. `conftest.py` 放共享夹具

任何测试都用得上的数据（固定文本、临时文件），在 `conftest.py` 里定义一次，
测试函数把它当参数写进函数签名就能用。

## 常见误区

| 误区 | 更好的做法 |
| --- | --- |
| 什么都塞进一个 `main.py` | 按职责拆模块，一个模块一件事 |
| 把手写的 `requirements.txt` 当唯一依赖来源 | 用 `pyproject.toml` 声明依赖 |
| `print()` 满天飞地调试 | 用 VS Code 断点，或 `logging` |
| 测试里真的去读写项目文件 | 用 `tmp_path` 夹具给临时目录 |
| 把 `.venv` 提交到 git | 写进 `.gitignore` |

## 目录该进版本库吗？

| 目录/文件 | 进 git？ | 原因 |
| --- | --- | --- |
| `src/` `tests/` `examples/` `docs/` | ✅ | 项目本体 |
| `pyproject.toml` `Makefile` `README.md` | ✅ | 配置与文档 |
| `.vscode/settings.json` `launch.json` | ✅ | 团队共享的编辑器约定 |
| `.venv/` | ❌ | 每个人本地重建，体积大 |
| `__pycache__/` `.pytest_cache/` | ❌ | 运行时产生的缓存 |
| `.env` | ❌ | 通常含密钥 |



# Python 学习工作区

这里是你学习 Python 的专属文件夹，所有代码、练习都放在这里。

## 一、环境总览（已经帮你配好了）

| 项目     | 内容                                            |
| -------- | ----------------------------------------------- |
| 编辑器   | Visual Studio Code 1.141.0                      |
| Python   | 3.14.7（Homebrew，`/opt/homebrew/bin/python3`） |
| 虚拟环境 | `./.venv`（本项目的独立 Python 环境）           |
| 已装扩展 | Python、Pylance、Debugpy、Ruff                  |
| pip 镜像 | 中科大 / 清华（国内下载飞快）                   |

## 二、第一次打开项目

1. 打开 VS Code（启动台或 `⌘ + 空格` 搜 "Visual Studio Code"）。

2. 菜单 **File → Open Folder…**，选择本文件夹：
   `~/Documents/python-learning`

3. 如果右下角弹出 "推荐安装扩展"，点 **Install**。

4. 确认解释器：按 `⌘ + ⇧ + P`，输入 `Python: Select Interpreter`，
   选择带 `.venv` 字样的那一个（`./.venv/bin/python`）。

   > 已写好配置，正常情况下会自动选中，不用手动改。

## 三、运行你的第一行代码

打开 `hello.py`，用下面任意一种方式运行：

- **快捷键**：`F5`（调试运行，可以打断点）/ `⌃ + F5`（直接运行）

- **按钮**：右上角的 ▶️ 播放键

- **终端**：

  ```bash
  cd ~/Documents/python-learning
  ./.venv/bin/python hello.py      # 不需要先激活环境
  ```

看到终端输出 `Hello, Python!` 就说明整条链路打通了 🎉

## 四、常用终端操作

```bash
cd ~/Documents/python-learning   # 进入项目
source .venv/bin/activate        # 激活虚拟环境（命令行前会出现 (.venv)）
python hello.py                  # 运行脚本
pip install 包名                 # 装第三方库（已自动走国内镜像）
pip list                         # 看已装了什么
deactivate                       # 退出虚拟环境
```

> 装了新库之后，VS Code 里的黄色波浪线如果没消失，按 `⌘ + ⇧ + P`
> 执行 `Developer: Reload Window` 刷新一下。

## 五、推荐学习顺序

| 顺序 | 文件                        | 学到什么                     |
| ---- | --------------------------- | ---------------------------- |
| 1    | `hello.py`                  | 输出、注释、被程序执行的感觉 |
| 2    | `basics/01_variables.py`    | 变量、数字、字符串、输入     |
| 3    | `basics/02_control_flow.py` | if / for / while             |
| 4    | `basics/03_functions.py`    | 函数、参数、返回值           |
| 5    | `basics/04_collections.py`  | 列表、字典、集合、推导式     |
| 6    | `basics/05_classes.py`      | 类与对象、模块导入           |
| 7    | `exercises/exercises.py`    | 动手练习（含参考答案）       |

每个文件都能直接按 `F5` 运行，**建议先自己改数字、改字符串，看输出怎么变**。
学编程最快的办法就是：改一处 → 跑一次 → 看结果。

## 六、效率快捷键

| 快捷键      | 作用                                             |
| ----------- | ------------------------------------------------ |
| `F5`        | 调试运行当前文件                                 |
| `⌃ + F5`    | 直接运行当前文件                                 |
| `⇧ + Enter` | 在 Python 交互窗口运行选中代码（非常适合试语法） |
| `⌘ + /`     | 注释 / 取消注释                                  |
| `⌘ + P`     | 快速打开文件                                     |
| `⌘ + ⇧ + P` | 命令面板（什么都能干）                           |
| `⌥ + ↑/↓`   | 把当前行上下移动                                 |

## 七、遇到问题怎么办

1. **红色波浪线**：鼠标悬停在上面，VS Code 会告诉你原因，Pylance 的提示很准。
2. **报错看不懂**：看最后一行。`NameError` 多半是名字拼错，`IndentationError` 是缩进不对。
3. **说找不到某个包**：确认左下角解释器是 `.venv`，再 `pip install`。
4. **想从头再来**：删掉 `.venv` 文件夹，重新执行
   `python3 -m venv .venv` 即可。
