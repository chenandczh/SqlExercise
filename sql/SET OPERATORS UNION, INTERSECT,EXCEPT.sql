-- SET OPERATORS UNION, INTERSECT, EXCEPT
-- 本文件演示 SQL 集合操作符的使用，用于合并或比较多个查询结果集

-- ========== UNION 操作符 ==========
-- 功能：合并两个查询结果，自动去除重复行
-- 实现方式：将两个 SELECT 语句的结果合并，返回唯一的记录集
SELECT a_team_id, artist_captain_id FROM round_captain WHERE a_team_id IN(1025,1034)
UNION
SELECT a_team_id, artist_id FROM senior_artist_details WHERE a_team_id IN(1025,1034)
ORDER BY a_team_id;

-- ========== UNION ALL 操作符 ==========
-- 功能：合并两个查询结果，保留所有行（包括重复行）
-- 实现方式：直接合并两个结果集，不进行去重操作，性能优于 UNION
SELECT a_team_id, artist_captain_id FROM round_captain WHERE a_team_id IN(1025,1034)
UNION ALL
SELECT a_team_id, artist_id FROM senior_artist_details WHERE a_team_id IN(1025,1034)
ORDER BY a_team_id;

-- ========== INTERSECT 操作符 ==========
-- 功能：返回两个查询结果的交集（同时存在于两个结果集中的行）
-- 实现方式：找出两个结果集的共同记录，自动去重
SELECT a_team_id, artist_captain_id FROM round_captain WHERE a_team_id IN(1025,1034)
INTERSECT
SELECT a_team_id, artist_id FROM senior_artist_details WHERE a_team_id IN(1025,1034)
ORDER BY a_team_id;

-- ========== EXCEPT 操作符 ==========
-- 功能：返回第一个查询结果中存在但第二个查询结果中不存在的行
-- 实现方式：从第一个结果集中排除与第二个结果集相同的记录
SELECT a_team_id, artist_captain_id FROM round_captain WHERE a_team_id IN(1025,1034)
EXCEPT
SELECT a_team_id, artist_id FROM senior_artist_details WHERE a_team_id IN(1025,1034)
ORDER BY a_team_id;

-- ========== 集合操作符组合使用（无括号）==========
-- 功能：演示多个集合操作符的优先级执行顺序
-- 实现方式：INTERSECT 优先级高于 UNION/EXCEPT，先执行所有 INTERSECT，再从左到右执行 UNION/EXCEPT
-- 执行顺序：先 INTERSECT(Q2, Q3)，再 UNION(Q1, 结果)，最后 EXCEPT(结果, Q4)
SELECT a_team_id, artist_captain_id FROM round_captain WHERE a_team_id IN(1025,1034)
UNION
SELECT a_team_id, artist_id FROM senior_artist_details WHERE a_team_id IN(1025,1034)
INTERSECT
SELECT a_team_id, artist_id FROM senior_artist_details WHERE comp_total= 4
EXCEPT
SELECT a_team_id, artist_id FROM senior_artist_details WHERE awards_won= 2;

-- ========== 集合操作符组合使用（带括号）==========
-- 功能：演示使用括号改变集合操作的执行顺序
-- 实现方式：先执行括号内的操作，再执行括号外的操作
-- 执行顺序：先计算 EXCEPT，再计算 INTERSECT，最后计算 UNION
SELECT a_team_id, artist_captain_id FROM round_captain WHERE a_team_id IN(1025,1034)
UNION
SELECT a_team_id, artist_id FROM senior_artist_details WHERE a_team_id IN(1025,1034)
INTERSECT(
SELECT a_team_id, artist_id FROM senior_artist_details WHERE comp_total= 4
EXCEPT
SELECT a_team_id, artist_id FROM senior_artist_details WHERE awards_won= 2);
