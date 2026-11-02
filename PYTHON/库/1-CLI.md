> 第 5 类：CLI 工具化。把脚本变成「别人也敢用」的命令行工具。
>

------

## 1. argparse ★★★ —— 基础命令行参数解析

脚本的标准配置。**参数一律走命令行，绝不要 `input()`**——cron/K8s Job 里没人敲回车。

### ArgumentParser 参数

```
argparse.ArgumentParser(
    prog="check.py",             程序名（默认取 sys.argv[0]）
    description="检查异常 Pod",   --help 时显示的说明
    epilog="示例: ...",           帮助末尾的补充
    formatter_class=argparse.RawDescriptionHelpFormatter,   保留换行
    add_help=True,               是否自动加 -h
)
```

### add_argument 常用参数

```
名字             "-n", "--nodes"        短选项 + 长选项
dest="nodes"     变量名（不给就从 --nodes 推导）
type=int         类型转换（失败自动报错退出）
default=10       默认值
required=True    必填（位置参数天然必填）
choices=[...]    限定可选值
nargs="+"        一个或多个，得到 list
nargs="*"        零个或多个
nargs="?"        零个或一个
action="store_true"   布尔开关，默认 False
action="store_false"  布尔开关，默认 True
action="count"        可叠加，-vv → 2
action="append"       重复出现就追加到 list
metavar="NAME"        帮助里显示的名字
help="说明"
```

```Python
import argparse

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="check.py",
        description="检查集群中异常的 Pod，有异常时退出码 1",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "示例:\n"
            "  check.py prod\n"
            "  check.py prod -l app=web -n 5\n"
            "  check.py prod --dry-run -vv\n"
        ),
    )

    # ==== 位置参数（必填，不用写 -- ）====
    p.add_argument("namespace", help="命名空间")

    # ==== 可选参数 ====
    p.add_argument("-l", "--label", default="app=web", help="标签选择器")
    p.add_argument("-n", "--retries", type=int, default=3,
                   help="重试次数（默认 3）")
    p.add_argument("--timeout", type=float, default=10.0, help="单次超时秒数")
    p.add_argument("--level", choices=["debug", "info", "warn"],
                   default="info", help="日志级别")

    # ==== 布尔开关 ====
    p.add_argument("--dry-run", action="store_true", help="只打印不执行")

    # ==== 可叠加的详细度 ====
    p.add_argument("-v", "--verbose", action="count", default=0,
                   help="可叠加，-vv 更详细")

    # ==== 多样参数 ====
    p.add_argument("--hosts", nargs="+", metavar="HOST",
                   help="目标主机，空格分隔")

    return p

def main() -> int:
    args = build_parser().parse_args()      # 解析失败会自动打印用法并 exit(2)

    # 类型已经是转换后的
    print(args.namespace, args.retries, args.timeout, args.dry_run, args.verbose)
    print(args.hosts)                        # list 或 None
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
```

```Shell
$ python3 check.py --help
$ python3 check.py prod -l app=db -n 5 --dry-run -vv
$ python3 check.py prod --hosts 10.0.0.1 10.0.0.2
```

### 互斥参数与子命令

```Python
# ==== 互斥：两个不能同时给 ====
g = p.add_mutually_exclusive_group()
g.add_argument("--json", action="store_true", help="输出 JSON")
g.add_argument("--yaml", action="store_true", help="输出 YAML")

# ==== 子命令：像 git 那样 ====
sub = p.add_subparsers(dest="command", required=True)

p_get = sub.add_parser("get", help="查询")
p_get.add_argument("kind", choices=["pod", "node"])
p_get.set_defaults(func=cmd_get)

p_del = sub.add_parser("delete", help="删除")
p_del.add_argument("name")
p_del.set_defaults(func=cmd_del)

args = p.parse_args()
args.func(args)          # 分发到对应函数
```

### 环境变量作为默认值

```Python
import os

p.add_argument("--token", default=os.environ.get("API_TOKEN"),
               help="API Token，默认取环境变量 API_TOKEN")
p.add_argument("--timeout", type=int, default=int(os.environ.get("API_TIMEOUT", "10")))
```

⚠️ 坑：

- `type=int` 转换失败时 argparse 自己报错退出（退出码 2），不用你 try
- `nargs="+"` 返回 **list**；不给 `nargs` 时返回 **str**，别写错
- `parse_args()` 遇到 `--help` 或错误会直接 `SystemExit`，在测试里要改用 `parse_args([...])` 传固定参数
- 布尔参数不要写 `--dry-run True`，用 `action="store_true"`

------

## 2. Typer ★★ —— 基于类型注解的现代 CLI

用**类型注解**描述 CLI，样板代码几乎为零。

