-- ========================================
-- SQL Server 高级查询示例集
-- ART_CONTEST 数据库
-- ========================================
-- 本文件包含 10 大高级查询技能的完整示例
-- 按章节划分，可独立执行
-- ========================================

USE ART_CONTEST;
GO

-- ========================================
-- 第1章：复杂条件组合查询
-- ========================================

-- 场景：查询参赛队伍综合统计数据

-- 1.1 基础条件组合：查询特定分组且积分达标的队伍
SELECT 
    a_team_id,
    round_stage,
    in_group,
    r_won,
    r_lost,
    points_for_team
FROM art_team_results
WHERE in_group = 'A'                    
    AND points_for_team >= 15           
    AND r_won > r_lost;                 

-- 1.2 BETWEEN 范围查询：查询积分在特定区间的队伍
SELECT 
    a_team_id,
    round_stage,
    points_for_team
FROM art_team_results
WHERE points_for_team BETWEEN 15 AND 20
ORDER BY points_for_team DESC;

-- 1.3 IN 多值匹配：查询多个队伍的信息
SELECT 
    artist_id,
    artist_name,
    specialization_id,
    cur_art_studio
FROM artist_roster
WHERE a_team_id IN (1021, 1025, 1034)
ORDER BY a_team_id, artist_name;

-- 1.4 LIKE 模糊匹配：查询工作室名称包含特定关键词的艺术家
SELECT 
    artist_id,
    artist_name,
    cur_art_studio,
    prev_art_studio
FROM artist_roster
WHERE cur_art_studio LIKE '%Art Studio%'      
   OR prev_art_studio LIKE '%Art Studio%';

-- 1.5 复合条件：综合查询
SELECT 
    a_team_id,
    round_stage,
    in_group,
    points_for_team,
    p_s,
    p_v2
FROM art_team_results
WHERE (in_group = 'A' OR in_group = 'B')      
    AND points_for_team >= 12
    AND p_s > p_v2                            
ORDER BY in_group, points_for_team DESC;

GO

-- ========================================
-- 第2章：多表关联查询
-- ========================================

-- 2.1 INNER JOIN：艺术家详细信息
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.specialization_id,
    sp.specialization_desc,
    ar.cur_art_studio
FROM artist_roster ar
INNER JOIN art_specialization sp 
    ON ar.specialization_id = sp.specialization_id;

-- 2.2 LEFT JOIN：查询所有艺术家及他们的队伍信息
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.a_team_id,
    atr.round_stage,
    atr.points_for_team
FROM artist_roster ar
LEFT JOIN art_team_results atr 
    ON ar.a_team_id = atr.a_team_id
WHERE atr.round_stage = 'G'
ORDER BY ar.artist_id;

-- 2.3 多表连接：艺术家、队伍、国家、城市完整信息
SELECT 
    ar.artist_name,
    ar.cur_art_studio,
    ac.city_name,
    acn.country_name,
    acn.continent_name
FROM artist_roster ar
INNER JOIN art_team_results atr ON ar.a_team_id = atr.a_team_id
INNER JOIN art_gallery ag ON atr.a_team_id = ag.gallery_id
LEFT JOIN art_city ac ON ag.city_id = ac.city_id
LEFT JOIN art_country acn ON ac.country_id = acn.country_id
ORDER BY acn.country_name, ar.artist_name;

-- 2.4 自连接：查询艺术家的工作室变动信息
SELECT 
    ar1.artist_name,
    ar1.prev_art_studio AS PreviousStudio,
    ar2.cur_art_studio AS CurrentStudioAtSameTeam
FROM artist_roster ar1
INNER JOIN artist_roster ar2 
    ON ar1.a_team_id = ar2.a_team_id
WHERE ar1.prev_art_studio IS NOT NULL
    AND ar1.artist_id <> ar2.artist_id
ORDER BY ar1.artist_name;

-- 2.5 聚合 + JOIN：各国家参赛艺术家数量统计
SELECT 
    acn.country_id,
    acn.country_name,
    acn.continent_name,
    COUNT(ar.artist_id) AS ArtistCount
