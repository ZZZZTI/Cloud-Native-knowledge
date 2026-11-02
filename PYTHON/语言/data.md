> 变量，数字，字符串，布尔值，None，类型转换，
> 
> 容器类型：列表，字典，集合，元组，推导式，排序，浅拷贝陷阱，嵌套结构

------

## 1. 变量：给值起个名字

```python
# Python 不需要提前声明类型，赋值即创建
host = "10.0.0.1"      # 字符串
port = 6443            # 整数
ratio = 0.75           # 浮点数
ready = True           # 布尔值

# 同一行给多个变量赋值
x, y = 1, 2

# 交换两个变量（不用中间变量）
x, y = y, x

# 变量名规则：字母/数字/下划线，不能数字开头，区分大小写
# 推荐小写 + 下划线（snake_case）：pod_count、node_name、is_healthy
```

**没有「声明」这一步，但有「赋值前不能使用」**：

```python
print(abc)      # ❌ NameError: name 'abc' is not defined
abc = 1
print(abc)      # ✅ 1
```

------

## 2. 数字

```python
10          # 整数 int
3.14        # 浮点数 float
1_000_000   # 下划线只是方便阅读，等于 1000000

# 四则运算
7 + 3       # 10
7 - 3       # 4
7 * 3       # 21
7 / 3       # 2.3333...   ← 注意：/ 永远得到浮点数
7 // 3      # 2           ← 整除，向下取整
7 % 3       # 1           ← 取余（判断奇偶、分片常用）
7 ** 3      # 343         ← 幂

# 运算优先级：** > * / // % > + -
(1 + 2) * 3     # 用括号明确优先级，别靠记忆

# 浮点数精度陷阱
0.1 + 0.2 == 0.3          # False！
abs(0.1 + 0.2 - 0.3) < 1e-9   # ✅ 比较浮点用误差范围
```

------

## 3. 布尔值与 None

```python
True / False        # 只有首字母大写，true/false 是错的

# 各种「假值」（在 if 判断里等价于 False）
bool(0)         # False
bool("")        # False   空字符串
bool([])        # False   空列表
bool({})        # False   空字典
bool(set())     # False   空集合
bool(None)      # False

# 其余都是真值
bool("0")       # True   ← 注意："0" 是非空字符串，为真
bool([0])       # True   ← 非空列表

# None：表示「什么都没有」，不是 0、不是 ""、不是 False
result = None
if result is None:        # ✅ 判断 None 永远用 is
    print("还没有结果")

if result == None:        # ❌ 不要这样写
    pass
```

------

## 4. 类型转换

```python
int("123")        # 123        字符串 → 整数
int("abc")        # ❌ ValueError，转换失败会抛异常
float("3.14")     # 3.14
str(123)          # "123"      任何东西 → 字符串
bool(1)           # True

# 输入的数字一定要转换！input() 拿到的永远是字符串
age = input("年龄：")      # 用户输入 25，age 是 "25" 不是 25
age = int(input("年龄：")) # ✅ 转换成整数

# 安全转换：不确定内容是否合法时，用 try 兜底
def to_int(s, default=0):
    try:
        return int(s)
    except (ValueError, TypeError):
        return default

to_int("8080")   # 8080
to_int("abc")    # 0
```

------

## 5. 查看类型

```python
type(123)            # <class 'int'>
type("abc")          # <class 'str'>
isinstance(123, int)          # True
isinstance("123", (int, str)) # True   可以传元组，任一匹配即可
isinstance(True, int)         # True   ← 坑：布尔是整数的子类
```

判断类型优先用 `isinstance()`，它支持继承关系；`type(x) == int` 太死板。


## 6. 列表 list：有序、可变

