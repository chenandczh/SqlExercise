-- ========================================
-- 数据库备份与日志管理 - 配套SQL脚本
-- 文件位置: D:\SQLBackup\Scripts\
-- ========================================

-- ========================================
-- 1. 备份历史表
-- ========================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'BackupHistory')
BEGIN
    CREATE TABLE dbo.BackupHistory (
        BackupHistoryId INT IDENTITY(1,1) PRIMARY KEY,
        BackupType VARCHAR(20) NOT NULL,
        BackupPath VARCHAR(500) NOT NULL,
        BackupSizeMB DECIMAL(10,2) NOT NULL,
        BackupDate DATETIME NOT NULL DEFAULT GETDATE(),
        VerifyStatus BIT NOT NULL DEFAULT 0,
        VerifyDate DATETIME NULL
    );
END
GO

-- ========================================
-- 2. 日志归档表
-- ========================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'LogArchive')
BEGIN
    CREATE TABLE dbo.LogArchive (
        LogArchiveId INT IDENTITY(1,1) PRIMARY KEY,
        LogType VARCHAR(30) NOT NULL,
        OriginalPath VARCHAR(500) NOT NULL,
        ArchivePath VARCHAR(500) NOT NULL,
        FileName VARCHAR(200) NOT NULL,
        FileSizeKB DECIMAL(10,2) NOT NULL,
        Compressed BIT NOT NULL DEFAULT 0,
        ArchiveDate DATETIME NOT NULL DEFAULT GETDATE(),
        RetentionUntil DATE NOT NULL,
        ArchivedBy VARCHAR(50) NOT NULL DEFAULT SUSER_NAME()
    );
END
GO

-- ========================================
-- 3. 备份状态视图
-- ========================================
IF EXISTS (SELECT * FROM sys.views WHERE name = 'v_Backup_Status')
    DROP VIEW v_Backup_Status;
GO

CREATE VIEW v_Backup_Status
AS
SELECT 
    BackupType,
    COUNT(*) AS BackupCount,
    MIN(BackupDate) AS OldestBackup,
    MAX(BackupDate) AS LatestBackup,
    SUM(BackupSizeMB) AS TotalSizeMB,
    AVG(CASE WHEN VerifyStatus = 1 THEN 1.0 ELSE 0.0 END) * 100 AS VerifyRatePercent
FROM dbo.BackupHistory
GROUP BY BackupType;
GO

-- ========================================
-- 4. 全量备份脚本 (Backup_Full.sql)
-- ========================================
PRINT '=== 开始全量备份 ===';

DECLARE @BackupPath VARCHAR(500);
DECLARE @FileName VARCHAR(200);
DECLARE @DateStr VARCHAR(20);
DECLARE @BackupSizeMB DECIMAL(10,2);

SET @DateStr = CONVERT(VARCHAR(8), GETDATE(), 112) + '_' + 
               REPLACE(CONVERT(VARCHAR(8), GETDATE(), 108), ':', '');
SET @FileName = 'ART_CONTEST_FULL_' + @DateStr + '.bak';
SET @BackupPath = 'D:\SQLBackup\Local\' + @FileName;

SELECT @BackupSizeMB = SUM(size)/128.0 
FROM sys.master_files 
WHERE database_id = DB_ID('ART_CONTEST');

BACKUP DATABASE ART_CONTEST 
TO DISK = @BackupPath 
WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;

RESTORE VERIFYONLY FROM DISK = @BackupPath WITH CHECKSUM;

INSERT INTO dbo.BackupHistory (BackupType, BackupPath, BackupSizeMB, BackupDate, VerifyStatus, VerifyDate)
SELECT 'FULL', @BackupPath, @BackupSizeMB, GETDATE(), 1, GETDATE();

PRINT '全量备份完成: ' + @BackupPath;
GO

-- ========================================
-- 5. 差异备份脚本 (Backup_Diff.sql)
-- ========================================
PRINT '=== 开始差异备份 ===';

DECLARE @BackupPath VARCHAR(500);
DECLARE @FileName VARCHAR(200);
DECLARE @DateStr VARCHAR(20);

SET @DateStr = CONVERT(VARCHAR(8), GETDATE(), 112) + '_' + 
               REPLACE(CONVERT(VARCHAR(8), GETDATE(), 108), ':', '');
