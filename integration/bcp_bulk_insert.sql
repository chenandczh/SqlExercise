-- =============================================
-- BCP (Bulk Copy Program) 与 BULK INSERT 脚本
-- =============================================

-- =============================================
-- 1. BCP命令行工具使用示例
-- =============================================

-- 注意：BCP命令需要在命令提示符或PowerShell中执行

/*
-- 导出数据到文件
bcp ART_CONTEST.dbo.Artists out "D:\DataExport\Artists.csv" -S localhost -d ART_CONTEST -T -c -t,

-- 导入数据从文件
bcp ART_CONTEST.dbo.Artists in "D:\DataExport\Artists.csv" -S localhost -d ART_CONTEST -T -c -t, -b 10000

-- 使用格式文件
bcp ART_CONTEST.dbo.Artists in "D:\DataExport\Artists.csv" -S localhost -d ART_CONTEST -T -f "D:\DataExport\Artists.fmt"

-- 查询数据并导出
bcp "SELECT * FROM ART_CONTEST.dbo.Artists WHERE Country='China'" queryout "D:\DataExport\ChineseArtists.csv" -S localhost -T -c

-- 使用密码认证
bcp ART_CONTEST.dbo.Artists out "D:\DataExport\Artists.csv" -S localhost -d ART_CONTEST -U username -P password -c

-- 指定字符编码
bcp ART_CONTEST.dbo.Artists out "D:\DataExport\Artists.csv" -S localhost -d ART_CONTEST -T -c -C 65001

-- 错误文件
bcp ART_CONTEST.dbo.Artists in "D:\DataExport\Artists.csv" -S localhost -d ART_CONTEST -T -c -e "D:\DataExport\Errors.txt"
*/

-- =============================================
-- 2. BULK INSERT 命令使用示例
-- =============================================

USE ART_CONTEST;
GO

-- 基本语法
BULK INSERT [dbo].[Artists_Staging]
FROM 'D:\DataImport\Artists.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,
    TABLOCK
);
GO

-- 带选项的批量插入
BULK INSERT [dbo].[Artists_Staging]
FROM 'D:\DataImport\Artists.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,
    TABLOCK,
    BATCHSIZE = 10000,
    MAXERRORS = 10,
    CODEPAGE = '65001',
    DATAFILETYPE = 'char'
);
GO

-- 使用格式文件
BULK INSERT [dbo].[Artists_Staging]
FROM 'D:\DataImport\Artists.csv'
WITH (
    FORMATFILE = 'D:\DataImport\Artists.fmt',
    TABLOCK,
    BATCHSIZE = 10000
);
GO

-- =============================================
-- 3. 创建格式文件
-- =============================================

/*
-- 使用BCP生成格式文件
bcp ART_CONTEST.dbo.Artists format nul -S localhost -d ART_CONTEST -T -c -f "D:\DataImport\Artists.fmt"

-- 格式文件示例（Artists.fmt）
12.0
7
1       SQLCHAR             0       50      ","      1     ArtistID            ""
2       SQLCHAR             0       100     ","      2     FirstName           SQL_Latin1_General_CP1_CI_AS
3       SQLCHAR             0       100     ","      3     LastName            SQL_Latin1_General_CP1_CI_AS
4       SQLCHAR             0       200     ","      4     Email               SQL_Latin1_General_CP1_CI_AS
5       SQLCHAR             0       20      ","      5     Phone               SQL_Latin1_General_CP1_CI_AS
6       SQLCHAR             0       50      ","      6     StudioID            ""
7       SQLCHAR             0       100     "\r\n"   7     Country             SQL_Latin1_General_CP1_CI_AS
*/

-- =============================================
-- 4. 批量插入到临时表
-- =============================================

USE ART_CONTEST;
GO

-- 创建临时表
CREATE TABLE #TempArtists (
    ArtistID INT,
    FirstName NVARCHAR(100),
    LastName NVARCHAR(100),
    Email NVARCHAR(200),
    Phone NVARCHAR(20),
    StudioID INT,
    Country NVARCHAR(100)
);
GO

-- 批量插入到临时表
BULK INSERT #TempArtists
FROM 'D:\DataImport\Artists.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,
    TABLOCK
);
GO

