# SQL Server 安全管理模块

本目录包含数据库安全管理的完整文档和SQL脚本，涵盖用户与角色管理、行级安全性、透明数据加密（TDE）和审计追踪四大核心领域。

## 目录结构

```
security/
├── security_guide.md          # 安全管理理论文档
├── user_role_management.sql   # 用户与角色管理SQL脚本
├── row_level_security.sql     # 行级安全性SQL脚本
├── tde_implementation.sql     # 透明数据加密SQL脚本
├── audit_tracking.sql         # 审计追踪SQL脚本
└── README.md                  # 本文件
```

## 文件说明

### 1. security_guide.md
安全管理理论文档，包含：
- 用户账户创建规范和密码策略
- 角色定义与权限分配机制
- 行级安全性策略设计
- TDE加密方案与密钥管理
- 审计追踪策略与日志管理

### 2. user_role_management.sql
用户与角色管理脚本，包含：
- 登录名和用户创建
- 自定义角色创建
- 权限分配（最小权限原则）
- 用户生命周期管理
- 权限审计查询

### 3. row_level_security.sql
行级安全性脚本，包含：
- 基于部门的访问控制
- 基于用户的访问控制（只能访问自己创建的数据）
- 基于角色的访问控制
- 动态数据脱敏
- 时间敏感数据访问控制

### 4. tde_implementation.sql
透明数据加密脚本，包含：
- 数据库主密钥创建
- 服务器证书管理
- 数据库加密密钥创建
- TDE启用与监控
- 列级加密实现
- 密钥轮换策略

### 5. audit_tracking.sql
审计追踪脚本，包含：
- SQL Server审计对象创建
- 服务器级审计规范
- 数据库级审计规范
- 自定义审计日志表
- 触发器审计
- 扩展事件审计
- 审计报告查询

## 使用方法

### 1. 用户与角色管理

```sql
-- 创建登录名和用户
USE master;
GO
CREATE LOGIN [DEV_UserName_01] WITH PASSWORD = 'P@ssw0rd2026!';
GO

USE ART_CONTEST;
GO
CREATE USER [DEV_UserName_01] FOR LOGIN [DEV_UserName_01];
GO

-- 分配权限
GRANT SELECT ON [dbo].[Artists] TO [DEV_UserName_01];
GO
```

### 2. 行级安全性

```sql
-- 创建安全函数
CREATE OR ALTER FUNCTION [dbo].[fn_DepartmentSecurityPredicate]
(@Department NVARCHAR(50))
RETURNS TABLE WITH SCHEMABINDING
AS
RETURN (
    SELECT 1 AS Result
    WHERE IS_MEMBER('db_owner') = 1
        OR @Department = (SELECT Department FROM [dbo].[UserDepartment] 
                          WHERE UserName = SUSER_SNAME())
);
GO

-- 创建安全策略
CREATE SECURITY POLICY [DepartmentSecurityPolicy]
    ADD FILTER PREDICATE [dbo].[fn_DepartmentSecurityPredicate]([Department])
    ON [dbo].[DepartmentData]
    WITH (STATE = ON);
GO
```

### 3. TDE加密

```sql
-- 创建主密钥（master数据库）
USE master;
GO
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'M@sterK3y2026!';
GO

-- 创建证书
CREATE CERTIFICATE TDE_Certificate_ART_CONTEST
    WITH SUBJECT = 'TDE Certificate for ART_CONTEST';
GO

-- 创建数据库加密密钥
USE ART_CONTEST;
GO
CREATE DATABASE ENCRYPTION KEY
    WITH ALGORITHM = AES_256
    ENCRYPTION BY SERVER CERTIFICATE TDE_Certificate_ART_CONTEST;
GO

-- 启用加密
ALTER DATABASE ART_CONTEST SET ENCRYPTION ON;
GO
```

### 4. 审计追踪

```sql
-- 创建审计
CREATE SERVER AUDIT [ART_CONTEST_Server_Audit]
TO FILE (FILEPATH = 'D:\SQLAudit\')
WITH (ON_FAILURE = CONTINUE);
GO

-- 启用审计
ALTER SERVER AUDIT [ART_CONTEST_Server_Audit] WITH (STATE = ON);
GO

-- 查询审计日志
SELECT * FROM sys.fn_get_audit_file('D:\SQLAudit\*.sqlaudit', DEFAULT, DEFAULT);
GO
```

## 实施建议

### 用户与角色管理
1. 遵循最小权限原则，只授予必要权限
2. 定期进行权限审计（建议每季度）
3. 离职人员账户及时禁用
4. 使用角色进行权限管理，避免直接授权

### 行级安全性
1. 对敏感表配置行级安全策略
2. 使用安全函数定义访问规则
3. 测试权限边界确保数据隔离正确

### TDE加密
1. 启用TDE前备份证书和私钥
2. 定期轮换密钥（建议每年）
3. 监控加密状态和性能影响

### 审计追踪
1. 配置全面的审计策略
2. 定期清理旧日志（建议保留90天）
3. 设置告警规则监控异常行为

## 环境要求

- SQL Server 2016 或更高版本
- 数据库兼容级别 130 或更高
- SQL Server Agent（用于定期任务）
- 足够的磁盘空间存储审计日志

## 学习路径

1. **基础篇**：用户与角色管理 → 理解权限体系
2. **进阶篇**：行级安全性 → 实现数据隔离
3. **高级篇**：TDE加密 → 保护数据安全
4. **监控篇**：审计追踪 → 追踪安全事件

## 注意事项

- 执行脚本前请确认数据库备份
- TDE加密需要服务器级别权限
- 审计日志会占用磁盘空间，需定期清理
- 密钥管理非常重要，丢失密钥会导致数据无法恢复