SET @FileName = 'ART_CONTEST_DIFF_' + @DateStr + '.bak';
SET @BackupPath = 'D:\SQLBackup\Local\' + @FileName;

BACKUP DATABASE ART_CONTEST 
TO DISK = @BackupPath
WITH DIFFERENTIAL, INIT, COMPRESSION, CHECKSUM, STATS = 10;

INSERT INTO dbo.BackupHistory (BackupType, BackupPath, BackupSizeMB, BackupDate, VerifyStatus)
SELECT 'DIFF', @BackupPath, SUM(size)/128.0, GETDATE(), 0
FROM sys.master_files WHERE database_id = DB_ID('ART_CONTEST');

PRINT '差异备份完成: ' + @BackupPath;
GO

-- ========================================
-- 6. 事务日志备份脚本 (Backup_Log.sql)
-- ========================================
PRINT '=== 开始事务日志备份 ===';

DECLARE @BackupPath VARCHAR(500);
DECLARE @FileName VARCHAR(200);
DECLARE @DateStr VARCHAR(20);
DECLARE @CurrentRecoveryModel VARCHAR(50);

SELECT @CurrentRecoveryModel = recovery_model_desc 
FROM sys.databases WHERE name = 'ART_CONTEST';

IF @CurrentRecoveryModel = 'SIMPLE'
BEGIN
    PRINT '切换到FULL模式并执行初始全量备份...';
    ALTER DATABASE ART_CONTEST SET RECOVERY FULL;
    
    DECLARE @FullBackupPath VARCHAR(500);
    DECLARE @FullFileName VARCHAR(200);
    SET @DateStr = CONVERT(VARCHAR(8), GETDATE(), 112) + '_' + 
                   REPLACE(CONVERT(VARCHAR(8), GETDATE(), 108), ':', '');
    SET @FullFileName = 'ART_CONTEST_FULL_' + @DateStr + '.bak';
    SET @FullBackupPath = 'D:\SQLBackup\Local\' + @FullFileName;
    
    BACKUP DATABASE ART_CONTEST TO DISK = @FullBackupPath WITH INIT, COMPRESSION, CHECKSUM;
    PRINT '初始全量备份完成';
END

SET @DateStr = CONVERT(VARCHAR(8), GETDATE(), 112) + '_' + 
               REPLACE(CONVERT(VARCHAR(8), GETDATE(), 108), ':', '');
SET @FileName = 'ART_CONTEST_LOG_' + @DateStr + '.trn';
SET @BackupPath = 'D:\SQLBackup\Logs\' + @FileName;

BACKUP LOG ART_CONTEST 
TO DISK = @BackupPath 
WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;

INSERT INTO dbo.BackupHistory (BackupType, BackupPath, BackupSizeMB, BackupDate, VerifyStatus)
SELECT 'LOG', @BackupPath, SUM(size)/128.0, GETDATE(), 1
FROM sys.master_files WHERE database_id = DB_ID('ART_CONTEST') AND type = 1;

PRINT '事务日志备份完成: ' + @BackupPath;
GO

-- ========================================
-- 7. 日志清理脚本 (Log_Cleanup.sql)
-- ========================================
PRINT '=== 开始日志清理 ===';

DECLARE @CleanupDate DATETIME;
DECLARE @ArchivePath VARCHAR(500);

-- 1. 清理SQL Server错误日志归档
SET @ArchivePath = 'D:\SQLLogs\Archive\Error\';
SET @CleanupDate = DATEADD(DAY, -90, GETDATE());
EXEC master.dbo.xp_delete_file 0, @ArchivePath, 'log', @CleanupDate, 1;

-- 2. 清理SQL Server Agent日志
SET @ArchivePath = 'D:\SQLLogs\Archive\Agent\';
SET @CleanupDate = DATEADD(DAY, -30, GETDATE());
EXEC master.dbo.xp_delete_file 0, @ArchivePath, 'log', @CleanupDate, 1;

-- 3. 清理跟踪日志
SET @ArchivePath = 'D:\SQLLogs\Trace\';
SET @CleanupDate = DATEADD(DAY, -7, GETDATE());
EXEC master.dbo.xp_delete_file 0, @ArchivePath, 'trc', @CleanupDate, 1;

