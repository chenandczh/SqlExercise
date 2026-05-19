-- ============================================================================
-- ART_CONTEST 数据库索引回滚脚本
-- ============================================================================
-- 用途：删除所有通过 index_optimization_script.sql 创建的索引
-- 注意：此脚本仅删除以 IX_ 开头的非聚集索引
-- ============================================================================

USE ART_CONTEST;
GO

PRINT '========================================';
PRINT '开始回滚索引优化';
PRINT '========================================';
PRINT '';

-- ============================================================================
-- 回滚 artist_roster 表的索引
-- ============================================================================

PRINT '正在删除 artist_roster 表的索引...';

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_artist_roster_team_specialization' AND object_id = OBJECT_ID('artist_roster'))
BEGIN
    DROP INDEX IX_artist_roster_team_specialization ON artist_roster;
    PRINT '  ✓ 已删除 IX_artist_roster_team_specialization';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_artist_roster_senior' AND object_id = OBJECT_ID('artist_roster'))
BEGIN
    DROP INDEX IX_artist_roster_senior ON artist_roster;
    PRINT '  ✓ 已删除 IX_artist_roster_senior';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_artist_roster_studio' AND object_id = OBJECT_ID('artist_roster'))
BEGIN
    DROP INDEX IX_artist_roster_studio ON artist_roster;
    PRINT '  ✓ 已删除 IX_artist_roster_studio';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_artist_roster_dob' AND object_id = OBJECT_ID('artist_roster'))
BEGIN
    DROP INDEX IX_artist_roster_dob ON artist_roster;
    PRINT '  ✓ 已删除 IX_artist_roster_dob';
END

PRINT '';
GO

-- ============================================================================
-- 回滚 round_summary 表的索引
-- ============================================================================

PRINT '正在删除 round_summary 表的索引...';

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_round_summary_gallery_stage' AND object_id = OBJECT_ID('round_summary'))
BEGIN
    DROP INDEX IX_round_summary_gallery_stage ON round_summary;
    PRINT '  ✓ 已删除 IX_round_summary_gallery_stage';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_round_summary_artist' AND object_id = OBJECT_ID('round_summary'))
BEGIN
    DROP INDEX IX_round_summary_artist ON round_summary;
    PRINT '  ✓ 已删除 IX_round_summary_artist';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_round_summary_stage' AND object_id = OBJECT_ID('round_summary'))
BEGIN
    DROP INDEX IX_round_summary_stage ON round_summary;
    PRINT '  ✓ 已删除 IX_round_summary_stage';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_round_summary_judge' AND object_id = OBJECT_ID('round_summary'))
BEGIN
    DROP INDEX IX_round_summary_judge ON round_summary;
    PRINT '  ✓ 已删除 IX_round_summary_judge';
END

PRINT '';
GO

-- ============================================================================
-- 回滚 sales 表的索引
-- ============================================================================

PRINT '正在删除 sales 表的索引...';

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_sales_artist' AND object_id = OBJECT_ID('sales'))
BEGIN
    DROP INDEX IX_sales_artist ON sales;
    PRINT '  ✓ 已删除 IX_sales_artist';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_sales_team' AND object_id = OBJECT_ID('sales'))
BEGIN
    DROP INDEX IX_sales_team ON sales;
    PRINT '  ✓ 已删除 IX_sales_team';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_sales_buyer_type' AND object_id = OBJECT_ID('sales'))
BEGIN
    DROP INDEX IX_sales_buyer_type ON sales;
    PRINT '  ✓ 已删除 IX_sales_buyer_type';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_sales_price' AND object_id = OBJECT_ID('sales'))
BEGIN
    DROP INDEX IX_sales_price ON sales;
    PRINT '  ✓ 已删除 IX_sales_price';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_sales_round' AND object_id = OBJECT_ID('sales'))
BEGIN
    DROP INDEX IX_sales_round ON sales;
    PRINT '  ✓ 已删除 IX_sales_round';
