-- =============================================
-- 审计追踪(Audit Tracking) SQL脚本
-- =============================================

-- =============================================
-- 1. 创建SQL Server审计对象
-- =============================================

-- 创建审计文件目标
CREATE SERVER AUDIT [ART_CONTEST_Server_Audit]
TO FILE 
(
    FILEPATH = 'D:\SQLAudit\',
    MAXSIZE = 1024 MB,
    MAX_FILES = 100,
    RESERVE_DISK_SPACE = ON
)
WITH 
(
    QUEUE_DELAY = 1000,
    ON_FAILURE = CONTINUE,
    AUDIT_GUID = 'A1B2C3D4-E5F6-7890-ABCD-EFGHIJKLMNOP'
);
GO

-- 启用审计
ALTER SERVER AUDIT [ART_CONTEST_Server_Audit] WITH (STATE = ON);
GO

-- =============================================
-- 2. 创建服务器级审计规范
-- =============================================

CREATE SERVER AUDIT SPECIFICATION [ART_CONTEST_Server_Audit_Specification]
FOR SERVER AUDIT [ART_CONTEST_Server_Audit]
ADD (SUCCESSFUL_LOGIN_GROUP),
ADD (FAILED_LOGIN_GROUP),
ADD (SERVER_ROLE_MEMBER_CHANGE_GROUP),
ADD (LOGIN_CHANGE_PASSWORD_GROUP),
ADD (LOGIN_CREATE_GROUP),
ADD (LOGIN_DROP_GROUP),
ADD (SERVER_PERMISSION_CHANGE_GROUP),
ADD (SERVER_PRINCIPAL_CHANGE_GROUP);
GO

-- 启用服务器审计规范
ALTER SERVER AUDIT SPECIFICATION [ART_CONTEST_Server_Audit_Specification] WITH (STATE = ON);
GO

-- =============================================
-- 3. 创建数据库级审计规范
-- =============================================

USE ART_CONTEST;
GO

CREATE DATABASE AUDIT SPECIFICATION [ART_CONTEST_Database_Audit_Specification]
FOR SERVER AUDIT [ART_CONTEST_Server_Audit]
ADD (SELECT ON SCHEMA::dbo BY public),
ADD (INSERT ON SCHEMA::dbo BY public),
ADD (UPDATE ON SCHEMA::dbo BY public),
ADD (DELETE ON SCHEMA::dbo BY public),
ADD (EXECUTE ON SCHEMA::dbo BY public),
ADD (ALTER ON SCHEMA::dbo BY public),
ADD (CREATE TABLE ON SCHEMA::dbo BY public),
ADD (DROP TABLE ON SCHEMA::dbo BY public),
ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP),
ADD (DATABASE_PERMISSION_CHANGE_GROUP),
ADD (DATABASE_PRINCIPAL_CHANGE_GROUP);
GO

-- 启用数据库审计规范
ALTER DATABASE AUDIT SPECIFICATION [ART_CONTEST_Database_Audit_Specification] WITH (STATE = ON);
GO

-- =============================================
-- 4. 查询审计日志
-- =============================================

-- 查询服务器审计日志
SELECT 
    event_time AS EventTime,
    action_id AS ActionID,
    succeeded AS Succeeded,
    session_server_principal_name AS UserName,
    session_id AS SessionID,
    server_principal_name AS ServerPrincipal,
    database_name AS DatabaseName,
    object_name AS ObjectName,
    statement AS Statement,
    file_name AS AuditFileName,
    audit_file_offset AS Offset
FROM sys.fn_get_audit_file('D:\SQLAudit\ART_CONTEST_Server_Audit_*.sqlaudit', DEFAULT, DEFAULT)
ORDER BY event_time DESC;
GO

-- 查询失败的登录尝试
SELECT 
    event_time AS EventTime,
    session_server_principal_name AS UserName,
    action_id AS ActionID,
    succeeded AS Succeeded,
    session_id AS SessionID
FROM sys.fn_get_audit_file('D:\SQLAudit\ART_CONTEST_Server_Audit_*.sqlaudit', DEFAULT, DEFAULT)
WHERE action_id = 'LGIF' -- 登录失败
ORDER BY event_time DESC;
GO

-- 查询权限变更
SELECT 
    event_time AS EventTime,
    action_id AS ActionID,
    session_server_principal_name AS UserName,
    object_name AS ObjectName,
    statement AS Statement
FROM sys.fn_get_audit_file('D:\SQLAudit\ART_CONTEST_Server_Audit_*.sqlaudit', DEFAULT, DEFAULT)
WHERE action_id IN ('GRT', 'DEN', 'REV') -- 授予、拒绝、回收权限
ORDER BY event_time DESC;
GO

-- =============================================
-- 5. 创建自定义审计表和存储过程
-- =============================================

USE ART_CONTEST;
GO

