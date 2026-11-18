> import 语法，包结构，__init__.py，__main__，模块搜索路径，常见导入错误，把代码拆成多个文件
>
> 文件读写，路径操作，原子写入，大文件处理
------

## 1. 三种导入写法

```python
# ① 导入整个模块，用「模块名.函数名」调用（推荐，来源清晰）
import json
json.loads('{"a":1}')

# ② 导入模块并起别名（名字太长时用）
import numpy as np
import yaml as y

# ③ 导入模块里的具体函数（调用短，但来源不清晰）
from pathlib import Path
from os.path import join, exists

Path("/tmp/a").exists()

# ④ 导入全部（❌ 不推荐：污染命名空间，不知道函数从哪来）
from os.path import *
```

**团队约定**：优先 `import 模块`，其次 `from 模块 import 具体名字`，禁止 `import *`。

----- 

## 2. 标准库不用装

```python
import os, sys, json, re, time, socket     # 直接可用

# 第三方包要先装
pip install requests   # 装完再导入
import requests        # 没装会 ModuleNotFoundError
```

----- 

## 3. 自己的模块

```
ops-scripts/
├── main.py            # 入口
└── lib/
    ├── __init__.py    # 有这个文件，lib 才是一个「包」
    ├── k8s.py         # 写成模块
    └── net.py
```

```python
# lib/k8s.py
def get_pods(namespace="default"):
    """获取 Pod 列表。"""
    return [...]
```

```python
# main.py —— 两种导入方式

# 方式一：导入模块
from lib import k8s
pods = k8s.get_pods("prod")

# 方式二：导入函数
from lib.k8s import get_pods
pods = get_pods("prod")
```

`__init__.py` 的作用：

- 标记这个目录是一个 Python 包（Python 3.3+ 可以没有，但显式创建更清晰）
- 可以在里面写包的初始化代码，或做快捷导出：

```python
# lib/__init__.py
from .k8s import get_pods          # 这样就能 from lib import get_pods
```

----- 

## 4. `__name__ == "__main__"` 的意义

```python
# lib/k8s.py
def get_pods():
    ...

if __name__ == "__main__":
    # 只有「直接运行 python lib/k8s.py」时才执行这里
    # 被 main.py import 时不会执行
    print(get_pods())
```

**为什么重要**：同一个文件既能当脚本跑（方便调试），又能被别的模块 import 复用。没有这行的话，一 import 就会执行测试代码。

----- 

## 5. 模块搜索路径

```python
import sys
print(sys.path)      # Python 按这个列表的顺序找模块
```

顺序大致是：

1. 当前脚本所在目录
2. `PYTHONPATH` 环境变量里的目录
3. 标准库目录
4. `site-packages`（pip 装的位置）

```bash
# 临时让 Python 能找到你的目录
export PYTHONPATH=/Users/mac/ops-lib:$PYTHONPATH
```

**注意**：模块名不要和标准库/第三方包重名。比如你自己写一个 `json.py`，`import json` 就会导到你自己的文件，引发诡异问题。

----- 

## 6. 常见导入错误

```
报错                                                 原因                 解决
ModuleNotFoundError: No module named 'requests'     没装 / 装错环境        pip install，并确认 which python3
ImportError: cannot import name 'x' from 'y'        y 里没有 x，或拼写错   检查函数名、检查文件是否保存
ModuleNotFoundError: No module named 'lib'          不在搜索路径里         从项目根目录运行，或设 PYTHONPATH
循环导入 ImportError: partially initialized module   A 导 B、B 又导 A      把公共部分抽到第三个模块
导到了同名的错误文件                                   文件名和标准库冲突      改文件名
```

----- 

## 实战：拆分一个巡检脚本

```
inspect/
├── main.py
├── config.py
└── checks/
    ├── __init__.py
    ├── nodes.py
    └── pods.py
```

```python
# config.py —— 配置集中在一处
NAMESPACE = "prod"
RESTART_THRESHOLD = 10
TIMEOUT = 5
```

```python
# checks/pods.py —— 只负责 Pod 检查
from ..config import RESTART_THRESHOLD      # 相对导入：.. 表示上一级

def find_problems(pods):
    return [p for p in pods if p["restarts"] > RESTART_THRESHOLD]
```

```python
# main.py —— 只负责串联
from config import NAMESPACE
from checks.pods import find_problems

def main() -> int:
    pods = fetch_pods(NAMESPACE)
    problems = find_problems(pods)
    ...
    return 1 if problems else 0

if __name__ == "__main__":
    raise SystemExit(main())
```

