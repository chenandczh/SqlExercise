-- =============================================
-- 企业级数据同步方案脚本
-- =============================================

-- =============================================
-- 1. 创建同步日志表
-- =============================================

USE ART_CONTEST;
GO

-- 创建同步日志主表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SyncLog')
BEGIN
    CREATE TABLE [dbo].[SyncLog] (
        [SyncID] BIGINT PRIMARY KEY IDENTITY(1,1),
        [SyncName] NVARCHAR(100) NOT NULL,
        [SourceSystem] NVARCHAR(100) NOT NULL,
        [TargetSystem] NVARCHAR(100) NOT NULL,
        [SyncType] NVARCHAR(50) NOT NULL, -- Full, Incremental, Delta
        [StartTime] DATETIME NOT NULL DEFAULT GETDATE(),
        [EndTime] DATETIME,
        [Status] NVARCHAR(50) NOT NULL DEFAULT 'Running', -- Running, Success, Failed, Warning
        [SourceRowCount] INT,
        [TargetRowCount] INT,
        [InsertedRows] INT DEFAULT 0,
        [UpdatedRows] INT DEFAULT 0,
        [DeletedRows] INT DEFAULT 0,
        [Errors] INT DEFAULT 0,
        [ErrorMessage] NVARCHAR(MAX),
        [SyncDuration] INT, -- 秒
        [CreatedBy] NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
        CONSTRAINT UC_SyncLog_Unique UNIQUE (SyncName, StartTime)
    );
END
GO

-- 创建同步详细日志表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SyncLogDetail')
BEGIN
    CREATE TABLE [dbo].[SyncLogDetail] (
        [DetailID] BIGINT PRIMARY KEY IDENTITY(1,1),
        [SyncID] BIGINT NOT NULL,
        [TableName] NVARCHAR(128) NOT NULL,
        [Operation] NVARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE, MERGE
        [SourceRowCount] INT,
        [TargetRowCount] INT,
        [SuccessCount] INT DEFAULT 0,
        [ErrorCount] INT DEFAULT 0,
        [Duration] INT, -- 秒
        [ErrorMessage] NVARCHAR(MAX),
        CONSTRAINT FK_SyncLogDetail_SyncLog FOREIGN KEY (SyncID) REFERENCES [dbo].[SyncLog](SyncID)
    );
END
GO

-- 创建索引
CREATE INDEX IX_SyncLog_SyncName ON [dbo].[SyncLog](SyncName);
CREATE INDEX IX_SyncLog_Status ON [dbo].[SyncLog](Status);
CREATE INDEX IX_SyncLog_StartTime ON [dbo].[SyncLog](StartTime);
CREATE INDEX IX_SyncLogDetail_SyncID ON [dbo].[SyncLogDetail](SyncID);
GO

-- =============================================
-- 2. 创建同步配置表
-- =============================================

USE ART_CONTEST;
GO

-- 创建同步任务配置表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SyncConfig')
BEGIN
    CREATE TABLE [dbo].[SyncConfig] (
        [ConfigID] INT PRIMARY KEY IDENTITY(1,1),
        [SyncName] NVARCHAR(100) NOT NULL UNIQUE,
        [SourceConnectionString] NVARCHAR(500) NOT NULL,
        [TargetConnectionString] NVARCHAR(500) NOT NULL,
        [SyncType] NVARCHAR(50) NOT NULL DEFAULT 'Incremental',
        [Enabled] BIT NOT NULL DEFAULT 1,
        [ScheduleType] NVARCHAR(20) NOT NULL DEFAULT 'Manual', -- Manual, Daily, Hourly, Weekly
        [ScheduleTime] TIME,
        [BatchSize] INT NOT NULL DEFAULT 10000,
        [MaxErrors] INT NOT NULL DEFAULT 10,
        [RetryCount] INT NOT NULL DEFAULT 3,
        [RetryInterval] INT NOT NULL DEFAULT 60, -- 秒
        [LastSyncTime] DATETIME,
        [Description] NVARCHAR(500),
        [CreatedBy] NVARCHAR(128) NOT NULL DEFAULT SUSER_SNAME(),
        [CreatedDate] DATETIME NOT NULL DEFAULT GETDATE(),
        [ModifiedBy] NVARCHAR(128),
        [ModifiedDate] DATETIME
    );
