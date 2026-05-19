# SQL Server 数据库备份与日志管理最佳实践方案

## 文档版本信息

| 项目 | 内容 |
|------|------|
| **文档版本** | V1.0 |
| **创建日期** | 2026年5月 |
| **适用环境** | SQL Server 2016+ |
| **适用范围** | ART_CONTEST 数据库及相关生产环境 |

---

## 1. 引言

### 1.1 背景

过往由于缺乏系统化的日志备份计划以及未实施定时清理长期未使用的数据和日志，曾导致生产环境中数据库文件过度增长，最终引发数据插入操作失败的严重生产事故。此类情况对业务连续性构成重大风险。

### 1.2 目标

制定全面、专业的数据库备份与日志管理最佳实践方案，确保：
- 数据完整性和可恢复性
- 日志文件可控增长
- 磁盘空间合理利用
- 快速故障恢复能力

---

## 2. 数据库备份策略

### 2.1 备份类型概述

| 备份类型 | 说明 | 优点 | 缺点 |
|----------|------|------|------|
| **全量备份** | 备份整个数据库 | 恢复简单，独立完整 | 备份时间长，占用空间大 |
| **差异备份** | 备份自上次全量备份以来的变更 | 备份时间短，占用空间较小 | 依赖全量备份 |
| **增量备份** | 备份自上次备份以来的变更 | 备份速度最快，空间最小 | 恢复复杂，依赖链长 |
| **事务日志备份** | 备份事务日志 | 支持时间点恢复 | 仅适用于完整恢复模式 |

### 2.2 备份策略设计

#### 2.2.1 备份频率规划

```
┌─────────────────────────────────────────────────────────────────┐
│                    每周备份周期示意图                            │
├─────────────────────────────────────────────────────────────────┤
│  周一       周二       周三       周四       周五       周六    │
│  ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐│
│  │全量  │    │差异 │    │差异 │    │差异 │    │差异 │    │全量  ││
│  │备份  │    │备份 │    │备份 │    │备份 │    │备份 │    │备份  ││
│  └─────┘    └─────┘    └─────┘    └─────┘    └─────┘    └─────┘│
│     │          │          │          │          │          │    │
│     ▼          ▼          ▼          ▼          ▼          ▼    │
│  00:00     02:00     02:00     02:00     02:00     00:00      │
└─────────────────────────────────────────────────────────────────┘

每日事务日志备份：每15分钟执行一次
```

#### 2.2.2 备份策略表

| 备份类型 | 执行频率 | 执行时间 | 保留周期 |
|----------|----------|----------|----------|
| 全量备份 | 每周两次 | 周一、周六 00:00 | 4周 |
| 差异备份 | 每日 | 周二至周五 02:00 | 1周 |
| 事务日志备份 | 每15分钟 | 持续执行 | 3天 |

### 2.3 备份存储方案

#### 2.3.1 本地存储策略

| 存储类型 | 位置 | 容量要求 | 冗余策略 |
|----------|------|----------|----------|
| 主备份存储 | D:\SQLBackup\Local | 至少2倍数据库大小 | RAID 5/RAID 10 |
| 临时存储 | 本地SSD | 至少1倍数据库大小 | 无 |

#### 2.3.2 异地容灾策略

| 存储类型 | 位置 | 同步频率 | 保留周期 |
|----------|------|----------|----------|
| 异地备份 | 云存储/远程服务器 | 每日同步 | 4周 |
| 灾难恢复副本 | 异地数据中心 | 实时同步 | 持续 |

### 2.4 备份验证机制

```sql
-- 备份后验证脚本
DECLARE @BackupPath VARCHAR(500) = 'D:\SQLBackup\Local\ART_CONTEST_FULL.bak';

-- 验证备份文件完整性
RESTORE VERIFYONLY 
FROM DISK = @BackupPath
WITH CHECKSUM;

-- 检查备份信息
RESTORE HEADERONLY 
FROM DISK = @BackupPath;
```

### 2.5 备份恢复演练计划

| 演练类型 | 频率 | 参与角色 | 演练内容 |
|----------|------|----------|----------|
| 全量恢复演练 | 每月 | DBA、运维工程师 | 完整数据库恢复测试 |
| 时间点恢复演练 | 每季度 | DBA、开发工程师 | 基于事务日志的时间点恢复 |
| 灾难恢复演练 | 每半年 | 全团队 | 异地容灾切换测试 |