```python
pods = ["web-1", "web-2"]

# 增
pods.append("web-3")            # 末尾追加
pods.insert(0, "web-0")         # 指定位置插入
pods.extend(["web-4", "web-5"]) # 追加多个（等价于 +=）

# 删
pods.remove("web-0")            # 按值删（值不存在会 ValueError）
popped = pods.pop()             # 弹出末尾
popped = pods.pop(0)            # 弹出指定下标
del pods[0]                     # 按下标删
pods.clear()                    # 清空

# 查 / 改
pods[0]                         # 第一个
pods[-1]                        # 最后一个
pods[1:3]                       # 切片，左闭右开
pods[0] = "web-9"               # 修改
"web-1" in pods                 # 是否存在（O(n) 线性查找）
pods.index("web-1")             # 找下标（不存在会 ValueError）
len(pods)                       # 长度

# 排序
pods.sort()                     # 原地排序，返回 None
sorted(pods)                    # 返回新列表，原列表不动
pods.sort(reverse=True)         # 倒序
pods.sort(key=len)              # 按长度排
pods.sort(key=lambda p: p.split("-")[1])   # 按末尾数字排

# 反转
pods.reverse()                  # 原地反转
pods[::-1]                      # 切片反转（生成新列表）
```

----- 

## 7. 字典 dict：键值对，运维最常用

**JSON 和 YAML 解析出来就是字典**，所以这个要写熟。

```python
node = {"name": "k8s-01", "cpu": 8, "role": "worker"}

# 读
node["name"]                    # 取不到会 KeyError ❌
node.get("mem")                 # 取不到返回 None ✅
node.get("mem", 0)              # 取不到返回默认值 ✅
"cpu" in node                   # 判断 key 是否存在

# 增 / 改
node["ttl"] = 30                # 不存在就新增，存在就覆盖
node.update({"zone": "az1"})    # 批量更新

# 删
del node["ttl"]
node.pop("zone", None)          # 删除并返回值，不存在返回默认值
node.clear()

# 遍历
for k in node:                  # 遍历 key
    print(k, node[k])
for k, v in node.items():       # 同时拿 key 和 value（最常用）
    print(k, v)
for v in node.values():         # 只要 value
    print(v)

# 常用工具
node.keys(); node.values(); node.items()
len(node)
node.setdefault("labels", [])   # 有则返回，无则写入并返回
```

### 嵌套字典的安全取值

```python
resp = {"data": {"spec": {"port": 8080}}}

# ❌ 中间任何一层缺失都会 KeyError
port = resp["data"]["spec"]["port"]

# ✅ 链式 get，每层都给默认空字典
port = resp.get("data", {}).get("spec", {}).get("port", 0)
```

### 字典合并

```python
a = {"x": 1}
b = {"y": 2}

{**a, **b}        # {'x': 1, 'y': 2}   Python 3.5+
a | b             # {'x': 1, 'y': 2}   Python 3.9+
a.update(b)       # 原地合并（会覆盖同名 key）
```

----- 

## 8. 集合 set：去重 + 交并差

```python
old = {"web-1", "web-2", "web-3"}
new = {"web-2", "web-3", "web-4"}

old | new        # 并集  全部
old & new        # 交集  两边都有
old - new        # 差集  在 old 不在 new（被删掉的）
new - old        # 差集  新增的

old.symmetric_difference(new)   # 只在一侧出现的

# 去重（最常见的用法）
pods = ["web-1", "web-1", "web-2"]
list(set(pods))                 # ⚠️ 顺序会乱
list(dict.fromkeys(pods))       # ✅ 去重且保持原顺序

# 增删
s = {1, 2}
s.add(3)
s.discard(99)                   # 不存在也不报错（remove 会 KeyError）

# 子集判断
{1, 2} <= {1, 2, 3}             # True
```

**集合只能装不可变对象**：列表放不进去，元组可以。

----- 

## 9. 元组 tuple：不可变

```python
point = (10, 20)          # 括号可省略：point = 10, 20
point[0]                  # 可以按索引访问
point[0] = 99             # ❌ TypeError，不可修改

# 为什么用它
# ① 可作 dict 的 key（列表不行）
cache = {("prod", "web"): 3}

# ② 表示「一条不能改的记录」
endpoint = ("10.0.0.1", 6443)

# ③ 函数返回多个值时，实际返回的就是元组
def get():
    return "web-1", 8080
name, port = get()        # 自动解包
```

