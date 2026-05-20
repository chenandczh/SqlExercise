-- =============================================
-- 透明数据加密(TDE) SQL脚本
-- =============================================

-- =============================================
-- 1. 检查数据库是否支持TDE
-- =============================================

-- 检查SQL Server版本和兼容性
SELECT 
    SERVERPROPERTY('ProductVersion') AS ServerVersion,
    SERVERPROPERTY('ProductLevel') AS ProductLevel,
    SERVERPROPERTY('Edition') AS Edition;
GO

-- 检查数据库兼容级别
SELECT name, compatibility_level 
FROM sys.databases 
WHERE name = 'ART_CONTEST';
GO

-- =============================================
-- 2. 启用TDE的步骤
-- =============================================

-- 步骤1: 在master数据库中创建数据库主密钥
USE master;
GO

-- 检查是否已存在主密钥
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'M@sterK3y2026!';
    PRINT '数据库主密钥已创建';
END
ELSE
BEGIN
    PRINT '数据库主密钥已存在';
END
GO

-- 步骤2: 创建服务器证书（用于加密数据库加密密钥）
USE master;
GO

-- 检查证书是否存在
IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'TDE_Certificate_ART_CONTEST')
BEGIN
    CREATE CERTIFICATE TDE_Certificate_ART_CONTEST
        WITH SUBJECT = 'TDE Certificate for ART_CONTEST Database',
        START_DATE = '2026-01-01',
        EXPIRY_DATE = '2036-01-01';
    PRINT 'TDE证书已创建';
END
ELSE
BEGIN
    PRINT 'TDE证书已存在';
END
GO

-- 步骤3: 查看证书信息
USE master;
GO

SELECT 
    name AS CertificateName,
    subject,
    start_date,
    expiry_date,
    is_active_for_begin_dialog
FROM sys.certificates
WHERE name = 'TDE_Certificate_ART_CONTEST';
GO

-- =============================================
-- 3. 在目标数据库中创建数据库加密密钥
-- =============================================

USE ART_CONTEST;
GO

-- 检查是否已存在数据库加密密钥
IF NOT EXISTS (SELECT * FROM sys.dm_database_encryption_keys WHERE database_id = DB_ID('ART_CONTEST'))
BEGIN
    CREATE DATABASE ENCRYPTION KEY
        WITH ALGORITHM = AES_256
        ENCRYPTION BY SERVER CERTIFICATE TDE_Certificate_ART_CONTEST;
    PRINT '数据库加密密钥已创建';
END
ELSE
BEGIN
    PRINT '数据库加密密钥已存在';
END
GO

-- =============================================
-- 4. 启用数据库加密
-- =============================================

USE master;
GO

-- 检查当前加密状态
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    encryption_state,
    encryption_state_desc = 
        CASE encryption_state
            WHEN 0 THEN '未加密'
            WHEN 1 THEN '加密中'
            WHEN 2 THEN '已加密'
            WHEN 3 THEN '密钥更改中'
            WHEN 4 THEN '解密中'
            WHEN 5 THEN '密钥移除中'
            ELSE '未知'
        END,
    percent_complete,
    encryptor_type,
    encryptor_thumbprint
FROM sys.dm_database_encryption_keys
WHERE database_id = DB_ID('ART_CONTEST');
GO

-- 启用TDE加密
ALTER DATABASE ART_CONTEST
SET ENCRYPTION ON;
GO

-- 等待加密完成并检查状态
WAITFOR DELAY '00:01:00'; -- 等待1分钟

SELECT 
    DB_NAME(database_id) AS DatabaseName,
    encryption_state,
    encryption_state_desc = 
        CASE encryption_state
            WHEN 0 THEN '未加密'
            WHEN 1 THEN '加密中'
            WHEN 2 THEN '已加密'
            WHEN 3 THEN '密钥更改中'
            WHEN 4 THEN '解密中'
            WHEN 5 THEN '密钥移除中'
            ELSE '未知'
        END,
    percent_complete