FROM art_country acn
LEFT JOIN artist_roster ar ON acn.country_id = ar.a_team_id % 1000 + 1000
GROUP BY acn.country_id, acn.country_name, acn.continent_name
HAVING COUNT(ar.artist_id) > 0
ORDER BY ArtistCount DESC;

GO

-- ========================================
-- 第3章：子查询应用
-- ========================================

-- 3.1 标量子查询：计算每个艺术家相对于平均分的差异
SELECT 
    pd.artist_id,
    ar.artist_name,
    pd.point_amt,
    (SELECT AVG(point_amt) FROM point_details) AS AvgPoint,
    pd.point_amt - (SELECT AVG(point_amt) FROM point_details) AS DiffFromAvg
FROM point_details pd
INNER JOIN artist_roster ar ON pd.artist_id = ar.artist_id
WHERE pd.round_stage = 'G'
ORDER BY DiffFromAvg DESC;

-- 3.2 表值子查询：查询积分高于平均分的艺术家
SELECT 
    artist_id,
    artist_name,
    a_team_id,
    date_of_birth
FROM artist_roster
WHERE artist_id IN (
    SELECT DISTINCT artist_id 
    FROM point_details 
    WHERE point_amt > (SELECT AVG(point_amt) FROM point_details WHERE round_stage = 'G')
)
ORDER BY artist_id;

-- 3.3 相关子查询：查询每个队伍中得分最高的艺术家
SELECT 
    ar.artist_name,
    ar.a_team_id,
    ar.specialization_id,
    pd.point_amt
FROM artist_roster ar
INNER JOIN point_details pd ON ar.artist_id = pd.artist_id
WHERE pd.point_amt = (
    SELECT MAX(pd2.point_amt) 
    FROM point_details pd2 
    WHERE pd2.a_team_id = pd.a_team_id 
        AND pd2.round_stage = pd.round_stage
)
ORDER BY ar.a_team_id, pd.point_amt DESC;

-- 3.4 NOT IN 排除查询：查询从未获得过满分的艺术家
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.cur_art_studio
FROM artist_roster ar
WHERE ar.artist_id NOT IN (
    SELECT DISTINCT artist_id 
    FROM point_details 
    WHERE point_type = 'PERF'
)
ORDER BY ar.artist_id;

-- 3.5 EXISTS 检查：查询是否存在符合条件的记录
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.senior_artist
FROM artist_roster ar
WHERE EXISTS (
    SELECT 1 
    FROM sales s 
    WHERE s.artist_id = ar.artist_id 
        AND s.sale_price > 50000
)
ORDER BY ar.artist_name;

-- 3.6 多层嵌套子查询：查询顶级队伍中的艺术家
SELECT 
    ar.artist_name,
    ar.a_team_id,
    atr.points_for_team
FROM artist_roster ar
INNER JOIN art_team_results atr ON ar.a_team_id = atr.a_team_id
WHERE atr.a_team_id IN (
    SELECT a_team_id 
    FROM art_team_results 
    WHERE round_stage = 'G' 
        AND points_for_team > (
            SELECT AVG(points_for_team) 
            FROM art_team_results 
            WHERE round_stage = 'G'
        )
)
ORDER BY atr.points_for_team DESC, ar.artist_name;

GO

-- ========================================
-- 第4章：聚合分析与统计
-- ========================================

-- 4.1 基础聚合统计：计算各分组总积分
SELECT 
    in_group,
    COUNT(*) AS TeamCount,
    SUM(points_for_team) AS TotalPoints,
    AVG(points_for_team) AS AvgPoints,
    MAX(points_for_team) AS MaxPoints,
    MIN(points_for_team) AS MinPoints
FROM art_team_results
WHERE round_stage = 'G'
GROUP BY in_group
ORDER BY TotalPoints DESC;

-- 4.2 多重分组：按阶段和分组统计
SELECT 
    round_stage,
    in_group,
    COUNT(*) AS TeamCount,
    SUM(r_won) AS TotalWins,
    SUM(r_lost) AS TotalLosses,
    AVG(points_for_team) AS AvgPoints
FROM art_team_results
GROUP BY round_stage, in_group
ORDER BY round_stage, in_group;

