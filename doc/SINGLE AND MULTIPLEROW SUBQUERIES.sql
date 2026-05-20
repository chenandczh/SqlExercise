-- SINGLE AND MULTIPLE ROW SUBQUERIES
-- 本文件演示 SQL 子查询的使用，包括单行子查询和多行子查询

-- ========== 单行子查询（使用 = 操作符）==========
-- 功能：根据外层查询的条件，执行返回单值的子查询
-- 实现方式：子查询返回单个值，外层查询使用 = 进行比较匹配
SELECT artist_id, artist_name, date_of_birth FROM artist_roster WHERE
a_team_id = (SELECT country_id FROM art_country WHERE country_name = 'France');

-- ========== 多行子查询（使用 IN 操作符）==========
-- 功能：处理子查询返回多个值的情况
-- 实现方式：子查询返回多行结果，外层查询使用 IN 判断是否包含在结果集中
SELECT artist_id, artist_name, date_of_birth FROM artist_roster WHERE
a_team_id IN (SELECT country_id FROM art_country WHERE country_name IN ('Spain', 'France'));

-- ========== 模式匹配查询（使用 LIKE）==========
-- 功能：基于通配符模式进行模糊查询
-- 实现方式：使用 LIKE 操作符配合 % 通配符匹配字符串模式
SELECT artist_id, artist_name, prev_art_studio FROM artist_roster WHERE prev_art_studio LIKE '0%';

-- ========== NULL 值判断查询 ==========
-- 功能：检查字段是否为 NULL 值
-- 实现方式：使用 IS NULL 操作符判断字段是否未赋值
SELECT artist_id, artist_name, prev_art_studio FROM artist_roster WHERE prev_art_studio IS NULL;

-- ========== 范围查询（使用 BETWEEN 和子查询）==========
-- 功能：根据子查询动态确定查询范围
-- 实现方式：子查询分别返回最小值和最大值，外层查询使用 BETWEEN 限定范围
SELECT artist_id, artist_name FROM artist_roster WHERE date_of_birth BETWEEN (
SELECT MIN(date_of_birth) FROM artist_roster WHERE a_team_id = 1021 )
AND (SELECT MAX(date_of_birth) FROM artist_roster WHERE a_team_id = 1034 );

-- ========== TOP 子查询 ==========
-- 功能：获取子查询的前 N 条记录作为匹配条件
-- 实现方式：使用 TOP 关键字限制子查询返回行数，外层查询进行模式匹配
SELECT artist_id, artist_name FROM artist_roster WHERE artist_name LIKE(
SELECT TOP 1 artist_name FROM artist_roster WHERE a_team_id = 1021 );

-- ========== EXISTS 子查询 ==========
-- 功能：检查子查询是否返回任何结果
-- 实现方式：EXISTS 判断子查询是否存在满足条件的记录，不关心具体返回值
SELECT artist_id, artist_name FROM artist_roster WHERE EXISTS(
SELECT artist_id, date_of_birth FROM artist_roster WHERE date_of_birth > '1990-05-07');

-- ========== 标量子查询（作为列表达式）==========
-- 功能：将子查询结果作为列值返回
-- 实现方式：子查询返回单个值，作为外层查询的一个计算列
SELECT a_team_id, artist_name, specialization_id,
(SELECT MAX(sale_price) FROM sales WHERE artist_id = 2132) AS max_sale_price
FROM artist_roster WHERE artist_id = 2132;

-- ========== 派生表子查询 ==========
-- 功能：将子查询结果作为临时表供外层查询使用
-- 实现方式：子查询作为 FROM 子句的数据源，生成临时结果集
SELECT MAX(val) AS max_val FROM (
SELECT COUNT(artist_id) AS val FROM liked_artist WHERE invited IS NULL AND 
artist_id IN (SELECT artist_of_round FROM round_summary) GROUP BY a_team_id) AS d_table_name;

-- ========== HAVING 子句中的子查询 ==========
-- 功能：在分组聚合后进行条件筛选
-- 实现方式：子查询作为 HAVING 子句的条件，与聚合函数结果进行比较
SELECT artist_id, COUNT(*) AS num_of_times FROM liked_artist GROUP BY artist_id HAVING COUNT(*) >= (
SELECT COUNT(*) FROM liked_artist WHERE artist_id = 2112);

-- ========== ORDER BY 子句中的子查询 ==========
-- 功能：根据子查询结果动态排序
-- 实现方式：子查询返回用于排序的值，外层查询根据该值进行排序
SELECT artist_id, artist_name FROM artist_roster ORDER BY (
SELECT MIN(artist_of_round) FROM round_summary);