FROM sys.dm_database_encryption_keys
WHERE database_id = DB_ID('ART_CONTEST');
GO

-- =============================================
-- 5. 备份TDE证书和私钥（关键步骤！）
-- =============================================

USE master;
GO

-- 备份证书到文件
BACKUP CERTIFICATE TDE_Certificate_ART_CONTEST 
    TO FILE = 'D:\SQLBackup\Certificates\TDE_Certificate_ART_CONTEST.cer'
    WITH PRIVATE KEY (
        FILE = 'D:\SQLBackup\Certificates\TDE_Certificate_ART_CONTEST.pvk',
        ENCRYPTION BY PASSWORD = 'C3rtP@ssw0rd2026!'
    );
GO

-- =============================================
-- 6. 列级加密（针对敏感数据）
-- =============================================

USE ART_CONTEST;
GO

-- 步骤1: 创建列级加密密钥
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'ColumnEncryptionKey_ART_CONTEST')
BEGIN
    CREATE SYMMETRIC KEY ColumnEncryptionKey_ART_CONTEST
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE TDE_Certificate_ART_CONTEST;
    PRINT '列级加密密钥已创建';
END
GO

-- 步骤2: 创建加密视图（演示加密效果）
CREATE OR ALTER VIEW [dbo].[v_SensitiveData_Encrypted]
AS
SELECT 
    ArtistID,
    FirstName,
    LastName,
    -- 加密邮箱列
    EncryptByKey(Key_GUID('ColumnEncryptionKey_ART_CONTEST'), Email) AS Email_Encrypted,
    -- 加密电话列
    EncryptByKey(Key_GUID('ColumnEncryptionKey_ART_CONTEST'), Phone) AS Phone_Encrypted,
    StudioID,
    Country
FROM [dbo].[Artists];
GO

-- 步骤3: 创建解密视图
CREATE OR ALTER VIEW [dbo].[v_SensitiveData_Decrypted]
AS
SELECT 
    ArtistID,
    FirstName,
    LastName,
    -- 解密邮箱
    CAST(DecryptByKey(Email_Encrypted) AS NVARCHAR(100)) AS Email,
    -- 解密电话
    CAST(DecryptByKey(Phone_Encrypted) AS NVARCHAR(20)) AS Phone,
    StudioID,
    Country
FROM [dbo].[v_SensitiveData_Encrypted];
GO

-- 步骤4: 测试加密和解密
-- 打开对称密钥
OPEN SYMMETRIC KEY ColumnEncryptionKey_ART_CONTEST
    DECRYPTION BY CERTIFICATE TDE_Certificate_ART_CONTEST;
GO

-- 查询加密数据
SELECT * FROM [dbo].[v_SensitiveData_Encrypted];
GO

-- 查询解密数据
SELECT * FROM [dbo].[v_SensitiveData_Decrypted];
GO

-- 关闭对称密钥
CLOSE SYMMETRIC KEY ColumnEncryptionKey_ART_CONTEST;
GO

-- =============================================
-- 7. 哈希加密（用于密码等敏感字段）
-- =============================================

USE ART_CONTEST;
GO

-- 创建密码哈希示例
DECLARE @Password NVARCHAR(100) = 'UserP@ssw0rd!';

-- 使用SHA2_512哈希
SELECT 
    @Password AS OriginalPassword,
    HASHBYTES('SHA2_512', @Password) AS HashedPassword,
    CONVERT(NVARCHAR(256), HASHBYTES('SHA2_512', @Password), 1) AS HashedPasswordHex;
GO

-- 创建带盐值的哈希（更安全）
DECLARE @Password2 NVARCHAR(100) = 'UserP@ssw0rd!';
DECLARE @Salt UNIQUEIDENTIFIER = NEWID();

SELECT 
    @Password2 AS OriginalPassword,
    @Salt AS Salt,
    HASHBYTES('SHA2_512', CONCAT(@Salt, @Password2)) AS HashedWithSalt;
