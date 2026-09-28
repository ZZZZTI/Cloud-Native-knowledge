> 常用文件格式语法

| 格式          | 用途                               |
| :------------ | :--------------------------------- |
| JSON          | API 数据交换、项目配置             |
| YAML          | K8s、Docker、CI/CD 配置            |
| TOML          | Rust/Python 项目配置               |
| XML           | 老式配置、Android、Maven项目       |
| HTML          | 网页结构                           |
| Markdown      | README、技术文档                   |
| CSV           | 表格数据、导入导出                 |
| Makefile      | 编译/构建自动化                    |
| Dockerfile    | 构建容器镜像                       |
| K8s YAML      | 容器编排（Pod/Service/Deployment） |
| Terraform .tf | 基础设施即代码（云资源）           |
| CI YAML       | 流水线（GitHub Actions/GitLab CI） |
| .gitignore    | 指定 Git 忽略的文件                |
| Shell (.sh)   | 自动化任务、运维脚本               |

### JSON

```json
// ---------- 1. 六种数据类型 ----------
{
  "string": "ABC",               // 字符串
  "number": 25,                  // 数字（含小数、科学计数法，不支持 NaN/Infinity）
  "bool": true,                  // 布尔值 true / false
  "null": null,                  // 空值
  "object": { "k": "v" },        // 对象（键必须是双引号字符串）
  "array": [1, "a", true, null]  // 数组（元素可任意类型）
}

// ---------- 2. 嵌套示例 ----------
{
  "code": 200,
  "data": {
    "user": { "id": 1, "name": "Alice" },
    "roles": ["admin", "user"],
    "friends": [
      { "name": "Bob", "age": 24 },
      { "name": "Carol", "age": 26 }
    ]
  }
}

// ---------- 3. 应用场景 ----------
// API 数据交换、配置文件(package.json)、NoSQL 存储(MongoDB)、跨语言传输
// 需要注释时用 JSONC / JSON5
```

### YAML

```yaml
# ---------- 1. 基本数据类型 ----------
name: Alice                # 字符串（可省略引号）
age: 25                    # 整数
height: 1.68               # 浮点数
isStudent: true            # 布尔值（true/false、yes/no、on/off）
nickname: null             # 空值（null、~、空）
quoted: "含: 冒号的字符串"   # 需引号时用单/双引号
multi: |                   # 字面块，保留换行
  第一行
  第二行
folded: >                  # 折叠块，换行变空格
  这段文字
  会被折叠成一行

# ---------- 2. 复合类型 ----------
# 对象/字典：缩进表示层级（只能用空格，不能用 Tab）
person:
  firstName: Zhang
  lastName: San
  address:
    city: Beijing
    zip: "100000"          # 数字想当字符串用需引号

# 数组/列表：用 "- " 表示元素
hobbies:
  - reading
  - coding
  - hiking

# 行内写法（类似 JSON）
point: { x: 1, y: 2 }
colors: [red, green, blue]

# 对象数组
friends:
  - name: Li Si
    age: 24
  - name: Wang Wu
    age: 26

# 多行字符串
script: |
  #!/bin/bash
  echo "hello"

# ---------- 3. 多文档 ----------
# 一个文件可含多个文档，用 --- 分隔，... 结束
---
doc: 1
---
doc: 2
...


# ---------- 4. 应用场景 ----------
# K8s 配置、Docker Compose、CI/CD（GitHub Actions/GitLab CI）
# Ansible 剧本、Spring Boot 配置、OpenAPI 描述

# 缩进用空格（推荐 2 个），同一层级缩进必须一致
# 键值对用 ": " 分隔（冒号后必须有空格）
# "- " 表示列表项（短横线后有空格）
# 注释用 #，可写在行首或行尾
```

### HTML