END
GO

-- =============================================
-- 3. 创建同步存储过程
-- =============================================

USE ART_CONTEST;
GO

-- 创建通用数据同步存储过程
CREATE OR ALTER PROCEDURE [dbo].[sp_DataSync]
    @SyncName NVARCHAR(100),
    @SyncType NVARCHAR(50) = 'Incremental',
    @BatchSize INT = 10000,
    @MaxErrors INT = 10
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SyncID BIGINT;
    DECLARE @StartTime DATETIME = GETDATE();
    DECLARE @EndTime DATETIME;
    DECLARE @Status NVARCHAR(50) = 'Running';
    DECLARE @ErrorMessage NVARCHAR(MAX);
    
    -- 记录同步开始
    INSERT INTO [dbo].[SyncLog] (
        SyncName, 
        SourceSystem, 
        TargetSystem, 
        SyncType, 
        StartTime, 
        Status
    )
    VALUES (@SyncName, 'SourceDB', 'ART_CONTEST', @SyncType, @StartTime, @Status);
    
    SET @SyncID = SCOPE_IDENTITY();
    
    BEGIN TRY
        -- 根据同步类型执行不同的同步逻辑
        IF @SyncType = 'Full'
        BEGIN
            EXEC [dbo].[sp_FullSync] @SyncID, @BatchSize, @MaxErrors;
        END
        ELSE IF @SyncType = 'Incremental'
        BEGIN
            EXEC [dbo].[sp_IncrementalSync] @SyncID, @BatchSize, @MaxErrors;
        END
        ELSE IF @SyncType = 'Delta'
        BEGIN
            EXEC [dbo].[sp_DeltaSync] @SyncID, @BatchSize, @MaxErrors;
        END
        
        SET @Status = 'Success';
    END TRY
    BEGIN CATCH
        SET @Status = 'Failed';
        SET @ErrorMessage = ERROR_MESSAGE();
        
        -- 记录错误
        UPDATE [dbo].[SyncLog]
        SET 
            Status = @Status,
            ErrorMessage = @ErrorMessage,
            Errors = COALESCE(Errors, 0) + 1
        WHERE SyncID = @SyncID;
        
        THROW;
    END CATCH;
    
    -- 更新同步日志
    SET @EndTime = GETDATE();
    
    UPDATE [dbo].[SyncLog]
    SET 
        EndTime = @EndTime,
        Status = @Status,
        SyncDuration = DATEDIFF(SECOND, @StartTime, @EndTime)
    WHERE SyncID = @SyncID;
    
    PRINT '同步完成: ' + @SyncName + ' - ' + @Status;
END
GO