---

## 3. 数据库日志管理规划

### 3.1 日志分类管理

| 日志类型 | 说明 | 重要性 | 管理策略 |
|----------|------|--------|----------|
| **事务日志** | 记录所有数据修改操作 | 高 | 定期备份、及时截断 |
| **错误日志** | 记录数据库引擎错误和警告 | 中 | 定期轮转、保留90天 |
| **审计日志** | 记录安全相关事件 | 高 | 加密存储、保留1年 |
| **SQL Server Agent日志** | 记录作业执行情况 | 中 | 定期轮转、保留30天 |
| **查询日志** | 记录慢查询和性能数据 | 中 | 按需收集、保留7天 |

### 3.2 日志轮转策略

```
┌──────────────────────────────────────────────────────────────┐
│                     日志轮转周期示意图                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  日志文件    大小达到阈值?    轮转触发    创建新文件          │
│      │              │              │            │            │
│      ▼              ▼              ▼            ▼            │
│   active.log ──────Yes──────► 重命名 ────► active.log       │
│      │                         │              │              │
│      │                    active.1.log        │              │
│      │                         │              │              │
│      │                    压缩归档            │              │
│      │                         │              │              │
│      │                    检查保留期          │              │
│      │                         │              │              │
│      │                    超过30天?           │              │
│      │                         │              │              │
│      │                    Yes───► 删除旧日志  │              │
│      │                         │              │              │
│      └─────────────────────────┴──────────────┘              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 3.3 日志轮转配置表

| 日志类型 | 单个文件大小限制 | 轮转频率 | 保留期限 | 归档位置 |
|----------|------------------|----------|----------|----------|
| 错误日志 | 50MB | 达到大小限制或每日 | 90天 | D:\SQLLogs\Archive\Error |
| SQL Agent日志 | 10MB | 达到大小限制或每日 | 30天 | D:\SQLLogs\Archive\Agent |
| 查询日志 | 100MB | 达到大小限制 | 7天 | D:\SQLLogs\Archive\Query |
| 审计日志 | 200MB | 达到大小限制 | 365天 | D:\SQLLogs\Archive\Audit |

### 3.4 事务日志管理

```sql
-- 查看事务日志空间使用
DBCC SQLPERF(LOGSPACE);

-- 收缩事务日志（仅在必要时执行）
USE ART_CONTEST;
GO
BACKUP LOG ART_CONTEST TO DISK = 'D:\SQLBackup\Logs\ART_CONTEST_LOG.trn';
GO
DBCC SHRINKFILE (ART_CONTEST_Log, 100);  -- 收缩到100MB
GO

-- 设置事务日志自动增长
ALTER DATABASE ART_CONTEST 
MODIFY FILE (NAME = ART_CONTEST_Log, FILEGROWTH = 1024MB);  -- 每次增长1GB
```

### 3.5 日志清理自动化流程

#### 3.5.1 清理脚本

```sql
-- 清理过期的备份文件
DECLARE @CleanupPath VARCHAR(500) = 'D:\SQLBackup\Local\';
DECLARE @RetentionDays INT = 3;

EXEC master.dbo.xp_delete_file 
    0,  -- 文件类型: 0=备份文件, 1=报告文件
    @CleanupPath,
    'bak',  -- 扩展名
    DATEADD(DAY, -@RetentionDays, GETDATE()),
    1;  -- 子目录递归

EXEC master.dbo.xp_delete_file 
    0,
    @CleanupPath,
    'trn',  -- 事务日志备份
    DATEADD(DAY, -@RetentionDays, GETDATE()),
    1;
