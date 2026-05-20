/*
ART_CONTEST 数据库设计与优化实践脚本
======================================
文件：design_optimization_examples.sql
版本：V1.0
日期：2026年5月

包含：
1. 规范化设计示例（1NF-3NF）
2. 反规范化策略示例
3. 索引设计示例
4. 数据类型选择示例
*/

USE ART_CONTEST;
GO

-- ========================================
-- 1. 规范化设计示例
-- ========================================
PRINT '========== 1. 规范化设计示例 ==========';
GO

-- 1.1 非规范化表（反例）
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'NonNormalizedData')
    DROP TABLE NonNormalizedData;

CREATE TABLE NonNormalizedData (
    artist_id INT,
    artist_name VARCHAR(100),
    team_info VARCHAR(200),  -- 包含队伍名和国家，违反1NF
    specializations VARCHAR(200),  -- 多个专长，违反1NF
    scores VARCHAR(500)  -- 多个阶段评分，违反1NF
);
PRINT '创建非规范化表 NonNormalizedData';
GO

-- 1.2 转换为1NF
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Artist_1NF')
    DROP TABLE Artist_1NF;

CREATE TABLE Artist_1NF (
    artist_id INT,
    artist_name VARCHAR(100),
    team_name VARCHAR(100),
    country_code CHAR(3),
    specialization_id VARCHAR(10),
    round_stage CHAR(2),
    score DECIMAL(5,2)
);
PRINT '创建符合1NF的表 Artist_1NF';
GO

-- 1.3 转换为2NF
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Artist_2NF')
    DROP TABLE Artist_2NF;
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Scores_2NF')
    DROP TABLE Scores_2NF;

CREATE TABLE Artist_2NF (
    artist_id INT PRIMARY KEY,
    artist_name VARCHAR(100),
    team_name VARCHAR(100),
    country_code CHAR(3),
    specialization_id VARCHAR(10)
);

CREATE TABLE Scores_2NF (
    artist_id INT,
    round_stage CHAR(2),
    score DECIMAL(5,2),
    PRIMARY KEY (artist_id, round_stage)
);
PRINT '创建符合2NF的表 Artist_2NF 和 Scores_2NF';
GO

-- 1.4 转换为3NF
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Artist_3NF')
    DROP TABLE Artist_3NF;
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Team_3NF')
    DROP TABLE Team_3NF;
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Specialization_3NF')
    DROP TABLE Specialization_3NF;
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Scores_3NF')
    DROP TABLE Scores_3NF;

CREATE TABLE Team_3NF (
    team_id INT PRIMARY KEY,
    team_name VARCHAR(100),
    country_code CHAR(3)
);

CREATE TABLE Specialization_3NF (
    specialization_id VARCHAR(10) PRIMARY KEY,
    specialization_name VARCHAR(50)
);

CREATE TABLE Artist_3NF (
    artist_id INT PRIMARY KEY,
    artist_name VARCHAR(100),
    team_id INT FOREIGN KEY REFERENCES Team_3NF(team_id),
    specialization_id VARCHAR(10) FOREIGN KEY REFERENCES Specialization_3NF(specialization_id)
);

CREATE TABLE Scores_3NF (
    artist_id INT FOREIGN KEY REFERENCES Artist_3NF(artist_id),
    round_stage CHAR(2),
    score DECIMAL(5,2),
    PRIMARY KEY (artist_id, round_stage)
);
PRINT '创建符合3NF的表结构';
GO

-- ========================================
-- 2. 反规范化策略示例
-- ========================================
PRINT '========== 2. 反规范化策略示例 ==========';
GO

-- 2.1 增加冗余字段
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Artist_Denorm_Redundant')
    DROP TABLE Artist_Denorm_Redundant;

CREATE TABLE Artist_Denorm_Redundant (
    artist_id INT PRIMARY KEY,
    artist_name VARCHAR(100),
    team_id INT,
    team_name VARCHAR(100),      -- 冗余字段
    country_code CHAR(3),        -- 冗余字段
    specialization_id VARCHAR(10),
    specialization_name VARCHAR(50)  -- 冗余字段
);
PRINT '创建带冗余字段的表 Artist_Denorm_Redundant';
GO

-- 2.2 创建汇总表
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Team_Score_Summary')
    DROP TABLE Team_Score_Summary;

CREATE TABLE Team_Score_Summary (
    team_id INT PRIMARY KEY,
    team_name VARCHAR(100),
    group_stage_points DECIMAL(10,2) DEFAULT 0,
    semi_final_points DECIMAL(10,2) DEFAULT 0,
    final_points DECIMAL(10,2) DEFAULT 0,
    total_points DECIMAL(10,2) DEFAULT 0,
    ranking INT,
    last_updated DATETIME DEFAULT GETDATE()
);
PRINT '创建汇总表 Team_Score_Summary';
GO