-- 全量同步存储过程
CREATE OR ALTER PROCEDURE [dbo].[sp_FullSync]
    @SyncID BIGINT,
    @BatchSize INT,
    @MaxErrors INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @DetailID BIGINT;
    DECLARE @StartTime DATETIME = GETDATE();
    
    -- 记录详细日志
    INSERT INTO [dbo].[SyncLogDetail] (SyncID, TableName, Operation, SourceRowCount)
    VALUES (@SyncID, 'Artists', 'MERGE', (SELECT COUNT(*) FROM SOURCE_DB.dbo.Artists));
    
    SET @DetailID = SCOPE_IDENTITY();
    
    -- 全量同步Artists表
    BEGIN TRY
        -- 清空目标表
        TRUNCATE TABLE [dbo].[Artists];
        
        -- 批量插入数据
        DECLARE @Offset INT = 0;
        DECLARE @RowCount INT = 1;
        
        WHILE @RowCount > 0 AND (SELECT Errors FROM [dbo].[SyncLog] WHERE SyncID = @SyncID) < @MaxErrors
        BEGIN
            INSERT INTO [dbo].[Artists] (ArtistID, FirstName, LastName, Email, Phone, StudioID, Country, Bio)
            SELECT ArtistID, FirstName, LastName, Email, Phone, StudioID, Country, Bio
            FROM (
                SELECT *, ROW_NUMBER() OVER (ORDER BY ArtistID) AS RowNum
                FROM SOURCE_DB.dbo.Artists
            ) AS Temp
            WHERE RowNum > @Offset AND RowNum <= @Offset + @BatchSize;
            
            SET @RowCount = @@ROWCOUNT;
            SET @Offset += @BatchSize;
        END
        
        -- 更新详细日志
        UPDATE [dbo].[SyncLogDetail]
        SET 
            SuccessCount = (SELECT COUNT(*) FROM [dbo].[Artists]),
            Duration = DATEDIFF(SECOND, @StartTime, GETDATE())
        WHERE DetailID = @DetailID;
        
        -- 更新主日志
        UPDATE [dbo].[SyncLog]
        SET 
            TargetRowCount = (SELECT COUNT(*) FROM [dbo].[Artists]),
            InsertedRows = COALESCE(InsertedRows, 0) + (SELECT COUNT(*) FROM [dbo].[Artists])
        WHERE SyncID = @SyncID;
    END TRY
    BEGIN CATCH
        UPDATE [dbo].[SyncLogDetail]
        SET 
            ErrorCount = COALESCE(ErrorCount, 0) + 1,
            ErrorMessage = ERROR_MESSAGE()
        WHERE DetailID = @DetailID;
        
        UPDATE [dbo].[SyncLog]
        SET Errors = COALESCE(Errors, 0) + 1
        WHERE SyncID = @SyncID;
        
        THROW;
    END CATCH;
END
GO

-- 增量同步存储过程
CREATE OR ALTER PROCEDURE [dbo].[sp_IncrementalSync]
    @SyncID BIGINT,
    @BatchSize INT,
    @MaxErrors INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @LastSyncTime DATETIME;
    DECLARE @DetailID BIGINT;
    DECLARE @StartTime DATETIME = GETDATE();
    
    -- 获取上次同步时间
    SELECT @LastSyncTime = LastSyncTime 
    FROM [dbo].[SyncConfig] 
    WHERE SyncName = (SELECT SyncName FROM [dbo].[SyncLog] WHERE SyncID = @SyncID);
    
    IF @LastSyncTime IS NULL
    BEGIN
        SET @LastSyncTime = '2000-01-01';
    END
    
    -- 记录详细日志
    INSERT INTO [dbo].[SyncLogDetail] (SyncID, TableName, Operation, SourceRowCount)
    VALUES (@SyncID, 'Artists', 'MERGE', (SELECT COUNT(*) FROM SOURCE_DB.dbo.Artists WHERE LastModified > @LastSyncTime));
    
    SET @DetailID = SCOPE_IDENTITY();
    
    -- 增量同步Artists表
    BEGIN TRY
        -- 使用MERGE进行增量同步
        MERGE INTO [dbo].[Artists] AS Target
        USING (
            SELECT ArtistID, FirstName, LastName, Email, Phone, StudioID, Country, Bio, LastModified
            FROM SOURCE_DB.dbo.Artists
            WHERE LastModified > @LastSyncTime
        ) AS Source
        ON Target.ArtistID = Source.ArtistID
        WHEN MATCHED THEN
            UPDATE SET 
                FirstName = Source.FirstName,
                LastName = Source.LastName,
                Email = Source.Email,
                Phone = Source.Phone,
                StudioID = Source.StudioID,
                Country = Source.Country,
                Bio = Source.Bio
        WHEN NOT MATCHED THEN
            INSERT (ArtistID, FirstName, LastName, Email, Phone, StudioID, Country, Bio)
            VALUES (Source.ArtistID, Source.FirstName, Source.LastName, Source.Email, Source.Phone, Source.StudioID, Source.Country, Source.Bio);
        
        -- 获取MERGE操作的影响行数
        DECLARE @Inserted INT = 0, @Updated INT = 0;
        
        -- 更新详细日志
        UPDATE [dbo].[SyncLogDetail]
        SET 
            SuccessCount = @Inserted + @Updated,
            Duration = DATEDIFF(SECOND, @StartTime, GETDATE())
        WHERE DetailID = @DetailID;
        
        -- 更新主日志
        UPDATE [dbo].[SyncLog]
        SET 
            InsertedRows = @Inserted,
            UpdatedRows = @Updated
        WHERE SyncID = @SyncID;
        
        -- 更新配置中的上次同步时间
        UPDATE [dbo].[SyncConfig]
        SET LastSyncTime = GETDATE()
        WHERE SyncName = (SELECT SyncName FROM [dbo].[SyncLog] WHERE SyncID = @SyncID);
    END TRY
    BEGIN CATCH
        UPDATE [dbo].[SyncLogDetail]
        SET 
            ErrorCount = COALESCE(ErrorCount, 0) + 1,
            ErrorMessage = ERROR_MESSAGE()
        WHERE DetailID = @DetailID;
        
        UPDATE [dbo].[SyncLog]
        SET Errors = COALESCE(Errors, 0) + 1
        WHERE SyncID = @SyncID;
        
        THROW;
    END CATCH;