```

#### 3.5.2 清理计划

| 清理项 | 执行频率 | 保留期限 | 执行者 |
|--------|----------|----------|--------|
| 事务日志备份 | 每日 | 3天 | SQL Server Agent |
| 全量备份 | 每周 | 4周 | SQL Server Agent |
| 错误日志归档 | 每日 | 90天 | SQL Server Agent |
| 审计日志归档 | 每月 | 365天 | DBA |

---

## 4. 实施操作指南

### 4.1 备份脚本

#### 4.1.1 全量备份脚本

```sql
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
```

#### 4.1.2 差异备份脚本

```sql
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
```

#### 4.1.3 事务日志备份脚本

```sql
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
```

### 4.2 SQL Server Agent 作业配置

#### 4.2.1 作业计划配置

| 作业名称 | 类型 | 调度频率 | 执行时间 |
|----------|------|----------|----------|
| DB_Backup_Full | 全量备份 | 每周 | 周一、周六 00:00 |
| DB_Backup_Diff | 差异备份 | 每日 | 周二至周五 02:00 |
| DB_Backup_Log | 事务日志备份 | 每15分钟 | 持续执行 |
| DB_Log_Cleanup | 日志清理 | 每日 | 01:00 |
| DB_Backup_Verify | 备份验证 | 每日 | 03:00 |

#### 4.2.2 作业创建脚本

```sql
-- 创建全量备份作业
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'DB_Backup_Full',
    @description = N'ART_CONTEST 数据库全量备份',
    @owner_login_name = N'sa';

-- 添加作业步骤
EXEC dbo.sp_add_jobstep
    @job_name = N'DB_Backup_Full',
    @step_name = N'执行全量备份',
    @subsystem = N'TSQL',
    @command = N'-- 全量备份脚本（引用外部脚本）
EXEC master.dbo.xp_cmdshell ''sqlcmd -S DESKTOP-4FGJ7U3 -d ART_CONTEST -i "D:\SQLBackup\Scripts\backup_full.sql"''',
    @retry_attempts = 3,
    @retry_interval = 5;

-- 添加调度（每周一、周六 00:00）
EXEC dbo.sp_add_schedule
    @schedule_name = N'Weekly_Full_Backup',
    @freq_type = 8,  -- 每周
    @freq_interval = 65,  -- 周一 + 周六
    @freq_recurrence_factor = 1,
    @active_start_time = 000000;

EXEC dbo.sp_attach_schedule
    @job_name = N'DB_Backup_Full',
    @schedule_name = N'Weekly_Full_Backup';

EXEC dbo.sp_add_jobserver
    @job_name = N'DB_Backup_Full',
    @server_name = N'DESKTOP-4FGJ7U3';

-- =============================================
-- 4.2.2.1 差异备份作业创建
-- =============================================

-- 创建差异备份作业
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'DB_Backup_Diff',
    @description = N'ART_CONTEST 数据库差异备份',
    @owner_login_name = N'sa';

-- 添加作业步骤
EXEC dbo.sp_add_jobstep
    @job_name = N'DB_Backup_Diff',
    @step_name = N'执行差异备份',
    @subsystem = N'TSQL',
    @command = N'EXEC master.dbo.xp_cmdshell ''sqlcmd -S DESKTOP-4FGJ7U3 -d ART_CONTEST -i "D:\SQLBackup\Scripts\backup_diff.sql"''',
    @retry_attempts = 3,
    @retry_interval = 5;

-- 添加调度（周二至周五 02:00）
EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily_Diff_Backup',
    @freq_type = 4,  -- 每日
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 020000;

EXEC dbo.sp_attach_schedule
    @job_name = N'DB_Backup_Diff',
    @schedule_name = N'Daily_Diff_Backup';

EXEC dbo.sp_add_jobserver
    @job_name = N'DB_Backup_Diff',
    @server_name = N'DESKTOP-4FGJ7U3';

-- =============================================
-- 4.2.2.2 事务日志备份作业创建
-- =============================================

-- 创建事务日志备份作业
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'DB_Backup_Log',
    @description = N'ART_CONTEST 数据库事务日志备份',
    @owner_login_name = N'sa';

-- 添加作业步骤
EXEC dbo.sp_add_jobstep
    @job_name = N'DB_Backup_Log',
    @step_name = N'执行事务日志备份',
    @subsystem = N'TSQL',
    @command = N'EXEC master.dbo.xp_cmdshell ''sqlcmd -S DESKTOP-4FGJ7U3 -d ART_CONTEST -i "D:\SQLBackup\Scripts\backup_log.sql"''',
    @retry_attempts = 3,
    @retry_interval = 5;

