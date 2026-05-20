-- =============================================
-- SSIS (SQL Server Integration Services) 配置脚本
-- =============================================

-- =============================================
-- 1. 检查SSIS服务状态
-- =============================================

-- 检查SSIS目录是否存在
SELECT * FROM sys.databases WHERE name = 'SSISDB';
GO

-- 检查SSIS配置
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXEC sp_configure 'Integration Services catalog';
GO

-- =============================================
-- 2. 创建SSIS目录（如果不存在）
-- =============================================

USE master;
GO

-- 检查是否已创建SSIS目录
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'SSISDB')
BEGIN
    -- 创建SSIS目录
    DECLARE @Password NVARCHAR(128) = 'SSIS@Admin2026!';
    
    EXEC [SSISDB].[catalog].[create_catalog] 
        @catalog_name = 'SSISDB',
        @description = 'SQL Server Integration Services Catalog',
        @password = @Password,
        @encryption_algorithm = 'AES_256';
    
    PRINT 'SSIS目录创建成功';
END
ELSE
BEGIN
    PRINT 'SSIS目录已存在';
END
GO

-- =============================================
-- 3. 创建SSIS文件夹
-- =============================================

USE SSISDB;
GO

-- 创建项目文件夹
IF NOT EXISTS (SELECT * FROM [catalog].[folders] WHERE name = 'ART_CONTEST_Integration')
BEGIN
    EXEC [catalog].[create_folder] 
        @folder_name = 'ART_CONTEST_Integration',
        @description = 'ART_CONTEST数据库集成项目文件夹';
    
    PRINT 'SSIS文件夹创建成功';
END
GO

-- =============================================
-- 4. 创建环境变量
-- =============================================

USE SSISDB;
GO

-- 创建环境
IF NOT EXISTS (SELECT * FROM [catalog].[environments] WHERE name = 'ART_CONTEST_Env')
BEGIN
    EXEC [catalog].[create_environment] 
        @environment_name = 'ART_CONTEST_Env',
        @folder_name = 'ART_CONTEST_Integration',
        @description = 'ART_CONTEST集成环境变量';
END
GO

-- 添加环境变量
EXEC [catalog].[create_environment_variable] 
    @variable_name = 'SourceConnectionString',
    @sensitive = FALSE,
    @description = '源数据库连接字符串',
    @environment_name = 'ART_CONTEST_Env',
    @folder_name = 'ART_CONTEST_Integration',
    @value_type = 'String',
    @value = 'Data Source=SOURCE_SERVER;Initial Catalog=SOURCE_DB;Integrated Security=True';
GO

EXEC [catalog].[create_environment_variable] 
    @variable_name = 'TargetConnectionString',
    @sensitive = FALSE,
    @description = '目标数据库连接字符串',
    @environment_name = 'ART_CONTEST_Env',
    @folder_name = 'ART_CONTEST_Integration',
    @value_type = 'String',
    @value = 'Data Source=TARGET_SERVER;Initial Catalog=ART_CONTEST;Integrated Security=True';
GO

EXEC [catalog].[create_environment_variable] 
    @variable_name = 'BatchSize',
    @sensitive = FALSE,
    @description = '批量处理大小',
    @environment_name = 'ART_CONTEST_Env',
    @folder_name = 'ART_CONTEST_Integration',
    @value_type = 'Int32',
    @value = 10000;
GO

EXEC [catalog].[create_environment_variable] 
    @variable_name = 'ErrorThreshold',
    @sensitive = FALSE,
    @description = '错误阈值',
    @environment_name = 'ART_CONTEST_Env',
    @folder_name = 'ART_CONTEST_Integration',
    @value_type = 'Int32',
    @value = 10;
GO

-- =============================================
-- 5. 部署SSIS包（示例）
-- =============================================

/*
-- 使用dtutil命令行工具部署包
dtutil /file "D:\SSISPackages\DataSync.dtsx" /destserver localhost /copy SQL;ART_CONTEST_Integration\DataSync

-- 或者使用PowerShell
Import-Module SqlServer
$project = Publish-DtsProject -Path "D:\SSISProjects\IntegrationProject.ispac" -DestinationServer "localhost" -DestinationPath "ART_CONTEST_Integration"
*/

-- =============================================
-- 6. 执行SSIS包
-- =============================================

USE SSISDB;
GO

-- 执行SSIS包（同步执行）
DECLARE @execution_id BIGINT;

EXEC [catalog].[create_execution] 
    @package_name = 'DataSync.dtsx',
    @execution_id = @execution_id OUTPUT,
    @folder_name = 'ART_CONTEST_Integration',
    @project_name = 'ART_CONTEST_Integration_Project',
    @use32bitruntime = FALSE;

-- 设置参数
EXEC [catalog].[set_execution_parameter_value] 
    @execution_id = @execution_id,
    @object_type = 30,
    @parameter_name = 'SourceConnectionString',
    @parameter_value = 'Data Source=SOURCE_SERVER;Initial Catalog=SOURCE_DB;Integrated Security=True';

EXEC [catalog].[set_execution_parameter_value] 
    @execution_id = @execution_id,
    @object_type = 30,
    @parameter_name = 'TargetConnectionString',
    @parameter_value = 'Data Source=TARGET_SERVER;Initial Catalog=ART_CONTEST;Integrated Security=True';

-- 启动执行
EXEC [catalog].[start_execution] @execution_id;