END
GO

-- 差异同步存储过程
CREATE OR ALTER PROCEDURE [dbo].[sp_DeltaSync]
    @SyncID BIGINT,
    @BatchSize INT,
    @MaxErrors INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- 差异同步：只同步变更的数据（通过变更追踪或CDC）
    PRINT '执行差异同步';
    
    -- 实现变更数据捕获(CDC)同步
    -- 假设源数据库已启用CDC
    BEGIN TRY
        -- 从CDC捕获实例获取变更数据
        INSERT INTO [dbo].[Artists] (ArtistID, FirstName, LastName, Email, Phone, StudioID, Country, Bio)
        SELECT 
            __$start_lsn,
            ArtistID, 
            FirstName, 
            LastName, 
            Email, 
            Phone, 
            StudioID, 
            Country, 
            Bio
        FROM cdc.fn_cdc_get_all_changes_dbo_Artists(
            (SELECT MAX(__$start_lsn) FROM cdc.dbo_Artists_CT WHERE __$operation IN (1,2,3)),
            NULL,
            'all'
        )
        WHERE __$operation IN (2, 4); -- 插入和更新
        
        -- 更新同步日志
        UPDATE [dbo].[SyncLog]
        SET InsertedRows = @@ROWCOUNT
        WHERE SyncID = @SyncID;
    END TRY
    BEGIN CATCH
        UPDATE [dbo].[SyncLog]
        SET 
            Status = 'Failed',
            ErrorMessage = ERROR_MESSAGE(),
            Errors = COALESCE(Errors, 0) + 1
        WHERE SyncID = @SyncID;
        
        THROW;
    END CATCH;
END
GO

-- =============================================
-- 4. 创建同步配置管理存储过程
-- =============================================

USE ART_CONTEST;
GO

-- 添加同步配置
CREATE OR ALTER PROCEDURE [dbo].[sp_AddSyncConfig]
    @SyncName NVARCHAR(100),
    @SourceConnectionString NVARCHAR(500),
    @TargetConnectionString NVARCHAR(500),
    @SyncType NVARCHAR(50) = 'Incremental',
    @ScheduleType NVARCHAR(20) = 'Manual',
    @ScheduleTime TIME = NULL,
    @BatchSize INT = 10000,
    @MaxErrors INT = 10,
    @RetryCount INT = 3,
    @RetryInterval INT = 60,
    @Description NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT * FROM [dbo].[SyncConfig] WHERE SyncName = @SyncName)
    BEGIN
        RAISERROR('同步配置已存在', 16, 1);
        RETURN;
    END
    
    INSERT INTO [dbo].[SyncConfig] (
        SyncName,
        SourceConnectionString,
        TargetConnectionString,
        SyncType,
        ScheduleType,
        ScheduleTime,
        BatchSize,
        MaxErrors,
        RetryCount,
        RetryInterval,
        Description,
        CreatedBy,
        CreatedDate
    )
    VALUES (
        @SyncName,
        @SourceConnectionString,
        @TargetConnectionString,
        @SyncType,
        @ScheduleType,
        @ScheduleTime,
        @BatchSize,
        @MaxErrors,
        @RetryCount,
        @RetryInterval,
        @Description,
        SUSER_SNAME(),
        GETDATE()
    );
    
    PRINT '同步配置创建成功: ' + @SyncName;