-- 添加调度（每15分钟）
EXEC dbo.sp_add_schedule
    @schedule_name = N'Every_15_Minutes_Log_Backup',
    @freq_type = 4,  -- 每日
    @freq_interval = 1,
    @freq_subday_type = 4,  -- 分钟
    @freq_subday_interval = 15,
    @active_start_time = 000000;

EXEC dbo.sp_attach_schedule
    @job_name = N'DB_Backup_Log',
    @schedule_name = N'Every_15_Minutes_Log_Backup';

EXEC dbo.sp_add_jobserver
    @job_name = N'DB_Backup_Log',
    @server_name = N'DESKTOP-4FGJ7U3';

-- =============================================
-- 4.2.2.3 事件日志收集作业创建
-- =============================================

-- 创建SQL Server错误日志收集作业
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'DB_ErrorLog_Collection',
    @description = N'收集SQL Server错误日志并归档',
    @owner_login_name = N'sa';

-- 添加作业步骤
EXEC dbo.sp_add_jobstep
    @job_name = N'DB_ErrorLog_Collection',
    @step_name = N'读取并归档错误日志',
    @subsystem = N'TSQL',
    @command = N'
    DECLARE @LogDate VARCHAR(8) = CONVERT(VARCHAR(8), GETDATE(), 112);
    DECLARE @ArchivePath VARCHAR(500) = ''D:\SQLLogs\Archive\Error\'';
    DECLARE @ArchiveFile VARCHAR(500) = @ArchivePath + ''ERROR_LOG_'' + @LogDate + ''.xel'';
    
    -- 创建归档目录（如果不存在）
    EXEC master.dbo.xp_create_subdir @ArchivePath;
    
    -- 导出错误日志到文件
    EXEC master.dbo.xp_readerrlog 0, 1, NULL, NULL, NULL, NULL, ''D:\SQLLogs\ERROR_LOG_'' + @LogDate + ''.log'';
    ',
    @retry_attempts = 3,
    @retry_interval = 5;

-- 添加调度（每日执行）
EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily_ErrorLog_Collection',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 010000;

EXEC dbo.sp_attach_schedule
    @job_name = N'DB_ErrorLog_Collection',
    @schedule_name = N'Daily_ErrorLog_Collection';

EXEC dbo.sp_add_jobserver
    @job_name = N'DB_ErrorLog_Collection',
    @server_name = N'DESKTOP-4FGJ7U3';
