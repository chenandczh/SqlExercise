/*
SQL Server 事务与并发控制实践脚本
====================================
文件：transaction_practice.sql
版本：V1.0
日期：2026年5月
适用：SQL Server 2016+
*/

USE ART_CONTEST;
GO

-- ========================================
-- 第1部分：事务基础操作
-- ========================================
PRINT '========== 第1部分：事务基础操作 ==========';
GO

-- 1.1 简单事务示例
BEGIN TRANSACTION;
BEGIN TRY
    INSERT INTO artist_roster (artist_id, artist_name, a_team_id, specialization_id, cur_art_studio)
    VALUES (9999, 'Test Artist', 1049, 'PT', 'Test Studio');
    
    COMMIT TRANSACTION;
    PRINT '1.1 简单事务：提交成功';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT '1.1 简单事务：回滚 - ' + ERROR_MESSAGE();
END CATCH;
GO

-- 1.2 带验证的事务
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @Stock INT;
    SELECT @Stock = stock_qty FROM inventory WHERE product_id = 'P001';
    
    IF @Stock >= 5
    BEGIN
        UPDATE inventory SET stock_qty = stock_qty - 5 WHERE product_id = 'P001';
        INSERT INTO orders (order_id, customer_id, order_date) VALUES ('TEST001', 'C001', GETDATE());
        COMMIT TRANSACTION;
        PRINT '1.2 带验证事务：提交成功';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT '1.2 带验证事务：回滚 - 库存不足';
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT '1.2 带验证事务：异常回滚 - ' + ERROR_MESSAGE();
END CATCH;
GO

-- ========================================
-- 第2部分：隔离级别演示
-- ========================================
PRINT '========== 第2部分：隔离级别演示 ==========';
GO

-- 2.1 READ UNCOMMITTED（未提交读）
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
BEGIN TRANSACTION;
    SELECT COUNT(*) AS OrderCount FROM orders;
COMMIT TRANSACTION;
PRINT '2.1 READ UNCOMMITTED：查询完成';
GO

-- 2.2 READ COMMITTED（已提交读 - 默认）
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
    SELECT * FROM artist_roster WHERE specialization_id = 'PT';
COMMIT TRANSACTION;
PRINT '2.2 READ COMMITTED：查询完成';
GO

-- 2.3 REPEATABLE READ（可重复读）
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
BEGIN TRANSACTION;
    SELECT AVG(point_amt) AS AvgPoints FROM point_details;
    -- 模拟等待期间其他事务可能的修改
    WAITFOR DELAY '00:00:02';
    SELECT AVG(point_amt) AS AvgPoints FROM point_details;
COMMIT TRANSACTION;
PRINT '2.3 REPEATABLE READ：查询完成';
GO

-- 2.4 SERIALIZABLE（可串行化）
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;
    SELECT COUNT(*) AS TeamCount FROM art_team_results WHERE round_stage = 'G';
    WAITFOR DELAY '00:00:02';
    SELECT COUNT(*) AS TeamCount FROM art_team_results WHERE round_stage = 'G';
COMMIT TRANSACTION;
PRINT '2.4 SERIALIZABLE：查询完成';
GO

-- 恢复默认隔离级别
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO

-- ========================================
-- 第3部分：并发控制演示
-- ========================================
PRINT '========== 第3部分：并发控制演示 ==========';
GO

-- 3.1 乐观并发控制（基于版本）
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @CurrentVersion INT;
    SELECT @CurrentVersion = version FROM products WHERE product_id = 'P001';
    
    UPDATE products 
    SET price = 199.99, version = version + 1
    WHERE product_id = 'P001' AND version = @CurrentVersion;
    
    IF @@ROWCOUNT = 0
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT '3.1 乐观并发：数据已被修改，回滚';
    END
    ELSE
    BEGIN
        COMMIT TRANSACTION;
        PRINT '3.1 乐观并发：更新成功';
    END
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT '3.1 乐观并发：异常 - ' + ERROR_MESSAGE();
END CATCH;
GO

-- 3.2 悲观并发控制（使用锁提示）
BEGIN TRANSACTION;
BEGIN TRY
    -- 使用 UPDLOCK 获取更新锁
    SELECT * FROM orders WITH (UPDLOCK, HOLDLOCK) 
    WHERE order_id = 'TEST001';
    
    -- 模拟处理时间
    WAITFOR DELAY '00:00:01';
    
    UPDATE orders SET status = 'Processed' WHERE order_id = 'TEST001';
    
    COMMIT TRANSACTION;
    PRINT '3.2 悲观并发：更新成功';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT '3.2 悲观并发：异常 - ' + ERROR_MESSAGE();
END CATCH;
GO

-- ========================================
-- 第4部分：锁机制实践
-- ========================================
PRINT '========== 第4部分：锁机制实践 ==========';
GO

-- 4.1 使用 NOLOCK 提示（无锁读取）
SELECT * FROM artist_roster WITH (NOLOCK);
PRINT '4.1 NOLOCK：查询完成';
GO