END
GO

-- 更新同步配置
CREATE OR ALTER PROCEDURE [dbo].[sp_UpdateSyncConfig]
    @SyncName NVARCHAR(100),
    @SourceConnectionString NVARCHAR(500) = NULL,
    @TargetConnectionString NVARCHAR(500) = NULL,
    @SyncType NVARCHAR(50) = NULL,
    @Enabled BIT = NULL,
    @ScheduleType NVARCHAR(20) = NULL,
    @ScheduleTime TIME = NULL,
    @BatchSize INT = NULL,
    @MaxErrors INT = NULL,
    @RetryCount INT = NULL,
    @RetryInterval INT = NULL,
    @Description NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE [dbo].[SyncConfig]
    SET 
        SourceConnectionString = COALESCE(@SourceConnectionString, SourceConnectionString),
        TargetConnectionString = COALESCE(@TargetConnectionString, TargetConnectionString),
        SyncType = COALESCE(@SyncType, SyncType),
        Enabled = COALESCE(@Enabled, Enabled),
        ScheduleType = COALESCE(@ScheduleType, ScheduleType),
        ScheduleTime = COALESCE(@ScheduleTime, ScheduleTime),
        BatchSize = COALESCE(@BatchSize, BatchSize),
        MaxErrors = COALESCE(@MaxErrors, MaxErrors),
        RetryCount = COALESCE(@RetryCount, RetryCount),
        RetryInterval = COALESCE(@RetryInterval, RetryInterval),
        Description = COALESCE(@Description, Description),
        ModifiedBy = SUSER_SNAME(),
        ModifiedDate = GETDATE()
    WHERE SyncName = @SyncName;
    
    PRINT '同步配置更新成功: ' + @SyncName;
END
GO

-- =============================================
-- 5. 创建SQL Server Agent作业调度
-- =============================================

USE msdb;
GO

-- 创建同步作业
EXEC dbo.sp_add_job
    @job_name = N'ART_CONTEST_Data_Sync',
    @enabled = 1,
    @description = N'企业级数据同步作业';
GO

-- 添加作业步骤：执行同步
EXEC dbo.sp_add_jobstep
    @job_name = N'ART_CONTEST_Data_Sync',
    @step_name = N'执行增量同步',
    @subsystem = N'TSQL',
    @command = N'EXEC ART_CONTEST.dbo.sp_DataSync @SyncName = ''Daily_Sync'', @SyncType = ''Incremental'', @BatchSize = 10000;',
    @database_name = N'ART_CONTEST';
GO

-- 添加作业步骤：发送通知
EXEC dbo.sp_add_jobstep
    @job_name = N'ART_CONTEST_Data_Sync',
    @step_name = N'发送同步结果通知',
    @subsystem = N'TSQL',
    @command = N'
        DECLARE @Status NVARCHAR(50);
        SELECT @Status = Status FROM ART_CONTEST.dbo.SyncLog WHERE SyncName = ''Daily_Sync'' ORDER BY StartTime DESC;
        
        IF @Status = ''Failed''
        BEGIN
            -- 发送失败通知（可配置邮件通知）
            PRINT ''同步失败，请检查日志'';
        END
        ELSE
        BEGIN
            PRINT ''同步成功'';
        END
    ',
    @database_name = N'ART_CONTEST';