```

### 4.2.3 日志清理详细机制

#### 4.2.3.1 日志清理触发条件

| 触发类型 | 触发条件 | 优先级 | 说明 |
|----------|----------|--------|------|
| **定时触发** | 每日01:00执行 | 高 | 通过SQL Server Agent作业定时执行 |
| **空间触发** | 磁盘空间使用率>80% | 紧急 | 触发时立即执行清理 |
| **大小触发** | 单个日志文件>500MB | 高 | 日志文件达到阈值时触发 |
| **手动触发** | DBA确认需要清理 | 中 | 紧急情况下的手动干预 |

#### 4.2.3.2 不同类型日志清理策略

| 日志类型 | 存储位置 | 文件大小限制 | 保留期限 | 清理频率 | 归档策略 |
|----------|----------|--------------|----------|----------|----------|
| **SQL Server错误日志** | D:\SQLLogs\Error\ | 50MB/文件 | 90天 | 每日检查 | 压缩后归档到D:\SQLLogs\Archive\Error\ |
| **SQL Server Agent日志** | D:\SQLLogs\Agent\ | 10MB/文件 | 30天 | 每日检查 | 自动覆盖 |
| **Windows事件日志** | 系统事件查看器 | - | 7天 | 每周 | 导出为EVTX文件后删除 |
| **跟踪日志** | D:\SQLLogs\Trace\ | 100MB/文件 | 7天 | 每日检查 | 超过阈值自动轮转 |
| **审核日志** | D:\SQLLogs\Audit\ | 200MB/文件 | 365天 | 每月 | 加密归档 |
| **事务日志备份** | D:\SQLBackup\Logs\ | - | 3天 | 每15分钟备份 | 备份后自动删除超过3天的文件 |

#### 4.2.3.3 日志清理自动化实现

```sql
-- =============================================
-- 日志清理存储过程
-- 文件位置: D:\SQLBackup\Scripts\Log_Cleanup.sql
-- =============================================
CREATE PROCEDURE sp_Log_Cleanup
    @ErrorLogRetentionDays INT = 90,
    @AgentLogRetentionDays INT = 30,
    @TraceLogRetentionDays INT = 7,
    @BackupLogRetentionDays INT = 3
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CleanupDate DATETIME;
    DECLARE @Cmd VARCHAR(8000);
    DECLARE @ArchivePath VARCHAR(500);
    
    -- 1. 清理SQL Server错误日志归档
    SET @ArchivePath = 'D:\SQLLogs\Archive\Error\';
    SET @CleanupDate = DATEADD(DAY, -@ErrorLogRetentionDays, GETDATE());
    
    -- 删除超过保留期的错误日志文件
    EXEC master.dbo.xp_delete_file 
        0,  -- 备份文件类型
        @ArchivePath,
        'log',
        @CleanupDate,
        1;
    
    -- 2. 清理SQL Server Agent日志
    SET @ArchivePath = 'D:\SQLLogs\Archive\Agent\';
    SET @CleanupDate = DATEADD(DAY, -@AgentLogRetentionDays, GETDATE());
    
    EXEC master.dbo.xp_delete_file 
        0,
        @ArchivePath,
        'log',
        @CleanupDate,
        1;
    
    -- 3. 清理跟踪日志
    SET @ArchivePath = 'D:\SQLLogs\Trace\';
    SET @CleanupDate = DATEADD(DAY, -@TraceLogRetentionDays, GETDATE());
    
    EXEC master.dbo.xp_delete_file 
        0,
        @ArchivePath,
        'trc',
        @CleanupDate,
        1;
    
    -- 4. 清理事务日志备份文件
    SET @ArchivePath = 'D:\SQLBackup\Logs\';
    SET @CleanupDate = DATEADD(DAY, -@BackupLogRetentionDays, GETDATE());
    
    EXEC master.dbo.xp_delete_file 
        0,
        @ArchivePath,
        'trn',
        @CleanupDate,
        1;
    
    -- 5. 清理过期的备份文件
    SET @ArchivePath = 'D:\SQLBackup\Local\';
    SET @CleanupDate = DATEADD(DAY, -28, GETDATE());  -- 4周
    
    EXEC master.dbo.xp_delete_file 
        0,
        @ArchivePath,
        'bak',
        @CleanupDate,
        1;
    
    PRINT '日志清理完成 - ' + CONVERT(VARCHAR(23), GETDATE(), 121);
END
GO

-- 创建日志清理作业
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'DB_Log_Cleanup',
    @description = N'定期清理过期日志文件',
    @owner_login_name = N'sa';

EXEC dbo.sp_add_jobstep
    @job_name = N'DB_Log_Cleanup',
    @step_name = N'执行日志清理',
    @subsystem = N'TSQL',
    @command = N'EXEC sp_Log_Cleanup',
    @retry_attempts = 3,
    @retry_interval = 5;

-- 添加调度（每日01:00执行）
EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily_Log_Cleanup',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 010000;

EXEC dbo.sp_attach_schedule
    @job_name = N'DB_Log_Cleanup',
    @schedule_name = N'Daily_Log_Cleanup';

EXEC dbo.sp_add_jobserver
    @job_name = N'DB_Log_Cleanup',
    @server_name = N'DESKTOP-4FGJ7U3';
```

#### 4.2.3.4 日志清理前的数据备份与归档方案

```
┌─────────────────────────────────────────────────────────────────┐
│                    日志归档流程图                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  日志文件生成                                                    │
│       │                                                         │
│       ▼                                                         │
│  判断是否需要归档                                                │
│       │                                                         │
│       ├───<保留期内>───► 继续使用（不处理）                       │
│       │                                                         │
│       └───>保留期外>───► 压缩打包                                │
│                           │                                     │
│                           ▼                                     │
│                      移动到归档目录                              │
│                           │                                     │
│                           ▼                                     │
│                   更新归档记录表                                │
│                           │                                     │
│                           ▼                                     │
│                      删除原文件                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**归档记录表结构：**

