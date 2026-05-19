-- ========================================
-- SQL Server 慢查询捕获方案 - 简化版
-- ========================================

-- 【方法1】实时监控当前正在运行的查询
PRINT '=== 方法1：实时监控当前查询 ===';
SELECT 
    session_id, 
    start_time, 
    DATEDIFF(second, start_time, GETDATE()) AS elapsed_seconds, 
    status,
    command,
    SUBSTRING(st.text, (er.statement_start_offset/2)+1,
        ((CASE er.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)
          ELSE er.statement_end_offset END - er.statement_start_offset)/2) + 1) AS query_text
FROM sys.dm_exec_requests er
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
WHERE session_id > 50  -- 排除系统会话
ORDER BY elapsed_seconds DESC;

GO

-- 【方法2】启用Query Store（推荐用于历史慢查询分析）
PRINT '';
PRINT '=== 方法2：启用Query Store ===';
ALTER DATABASE ART_CONTEST SET QUERY_STORE = ON;
ALTER DATABASE ART_CONTEST SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30)
);
PRINT 'Query Store已启用';

GO

-- 【方法3】使用DMV查询缓存中的慢查询
PRINT '';
PRINT '=== 方法3：查询缓存中的慢查询 ===';
SELECT TOP 10
    qs.total_elapsed_time / qs.execution_count / 1000000.0 AS avg_duration_seconds,
    qs.total_elapsed_time / 1000000.0 AS total_duration_seconds,
    qs.execution_count,
    SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(st.text)
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
WHERE qs.total_elapsed_time / qs.execution_count > 1000000  -- 平均超过1秒
ORDER BY avg_duration_seconds DESC;

GO

-- 【方法4】创建慢查询日志表（手动记录）
PRINT '';
PRINT '=== 方法4：创建慢查询日志表 ===';
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'slow_query_log')
BEGIN
    CREATE TABLE slow_query_log (
        log_id INT IDENTITY(1,1) PRIMARY KEY,
        session_id INT,
        start_time DATETIME,
        end_time DATETIME,
        duration_seconds INT,
        query_text NVARCHAR(MAX),
        captured_at DATETIME DEFAULT GETDATE()
    );
    PRINT 'slow_query_log表已创建';
END
ELSE
BEGIN
    PRINT 'slow_query_log表已存在';
END