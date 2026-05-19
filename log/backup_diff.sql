-- ========================================
-- 差异备份脚本
-- ========================================
DECLARE @BackupPath VARCHAR(500);
DECLARE @FileName VARCHAR(200);
DECLARE @DateStr VARCHAR(20);

SET @DateStr = CONVERT(VARCHAR(8), GETDATE(), 112) + '_' + 
               REPLACE(CONVERT(VARCHAR(8), GETDATE(), 108), ':', '');
SET @FileName = 'ART_CONTEST_DIFF_' + @DateStr + '.bak';
SET @BackupPath = 'D:\SQLBackup\Local\' + @FileName;

BACKUP DATABASE ART_CONTEST 
TO DISK = @BackupPath
WITH 
    DIFFERENTIAL,  -- 差异备份
    INIT,
    COMPRESSION,
    CHECKSUM,
    STATS = 10;