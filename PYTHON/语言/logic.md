> 运算符，print 与 input，if / elif / else，比较与逻辑
> 
>for 循环，while 循环，break / continue，遍历技巧
------

## 1. 运算符

```python
# 比较运算，结果是布尔值
1 == 1      # True   等于（两个等号！）
1 != 2      # True   不等于
3 > 2       # True
3 >= 3      # True
"a" < "b"   # True   字符串按字典序比较

# 逻辑运算
True and False   # False   两个都真才真
True or False    # True    一个真就真
not True         # False   取反

# 短路求值：and/or 左边能确定结果时，右边不会执行
# 利用这个特性写默认值
name = user_input or "unknown"    # 空字符串 → "unknown"

# 成员运算
"8080" in "http://x:8080"     # True
"web" in ["web-1", "web-2"]   # False（要完全相等，不是子串）

# 身份运算
a = [1, 2]
b = [1, 2]
a == b      # True    值相等
a is b      # False   不是同一个对象
```

`==` 比的是**值**，`is` 比的是**是不是同一个对象**。只有判断 `None`/`True`/`False` 时才用 `is`。

------

## 2. 输出：print

```python
print("hello")
print("a", "b", "c")              # a b c（默认用空格分隔）
print("a", "b", sep="-")          # a-b（自定义分隔符）
print("end 不换行", end="")        # 默认结尾换行，改成空字符串就不换行
print()

# f-string：最推荐的格式化方式（Python 3.6+）
name, port = "api", 8080
print(f"服务 {name} 监听 {port}")
print(f"耗时 {1.23456:.2f} 秒")        # 保留两位小数
print(f"编号 {7:03d}")                 # 补零成 007
print(f"{'左对齐':<10}|")              # 左对齐占 10 位
print(f"{'右对齐':>10}|")              # 右对齐占 10 位
print(f"{0.856:.1%}")                  # 百分比 85.6%

# 不推荐：+ 拼接（类型不匹配就报错，且慢）
print("服务 " + name + " 监听 " + str(port))   # 必须手动 str()

# 调试用：直接把变量名和值都打出来
x = 42
print(f"{x=}")       # x=42   ← 这是最快的调试打印
```

------

## 3. 输入：input

```python
# input() 永远返回字符串，并且会阻塞等待回车
name = input("请输入节点名：")

# 需要数字就转换，并且要防用户乱输
raw = input("请输入端口：")
try:
    port = int(raw)
except ValueError:
    print("端口必须是数字")
    port = 8080
```

**运维脚本里尽量少用 `input()`**：脚本通常无人值守，交互式输入会挂住。用命令行参数（见 `12-标准库运维常用.md` 的 argparse）代替。


## 4. if：做判断

```python
status = "Running"

if status == "Running":
    print("正常")
```

**语法三条硬规定**：

1. 条件后面必须有**英文冒号** `:`
2. 下一行必须**缩进 4 个空格**（统一用空格，别用 Tab）
3. 同一代码块内缩进必须一致

```python
# 完整形式
if status == "Running":
    print("正常")
elif status == "Pending":
    print("未调度")
elif status in ("Failed", "Unknown"):
    print("异常")
else:
    print("其他状态")
```

`elif` 从上往下匹配，**命中一个就跳过其余**，所以顺序很重要（范围判断要从窄到宽）。

------

## 5. 条件怎么写

```python
# 比较
cpu_usage > 80          # 超过 80%
cpu_usage >= 80         # 大于等于
name == "web-1"         # 相等（两个等号）
name != "web-1"         # 不等

# 组合条件
if cpu > 80 and mem > 90:      # 两个都成立
if status == "Failed" or status == "Unknown":   # 任一个成立
if not ready:                  # 取反

# 链式比较（Python 特有，很好用）
if 0 <= cpu <= 100:            # 等价于 0 <= cpu and cpu <= 100

# 成员判断
if status in ("Pending", "Failed"):   # 元组比链式 or 清晰
if "error" in line.lower():           # 子串判断（先转小写避免大小写问题）

# 判断空值/空容器（不要写 len(x) > 0）
if pods:            # 非空才进
if not pods:        # 空才进
```

**真假值速记**：`0`、`0.0`、`""`、`[]`、`{}`、`set()`、`None`、`False` 都是假，其余为真（包括 `"0"` 和 `"False"`）。

