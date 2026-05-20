/*
SQL Server 高可用性方案实施脚本
================================
文件：high_availability_scripts.sql
版本：V1.0
日期：2026年5月

包含：
1. 备份与恢复脚本
2. 日志传送配置脚本
3. AlwaysOn可用性组配置脚本
4. 故障转移集群相关脚本
5. 监控与维护脚本
*/

-- ========================================
-- 1. 备份与恢复脚本
-- ========================================
PRINT '========== 1. 备份与恢复脚本 ==========';
GO

-- 1.1 创建备份目录（如果不存在）
EXEC master.dbo.xp_create_subdir 'D:\SQLBackup\Full';
EXEC master.dbo.xp_create_subdir 'D:\SQLBackup\Diff';
EXEC master.dbo.xp_create_subdir 'D:\SQLBackup\Log';
PRINT '备份目录创建完成';
GO

-- 1.2 完整备份脚本
CREATE PROCEDURE dbo.sp_Backup_Full
    @DatabaseName VARCHAR(100) = 'ART_CONTEST',
    @BackupPath VARCHAR(255) = 'D:\SQLBackup\Full\'
AS
BEGIN
    DECLARE @FileName VARCHAR(255);
    SET @FileName = @BackupPath + @DatabaseName + '_FULL_' + 
                    REPLACE(REPLACE(CONVERT(VARCHAR, GETDATE(), 120), ':', '-'), ' ', '_') + '.bak';
    
    BACKUP DATABASE @DatabaseName
    TO DISK = @FileName
    WITH 
        INIT,
        COMPRESSION,
        STATS = 10,
        DESCRIPTION = '完整备份 - ' + @DatabaseName;
    
    PRINT '完整备份完成: ' + @FileName;
END
GO

-- 1.3 差异备份脚本
CREATE PROCEDURE dbo.sp_Backup_Diff
    @DatabaseName VARCHAR(100) = 'ART_CONTEST',
    @BackupPath VARCHAR(255) = 'D:\SQLBackup\Diff\'
AS
BEGIN
    DECLARE @FileName VARCHAR(255);
    SET @FileName = @BackupPath + @DatabaseName + '_DIFF_' + 
                    REPLACE(REPLACE(CONVERT(VARCHAR, GETDATE(), 120), ':', '-'), ' ', '_') + '.bak';
    
    BACKUP DATABASE @DatabaseName
    TO DISK = @FileName
    WITH 
        DIFFERENTIAL,
        COMPRESSION,
        STATS = 10,
        DESCRIPTION = '差异备份 - ' + @DatabaseName;
    
    PRINT '差异备份完成: ' + @FileName;
END
GO

-- 1.4 事务日志备份脚本
CREATE PROCEDURE dbo.sp_Backup_Log
    @DatabaseName VARCHAR(100) = 'ART_CONTEST',
    @BackupPath VARCHAR(255) = 'D:\SQLBackup\Log\'
AS
BEGIN
    DECLARE @FileName VARCHAR(255);
    SET @FileName = @BackupPath + @DatabaseName + '_LOG_' + 
                    REPLACE(REPLACE(CONVERT(VARCHAR, GETDATE(), 120), ':', '-'), ' ', '_') + '.trn';
    
    BACKUP LOG @DatabaseName
    TO DISK = @FileName
    WITH 
        COMPRESSION,
        STATS = 10,
        DESCRIPTION = '事务日志备份 - ' + @DatabaseName;
    
    PRINT '日志备份完成: ' + @FileName;
END
GO

-- 1.5 恢复脚本
CREATE PROCEDURE dbo.sp_Restore_Database
    @DatabaseName VARCHAR(100),
    @FullBackupPath VARCHAR(255),
    @DiffBackupPath VARCHAR(255) = NULL,
    @LogBackupPath VARCHAR(255) = NULL