```sql
-- 创建日志归档记录表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'LogArchive')
BEGIN
    CREATE TABLE dbo.LogArchive (
        LogArchiveId INT IDENTITY(1,1) PRIMARY KEY,
        LogType VARCHAR(30) NOT NULL,  -- ERROR, AGENT, TRACE, AUDIT
        OriginalPath VARCHAR(500) NOT NULL,
        ArchivePath VARCHAR(500) NOT NULL,
        FileName VARCHAR(200) NOT NULL,
        FileSizeKB DECIMAL(10,2) NOT NULL,
        Compressed BIT NOT NULL DEFAULT 0,  -- 是否已压缩
        ArchiveDate DATETIME NOT NULL DEFAULT GETDATE(),
        RetentionUntil DATE NOT NULL,  -- 保留截止日期
        ArchivedBy VARCHAR(50) NOT NULL DEFAULT SUSER_NAME()
    );
END
GO

-- 归档存储过程
CREATE PROCEDURE sp_Archive_Logs
    @LogType VARCHAR(30),
    @SourcePath VARCHAR(500),
    @ArchivePath VARCHAR(500),
    @RetentionDays INT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @FileName VARCHAR(200);
    DECLARE @FullSourcePath VARCHAR(1000);
    DECLARE @FullArchivePath VARCHAR(1000);
    DECLARE @FileSizeKB DECIMAL(10,2);
    DECLARE @RetentionUntil DATE;
    
    SET @RetentionUntil = DATEADD(DAY, @RetentionDays, GETDATE());
    
    -- 获取源目录下的文件列表
    CREATE TABLE #FileList (
        FileName VARCHAR(200),
        Depth INT,
        [File Size] BIGINT
    );
    
    INSERT INTO #FileList
    EXEC xp_dirtree @SourcePath, 1, 1;
    
    -- 遍历文件并归档
    DECLARE file_cursor CURSOR FOR
    SELECT FileName FROM #FileList WHERE [File Size] > 0;
    
    OPEN file_cursor;
    FETCH NEXT FROM file_cursor INTO @FileName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @FullSourcePath = @SourcePath + @FileName;
        SET @FullArchivePath = @ArchivePath + @FileName + '.gz';
        
        -- 获取文件大小
        SELECT @FileSizeKB = [File Size] / 1024.0 FROM #FileList WHERE FileName = @FileName;
        
        -- 记录归档信息
        INSERT INTO dbo.LogArchive (
            LogType,
            OriginalPath,
            ArchivePath,
            FileName,
            FileSizeKB,
            RetentionUntil
        )
        VALUES (
            @LogType,
            @FullSourcePath,
            @FullArchivePath,
            @FileName,
            @FileSizeKB,
            @RetentionUntil
        );
        
        FETCH NEXT FROM file_cursor INTO @FileName;
    END
    
    CLOSE file_cursor;
    DEALLOCATE file_cursor;
    
    DROP TABLE #FileList;
    
    PRINT '归档完成：' + @LogType;
END
GO
```

#### 4.2.3.5 磁盘空间紧急清理预案

```sql
-- 紧急磁盘空间清理存储过程
CREATE PROCEDURE sp_Emergency_Disk_Cleanup
    @TargetFreeSpaceGB DECIMAL(10,2) = 50.0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentFreeSpaceGB DECIMAL(10,2);
    DECLARE @RequiredSpaceGB DECIMAL(10,2);
    
    -- 获取当前D盘可用空间
    SELECT @CurrentFreeSpaceGB = CAST(available_bytes / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(10,2))
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id)
    WHERE volume_mount_point = 'D:\'
    GROUP BY volume_mount_point;
    
    SET @RequiredSpaceGB = @CurrentFreeSpaceGB + @TargetFreeSpaceGB;
    
    PRINT '当前D盘可用空间: ' + CAST(@CurrentFreeSpaceGB AS VARCHAR) + ' GB';
    PRINT '目标可用空间: ' + CAST(@RequiredSpaceGB AS VARCHAR) + ' GB';
    
    -- 紧急清理步骤
    -- 1. 先清理事务日志备份（最快速释放空间）
    PRINT '步骤1: 清理最旧的事务日志备份...';
    EXEC master.dbo.xp_delete_file 0, 'D:\SQLBackup\Logs\', 'trn', DATEADD(DAY, -1, GETDATE()), 1;
    
    -- 2. 收缩事务日志
    PRINT '步骤2: 收缩事务日志...';
    DECLARE @LogFileName VARCHAR(100);
    SELECT @LogFileName = name FROM sys.master_files WHERE database_id = DB_ID('ART_CONTEST') AND type = 1;
    BACKUP LOG ART_CONTEST TO DISK = 'D:\SQLBackup\Logs\EMERGENCY_LOG.trn';
    DBCC SHRINKFILE (@LogFileName, 1024);  -- 收缩到1GB
    
    -- 3. 清理旧的备份文件
    PRINT '步骤3: 清理7天前的备份文件...';
    EXEC master.dbo.xp_delete_file 0, 'D:\SQLBackup\Local\', 'bak', DATEADD(DAY, -7, GETDATE()), 1;
    
    -- 4. 清理临时文件
    PRINT '步骤4: 清理临时文件...';
    EXEC master.dbo.xp_cmdshell 'del /q/f/s %TEMP%\*.tmp';
    
    PRINT '紧急清理完成';
END
GO
```

