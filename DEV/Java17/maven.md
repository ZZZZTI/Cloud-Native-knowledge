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

