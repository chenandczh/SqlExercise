# SQL Server 高级查询技术全面指南

## 文档概述

本文档系统梳理软件开发场景中的高级查询技能需求，结合 ART_CONTEST 数据库的实际表结构和数据特征，提供完整的 SQL 查询示例和业务应用场景说明。

---

## 目录

1. [复杂条件组合查询](#1-复杂条件组合查询)
2. [多表关联查询](#2-多表关联查询)
3. [子查询应用](#3-子查询应用)
4. [聚合分析与统计](#4-聚合分析与统计)
5. [数据排序与分页](#5-数据排序与分页)
6. [窗口函数应用](#6-窗口函数应用)
7. [公用表表达式(CTE)](#7-公用表表达式cte)
8. [PIVOT与UNPIVOT](#8-pivot与unpivot)
9. [EXISTS与NOT EXISTS](#9-exists与not-exists)
10. [CASE表达式高级应用](#10-case表达式高级应用)

---

## 1. 复杂条件组合查询

### 1.1 业务场景

在艺术大赛管理系统中，需要查询符合多种条件组合的参赛队伍、艺术家或作品信息。常见的条件组合包括：数值范围筛选、模糊匹配、空值判断、多值匹配等。

### 1.2 技能要点

| 技能 | 说明 |
|------|------|
| AND/OR 组合 | 组合多个条件 |
| BETWEEN | 范围查询 |
| IN/NOT IN | 多值匹配 |
| LIKE | 模糊匹配 |
| IS NULL/IS NOT NULL | 空值判断 |

### 1.3 SQL示例

```sql
-- ========================================
-- 场景：查询参赛队伍综合统计数据
-- ========================================

-- 1. 基础条件组合：查询特定分组且积分达标的队伍
SELECT 
    a_team_id,
    round_stage,
    in_group,
    r_won,
    r_lost,
    points_for_team
FROM art_team_results
WHERE in_group = 'A'                    -- 分组条件
    AND points_for_team >= 15           -- 数值范围
    AND r_won > r_lost;                 -- 比较条件

-- 2. BETWEEN 范围查询：查询积分在特定区间的队伍
SELECT 
    a_team_id,
    round_stage,
    points_for_team
FROM art_team_results
WHERE points_for_team BETWEEN 15 AND 20  -- 包含端点值
ORDER BY points_for_team DESC;

-- 3. IN 多值匹配：查询多个队伍的信息
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.specialization_id,
    ar.cur_art_studio
FROM artist_roster ar
WHERE ar.a_team_id IN (1021, 1025, 1034)  -- 多个队伍
ORDER BY ar.a_team_id, ar.artist_name;

-- 4. LIKE 模糊匹配：查询工作室名称包含特定关键词的艺术家
SELECT 
    artist_id,
    artist_name,
    cur_art_studio,
    prev_art_studio
FROM artist_roster
WHERE cur_art_studio LIKE '%Art Studio%'      -- 包含关键词
   OR prev_art_studio LIKE '%Art Studio%';

-- 5. 复合条件：综合查询
SELECT 
    a_team_id,
    round_stage,
    in_group,
    points_for_team,
    p_s,
    p_v2
FROM art_team_results
WHERE (in_group = 'A' OR in_group = 'B')      -- OR条件组
    AND points_for_team >= 12
    AND p_s > p_v2                            -- 额外筛选条件
ORDER BY in_group, points_for_team DESC;
```

### 1.4 查询结果说明

| 条件类型 | 使用频率 | 性能提示 |
|----------|----------|----------|
| 等值连接 (=) | 最高 | 可利用索引 |
| 范围查询 (BETWEEN, >, <) | 高 | 建议建立索引 |
| 模糊匹配 (LIKE) | 中 | 避免前缀通配符 |
| OR 组合 | 中 | 考虑用 UNION 替代 |

---

## 2. 多表关联查询

### 2.1 业务场景

艺术大赛涉及多个数据表：参赛队伍、艺术家、画廊、城市、国家等。查询时需要通过外键关联获取完整的业务信息。

### 2.2 技能要点

| 连接类型 | 说明 | 使用场景 |
|----------|------|----------|
| INNER JOIN | 仅返回匹配行 | 获取有关联的数据 |
| LEFT JOIN | 返回左表全部 | 需要保留左表数据 |
| RIGHT JOIN | 返回右表全部 | 需要保留右表数据 |
| FULL OUTER JOIN | 返回全部数据 | 需要保留双方数据 |
| CROSS JOIN | 笛卡尔积 | 生成组合数据 |

### 2.3 SQL示例

```sql
-- ========================================
-- 场景：查询艺术家及其所属队伍、国家和城市信息
-- ========================================

-- 1. INNER JOIN：艺术家详细信息（只显示有队伍和国家的艺术家）
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.specialization_id,
    sp.specialization_desc,           -- 专业描述
    ar.cur_art_studio
FROM artist_roster ar
INNER JOIN art_specialization sp 
    ON ar.specialization_id = sp.specialization_id;

-- 2. LEFT JOIN：查询所有艺术家及他们的队伍信息（包括无队伍的）
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.a_team_id,
    atr.round_stage,
    atr.points_for_team
FROM artist_roster ar
LEFT JOIN art_team_results atr 
    ON ar.a_team_id = atr.a_team_id
WHERE atr.round_stage = 'G'  -- 仅小组赛阶段
ORDER BY ar.artist_id;

-- 3. 多表连接：艺术家、队伍、国家、城市完整信息
SELECT 
    ar.artist_name,
    ar.cur_art_studio,
    ac.city_name,
    acn.country_name,
    acn.continent_name
FROM artist_roster ar
INNER JOIN art_team_results atr ON ar.a_team_id = atr.a_team_id
INNER JOIN art_gallery ag ON atr.a_team_id = ag.gallery_id  -- 假设关联
LEFT JOIN art_city ac ON ag.city_id = ac.city_id
LEFT JOIN art_country acn ON ac.country_id = acn.country_id
ORDER BY acn.country_name, ar.artist_name;

-- 4. 自连接：查询艺术家的工作室变动信息
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

-- 5. 聚合 + JOIN：各国家参赛艺术家数量统计
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

-- 6. CROSS JOIN：生成所有可能的比赛组合
SELECT 
    atr1.a_team_id AS Team1,
    atr2.a_team_id AS Team2,
    atr1.in_group
FROM art_team_results atr1
CROSS JOIN art_team_results atr2
WHERE atr1.a_team_id < atr2.a_team_id  -- 避免重复配对
    AND atr1.round_stage = 'G'
    AND atr2.round_stage = 'G'
    AND atr1.in_group = atr2.in_group;  -- 仅同组比赛
```

### 2.4 连接性能优化建议

| 优化项 | 说明 |
|--------|------|
| 选择小表驱动大表 | LEFT JOIN 时，右表数据量小更好 |
| 创建适当索引 | 外键列建立索引加速连接 |
| 避免 SELECT * | 只查询需要的列 |
| 减少嵌套连接 | 超过5个表连接考虑优化 |

---

## 3. 子查询应用

### 3.1 业务场景

子查询是解决复杂业务逻辑的强大工具，常用于数据过滤、计算和条件判断。

### 3.2 技能要点

| 子查询类型 | 说明 |
|------------|------|
| 标量子查询 | 返回单个值 |
| 表值子查询 | 返回多行多列 |
| 相关子查询 | 依赖外部查询 |
| NOT IN / NOT EXISTS | 排除逻辑 |

### 3.3 SQL示例

```sql
-- ========================================
-- 场景：分析艺术家得分和比赛表现
-- ========================================

-- 1. 标量子查询：计算每个艺术家相对于平均分的差异
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

-- 2. 表值子查询：查询积分高于特定艺术家平均分的艺术家
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

-- 3. 相关子查询：查询每个队伍中得分最高的艺术家
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

-- 4. NOT IN 排除查询：查询从未获得过满分的艺术家
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.cur_art_studio
FROM artist_roster ar
WHERE ar.artist_id NOT IN (
    SELECT DISTINCT artist_id 
    FROM point_details 
    WHERE point_type = 'PERF'  -- 满分类型
)
ORDER BY ar.artist_id;

-- 5. EXISTS 检查：查询是否存在符合条件的记录
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

-- 6. 多层嵌套子查询：查询顶级队伍中的艺术家
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

-- 7. 子查询在 UPDATE 中应用：更新艺术家的工作室信息
UPDATE artist_roster
SET cur_art_studio = 'Elite Art Studio'
WHERE artist_id IN (
    SELECT TOP 10 artist_id 
    FROM point_details 
    GROUP BY artist_id 
    ORDER BY SUM(point_amt) DESC
);
```

### 3.4 子查询性能优化

| 优化技巧 | 适用场景 |
|----------|----------|
| 用 JOIN 替代子查询 | 子查询返回大结果集 |
| 用 EXISTS 替代 IN | 只关心是否存在匹配 |
| 避免相关子查询嵌套 | 考虑用窗口函数替代 |
| 确保子查询有索引 | 加速过滤条件 |

---

## 4. 聚合分析与统计

### 4.1 业务场景

需要对数据进行分组统计、汇总分析，支持业务决策和报表生成。

### 4.2 技能要点

| 聚合函数 | 说明 |
|----------|------|
| COUNT/SUM | 计数和求和 |
| AVG/MIN/MAX | 平均/最小/最大 |
| GROUP BY | 分组统计 |
| HAVING | 分组后过滤 |
| DISTINCT COUNT | 去重计数 |

### 4.3 SQL示例

```sql
-- ========================================
-- 场景：艺术大赛数据统计分析
-- ========================================

-- 1. 基础聚合统计：计算各分组总积分
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

-- 2. 多重分组：按阶段和分组统计
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

-- 3. HAVING 过滤：筛选符合条件的分组
SELECT 
    in_group,
    COUNT(*) AS TeamCount,
    AVG(points_for_team) AS AvgPoints
FROM art_team_results
WHERE round_stage = 'G'
GROUP BY in_group
HAVING AVG(points_for_team) > 15   -- 平均积分大于15
ORDER BY AvgPoints DESC;

-- 4. 聚合 + JOIN：统计每位艺术家的得分
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

-- 5. DISTINCT COUNT：统计独立艺术家数量
SELECT 
    round_stage,
    COUNT(DISTINCT artist_id) AS UniqueArtists,
    COUNT(DISTINCT a_team_id) AS UniqueTeams,
    COUNT(*) AS TotalRecords
FROM point_details
GROUP BY round_stage
ORDER BY round_stage;

-- 6. 条件聚合：统计各类型得分
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

-- 7. 聚合函数嵌套：计算分组内占比
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
```

### 4.4 聚合查询性能要点

| 要点 | 说明 |
|------|------|
| GROUP BY 列建索引 | 加速分组操作 |
| 避免 SELECT * | 只选需要的列 |
| 过滤条件放 WHERE | 减少分组数据量 |
| HAVING 放最后 | 对分组结果过滤 |

---

## 5. 数据排序与分页

### 5.1 业务场景

展示数据时需要按特定字段排序，并支持分页显示以提升性能和用户体验。

### 5.2 技能要点

| 技术 | 说明 |
|------|------|
| ORDER BY | 单列/多列排序 |
| ASC/DESC | 升序/降序 |
| OFFSET-FETCH | SQL Server 2012+ 分页 |
| TOP | 限制返回行数 |

### 5.3 SQL示例

```sql
-- ========================================
-- 场景：分页展示参赛艺术家列表
-- ========================================

-- 1. 基础排序：按积分降序排列
SELECT TOP 10
    ar.artist_id,
    ar.artist_name,
    ar.cur_art_studio,
    SUM(pd.point_amt) AS TotalPoints
FROM artist_roster ar
LEFT JOIN point_details pd ON ar.artist_id = pd.artist_id
GROUP BY ar.artist_id, ar.artist_name, ar.cur_art_studio
ORDER BY TotalPoints DESC;  -- 降序排列

-- 2. 多列排序：先按分组，再按积分
SELECT 
    a_team_id,
    in_group,
    points_for_team,
    r_won,
    r_lost
FROM art_team_results
WHERE round_stage = 'G'
ORDER BY 
    in_group ASC,              -- 先按分组升序
    points_for_team DESC;      -- 再按积分降序

-- 3. OFFSET-FETCH 分页（推荐方式）
DECLARE @PageNumber INT = 2;      -- 第2页
DECLARE @PageSize INT = 10;        -- 每页10条

SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.date_of_birth,
    ar.specialization_id,
    ar.cur_art_studio
FROM artist_roster ar
ORDER BY ar.artist_name
OFFSET (@PageNumber - 1) * @PageSize ROWS      -- 跳过前N行
FETCH NEXT @PageSize ROWS ONLY;                  -- 取下一页

-- 4. 完整分页查询（带总数）
DECLARE @PageNumber INT = 1;
DECLARE @PageSize INT = 10;

;WITH TotalCount AS (
    SELECT COUNT(*) AS TotalRows FROM artist_roster
)
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.date_of_birth,
    ar.cur_art_studio,
    tc.TotalRows,
    CEILING(CAST(tc.TotalRows AS DECIMAL(10,2)) / @PageSize) AS TotalPages
FROM artist_roster ar
CROSS JOIN TotalCount tc
ORDER BY ar.artist_name
OFFSET (@PageNumber - 1) * @PageSize ROWS
FETCH NEXT @PageSize ROWS ONLY;

-- 5. NULL 值排序处理
SELECT 
    artist_id,
    artist_name,
    prev_art_studio,
    cur_art_studio
FROM artist_roster
ORDER BY 
    CASE WHEN prev_art_studio IS NULL THEN 1 ELSE 0 END,  -- NULL 值排在最后
    prev_art_studio DESC;

-- 6. 随机排序（抽样调查）
SELECT TOP 5
    artist_id,
    artist_name,
    cur_art_studio
FROM artist_roster
ORDER BY NEWID();  -- 随机排序

-- 7. 带排序表达式的复杂查询
SELECT 
    ar.artist_id,
    ar.artist_name,
    ar.date_of_birth,
    DATEDIFF(YEAR, ar.date_of_birth, GETDATE()) AS Age,
    CASE 
        WHEN DATEDIFF(YEAR, ar.date_of_birth, GETDATE()) < 25 THEN '青年'
        WHEN DATEDIFF(YEAR, ar.date_of_birth, GETDATE()) < 35 THEN '中年'
        ELSE '资深'
    END AS AgeGroup
FROM artist_roster ar
ORDER BY 
    CASE 
        WHEN ar.senior_artist = 'Y' THEN 0 
        ELSE 1 
    END,                           -- 资深艺术家优先
    Age DESC;                      -- 再按年龄降序
```

### 5.4 分页性能对比

| 分页方式 | 适用版本 | 性能 |
|----------|----------|------|
| TOP + 子查询 | 所有版本 | 较差（深分页慢） |
| OFFSET-FETCH | SQL 2012+ | 良好 |
| CTE + ROW_NUMBER | SQL 2005+ | 良好 |
|键值分页（游标） | 所有版本 | 最优（但复杂） |

---

## 6. 窗口函数应用

### 6.1 业务场景

窗口函数是 SQL Server 2005+ 引入的强大功能，可在不分组的情况下计算排名、累计值、移动平均等。

### 6.2 技能要点

| 函数类型 | 函数 | 说明 |
|----------|------|------|
| 行号 | ROW_NUMBER | 连续编号 |
| 排名 | RANK/DENSE_RANK | 排名（可并列） |
| 导航 | LAG/LEAD | 前后行数据 |
| 聚合 | SUM/AVG/COUNT over | 窗口聚合 |
| 首尾 | FIRST/LAST | 取首尾值 |

### 6.3 SQL示例

```sql
-- ========================================
-- 场景：艺术家得分排名和趋势分析
-- ========================================

-- 1. ROW_NUMBER：生成分组内连续编号
SELECT 
    ar.artist_name,
    ar.specialization_id,
    pd.point_amt,
    pd.round_id,
    ROW_NUMBER() OVER (
        PARTITION BY ar.specialization_id   -- 按专业分组
        ORDER BY pd.point_amt DESC          -- 组内按积分排序
    ) AS RowNumInGroup
FROM artist_roster ar
INNER JOIN point_details pd ON ar.artist_id = pd.artist_id
WHERE pd.round_stage = 'G'
ORDER BY ar.specialization_id, RowNumInGroup;

-- 2. RANK 与 DENSE_RANK：排名计算
SELECT 
    ar.artist_id,
    ar.artist_name,
    pd.point_amt,
    ROW_NUMBER() OVER (ORDER BY pd.point_amt DESC) AS RowNum,
    RANK() OVER (ORDER BY pd.point_amt DESC) AS [Rank],        -- 并列跳过
    DENSE_RANK() OVER (ORDER BY pd.point_amt DESC) AS DenseRank  -- 并列不跳过
FROM artist_roster ar
INNER JOIN point_details pd ON ar.artist_id = pd.artist_id
WHERE pd.round_stage = 'G'
ORDER BY pd.point_amt DESC;

-- 3. LAG/LEAD：获取前一个/后一个的值
SELECT 
    pd.round_id,
    pd.a_team_id,
    pd.point_amt,
    pd.point_type,
    LAG(pd.point_amt, 1) OVER (          -- 前一行积分
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
    ) AS PrevPoint,
    LEAD(pd.point_amt, 1) OVER (         -- 后一行积分
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
    ) AS NextPoint,
    pd.point_amt - LAG(pd.point_amt, 1) OVER (  -- 与上轮差值
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
    ) AS PointDiff
FROM point_details pd
WHERE pd.artist_id = 2102  -- 指定艺术家
ORDER BY pd.round_id;

-- 4. 窗口聚合：计算累计和移动平均
SELECT 
    pd.round_id,
    pd.artist_id,
    pd.point_amt,
    SUM(pd.point_amt) OVER (             -- 累计求和
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS RunningTotal,
    AVG(pd.point_amt) OVER (             -- 移动平均（最近3轮）
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS MovingAvg3,
    COUNT(pd.point_amt) OVER (           -- 截止当前的计数
        PARTITION BY pd.artist_id 
        ORDER BY pd.round_id
    ) AS RecordCount
FROM point_details pd
WHERE pd.artist_id IN (2102, 2501, 3411)  -- 多艺术家对比
ORDER BY pd.artist_id, pd.round_id;

-- 5. FIRST_VALUE/LAST_VALUE：取窗口首尾值
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

-- 6. NTILE：把数据分成N个组
SELECT 
    ar.artist_name,
    ar.date_of_birth,
    DATEDIFF(YEAR, ar.date_of_birth, GETDATE()) AS Age,
    NTILE(4) OVER (ORDER BY DATEDIFF(YEAR, ar.date_of_birth, GETDATE())) AS AgeQuartile
FROM artist_roster ar
ORDER BY AgeQuartile, ar.artist_name;

-- 7. 复杂窗口计算：竞赛排名实时更新
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

-- 8. 窗口函数在 UPDATE 中应用
UPDATE point_details
SET point_amt = point_amt + 
    (SELECT AVG(point_amt) * 0.1 
     FROM point_details pd2 
     WHERE pd2.artist_id = point_details.artist_id 
         AND pd2.round_stage = point_details.round_stage)
WHERE round_id > 10;  -- 仅更新特定轮次
```

### 6.4 窗口函数语法详解

```sql
-- 完整语法结构
FUNCTION_NAME() OVER (
    PARTITION BY column1, column2, ...   -- 分区列（可选）
    ORDER BY column3, column4, ...      -- 排序列（可选）
    ROWS/RANGE BETWEEN ...              -- 窗口框架（可选）
)
```

**窗口框架选项：**
- `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` - 从开始到当前行
- `ROWS BETWEEN 2 PRECEDING AND 1 FOLLOWING` - 前后2行范围
- `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` - 整个分区

---

## 7. 公用表表达式(CTE)

### 7.1 业务场景

CTE 是组织复杂查询的利器，可提高可读性和支持递归查询。

### 7.2 技能要点

| CTE类型 | 说明 |
|---------|------|
| 非递归 CTE | 简化复杂查询 |
| 递归 CTE | 处理层次结构 |
| 多重 CTE | 链式引用 |

### 7.3 SQL示例

```sql
-- ========================================
-- 场景：竞赛数据多维度分析
-- ========================================

-- 1. 非递归 CTE：简化复杂查询
;WITH ArtistStats AS (
    -- 第一次 CTE：计算艺术家积分
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
    -- 第二次 CTE：从第一个 CTE 结果中筛选
    SELECT TOP 5 *
    FROM ArtistStats
    WHERE TotalPoints > 0
    ORDER BY TotalPoints DESC
)
-- 最终查询：关联更多信息
SELECT 
    ta.artist_name,
    ta.TotalPoints,
    sp.specialization_desc
FROM TopArtists ta
INNER JOIN art_specialization sp ON ta.specialization_id = sp.specialization_id;

-- 2. 多重 CTE：链式数据处理
;WITH StageStats AS (
    -- 第一步：按阶段统计
    SELECT 
        round_stage,
        COUNT(DISTINCT a_team_id) AS TeamCount,
        SUM(points_for_team) AS TotalPoints
    FROM art_team_results
    GROUP BY round_stage
),
GroupStats AS (
    -- 第二步：按分组统计
    SELECT 
        in_group,
        COUNT(*) AS TeamCount,
        AVG(points_for_team) AS AvgPoints
    FROM art_team_results
    GROUP BY in_group
)
-- 最终结果：合并两个 CTE
SELECT 
    ss.round_stage,
    ss.TeamCount,
    gs.in_group,
    gs.TeamCount AS GroupTeamCount
FROM StageStats ss
CROSS JOIN GroupStats gs
ORDER BY ss.round_stage, gs.in_group;

-- 3. 递归 CTE：处理层次数据
-- 场景：假设有员工层次结构表，这里用艺术家表演评分演示
;WITH ScoreHierarchy AS (
    -- 基础查询：起始点
    SELECT 
        round_id,
        artist_id,
        point_amt,
        point_type,
        1 AS Level,
        CAST(point_amt AS VARCHAR(MAX)) AS Path
    FROM point_details
    WHERE round_id = 1
    
    UNION ALL
    
    -- 递归部分：逐层深入
    SELECT 
        pd.round_id,
        pd.artist_id,
        pd.point_amt,
        pd.point_type,
        sh.Level + 1,
        sh.Path + ' -> ' + CAST(pd.point_amt AS VARCHAR)
    FROM point_details pd
    INNER JOIN ScoreHierarchy sh ON pd.round_id = sh.round_id + 1
    WHERE sh.Level < 5  -- 递归深度限制
)
SELECT 
    Level,
    artist_id,
    point_amt,
    Path
FROM ScoreHierarchy
ORDER BY Path;

-- 4. CTE 替代子查询：提高可读性
-- 不使用 CTE（嵌套子查询）
SELECT *
FROM (
    SELECT 
        artist_id,
        SUM(point_amt) AS TotalPoints
    FROM point_details
    GROUP BY artist_id
) AS ArtistTotals
WHERE TotalPoints > (
    SELECT AVG(TotalPoints) 
    FROM (
        SELECT SUM(point_amt) AS TotalPoints
        FROM point_details
        GROUP BY artist_id
    ) AS AllTotals
);

-- 使用 CTE（更清晰）
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

-- 5. 递归 CTE：生成数字序列（替代 WHILE 循环）
;WITH Numbers AS (
    SELECT 1 AS Num
    UNION ALL
    SELECT Num + 1 
    FROM Numbers 
    WHERE Num < 100
)
SELECT Num FROM Numbers;

-- 6. CTE 在数据修改中的应用
;WITH HighScorers AS (
    SELECT artist_id 
    FROM point_details 
    GROUP BY artist_id 
    HAVING SUM(point_amt) > 100
)
UPDATE artist_roster
SET cur_art_studio = 'Champion Studio'
WHERE artist_id IN (SELECT artist_id FROM HighScorers);
```

### 7.4 CTE 性能特点

| 特点 | 说明 |
|------|------|
| 可读性高 | 逻辑清晰分段 |
| 可重复引用 | 一次定义多次使用 |
| 递归能力 | 处理层次结构 |
| 不创建对象 | 仅在查询时存在 |
| 性能等价 | 与子查询性能相近 |

---

## 8. PIVOT与UNPIVOT

### 8.1 业务场景

数据行列转换常用于报表生成，将明细数据转换为交叉表格形式。

### 8.2 技能要点

| 技术 | 说明 |
|------|------|
| PIVOT | 行转列 |
| UNPIVOT | 列转行 |
| 聚合组合 | 配合聚合函数 |

### 8.3 SQL示例

```sql
-- ========================================
-- 场景：竞赛数据交叉分析
-- ========================================

-- 1. PIVOT：行列转换（按得分类型统计）
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
    SUM(point_amt)               -- 聚合方式
    FOR point_type IN (          -- 要转换的列值
        [PERF], 
        [SALE], 
        [VOTE]
    )
) AS PivotTable
ORDER BY a_team_id;

-- 2. 动态 PIVOT：自动获取所有 point_type
DECLARE @Columns NVARCHAR(MAX);
DECLARE @SQL NVARCHAR(MAX);

-- 构建列名列表
SELECT @Columns = STRING_AGG(QUOTENAME(point_type), ', ')
FROM (SELECT DISTINCT point_type FROM point_details) AS types;

-- 构建动态 SQL
SET @SQL = N'
SELECT a_team_id, ' + @Columns + N'
FROM (
    SELECT a_team_id, point_type, point_amt
    FROM point_details
) AS SourceData
PIVOT (
    SUM(point_amt)
    FOR point_type IN (' + @Columns + N')
) AS PivotTable
ORDER BY a_team_id;';

EXEC sp_executesql @SQL;

-- 3. 多列 PIVOT：按阶段和类型统计
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

-- 4. UNPIVOT：列转行
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

-- 5. 复杂转换：带聚合的 PIVOT
SELECT 
    specialization_id,
    [G] AS GroupStagePoints,
    [S] AS SemiFinalPoints,
    Total = [G] + ISNULL([S], 0)
FROM (
    SELECT 
        ar.specialization_id,
        atr.round_stage,
        pd.point_amt
    FROM artist_roster ar
    INNER JOIN point_details pd ON ar.artist_id = pd.artist_id
    INNER JOIN art_team_results atr ON ar.a_team_id = atr.a_team_id
) AS SourceData
PIVOT (
    SUM(point_amt)
    FOR round_stage IN ([G], [S])
) AS PivotTable
ORDER BY specialization_id;

-- 6. PIVOT 结合 GROUP BY：分组统计
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
```

### 8.4 PIVOT 性能优化

| 优化项 | 说明 |
|--------|------|
| 源数据量控制 | 先过滤再 PIVOT |
| 索引优化 | 源表建立适当索引 |
| 动态 SQL 限制 | 谨慎使用，防止注入 |

---

## 9. EXISTS与NOT EXISTS

### 9.1 业务场景

用于检查子查询是否存在匹配行，是处理"是否存在"类业务逻辑的最佳选择。

### 9.2 技能要点

| 用法 | 适用场景 |
|------|----------|
| EXISTS | 确认存在至少一行 |
| NOT EXISTS | 确认不存在匹配行 |
| 性能优势 | 找到第一个匹配即停止 |

### 9.3 SQL示例

```sql
-- ========================================
-- 场景：业务资格和关系检查
-- ========================================

-- 1. EXISTS：查询有销售记录的艺术家
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

-- 2. NOT EXISTS：查询从未获得满分的艺术家
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

-- 3. 多条件 EXISTS：复合条件检查
SELECT 
    ar.artist_id,
    ar.artist_name
FROM artist_roster ar
WHERE EXISTS (
    SELECT 1 
    FROM sales s
    INNER JOIN artwork_details aw ON s.artwork_id = aw.artwork_id
    WHERE s.artist_id = ar.artist_id
        AND aw.orig_price > 30000          -- 作品原价高
        AND s.sale_price > aw.orig_price   -- 销售价格更高
)
ORDER BY ar.artist_name;

-- 4. NOT EXISTS 替代 NOT IN：避免 NULL 问题
-- 使用 NOT IN（有 NULL 风险）
SELECT artist_id
FROM artist_roster
WHERE artist_id NOT IN (SELECT artist_id FROM point_details);

-- 使用 NOT EXISTS（更安全）
SELECT ar.artist_id, ar.artist_name
FROM artist_roster ar
WHERE NOT EXISTS (
    SELECT 1 
    FROM point_details pd 
    WHERE pd.artist_id = ar.artist_id
);

-- 5. 双重 EXISTS：多层关系检查
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

-- 6. EXISTS 在数据验证中的应用
-- 验证：确保所有参赛艺术家都有队伍记录
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

-- 7. 复杂逻辑：查询满足多个条件的艺术家
SELECT 
    ar.artist_name,
    ar.specialization_id
FROM artist_roster ar
WHERE EXISTS (
    -- 条件1：有销售记录
    SELECT 1 FROM sales WHERE artist_id = ar.artist_id
)
AND EXISTS (
    -- 条件2：有得分记录
    SELECT 1 FROM point_details WHERE artist_id = ar.artist_id
)
AND EXISTS (
    -- 条件3：资深艺术家
    SELECT 1 FROM artist_roster WHERE artist_id = ar.artist_id AND senior_artist = 'Y'
)
ORDER BY ar.artist_name;
```

### 9.4 EXISTS vs IN vs JOIN

| 特性 | EXISTS | IN | JOIN |
|------|--------|-----|------|
| NULL 处理 | 安全 | 风险 | 视情况 |
| 多列支持 | 灵活 | 有限制 | 支持 |
| 性能 | 快速找到即停 | 需全部扫描 | 视情况 |
| 可读性 | 高 | 中 | 低 |

---

## 10. CASE表达式高级应用

### 10.1 业务场景

CASE 表达式是最常用的条件逻辑工具，可用于计算列、排序、分组等多种场景。

### 10.2 技能要点

| 类型 | 说明 |
|------|------|
| 简单 CASE | 匹配固定值 |
| 搜索 CASE | 条件表达式 |
| 聚合内 CASE | 条件聚合 |
| ORDER BY 中 CASE | 自定义排序 |

### 10.3 SQL示例

```sql
-- ========================================
-- 场景：数据分类和条件计算
-- ========================================

-- 1. 简单 CASE：状态映射
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

-- 2. 搜索 CASE：范围判断
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

-- 3. CASE 在聚合中：条件统计
SELECT 
    ar.specialization_id,
    COUNT(*) AS TotalArtists,
    SUM(CASE WHEN ar.senior_artist = 'Y' THEN 1 ELSE 0 END) AS SeniorCount,
    SUM(CASE WHEN ar.senior_artist = 'Y' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS SeniorPercentage
FROM artist_roster ar
GROUP BY ar.specialization_id
ORDER BY SeniorPercentage DESC;

-- 4. 多条件 CASE：复杂分类
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

-- 5. CASE 在 UPDATE 中：条件更新
UPDATE artist_roster
SET cur_art_studio = CASE 
    WHEN a_team_id = 1021 THEN 'Spain Elite Studio'
    WHEN a_team_id = 1025 THEN 'Czech Premier Studio'
    WHEN a_team_id = 1034 THEN 'France Art Studio'
    ELSE 'International Studio'
END
WHERE a_team_id IN (1021, 1025, 1034);

-- 6. CASE 在 ORDER BY 中：自定义排序
SELECT 
    ar.artist_name,
    ar.specialization_id,
    ar.senior_artist
FROM artist_roster ar
ORDER BY 
    CASE ar.specialization_id
        WHEN 'PT' THEN 1   -- 画家优先
        WHEN 'PH' THEN 2   -- 摄影师其次
        WHEN 'SC' THEN 3   -- 雕塑家最后
    END,
    CASE WHEN ar.senior_artist = 'Y' THEN 0 ELSE 1 END;  -- 资深优先

-- 7. CASE 处理 NULL：NULL 值替换
SELECT 
    ar.artist_id,
    ar.artist_name,
    CASE ar.prev_art_studio 
        WHEN NULL THEN '无工作室变更'  -- 注意：这里不会生效！
        ELSE ar.prev_art_studio
    END AS PrevStudioCorrect,
    -- 正确方式
    CASE 
        WHEN ar.prev_art_studio IS NULL THEN '无工作室变更'
        ELSE ar.prev_art_studio
    END AS PrevStudioFixed
FROM artist_roster ar;

-- 8. CASE 在 HAVING 中：分组后筛选
SELECT 
    ar.specialization_id,
    COUNT(*) AS ArtistCount,
    SUM(CASE WHEN ar.senior_artist = 'Y' THEN 1 ELSE 0 END) AS SeniorCount
FROM artist_roster ar
GROUP BY ar.specialization_id
HAVING SUM(CASE WHEN ar.senior_artist = 'Y' THEN 1 ELSE 0 END) > 0
ORDER BY SeniorCount DESC;

-- 9. 嵌套 CASE：多层条件
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

-- 10. CASE 与聚合函数结合：创建数据透视
SELECT 
    SUM(CASE WHEN round_stage = 'G' THEN 1 ELSE 0 END) AS GroupStageCount,
    SUM(CASE WHEN round_stage = 'S' THEN 1 ELSE 0 END) AS SemiFinalCount,
    SUM(CASE WHEN round_stage = 'F' THEN 1 ELSE 0 END) AS FinalCount
FROM art_team_results;
```

### 10.4 CASE 表达式性能特点

| 特点 | 说明 |
|------|------|
| 位置灵活 | SELECT、WHERE、ORDER BY、UPDATE |
| 性能开销 | 简单条件可忽略 |
| 可嵌套 | 支持多层 CASE |
| NULL 处理 | 注意 IS NULL 写法 |

---

## 附录：高级查询技能清单

### A. 核心技能检查表

| 技能领域 | 技能点 | 掌握程度 |
|----------|--------|----------|
| **条件查询** | AND/OR/NOT/BETWEEN/IN/LIKE | □ 精通 □ 熟悉 □ 了解 |
| **多表连接** | INNER/LEFT/RIGHT/FULL/CROSS JOIN | □ 精通 □ 熟悉 □ 了解 |
| **子查询** | 标量/表值/相关子查询 | □ 精通 □ 熟悉 □ 了解 |
| **聚合分析** | GROUP BY/HAVING/聚合函数 | □ 精通 □ 熟悉 □ 了解 |
| **排序分页** | ORDER BY/OFFSET-FETCH/TOP | □ 精通 □ 熟悉 □ 了解 |
| **窗口函数** | ROW_NUMBER/RANK/LAG/LEAD/SUM | □ 精通 □ 熟悉 □ 了解 |
| **CTE** | 非递归/递归/多重CTE | □ 精通 □ 熟悉 □ 了解 |
| **数据转换** | PIVOT/UNPIVOT | □ 精通 □ 熟悉 □ 了解 |
| **存在检查** | EXISTS/NOT EXISTS | □ 精通 □ 熟悉 □ 了解 |
| **条件逻辑** | CASE 表达式 | □ 精通 □ 熟悉 □ 了解 |

### B. 性能优化建议

1. **避免 SELECT *** - 只查询需要的列
2. **创建适当索引** - 外键列和过滤条件列
3. **理解执行计划** - 分析查询开销
4. **合理使用子查询** - 考虑用 JOIN 替代
5. **窗口函数优先** - 替代相关子查询
6. **避免函数在列上** - 导致索引失效

### C. 常见错误及解决方案

| 错误 | 原因 | 解决 |
|------|------|------|
| 子查询返回多行 | IN 使用了多行子查询 | 改用 EXISTS 或 ANY |
| NULL 比较失败 | NULL = NULL 不成立 | 使用 IS NULL |
| 列名歧义 | 多表有相同列名 | 使用表别名限定 |
| 类型转换错误 | 数据类型不匹配 | 显式转换 |
| 聚合函数嵌套 | 不能直接嵌套聚合 | 使用子查询 |