-- 4.3 HAVING 过滤：筛选符合条件的分组
SELECT 
    in_group,
    COUNT(*) AS TeamCount,
    AVG(points_for_team) AS AvgPoints
FROM art_team_results
WHERE round_stage = 'G'
GROUP BY in_group
HAVING AVG(points_for_team) > 15
ORDER BY AvgPoints DESC;

-- 4.4 聚合 + JOIN：统计每位艺术家的得分
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.specialization_id,
    COUNT(pd.point_id) AS PointCount,
    SUM(pd.point_amt) AS TotalPoints,
    AVG(pd.point_amt) AS AvgPoints
FROM artist_roster ar
LEFT JOIN point_details pd ON ar.artist_id = pd.artist_id
GROUP BY ar.artist_id, ar.artist_name, ar.specialization_id
HAVING SUM(pd.point_amt) > 0
ORDER BY TotalPoints DESC;

-- 4.5 DISTINCT COUNT：统计独立艺术家数量
SELECT 
    round_stage,
    COUNT(DISTINCT artist_id) AS UniqueArtists,
    COUNT(DISTINCT a_team_id) AS UniqueTeams,
    COUNT(*) AS TotalRecords
FROM point_details
GROUP BY round_stage
ORDER BY round_stage;

-- 4.6 条件聚合：统计各类型得分
SELECT 
    pd.round_id,
    pd.round_stage,
    SUM(CASE WHEN pd.point_type = 'PERF' THEN pd.point_amt ELSE 0 END) AS PerfPoints,
    SUM(CASE WHEN pd.point_type = 'SALE' THEN pd.point_amt ELSE 0 END) AS SalePoints,
    SUM(CASE WHEN pd.point_type = 'VOTE' THEN pd.point_amt ELSE 0 END) AS VotePoints,
    SUM(pd.point_amt) AS TotalPoints
FROM point_details pd
GROUP BY pd.round_id, pd.round_stage
ORDER BY pd.round_id;

-- 4.7 聚合函数嵌套：计算分组内占比
SELECT 
    ar.specialization_id,
    sp.specialization_desc,
    COUNT(*) AS ArtistCount,
    ROUND(
        COUNT(*) * 100.0 / (SELECT COUNT(*) FROM artist_roster),
        2
    ) AS Percentage
FROM artist_roster ar
INNER JOIN art_specialization sp ON ar.specialization_id = sp.specialization_id
GROUP BY ar.specialization_id, sp.specialization_desc
ORDER BY ArtistCount DESC;

GO

-- ========================================
-- 第5章：数据排序与分页
-- ========================================

-- 5.1 基础排序：按积分降序排列
SELECT TOP 10
    ar.artist_id,
    ar.artist_name,
    ar.cur_art_studio,
    SUM(pd.point_amt) AS TotalPoints
FROM artist_roster ar
LEFT JOIN point_details pd ON ar.artist_id = pd.artist_id
GROUP BY ar.artist_id, ar.artist_name, ar.cur_art_studio
ORDER BY TotalPoints DESC;

-- 5.2 多列排序：先按分组，再按积分
SELECT 
    a_team_id,
    in_group,
    points_for_team,
    r_won,
    r_lost
FROM art_team_results
WHERE round_stage = 'G'
ORDER BY 
    in_group ASC,              
    points_for_team DESC;      

-- 5.3 OFFSET-FETCH 分页（第2页，每页10条）
DECLARE @PageNumber INT = 2;
DECLARE @PageSize INT = 10;

SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.date_of_birth,
    ar.specialization_id,
    ar.cur_art_studio
FROM artist_roster ar
ORDER BY ar.artist_name
OFFSET (@PageNumber - 1) * @PageSize ROWS
FETCH NEXT @PageSize ROWS ONLY;

-- 5.4 完整分页查询（带总数和总页数）
DECLARE @PageNum INT = 1;
DECLARE @PageSz INT = 10;

;WITH TotalCount AS (
    SELECT COUNT(*) AS TotalRows FROM artist_roster
)
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.date_of_birth,
    ar.cur_art_studio,
    tc.TotalRows,
    CEILING(CAST(tc.TotalRows AS DECIMAL(10,2)) / @PageSz) AS TotalPages