AS
BEGIN
    -- 恢复完整备份
    RESTORE DATABASE @DatabaseName
    FROM DISK = @FullBackupPath
    WITH 
        NORECOVERY,
        REPLACE,
        STATS = 10;
    
    PRINT '完整备份恢复完成';
    
    -- 恢复差异备份（如果提供）
    IF @DiffBackupPath IS NOT NULL
    BEGIN
        RESTORE DATABASE @DatabaseName
        FROM DISK = @DiffBackupPath
        WITH NORECOVERY,
             STATS = 10;
        PRINT '差异备份恢复完成';
    END
    
    -- 恢复事务日志（如果提供）
    IF @LogBackupPath IS NOT NULL
    BEGIN
        RESTORE LOG @DatabaseName
        FROM DISK = @LogBackupPath
        WITH RECOVERY,
             STATS = 10;
        PRINT '事务日志恢复完成';
    END
    ELSE
    BEGIN
        RESTORE DATABASE @DatabaseName WITH RECOVERY;
        PRINT '数据库恢复完成（无日志备份）';
    END
END
GO

-- ========================================
-- 2. 日志传送配置脚本
-- ========================================
PRINT '========== 2. 日志传送配置脚本 ==========';
GO

-- 2.1 主服务器配置
CREATE PROCEDURE dbo.sp_Configure_LogShipping_Primary
    @DatabaseName VARCHAR(100) = 'ART_CONTEST',
    @BackupDirectory VARCHAR(255) = 'D:\SQLBackup\LogShipping',
    @BackupShare VARCHAR(255) = '\\PRIMARY\LogShipping',
    @RetentionPeriod INT = 720,  -- 30天
    @MonitorServer VARCHAR(100) = NULL
AS
BEGIN
    -- 创建备份目录
    EXEC master.dbo.xp_create_subdir @BackupDirectory;
    
    -- 启用日志传送
    DECLARE @BackupJobId UNIQUEIDENTIFIER;
    
    EXEC sp_add_log_shipping_primary_database
        @database = @DatabaseName,
        @backup_directory = @BackupDirectory,
        @backup_share = @BackupShare,
        @backup_job_name = N'LSBackup_' + @DatabaseName,
        @backup_retention_period = @RetentionPeriod,
        @monitor_server = @MonitorServer,
        @monitor_server_security_mode = 1,
        @backup_job_id = @BackupJobId OUTPUT;
    
    -- 启动备份作业
    EXEC msdb.dbo.sp_start_job @job_name = N'LSBackup_' + @DatabaseName;
    
    PRINT '日志传送主服务器配置完成';
END
GO

-- 2.2 辅助服务器配置
CREATE PROCEDURE dbo.sp_Configure_LogShipping_Secondary
    @PrimaryServer VARCHAR(100),
    @DatabaseName VARCHAR(100) = 'ART_CONTEST',
    @BackupSourceDir VARCHAR(255) = '\\PRIMARY\LogShipping',
    @BackupDestDir VARCHAR(255) = 'D:\SQLBackup\LogShipping',
    @MonitorServer VARCHAR(100) = NULL,
    @RestoreMode INT = 1  -- 1=NORECOVERY, 2=STANDBY
AS
BEGIN
    -- 创建目标目录
    EXEC master.dbo.xp_create_subdir @BackupDestDir;
    
    -- 添加辅助数据库
    DECLARE @RestoreJobId UNIQUEIDENTIFIER;
    
    EXEC sp_add_log_shipping_secondary_primary
        @primary_server = @PrimaryServer,
        @primary_database = @DatabaseName,
        @backup_source_directory = @BackupSourceDir,
        @backup_destination_directory = @BackupDestDir,
        @secondary_database = @DatabaseName,
        @restore_job_name = N'LSRestore_' + @DatabaseName,
        @monitor_server = @MonitorServer,
        @monitor_server_security_mode = 1,
        @restore_job_id = @RestoreJobId OUTPUT;
    
    -- 配置辅助数据库恢复模式
    EXEC sp_add_log_shipping_secondary_database
        @secondary_database = @DatabaseName,
        @restore_delay = 0,
        @restore_mode = @RestoreMode,
        @disconnect_users = 1;
    
    -- 启动恢复作业
    EXEC msdb.dbo.sp_start_job @job_name = N'LSRestore_' + @DatabaseName;
    
    PRINT '日志传送辅助服务器配置完成';
