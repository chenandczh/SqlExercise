# SQL Server 存储过程与自定义函数教学案例

## 目录

1. [存储过程基础](#1-存储过程基础)
   - 1.1 存储过程概念
   - 1.2 创建存储过程
   - 1.3 参数类型（输入/输出参数）
   - 1.4 流程控制语句
   - 1.5 错误处理

2. [自定义函数](#2-自定义函数)
   - 2.1 标量函数
   - 2.2 表值函数（内联/多语句）
   - 2.3 函数与存储过程的区别

3. [SSMS 断点调试指南](#3-ssms-断点调试指南)
   - 3.1 调试准备
   - 3.2 设置断点
   - 3.3 调试执行
   - 3.4 查看变量和调用栈

4. [性能优化技巧](#4-性能优化技巧)
   - 4.1 执行计划分析
   - 4.2 索引优化
   - 4.3 避免常见陷阱

5. [实战案例](#5-实战案例)
   - 5.1 案例1：数据统计存储过程
   - 5.2 案例2：自定义计算函数
   - 5.3 案例3：复杂业务逻辑处理

---

## 1. 存储过程基础

### 1.1 存储过程概念

**存储过程**（Stored Procedure）是预编译的 SQL 语句集合，存储在数据库中，可通过名称调用执行。

**优点：**
- 提高性能：预编译执行计划
- 代码复用：一次编写多次调用
- 安全性：可以控制权限
- 减少网络流量：只需传递调用参数

### 1.2 创建存储过程

```sql
-- 基本语法
CREATE PROCEDURE ProcedureName
    @Parameter1 DataType = DefaultValue,
    @Parameter2 DataType OUTPUT
AS
BEGIN
    -- 执行逻辑
    SELECT * FROM TableName WHERE Column = @Parameter1;
END
GO
```

**示例：查询指定部门的员工**

```sql
CREATE PROCEDURE GetEmployeesByDepartment
    @DepartmentName VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON; -- 禁止返回影响行数信息
    
    SELECT 
        user_id,
        username,
        department,
        registration_date
    FROM slow_query_test
    WHERE department = @DepartmentName;
END
GO

-- 调用存储过程
EXEC GetEmployeesByDepartment @DepartmentName = '技术部';
```

### 1.3 参数类型

#### 输入参数（Input Parameter）

```sql
CREATE PROCEDURE GetUserScore
    @UserId INT  -- 输入参数
AS
BEGIN
    SELECT score FROM slow_query_test WHERE user_id = @UserId;
END
GO
```

#### 输出参数（Output Parameter）

```sql
CREATE PROCEDURE GetDepartmentStats
    @DepartmentName VARCHAR(50),
    @TotalUsers INT OUTPUT,      -- 输出参数
    @AvgScore DECIMAL(10,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        @TotalUsers = COUNT(*),
        @AvgScore = AVG(score)
    FROM slow_query_test
    WHERE department = @DepartmentName;
END
GO

-- 调用带有输出参数的存储过程
DECLARE @Total INT, @Avg DECIMAL(10,2);
EXEC GetDepartmentStats 
    @DepartmentName = '技术部',
    @TotalUsers = @Total OUTPUT,
    @AvgScore = @Avg OUTPUT;

SELECT @Total AS TotalUsers, @Avg AS AverageScore;
```

#### 返回值（Return Value）

```sql
CREATE PROCEDURE CheckUserExists
    @Username VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM slow_query_test WHERE username = @Username)
        RETURN 1;  -- 用户存在
    ELSE
        RETURN 0;  -- 用户不存在
END
GO

-- 调用并获取返回值
DECLARE @Result INT;
EXEC @Result = CheckUserExists @Username = 'user_1';
SELECT @Result AS UserExists;
```

### 1.4 流程控制语句

#### IF...ELSE

```sql
CREATE PROCEDURE UpdateUserStatus
    @UserId INT,
    @NewStatus INT
AS
BEGIN
    SET NOCOUNT ON;
    
    IF @NewStatus NOT IN (0, 1, 2)
    BEGIN
        RAISERROR('无效的状态值，有效值为 0, 1, 2', 16, 1);
        RETURN;
    END
    
    UPDATE slow_query_test
    SET status = @NewStatus
    WHERE user_id = @UserId;
    
    IF @@ROWCOUNT = 0
    BEGIN
        PRINT '未找到指定用户';
    END
    ELSE
    BEGIN
        PRINT '用户状态更新成功';
    END
END
GO
```

#### WHILE 循环

```sql
CREATE PROCEDURE GenerateTestData
    @Count INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @i INT = 1;
    WHILE @i <= @Count
    BEGIN
        INSERT INTO slow_query_test (user_id, username, department)
        VALUES (@i, 'test_user_' + CAST(@i AS VARCHAR), '技术部');
        
        SET @i = @i + 1;
    END
END
GO
```

#### CASE 表达式

```sql
CREATE PROCEDURE GetUserLevel
    @UserId INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        username,
        score,
        CASE
            WHEN score >= 900 THEN '金牌用户'
            WHEN score >= 700 THEN '银牌用户'
            WHEN score >= 500 THEN '铜牌用户'
            ELSE '普通用户'
        END AS UserLevel
    FROM slow_query_test
    WHERE user_id = @UserId;
END
GO
```

### 1.5 错误处理

#### TRY...CATCH

```sql
CREATE PROCEDURE SafeUpdateUser
    @UserId INT,
    @NewEmail VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- 遇到错误时回滚事务
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 验证邮箱格式
        IF @NewEmail NOT LIKE '%_@__%.__%'
        BEGIN
            THROW 50001, '无效的邮箱格式', 1;
        END
        
        UPDATE slow_query_test
        SET email = @NewEmail
        WHERE user_id = @UserId;
        
        COMMIT TRANSACTION;
        PRINT '更新成功';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        -- 输出错误信息
        SELECT
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;
    END CATCH
END
GO
```

---

## 2. 自定义函数

### 2.1 标量函数（Scalar Function）

返回单个值的函数。

```sql
-- 创建标量函数：计算用户等级
CREATE FUNCTION dbo.GetUserLevelByScore(@Score DECIMAL(10,2))
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @Level VARCHAR(20);
    
    SET @Level = CASE
        WHEN @Score >= 900 THEN '金牌用户'
        WHEN @Score >= 700 THEN '银牌用户'
        WHEN @Score >= 500 THEN '铜牌用户'
        ELSE '普通用户'
    END;
    
    RETURN @Level;
END
GO

-- 使用标量函数
SELECT 
    username,
    score,
    dbo.GetUserLevelByScore(score) AS UserLevel
FROM slow_query_test
WHERE department = '技术部';
```

### 2.2 表值函数

#### 内联表值函数（Inline Table-Valued Function）

```sql
-- 创建内联表值函数：获取指定部门用户
CREATE FUNCTION dbo.GetUsersByDepartment(@DepartmentName VARCHAR(50))
RETURNS TABLE
AS
RETURN (
    SELECT 
        user_id,
        username,
        email,
        registration_date,
        score
    FROM slow_query_test
    WHERE department = @DepartmentName
);
GO

-- 使用内联表值函数（可像表一样使用）
SELECT * FROM dbo.GetUsersByDepartment('技术部');

-- 可用于 JOIN
SELECT 
    u.username,
    o.order_id
FROM dbo.GetUsersByDepartment('技术部') u
JOIN slow_query_orders o ON u.user_id = o.user_id;
```

#### 多语句表值函数（Multi-Statement Table-Valued Function）

```sql
-- 创建多语句表值函数：获取用户统计信息
CREATE FUNCTION dbo.GetUserStatistics(@DepartmentName VARCHAR(50))
RETURNS @Stats TABLE (
    StatName VARCHAR(50),
    StatValue VARCHAR(100)
)
AS
BEGIN
    -- 添加统计信息
    INSERT INTO @Stats
    SELECT '总用户数', CAST(COUNT(*) AS VARCHAR)
    FROM slow_query_test
    WHERE department = @DepartmentName;
    
    INSERT INTO @Stats
    SELECT '平均分数', CAST(AVG(score) AS VARCHAR)
    FROM slow_query_test
    WHERE department = @DepartmentName;
    
    INSERT INTO @Stats
    SELECT '最高分数', CAST(MAX(score) AS VARCHAR)
    FROM slow_query_test
    WHERE department = @DepartmentName;
    
    RETURN;
END
GO

-- 使用多语句表值函数
SELECT * FROM dbo.GetUserStatistics('技术部');
```

### 2.3 函数与存储过程的区别

| 特性 | 存储过程 | 自定义函数 |
|------|----------|------------|
| 返回值 | 可返回多个结果集/输出参数 | 标量函数返回单个值，表值函数返回表 |
| 事务控制 | 支持事务 | 不支持事务 |
| DML操作 | 可执行 INSERT/UPDATE/DELETE | 仅表值函数有限支持 |
| 调用方式 | EXEC 语句 | 可在 SELECT 中使用 |
| 错误处理 | TRY/CATCH、RAISERROR | 受限的错误处理 |
| 性能 | 适合复杂逻辑和批处理 | 适合计算和查询 |

---

## 3. SSMS 断点调试指南

### 3.1 调试准备

1. **确保 SQL Server 已启用调试**：
   - 打开 SSMS，连接到数据库
   - 确保使用的登录账户具有 `ALTER ANY PROCEDURE` 权限

2. **打开调试工具栏**：
   - 菜单栏：`视图` → `工具栏` → `调试`

### 3.2 设置断点

**方法1：在行号左侧点击**

1. 打开存储过程或函数脚本
2. 在要设置断点的行号左侧灰色区域点击
3. 会出现红色圆点，表示断点已设置

**方法2：右键菜单**

1. 右键点击目标行
2. 选择 `断点` → `插入断点`

**方法3：快捷键**

- 设置/取消断点：`F9`

### 3.3 调试执行

**启动调试：**

1. 打开存储过程脚本
2. 点击工具栏的 **▶️ 启动调试** 按钮（或按 `F5`）
3. 如果有参数，会弹出 "执行过程" 对话框，输入参数值
4. 点击 **确定** 开始调试

**调试快捷键：**

| 快捷键 | 功能 |
|--------|------|
| `F5` | 继续执行（到下一个断点或结束） |
| `F10` | 单步执行（跳过函数调用） |
| `F11` | 单步执行（进入函数调用） |
| `Shift + F11` | 跳出当前函数 |
| `Ctrl + Shift + F5` | 重新开始调试 |
| `Shift + F5` | 停止调试 |

### 3.4 查看变量和调用栈

**局部变量窗口：**
- 菜单栏：`调试` → `窗口` → `局部变量`
- 显示当前作用域内的所有变量及其值

**监视窗口：**
- 菜单栏：`调试` → `窗口` → `监视`
- 可手动添加要监视的变量或表达式

**调用栈窗口：**
- 菜单栏：`调试` → `窗口` → `调用栈`
- 显示当前执行的函数调用层次

**即时窗口：**
- 菜单栏：`调试` → `窗口` → `即时`
- 可在调试过程中执行临时 SQL 语句

---

## 4. 性能优化技巧

### 4.1 执行计划分析

**查看执行计划：**

1. 打开查询窗口
2. 点击工具栏的 **显示估计的执行计划** 按钮（或按 `Ctrl + L`）
3. 分析执行计划中的：
   - 扫描类型（Table Scan vs Index Seek）
   - 逻辑读/物理读次数
   - 执行时间
   - 运算符成本

**实际执行计划：**

1. 点击工具栏的 **包括实际执行计划** 按钮（或按 `Ctrl + M`）
2. 执行查询，查看实际执行情况

### 4.2 索引优化

**识别缺失索引：**

```sql
-- 查询缺失索引建议
SELECT
    migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) AS improvement_measure,
    'CREATE NONCLUSTERED INDEX IX_' + OBJECT_NAME(mid.object_id) + '_' + 
        REPLACE(REPLACE(REPLACE(ISNULL(mid.equality_columns, ''), ', ', '_'), '[', ''), ']', '') +
        CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN '_' ELSE '' END +
        REPLACE(REPLACE(REPLACE(ISNULL(mid.inequality_columns, ''), ', ', '_'), '[', ''), ']', '')
        AS create_index_statement,
    migs.*, mid.database_id, mid.object_id
FROM sys.dm_db_missing_index_groups mig
INNER JOIN sys.dm_db_missing_index_group_stats migs ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
WHERE migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) > 10
ORDER BY improvement_measure DESC;
```

### 4.3 避免常见陷阱

**陷阱1：使用游标**

```sql
-- 不推荐：使用游标
DECLARE user_cursor CURSOR FOR
SELECT user_id FROM slow_query_test;

OPEN user_cursor;
FETCH NEXT FROM user_cursor INTO @UserId;
WHILE @@FETCH_STATUS = 0
BEGIN
    -- 处理每个用户
    FETCH NEXT FROM user_cursor INTO @UserId;
END
CLOSE user_cursor;
DEALLOCATE user_cursor;

-- 推荐：使用集合操作
UPDATE slow_query_test
SET status = 1
WHERE department = '技术部';
```

**陷阱2：过度使用标量函数**

```sql
-- 不推荐：在 WHERE 子句中使用标量函数
SELECT * 
FROM slow_query_test
WHERE dbo.GetUserLevelByScore(score) = '金牌用户';

-- 推荐：直接使用条件表达式
SELECT * 
FROM slow_query_test
WHERE score >= 900;
```

**陷阱3：不必要的动态 SQL**

```sql
-- 不推荐：不必要的动态SQL
DECLARE @SQL VARCHAR(MAX);
SET @SQL = 'SELECT * FROM slow_query_test WHERE department = ''技术部''';
EXEC(@SQL);

-- 推荐：直接查询
SELECT * FROM slow_query_test WHERE department = '技术部';
```

---

## 5. 实战案例

### 5.1 案例1：数据统计存储过程

```sql
-- 创建存储过程：获取销售统计报表
CREATE PROCEDURE GetSalesReport
    @StartDate DATE,
    @EndDate DATE,
    @DepartmentFilter VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT
        p.category AS 产品类别,
        SUM(od.quantity) AS 销售数量,
        SUM(od.quantity * od.unit_price) AS 销售金额,
        AVG(od.unit_price) AS 平均单价,
        COUNT(DISTINCT o.order_id) AS 订单数量
    FROM slow_query_orders o
    JOIN slow_query_order_details od ON o.order_id = od.order_id
    JOIN slow_query_products p ON od.product_id = p.product_id
    JOIN slow_query_test u ON o.user_id = u.user_id
    WHERE o.order_date BETWEEN @StartDate AND @EndDate
        AND (@DepartmentFilter IS NULL OR u.department = @DepartmentFilter)
    GROUP BY p.category
    ORDER BY 销售金额 DESC;
END
GO

-- 调用示例
EXEC GetSalesReport @StartDate = '2024-01-01', @EndDate = '2024-12-31';
EXEC GetSalesReport @StartDate = '2024-01-01', @EndDate = '2024-12-31', @DepartmentFilter = '技术部';
```

### 5.2 案例2：自定义计算函数

```sql
-- 创建函数：计算订单折扣
CREATE FUNCTION dbo.CalculateDiscount(@OrderTotal DECIMAL(10,2), @UserScore DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Discount DECIMAL(10,2) = 0;
    
    -- 根据订单金额计算基础折扣
    IF @OrderTotal >= 10000
        SET @Discount = @Discount + 0.10;  -- 10%
    ELSE IF @OrderTotal >= 5000
        SET @Discount = @Discount + 0.05;  -- 5%
    ELSE IF @OrderTotal >= 1000
        SET @Discount = @Discount + 0.02;  -- 2%
    
    -- 根据用户积分增加折扣
    IF @UserScore >= 900
        SET @Discount = @Discount + 0.05;  -- 额外5%
    ELSE IF @UserScore >= 700
        SET @Discount = @Discount + 0.03;  -- 额外3%
    
    RETURN @Discount;
END
GO

-- 使用函数计算实际支付金额
SELECT
    o.order_id,
    SUM(od.quantity * od.unit_price) AS 订单总额,
    dbo.CalculateDiscount(SUM(od.quantity * od.unit_price), u.score) AS 折扣率,
    SUM(od.quantity * od.unit_price) * (1 - dbo.CalculateDiscount(SUM(od.quantity * od.unit_price), u.score)) AS 实际支付
FROM slow_query_orders o
JOIN slow_query_order_details od ON o.order_id = od.order_id
JOIN slow_query_test u ON o.user_id = u.user_id
GROUP BY o.order_id, u.score;
```

### 5.3 案例3：复杂业务逻辑处理

```sql
-- 创建存储过程：处理订单退款
CREATE PROCEDURE ProcessRefund
    @OrderId INT,
    @RefundAmount DECIMAL(10,2),
    @RefundReason VARCHAR(200),
    @ResultMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- 验证订单存在
        IF NOT EXISTS (SELECT 1 FROM slow_query_orders WHERE order_id = @OrderId)
        BEGIN
            SET @ResultMessage = '错误：订单不存在';
            RETURN;
        END
        
        -- 验证订单状态
        DECLARE @OrderStatus INT;
        SELECT @OrderStatus = status FROM slow_query_orders WHERE order_id = @OrderId;
        IF @OrderStatus <> 1  -- 1 = 已完成
        BEGIN
            SET @ResultMessage = '错误：订单状态不允许退款';
            RETURN;
        END
        
        -- 验证退款金额
        DECLARE @TotalAmount DECIMAL(10,2);
        SELECT @TotalAmount = SUM(quantity * unit_price) 
        FROM slow_query_order_details 
        WHERE order_id = @OrderId;
        
        IF @RefundAmount > @TotalAmount
        BEGIN
            SET @ResultMessage = '错误：退款金额超过订单总额';
            RETURN;
        END
        
        -- 更新订单状态为已退款
        UPDATE slow_query_orders
        SET status = 3,  -- 3 = 已退款
            last_updated = GETDATE()
        WHERE order_id = @OrderId;
        
        -- 记录退款事务
        INSERT INTO slow_query_transactions (
            transaction_type,
            order_id,
            amount,
            description
        )
        VALUES (
            'REFUND',
            @OrderId,
            @RefundAmount,
            @RefundReason
        );
        
        COMMIT TRANSACTION;
        SET @ResultMessage = '退款处理成功';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SET @ResultMessage = '退款失败：' + ERROR_MESSAGE();
    END CATCH
END
GO

-- 调用退款存储过程
DECLARE @Result VARCHAR(500);
EXEC ProcessRefund 
    @OrderId = 1001,
    @RefundAmount = 100.00,
    @RefundReason = '客户退货',
    @ResultMessage = @Result OUTPUT;

SELECT @Result AS Result;
```

---

## 附录：常用系统视图

| 视图名称 | 用途 |
|----------|------|
| `sys.procedures` | 查询存储过程信息 |
| `sys.parameters` | 查询存储过程参数 |
| `sys.sql_modules` | 查询存储过程/函数定义 |
| `sys.objects` | 查询数据库对象信息 |
| `sys.dm_exec_procedure_stats` | 查询存储过程执行统计 |

```sql
-- 查询所有存储过程
SELECT 
    name AS ProcedureName,
    create_date AS CreatedDate,
    modify_date AS ModifiedDate
FROM sys.procedures
ORDER BY create_date DESC;

-- 查询存储过程定义
SELECT 
    OBJECT_NAME(object_id) AS ProcedureName,
    definition AS ProcedureDefinition
FROM sys.sql_modules
WHERE object_id = OBJECT_ID('GetSalesReport');
```