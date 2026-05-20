-- =============================================
-- 行级安全性(Row-Level Security) SQL脚本
-- =============================================

USE [ART_CONTEST];
GO

-- =============================================
-- 1. 启用行级安全性
-- =============================================

-- 确保数据库兼容级别为130或更高
ALTER DATABASE [ART_CONTEST] SET COMPATIBILITY_LEVEL = 150;
GO

-- =============================================
-- 2. 场景一：基于部门的行级访问控制
-- =============================================

-- 假设我们有一个包含部门信息的表
-- 创建测试表（如果不存在）
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DepartmentData')
BEGIN
    CREATE TABLE [dbo].[DepartmentData] (
        [ID] INT PRIMARY KEY IDENTITY(1,1),
        [Department] NVARCHAR(50) NOT NULL,
        [DataValue] NVARCHAR(200) NOT NULL,
        [CreatedBy] NVARCHAR(128) NOT NULL,
        [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE()
    );
END
GO

-- 插入测试数据
INSERT INTO [dbo].[DepartmentData] (Department, DataValue, CreatedBy)
VALUES 
    ('研发部', '研发项目A数据', 'DEV_WangWei_01'),
    ('研发部', '研发项目B数据', 'DEV_WangWei_01'),
    ('财务部', '财务报表Q1', 'FIN_ZhangLi_01'),
    ('财务部', '预算数据2026', 'FIN_ZhangLi_01'),
    ('市场部', '市场调研报告', 'MKT_LiuFang_01'),
    ('市场部', '竞品分析数据', 'MKT_LiuFang_01');
GO

-- 创建安全函数：根据用户所属部门过滤数据
CREATE OR ALTER FUNCTION [dbo].[fn_DepartmentSecurityPredicate]
(
    @Department NVARCHAR(50)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS Result
    WHERE 
        -- 管理员可以访问所有数据
        IS_MEMBER('db_owner') = 1
        OR
        -- 用户只能访问自己部门的数据
        @Department = (SELECT Department FROM [dbo].[UserDepartment] WHERE UserName = SUSER_SNAME())
);
GO

-- 创建用户部门映射表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'UserDepartment')
BEGIN
    CREATE TABLE [dbo].[UserDepartment] (
        [ID] INT PRIMARY KEY IDENTITY(1,1),
        [UserName] NVARCHAR(128) NOT NULL UNIQUE,
        [Department] NVARCHAR(50) NOT NULL,
        [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE()
    );
END
GO

-- 插入用户部门映射数据
INSERT INTO [dbo].[UserDepartment] (UserName, Department)
VALUES 
    ('DEV_WangWei_01', '研发部'),
    ('FIN_ZhangLi_01', '财务部'),
    ('MKT_LiuFang_01', '市场部');
GO

-- 创建安全策略
CREATE SECURITY POLICY [DepartmentSecurityPolicy]
    ADD FILTER PREDICATE [dbo].[fn_DepartmentSecurityPredicate]([Department])
    ON [dbo].[DepartmentData]
    WITH (STATE = ON);
GO

-- =============================================
-- 3. 场景二：基于用户的行级访问控制（用户只能访问自己创建的数据）
-- =============================================

-- 创建安全函数：用户只能访问自己创建的数据
CREATE OR ALTER FUNCTION [dbo].[fn_OwnerSecurityPredicate]
(
    @CreatedBy NVARCHAR(128)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS Result
    WHERE 
        -- 管理员可以访问所有数据
        IS_MEMBER('db_owner') = 1
        OR
        -- 用户只能访问自己创建的数据
        @CreatedBy = SUSER_SNAME()
);
GO

-- 创建安全策略
CREATE SECURITY POLICY [OwnerSecurityPolicy]
    ADD FILTER PREDICATE [dbo].[fn_OwnerSecurityPredicate]([CreatedBy])
    ON [dbo].[DepartmentData]
    WITH (STATE = ON);
GO

-- =============================================
-- 4. 场景三：基于角色的行级访问控制
-- =============================================

-- 创建角色特定的安全函数
CREATE OR ALTER FUNCTION [dbo].[fn_RoleBasedSecurityPredicate]
(
    @Department NVARCHAR(50)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS Result
    WHERE 
        -- 管理员可以访问所有数据
        IS_MEMBER('db_owner') = 1
        OR
        -- 研发角色可以访问研发部数据
        (IS_MEMBER('APP_RD') = 1 AND @Department = '研发部')
        OR
        -- 财务角色可以访问财务部数据
        (IS_MEMBER('APP_FIN') = 1 AND @Department = '财务部')
        OR
        -- 市场角色可以访问市场部数据
        (IS_MEMBER('APP_MKT') = 1 AND @Department = '市场部')
);
GO

-- 创建部门角色
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'APP_RD')
BEGIN
    CREATE ROLE [APP_RD];
END
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'APP_FIN')
BEGIN
    CREATE ROLE [APP_FIN];
END
GO

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'APP_MKT')
BEGIN
    CREATE ROLE [APP_MKT];
END
GO

-- 创建安全策略
CREATE SECURITY POLICY [RoleBasedSecurityPolicy]
    ADD FILTER PREDICATE [dbo].[fn_RoleBasedSecurityPredicate]([Department])
    ON [dbo].[DepartmentData]
    WITH (STATE = ON);
GO

-- =============================================
-- 5. 场景四：动态数据脱敏（基于角色显示不同数据）
-- =============================================

