> Maven：项目的依赖、配置与打包

------

### pom.xml（项目的核心配置文件）

```xml
<project>

    <!-- 坐标：唯一标识一个项目:对应本地仓库路径>
    <groupId>com.company</groupId>        <!-- 组织/公司 -->
    <artifactId>project-name</artifactId> <!-- 项目名 -->
    <version>1.0.0</version>              <!-- 版本号 -->
    <packaging>jar</packaging>            <!-- 打包类型(pom为父工程) -->

    <name>maven-demo</name>               <!-- 项目名称 -->
    <url>http://maven.apache.org</url>    <!-- 项目网站 -->

  
    <!-- 文件属性 -->
    <properties>...</properties>          <!-- 定义一个标签(在配置文件中引用) -->       

  
    <!-- 依赖列表 -->                      <!-- mvnrepository.com -->
    <dependencies>
        <groupId>......</groupId>  
        <artifactId>...</artifactId> 
        <version>......</version> 
        <scope>provided</scope>      <!-- 依赖范围(provided不能package) -->
        <optional>false</optional>   <!-- 依赖是否可选 -->
        <exclusions>                 <!-- 排除传递依赖 -->
               <exclusion>
                     <groupId>org.slf4j</groupId>
                     <artifactId>slf4j-log4j12</artifactId>
               </exclusion>
        </exclusions>
    </dependencies>
    
  
    <!-- 插件配置 -->
    <build>...</build>
    
  
    <!-- 版本统一管理(手动选择子工程的依赖) -->
    <dependencyManagement>...</dependencyManagement>
    
  
    <!-- 多模块聚合 -->
    <modules>...</modules>

</project>
```

### maven操作

```Shell
# 项目结构
maven-learning/
├── pom.xml              ← 核心配置文件
├── src/
│   ├── main/
│   │   └── java/        ← 代码
│   │       └── com/learn/
│   └── test/
│       └── java/        ← 测试代码
└── target/              ← 编译后的文件（自动生成）


# Lifecycle :项目生命周期
clean → compile → test → package → install → deploy
↓         ↓        ↓        ↓         ↓         ↓
删除      编译      运行     打包      安装到    发布到
target   代码      单元      jar       本地      远程
测试               仓库      仓库


-- 跳过测试打包
mvn clean package -DskipTes
-- 查看依赖树
mvn dependency:tree
-- 分析未使用或未声明的依赖
mvn dependency:analyze
```

### XML

```xml
<!-- ---------- 1. 基本结构 ---------- -->
<?xml version="1.0" encoding="UTF-8"?>   <!-- 声明，必须在第一行 -->
<root>                                    <!-- 根元素，有且仅有一个 -->
  <child>内容</child>
</root>

<!-- ---------- 2. 标签语法 ---------- -->
<name>Alice</name>          <!-- 双标签，必须闭合 -->
<img src="a.png" />         <!-- 空元素，自闭合 -->
<person>                    <!-- 可嵌套，不能交叉 -->
  <name>Zhang San</name>
</person>
<!-- 大小写敏感：<Name> 和 <name> 不同 -->

<!-- ---------- 3. 属性 ---------- -->
<book id="1" category="tech">XML 入门</book>
<!-- 值必须加引号；元数据用属性，内容用子元素 -->

<!-- ---------- 4. 注释 ---------- -->
<!-- 这是注释，不能嵌套，不能出现在标签内 -->

<!-- ---------- 5. 转义与 CDATA ---------- -->
<!-- < -> &lt;   > -> &gt;   & -> &amp;   " -> &quot;   ' -> &apos; -->
<expr>3 &lt; 5 &amp;&amp; 2 &gt; 1</expr>
<script><![CDATA[ if (a < b && c > d) {} ]]></script>  <!-- 原样输出 -->

<!-- ---------- 6. 命名空间 ---------- -->
<root xmlns:h="http://www.w3.org/TR/html4/">
  <h:table>HTML 表格</h:table>
</root>
<!-- 解决标签重名；默认命名空间：xmlns="url" -->

<!-- ---------- 7. 文档约束 ---------- -->
<!-- DTD : 定义元素/属性/顺序，<!DOCTYPE note SYSTEM "note.dtd">
     XSD : 更强大的 Schema 校验（推荐） -->

<!-- ---------- 8. 解析方式 ---------- -->
<!-- DOM  : 整树加载，可随机访问，适合小文件
     SAX  : 事件驱动，逐行读，省内存，适合大文件
     StAX : 流式拉取（Java）
     XPath: 路径查询，如 //book[@category='tech']/title
     XSLT : XML 转 HTML/文本 -->

<!-- ---------- 9. 应用场景 ---------- -->
<!-- 配置：Maven pom.xml、Android 布局、Spring
     数据：SOAP、RSS、SVG、Office(docx/xlsx = zip+xml)
     文档：XHTML、DocBook -->
```