-- 创建自定义审计日志表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AuditLog')
BEGIN
    CREATE TABLE [dbo].[AuditLog] (
        [AuditID] BIGINT PRIMARY KEY IDENTITY(1,1),
        [EventTime] DATETIME NOT NULL DEFAULT GETDATE(),
        [EventType] NVARCHAR(50) NOT NULL,
        [UserName] NVARCHAR(128) NOT NULL,
        [DatabaseName] NVARCHAR(128) NOT NULL,
        [SchemaName] NVARCHAR(128),
        [ObjectName] NVARCHAR(128),
        [Action] NVARCHAR(50) NOT NULL,
        [Statement] NVARCHAR(MAX),
        [Success] BIT NOT NULL,
        [ErrorMessage] NVARCHAR(MAX),
        [ClientIP] NVARCHAR(50),
        [ApplicationName] NVARCHAR(128),
        [HostName] NVARCHAR(128)
    );
END
GO

-- 创建索引
CREATE INDEX IX_AuditLog_EventTime ON [dbo].[AuditLog](EventTime);
CREATE INDEX IX_AuditLog_UserName ON [dbo].[AuditLog](UserName);
CREATE INDEX IX_AuditLog_EventType ON [dbo].[AuditLog](EventType);
GO

-- 创建审计存储过程
CREATE OR ALTER PROCEDURE [dbo].[sp_LogAuditEvent]
    @EventType NVARCHAR(50),
    @UserName NVARCHAR(128),
    @DatabaseName NVARCHAR(128),
    @SchemaName NVARCHAR(128) = NULL,
    @ObjectName NVARCHAR(128) = NULL,
    @Action NVARCHAR(50),
    @Statement NVARCHAR(MAX) = NULL,
    @Success BIT,
    @ErrorMessage NVARCHAR(MAX) = NULL,
    @ClientIP NVARCHAR(50) = NULL,
    @ApplicationName NVARCHAR(128) = NULL,
    @HostName NVARCHAR(128) = NULL
AS
BEGIN
    INSERT INTO [dbo].[AuditLog] (
        EventType,
        UserName,
        DatabaseName,
        SchemaName,
        ObjectName,
        Action,
        Statement,
        Success,
        ErrorMessage,
        ClientIP,
        ApplicationName,
        HostName
    )
    VALUES (
        @EventType,
        @UserName,
        @DatabaseName,
        @SchemaName,
        @ObjectName,
        @Action,
        @Statement,
        @Success,
        @ErrorMessage,
        @ClientIP,
        @ApplicationName,
        @HostName
    );
END
GO

-- =============================================
-- 6. 使用触发器进行审计
-- =============================================

-- 创建表级审计触发器（示例：Artworks表）
CREATE OR ALTER TRIGGER [trg_Artworks_Audit]
ON [dbo].[Artworks]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Action NVARCHAR(50);
    DECLARE @UserName NVARCHAR(128) = SUSER_SNAME();
    DECLARE @HostName NVARCHAR(128) = HOST_NAME();
    DECLARE @AppName NVARCHAR(128) = APP_NAME();
    
    IF EXISTS (SELECT * FROM inserted) AND EXISTS (SELECT * FROM deleted)
    BEGIN
        SET @Action = 'UPDATE';
    END
    ELSE IF EXISTS (SELECT * FROM inserted)
    BEGIN
        SET @Action = 'INSERT';
    END
    ELSE
    BEGIN
        SET @Action = 'DELETE';
    END
    
    -- 记录审计日志
    EXEC [dbo].[sp_LogAuditEvent]
        @EventType = 'DATA_MODIFICATION',
        @UserName = @UserName,
        @DatabaseName = 'ART_CONTEST',
        @SchemaName = 'dbo',
        @ObjectName = 'Artworks',
        @Action = @Action,
        @Statement = NULL,
        @Success = 1,
        @ErrorMessage = NULL,
        @ClientIP = NULL,
        @ApplicationName = @AppName,
        @HostName = @HostName;
END
GO

-- =============================================
-- 7. 使用扩展事件进行高级审计
-- =============================================

-- 创建扩展事件会话
IF NOT EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'ART_CONTEST_Audit_Session')
BEGIN
    CREATE EVENT SESSION [ART_CONTEST_Audit_Session] ON SERVER 
    ADD EVENT sqlserver.sql_statement_completed(
        ACTION(sqlserver.sql_text, sqlserver.session_id, sqlserver.username)
        WHERE (sqlserver.database_name = 'ART_CONTEST')),
    ADD EVENT sqlserver.login(
        ACTION(sqlserver.session_id, sqlserver.username, sqlserver.client_app_name)),
    ADD EVENT sqlserver.logout(
        ACTION(sqlserver.session_id, sqlserver.username)),
    ADD EVENT sqlserver.permission_change(
        ACTION(sqlserver.sql_text, sqlserver.session_id, sqlserver.username))
    ADD TARGET package0.event_file(SET filename=N'D:\SQLExtendedEvents\ART_CONTEST_Audit_Session.xel')
    WITH (STARTUP_STATE=ON);
END
GO

-- 启动扩展事件会话
ALTER EVENT SESSION [ART_CONTEST_Audit_Session] ON SERVER STATE = START;
GO