-- 验证数据
SELECT COUNT(*) FROM #TempArtists;
GO

-- 合并到正式表
MERGE INTO [dbo].[Artists] AS Target
USING #TempArtists AS Source
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

-- 清理临时表
DROP TABLE #TempArtists;
GO

-- =============================================
-- 5. 带事务的批量插入
-- =============================================

USE ART_CONTEST;
GO

BEGIN TRANSACTION;

BEGIN TRY
    -- 禁用索引以提高性能
    ALTER INDEX ALL ON [dbo].[Artists] DISABLE;
    
    -- 执行批量插入
    BULK INSERT [dbo].[Artists]
    FROM 'D:\DataImport\Artists.csv'
    WITH (
        FIELDTERMINATOR = ',',
        ROWTERMINATOR = '\n',
        FIRSTROW = 2,
        TABLOCK,
        BATCHSIZE = 10000,
        MAXERRORS = 5
    );
    
    -- 重建索引
    ALTER INDEX ALL ON [dbo].[Artists] REBUILD;
    
    -- 验证数据
    DECLARE @SourceCount INT = (SELECT COUNT(*) FROM OPENROWSET(BULK 'D:\DataImport\Artists.csv', SINGLE_CLOB) AS Data);
    DECLARE @TargetCount INT = (SELECT COUNT(*) FROM [dbo].[Artists]);
    
    IF @SourceCount = @TargetCount
    BEGIN
        COMMIT TRANSACTION;
        PRINT '批量插入成功，数据一致';
    END
    ELSE
    BEGIN
        ROLLBACK TRANSACTION;
        PRINT '数据不一致，已回滚';
    END
END TRY
BEGIN CATCH
    -- 重建索引（即使失败也要恢复索引）
    ALTER INDEX ALL ON [dbo].[Artists] REBUILD;
    
    ROLLBACK TRANSACTION;
    PRINT '批量插入失败: ' + ERROR_MESSAGE();
END CATCH;
GO

-- =============================================
-- 6. 大容量数据导入优化
-- =============================================

USE ART_CONTEST;
GO

-- 切换到批量日志恢复模式（如果在完整恢复模式下）
ALTER DATABASE ART_CONTEST SET RECOVERY BULK_LOGGED;
GO

-- 执行大容量导入
BULK INSERT [dbo].[LargeTable]
FROM 'D:\DataImport\LargeData.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK,
    BATCHSIZE = 50000,
    MAXERRORS = 0,
    CHECK_CONSTRAINTS = OFF,
    TRIGGERS = OFF
);
GO

-- 切换回完整恢复模式
ALTER DATABASE ART_CONTEST SET RECOVERY FULL;
GO

-- =============================================
-- 7. BCP PowerShell脚本示例
-- =============================================

/*
PowerShell脚本示例：

# 导出数据
bcp "ART_CONTEST.dbo.Artists" out "D:\DataExport\Artists.csv" -S "localhost" -T -c -t ","

# 导入数据
bcp "ART_CONTEST.dbo.Artists" in "D:\DataExport\Artists.csv" -S "localhost" -T -c -t "," -b 10000

# 批量导出多个表
$tables = @("Artists", "Artworks", "Categories", "Contests")

foreach ($table in $tables) {
    $outputFile = "D:\DataExport\$table.csv"
    bcp "ART_CONTEST.dbo.$table" out $outputFile -S "localhost" -T -c -t ","
    Write-Host "Exported $table to $outputFile"
}
*/

-- =============================================
-- 8. 错误处理与日志记录
-- =============================================

USE ART_CONTEST;
GO

-- 创建导入日志表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'BulkImportLog')
BEGIN
    CREATE TABLE [dbo].[BulkImportLog] (
        [ImportID] BIGINT PRIMARY KEY IDENTITY(1,1),
        [FileName] NVARCHAR(255) NOT NULL,
        [TableName] NVARCHAR(128) NOT NULL,
        [StartTime] DATETIME NOT NULL DEFAULT GETDATE(),
        [EndTime] DATETIME,
        [RowsImported] INT,
        [RowsFailed] INT,
        [Status] NVARCHAR(50) NOT NULL,
        [ErrorMessage] NVARCHAR(MAX),
        [CreatedBy] NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME()
    );
