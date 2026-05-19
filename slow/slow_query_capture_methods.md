# SQL Server 慢查询捕获与性能监控方法

## 目录
1. [慢查询问题概述](#1-慢查询问题概述)
2. [SQL Server 查询计划失效原因分析](#2-sql-server-查询计划失效原因分析)
3. [内置工具捕获慢查询](#3-内置工具捕获慢查询)
4. [动态管理视图(DMV)捕获慢查询](#4-动态管理视图dmv捕获慢查询)
5. [扩展事件(Extended Events)捕获慢查询](#5-扩展事件extended-events捕获慢查询)
6. [Query Store 捕获慢查询](#6-query-store-捕获慢查询)
7. [性能监控与告警策略](#7-性能监控与告警策略)
8. [第三方工具集成](#8-第三方工具集成)
9. [最佳实践建议](#9-最佳实践建议)

---

## 1. 慢查询问题概述

### 1.1 慢查询的定义

慢查询是指执行时间超过预期阈值的SQL查询，通常表现为：

| 指标 | 阈值参考 | 说明 |
|------|----------|------|
| **执行时间** | > 1秒 | 交互式查询的合理响应时间 |
| **逻辑读** | > 1000次 | 大量内存读取 |
| **物理读** | > 100次 | 大量磁盘读取 |
| **CPU时间** | > 500ms | 高CPU消耗 |

### 1.2 慢查询的影响

| 影响维度 | 具体表现 |
|----------|----------|
| **用户体验** | 页面响应慢、超时错误 |
| **系统性能** | CPU/内存/IO资源耗尽 |
| **数据库性能** | 阻塞、死锁、锁等待 |
| **业务影响** | 订单处理延迟、数据不一致 |

### 1.3 典型慢查询场景

| 场景 | 示例 |
|------|------|
| **全表扫描** | 缺少索引或索引失效 |
| **复杂连接** | 多表JOIN且条件不明确 |
| **大结果集** | SELECT * 返回大量数据 |
| **排序操作** | ORDER BY/GROUP BY 无索引支持 |
| **参数嗅探** | 执行计划不适合当前参数 |

---

## 2. SQL Server 查询计划失效原因分析

### 2.1 索引突然失效的常见原因

**问题现象**：早上索引生效，下午索引失效

| 原因 | 说明 | 解决方案 |
|------|------|----------|
| **统计信息过期** | 数据变化超过20%，统计信息未更新 | UPDATE STATISTICS |
| **参数嗅探** | 第一次执行的参数影响后续执行计划 | OPTION (RECOMPILE) |
| **执行计划缓存** | 旧的执行计划被复用 | DBCC FREEPROCCACHE |
| **数据分布变化** | 新增/删除大量数据 | 更新统计信息 |
| **索引碎片化** | 索引页碎片化严重 | REBUILD/REORGANIZE |
| **查询重编译** | 模式变更触发重编译 | 检查依赖对象 |

### 2.2 查询计划缓存机制

```
SQL Server 查询执行流程：
1. 用户提交查询
2. 检查执行计划缓存
3. 如果缓存命中 → 直接执行
4. 如果缓存未命中 → 生成新计划并缓存

缓存失效条件：
- 表结构变更（ALTER TABLE）
- 索引创建/删除
- 统计信息更新
- 内存压力导致缓存清理
- 计划缓存达到阈值
```

### 2.3 参数嗅探问题

```sql
-- 参数嗅探示例
-- 第一次执行：参数为常见值，生成高效计划
SELECT * FROM sales WHERE artist_id = 2102; -- 高频艺术家

-- 第二次执行：参数为稀有值，但复用了第一次的计划
SELECT * FROM sales WHERE artist_id = 9999; -- 低频艺术家
```

---

## 3. 内置工具捕获慢查询

### 3.1 SQL Server Profiler（已弃用，但仍可用）

**使用步骤**：
1. 打开 SSMS → 连接数据库
2. 工具 → SQL Server Profiler
3. 创建新跟踪 → 选择"TSQL_SPs"或"TSQL_Replay"模板
4. 设置筛选条件：Duration > 1000000（1秒）
5. 开始跟踪 → 捕获慢查询

**优点**：
- 图形化界面，易于使用
- 实时监控
- 支持多种事件类型

**缺点**：
- 性能开销大（约5-10%）
- 已被Extended Events取代
- 不适合生产环境长期运行

### 3.2 SSMS 活动监视器

**使用步骤**：
1. 打开 SSMS → 连接数据库
2. 右键服务器 → 活动监视器
3. 查看"进程"和"等待任务"
4. 筛选长时间运行的查询

**监控指标**：
| 指标 | 说明 |
|------|------|
| **CPU** | 高CPU消耗的查询 |
| **I/O** | 高磁盘读写的查询 |
| **等待时间** | 阻塞和等待的查询 |
| **执行时间** | 长时间运行的查询 |

---

## 4. 动态管理视图(DMV)捕获慢查询

### 4.1 查询慢查询历史

```sql
-- 查询执行时间最长的TOP 10查询
SELECT TOP 10
    qs.total_elapsed_time / 1000000.0 AS total_elapsed_time_sec,
    qs.total_logical_reads,
    qs.total_physical_reads,
    qs.execution_count,
    SUBSTRING(qt.text, (qs.statement_start_offset/2)+1, 
        ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text) 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) + 1) AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
WHERE qt.text NOT LIKE '%sys.dm_exec%'
ORDER BY qs.total_elapsed_time DESC;
```

### 4.2 查询当前正在执行的慢查询

```sql
-- 查询当前运行时间超过5秒的查询
SELECT 
    session_id,
    start_time,
    DATEDIFF(second, start_time, GETDATE()) AS elapsed_seconds,
    status,
    SUBSTRING(st.text, (er.statement_start_offset/2)+1, 
        ((CASE er.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) 
          ELSE er.statement_end_offset END - er.statement_start_offset)/2) + 1) AS query_text
FROM sys.dm_exec_requests er
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
WHERE DATEDIFF(second, start_time, GETDATE()) > 5
  AND session_id <> @@SPID
ORDER BY elapsed_seconds DESC;
```

### 4.3 查询缺失索引建议

```sql
-- 查询缺失索引建议
SELECT TOP 10
    CONVERT(VARCHAR(128), mid.equality_columns) AS equality_columns,
    CONVERT(VARCHAR(128), mid.inequality_columns) AS inequality_columns,
    CONVERT(VARCHAR(128), mid.included_columns) AS included_columns,
    migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) AS improvement_measure,
    'CREATE NONCLUSTERED INDEX IX_' + OBJECT_NAME(mid.object_id) + '_' + 
    REPLACE(REPLACE(CONVERT(VARCHAR(128), mid.equality_columns), ', ', '_'), '[', '') + '_' +
    REPLACE(REPLACE(CONVERT(VARCHAR(128), mid.inequality_columns), ', ', '_'), '[', '') AS create_index_command
FROM sys.dm_db_missing_index_details mid
INNER JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
ORDER BY improvement_measure DESC;
```

### 4.4 查询索引使用情况

```sql
-- 查询未使用的索引（创建后从未使用）
SELECT 
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    'DROP INDEX ' + i.name + ' ON ' + OBJECT_NAME(i.object_id) AS drop_command
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE i.name LIKE 'IX_%'
  AND s.user_seeks IS NULL
  AND s.user_scans IS NULL
  AND s.user_lookups IS NULL
  AND i.is_primary_key = 0;
```

---

## 5. 扩展事件(Extended Events)捕获慢查询

### 5.1 创建扩展事件会话

```sql
-- 创建慢查询捕获会话
CREATE EVENT SESSION [SlowQueries] ON SERVER 
ADD EVENT sqlserver.sql_statement_completed(
    ACTION(sqlserver.sql_text, sqlserver.session_id, sqlserver.username)
    WHERE duration > 1000000 -- 超过1秒
),
ADD EVENT sqlserver.rpc_completed(
    ACTION(sqlserver.sql_text, sqlserver.session_id, sqlserver.username)
    WHERE duration > 1000000
)
ADD TARGET package0.event_file(SET filename=N'C:\XEvents\SlowQueries.xel')
WITH (STARTUP_STATE=ON);
GO

-- 启动会话
ALTER EVENT SESSION [SlowQueries] ON SERVER STATE=START;
GO
```

### 5.2 查询扩展事件数据

```sql
-- 查询捕获的慢查询数据
SELECT 
    event_data.value('(event/@name)[1]', 'varchar(50)') AS event_name,
    event_data.value('(event/@timestamp)[1]', 'datetime') AS event_time,
    event_data.value('(event/data[@name="duration"]/value)[1]', 'bigint') / 1000000.0 AS duration_sec,
    event_data.value('(event/data[@name="logical_reads"]/value)[1]', 'bigint') AS logical_reads,
    event_data.value('(event/data[@name="physical_reads"]/value)[1]', 'bigint') AS physical_reads,
    event_data.value('(event/action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS sql_text,
    event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') AS session_id,
    event_data.value('(event/action[@name="username"]/value)[1]', 'varchar(100)') AS username
FROM 
    (SELECT CAST(event_data AS XML) AS event_data 
     FROM sys.fn_xe_file_target_read_file('C:\XEvents\SlowQueries*.xel', NULL, NULL, NULL)) AS x
ORDER BY event_time DESC;
```

### 5.3 扩展事件优点

| 优点 | 说明 |
|------|------|
| **性能开销低** | 仅约1-2% |
| **轻量级** | 适合生产环境长期运行 |
| **灵活** | 可自定义事件和筛选条件 |
| **可扩展** | 支持多种目标类型 |

---

## 6. Query Store 捕获慢查询

### 6.1 启用 Query Store

```sql
-- 启用Query Store
ALTER DATABASE ART_CONTEST 
SET QUERY_STORE = ON
(
    OPERATION_MODE = READ_WRITE,
    CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES = 60,
    MAX_STORAGE_SIZE_MB = 1024,
    QUERY_CAPTURE_MODE = AUTO,
    SIZE_BASED_CLEANUP_MODE = AUTO,
    MAX_PLANS_PER_QUERY = 100
);
GO
```

### 6.2 查询慢查询（通过Query Store）

```sql
-- 查询执行时间最长的查询
SELECT TOP 10
    qsq.query_id,
    qsq.object_id,
    qsq.query_hash,
    qsp.plan_id,
    qsp.last_compile_time,
    qsp.last_execution_time,
    qsp.avg_duration / 1000000.0 AS avg_duration_sec,
    qsp.max_duration / 1000000.0 AS max_duration_sec,
    qsp.total_duration / 1000000.0 AS total_duration_sec,
    qsp.avg_logical_io_reads,
    qsp.execution_count,
    SUBSTRING(qsqt.query_sql_text, 1, 500) AS query_text
FROM sys.query_store_query qsq
INNER JOIN sys.query_store_plan qsp ON qsq.query_id = qsp.query_id
INNER JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id
ORDER BY qsp.avg_duration DESC;
```

### 6.3 查询计划回归检测

```sql
-- 查询执行计划回归（性能突然变差的查询）
SELECT 
    qsq.query_id,
    qsp.plan_id,
    qsp.avg_duration / 1000000.0 AS avg_duration_sec,
    qsp_regressed.avg_duration / 1000000.0 AS regressed_duration_sec,
    (qsp_regressed.avg_duration - qsp.avg_duration) / qsp.avg_duration * 100 AS regression_percent,
    SUBSTRING(qsqt.query_sql_text, 1, 500) AS query_text
FROM sys.query_store_query qsq
INNER JOIN sys.query_store_plan qsp ON qsq.query_id = qsp.query_id
INNER JOIN sys.query_store_plan qsp_regressed ON qsq.query_id = qsp_regressed.query_id
INNER JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id
WHERE qsp.is_forced_plan = 1
  AND qsp_regressed.avg_duration > qsp.avg_duration * 2 -- 性能下降超过2倍
ORDER BY regression_percent DESC;
```

### 6.4 Query Store 优点

| 优点 | 说明 |
|------|------|
| **自动捕获** | 无需手动配置，自动捕获查询 |
| **历史追踪** | 保留查询执行历史 |
| **计划比较** | 可比较不同执行计划的性能 |
| **强制计划** | 可强制使用高效执行计划 |

---

## 7. 性能监控与告警策略

### 7.1 建立性能基线

```sql
-- 收集性能基线数据
CREATE TABLE PerformanceBaseline (
    baseline_id INT IDENTITY(1,1) PRIMARY KEY,
    capture_time DATETIME DEFAULT GETDATE(),
    cpu_usage DECIMAL(5,2),
    memory_usage DECIMAL(5,2),
    disk_io_usage DECIMAL(5,2),
    avg_query_duration_ms INT,
    max_query_duration_ms INT,
    active_sessions INT,
    blocked_processes INT
);
GO

-- 定期收集基线数据
INSERT INTO PerformanceBaseline (
    cpu_usage, memory_usage, disk_io_usage,
    avg_query_duration_ms, max_query_duration_ms,
    active_sessions, blocked_processes
)
SELECT
    (SELECT TOP 1 100.0 - system_health FROM sys.dm_os_ring_buffers WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'),
    (SELECT TOP 1 (total_physical_memory_kb - available_physical_memory_kb) * 100.0 / total_physical_memory_kb FROM sys.dm_os_sys_memory),
    (SELECT TOP 1 100.0 - idle_time / 100.0 FROM sys.dm_os_wait_stats WHERE wait_type = N'IDLE'),
    (SELECT AVG(total_elapsed_time / 1000) FROM sys.dm_exec_query_stats),
    (SELECT MAX(total_elapsed_time / 1000) FROM sys.dm_exec_query_stats),
    (SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1),
    (SELECT COUNT(*) FROM sys.dm_os_wait_stats WHERE wait_type = N'BLOCKED_PROCESS_REPORT')
GO
```

### 7.2 设置慢查询告警

```sql
-- 创建慢查询告警作业
USE msdb;
GO

-- 创建作业
EXEC dbo.sp_add_job
    @job_name = N'Slow Query Alert',
    @enabled = 1,
    @description = N'检测并告警慢查询';
GO

-- 添加步骤
EXEC dbo.sp_add_jobstep
    @job_name = N'Slow Query Alert',
    @step_name = N'Check Slow Queries',
    @step_id = 1,
    @subsystem = N'TSQL',
    @command = N'
        IF EXISTS (
            SELECT 1 FROM sys.dm_exec_requests er
            WHERE DATEDIFF(second, er.start_time, GETDATE()) > 30
              AND er.session_id <> @@SPID
        )
        BEGIN
            -- 发送邮件告警
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = ''DBA_Profile'',
                @recipients = ''dba@example.com'',
                @subject = ''Slow Query Alert - ART_CONTEST'',
                @body = ''检测到运行时间超过30秒的慢查询，请立即检查！'';
        END
    ',
    @database_name = N'ART_CONTEST';
GO

-- 添加调度（每分钟执行）
EXEC dbo.sp_add_jobschedule
    @job_name = N'Slow Query Alert',
    @name = N'Every Minute',
    @enabled = 1,
    @freq_type = 4, -- 每天
    @freq_interval = 1,
    @freq_subday_type = 4, -- 分钟
    @freq_subday_interval = 1;
GO
```

### 7.3 阻塞进程检测

```sql
-- 检测阻塞进程
WITH BlockedProcesses AS (
    SELECT 
        blocking_session_id,
        session_id,
        DATEDIFF(second, start_time, GETDATE()) AS blocked_duration_sec,
        SUBSTRING(st.text, (er.statement_start_offset/2)+1, 
            ((CASE er.statement_end_offset WHEN -1 THEN DATALENGTH(st.text) 
              ELSE er.statement_end_offset END - er.statement_start_offset)/2) + 1) AS blocked_query
    FROM sys.dm_exec_requests er
    CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
    WHERE blocking_session_id IS NOT NULL
)
SELECT 
    bp.blocking_session_id,
    bp.session_id AS blocked_session_id,
    bp.blocked_duration_sec,
    bp.blocked_query,
    SUBSTRING(st.text, 1, 200) AS blocking_query
FROM BlockedProcesses bp
LEFT JOIN sys.dm_exec_requests er ON bp.blocking_session_id = er.session_id
CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
WHERE bp.blocked_duration_sec > 10 -- 阻塞超过10秒
ORDER BY bp.blocked_duration_sec DESC;
```

---

## 8. 第三方工具集成

### 8.1 Azure Monitor（云环境）

| 功能 | 说明 |
|------|------|
| **性能指标收集** | CPU、内存、IO、查询性能 |
| **智能检测** | 自动检测异常性能模式 |
| **告警规则** | 自定义阈值告警 |
| **可视化仪表板** | 实时监控图表 |

### 8.2 SolarWinds Database Performance Analyzer

| 功能 | 说明 |
|------|------|
| **查询分析** | 深入分析查询执行计划 |
| **性能基线** | 建立和对比性能基线 |
| **预测分析** | 预测性能趋势 |
| **自动化建议** | 自动生成优化建议 |

### 8.3 Redgate SQL Monitor

| 功能 | 说明 |
|------|------|
| **实时监控** | 实时性能监控 |
| **历史分析** | 历史性能数据查询 |
| **异常检测** | 智能异常检测 |
| **报表生成** | 自动生成性能报表 |

---

## 9. 最佳实践建议

### 9.1 慢查询捕获策略

| 策略 | 说明 |
|------|------|
| **分层监控** | 开发环境用Profiler，生产环境用Extended Events |
| **阈值设定** | 根据业务需求设定合理阈值 |
| **定期审查** | 每周审查慢查询日志 |
| **自动化告警** | 设置邮件/短信告警 |

### 9.2 查询性能优化流程

```
慢查询检测 → 分析执行计划 → 识别瓶颈 → 优化索引/查询 → 验证效果 → 建立基线
```

### 9.3 索引维护最佳实践

| 实践 | 说明 |
|------|------|
| **定期更新统计信息** | 每周执行 UPDATE STATISTICS |
| **重建碎片化索引** | 碎片化>30%重建，10-30%重组 |
| **清理未使用的索引** | 删除创建后从未使用的索引 |
| **监控索引使用** | 定期检查sys.dm_db_index_usage_stats |

### 9.4 参数嗅探解决方案

| 方案 | 说明 |
|------|------|
| **OPTION (RECOMPILE)** | 每次重新编译执行计划 |
| **OPTION (OPTIMIZE FOR)** | 指定参数值优化 |
| **OPTION (USE HINT)** | 使用查询提示 |
| **计划指南** | 创建计划指南强制使用特定计划 |

---

## 附录：常用查询语句

### A. 实时监控查询

```sql
-- 当前活动查询
SELECT * FROM sys.dm_exec_requests WHERE status = 'running';

-- 阻塞进程
SELECT * FROM sys.dm_os_wait_stats WHERE wait_type = 'BLOCKED_PROCESS_REPORT';

-- CPU消耗最高的查询
SELECT TOP 5 * FROM sys.dm_exec_query_stats ORDER BY total_worker_time DESC;
```

### B. 性能基线查询

```sql
-- 最近7天的性能趋势
SELECT 
    CONVERT(DATE, capture_time) AS capture_date,
    AVG(avg_query_duration_ms) AS avg_duration_ms,
    MAX(max_query_duration_ms) AS max_duration_ms,
    AVG(active_sessions) AS avg_sessions
FROM PerformanceBaseline
WHERE capture_time > DATEADD(day, -7, GETDATE())
GROUP BY CONVERT(DATE, capture_time)
ORDER BY capture_date;
```

### C. 查询计划缓存管理

```sql
-- 查看计划缓存使用情况
SELECT 
    objtype,
    COUNT(*) AS plan_count,
    SUM(size_in_bytes) / 1024 / 1024 AS size_mb
FROM sys.dm_exec_cached_plans
GROUP BY objtype;

-- 清理特定查询的执行计划
DBCC FREEPROCCACHE (plan_handle);

-- 清理所有执行计划（谨慎使用）
DBCC FREEPROCCACHE;
```