END

PRINT '';
GO

-- ============================================================================
-- 回滚 liked_artist 表的索引
-- ============================================================================

PRINT '正在删除 liked_artist 表的索引...';

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_liked_artist_artist' AND object_id = OBJECT_ID('liked_artist'))
BEGIN
    DROP INDEX IX_liked_artist_artist ON liked_artist;
    PRINT '  ✓ 已删除 IX_liked_artist_artist';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_liked_artist_invited' AND object_id = OBJECT_ID('liked_artist'))
BEGIN
    DROP INDEX IX_liked_artist_invited ON liked_artist;
    PRINT '  ✓ 已删除 IX_liked_artist_invited';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_liked_artist_team' AND object_id = OBJECT_ID('liked_artist'))
BEGIN
    DROP INDEX IX_liked_artist_team ON liked_artist;
    PRINT '  ✓ 已删除 IX_liked_artist_team';
END

PRINT '';
GO

-- ============================================================================
-- 回滚 point_details 表的索引
-- ============================================================================

PRINT '正在删除 point_details 表的索引...';

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_point_details_team' AND object_id = OBJECT_ID('point_details'))
BEGIN
    DROP INDEX IX_point_details_team ON point_details;
    PRINT '  ✓ 已删除 IX_point_details_team';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_point_details_round' AND object_id = OBJECT_ID('point_details'))
BEGIN
    DROP INDEX IX_point_details_round ON point_details;
    PRINT '  ✓ 已删除 IX_point_details_round';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_point_details_type' AND object_id = OBJECT_ID('point_details'))
BEGIN
    DROP INDEX IX_point_details_type ON point_details;
    PRINT '  ✓ 已删除 IX_point_details_type';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_point_details_artist' AND object_id = OBJECT_ID('point_details'))
BEGIN
    DROP INDEX IX_point_details_artist ON point_details;
    PRINT '  ✓ 已删除 IX_point_details_artist';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_point_details_points' AND object_id = OBJECT_ID('point_details'))
BEGIN
    DROP INDEX IX_point_details_points ON point_details;
    PRINT '  ✓ 已删除 IX_point_details_points';
END

PRINT '';
GO

-- ============================================================================
-- 回滚 art_team_results 表的索引
-- ============================================================================

PRINT '正在删除 art_team_results 表的索引...';

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_art_team_results_stage' AND object_id = OBJECT_ID('art_team_results'))
BEGIN
    DROP INDEX IX_art_team_results_stage ON art_team_results;
    PRINT '  ✓ 已删除 IX_art_team_results_stage';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_art_team_results_team' AND object_id = OBJECT_ID('art_team_results'))
BEGIN
    DROP INDEX IX_art_team_results_team ON art_team_results;
    PRINT '  ✓ 已删除 IX_art_team_results_team';
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_art_team_results_points' AND object_id = OBJECT_ID('art_team_results'))
BEGIN
    DROP INDEX IX_art_team_results_points ON art_team_results;
    PRINT '  ✓ 已删除 IX_art_team_results_points';
END

PRINT '';
GO

-- ============================================================================
-- 验证索引删除结果
-- ============================================================================

PRINT '========================================';
PRINT '验证索引删除结果';
PRINT '========================================';
PRINT '';

SELECT 
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc AS index_type
FROM sys.indexes i
WHERE OBJECT_NAME(i.object_id) IN ('artist_roster', 'round_summary', 'sales', 'liked_artist', 'point_details', 'art_team_results')
  AND i.name LIKE 'IX_%'
ORDER BY table_name, i.name;

IF @@ROWCOUNT = 0
BEGIN
    PRINT '✓ 所有优化索引已成功删除！';
END
ELSE
BEGIN
    PRINT '⚠ 仍有 ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' 个索引未删除，请手动检查。';
END

PRINT '';
PRINT '========================================';
PRINT '索引回滚完成';
PRINT '========================================';
GO