-- ========================================
-- 存储过程与自定义函数教学案例 - SQL脚本
-- ========================================

-- ========================================
-- 1. 存储过程示例
-- ========================================

-- 示例1：查询指定部门的员工
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetEmployeesByDepartment')
    DROP PROCEDURE GetEmployeesByDepartment;
GO

CREATE PROCEDURE GetEmployeesByDepartment
    @DepartmentName VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        user_id,
        username,
        department,
        registration_date,
        score
    FROM slow_query_test
    WHERE department = @DepartmentName;
END
GO

-- 示例2：带输出参数的存储过程
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetDepartmentStats')
    DROP PROCEDURE GetDepartmentStats;
GO

CREATE PROCEDURE GetDepartmentStats
    @DepartmentName VARCHAR(50),
    @TotalUsers INT OUTPUT,
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

-- 示例3：带返回值的存储过程
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'CheckUserExists')
    DROP PROCEDURE CheckUserExists;
GO

CREATE PROCEDURE CheckUserExists
    @Username VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM slow_query_test WHERE username = @Username)
        RETURN 1;
    ELSE
        RETURN 0;
END
GO

-- 示例4：IF...ELSE流程控制
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'UpdateUserStatus')
    DROP PROCEDURE UpdateUserStatus;
GO

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
        PRINT '未找到指定用户';
    ELSE
        PRINT '用户状态更新成功';
END
GO

-- 示例5：TRY...CATCH错误处理
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'SafeUpdateUser')
    DROP PROCEDURE SafeUpdateUser;
GO

CREATE PROCEDURE SafeUpdateUser
    @UserId INT,
    @NewEmail VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF @NewEmail NOT LIKE '%_@__%.__%'
            THROW 50001, '无效的邮箱格式', 1;
        
        UPDATE slow_query_test
        SET email = @NewEmail
        WHERE user_id = @UserId;
        
        COMMIT TRANSACTION;
        PRINT '更新成功';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        SELECT
            ERROR_NUMBER() AS ErrorNumber,
            ERROR_MESSAGE() AS ErrorMessage,
            ERROR_LINE() AS ErrorLine;
    END CATCH
END
GO

-- 示例6：数据统计存储过程
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetSalesReport')
    DROP PROCEDURE GetSalesReport;
GO

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

-- 示例7：复杂业务逻辑处理（退款）
IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'ProcessRefund')
    DROP PROCEDURE ProcessRefund;
GO

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
        
        IF NOT EXISTS (SELECT 1 FROM slow_query_orders WHERE order_id = @OrderId)
        BEGIN
            SET @ResultMessage = '错误：订单不存在';
            RETURN;
        END
        
        DECLARE @OrderStatus INT;
        SELECT @OrderStatus = status FROM slow_query_orders WHERE order_id = @OrderId;
        IF @OrderStatus <> 1
        BEGIN
            SET @ResultMessage = '错误：订单状态不允许退款';
            RETURN;
        END
        
        DECLARE @TotalAmount DECIMAL(10,2);
        SELECT @TotalAmount = SUM(quantity * unit_price) 
        FROM slow_query_order_details 
        WHERE order_id = @OrderId;
        
        IF @RefundAmount > @TotalAmount
        BEGIN
            SET @ResultMessage = '错误：退款金额超过订单总额';
            RETURN;
        END
        
        UPDATE slow_query_orders
        SET status = 3,
            last_updated = GETDATE()
        WHERE order_id = @OrderId;
        
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

-- ========================================
-- 2. 自定义函数示例
-- ========================================

-- 示例1：标量函数 - 获取用户等级
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'GetUserLevelByScore' AND type = 'FN')
    DROP FUNCTION dbo.GetUserLevelByScore;
GO

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

-- 示例2：内联表值函数 - 获取指定部门用户
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'GetUsersByDepartment' AND type = 'IF')
    DROP FUNCTION dbo.GetUsersByDepartment;
GO

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

-- 示例3：多语句表值函数 - 获取用户统计信息
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'GetUserStatistics' AND type = 'TF')
    DROP FUNCTION dbo.GetUserStatistics;
GO

CREATE FUNCTION dbo.GetUserStatistics(@DepartmentName VARCHAR(50))
RETURNS @Stats TABLE (
    StatName VARCHAR(50),
    StatValue VARCHAR(100)
)
AS
BEGIN
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

-- 示例4：标量函数 - 计算订单折扣
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'CalculateDiscount' AND type = 'FN')
    DROP FUNCTION dbo.CalculateDiscount;
GO

CREATE FUNCTION dbo.CalculateDiscount(@OrderTotal DECIMAL(10,2), @UserScore DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Discount DECIMAL(10,2) = 0;
    
    IF @OrderTotal >= 10000
        SET @Discount = @Discount + 0.10;
    ELSE IF @OrderTotal >= 5000
        SET @Discount = @Discount + 0.05;
    ELSE IF @OrderTotal >= 1000
        SET @Discount = @Discount + 0.02;
    
    IF @UserScore >= 900
        SET @Discount = @Discount + 0.05;
    ELSE IF @UserScore >= 700
        SET @Discount = @Discount + 0.03;
    
    RETURN @Discount;
END
GO

-- ========================================
-- 3. 调用示例
-- ========================================

PRINT '=== 测试存储过程 ===';
PRINT '';

-- 测试 GetEmployeesByDepartment
PRINT '1. 调用 GetEmployeesByDepartment';
EXEC GetEmployeesByDepartment @DepartmentName = '技术部';

PRINT '';

-- 测试 GetDepartmentStats
PRINT '2. 调用 GetDepartmentStats';
DECLARE @Total INT, @Avg DECIMAL(10,2);
EXEC GetDepartmentStats 
    @DepartmentName = '技术部',
    @TotalUsers = @Total OUTPUT,
    @AvgScore = @Avg OUTPUT;
SELECT @Total AS TotalUsers, @Avg AS AverageScore;

PRINT '';

-- 测试 CheckUserExists
PRINT '3. 调用 CheckUserExists';
DECLARE @Result INT;
EXEC @Result = CheckUserExists @Username = 'user_1';
SELECT @Result AS UserExists;

PRINT '';

-- 测试标量函数
PRINT '4. 使用标量函数 GetUserLevelByScore';
SELECT TOP 5
    username,
    score,
    dbo.GetUserLevelByScore(score) AS UserLevel
FROM slow_query_test;

PRINT '';

-- 测试内联表值函数
PRINT '5. 使用内联表值函数 GetUsersByDepartment';
SELECT TOP 5 * FROM dbo.GetUsersByDepartment('技术部');

PRINT '';

-- 测试多语句表值函数
PRINT '6. 使用多语句表值函数 GetUserStatistics';
SELECT * FROM dbo.GetUserStatistics('技术部');

PRINT '';
PRINT '=== 所有测试完成 ===';