```java
package DEV_mySQL;
//JDBC操作
import com.alibaba.druid.pool.DruidDataSourceFactory;
import javax.sql.DataSource;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.Properties;

public class JDBC {

    public static void main(String[] args)throws Exception {

        // 连接 Druid 连接池（Maven）
        Properties prop = new Properties();
        InputStream is = JDBC.class.getClassLoader().getResourceAsStream("DEV_mySQL/druid.properties");
        prop.load(is);
        DataSource ds = DruidDataSourceFactory.createDataSource(prop);
        Connection conn = ds.getConnection();

        //查询
        String sql1="select * from tb_brand";//写sql
        PreparedStatement pstmt1=conn.prepareStatement(sql1);
        ResultSet rs1=pstmt1.executeQuery();
        ArrayList<Brand> list=new ArrayList<>();//处理结果

        while (rs1.next()){
            int id=rs1.getInt("id");//获取数据
            String name1=rs1.getString("brand_name");
            String name2=rs1.getString("company_name");
            int ordered=rs1.getInt("ordered");
            String description=rs1.getString("description");
            int status=rs1.getInt("status");
            Brand b1=new Brand();//封装
            b1.setId(id);
            b1.setBrandName(name1);
            b1.setCompanyName(name2);
            b1.setOrdered(ordered);
            b1.setDescription(description);
            b1.setStatus(status);
            list.add(b1);
            System.out.println(b1);
        }

        //添加
        String brandName = "tk_hawk";
        String companyName = "胜利";
        int ordered = 3;
        String description = "胜利在手";
        int status = 1;
        String sql2="insert into tb_brand(brand_name,company_name,ordered,description,status)values(?,?,?,?,?)";
        PreparedStatement pstmt2=conn.prepareStatement(sql2);
        pstmt2.setString(1,brandName);
        pstmt2.setString(2,companyName);
        pstmt2.setInt(3,ordered);
        pstmt2.setString(4,description);
        pstmt2.setInt(5,status);
        int count=pstmt2.executeUpdate();
        if (count>0){
            System.out.println("操作成功");
        }else {
            System.out.println("操作失败");
        }


        //事务
        Statement stat=conn.createStatement();
        String sql4="";
        String sql5="";
        //执行sql
        try{
            conn.setAutoCommit(false);//开启事务

            //多条sql
            stat.executeUpdate(sql4);
            stat.executeUpdate(sql5);
            //输出结果
            int count2=stat.executeUpdate(sql4);
            int count3=stat.executeUpdate(sql5);
            System.out.println(count2);
            System.out.println(count3);

            conn.commit();//提交事务

        }catch (Exception throwable){

            conn.rollback();//回滚事务
            throwable.printStackTrace();
        }


        //释放资源
        rs1.close();
        pstmt1.close();
        pstmt2.close();
        conn.close();
    }


    public static class Brand {
        private Integer id;
        private String brandName;
        private String companyName;
        private Integer ordered;
        private String description;
        private Integer status;


        public Brand() {
        }
        public Brand(Integer id, String brandName, String companyName, Integer ordered, String description, Integer status) {
            this.id = id;
            this.brandName = brandName;
            this.companyName = companyName;
            this.ordered = ordered;
            this.description = description;
            this.status = status;
        }
        public Integer getId() {
            return id;
        }
        public void setId(Integer id) {
            this.id = id;
        }
        public String getBrandName() {
            return brandName;
        }
        public void setBrandName(String brandName) {
            this.brandName = brandName;
        }
        public String getCompanyName() {
            return companyName;
        }
        public void setCompanyName(String companyName) {
            this.companyName = companyName;
        }
        public Integer getOrdered() {
            return ordered;
        }
        public void setOrdered(Integer ordered) {
            this.ordered = ordered;
        }
        public String getDescription() {
            return description;
        }
        public void setDescription(String description) {
            this.description = description;
        }
        public Integer getStatus() {
            return status;
        }
        public void setStatus(Integer status) {
            this.status = status;
        }
        public String toString() {
            return "Brand{id = " + id + ", brandName = " + brandName + ", companyName = " + companyName + ", ordered = " + ordered + ", description = " + description + ", status = " + status + "}";
        }
    }

}
```

```properties
## druid连接池文件
#注册驱动
driverClassName=com.mysql.cj.jdbc.Driver
#用户
url=jdbc:mysql:///db2?useSSL=false&useServerPrepStmts=true
username=root
password=271271
#初始化连接数
initialSize=5
#最大连接数
maxActive=10
#最大等待时间
maxWait=60000
```