END
GO

-- ========================================
-- 3. AlwaysOn可用性组配置脚本
-- ========================================
PRINT '========== 3. AlwaysOn可用性组配置脚本 ==========';
GO

-- 3.1 创建端点
CREATE PROCEDURE dbo.sp_Create_AG_Endpoint
    @EndpointName VARCHAR(100) = 'Hadr_endpoint',
    @Port INT = 5022,
    @IPAddress VARCHAR(50) = '0.0.0.0'
AS
BEGIN
    -- 检查端点是否已存在
    IF NOT EXISTS (SELECT * FROM sys.endpoints WHERE name = @EndpointName)
    BEGIN
        CREATE ENDPOINT [@EndpointName]
            STATE = STARTED
            AS TCP (LISTENER_PORT = @Port, LISTENER_IP = @IPAddress)
            FOR DATA_MIRRORING (
                ROLE = ALL,
                AUTHENTICATION = WINDOWS NEGOTIATE,
                ENCRYPTION = REQUIRED ALGORITHM AES
            );
        
        -- 授予连接权限
        GRANT CONNECT ON ENDPOINT::[@EndpointName] TO [PUBLIC];
        
        PRINT 'AlwaysOn端点创建完成: ' + @EndpointName;
    END
    ELSE
    BEGIN
        PRINT '端点已存在: ' + @EndpointName;
    END
END
GO

-- 3.2 创建可用性组
CREATE PROCEDURE dbo.sp_Create_Availability_Group
    @AGName VARCHAR(100) = 'AG_ART_CONTEST',
    @DatabaseName VARCHAR(100) = 'ART_CONTEST',
    @PrimaryReplica VARCHAR(100),
    @SecondaryReplica VARCHAR(100),
    @ListenerName VARCHAR(100) = 'AGListener',
    @ListenerIP VARCHAR(50) = '192.168.1.100',
    @ListenerPort INT = 1433