GO

-- 创建调度（每天凌晨2点执行）
EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily_Sync_Schedule',
    @freq_type = 4, -- 每天
    @freq_interval = 1,
    @active_start_time = 020000; -- 凌晨2点
GO

-- 关联调度到作业
EXEC dbo.sp_attach_schedule
    @job_name = N'ART_CONTEST_Data_Sync',
    @schedule_name = N'Daily_Sync_Schedule';
GO

-- =============================================
-- 6. 查询同步日志
-- =============================================

USE ART_CONTEST;
GO

-- 查询最近的同步记录
SELECT TOP 10
    SyncID,
    SyncName,
    SyncType,
    StartTime,
    EndTime,
    Duration = DATEDIFF(SECOND, StartTime, EndTime),
    Status,
    InsertedRows,
    UpdatedRows,
    DeletedRows,
    Errors
FROM [dbo].[SyncLog]
ORDER BY StartTime DESC;
GO

-- 查询失败的同步记录
SELECT 
    SyncID,
    SyncName,
    StartTime,
    Status,
    ErrorMessage
FROM [dbo].[SyncLog]
WHERE Status = 'Failed'
ORDER BY StartTime DESC;
GO

-- 查询同步详细日志
SELECT 
    sd.SyncID,
    sl.SyncName,
    sd.TableName,
    sd.Operation,
    sd.SuccessCount,
    sd.ErrorCount,
    sd.Duration,
    sd.ErrorMessage
FROM [dbo].[SyncLogDetail] sd
JOIN [dbo].[SyncLog] sl ON sd.SyncID = sl.SyncID
ORDER BY sl.StartTime DESC;
GO

-- =============================================
-- 7. 手动执行同步示例
-- =============================================

USE ART_CONTEST;
GO

-- 执行全量同步
EXEC [dbo].[sp_DataSync] 
    @SyncName = 'Full_Sync',
    @SyncType = 'Full',
    @BatchSize = 50000;
GO

-- 执行增量同步
EXEC [dbo].[sp_DataSync] 
    @SyncName = 'Incremental_Sync',
    @SyncType = 'Incremental',
    @BatchSize = 10000;
GO

-- =============================================
-- 8. 数据一致性验证
-- =============================================

USE ART_CONTEST;
GO

-- 创建数据验证存储过程
CREATE OR ALTER PROCEDURE [dbo].[sp_ValidateDataConsistency]
    @SourceTable NVARCHAR(128),
    @TargetTable NVARCHAR(128),
    @KeyColumn NVARCHAR(128) = 'ID'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SourceCount INT;
    DECLARE @TargetCount INT;
    DECLARE @MismatchCount INT;
    
    -- 获取源表行数
    DECLARE @SourceSQL NVARCHAR(MAX) = N'SELECT @Count = COUNT(*) FROM ' + @SourceTable;
    EXEC sp_executesql @SourceSQL, N'@Count INT OUTPUT', @Count = @SourceCount OUTPUT;
    
    -- 获取目标表行数
    DECLARE @TargetSQL NVARCHAR(MAX) = N'SELECT @Count = COUNT(*) FROM ' + @TargetTable;
    EXEC sp_executesql @TargetSQL, N'@Count INT OUTPUT', @Count = @TargetCount OUTPUT;
    
    -- 验证行数一致性
    PRINT '源表行数: ' + CAST(@SourceCount AS VARCHAR);
    PRINT '目标表行数: ' + CAST(@TargetCount AS VARCHAR);
    
    IF @SourceCount = @TargetCount
    BEGIN
        PRINT '行数一致';
    END
    ELSE
    BEGIN
        PRINT '行数不一致，差异: ' + CAST(ABS(@SourceCount - @TargetCount) AS VARCHAR);
    END
END
GO

-- 执行数据验证
EXEC [dbo].[sp_ValidateDataConsistency] 
    @SourceTable = 'SOURCE_DB.dbo.Artists',
    @TargetTable = 'ART_CONTEST.dbo.Artists';
GO