### 4.3 监控告警机制

#### 4.3.1 磁盘空间监控（改进版 - 显示所有磁盘状态）

```sql
-- =============================================
-- 磁盘空间监控脚本（显示所有磁盘状态）
-- 文件位置: D:\SQLBackup\Scripts\Disk_Monitor.sql
-- =============================================
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
```

#### 4.3.2 仅显示告警磁盘的版本

```sql
-- 仅显示超过阈值的磁盘（用于告警触发）
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
        CAST(SUM(available_bytes) / 1024.0 / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS AvailableGB,
        CAST((1 - (SUM(available_bytes) * 1.0 / SUM(total_bytes))) * 100 AS DECIMAL(5,2)) AS UsedPercent
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id)
    WHERE volume_mount_point IN ('D:\', 'E:\')
    GROUP BY volume_mount_point
) AS VolumeStats
WHERE UsedPercent > 85;  -- 仅显示超过85%的磁盘
```

### 4.3 监控告警机制

#### 4.3.1 磁盘空间监控

```sql
-- 磁盘空间监控脚本
SELECT 
    DISTINCT 
    volume_mount_point AS Drive,
    CAST(total_bytes / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS TotalGB,
    CAST(available_bytes / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS AvailableGB,
    CAST((1 - (available_bytes * 1.0 / total_bytes)) * 100 AS DECIMAL(5,2)) AS UsedPercent
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id)
WHERE volume_mount_point IN ('D:\', 'E:\')  -- 监控关键磁盘
HAVING CAST((1 - (available_bytes * 1.0 / total_bytes)) * 100 AS DECIMAL(5,2)) > 85;  -- 超过85%告警
```

#### 4.3.2 告警规则配置

| 告警项 | 阈值 | 告警方式 | 通知对象 |
|--------|------|----------|----------|
| 磁盘空间使用率 | >85% | 邮件 + 短信 | DBA、运维值班 |
| 备份失败 | 任何失败 | 邮件 + 短信 | DBA |
| 事务日志增长异常 | 1小时增长>5GB | 邮件 | DBA |
| SQL Server Agent停止 | 服务停止 | 短信 | DBA、运维值班 |
| 数据库备份延迟 | 超过24小时无备份 | 邮件 + 短信 | DBA |

### 4.4 异常处理流程

#### 4.4.1 备份失败处理流程