AS
BEGIN
    -- 创建可用性组
    DECLARE @SQL NVARCHAR(MAX);
    
    SET @SQL = N'CREATE AVAILABILITY GROUP [' + @AGName + N']
    WITH (AUTOMATED_BACKUP_PREFERENCE = SECONDARY)
    FOR DATABASE [' + @DatabaseName + N']
    REPLICA ON 
        N''' + @PrimaryReplica + N''' WITH (
            ENDPOINT_URL = N''TCP://' + @PrimaryReplica + N':' + CAST(@Port AS VARCHAR) + N''',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
            FAILOVER_MODE = AUTOMATIC,
            SEEDING_MODE = AUTOMATIC,
            BACKUP_PRIORITY = 50,
            SECONDARY_ROLE(ALLOW_CONNECTIONS = NO)
        ),
        N''' + @SecondaryReplica + N''' WITH (
            ENDPOINT_URL = N''TCP://' + @SecondaryReplica + N':' + CAST(@Port AS VARCHAR) + N''',
            AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
            FAILOVER_MODE = AUTOMATIC,
            SEEDING_MODE = AUTOMATIC,
            BACKUP_PRIORITY = 50,
            SECONDARY_ROLE(ALLOW_CONNECTIONS = READ_ONLY, READ_ONLY_ROUTING_URL = N''TCP://' + @SecondaryReplica + N':1433'')
        );';
    
    EXEC sp_executesql @SQL;
    
    -- 创建侦听器
    SET @SQL = N'ALTER AVAILABILITY GROUP [' + @AGName + N']
    ADD LISTENER N''' + @ListenerName + N''' (
        WITH IP (
            (N''' + @ListenerIP + N''', N''255.255.255.0'')
        ),
        PORT = ' + CAST(@ListenerPort AS VARCHAR) + N'
    );';
    
    EXEC sp_executesql @SQL;
    
    PRINT '可用性组创建完成: ' + @AGName;
END
GO

-- 3.3 添加只读路由
CREATE PROCEDURE dbo.sp_Configure_Readonly_Routing
    @AGName VARCHAR(100) = 'AG_ART_CONTEST',
    @PrimaryReplica VARCHAR(100),
    @SecondaryReplica VARCHAR(100)
AS
BEGIN
    -- 配置只读路由URL
    DECLARE @SQL NVARCHAR(MAX);
    
    SET @SQL = N'ALTER AVAILABILITY GROUP [' + @AGName + N']
    MODIFY REPLICA ON N''' + @SecondaryReplica + N''' WITH 
    (READ_ONLY_ROUTING_URL = N''TCP://' + @SecondaryReplica + N':1433'');';
    
    EXEC sp_executesql @SQL;
    
    -- 添加只读路由列表
    SET @SQL = N'ALTER AVAILABILITY GROUP [' + @AGName + N']
    ADD READ_ONLY_ROUTING LIST FOR REPLICA N''' + @PrimaryReplica + N''' 
    ((N''' + @SecondaryReplica + N'''));';
    
    EXEC sp_executesql @SQL;
    
    PRINT '只读路由配置完成';
END
GO

-- 3.4 手动故障转移
CREATE PROCEDURE dbo.sp_Failover_AlwaysOn
    @AGName VARCHAR(100) = 'AG_ART_CONTEST',
    @ForceFailover BIT = 0
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX);
    
    IF @ForceFailover = 1
    BEGIN
        -- 强制故障转移（可能丢失数据）
        SET @SQL = N'ALTER AVAILABILITY GROUP [' + @AGName + N'] FORCE_FAILOVER_ALLOW_DATA_LOSS;';
        PRINT '执行强制故障转移...';
    END
    ELSE
    BEGIN
        -- 正常故障转移
        SET @SQL = N'ALTER AVAILABILITY GROUP [' + @AGName + N'] FAILOVER;';
        PRINT '执行正常故障转移...';
    END
    
    EXEC sp_executesql @SQL;
    PRINT '故障转移完成';
END
GO

-- ========================================
-- 4. 监控脚本
-- ========================================
PRINT '========== 4. 监控脚本 ==========';
GO

-- 4.1 检查数据库状态
CREATE VIEW dbo.v_Database_Status
AS
SELECT 
    name AS DatabaseName,
    state_desc AS State,
    recovery_model_desc AS RecoveryModel,
    compatibility_level AS CompatibilityLevel,
    create_date AS CreateDate
FROM sys.databases;
GO

-- 4.2 检查备份状态
CREATE VIEW dbo.v_Backup_Status
AS
SELECT 
    database_name AS DatabaseName,
    MAX(CASE WHEN type = 'D' THEN backup_finish_date END) AS LastFullBackup,
    MAX(CASE WHEN type = 'I' THEN backup_finish_date END) AS LastDiffBackup,
    MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS LastLogBackup
FROM msdb.dbo.backupset
GROUP BY database_name;
GO

-- 4.3 检查AlwaysOn状态
CREATE VIEW dbo.v_AlwaysOn_Status
AS
SELECT 
    ag.name AS AG_Name,
    ar.replica_server_name,
    ar.availability_mode_desc,
    ar.failover_mode_desc,
    rs.role_desc,
    rs.synchronization_health_desc,
    rs.last_connect_error_description
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
LEFT JOIN sys.dm_hadr_availability_replica_states rs ON ar.replica_id = rs.replica_id;
GO

-- 4.4 检查日志传送状态
CREATE VIEW dbo.v_LogShipping_Status
AS
SELECT 
    p.primary_database,
    p.last_backup_date,
    p.backup_retention_period,
    s.last_restored_date,
    DATEDIFF(MINUTE, p.last_backup_date, s.last_restored_date) AS LatencyMinutes
FROM msdb.dbo.log_shipping_monitor_primary p
LEFT JOIN msdb.dbo.log_shipping_monitor_secondary s ON p.primary_id = s.primary_id;
GO

-- 4.5 检查磁盘空间
CREATE VIEW dbo.v_Disk_Space
AS
SELECT 
    drive_letter,
    total_mb,
    free_mb,
    CAST(free_mb * 100.0 / total_mb AS DECIMAL(5,2)) AS FreePercent
FROM (
    SELECT 
        LEFT(physical_name, 1) AS drive_letter,
        SUM(size * 8 / 1024) AS total_mb,
        SUM(FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024) AS used_mb,
        SUM(size * 8 / 1024) - SUM(FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024) AS free_mb
    FROM sys.master_files
    GROUP BY LEFT(physical_name, 1)
) AS DiskStats;
GO

-- ========================================
-- 5. 维护脚本
-- ========================================
PRINT '========== 5. 维护脚本 ==========';
GO

-- 5.1 重建索引
CREATE PROCEDURE dbo.sp_Reindex_Database
    @DatabaseName VARCHAR(100) = 'ART_CONTEST'
AS
BEGIN
    DECLARE @TableName VARCHAR(100);
    DECLARE @SQL NVARCHAR(MAX);
    
    DECLARE TableCursor CURSOR FOR
    SELECT name FROM sys.tables WHERE type = 'U';
    
    OPEN TableCursor;
    FETCH NEXT FROM TableCursor INTO @TableName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = N'ALTER INDEX ALL ON [' + @TableName + N'] REBUILD WITH (ONLINE = ON, COMPRESSION_DELAY = 0);';
        EXEC sp_executesql @SQL;
        PRINT '重建索引完成: ' + @TableName;
        
        FETCH NEXT FROM TableCursor INTO @TableName;
    END
    
    CLOSE TableCursor;
    DEALLOCATE TableCursor;
    
    PRINT '所有索引重建完成';
END
GO

-- 5.2 更新统计信息
CREATE PROCEDURE dbo.sp_Update_Statistics
    @DatabaseName VARCHAR(100) = 'ART_CONTEST'
AS
BEGIN
    EXEC sp_updatestats;
    PRINT '统计信息更新完成';
END
GO

-- 5.3 清理旧备份
CREATE PROCEDURE dbo.sp_Cleanup_Old_Backups
    @BackupPath VARCHAR(255) = 'D:\SQLBackup',
    @RetentionDays INT = 30
AS
BEGIN
    DECLARE @DeleteDate DATETIME;
    SET @DeleteDate = DATEADD(DAY, -@RetentionDays, GETDATE());
    
    -- 删除旧的完整备份
    EXEC master.dbo.xp_delete_file 0, @BackupPath + '\Full', 'bak', @DeleteDate, 0;
    
    -- 删除旧的差异备份
    EXEC master.dbo.xp_delete_file 0, @BackupPath + '\Diff', 'bak', @DeleteDate, 0;
    
    -- 删除旧的日志备份
    EXEC master.dbo.xp_delete_file 0, @BackupPath + '\Log', 'trn', @DeleteDate, 0;
    
    PRINT '旧备份清理完成（保留最近' + CAST(@RetentionDays AS VARCHAR) + '天）';
END
GO

-- ========================================
-- 6. 执行示例
-- ========================================
PRINT '========== 6. 执行示例 ==========';
GO

-- 示例1：执行完整备份
-- EXEC dbo.sp_Backup_Full 'ART_CONTEST';

-- 示例2：检查数据库状态
-- SELECT * FROM dbo.v_Database_Status;

-- 示例3：检查AlwaysOn状态
-- SELECT * FROM dbo.v_AlwaysOn_Status;

-- 示例4：检查磁盘空间
-- SELECT * FROM dbo.v_Disk_Space;

PRINT '========== 脚本创建完成 ==========';
GO