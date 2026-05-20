# 企业异构数据集成模块

本模块包含企业级数据集成方案的完整文档和SQL脚本，涵盖SSIS、BCP、BULK INSERT、OPENROWSET、OPENDATASOURCE等核心技术。

## 目录结构

```
integration/
├── integration_guide.md        # 技术分析文档
├── ssis_integration.sql        # SSIS配置与使用脚本
├── bcp_bulk_insert.sql         # BCP与BULK INSERT脚本
├── cross_data_source.sql       # OPENROWSET与OPENDATASOURCE脚本
├── data_sync_solution.sql      # 数据同步方案脚本
└── README.md                   # 使用说明文档
```

## 文件说明

| 文件 | 描述 |
|------|------|
| `integration_guide.md` | 完整的技术分析文档，包含SSIS、BCP、BULK INSERT、OPENROWSET、OPENDATASOURCE的功能介绍、适用场景、方案设计等 |
| `ssis_integration.sql` | SSIS配置脚本，包含目录创建、环境变量配置、包执行、作业调度等 |
| `bcp_bulk_insert.sql` | BCP命令和BULK INSERT脚本，包含批量导入、格式文件、错误处理等 |
| `cross_data_source.sql` | OPENROWSET和OPENDATASOURCE脚本，包含跨数据源查询、链接服务器配置等 |
| `data_sync_solution.sql` | 企业级数据同步方案，包含同步日志、配置管理、增量同步等 |

## 使用方法

### 1. SSIS集成

```sql
-- 创建SSIS目录
USE master;
GO
EXEC [SSISDB].[catalog].[create_catalog] 
    @catalog_name = 'SSISDB',
    @password = 'YourPassword';
GO

-- 创建环境变量
USE SSISDB;
GO
EXEC [catalog].[create_environment] 
    @environment_name = 'ART_CONTEST_Env',
    @folder_name = 'ART_CONTEST_Integration';
GO
```

### 2. BCP批量导入

```bash
# 导出数据
bcp ART_CONTEST.dbo.Artists out "D:\DataExport\Artists.csv" -S localhost -d ART_CONTEST -T -c -t,

# 导入数据
bcp ART_CONTEST.dbo.Artists in "D:\DataImport\Artists.csv" -S localhost -d ART_CONTEST -T -c -t, -b 10000
```

### 3. BULK INSERT批量导入

```sql
USE ART_CONTEST;
GO

BULK INSERT [dbo].[Artists_Staging]
FROM 'D:\DataImport\Artists.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,
    TABLOCK,
    BATCHSIZE = 10000
);
GO
```

### 4. 跨数据源查询

```sql
-- 使用OPENROWSET读取Excel
SELECT * FROM OPENROWSET(
    'Microsoft.ACE.OLEDB.12.0',
    'Excel 12.0;Database=D:\DataImport\Artists.xlsx',
    'SELECT * FROM [Sheet1$]'
);
GO

-- 使用OPENDATASOURCE查询远程数据库
SELECT * FROM OPENDATASOURCE(
    'SQLNCLI',
    'Data Source=REMOTE_SERVER;Integrated Security=SSPI'
).RemoteDB.dbo.Artists;
GO
```

### 5. 执行数据同步

```sql
-- 执行增量同步
EXEC [dbo].[sp_DataSync] 
    @SyncName = 'Daily_Sync',
    @SyncType = 'Incremental',
    @BatchSize = 10000;
GO

-- 执行全量同步
EXEC [dbo].[sp_DataSync] 
    @SyncName = 'Full_Sync',
    @SyncType = 'Full',
    @BatchSize = 50000;
GO
```

## 技术选型建议

| 数据量 | 推荐技术 | 说明 |
|-------|---------|------|
| 小量（<1万行） | SSIS / OPENROWSET | 灵活可控，支持复杂转换 |
| 中量（1万-100万行） | SSIS / BULK INSERT | 平衡性能和灵活性 |
| 大量（>100万行） | BCP / BULK INSERT | 最高性能，最小开销 |

## 安全注意事项

1. **权限管理**：确保服务账户仅授予必要的权限
2. **连接字符串**：避免硬编码敏感信息，使用配置文件或环境变量
3. **数据加密**：传输使用SSL/TLS，存储使用TDE
4. **审计日志**：记录所有数据集成操作

## 环境要求

- SQL Server 2016 或更高版本
- SQL Server Integration Services (SSIS)
- 必要的OLEDB驱动程序（Excel、Oracle、MySQL等）
- SQL Server Agent（用于作业调度）

## 学习路径

1. **入门篇**：学习BCP和BULK INSERT基础用法
2. **进阶篇**：掌握OPENROWSET和OPENDATASOURCE跨数据源查询
3. **高级篇**：学习SSIS企业级ETL开发
4. **实战篇**：部署完整的数据同步方案