FROM artist_roster ar
CROSS JOIN TotalCount tc
ORDER BY ar.artist_name
OFFSET (@PageNum - 1) * @PageSz ROWS
FETCH NEXT @PageSz ROWS ONLY;

-- 5.5 NULL 值排序处理
SELECT 
    artist_id,
    artist_name,
    prev_art_studio,
    cur_art_studio
FROM artist_roster
ORDER BY 
    CASE WHEN prev_art_studio IS NULL THEN 1 ELSE 0 END,  -- NULL排最后
    prev_art_studio DESC;

GO

-- ========================================
-- 第6章：窗口函数应用
-- ========================================

-- 6.1 ROW_NUMBER：生成分组内连续编号
SELECT 
    ar.artist_name,
    ar.specialization_id,
    pd.point_amt,
    pd.round_id,
    ROW_NUMBER() OVER (
        PARTITION BY ar.specialization_id
        ORDER BY pd.point_amt DESC
    ) AS RowNumInGroup
FROM artist_roster ar
INNER JOIN point_details pd ON ar.artist_id = pd.artist_id
WHERE pd.round_stage = 'G'
ORDER BY ar.specialization_id, RowNumInGroup;

-- 6.2 RANK 与 DENSE_RANK：排名计算
SELECT 
    ar.artist_id,
    ar.artist_name,
    pd.point_amt,
    ROW_NUMBER() OVER (ORDER BY pd.point_amt DESC) AS RowNum,
    RANK() OVER (ORDER BY pd.point_amt DESC) AS [Rank],        
    DENSE_RANK() OVER (ORDER BY pd.point_amt DESC) AS DenseRank  
FROM artist_roster ar
INNER JOIN point_details pd ON ar.artist_id = pd.artist_id
WHERE pd.round_stage = 'G'
ORDER BY pd.point_amt DESC;

-- 6.3 LAG/LEAD：获取前一个/后一个的值
SELECT 
    pd.round_id,
    pd.a_team_id,
    pd.point_amt,
    pd.point_type,
    LAG(pd.point_amt, 1) OVER (
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
    ) AS PrevPoint,
    LEAD(pd.point_amt, 1) OVER (
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
    ) AS NextPoint,
    pd.point_amt - LAG(pd.point_amt, 1) OVER (
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
    ) AS PointDiff
FROM point_details pd
WHERE pd.artist_id = 2102
ORDER BY pd.round_id;

