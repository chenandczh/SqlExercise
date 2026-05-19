-- ============================================================================
-- ART_CONTEST 数据库索引性能测试脚本
-- ============================================================================
-- 测试目的：对比索引优化前后的查询性能
-- 测试方法：使用SET STATISTICS和执行计划收集性能指标
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
PRINT '索引优化前性能测试';
PRINT '========================================';
PRINT '';

-- ============================================================================
-- 测试用例1: 查询法国的所有画家（多表JOIN）
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
-- ============================================================================
PRINT '测试用例4: 查询团队ID=1021的所有积分记录';
PRINT '----------------------------------------';

SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT 
    pd.point_id,
    pd.round_id,
    pd.point_type,
    ar.artist_name
FROM point_details pd
LEFT JOIN artist_roster ar ON pd.artist_id = ar.artist_id
WHERE pd.a_team_id = 1021;

SET STATISTICS TIME ON;
SET STATISTICS IO ON;

PRINT '';
GO

-- ============================================================================
-- 测试用例5: 查询最受欢迎艺术家（聚合查询）
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

PRINT '========================================';
PRINT '索引优化前性能测试完成';
PRINT '========================================';
GO