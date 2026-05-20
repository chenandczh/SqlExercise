-- =============================================
-- 用户与角色管理SQL脚本
-- =============================================

-- =============================================
-- 1. 创建登录名与用户
-- =============================================

-- 创建SQL Server登录名
CREATE LOGIN [DEV_WangWei_01] 
    WITH PASSWORD = 'P@ssw0rd2026!',
    DEFAULT_DATABASE = [ART_CONTEST],
    CHECK_EXPIRATION = ON,
    CHECK_POLICY = ON;
GO

-- 创建Windows登录名（域用户）
-- CREATE LOGIN [DOMAIN\UserName] FROM WINDOWS;
-- GO

-- 在数据库中创建用户
USE [ART_CONTEST];
GO

CREATE USER [DEV_WangWei_01] FOR LOGIN [DEV_WangWei_01];
GO

-- 创建服务账户
CREATE LOGIN [SVC_ART_CONTEST_APP] 
    WITH PASSWORD = 'Svc@rtC0nt3st!',
    DEFAULT_DATABASE = [ART_CONTEST],
    CHECK_EXPIRATION = OFF,
    CHECK_POLICY = ON;
GO

CREATE USER [SVC_ART_CONTEST_APP] FOR LOGIN [SVC_ART_CONTEST_APP];
GO

-- =============================================
-- 2. 创建自定义数据库角色
-- =============================================

USE [ART_CONTEST];
GO

-- 创建只读角色
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'APP_ReadOnly')
BEGIN
    CREATE ROLE [APP_ReadOnly];
END
GO

-- 创建读写角色
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'APP_ReadWrite')
BEGIN
    CREATE ROLE [APP_ReadWrite];
END
GO

-- 创建报表角色
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'APP_Report')
BEGIN
    CREATE ROLE [APP_Report];
END
GO

-- =============================================
-- 3. 权限分配
-- =============================================

USE [ART_CONTEST];
GO

-- 授予APP_ReadOnly角色只读权限
GRANT SELECT ON SCHEMA::dbo TO [APP_ReadOnly];
GO

-- 授予APP_ReadWrite角色读写权限
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO [APP_ReadWrite];
GO

-- 授予APP_Report角色执行存储过程权限
GRANT EXECUTE ON SCHEMA::dbo TO [APP_Report];
GO

-- 为特定用户授予特定表权限（最小权限原则）
GRANT SELECT ON [dbo].[Artists] TO [DEV_WangWei_01];
GRANT SELECT, INSERT, UPDATE ON [dbo].[Artworks] TO [DEV_WangWei_01];
GO

-- 为服务账户授予应用所需的最小权限
GRANT SELECT, INSERT, UPDATE, DELETE ON [dbo].[Submissions] TO [SVC_ART_CONTEST_APP];
GRANT SELECT ON [dbo].[Artworks] TO [SVC_ART_CONTEST_APP];
GRANT SELECT ON [dbo].[Artists] TO [SVC_ART_CONTEST_APP];
GO

-- =============================================
-- 4. 将用户添加到角色
-- =============================================

USE [ART_CONTEST];
GO

-- 将用户添加到角色
EXEC sp_addrolemember 'APP_ReadOnly', 'DEV_WangWei_01';
GO

EXEC sp_addrolemember 'APP_ReadWrite', 'SVC_ART_CONTEST_APP';
GO

-- =============================================
-- 5. 创建服务器角色（可选）
-- =============================================

-- 创建服务器级安全管理员角色
-- CREATE SERVER ROLE [SecurityAdmin] AUTHORIZATION [sa];
-- GRANT ALTER ANY LOGIN TO [SecurityAdmin];
-- GRANT ALTER ANY SERVER ROLE TO [SecurityAdmin];
-- GO

-- =============================================
-- 6. 用户生命周期管理
-- =============================================

-- 禁用用户（离职人员）
ALTER LOGIN [DEV_WangWei_01] DISABLE;
GO

-- 启用用户
ALTER LOGIN [DEV_WangWei_01] ENABLE;
GO

-- 修改密码
ALTER LOGIN [DEV_WangWei_01] WITH PASSWORD = 'N3wP@ssw0rd!';
GO

-- 删除用户和登录名
USE [ART_CONTEST];
GO

DROP USER IF EXISTS [DEV_WangWei_01];
GO

DROP LOGIN IF EXISTS [DEV_WangWei_01];
GO