-- 查询扩展事件日志
SELECT 
    event_data.value('(event/@name)[1]', 'varchar(50)') AS EventName,
    event_data.value('(event/@timestamp)[1]', 'datetime') AS EventTime,
    event_data.value('(event/action[@name="username"]/value)[1]', 'varchar(128)') AS UserName,
    event_data.value('(event/action[@name="session_id"]/value)[1]', 'int') AS SessionID,
    event_data.value('(event/action[@name="sql_text"]/value)[1]', 'varchar(max)') AS SQLText
FROM 
    (SELECT CAST(event_data AS XML) AS event_data
     FROM sys.fn_xe_file_target_read_file('D:\SQLExtendedEvents\ART_CONTEST_Audit_Session_*.xel', NULL, NULL, NULL)) AS x
ORDER BY EventTime DESC;
GO

-- =============================================
-- 8. 定期清理审计日志
-- =============================================

-- 创建清理存储过程
CREATE OR ALTER PROCEDURE [dbo].[sp_CleanupAuditLog]
    @RetentionDays INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CutoffDate DATETIME = DATEADD(DAY, -@RetentionDays, GETDATE());
    
    -- 清理自定义审计日志
    DELETE FROM [dbo].[AuditLog]
    WHERE EventTime < @CutoffDate;
    
    PRINT '已清理 ' + CAST(@@ROWCOUNT AS VARCHAR) + ' 条审计记录';
END
GO

-- 创建SQL Server Agent作业定期清理（需要启用SQL Server Agent）
/*
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'Cleanup Audit Log',
    @enabled = 1,
    @description = N'定期清理90天前的审计日志';
GO

EXEC dbo.sp_add_jobstep
    @job_name = N'Cleanup Audit Log',
    @step_name = N'清理审计日志',
    @subsystem = N'TSQL',
    @command = N'EXEC ART_CONTEST.dbo.sp_CleanupAuditLog @RetentionDays = 90;',
    @database_name = N'ART_CONTEST';
GO

EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily_Audit_Cleanup',
    @freq_type = 4, -- 每天
    @freq_interval = 1,
    @active_start_time = 020000; -- 凌晨2点
GO

EXEC dbo.sp_attach_schedule
    @job_name = N'Cleanup Audit Log',
    @schedule_name = N'Daily_Audit_Cleanup';
GO
*/

-- =============================================
-- 9. 审计报告查询
-- =============================================

-- 登录统计报告
SELECT 
    UserName,
    COUNT(*) AS LoginCount,
    MIN(EventTime) AS FirstLogin,
    MAX(EventTime) AS LastLogin
FROM [dbo].[AuditLog]
WHERE EventType = 'LOGIN'
GROUP BY UserName
ORDER BY LoginCount DESC;
GO

-- 数据修改统计
SELECT 
    ObjectName,
    Action,
    COUNT(*) AS ActionCount
FROM [dbo].[AuditLog]
WHERE EventType = 'DATA_MODIFICATION'
GROUP BY ObjectName, Action
ORDER BY ObjectName, Action;
GO

-- 失败操作报告
SELECT 
    EventTime,
    UserName,
    ObjectName,
    Action,
    ErrorMessage
FROM [dbo].[AuditLog]
WHERE Success = 0
ORDER BY EventTime DESC;
GO

-- =============================================
-- 10. 管理审计配置
-- =============================================

-- 查看审计状态
SELECT 
    name AS AuditName,
    status_desc AS Status,
    audit_file_path AS FilePath,
    max_size AS MaxSize,
    max_files AS MaxFiles,
    create_date AS CreateDate
FROM sys.server_audits;
GO

-- 查看服务器审计规范
SELECT 
    name AS SpecificationName,
    status_desc AS Status,
    audit_name AS AuditName,
    create_date AS CreateDate
FROM sys.server_audit_specifications;
GO

-- 查看数据库审计规范
SELECT 
    name AS SpecificationName,
    status_desc AS Status,
    audit_name AS AuditName,
    create_date AS CreateDate
FROM sys.database_audit_specifications;
GO

-- 禁用审计（谨慎操作）
-- ALTER SERVER AUDIT [ART_CONTEST_Server_Audit] WITH (STATE = OFF);
-- GO

-- 删除审计（谨慎操作）
-- DROP SERVER AUDIT [ART_CONTEST_Server_Audit];
-- GO

-- =============================================
-- 11. 告警查询示例
-- =============================================

-- 查询暴力破解尝试（5分钟内10次失败登录）
WITH FailedLogins AS (
    SELECT 
        event_time,
        session_server_principal_name AS UserName,
        DATEADD(MINUTE, DATEDIFF(MINUTE, 0, event_time), 0) AS MinuteBucket
    FROM sys.fn_get_audit_file('D:\SQLAudit\ART_CONTEST_Server_Audit_*.sqlaudit', DEFAULT, DEFAULT)
    WHERE action_id = 'LGIF' -- 登录失败
)
SELECT 
    UserName,
    MinuteBucket,
    COUNT(*) AS FailedAttempts
FROM FailedLogins
GROUP BY UserName, MinuteBucket
HAVING COUNT(*) >= 10
ORDER BY MinuteBucket DESC;
GO