**拆分原则**：

- `config.py` 放常量，改参数只改一处
- `checks/` 下按检查项分文件，每篇只关心一类问题
- `main.py` 只做流程编排，不写具体逻辑


------

## 1. 读写文本文件

```python
# 读：用 with，结束自动关闭（异常时也会关）
with open("hosts.txt", encoding="utf-8") as f:
    content = f.read()             # 一次读完，得到一个大字符串

with open("hosts.txt", encoding="utf-8") as f:
    lines = f.readlines()          # 读成列表，每行带 \n

# 最推荐：逐行迭代，不占内存
with open("hosts.txt", encoding="utf-8") as f:
    for line in f:
        line = line.strip()        # ⚠️ 一定要 strip，否则带 \n
        if not line or line.startswith("#"):
            continue               # 跳过空行和注释行
        print(line)

# 写：会覆盖原文件！
with open("out.txt", "w", encoding="utf-8") as f:
    f.write("hello\n")

# 追加
with open("out.txt", "a", encoding="utf-8") as f:
    f.write("world\n")
```

```
模式        含义         注意
"r"        只读（默认）  文件不存在报错
"w"        只写         文件已存在会被清空
"a"        追加         不存在则创建
"x"        独占创建      已存在则报错（防止误覆盖）
"rb"/"wb"  二进制        图片、压缩包
```

----- 

## 2. pathlib：路径操作首选

```python
from pathlib import Path

p = Path("/var/log/nginx")
p / "access.log"                 # 拼接：/var/log/nginx/access.log
p.exists(); p.is_dir(); p.is_file()
p.name                           # 'nginx'
p.suffix                         # ''
p.stem                           # 'nginx'
p.parent                         # /var/log
p.stat().st_size                 # 字节数

# 遍历
for f in p.glob("*.log"):        # 当前目录下的 log
    print(f.name)

for f in p.rglob("*.log"):       # 递归
    print(f, f.stat().st_size)

# 直接读写（短文件很方便）
Path("a.txt").read_text(encoding="utf-8")
Path("b.txt").write_text("done\n", encoding="utf-8")

# 创建 / 删除
Path("/tmp/x/y").mkdir(parents=True, exist_ok=True)
Path("a.txt").unlink(missing_ok=True)
```

用 `pathlib` 而不是字符串拼接，能避免 `/` 重复或漏掉的低级错误。

----- 

## 6. 原子写入：防止写一半被读

```python
import os, tempfile

def atomic_write(path: str, content: str) -> None:
    """先写临时文件，再原子改名，避免读方看到半个文件。"""
    d = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(dir=d)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())      # 确保落盘
        os.replace(tmp, path)         # 原子替换
    except Exception:
        os.unlink(tmp)                # 失败清理临时文件
        raise
```

**什么时候必须用**：改配置文件（如 nginx.conf、kubeconfig）。直接 `open(w)` 会先把文件清空，此刻如果有进程读，就拿到空文件。

----- 

## 7. 大文件处理

```python
# ❌ 一次读进内存，1GB 日志直接把机器拖死
content = open("big.log", encoding="utf-8").read()

# ✅ 逐行迭代，内存占用恒定
with open("big.log", encoding="utf-8", errors="replace") as f:
    for line in f:
        if "ERROR" in line:
            print(line.rstrip())
```

```python
# 按块读二进制大文件
def sha256_of(path: str) -> str:
    import hashlib
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):   # 1MB 一块
            h.update(chunk)
    return h.hexdigest()
```

----- 

## 8. 实战：批量给 K8s YAML 换镜像 tag

```python
import yaml
from pathlib import Path

NEW_TAG = "v1.2.3"

for f in Path("manifests").rglob("*.yaml"):
    docs = list(yaml.safe_load_all(f.read_text(encoding="utf-8")))

    changed = False
    for d in docs:
        if not isinstance(d, dict) or d.get("kind") != "Deployment":
            continue
        for c in d["spec"]["template"]["spec"]["containers"]:
            image = c["image"]
            name, _, _old = image.rpartition(":")   # 去掉旧 tag
            c["image"] = f"{name}:{NEW_TAG}"
            changed = True

    if changed:
        # 原子写回，避免别人读到时文件不完整
        tmp = f.with_suffix(".yaml.tmp")
        tmp.write_text(
            yaml.safe_dump_all(docs, allow_unicode=True, sort_keys=False),
            encoding="utf-8",
        )
        tmp.replace(f)
        print("已更新", f)
```