-- 4. 清理事务日志备份文件
SET @ArchivePath = 'D:\SQLBackup\Logs\';
SET @CleanupDate = DATEADD(DAY, -3, GETDATE());
EXEC master.dbo.xp_delete_file 0, @ArchivePath, 'trn', @CleanupDate, 1;

-- 5. 清理过期的备份文件
SET @ArchivePath = 'D:\SQLBackup\Local\';
SET @CleanupDate = DATEADD(DAY, -28, GETDATE());
EXEC master.dbo.xp_delete_file 0, @ArchivePath, 'bak', @CleanupDate, 1;

PRINT '日志清理完成 - ' + CONVERT(VARCHAR(23), GETDATE(), 121);
GO

-- ========================================
-- 8. 磁盘空间监控脚本 (Disk_Monitor.sql)
-- ========================================
PRINT '=== 磁盘空间监控 ===';

SELECT 
    Drive,
    TotalGB,
    AvailableGB,
    UsedPercent,
    CASE 
        WHEN UsedPercent >= 95 THEN 'CRITICAL'
        WHEN UsedPercent >= 85 THEN 'WARNING'
        ELSE 'NORMAL'
    END AS Status
FROM (
    SELECT 
        volume_mount_point AS Drive,
        CAST(SUM(total_bytes) / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS TotalGB,
        CAST(SUM(available_bytes) / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS AvailableGB,
        CAST((1 - (SUM(available_bytes) * 1.0 / SUM(total_bytes))) * 100 AS DECIMAL(5,2)) AS UsedPercent
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id)
    WHERE volume_mount_point IN ('D:\', 'E:\')
    GROUP BY volume_mount_point
) AS VolumeStats
ORDER BY UsedPercent DESC;
GO

-- ========================================
-- 9. 紧急磁盘清理脚本 (Emergency_Cleanup.sql)
-- ========================================
PRINT '=== 紧急磁盘清理 ===';

DECLARE @CurrentFreeSpaceGB DECIMAL(10,2);

SELECT @CurrentFreeSpaceGB = CAST(available_bytes / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(10,2))
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id)
WHERE volume_mount_point = 'D:\'
GROUP BY volume_mount_point;

PRINT '当前D盘可用空间: ' + CAST(@CurrentFreeSpaceGB AS VARCHAR) + ' GB';

-- 步骤1: 清理最旧的事务日志备份
PRINT '步骤1: 清理最旧的事务日志备份...';
EXEC master.dbo.xp_delete_file 0, 'D:\SQLBackup\Logs\', 'trn', DATEADD(DAY, -1, GETDATE()), 1;

-- 步骤2: 收缩事务日志
PRINT '步骤2: 收缩事务日志...';
DECLARE @LogFileName VARCHAR(100);
SELECT @LogFileName = name FROM sys.master_files WHERE database_id = DB_ID('ART_CONTEST') AND type = 1;
BACKUP LOG ART_CONTEST TO DISK = 'D:\SQLBackup\Logs\EMERGENCY_LOG.trn';
DBCC SHRINKFILE (@LogFileName, 1024);

-- 步骤3: 清理7天前的备份文件
PRINT '步骤3: 清理7天前的备份文件...';
EXEC master.dbo.xp_delete_file 0, 'D:\SQLBackup\Local\', 'bak', DATEADD(DAY, -7, GETDATE()), 1;

-- 步骤4: 清理临时文件
PRINT '步骤4: 清理临时文件...';
EXEC master.dbo.xp_cmdshell 'del /q/f/s %TEMP%\*.tmp > nul 2>&1';

PRINT '紧急清理完成';
GO

PRINT '=== 所有脚本部署完成 ===';
PRINT '';
PRINT '脚本文件清单:';
PRINT '- Backup_Full.sql         (全量备份)';
PRINT '- Backup_Diff.sql         (差异备份)';
PRINT '- Backup_Log.sql         (事务日志备份)';
PRINT '- Log_Cleanup.sql         (日志清理)';
PRINT '- Disk_Monitor.sql        (磁盘空间监控)';
PRINT '- Emergency_Cleanup.sql  (紧急磁盘清理)';
GO