-- 2.3 汇总数据填充
INSERT INTO Team_Score_Summary (team_id, team_name)
SELECT a_team_id, team_name FROM art_team;

UPDATE Team_Score_Summary
SET 
    group_stage_points = ISNULL((SELECT total_points FROM art_team_results 
                                 WHERE a_team_id = Team_Score_Summary.team_id AND round_stage = 'G'), 0),
    semi_final_points = ISNULL((SELECT total_points FROM art_team_results 
                                 WHERE a_team_id = Team_Score_Summary.team_id AND round_stage = 'S'), 0),
    final_points = ISNULL((SELECT total_points FROM art_team_results 
                            WHERE a_team_id = Team_Score_Summary.team_id AND round_stage = 'F'), 0);

UPDATE Team_Score_Summary
SET total_points = group_stage_points + semi_final_points + final_points;

WITH RankedTeams AS (
    SELECT 
        team_id,
        RANK() OVER (ORDER BY total_points DESC) AS rnk
    FROM Team_Score_Summary
)
UPDATE Team_Score_Summary
SET ranking = RankedTeams.rnk
FROM RankedTeams
WHERE Team_Score_Summary.team_id = RankedTeams.team_id;

PRINT '汇总数据填充完成';
GO

-- 2.4 创建触发器维护汇总表
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_UpdateScoreSummary')
    DROP TRIGGER trg_UpdateScoreSummary;

CREATE TRIGGER trg_UpdateScoreSummary
ON art_team_results AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- 更新受影响的队伍
    DECLARE @TeamIDs TABLE (team_id INT);
    
    INSERT INTO @TeamIDs (team_id)
    SELECT DISTINCT a_team_id FROM inserted
    UNION
    SELECT DISTINCT a_team_id FROM deleted;
    
    -- 重新计算分数
    UPDATE Team_Score_Summary
    SET 
        group_stage_points = ISNULL((SELECT total_points FROM art_team_results 
                                     WHERE a_team_id = Team_Score_Summary.team_id AND round_stage = 'G'), 0),
        semi_final_points = ISNULL((SELECT total_points FROM art_team_results 
                                     WHERE a_team_id = Team_Score_Summary.team_id AND round_stage = 'S'), 0),
        final_points = ISNULL((SELECT total_points FROM art_team_results 
                                WHERE a_team_id = Team_Score_Summary.team_id AND round_stage = 'F'), 0),
        total_points = 0,
        last_updated = GETDATE()
    WHERE team_id IN (SELECT team_id FROM @TeamIDs);
    
    UPDATE Team_Score_Summary
    SET total_points = group_stage_points + semi_final_points + final_points
    WHERE team_id IN (SELECT team_id FROM @TeamIDs);
    
    -- 重新计算排名
    WITH RankedTeams AS (
        SELECT 
            team_id,
            RANK() OVER (ORDER BY total_points DESC) AS rnk
        FROM Team_Score_Summary
    )
    UPDATE Team_Score_Summary
    SET ranking = RankedTeams.rnk
    FROM RankedTeams
    WHERE Team_Score_Summary.team_id = RankedTeams.team_id;
END
PRINT '创建触发器 trg_UpdateScoreSummary';
GO

-- ========================================
-- 3. 索引设计示例
-- ========================================
PRINT '========== 3. 索引设计示例 ==========';
GO

-- 3.1 删除旧索引（如果存在）
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_artist_roster_team_old')
    DROP INDEX IX_artist_roster_team_old ON artist_roster;
GO

-- 3.2 创建普通索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_artist_roster_a_team_id')
BEGIN
    CREATE NONCLUSTERED INDEX IX_artist_roster_a_team_id
        ON artist_roster(a_team_id);
    PRINT '创建索引 IX_artist_roster_a_team_id';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_artist_roster_specialization')
BEGIN
    CREATE NONCLUSTERED INDEX IX_artist_roster_specialization
        ON artist_roster(specialization_id);
    PRINT '创建索引 IX_artist_roster_specialization';
END
GO

-- 3.3 创建复合索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_results_team_stage')
BEGIN
    CREATE NONCLUSTERED INDEX IX_results_team_stage
        ON art_team_results(a_team_id, round_stage);
    PRINT '创建复合索引 IX_results_team_stage';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_points_artist_stage')
BEGIN
    CREATE NONCLUSTERED INDEX IX_points_artist_stage
        ON point_details(artist_id, round_stage);
    PRINT '创建复合索引 IX_points_artist_stage';
END
GO

