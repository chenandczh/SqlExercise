-- =============================================
-- OPENROWSET 与 OPENDATASOURCE 跨数据源查询脚本
-- =============================================

-- =============================================
-- 1. 启用Ad Hoc Distributed Queries配置
-- =============================================

USE master;
GO

-- 检查当前配置
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

EXEC sp_configure 'Ad Hoc Distributed Queries';
GO

-- 启用Ad Hoc Distributed Queries
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

-- =============================================
-- 2. OPENROWSET基础用法
-- =============================================

-- 从Excel文件读取数据
SELECT * FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=D:\DataImport\Artists.xlsx',
    'SELECT * FROM [Sheet1$]'
);
GO

-- 从CSV文件读取数据
SELECT * FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Text;Database=D:\DataImport;HDR=YES;FORMAT=Delimited(,)',
    'SELECT * FROM Artists.csv'
);
GO

-- 查询远程SQL Server数据库
SELECT * FROM OPENROWSET(
    'SQLNCLI',
    'Server=REMOTE_SERVER;Trusted_Connection=yes;',
    'SELECT * FROM RemoteDB.dbo.Artists'
);
GO

-- 使用OPENROWSET执行存储过程
SELECT * FROM OPENROWSET(
    'SQLNCLI',
    'Server=REMOTE_SERVER;Trusted_Connection=yes;',
    'EXEC RemoteDB.dbo.sp_GetArtistDetails @ArtistID=1'
);
GO

-- =============================================
-- 3. OPENROWSET导入数据
-- =============================================

USE ART_CONTEST;
GO

-- 将Excel数据导入到表中
INSERT INTO [dbo].[Artists_Staging] (FirstName, LastName, Email, Country)
SELECT FirstName, LastName, Email, Country
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=D:\DataImport\NewArtists.xlsx',
    'SELECT FirstName, LastName, Email, Country FROM [Sheet1$]'
);
GO

-- 将CSV数据导入到表中
INSERT INTO [dbo].[Artworks_Staging] (Title, ArtistID, CategoryID, Price)
SELECT Title, ArtistID, CategoryID, Price
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Text;Database=D:\DataImport;HDR=YES;FORMAT=Delimited(,)',
    'SELECT Title, ArtistID, CategoryID, Price FROM Artworks.csv'
);
GO

-- =============================================
-- 4. OPENDATASOURCE基础用法
-- =============================================

-- 查询远程SQL Server数据库
SELECT * FROM OPENDATASOURCE(
    'SQLNCLI',
    'Data Source=REMOTE_SERVER;Integrated Security=SSPI'
).RemoteDB.dbo.Artists;
GO

-- 查询Oracle数据库
SELECT * FROM OPENDATASOURCE(
    'OraOLEDB.Oracle',
    'Data Source=ORACLE_DB;User ID=username;Password=password'
).ORACLE_SCHEMA.ARTISTS;
GO

-- 查询MySQL数据库
SELECT * FROM OPENDATASOURCE(
    'MySQL ODBC 8.0 Unicode Driver',
    'Server=MYSQL_SERVER;Database=mysql_db;User=username;Password=password'
).mysql_db.artists;
GO

-- =============================================
-- 5. 创建链接服务器（替代OPENDATASOURCE的持久化方案）
-- =============================================

USE master;
GO

-- 创建链接服务器
IF NOT EXISTS (SELECT * FROM sys.servers WHERE name = 'LINKED_REMOTE_SERVER')
BEGIN
    EXEC sp_addlinkedserver
        @server = 'LINKED_REMOTE_SERVER',
        @srvproduct = '',
        @provider = 'SQLNCLI',
        @datasrc = 'REMOTE_SERVER';
    
    PRINT '链接服务器创建成功';
END
GO

-- 设置链接服务器安全选项
EXEC sp_addlinkedsrvlogin
    @rmtsrvname = 'LINKED_REMOTE_SERVER',
    @useself = 'TRUE',
    @locallogin = NULL;
GO

-- 查询链接服务器
SELECT * FROM LINKED_REMOTE_SERVER.RemoteDB.dbo.Artists;
GO

-- 删除链接服务器
-- EXEC sp_dropserver 'LINKED_REMOTE_SERVER', 'droplogins';
-- GO

-- =============================================
-- 6. 跨数据源联合查询
-- =============================================

USE ART_CONTEST;
GO

-- 联合查询本地和远程数据
SELECT 
    a.ArtistID,
    a.FirstName,
    a.LastName,
    r.SalesAmount,
    r.SalesDate
FROM [dbo].[Artists] a
LEFT JOIN OPENDATASOURCE(
    'SQLNCLI',
    'Data Source=REMOTE_SERVER;Integrated Security=SSPI'
).SalesDB.dbo.ArtistSales r
ON a.ArtistID = r.ArtistID
WHERE a.Country = 'China';
GO

-- 对比本地和远程数据
SELECT 
    'Local' AS Source, ArtistID, FirstName, LastName
FROM [dbo].[Artists]
WHERE Country = 'USA'
UNION ALL
SELECT 
    'Remote' AS Source, ArtistID, FirstName, LastName
FROM OPENDATASOURCE(
    'SQLNCLI',
    'Data Source=REMOTE_SERVER;Integrated Security=SSPI'
).RemoteDB.dbo.Artists
WHERE Country = 'USA';
GO

-- =============================================
-- 7. 跨数据源数据同步
-- =============================================

USE ART_CONTEST;
GO