GO

-- =============================================
-- 8. 密钥轮换
-- =============================================

USE master;
GO

-- 创建新证书用于密钥轮换
CREATE CERTIFICATE TDE_Certificate_ART_CONTEST_New
    WITH SUBJECT = 'TDE Certificate for ART_CONTEST Database - New',
    START_DATE = '2026-05-01',
    EXPIRY_DATE = '2036-05-01';
GO

-- 将数据库加密密钥重新加密为新证书
USE ART_CONTEST;
GO

ALTER DATABASE ENCRYPTION KEY
    ENCRYPTION BY SERVER CERTIFICATE TDE_Certificate_ART_CONTEST_New;
GO

-- 备份新证书
USE master;
GO

BACKUP CERTIFICATE TDE_Certificate_ART_CONTEST_New 
    TO FILE = 'D:\SQLBackup\Certificates\TDE_Certificate_ART_CONTEST_New.cer'
    WITH PRIVATE KEY (
        FILE = 'D:\SQLBackup\Certificates\TDE_Certificate_ART_CONTEST_New.pvk',
        ENCRYPTION BY PASSWORD = 'NewC3rtP@ssw0rd2026!'
    );
GO

-- 删除旧证书（可选，建议保留一段时间）
-- DROP CERTIFICATE TDE_Certificate_ART_CONTEST;
-- GO

-- =============================================
-- 9. 禁用TDE（不推荐，但提供方法）
-- =============================================

-- 注意：禁用TDE会导致数据库解密，可能需要很长时间
/*
USE master;
GO

ALTER DATABASE ART_CONTEST
SET ENCRYPTION OFF;
GO

-- 等待解密完成
WAITFOR DELAY '00:10:00';

-- 删除数据库加密密钥
USE ART_CONTEST;
GO

DROP DATABASE ENCRYPTION KEY;
GO
*/

-- =============================================
-- 10. 监控TDE状态
-- =============================================

-- 查看所有数据库的加密状态
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    encryption_state,
    encryption_state_desc = 
        CASE encryption_state
            WHEN 0 THEN '未加密'
            WHEN 1 THEN '加密中'
            WHEN 2 THEN '已加密'
            WHEN 3 THEN '密钥更改中'
            WHEN 4 THEN '解密中'
            WHEN 5 THEN '密钥移除中'
            ELSE '未知'
        END,
    percent_complete,
    encryptor_type,
    encryptor_thumbprint,
    create_date,
    modify_date
FROM sys.dm_database_encryption_keys;
GO

-- 查看证书和密钥信息
SELECT 
    name AS KeyName,
    symmetric_key_id,
    key_length,
    algorithm_desc,
    create_date
FROM sys.symmetric_keys;
GO

-- 查看服务器证书
SELECT 
    name AS CertificateName,
    subject,
    issuer_name,
    start_date,
    expiry_date,
    is_active_for_begin_dialog
FROM sys.certificates
WHERE name LIKE 'TDE_%';
GO

-- =============================================
-- 11. 故障恢复：使用备份的证书还原数据库
-- =============================================

/*
-- 在新服务器上恢复TDE加密的数据库步骤：
-- 1. 创建数据库主密钥（如果不存在）
USE master;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'M@sterK3y2026!';
GO

-- 2. 从备份文件创建证书
CREATE CERTIFICATE TDE_Certificate_ART_CONTEST
    FROM FILE = 'D:\SQLBackup\Certificates\TDE_Certificate_ART_CONTEST.cer'
    WITH PRIVATE KEY (
        FILE = 'D:\SQLBackup\Certificates\TDE_Certificate_ART_CONTEST.pvk',
        DECRYPTION BY PASSWORD = 'C3rtP@ssw0rd2026!'
    );
GO

-- 3. 现在可以还原数据库
RESTORE DATABASE ART_CONTEST
    FROM DISK = 'D:\SQLBackup\ART_CONTEST_Full.bak'
    WITH RECOVERY;
GO
*/