-- 3.4 创建覆盖索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_orders_customer_include')
BEGIN
    CREATE NONCLUSTERED INDEX IX_orders_customer_include
        ON orders(customer_id)
        INCLUDE (order_id, order_date, status);
    PRINT '创建覆盖索引 IX_orders_customer_include';
END
GO

-- 3.5 创建唯一索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_unique_artist_name')
BEGIN
    CREATE UNIQUE NONCLUSTERED INDEX IX_unique_artist_name
        ON artist_roster(artist_name);
    PRINT '创建唯一索引 IX_unique_artist_name';
END
GO

-- ========================================
-- 4. 数据类型选择示例
-- ========================================
PRINT '========== 4. 数据类型选择示例 ==========';
GO

-- 4.1 创建最佳实践示例表
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'DataTypeExamples')
    DROP TABLE DataTypeExamples;

CREATE TABLE DataTypeExamples (
    -- 数值型
    tinyint_col TINYINT,              -- 0-255，用于状态码
    int_col INT,                      -- 一般ID
    bigint_col BIGINT,                -- 大数量
    decimal_col DECIMAL(10,2),        -- 金额、评分（精确）
    float_col FLOAT,                  -- 科学计算（近似）
    bit_col BIT,                      -- 布尔值
    
    -- 字符型
    char_col CHAR(3),                 -- 固定长度编码
    varchar_col VARCHAR(100),         -- 可变长度英文
    nvarchar_col NVARCHAR(100),       -- 可变长度Unicode（中文）
    
    -- 日期时间型
    date_col DATE,                    -- 仅日期
    datetime_col DATETIME,            -- 传统日期时间
    datetime2_col DATETIME2(0),       -- 高精度日期时间
    time_col TIME,                    -- 仅时间
    
    -- 特殊类型
    guid_col UNIQUEIDENTIFIER         -- 全局唯一标识符
);
PRINT '创建数据类型示例表 DataTypeExamples';
GO

-- 4.2 ART_CONTEST 推荐数据类型表
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'ARTIST_BestPractice')
    DROP TABLE ARTIST_BestPractice;

CREATE TABLE ARTIST_BestPractice (
    artist_id INT IDENTITY(1,1) PRIMARY KEY,  -- INT足够
    artist_name NVARCHAR(100) NOT NULL,       -- 支持中文
    date_of_birth DATE,                       -- 只需日期
    senior_artist BIT DEFAULT 0,              -- 布尔值
    team_id INT,                              -- 外键
    specialization_code CHAR(2),              -- 固定长度编码
    join_date DATETIME2(0) DEFAULT GETDATE(), -- 精确到秒
    rating DECIMAL(3,1),                      -- 评分1-10
    status TINYINT DEFAULT 1                  -- 状态码
);
PRINT '创建ARTIST最佳实践表 ARTIST_BestPractice';
GO

-- ========================================
-- 5. 性能测试对比
-- ========================================
PRINT '========== 5. 性能测试对比 ==========';
GO

-- 5.1 开启统计
SET STATISTICS TIME ON;
SET STATISTICS IO ON;

-- 5.2 规范化查询（需要多表JOIN）
PRINT '--- 规范化查询 ---';
SELECT 
    ar.artist_name,
    t.team_name,
    s.specialization_name,
    pd.round_stage,
    pd.point_amt
FROM point_details pd
JOIN artist_roster ar ON pd.artist_id = ar.artist_id
JOIN art_team t ON ar.a_team_id = t.a_team_id
JOIN specialization s ON ar.specialization_id = s.specialization_id
WHERE pd.round_stage = 'G'
ORDER BY pd.point_amt DESC;

-- 5.3 反规范化查询（使用汇总表）
PRINT '--- 反规范化查询 ---';
SELECT 
    team_name,
    group_stage_points,
    total_points,
    ranking
FROM Team_Score_Summary
ORDER BY ranking;

-- 5.4 关闭统计
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

-- ========================================
-- 6. 清理测试表
-- ========================================
PRINT '========== 6. 清理测试表 ==========';
GO

DROP TABLE IF EXISTS NonNormalizedData;
DROP TABLE IF EXISTS Artist_1NF;
DROP TABLE IF EXISTS Artist_2NF;
DROP TABLE IF EXISTS Scores_2NF;
DROP TABLE IF EXISTS Artist_3NF;
DROP TABLE IF EXISTS Team_3NF;
DROP TABLE IF EXISTS Specialization_3NF;
DROP TABLE IF EXISTS Scores_3NF;
DROP TABLE IF EXISTS Artist_Denorm_Redundant;
DROP TABLE IF EXISTS Team_Score_Summary;
DROP TABLE IF EXISTS DataTypeExamples;
DROP TABLE IF EXISTS ARTIST_BestPractice;

PRINT '测试表清理完成';
PRINT '========== 所有示例执行完成 ==========';
GO