-- 检查执行状态
SELECT 
    execution_id,
    status,
    status_desc = CASE status 
        WHEN 1 THEN 'Created'
        WHEN 2 THEN 'Running'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'Failed'
        WHEN 5 THEN 'Pending'
        WHEN 6 THEN 'Ended Normally'
        ELSE 'Unknown'
    END,
    start_time,
    end_time
FROM [catalog].[executions] 
WHERE execution_id = @execution_id;
GO

-- =============================================
-- 7. 异步执行SSIS包
-- =============================================

USE SSISDB;
GO

DECLARE @execution_id BIGINT;

EXEC [catalog].[create_execution] 
    @package_name = 'DataSync.dtsx',
    @execution_id = @execution_id OUTPUT,
    @folder_name = 'ART_CONTEST_Integration',
    @project_name = 'ART_CONTEST_Integration_Project',
    @use32bitruntime = FALSE,
    @reference_id = NULL;

EXEC [catalog].[start_execution] @execution_id;

PRINT 'SSIS包已启动，执行ID: ' + CAST(@execution_id AS VARCHAR);
GO

-- =============================================
-- 8. 查询SSIS执行历史
-- =============================================

USE SSISDB;
GO

-- 查询最近的执行记录
SELECT TOP 20
    execution_id,
    package_name,
    status,
    status_desc = CASE status 
        WHEN 1 THEN 'Created'
        WHEN 2 THEN 'Running'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'Failed'
        WHEN 5 THEN 'Pending'
        WHEN 6 THEN 'Ended Normally'
        ELSE 'Unknown'
    END,
    start_time,
    end_time,
    elapsed_time = DATEDIFF(SECOND, start_time, end_time),
    created_by_name AS ExecutedBy
FROM [catalog].[executions]
WHERE folder_name = 'ART_CONTEST_Integration'
ORDER BY start_time DESC;
GO

-- 查询失败的执行记录
SELECT 
    execution_id,
    package_name,
    start_time,
    end_time,
    error_message
FROM [catalog].[executions] e
LEFT JOIN [catalog].[execution_messages] em 
    ON e.execution_id = em.execution_id
WHERE e.status = 4 -- Failed
    AND em.message_type = 120 -- Error
ORDER BY e.start_time DESC;
GO

-- =============================================
-- 9. 创建SQL Server Agent作业调度SSIS包
-- =============================================

USE msdb;
GO

-- 创建作业
EXEC dbo.sp_add_job
    @job_name = N'ART_CONTEST_Data_Sync',
    @enabled = 1,
    @description = N'每日数据同步作业';
GO

-- 创建作业步骤
EXEC dbo.sp_add_jobstep
    @job_name = N'ART_CONTEST_Data_Sync',
    @step_name = N'执行SSIS数据同步包',
    @subsystem = N'SSIS',
    @command = N'/ISSERVER "\"\SSISDB\ART_CONTEST_Integration\ART_CONTEST_Integration_Project\DataSync.dtsx\"" /SERVER localhost /ENVREFERENCE 1 /Par "\"$ServerOption::LOGGING_LEVEL(Int32)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True',
    @database_name = N'master';
GO

-- 创建调度（每日凌晨2点执行）
EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily_Data_Sync',
    @freq_type = 4, -- 每天
    @freq_interval = 1,
    @active_start_time = 020000; -- 凌晨2点
GO

-- 关联调度到作业
EXEC dbo.sp_attach_schedule
    @job_name = N'ART_CONTEST_Data_Sync',
    @schedule_name = N'Daily_Data_Sync';
GO

-- =============================================
-- 10. SSIS性能监控
-- =============================================

USE SSISDB;
GO

-- 查询执行统计
SELECT 
    package_name,
    COUNT(*) AS ExecutionCount,
    AVG(DATEDIFF(SECOND, start_time, end_time)) AS AvgDurationSeconds,
    MIN(DATEDIFF(SECOND, start_time, end_time)) AS MinDurationSeconds,
    MAX(DATEDIFF(SECOND, start_time, end_time)) AS MaxDurationSeconds,
    SUM(CASE WHEN status = 4 THEN 1 ELSE 0 END) AS FailureCount
FROM [catalog].[executions]
WHERE folder_name = 'ART_CONTEST_Integration'
GROUP BY package_name;
GO

-- 查询数据流量统计
SELECT 
    execution_id,
    package_name,
    source_name,
    row_count,
    created_time
FROM [catalog].[execution_data_statistics]
WHERE execution_id = @execution_id;
GO

-- =============================================
-- 11. 清理SSIS执行日志
-- =============================================

USE SSISDB;
GO

-- 删除90天前的执行日志
DECLARE @RetentionDays INT = 90;
DECLARE @CutoffDate DATETIME = DATEADD(DAY, -@RetentionDays, GETDATE());

DELETE FROM [catalog].[execution_messages]
WHERE execution_id IN (
    SELECT execution_id 
    FROM [catalog].[executions] 
    WHERE start_time < @CutoffDate
);

DELETE FROM [catalog].[executions]
WHERE start_time < @CutoffDate;

PRINT '已清理 ' + CAST(@@ROWCOUNT AS VARCHAR) + ' 条执行记录';
GO

-- =============================================
-- 12. SSIS包参数化配置
-- =============================================

/*
SSIS包参数化最佳实践：

1. 使用项目参数存储连接字符串
2. 使用环境变量管理不同环境配置
3. 使用配置文件存储敏感信息
4. 在包执行时通过参数覆盖默认值

示例参数配置：
- SourceServer: 源数据库服务器
- TargetServer: 目标数据库服务器
- BatchSize: 批量处理大小
- ErrorThreshold: 错误阈值
- LogLevel: 日志级别
*/