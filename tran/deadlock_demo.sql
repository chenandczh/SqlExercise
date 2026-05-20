/*
SQL Server 死锁模拟演示脚本
============================
文件：deadlock_demo.sql
版本：V1.0
日期：2026年5月

使用说明：
1. 打开两个SSMS查询窗口
2. 在窗口1执行脚本的"会话1"部分
3. 立即在窗口2执行脚本的"会话2"部分
4. 观察死锁现象

注意：此脚本用于教学演示，生产环境需谨慎使用
*/

USE ART_CONTEST;
GO

-- ========================================
-- 准备：创建测试表
-- ========================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DeadlockTestA')
BEGIN
    CREATE TABLE DeadlockTestA (
        ID INT PRIMARY KEY,
        Value VARCHAR(50)
    );
    
    INSERT INTO DeadlockTestA (ID, Value) VALUES (1, 'Initial A');
    INSERT INTO DeadlockTestA (ID, Value) VALUES (2, 'Initial A2');
END

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DeadlockTestB')
BEGIN
    CREATE TABLE DeadlockTestB (
        ID INT PRIMARY KEY,
        Value VARCHAR(50)
    );
    
    INSERT INTO DeadlockTestB (ID, Value) VALUES (1, 'Initial B');
    INSERT INTO DeadlockTestB (ID, Value) VALUES (2, 'Initial B2');
END
GO

-- ========================================
-- 会话1：先更新表A，再更新表B
-- ========================================
-- 在第一个查询窗口执行
PRINT '=== 会话1开始 ===';
BEGIN TRANSACTION Session1;
BEGIN TRY
    -- 第一步：锁定表A的记录
    UPDATE DeadlockTestA 
    SET Value = 'Updated by Session 1' 
    WHERE ID = 1;
    PRINT '会话1：已锁定 DeadlockTestA(ID=1)';
    
    -- 延迟一段时间，确保会话2有机会执行
    WAITFOR DELAY '00:00:03';
    PRINT '会话1：等待结束，准备锁定表B';
    
    -- 第二步：尝试锁定表B的记录（此时会话2已锁定表B）
    UPDATE DeadlockTestB 
    SET Value = 'Updated by Session 1' 
    WHERE ID = 1;
    PRINT '会话1：已锁定 DeadlockTestB(ID=1)';
    
    COMMIT TRANSACTION Session1;
    PRINT '会话1：事务提交成功';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION Session1;
    PRINT '会话1：事务回滚 - ' + ERROR_MESSAGE();
END CATCH;
GO

-- ========================================
-- 会话2：先更新表B，再更新表A
-- ========================================
-- 在第二个查询窗口执行（与会话1同时或稍晚启动）
PRINT '=== 会话2开始 ===';
BEGIN TRANSACTION Session2;
BEGIN TRY
    -- 第一步：锁定表B的记录
    UPDATE DeadlockTestB 
    SET Value = 'Updated by Session 2' 
    WHERE ID = 1;
    PRINT '会话2：已锁定 DeadlockTestB(ID=1)';
    
    -- 延迟一段时间，确保会话1有机会执行
    WAITFOR DELAY '00:00:03';
    PRINT '会话2：等待结束，准备锁定表A';
    
    -- 第二步：尝试锁定表A的记录（此时会话1已锁定表A）
    UPDATE DeadlockTestA 
    SET Value = 'Updated by Session 2' 
    WHERE ID = 1;
    PRINT '会话2：已锁定 DeadlockTestA(ID=1)';
    
    COMMIT TRANSACTION Session2;
    PRINT '会话2：事务提交成功';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION Session2;
    PRINT '会话2：事务回滚 - ' + ERROR_MESSAGE();
END CATCH;
GO

-- ========================================
-- 死锁检测查询
-- ========================================
-- 在死锁发生后执行此查询查看死锁信息
PRINT '=== 死锁信息查询 ===';

-- 方法1：创建扩展事件会话（首次使用时执行）
IF NOT EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'DeadlockTracking')
BEGIN
    CREATE EVENT SESSION [DeadlockTracking] ON SERVER 
    ADD EVENT sqlserver.xml_deadlock_report(
        ACTION(sqlserver.sql_text, sqlserver.session_id)
    )
    ADD TARGET package0.event_file(SET filename=N'DeadlockReport.xel')
    WITH (STARTUP_STATE=ON);
    PRINT '扩展事件会话已创建';
END

-- 确保会话已启动
IF NOT EXISTS (SELECT * FROM sys.dm_xe_sessions WHERE name = 'DeadlockTracking')
BEGIN
    ALTER EVENT SESSION [DeadlockTracking] ON SERVER STATE = START;
    PRINT '扩展事件会话已启动';
END

-- 查询扩展事件中的死锁报告
SELECT 
    XEventData.value('(event/@name)[1]', 'varchar(50)') AS EventName,
    XEventData.value('(event/@timestamp)[1]', 'datetime') AS EventTime,
    XEventData.value('(event/data[@name="xml_report"]/value/deadlock)[1]', 'xml') AS DeadlockGraph,
    XEventData.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS SqlText,
    XEventData.value('(event/action[@name="session_id"]/value)[1]', 'int') AS SessionID
FROM (
    SELECT CAST(event_data AS XML) AS XEventData
    FROM sys.fn_xe_file_target_read_file('DeadlockReport*.xel', NULL, NULL, NULL)
) AS XEvents
ORDER BY EventTime DESC;

-- 方法2：查看系统视图中的死锁统计
SELECT 
    wait_type,
    waiting_tasks_count AS 等待次数,
    wait_time_ms / 1000.0 AS 总等待时间_秒,
    max_wait_time_ms / 1000.0 AS 最大等待时间_秒
FROM sys.dm_os_wait_stats
WHERE wait_type IN ('DEADLOCK_LOCK_WAIT', 'LOCK_DEADLOCK');

-- 方法3：查看当前锁信息和阻塞情况
SELECT 
    blocking_session_id AS 阻塞会话ID,
    session_id AS 当前会话ID,
    resource_type AS 资源类型,
    resource_description AS 资源描述,
    request_mode AS 请求模式,
    request_status AS 请求状态
FROM sys.dm_tran_locks
WHERE blocking_session_id IS NOT NULL;

-- 方法4：从系统健康会话查询（SQL Server 2012+）
PRINT '=== 从系统健康会话查询死锁 ===';
SELECT 
    XEventData.value('(event/@name)[1]', 'varchar(50)') AS EventName,
    XEventData.value('(event/@timestamp)[1]', 'datetime') AS EventTime,
    XEventData.value('(event/data[@name="xml_report"]/value/deadlock)[1]', 'xml') AS DeadlockGraph
FROM (
    SELECT CAST(event_data AS XML) AS XEventData
    FROM sys.fn_xe_file_target_read_file(
        'system_health*.xel', 
        NULL, 
        NULL, 
        NULL
    )
) AS XEvents
WHERE XEventData.value('(event/@name)[1]', 'varchar(50)') = 'xml_deadlock_report'
ORDER BY EventTime DESC;
GO

-- ========================================
-- 清理测试数据
-- ========================================
PRINT '=== 清理测试数据 ===';
DELETE FROM DeadlockTestA;
DELETE FROM DeadlockTestB;
GO