```
import typer
app = typer.Typer()

@app.command()
def main(
    namespace: str = typer.Argument(..., help="命名空间"),
    retries: int = typer.Option(3, "--retries", "-n", help="重试次数"),
    dry_run: bool = typer.Option(False, "--dry-run", help="只打印"),
): ...

if __name__ == "__main__":
    app()
```

```Python
from pathlib import Path
from typing import Optional
import typer

app = typer.Typer(help="集群巡检工具")

@app.command()
def check(
    namespace: str = typer.Argument(..., help="命名空间"),
    label: str = typer.Option("app=web", "--label", "-l", help="标签选择器"),
    retries: int = typer.Option(3, "--retries", "-n", min=1, max=10),
    dry_run: bool = typer.Option(False, "--dry-run", help="只打印不执行"),
    config: Optional[Path] = typer.Option(None, "--config", exists=True,
                                          help="配置文件，必须存在"),
):
    """检查异常 Pod。提示信息来自这个 docstring。"""
    typer.echo(f"namespace={namespace} label={label} dry_run={dry_run}")
    if dry_run:
        typer.secho("DRY RUN", fg=typer.colors.YELLOW)

@app.command()
def version():
    """显示版本。"""
    typer.echo("check.py 1.0.0")

if __name__ == "__main__":
    app()
```

```
Typer 关键点
--------------------------------------------------------------------
typer.Argument(...)     位置参数
typer.Option(...)       可选参数，第二个位置开始是参数名/短选项
类型注解自动转换        int / float / bool / Path / Enum
Path + exists=True      自动校验文件存在
Enum                    自动变成 choices
typer.echo / secho      输出 / 彩色输出
typer.confirm / prompt  交互确认（CLI 场景慎用）
typer.Exit(code)        退出
typer.testing.CliRunner 测试 CLI
```

⚠️ `bool` 类型在 Typer 里自动变成 `--flag/--no-flag` 开关，不需要 `store_true`。

------

## 3. Click ★★ —— 成熟稳定的 CLI 框架（Typer 的底层）

Typer 的底层，成熟稳定，装饰器风格。

```
import click

@click.command()
@click.argument("namespace")
@click.option("-n", "--retries", default=3, type=int, help="重试次数")
@click.option("--dry-run", is_flag=True, help="只打印")
def main(namespace, retries, dry_run): ...

click.echo() / click.secho(fg=, bold=)
click.confirm() / click.prompt()
click.Choice([...])        枚举
click.Path(exists=True)    路径校验
click.group()              子命令组
@click.pass_context        传递上下文
```

```Python
import click

@click.group()
def cli():
    """集群工具。"""

@cli.command()
@click.argument("namespace")
@click.option("-n", "--retries", default=3, type=int, show_default=True)
@click.option("--dry-run", is_flag=True, help="只打印不执行")
def check(namespace: str, retries: int, dry_run: bool):
    """检查异常 Pod。"""
    click.echo(f"{namespace} retries={retries}")
    if dry_run:
        click.secho("DRY RUN", fg="yellow")

if __name__ == "__main__":
    cli()
```

### 三者怎么选

```
场景                          选择
只有标准库可用                argparse
新写工具、想要最少样板        Typer
需要精细控制、老项目兼容      Click
```

------

## 4. Rich ★ —— 终端彩色输出、表格、进度条

终端美化，让 CLI 输出可读。**知道它在哪用就够**。

```
from rich.console import Console
from rich.table import Table
from rich.progress import track, Progress
from rich.panel import Panel

Console().print("[bold red]错误[/]")    支持简易标记
Table(title=) / table.add_column() / add_row() / console.print(table)
track(iterable, description=)           一行进度条
```

```Python
from rich.console import Console
from rich.table import Table
from rich.progress import track
import time

console = Console()

# ==== 表格 ====
table = Table(title="节点状态")
table.add_column("节点", style="cyan")
table.add_column("状态", style="green")
table.add_column("使用率", justify="right")

for node, status, pct in [("k8s-01", "Ready", "42%"),
                          ("k8s-02", "NotReady", "97%")]:
    style = "red" if status == "NotReady" else "green"
    table.add_row(node, f"[{style}]{status}[/]", pct)

console.print(table)

# ==== 进度条 ====
for _ in track(range(20), description="巡检中..."):
    time.sleep(0.02)
```

⚠️ Rich 的输出带 ANSI 控制符，写日志文件或管道给别的程序时要关掉（`Console(no_color=True)` 或设 `NO_COLOR=1`）。

------

### 检查清单

```
□ 会用 type= / default= / choices= / nargs=
□ 知道布尔开关用 action="store_true"
□ 知道 nargs="+" 返回 list
□ 会用 set_defaults(func=) 做子命令分发
□ 知道 argparse 出错自动 exit(2)
□ Typer：类型注解即校验，Optional[Path] + exists=True 校验文件
```
