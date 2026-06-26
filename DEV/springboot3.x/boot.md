





### 1. JavaWeb原生基础（Spring Boot的“底层容器”）

Spring Boot内嵌了Tomcat，但它本质上是**Servlet容器**的升级封装。不懂底层，遇到404/500时你会完全抓瞎。

- **Servlet核心**：生命周期（init->service->destroy）、`HttpServletRequest`/`HttpServletResponse`对象（如何获取参数、设置响应头）。
- **会话管理**：Cookie与Session的区别、Session失效原理（这直接关系到你后续做登录拦截）。
- **过滤器（Filter）与拦截器（Interceptor）的区别**（先理解Filter即可）。
- **JSP/EL/JSTL**：**跳过不学**（这是老旧技术，Spring Boot官方推荐模板引擎Thymeleaf或前后端分离，别在这浪费精力）。

### 2. 数据库访问进阶（从SQL到Java的桥梁）

你已会MySQL基础，但Spring Boot操作数据库全靠框架，你必须先理解框架在“代理”什么。

- **JDBC核心**：`Connection`、`PreparedStatement`、`ResultSet`（必须手写一遍原生JDBC增删改查，理解Connection的获取与释放）。
- **数据库连接池原理**：明白为什么需要连接池（Druid/HikariCP），理解`maxActive`、`maxWait`等参数含义。
- **事务本能**：理解MySQL的**事务隔离级别（读未提交、读已提交、可重复读）** 以及**脏读、幻读**。Spring Boot的`@Transactional`注解底层就是基于此。

### 3. JavaSE中被忽略的“框架级”语法（极其重要）

Spring Boot底层充斥大量的反射、代理和Lambda，学完JavaSE基础语法后，必须重点回头补这3个点：

- **反射（Reflection）**：必须能通过反射**创建对象**、**调用私有方法**、**获取注解信息**（Spring的IoC容器就是巨大的反射工厂）。
- **注解（Annotation）**：必须会**自定义注解**，并明白`@Retention`（生命周期）和`@Target`（作用位置）的含义（这是Spring Boot `@Autowired`、`@RequestMapping`的运行基础）。
- **Lambda表达式与Stream流**：不必深入函数式编程，但必须会用`list.stream().filter().collect()`处理集合数据（Controller返回List时几乎必用）。

### 4. 设计思想与核心模式（理解“为什么用Spring”）

不要求你背出23种设计模式，但以下2个是Spring的**灵魂**，必须搞懂概念：

- **IoC（控制反转）与DI（依赖注入）**：能用**通俗的话**解释清楚“原本我new对象，现在交给容器管”的区别。
- **工厂模式**：理解`BeanFactory`为什么是工厂（你不需要手写，但要明白`getBean()`是怎么来的）。

### 5. HTTP协议与RESTful风格（前后端交互的“通用语”）

Spring Boot开发几乎全是Web接口，必须懂网络基础：

- **HTTP请求结构**：GET/POST/PUT/DELETE的区别，**请求头（Header）** 与**请求体（Body）** 的作用（尤其要懂`application/json`和`application/x-www-form-urlencoded`的区别）。
- **HTTP状态码**：200、301、404、500、403的含义（排错全靠它）。
- **JSON语法**：必须能手写简单的嵌套JSON（Spring Boot默认用Jackson将Java对象转为JSON，你只需懂JSON结构即可）。