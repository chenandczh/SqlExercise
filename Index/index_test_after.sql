-- ============================================================================
-- ART_CONTEST 数据库索引优化后性能测试脚本
-- ============================================================================
-- 测试目的：对比索引优化后的查询性能
-- 测试方法：使用SET STATISTICS和执行计划收集性能指标
-- 注意：请在执行 index_optimization_script.sql 后运行此脚本
-- ============================================================================

USE ART_CONTEST;
GO

-- 清除缓存，确保测试准确性
DBCC DROPCLEANBUFFERS;
DBCC FREEPROCCACHE;
GO

-- 开启统计信息
SET STATISTICS TIME ON;
SET STATISTICS IO ON;
GO

PRINT '========================================';
PRINT '索引优化后性能测试';
PRINT '========================================';
PRINT '';

-- ============================================================================
-- 测试用例1: 查询法国的所有画家（多表JOIN）
-- 优化前：全表扫描 artist_roster
-- 优化后：使用 IX_artist_roster_team_specialization 索引
-- ============================================================================
PRINT '测试用例1: 查询法国的所有画家';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.date_of_birth,
    ar.cur_art_studio,
    aspt.specialization_desc
FROM artist_roster ar
INNER JOIN art_country ac ON ar.a_team_id = ac.country_id
INNER JOIN art_specialization aspt ON ar.specialization_id = aspt.specialization_id
WHERE ac.country_name = 'France' AND aspt.specialization_id = 'PT';

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- ============================================================================
-- 测试用例2: 查询某个艺术家的所有销售记录
-- 优化前：全表扫描 sales
-- 优化后：使用 IX_sales_artist 索引
-- ============================================================================
PRINT '测试用例2: 查询艺术家ID=2102的所有销售记录';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 
    s.sale_id,
    s.round_id,
    s.artwork_id,
    s.sale_price,
    s.buyer_type,
    ar.artist_name,
    ac.country_name
FROM sales s
INNER JOIN artist_roster ar ON s.artist_id = ar.artist_id
INNER JOIN art_country ac ON s.a_team_id = ac.country_id
WHERE s.artist_id = 2102
ORDER BY s.sale_price DESC;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- ============================================================================
-- 测试用例3: 查询决赛阶段的所有轮次
-- 优化前：全表扫描 round_summary
-- 优化后：使用 IX_round_summary_stage 覆盖索引
-- ============================================================================
PRINT '测试用例3: 查询决赛阶段的所有轮次';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 
    rs.round_id,
    rs.round_week,
    ag.gallery_name,
    ar.artist_name,
    rs.points_scored,
    rs.voters_no
FROM round_summary rs
INNER JOIN art_gallery ag ON rs.gallery_id = ag.gallery_id
INNER JOIN artist_roster ar ON rs.artist_of_round = ar.artist_id
WHERE rs.round_stage = 'F'
ORDER BY rs.round_week;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- ============================================================================
-- 测试用例4: 查询某个团队的所有积分记录
-- 优化前：全表扫描 point_details
-- 优化后：使用 IX_point_details_team 索引
-- ============================================================================
PRINT '测试用例4: 查询团队ID=1021的所有积分记录';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 
    pd.point_id,
    pd.round_id,
    pd.point_type,
    pd.points_awarded,
    ar.artist_name
FROM point_details pd
LEFT JOIN artist_roster ar ON pd.artist_id = ar.artist_id
WHERE pd.a_team_id = 1021
ORDER BY pd.points_awarded DESC;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- ============================================================================
-- 测试用例5: 查询最受欢迎艺术家（聚合查询）
-- 优化前：全表扫描 liked_artist
-- 优化后：使用 IX_liked_artist_artist 索引
-- ============================================================================
PRINT '测试用例5: 查询最受欢迎艺术家TOP5';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT TOP 5
    ar.artist_id,
    ar.artist_name,
    ac.country_name,
    COUNT(la.artist_id) AS liked_count
FROM liked_artist la
INNER JOIN artist_roster ar ON la.artist_id = ar.artist_id
INNER JOIN art_country ac ON ar.a_team_id = ac.country_id
GROUP BY ar.artist_id, ar.artist_name, ac.country_name
ORDER BY liked_count DESC;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- ============================================================================
-- 测试用例6: 查询销售业绩排名（复杂聚合）
-- 优化前：全表扫描 sales
-- 优化后：使用 IX_sales_team 索引
-- ============================================================================
PRINT '测试用例6: 查询销售业绩排名TOP10';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT TOP 10
    ar.artist_id,
    ar.artist_name,
    ac.country_name,
    COUNT(s.sale_id) AS sale_count,
    SUM(s.sale_price) AS total_sales,
    AVG(s.sale_price) AS avg_sale_price