```
┌──────────────────────────────────────────────────────────────┐
│                   备份失败处理流程                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  备份作业失败                                                 │
│      │                                                       │
│      ▼                                                       │
│  发送告警通知                                                 │
│      │                                                       │
│      ▼                                                       │
│  DBA确认告警                                                  │
│      │                                                       │
│      ├───是───► 检查备份存储是否可用                          │
│      │               │                                       │
│      │               ├───可用───► 手动执行备份                │
│      │               │                                       │
│      │               └───不可用───► 切换备用存储              │
│      │                                                       │
│      └───否───► 检查备份脚本错误                              │
│                     │                                        │
│                     ▼                                        │
│                修复脚本问题                                   │
│                     │                                        │
│                     ▼                                        │
│                重新执行备份                                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

#### 4.4.2 紧急恢复预案

| 场景 | 恢复步骤 | 负责人 |
|------|----------|--------|
| 数据库损坏 | 1. 停止应用 2. 执行全量恢复 3. 应用事务日志 4. 验证数据完整性 5. 启动应用 | DBA |
| 磁盘空间不足 | 1. 紧急清理临时文件 2. 收缩日志文件 3. 转移非关键数据 4. 扩展磁盘容量 | 运维工程师 |
| 备份丢失 | 1. 使用异地备份 2. 执行恢复 3. 验证数据完整性 | DBA |

---

## 5. 责任分工与执行时间表

### 5.1 责任分工

| 角色 | 职责 |
|------|------|
| **DBA** | 备份策略制定、备份验证、恢复演练、故障恢复 |
| **运维工程师** | 存储管理、监控配置、告警处理、日常巡检 |
| **开发工程师** | 协助恢复验证、应用兼容性测试 |
| **系统架构师** | 整体架构设计、容灾方案规划 |
| **安全管理员** | 审计日志管理、访问权限控制 |

### 5.2 执行时间表

| 时间 | 任务 | 负责人 |
|------|------|--------|
| 00:00 | 全量备份（周一、周六） | SQL Server Agent |
| 02:00 | 差异备份（周二至周五） | SQL Server Agent |
| 每15分钟 | 事务日志备份 | SQL Server Agent |
| 01:00 | 日志清理 | SQL Server Agent |
| 09:00 | 日常巡检 | 运维工程师 |
| 每月 | 全量恢复演练 | DBA |
| 每季度 | 时间点恢复演练 | DBA |
| 每半年 | 灾难恢复演练 | 全团队 |
| 每年 | 备份策略评审 | DBA、架构师 |

---

## 6. 效果评估指标与持续优化

### 6.1 关键指标

| 指标 | 目标值 | 监控频率 |
|------|--------|----------|
| 备份成功率 | ≥99.9% | 每日 |
| 备份恢复时间 | ≤30分钟 | 每月 |
| 磁盘空间使用率 | ≤80% | 实时 |
| 事务日志增长速率 | ≤1GB/小时 | 每日 |
| 备份验证通过率 | 100% | 每日 |

### 6.2 优化建议

1. **定期评审备份策略**：根据业务增长情况调整备份频率和保留周期
2. **优化备份存储**：采用增量备份策略减少存储成本
3. **自动化监控**：部署自动化监控系统，实现智能告警
4. **文档更新**：定期更新备份恢复文档，确保与实际环境一致
5. **培训演练**：定期组织团队培训和演练，提高应急响应能力

---

## 附录

### A. 备份历史表结构

```sql
CREATE TABLE dbo.BackupHistory (
    BackupHistoryId INT IDENTITY(1,1) PRIMARY KEY,
    BackupType VARCHAR(20) NOT NULL,  -- FULL, DIFF, LOG
    BackupPath VARCHAR(500) NOT NULL,
    BackupSizeMB DECIMAL(10,2) NOT NULL,
    BackupDate DATETIME NOT NULL DEFAULT GETDATE(),
    VerifyStatus BIT NOT NULL DEFAULT 0,  -- 0=未验证, 1=已验证
    VerifyDate DATETIME NULL
);
```

### B. 日志归档表结构

```sql
CREATE TABLE dbo.LogArchive (
    LogArchiveId INT IDENTITY(1,1) PRIMARY KEY,
    LogType VARCHAR(30) NOT NULL,  -- ERROR, AGENT, QUERY, AUDIT
    OriginalPath VARCHAR(500) NOT NULL,
    ArchivePath VARCHAR(500) NOT NULL,
    FileSizeKB DECIMAL(10,2) NOT NULL,
    ArchiveDate DATETIME NOT NULL DEFAULT GETDATE(),
    RetentionUntil DATE NOT NULL
);
```

### C. 脚本文件清单

| 文件路径 | 说明 |
|----------|------|
| D:\SQLScripts\Backup_Full.sql | 全量备份脚本 |
| D:\SQLScripts\Backup_Diff.sql | 差异备份脚本 |
| D:\SQLScripts\Backup_Log.sql | 事务日志备份脚本 |
| D:\SQLScripts\Log_Cleanup.sql | 日志清理脚本 |
| D:\SQLScripts\Disk_Monitor.sql | 磁盘空间监控脚本 |
