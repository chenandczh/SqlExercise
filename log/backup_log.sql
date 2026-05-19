-- ========================================
-- 事务日志备份脚本（已修复）
-- ========================================
DECLARE @BackupPath VARCHAR(500);
DECLARE @FileName VARCHAR(200);
DECLARE @DateStr VARCHAR(20);
DECLARE @CurrentRecoveryModel VARCHAR(50);

-- 获取当前恢复模式
SELECT @CurrentRecoveryModel = recovery_model_desc 
FROM sys.databases 
WHERE name = 'ART_CONTEST';

-- 如果当前是SIMPLE模式，改为FULL模式
IF @CurrentRecoveryModel = 'SIMPLE'
BEGIN
    PRINT '当前恢复模式为 SIMPLE，正在切换到 FULL 模式...';
    ALTER DATABASE ART_CONTEST SET RECOVERY FULL;
    PRINT '恢复模式已切换为 FULL';
    
    -- 切换到FULL模式后需要先执行一次全量备份作为日志备份的基础
    PRINT '切换到FULL模式后，需要先执行一次全量备份...';
    
    SET @DateStr = CONVERT(VARCHAR(8), GETDATE(), 112) + '_' + 
                   REPLACE(CONVERT(VARCHAR(8), GETDATE(), 108), ':', '');
    SET @FileName = 'ART_CONTEST_FULL_' + @DateStr + '.bak';
    SET @BackupPath = 'D:\SQLBackup\Local\' + @FileName;
    
    BACKUP DATABASE ART_CONTEST 
    TO DISK = @BackupPath 
    WITH 
        INIT,
        COMPRESSION,
        CHECKSUM,
        STATS = 10;
    
    PRINT '初始全量备份完成: ' + @BackupPath;
END

-- 执行事务日志备份
SET @DateStr = CONVERT(VARCHAR(8), GETDATE(), 112) + '_' + 
               REPLACE(CONVERT(VARCHAR(8), GETDATE(), 108), ':', '');
SET @FileName = 'ART_CONTEST_LOG_' + @DateStr + '.trn';
SET @BackupPath = 'D:\SQLBackup\Logs\' + @FileName;

BACKUP LOG ART_CONTEST 
TO DISK = @BackupPath 
WITH 
    INIT,
    COMPRESSION,
    CHECKSUM,
    STATS = 10;

PRINT '事务日志备份成功: ' + @BackupPath;