FROM sales s
INNER JOIN artist_roster ar ON s.artist_id = ar.artist_id
INNER JOIN art_country ac ON s.a_team_id = ac.country_id
GROUP BY ar.artist_id, ar.artist_name, ac.country_name
ORDER BY total_sales DESC;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- ============================================================================
-- 测试用例7: 查询决赛阶段团队成绩排名
-- 优化前：全表扫描 art_team_results
-- 优化后：使用 IX_art_team_results_stage 覆盖索引
-- ============================================================================
PRINT '测试用例7: 查询决赛阶段团队成绩排名';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 
    atr.a_team_id,
    ac.country_name,
    atr.rounds_no,
    atr.r_won,
    atr.r_lost,
    atr.points_for_team,
    atr.p_s,
    atr.p_v2,
    atr.p_v3,
    RANK() OVER (ORDER BY atr.points_for_team DESC) AS overall_rank
FROM art_team_results atr
INNER JOIN art_country ac ON atr.a_team_id = ac.country_id
WHERE atr.round_stage = 'F'
ORDER BY atr.points_for_team DESC;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- ============================================================================
-- 测试用例8: 查询某个画廊的所有轮次
-- 优化前：全表扫描 round_summary
-- 优化后：使用 IX_round_summary_gallery_stage 复合索引
-- ============================================================================
PRINT '测试用例8: 查询画廊ID=1的所有轮次';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 
    rs.round_id,
    rs.round_stage,
    rs.round_week,
    ar.artist_name,
    rs.points_scored,
    jr.judge_name
FROM round_summary rs
INNER JOIN artist_roster ar ON rs.artist_of_round = ar.artist_id
INNER JOIN judge_roster jr ON rs.head_judge_id = jr.judge_id
WHERE rs.gallery_id = 1
ORDER BY rs.round_week;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- ============================================================================
-- 测试用例9: 查询资深艺术家信息
-- 优化前：全表扫描 artist_roster
-- 优化后：使用 IX_artist_roster_senior 过滤索引
-- ============================================================================
PRINT '测试用例9: 查询所有资深艺术家';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 
    ar.artist_id,
    ar.artist_name,
    ac.country_name,
    aspt.specialization_desc,
    ar.date_of_birth,
    ar.cur_art_studio
FROM artist_roster ar
INNER JOIN art_country ac ON ar.a_team_id = ac.country_id
INNER JOIN art_specialization aspt ON ar.specialization_id = aspt.specialization_id
WHERE ar.senior_artist = 'Y'
ORDER BY ar.date_of_birth;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- ============================================================================
-- 测试用例10: 查询特定价格区间的销售记录
-- 优化前：全表扫描 sales
-- 优化后：使用 IX_sales_price 覆盖索引
-- ============================================================================
PRINT '测试用例10: 查询价格在1000-5000之间的销售记录';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 
    s.sale_id,
    s.sale_price,
    s.buyer_type,
    ar.artist_name,
    ac.country_name,
    s.artwork_id
FROM sales s
INNER JOIN artist_roster ar ON s.artist_id = ar.artist_id
INNER JOIN art_country ac ON s.a_team_id = ac.country_id
WHERE s.sale_price BETWEEN 1000 AND 5000
ORDER BY s.sale_price DESC;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- 关闭统计信息
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;
GO

-- ============================================================================
-- 索引使用情况验证
-- ============================================================================

PRINT '========================================';
PRINT '索引使用情况验证';
PRINT '========================================';
PRINT '';

SELECT 
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc AS index_type,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates,
    s.last_user_seek,
    s.last_user_scan
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats s ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE OBJECT_NAME(i.object_id) IN ('artist_roster', 'round_summary', 'sales', 'liked_artist', 'point_details', 'art_team_results')
  AND i.name LIKE 'IX_%'
ORDER BY table_name, i.name;
GO

PRINT '';
PRINT '========================================';
PRINT '索引优化后性能测试完成';
PRINT '========================================';
GO