-- 从远程服务器同步数据到本地
INSERT INTO [dbo].[Artists_Staging] (ArtistID, FirstName, LastName, Email, Country)
SELECT ArtistID, FirstName, LastName, Email, Country
FROM OPENDATASOURCE(
    'SQLNCLI',
    'Data Source=REMOTE_SERVER;Integrated Security=SSPI'
).RemoteDB.dbo.Artists
WHERE Country = 'China'
AND ArtistID NOT IN (SELECT ArtistID FROM [dbo].[Artists_Staging]);
GO

-- 使用MERGE进行增量同步
MERGE INTO [dbo].[Artists] AS Target
USING (
    SELECT ArtistID, FirstName, LastName, Email, Phone, StudioID, Country
    FROM OPENDATASOURCE(
        'SQLNCLI',
        'Data Source=REMOTE_SERVER;Integrated Security=SSPI'
    ).RemoteDB.dbo.Artists
) AS Source
ON Target.ArtistID = Source.ArtistID
WHEN MATCHED THEN
    UPDATE SET 
        FirstName = Source.FirstName,
        LastName = Source.LastName,
        Email = Source.Email,
        Phone = Source.Phone,
        StudioID = Source.StudioID,
        Country = Source.Country
WHEN NOT MATCHED THEN
    INSERT (ArtistID, FirstName, LastName, Email, Phone, StudioID, Country)
    VALUES (Source.ArtistID, Source.FirstName, Source.LastName, Source.Email, Source.Phone, Source.StudioID, Source.Country);
GO

-- =============================================
-- 8. 从Excel文件批量导入
-- =============================================

USE ART_CONTEST;
GO

-- 创建临时表
CREATE TABLE #TempExcelData (
    FirstName NVARCHAR(100),
    LastName NVARCHAR(100),
    Email NVARCHAR(200),
    Phone NVARCHAR(20),
    Country NVARCHAR(100)
);
GO

-- 从Excel导入数据
INSERT INTO #TempExcelData
SELECT FirstName, LastName, Email, Phone, Country
FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=D:\DataImport\Artists.xlsx;HDR=YES',
    'SELECT * FROM [Sheet1$]'
);
GO

-- 验证数据
SELECT * FROM #TempExcelData;
GO

-- 合并到正式表
MERGE INTO [dbo].[Artists] AS Target
USING #TempExcelData AS Source
ON Target.Email = Source.Email
WHEN MATCHED THEN
    UPDATE SET 
        FirstName = Source.FirstName,
        LastName = Source.LastName,
        Phone = Source.Phone,
        Country = Source.Country
WHEN NOT MATCHED THEN
    INSERT (FirstName, LastName, Email, Phone, Country)
    VALUES (Source.FirstName, Source.LastName, Source.Email, Source.Phone, Source.Country);
GO

-- 清理临时表
DROP TABLE #TempExcelData;
GO

-- =============================================
-- 9. 安全配置与最佳实践
-- =============================================

USE master;
GO

-- 配置OPENROWSET权限
GRANT ADMINISTER BULK OPERATIONS TO [IntegrationUser];
GO

-- 配置链接服务器权限
EXEC sp_addlinkedsrvlogin
    @rmtsrvname = 'LINKED_REMOTE_SERVER',
    @useself = 'FALSE',
    @locallogin = 'IntegrationUser',
    @rmtuser = 'RemoteUser',
    @rmtpassword = 'RemotePassword';
GO

-- 禁用Ad Hoc Distributed Queries（安全考虑）
-- EXEC sp_configure 'Ad Hoc Distributed Queries', 0;
-- RECONFIGURE;
-- GO

-- =============================================
-- 10. 故障排除与性能优化
-- =============================================

-- 检查链接服务器状态
EXEC sp_testlinkedserver 'LINKED_REMOTE_SERVER';
GO

-- 查询链接服务器信息
SELECT 
    srv.name AS ServerName,
    srv.product AS Product,
    srv.provider AS Provider,
    srv.data_source AS DataSource,
    srv.catalog AS Catalog
FROM sys.servers srv
WHERE srv.is_linked = 1;
GO

-- 优化跨服务器查询（使用OPENQUERY）
SELECT * FROM OPENQUERY(
    LINKED_REMOTE_SERVER,
    'SELECT ArtistID, FirstName, LastName FROM RemoteDB.dbo.Artists WHERE Country = ''China'''
);
GO

-- 使用OPENQUERY执行存储过程
SELECT * FROM OPENQUERY(
    LINKED_REMOTE_SERVER,
    'EXEC RemoteDB.dbo.sp_GetArtistSales @StartDate = ''2026-01-01'', @EndDate = ''2026-12-31'''
);
GO

-- =============================================
-- 11. 配置示例：连接不同数据源
-- =============================================

/*
-- 连接Excel 32位
SELECT * FROM OPENROWSET(
    'Microsoft.Jet.OLEDB.4.0',
    'Excel 8.0;Database=D:\DataImport\Artists.xls;HDR=YES',
    'SELECT * FROM [Sheet1$]'
);

-- 连接Access数据库
SELECT * FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Data Source=D:\DataImport\Artists.accdb;Persist Security Info=False',
    'SELECT * FROM Artists'
);

-- 连接CSV文件（使用Microsoft Text Driver）
SELECT * FROM OPENROWSET(
    'MSDASQL',
    'Driver={Microsoft Text Driver (*.txt; *.csv)};DBQ=D:\DataImport;Extensions=csv',
    'SELECT * FROM Artists.csv'
);
*/