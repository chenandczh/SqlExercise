-- ========================================
-- 全量备份脚本（已修复）
-- ========================================
DECLARE @BackupPath VARCHAR(500);
DECLARE @FileName VARCHAR(200);
DECLARE @DateStr VARCHAR(20);
DECLARE @BackupSizeMB DECIMAL(10,2);

SET @DateStr = CONVERT(VARCHAR(8), GETDATE(), 112) + '_' + 
               REPLACE(CONVERT(VARCHAR(8), GETDATE(), 108), ':', '');
SET @FileName = 'ART_CONTEST_FULL_' + @DateStr + '.bak';
SET @BackupPath = 'D:\SQLBackup\Local\' + @FileName;

-- 计算数据库总大小（修复：使用SUM函数）
SELECT @BackupSizeMB = SUM(size)/128.0 
FROM sys.master_files 
WHERE database_id = DB_ID('ART_CONTEST');

-- 执行全量备份
BACKUP DATABASE ART_CONTEST 
TO DISK = @BackupPath 
WITH 
    INIT,  -- 覆盖现有文件
    COMPRESSION,  -- 启用压缩
    CHECKSUM,  -- 生成校验和
    STATS = 10;  -- 每10%显示进度

-- 验证备份
RESTORE VERIFYONLY FROM DISK = @BackupPath WITH CHECKSUM;

-- 记录备份历史（修复：使用变量而非子查询）
INSERT INTO dbo.BackupHistory ( 
    BackupType, 
    BackupPath, 
    BackupSizeMB, 
    BackupDate 
) 
SELECT 
    'FULL', 
    @BackupPath, 
    @BackupSizeMB,  -- 使用已计算的变量
    GETDATE();

PRINT '全量备份成功: ' + @BackupPath;