------

## 6. for：遍历

```python
# 遍历列表
for pod in ["web-1", "web-2"]:
    print(pod)

# 遍历字典
node = {"name": "k8s-01", "cpu": 8}
for key in node:              # 默认遍历 key
    print(key, node[key])

for key, value in node.items():    # 同时拿 key 和 value（最常用）
    print(key, value)

for value in node.values():        # 只要 value
    print(value)

# 遍历字符串
for ch in "abc":
    print(ch)
```

### 需要下标：用 enumerate

```python
pods = ["web-1", "web-2", "web-3"]

for i, pod in enumerate(pods):
    print(f"{i}: {pod}")          # 0: web-1  1: web-2  2: web-3

for i, pod in enumerate(pods, start=1):
    print(f"第{i}个: {pod}")       # 从 1 开始编号，给人看时更友好
```

❌ 不要写 `for i in range(len(pods))` —— 又啰嗦又容易越界。

### 同时遍历两个列表：用 zip

```python
hosts = ["10.0.0.1", "10.0.0.2"]
ports = [22, 6443]

for host, port in zip(hosts, ports):
    print(host, port)             # 一对一配对

# zip 以最短的为准，长了会被截断（这个特性可以坑人）
list(zip([1, 2, 3], ["a", "b"]))  # [(1,'a'), (2,'b')]
```

### range：生成一串数字

```python
range(5)          # 0,1,2,3,4      ← 不含终点！
range(1, 6)       # 1,2,3,4,5
range(0, 10, 2)   # 0,2,4,6,8      步长 2
range(5, 0, -1)   # 5,4,3,2,1      倒序
```

------

## 7. while：条件成立就一直转

```python
# 典型：重试直到成功
retries = 0
while retries < 3:
    if try_connect():
        break
    retries += 1
    time.sleep(2)

# 典型：轮询直到状态变化
while not pod_ready():
    time.sleep(5)
```

⚠️ **`while` 必须保证有条件会变**，否则死循环。写的时候先想清楚「什么情况下退出」。

```python
# 死循环的正确写法：靠 break 退出
while True:
    result = check()
    if result:
        break
    time.sleep(10)
```

------

## 8. break / continue / else

```python
# break：立刻跳出整个循环
for pod in pods:
    if pod == "target":
        print("找到了")
        break          # 后面的 pod 不再检查

# continue：跳过本次，继续下一次
for pod in pods:
    if pod.startswith("test-"):
        continue       # 测试环境跳过
    print(pod)

# for-else：循环「正常跑完」才执行（被 break 打断就不执行）
for pod in pods:
    if pod == "target":
        break
else:
    print("一个都没找到")    # ← 只有没 break 时才打印
```

`for-else` 很适合「查找类」逻辑，避免额外加一个 found 标志位。

------

## 9. 嵌套循环

```python
nodes = ["k8s-01", "k8s-02"]
ports = [22, 6443]

for node in nodes:
    for port in ports:
        print(f"{node}:{port}")

# 内层 break 只跳出内层；要跳出两层需要标志位或函数 return
def find(d, target):
    for k, v in d.items():
        if v == target:
            return k        # 直接返回，两层一起退出
    return None
```

------

## 实战：批量判断 Pod 状态

```python
pods = [
    {"name": "web-1", "status": "Running",  "restarts": 0},
    {"name": "web-2", "status": "CrashLoopBackOff", "restarts": 12},
    {"name": "db-0",  "status": "Running",  "restarts": 2},
]

problems = []

for pod in pods:
    name = pod["name"]
    status = pod["status"]
    restarts = pod["restarts"]

    # 优先判断最严重的状态
    if status == "Running" and restarts == 0:
        continue                      # 完全健康，直接看下一个

    if status in ("Failed", "CrashLoopBackOff", "Error"):
        level = "严重"
    elif status == "Pending":
        level = "等待"
    elif restarts > 10:
        level = "频繁重启"
    else:
        level = "观察"

    problems.append((level, name, status, restarts))

for level, name, status, restarts in problems:
    print(f"[{level}] {name}: {status}, 重启 {restarts} 次")

if problems:
    exit(1)          # 有异常，退出码非 0，让监控能感知
```