-- 4.2 使用 HOLDLOCK 提示（保持共享锁）
BEGIN TRANSACTION;
    SELECT * FROM art_team_results WITH (HOLDLOCK) WHERE in_group = 'Group A';
    WAITFOR DELAY '00:00:01';
COMMIT TRANSACTION;
PRINT '4.2 HOLDLOCK：查询完成';
GO

-- 4.3 使用 TABLOCK 提示（表级锁）
BEGIN TRANSACTION;
    SELECT COUNT(*) FROM artist_roster WITH (TABLOCK);
COMMIT TRANSACTION;
PRINT '4.3 TABLOCK：查询完成';
GO

-- ========================================
-- 第5部分：死锁模拟与处理
-- ========================================
PRINT '========== 第5部分：死锁模拟与处理 ==========';
GO

-- 5.1 设置死锁超时
SET LOCK_TIMEOUT 5000;  -- 5秒超时
PRINT '5.1 死锁超时设置完成：5000ms';
GO

-- 5.2 创建死锁监控表（如果不存在）
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DeadlockLog')
BEGIN
    CREATE TABLE DeadlockLog (
        LogID INT IDENTITY(1,1) PRIMARY KEY,
        DeadlockTime DATETIME DEFAULT GETDATE(),
        DeadlockGraph XML
    );
    PRINT '5.2 死锁监控表创建完成';
END
GO

-- ========================================
-- 第6部分：嵌套事务与保存点
-- ========================================
PRINT '========== 第6部分：嵌套事务与保存点 ==========';
GO

-- 6.1 嵌套事务示例
BEGIN TRANSACTION OuterTran;
BEGIN TRY
    INSERT INTO log_entries (message, log_time) 
    VALUES ('外层事务开始', GETDATE());
    
    BEGIN TRANSACTION InnerTran;
    BEGIN TRY
        INSERT INTO log_entries (message, log_time) 
        VALUES ('内层事务开始', GETDATE());
        
        -- 模拟内层成功
        COMMIT TRANSACTION InnerTran;
        PRINT '6.1 内层事务提交成功';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION InnerTran;
        PRINT '6.1 内层事务回滚';
        THROW;
    END CATCH;
    
    COMMIT TRANSACTION OuterTran;
    PRINT '6.1 外层事务提交成功';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION OuterTran;
    PRINT '6.1 外层事务回滚 - ' + ERROR_MESSAGE();
END CATCH;
GO

-- 6.2 保存点示例
BEGIN TRANSACTION;
BEGIN TRY
    INSERT INTO log_entries (message) VALUES ('操作1开始');
    
    SAVE TRANSACTION SavePoint1;
    
    INSERT INTO log_entries (message) VALUES ('操作2开始');
    
    -- 模拟需要回滚到保存点
    DECLARE @RollbackFlag BIT = 0;
    IF @RollbackFlag = 1
    BEGIN
        ROLLBACK TRANSACTION SavePoint1;
        PRINT '6.2 回滚到保存点';
    END
    
    INSERT INTO log_entries (message) VALUES ('操作3开始');
    
    COMMIT TRANSACTION;
    PRINT '6.2 事务提交成功';
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT '6.2 事务回滚 - ' + ERROR_MESSAGE();
END CATCH;
GO

-- ========================================
-- 第7部分：事务性能监控
-- ========================================
PRINT '========== 第7部分：事务性能监控 ==========';
GO

-- 7.1 查看活动事务
SELECT 
    transaction_id,
    name,
    transaction_begin_time,
    CASE transaction_state 
        WHEN 0 THEN '未初始化'
        WHEN 1 THEN '已初始化但未启动'
        WHEN 2 THEN '活跃'
        WHEN 3 THEN '已结束'
        WHEN 4 THEN '提交中'
        WHEN 5 THEN '准备提交'
        WHEN 6 THEN '已提交'
        WHEN 7 THEN '回滚中'
        WHEN 8 THEN '已回滚'
    END AS transaction_state_desc
FROM sys.dm_tran_active_transactions;
PRINT '7.1 活动事务查询完成';
GO

-- 7.2 查看锁等待信息
SELECT 
    request_session_id,
    resource_type,
    resource_description,
    request_mode,
    request_status
FROM sys.dm_tran_locks
WHERE request_status = 'WAIT';
PRINT '7.2 锁等待查询完成';
GO

-- ========================================
-- 第8部分：清理测试数据
-- ========================================
PRINT '========== 第8部分：清理测试数据 ==========';
GO

BEGIN TRANSACTION;
BEGIN TRY
    DELETE FROM artist_roster WHERE artist_id = 9999;
    DELETE FROM orders WHERE order_id = 'TEST001';
    
    COMMIT TRANSACTION;
    PRINT '8.1 测试数据清理完成';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT '8.1 清理失败 - ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '========== 所有实践示例执行完成 ==========';
GO