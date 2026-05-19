-- 执行这个查询，查看执行计划

--IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_artist_roster_team_specialization' AND object_id = OBJECT_ID('artist_roster'))
--BEGIN
--    DROP INDEX IX_artist_roster_team_specialization ON artist_roster;
--    PRINT '  ✓ 已删除 IX_artist_roster_team_specialization';
--END

SELECT ar.artist_id, ar.artist_name, ar.date_of_birth
FROM artist_roster ar
WHERE ar.a_team_id = 1021 AND ar.specialization_id = 'PT';