END
GO

-- 创建批量导入存储过程
CREATE OR ALTER PROCEDURE [dbo].[sp_BulkImportFromCSV]
    @FilePath NVARCHAR(255),
    @TableName NVARCHAR(128),
    @FieldTerminator NVARCHAR(10) = ',',
    @RowTerminator NVARCHAR(10) = '\n',
    @FirstRow INT = 1,
    @BatchSize INT = 10000,
    @MaxErrors INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ImportID BIGINT;
    DECLARE @RowsImported INT;
    DECLARE @ErrorMessage NVARCHAR(MAX);
    
    -- 记录开始
    INSERT INTO [dbo].[BulkImportLog] (FileName, TableName, Status)
    VALUES (@FilePath, @TableName, 'Running');
    
    SET @ImportID = SCOPE_IDENTITY();
    
    BEGIN TRY
        -- 构建BULK INSERT语句
        DECLARE @SQL NVARCHAR(MAX) = 
            N'BULK INSERT ' + QUOTENAME(@TableName) + 
            N' FROM ''' + REPLACE(@FilePath, '''', '''''') + '''' +
            N' WITH (' +
            N' FIELDTERMINATOR = ''' + @FieldTerminator + ''',' +
            N' ROWTERMINATOR = ''' + @RowTerminator + ''',' +
            N' FIRSTROW = ' + CAST(@FirstRow AS VARCHAR) + ',' +
            N' TABLOCK,' +
            N' BATCHSIZE = ' + CAST(@BatchSize AS VARCHAR) + ',' +
            N' MAXERRORS = ' + CAST(@MaxErrors AS VARCHAR) +
            N')';
        
        EXEC sp_executesql @SQL;
        
        SET @RowsImported = @@ROWCOUNT;
        
        -- 更新日志
        UPDATE [dbo].[BulkImportLog]
        SET 
            EndTime = GETDATE(),
            RowsImported = @RowsImported,
            RowsFailed = 0,
            Status = 'Success'
        WHERE ImportID = @ImportID;
        
        PRINT '导入成功，共导入 ' + CAST(@RowsImported AS VARCHAR) + ' 行';
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = ERROR_MESSAGE();
        
        -- 更新日志
        UPDATE [dbo].[BulkImportLog]
        SET 
            EndTime = GETDATE(),
            RowsImported = 0,
            RowsFailed = 0,
            Status = 'Failed',
            ErrorMessage = @ErrorMessage
        WHERE ImportID = @ImportID;
        
        THROW;
    END CATCH;
END
GO

-- 调用存储过程
EXEC [dbo].[sp_BulkImportFromCSV]
    @FilePath = 'D:\DataImport\Artists.csv',
    @TableName = 'dbo.Artists_Staging',
    @FirstRow = 2,
    @BatchSize = 10000;
GO

-- =============================================
-- 9. 查询导入日志
-- =============================================

USE ART_CONTEST;
GO

-- 查询最近的导入记录
SELECT TOP 20
    ImportID,
    FileName,
    TableName,
    StartTime,
    EndTime,
    Duration = DATEDIFF(SECOND, StartTime, EndTime),
    RowsImported,
    Status,
    CreatedBy
FROM [dbo].[BulkImportLog]
ORDER BY StartTime DESC;
GO

-- 查询失败的导入记录
SELECT 
    ImportID,
    FileName,
    TableName,
    StartTime,
    Status,
    ErrorMessage
FROM [dbo].[BulkImportLog]
WHERE Status = 'Failed'
ORDER BY StartTime DESC;
GO

-- =============================================
-- 10. 性能对比测试
-- =============================================

/*
-- 测试不同批量大小的性能
BULK INSERT TestTable FROM 'data.csv' WITH (BATCHSIZE = 1000)  -- 小批量
BULK INSERT TestTable FROM 'data.csv' WITH (BATCHSIZE = 10000) -- 中批量
BULK INSERT TestTable FROM 'data.csv' WITH (BATCHSIZE = 50000) -- 大批量

-- 测试TABLOCK效果
BULK INSERT TestTable FROM 'data.csv' WITH (TABLOCK) -- 使用TABLOCK
BULK INSERT TestTable FROM 'data.csv' -- 不使用TABLOCK
*/