----- 

## 10. 推导式：一行生成列表/字典

```python
pods = ["web-1", "web-2", "db-0"]

# 列表推导：过滤
web = [p for p in pods if p.startswith("web")]      # ['web-1','web-2']

# 列表推导：转换
ports = [int(p.split("-")[1]) for p in pods]

# 字典推导
name_to_index = {p: i for i, p in enumerate(pods)}

# 集合推导（自动去重）
prefixes = {p.split("-")[0] for p in pods}          # {'web', 'db'}

# 带条件表达式
labels = [p if p.startswith("web") else f"other-{p}" for p in pods]

# 嵌套展开（把二维压平）
matrix = [[1, 2], [3, 4]]
flat = [x for row in matrix for x in row]           # [1,2,3,4]
```

**别写太复杂**：推导式超过两三个条件就拆成普通 for 循环，可读性优先。

----- 

## 11. 排序进阶

```python
pods = [
    {"name": "web-1", "restarts": 3},
    {"name": "web-2", "restarts": 12},
    {"name": "db-0",  "restarts": 0},
]

# 按字典的某个字段排
sorted(pods, key=lambda p: p["restarts"])
sorted(pods, key=lambda p: p["restarts"], reverse=True)   # 重启最多的排前面

# 多级排序：先用字段 A，A 相同再按 B
sorted(pods, key=lambda p: (p["restarts"], p["name"]))

# 取 Top N
sorted(pods, key=lambda p: p["restarts"], reverse=True)[:2]

# 用 operator.itemgetter 比 lambda 略快，也更简洁
from operator import itemgetter
sorted(pods, key=itemgetter("restarts"))
```

----- 

## 12. 浅拷贝陷阱（一定要知道）

```python
a = [1, 2, 3]
b = a               # ❌ b 和 a 是同一个列表，改一个另一个也变
b.append(4)
print(a)            # [1, 2, 3, 4]  ← a 也变了！

b = a.copy()        # ✅ 浅拷贝，顶层独立
b = a[:]            # ✅ 切片也是浅拷贝
b = list(a)         # ✅

# 但「浅」拷贝对嵌套无效
m = [[1, 2], [3, 4]]
n = m.copy()
n[0].append(99)
print(m)            # [[1, 2, 99], ...]  ← 内层还是共享的

# 要完全独立，用 deepcopy
import copy
n = copy.deepcopy(m)
```

字典同理：`b = a` 是引用，`b = a.copy()` / `dict(a)` 才是拷贝。

----- 

## 实战：处理集群状态数据

```python
# 典型的 API 返回结构（列表套字典）
nodes = [
    {"name": "k8s-01", "ready": True,  "cpu": 8,  "labels": ["ssd", "prod"]},
    {"name": "k8s-02", "ready": False, "cpu": 16, "labels": ["prod"]},
    {"name": "k8s-03", "ready": True,  "cpu": 8,  "labels": ["ssd"]},
]

# 1. 未就绪节点
not_ready = [n["name"] for n in nodes if not n["ready"]]
print("未就绪：", not_ready)

# 2. 按 CPU 排序取最大
biggest = max(nodes, key=lambda n: n["cpu"])
print("最大节点：", biggest["name"], biggest["cpu"])

# 3. 汇总 CPU 总量
total_cpu = sum(n["cpu"] for n in nodes)
print("总核数：", total_cpu)

# 4. 按标签分类
from collections import defaultdict
by_label = defaultdict(list)
for n in nodes:
    for lb in n["labels"]:
        by_label[lb].append(n["name"])
print(dict(by_label))    # {'ssd': ['k8s-01','k8s-03'], 'prod': ['k8s-01','k8s-02']}

# 5. 用集合算「本次新增/删除的节点」
old_names = {"k8s-01", "k8s-02"}
new_names = {n["name"] for n in nodes}
print("新增：", new_names - old_names)
print("移除：", old_names - new_names)
```