-- =============================================
-- 7. 权限审计查询
-- =============================================

-- 查询数据库用户及其角色
SELECT 
    dp.name AS UserName,
    dp.type_desc AS UserType,
    dr.name AS RoleName
FROM sys.database_principals dp
LEFT JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
LEFT JOIN sys.database_principals dr ON drm.role_principal_id = dr.principal_id
WHERE dp.type IN ('U', 'S')
ORDER BY dp.name;
GO

-- 查询用户权限
SELECT 
    dp.name AS Grantee,
    dp.type_desc AS GranteeType,
    OBJECT_NAME(dm.major_id) AS ObjectName,
    dm.permission_name,
    dm.state_desc
FROM sys.database_permissions dm
JOIN sys.database_principals dp ON dm.grantee_principal_id = dp.principal_id
WHERE dm.major_id > 0
ORDER BY dp.name;
GO

-- 查询服务器登录名
SELECT 
    name AS LoginName,
    type_desc AS LoginType,
    is_disabled AS IsDisabled,
    create_date AS CreateDate,
    modify_date AS ModifyDate
FROM sys.sql_logins
ORDER BY name;
GO

-- =============================================
-- 8. 密码策略配置（需要服务器级别权限）
-- =============================================

-- 查看当前密码策略
-- SELECT * FROM sys.login_token;

-- 配置密码复杂度策略（通过SQL Server配置管理器或组策略）
-- 以下为示例，实际需要在服务器级别配置
-- EXEC sp_configure 'show advanced options', 1;
-- RECONFIGURE;
-- GO

-- =============================================
-- 9. 示例：创建应用服务账户并配置权限
-- =============================================

-- 创建应用服务账户
CREATE LOGIN [SVC_ART_CONTEST_WEB] 
    WITH PASSWORD = 'W3bSvc@2026!',
    DEFAULT_DATABASE = [ART_CONTEST],
    CHECK_EXPIRATION = OFF;
GO

USE [ART_CONTEST];
GO

CREATE USER [SVC_ART_CONTEST_WEB] FOR LOGIN [SVC_ART_CONTEST_WEB];
GO

-- 授予应用所需的最小权限
GRANT SELECT ON [dbo].[Artists] TO [SVC_ART_CONTEST_WEB];
GRANT SELECT ON [dbo].[Artworks] TO [SVC_ART_CONTEST_WEB];
GRANT SELECT ON [dbo].[Categories] TO [SVC_ART_CONTEST_WEB];
GRANT SELECT ON [dbo].[Submissions] TO [SVC_ART_CONTEST_WEB];
GRANT SELECT ON [dbo].[Judges] TO [SVC_ART_CONTEST_WEB];
GRANT SELECT ON [dbo].[Scores] TO [SVC_ART_CONTEST_WEB];
GRANT SELECT ON [dbo].[Contests] TO [SVC_ART_CONTEST_WEB];

GRANT INSERT ON [dbo].[Submissions] TO [SVC_ART_CONTEST_WEB];
GRANT INSERT ON [dbo].[Scores] TO [SVC_ART_CONTEST_WEB];

GRANT UPDATE ON [dbo].[Artworks] TO [SVC_ART_CONTEST_WEB];
GRANT UPDATE ON [dbo].[Submissions] TO [SVC_ART_CONTEST_WEB];
GO

-- =============================================
-- 10. 拒绝权限示例
-- =============================================

-- 拒绝特定用户访问敏感表
-- DENY SELECT ON [dbo].[SensitiveData] TO [DEV_WangWei_01];
-- GO

-- =============================================
-- 11. 角色权限继承示例
-- =============================================

-- 创建层级角色
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'APP_Admin')
BEGIN
    CREATE ROLE [APP_Admin];
END
GO

-- APP_Admin继承APP_ReadWrite权限
EXEC sp_addrolemember 'APP_ReadWrite', 'APP_Admin';
GO

-- 额外授予管理权限
GRANT ALTER ON SCHEMA::dbo TO [APP_Admin];
GRANT REFERENCES ON SCHEMA::dbo TO [APP_Admin];
GO

-- =============================================
-- 12. 权限回收
-- =============================================

-- 回收用户权限
REVOKE UPDATE ON [dbo].[Artworks] FROM [DEV_WangWei_01];
GO

-- 回收角色权限
REVOKE DELETE ON SCHEMA::dbo FROM [APP_ReadWrite];
GO