-- 创建脱敏视图
CREATE OR ALTER VIEW [dbo].[v_Artists_Secure]
AS
SELECT 
    ArtistID,
    FirstName,
    LastName,
    -- 普通用户看到脱敏的邮箱，管理员看到完整邮箱
    CASE 
        WHEN IS_MEMBER('db_owner') = 1 THEN Email 
        ELSE LEFT(Email, 3) + '***' + RIGHT(Email, CHARINDEX('@', REVERSE(Email))) 
    END AS Email,
    -- 普通用户看到脱敏的电话
    CASE 
        WHEN IS_MEMBER('db_owner') = 1 THEN Phone 
        ELSE LEFT(Phone, 3) + '****' + RIGHT(Phone, 4) 
    END AS Phone,
    StudioID,
    Country,
    Bio
FROM [dbo].[Artists];
GO

-- =============================================
-- 6. 场景五：时间敏感数据访问控制
-- =============================================

-- 创建时间敏感的数据表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TimeSensitiveData')
BEGIN
    CREATE TABLE [dbo].[TimeSensitiveData] (
        [ID] INT PRIMARY KEY IDENTITY(1,1),
        [DataContent] NVARCHAR(200) NOT NULL,
        [AccessStartDate] DATETIME NOT NULL,
        [AccessEndDate] DATETIME NOT NULL,
        [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE()
    );
END
GO

-- 插入测试数据（只能在特定时间范围内访问）
INSERT INTO [dbo].[TimeSensitiveData] (DataContent, AccessStartDate, AccessEndDate)
VALUES 
    ('2026年第一季度财务数据', '2026-04-01', '2026-12-31'),
    ('年度审计报告', '2026-03-01', '2027-02-28');
GO

-- 创建时间安全函数
CREATE OR ALTER FUNCTION [dbo].[fn_TimeBasedSecurityPredicate]
(
    @AccessStartDate DATETIME,
    @AccessEndDate DATETIME
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS Result
    WHERE 
        -- 管理员可以随时访问
        IS_MEMBER('db_owner') = 1
        OR
        -- 当前时间在允许访问的时间范围内
        GETDATE() BETWEEN @AccessStartDate AND @AccessEndDate
);
GO

-- 创建时间安全策略
CREATE SECURITY POLICY [TimeBasedSecurityPolicy]
    ADD FILTER PREDICATE [dbo].[fn_TimeBasedSecurityPredicate]([AccessStartDate], [AccessEndDate])
    ON [dbo].[TimeSensitiveData]
    WITH (STATE = ON);
GO

-- =============================================
-- 7. 管理行级安全策略
-- =============================================

-- 查看所有安全策略
SELECT 
    name AS PolicyName,
    is_enabled AS IsEnabled,
    create_date AS CreateDate,
    modify_date AS ModifyDate
FROM sys.security_policies;
GO

-- 查看安全函数
SELECT 
    name AS FunctionName,
    create_date AS CreateDate,
    modify_date AS ModifyDate
FROM sys.objects
WHERE type = 'TF' AND name LIKE 'fn_%SecurityPredicate%';
GO

-- 禁用安全策略
ALTER SECURITY POLICY [DepartmentSecurityPolicy] WITH (STATE = OFF);
GO

-- 启用安全策略
ALTER SECURITY POLICY [DepartmentSecurityPolicy] WITH (STATE = ON);
GO

-- 删除安全策略
-- DROP SECURITY POLICY [DepartmentSecurityPolicy];
-- GO

-- =============================================
-- 8. 测试行级安全性
-- =============================================

-- 测试当前用户能看到的数据
SELECT * FROM [dbo].[DepartmentData];
GO

-- 测试脱敏视图
SELECT * FROM [dbo].[v_Artists_Secure];
GO

-- 测试时间敏感数据
SELECT * FROM [dbo].[TimeSensitiveData];
GO

-- =============================================
-- 9. 跨表行级安全示例
-- =============================================

-- 创建销售数据表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SalesData')
BEGIN
    CREATE TABLE [dbo].[SalesData] (
        [SaleID] INT PRIMARY KEY IDENTITY(1,1),
        [Region] NVARCHAR(50) NOT NULL,
        [Amount] DECIMAL(18,2) NOT NULL,
        [SaleDate] DATETIME NOT NULL DEFAULT GETDATE(),
        [CreatedBy] NVARCHAR(128) NOT NULL
    );
END
GO

-- 创建区域安全函数
CREATE OR ALTER FUNCTION [dbo].[fn_RegionSecurityPredicate]
(
    @Region NVARCHAR(50)
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
(
    SELECT 1 AS Result
    WHERE 
        IS_MEMBER('db_owner') = 1
        OR
        @Region = (SELECT Region FROM [dbo].[UserRegion] WHERE UserName = SUSER_SNAME())
);
GO

-- 创建用户区域映射表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'UserRegion')
BEGIN
    CREATE TABLE [dbo].[UserRegion] (
        [ID] INT PRIMARY KEY IDENTITY(1,1),
        [UserName] NVARCHAR(128) NOT NULL UNIQUE,
        [Region] NVARCHAR(50) NOT NULL,
        [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE()
    );
END
GO

-- 创建安全策略
CREATE SECURITY POLICY [RegionSecurityPolicy]
    ADD FILTER PREDICATE [dbo].[fn_RegionSecurityPredicate]([Region])
    ON [dbo].[SalesData]
    WITH (STATE = ON);
GO