-- 6.4 窗口聚合：计算累计和移动平均
SELECT 
    pd.round_id,
    pd.artist_id,
    pd.point_amt,
    SUM(pd.point_amt) OVER (
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningTotal,
    AVG(pd.point_amt) OVER (
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS MovingAvg3,
    COUNT(pd.point_amt) OVER (
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
    ) AS RecordCount
FROM point_details pd
WHERE pd.artist_id IN (2102, 2501, 3411)
ORDER BY pd.artist_id, pd.round_id;

-- 6.5 FIRST_VALUE/LAST_VALUE：取窗口首尾值
SELECT 
    pd.artist_id,
    pd.round_id,
    pd.point_amt,
    FIRST_VALUE(pd.point_amt) OVER (
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
    ) AS FirstPoint,
    LAST_VALUE(pd.point_amt) OVER (
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS LastPoint
FROM point_details pd
WHERE pd.artist_id IN (2102, 2501)
ORDER BY pd.artist_id, pd.round_id;

-- 6.6 NTILE：把数据分成N个组（年龄分组）
SELECT 
    ar.artist_name,
    ar.date_of_birth,
    DATEDIFF(YEAR, ar.date_of_birth, GETDATE()) AS Age,
    NTILE(4) OVER (ORDER BY DATEDIFF(YEAR, ar.date_of_birth, GETDATE())) AS AgeQuartile
FROM artist_roster ar
ORDER BY AgeQuartile, ar.artist_name;

-- 6.7 复杂窗口计算：竞赛排名实时更新
-- SQL Server 不支持窗口函数嵌套，需要使用 CTE 分步计算
;WITH ArtistPoints AS (
    SELECT 
        ar.artist_name,
        ar.specialization_id,
        SUM(pd.point_amt) AS TotalPoints
    FROM artist_roster ar
    INNER JOIN point_details pd ON ar.artist_id = pd.artist_id
    GROUP BY ar.artist_name, ar.specialization_id
),
ArtistRank AS (
    SELECT 
        artist_name,
        specialization_id,
        TotalPoints,
        ROW_NUMBER() OVER (ORDER BY TotalPoints DESC) AS CurrentRank
    FROM ArtistPoints
)
SELECT 
    artist_name,
    specialization_id,
    TotalPoints,
    CurrentRank,
    LAG(CurrentRank) OVER (
        PARTITION BY specialization_id 
        ORDER BY TotalPoints DESC
    ) AS PreviousRankInSpec
FROM ArtistRank
ORDER BY TotalPoints DESC;

GO

-- ========================================
-- 第7章：公用表表达式(CTE)
-- ========================================

-- 7.1 非递归 CTE：简化复杂查询
;WITH ArtistStats AS (
    SELECT 
        ar.artist_id,
        ar.artist_name,
        ar.specialization_id,
        SUM(pd.point_amt) AS TotalPoints
    FROM artist_roster ar
    LEFT JOIN point_details pd ON ar.artist_id = pd.artist_id
    GROUP BY ar.artist_id, ar.artist_name, ar.specialization_id
),
TopArtists AS (
    SELECT TOP 5 *
    FROM ArtistStats
    WHERE TotalPoints > 0
    ORDER BY TotalPoints DESC
)
SELECT 
    ta.artist_name,
    ta.TotalPoints,
    sp.specialization_desc
FROM TopArtists ta
INNER JOIN art_specialization sp ON ta.specialization_id = sp.specialization_id;

-- 7.2 多重 CTE：链式数据处理
;WITH StageStats AS (
    SELECT 
        round_stage,
        COUNT(DISTINCT a_team_id) AS TeamCount,
        SUM(points_for_team) AS TotalPoints
    FROM art_team_results
    GROUP BY round_stage
),
GroupStats AS (
    SELECT 
        in_group,
        COUNT(*) AS TeamCount,
        AVG(points_for_team) AS AvgPoints
    FROM art_team_results
    GROUP BY in_group
)
SELECT 
    ss.round_stage,
    ss.TeamCount,
    gs.in_group,
    gs.TeamCount AS GroupTeamCount
FROM StageStats ss
CROSS JOIN GroupStats gs
ORDER BY ss.round_stage, gs.in_group;

-- 7.3 CTE 替代子查询：提高可读性
;WITH ArtistTotals AS (
    SELECT 
        artist_id,
        SUM(point_amt) AS TotalPoints
    FROM point_details
    GROUP BY artist_id
),
AverageCalc AS (
    SELECT AVG(TotalPoints) AS OverallAvg FROM ArtistTotals
)
SELECT at.*
FROM ArtistTotals at
CROSS JOIN AverageCalc ac
WHERE at.TotalPoints > ac.OverallAvg;

-- 7.4 递归 CTE：生成数字序列
;WITH Numbers AS (
    SELECT 1 AS Num
    UNION ALL
    SELECT Num + 1 
    FROM Numbers 
    WHERE Num < 100
)
SELECT Num FROM Numbers
OPTION (MAXRECURSION 100);

-- 7.5 CTE 在数据修改中的应用
;WITH HighScorers AS (
    SELECT artist_id 
    FROM point_details 
    GROUP BY artist_id 
    HAVING SUM(point_amt) > 100
)
UPDATE artist_roster
SET cur_art_studio = 'Champion Studio'
WHERE artist_id IN (SELECT artist_id FROM HighScorers);

GO

-- ========================================
-- 第8章：PIVOT与UNPIVOT
-- ========================================

-- 8.1 PIVOT：行列转换（按得分类型统计）
SELECT 
    a_team_id,
    [PERF] AS PerfPoints,
    [SALE] AS SalePoints,
    [VOTE] AS VotePoints
FROM (
    SELECT 
        a_team_id,
        point_type,
        point_amt
    FROM point_details
) AS SourceData
PIVOT (
    SUM(point_amt)
    FOR point_type IN ([PERF], [SALE], [VOTE])
) AS PivotTable
ORDER BY a_team_id;

-- 8.2 多列 PIVOT：按阶段和类型统计
SELECT 
    a_team_id,
    [G_PERF] AS GroupPerf,
    [G_SALE] AS GroupSale,
    [S_PERF] AS SemiPerf,
    [S_SALE] AS SemiSale
FROM (
    SELECT 
        a_team_id,
        round_stage + '_' + point_type AS StageType,
        point_amt
    FROM point_details
) AS SourceData
PIVOT (
    SUM(point_amt)
    FOR StageType IN ([G_PERF], [G_SALE], [S_PERF], [S_SALE])
) AS PivotTable
ORDER BY a_team_id;

-- 8.3 UNPIVOT：列转行
-- 注意：UNPIVOT 要求所有列类型完全一致，需使用相同的类型转换
SELECT 
    artist_id,
    artist_name,
    Attribute,
    Value
FROM (
    SELECT 
        ar.artist_id,
        ar.artist_name,
        -- 使用相同长度的 VARCHAR 类型，确保类型一致
        CAST(CONVERT(VARCHAR(20), ar.date_of_birth, 120) AS VARCHAR(50)) AS DOB,
        CAST(ar.cur_art_studio AS VARCHAR(50)) AS CurrentStudio,
        CAST(ar.prev_art_studio AS VARCHAR(50)) AS PreviousStudio
    FROM artist_roster ar
) AS SourceData
UNPIVOT (
    Value FOR Attribute IN (DOB, CurrentStudio, PreviousStudio)
) AS UnpivotTable
WHERE Value IS NOT NULL
ORDER BY artist_id, Attribute;

-- 8.4 PIVOT 结合 GROUP BY：分组统计
SELECT 
    in_group,
    ISNULL([PT], 0) AS PainterCount,
    ISNULL([PH], 0) AS PhotographerCount,
    ISNULL([SC], 0) AS SculptorCount,
    ISNULL([PT], 0) + ISNULL([PH], 0) + ISNULL([SC], 0) AS GrandTotal
FROM (
    SELECT 
        atr.in_group,
        ar.specialization_id,
        1 AS cnt
    FROM artist_roster ar
    INNER JOIN art_team_results atr ON ar.a_team_id = atr.a_team_id
    WHERE atr.round_stage = 'G'
) AS SourceData
PIVOT (
    COUNT(cnt)
    FOR specialization_id IN ([PT], [PH], [SC])
) AS PivotTable
ORDER BY in_group;

GO

-- ========================================
-- 第9章：EXISTS与NOT EXISTS
-- ========================================

-- 9.1 EXISTS：查询有销售记录的艺术家
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.cur_art_studio
FROM artist_roster ar
WHERE EXISTS (
    SELECT 1 
    FROM sales s 
    WHERE s.artist_id = ar.artist_id
)
ORDER BY ar.artist_name;

-- 9.2 NOT EXISTS：查询从未获得满分的艺术家
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.cur_art_studio
FROM artist_roster ar
WHERE NOT EXISTS (
    SELECT 1 
    FROM point_details pd 
    WHERE pd.artist_id = ar.artist_id 
        AND pd.point_type = 'PERF'
)
ORDER BY ar.artist_name;

-- 9.3 多条件 EXISTS：复合条件检查
SELECT 
    ar.artist_id,
    ar.artist_name
FROM artist_roster ar
WHERE EXISTS (
    SELECT 1 
    FROM sales s
    INNER JOIN artwork_details aw ON s.artwork_id = aw.artwork_id
    WHERE s.artist_id = ar.artist_id
        AND aw.orig_price > 30000
        AND s.sale_price > aw.orig_price
)
ORDER BY ar.artist_name;

-- 9.4 NOT EXISTS 替代 NOT IN：避免 NULL 问题
SELECT ar.artist_id, ar.artist_name
FROM artist_roster ar
WHERE NOT EXISTS (
    SELECT 1 
    FROM point_details pd 
    WHERE pd.artist_id = ar.artist_id
);

-- 9.5 双重 EXISTS：多层关系检查
SELECT 
    ar.artist_name,
    ar.cur_art_studio
FROM artist_roster ar
WHERE EXISTS (
    SELECT 1 
    FROM art_team_results atr
    WHERE atr.a_team_id = ar.a_team_id
        AND atr.round_stage = 'G'
        AND EXISTS (
            SELECT 1 
            FROM sales s
            WHERE s.a_team_id = atr.a_team_id
                AND s.sale_price > 50000
        )
)
ORDER BY ar.artist_name;

-- 9.6 EXISTS 在数据验证中的应用
IF NOT EXISTS (
    SELECT 1 
    FROM artist_roster ar
    WHERE NOT EXISTS (
        SELECT 1 
        FROM art_team_results atr 
        WHERE atr.a_team_id = ar.a_team_id
    )
)
    PRINT '数据完整性验证通过：所有艺术家都有队伍记录';
ELSE
    PRINT '数据完整性验证失败：存在没有队伍记录的艺术家';

GO

-- ========================================
-- 第10章：CASE表达式高级应用
-- ========================================

-- 10.1 简单 CASE：状态映射
SELECT 
    ar.artist_id,
    ar.artist_name,
    CASE ar.senior_artist
        WHEN 'Y' THEN '资深艺术家'
        WHEN 'N' THEN '普通艺术家'
        ELSE '未评级'
    END AS ArtistLevel
FROM artist_roster ar
ORDER BY ar.artist_name;

-- 10.2 搜索 CASE：范围判断
SELECT 
    pd.artist_id,
    pd.point_amt,
    CASE 
        WHEN pd.point_amt >= 100 THEN '顶级表现'
        WHEN pd.point_amt >= 80 THEN '优秀'
        WHEN pd.point_amt >= 60 THEN '良好'
        WHEN pd.point_amt >= 40 THEN '一般'
        ELSE '需努力'
    END AS PerformanceLevel
FROM point_details pd
WHERE pd.round_stage = 'G'
ORDER BY pd.point_amt DESC;

-- 10.3 CASE 在聚合中：条件统计
SELECT 
    ar.specialization_id,
    COUNT(*) AS TotalArtists,
    SUM(CASE WHEN ar.senior_artist = 'Y' THEN 1 ELSE 0 END) AS SeniorCount,
    SUM(CASE WHEN ar.senior_artist = 'Y' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS SeniorPercentage
FROM artist_roster ar
GROUP BY ar.specialization_id
ORDER BY SeniorPercentage DESC;

-- 10.4 多条件 CASE：复杂分类
SELECT 
    ar.artist_name,
    ar.date_of_birth,
    DATEDIFF(YEAR, ar.date_of_birth, GETDATE()) AS Age,
    CASE 
        WHEN ar.senior_artist = 'Y' AND DATEDIFF(YEAR, ar.date_of_birth, GETDATE()) >= 30 
            THEN 'A类：资深且年长'
        WHEN ar.senior_artist = 'Y' AND DATEDIFF(YEAR, ar.date_of_birth, GETDATE()) < 30 
            THEN 'B类：资深但年轻'
        WHEN ar.senior_artist <> 'Y' AND DATEDIFF(YEAR, ar.date_of_birth, GETDATE()) >= 30 
            THEN 'C类：普通但年长'
        ELSE 'D类：普通且年轻'
    END AS ArtistCategory
FROM artist_roster ar
ORDER BY ArtistCategory, ar.artist_name;

-- 10.5 CASE 在 ORDER BY 中：自定义排序
SELECT 
    ar.artist_name,
    ar.specialization_id,
    ar.senior_artist
FROM artist_roster ar
ORDER BY 
    CASE ar.specialization_id
        WHEN 'PT' THEN 1
        WHEN 'PH' THEN 2
        WHEN 'SC' THEN 3
    END,
    CASE WHEN ar.senior_artist = 'Y' THEN 0 ELSE 1 END;

-- 10.6 CASE 正确处理 NULL
SELECT 
    ar.artist_id,
    ar.artist_name,
    CASE 
        WHEN ar.prev_art_studio IS NULL THEN '无工作室变更'
        ELSE ar.prev_art_studio
    END AS PrevStudioFixed
FROM artist_roster ar;

-- 10.7 CASE 在 HAVING 中：分组后筛选
SELECT 
    ar.specialization_id,
    COUNT(*) AS ArtistCount,
    SUM(CASE WHEN ar.senior_artist = 'Y' THEN 1 ELSE 0 END) AS SeniorCount
FROM artist_roster ar
GROUP BY ar.specialization_id
HAVING SUM(CASE WHEN ar.senior_artist = 'Y' THEN 1 ELSE 0 END) > 0
ORDER BY SeniorCount DESC;

-- 10.8 嵌套 CASE：多层条件
SELECT 
    ar.artist_name,
    pd.point_amt,
    CASE 
        WHEN pd.point_type = 'PERF' THEN
            CASE 
                WHEN pd.point_amt >= 100 THEN '完美表现'
                ELSE '一般表现'
            END
        WHEN pd.point_type = 'SALE' THEN
            CASE 
                WHEN pd.point_amt >= 50 THEN '热销'
                ELSE '平销'
            END
        ELSE '其他'
    END AS DetailedCategory
FROM artist_roster ar
INNER JOIN point_details pd ON ar.artist_id = pd.artist_id
ORDER BY pd.point_type, pd.point_amt DESC;

GO

-- ========================================
-- 综合练习：高级查询组合应用
-- ========================================

-- 练习1：使用多种技术查询各专业得分最高的艺术家
;WITH SpecAvgPoints AS (
    SELECT 
        ar.specialization_id,
        ar.artist_id,
        ar.artist_name,
        SUM(pd.point_amt) AS TotalPoints,
        AVG(pd.point_amt) AS AvgPoints,
        ROW_NUMBER() OVER (
            PARTITION BY ar.specialization_id 
            ORDER BY SUM(pd.point_amt) DESC
        ) AS RankInSpec
    FROM artist_roster ar
    INNER JOIN point_details pd ON ar.artist_id = pd.artist_id
    GROUP BY ar.specialization_id, ar.artist_id, ar.artist_name
)
SELECT 
    sp.specialization_desc AS 专业,
    sap.artist_name AS 艺术家,
    sap.TotalPoints AS 总得分,
    sap.AvgPoints AS 平均得分,
    CASE 
        WHEN sap.RankInSpec = 1 THEN '是该专业冠军'
        ELSE '普通参赛者'
    END AS 称号
FROM SpecAvgPoints sap
INNER JOIN art_specialization sp ON sap.specialization_id = sp.specialization_id
WHERE sap.RankInSpec <= 3  -- 每个专业前三名
ORDER BY sp.specialization_desc, sap.RankInSpec;

-- 练习2：竞赛表现综合分析
SELECT 
    ar.artist_name AS 艺术家,
    ar.cur_art_studio AS 当前工作室,
    sp.specialization_desc AS 专业,
    ISNULL(TotalPoints, 0) AS 总得分,
    ISNULL(SaleCount, 0) AS 销售次数,
    ISNULL(SaleTotal, 0) AS 销售总额,
    CASE 
        WHEN ISNULL(TotalPoints, 0) > 100 AND ISNULL(SaleTotal, 0) > 50000 THEN '双优艺术家'
        WHEN ISNULL(TotalPoints, 0) > 100 THEN '得分高手'
        WHEN ISNULL(SaleTotal, 0) > 50000 THEN '销售明星'
        ELSE '潜力新星'
    END AS 综合评价
FROM artist_roster ar
INNER JOIN art_specialization sp ON ar.specialization_id = sp.specialization_id
LEFT JOIN (
    SELECT artist_id, SUM(point_amt) AS TotalPoints
    FROM point_details
    GROUP BY artist_id
) pp ON ar.artist_id = pp.artist_id
LEFT JOIN (
    SELECT artist_id, COUNT(*) AS SaleCount, SUM(sale_price) AS SaleTotal
    FROM sales
    GROUP BY artist_id
) ss ON ar.artist_id = ss.artist_id
ORDER BY 综合评价 DESC, ISNULL(SaleTotal, 0) DESC;

PRINT '所有高级查询示例执行完成！';
GO