```html
<!-- ---------- 1. 基本结构 ---------- -->
<!DOCTYPE html>                     <!-- 声明文档类型，必须是第一行 -->
<html lang="zh-CN">                 <!-- 根元素，lang 指定语言 -->
<head>                              <!-- 元数据区，不显示在页面 -->
  <meta charset="UTF-8">            <!-- 字符编码，防乱码 -->
  <meta name="viewport"              <!-- 移动端适配 -->
        content="width=device-width, initial-scale=1.0">
  <title>页面标题</title>            <!-- 浏览器标签页标题 -->
  <link rel="stylesheet" href="style.css">  <!-- 引入外部 CSS -->
  <script src="app.js" defer></script>       <!-- 引入 JS，defer 延迟执行 -->
</head>
<body>                              <!-- 页面可见内容 -->
  <h1>Hello World</h1>
</body>
</html>

<!-- ---------- 2. 标签语法 ---------- -->
<!-- 双标签：<tag>内容</tag> -->
<p>这是一个段落</p>

<!-- 单标签（自闭合）：<tag> 或 <tag /> -->
<img src="a.png" alt="图片">
<br>
<hr>

<!-- 属性：写在开始标签内，格式 名="值" -->
<a href="https://example.com" target="_blank" title="提示">链接</a>
<input type="text" name="user" placeholder="请输入" disabled>

<!-- 注释 -->
<!-- 这是 HTML 注释，不会显示 -->

<!-- ---------- 3. 常用标签分类 ---------- -->
<!-- 文本 -->
<h1>~<h6>          标题（1 最大，6 最小）
<p>                段落
<span>             行内文本
<strong> / <em>    加粗 / 斜体（语义化）
<br>               换行
<hr>               水平分割线
<pre>              保留格式文本
<code>             代码

<!-- 链接与媒体 -->
<a>                超链接
<img>              图片（src / alt 必填）
<video> / <audio>  视频 / 音频
<iframe>           内嵌页面

<!-- 列表 -->
<ul> <li>          无序列表
<ol> <li>          有序列表
<dl> <dt> <dd>     定义列表

<!-- 表格 -->
<table>
  <thead> <tr> <th>表头</th> </tr> </thead>
  <tbody> <tr> <td>单元格</td> </tr> </tbody>
</table>

<!-- 表单 -->
<form action="/submit" method="post">
  <input type="text"     name="username">
  <input type="password" name="pwd">
  <input type="email"    name="mail">
  <input type="checkbox" name="agree">
  <input type="radio"    name="gender">
  <input type="submit"   value="提交">
  <textarea name="msg"></textarea>
  <select name="city">
    <option value="bj">北京</option>
  </select>
  <button type="submit">按钮</button>
</form>

<!-- 语义化布局 -->
<header>  页头
<nav>     导航
<main>    主体
<section> 区块
<article> 文章
<aside>   侧边
<footer>  页脚
<div>     通用块级容器

<!-- ---------- 4. 块级 vs 行内 ---------- -->
<!-- 块级：独占一行，可设宽高  (div, p, h1, ul, li, section)
     行内：不换行，宽高由内容决定  (span, a, img, strong, em) -->

<!-- ---------- 5. 全局属性（所有标签通用） ---------- -->
<!-- id        唯一标识
     class     类名（可多个，空格分隔）
     style     行内样式
     title     悬停提示
     hidden    隐藏元素
     data-*    自定义数据属性，如 data-id="1"
     tabindex  键盘 Tab 顺序 -->

<!-- ---------- 6. 语法规则 ---------- -->
<!-- ✓ 标签名不区分大小写（推荐小写）
     ✓ 属性值推荐用双引号
     ✓ 标签需正确嵌套闭合
     ✓ 空元素可自闭合 <br /> 或 <br>
     ✗ 不要交叉嵌套：<b><i></b></i>
     ✗ 属性值不加引号有风险 -->

<!-- ---------- 7. 文档类型与规范 ---------- -->
<!-- <!DOCTYPE html>       HTML5 声明
     HTML5 不基于 SGML，无需引用 DTD
     遵循 W3C 规范，可用 validator.w3.org 校验 -->
```

