-- ============================================================================
-- ART_CONTEST 数据库视图设计用例
-- ============================================================================
-- 项目名称：ART_CONTEST 艺术大赛数据库
-- 设计目的：提供常用业务查询的数据视图封装，简化应用层查询逻辑
-- 设计原则：
--   1. 视图命名遵循 v_业务含义 的规范
--   2. 每个视图附带详细的功能说明和使用场景注释
--   3. 视图仅支持 SELECT 查询，不包含业务逻辑修改
-- ============================================================================

-- ============================================================================
-- 视图 1: v_artist_complete_info - 艺术家完整信息视图
-- ============================================================================
-- 功能描述：
--   整合艺术家基本信息、所属国家、专业领域的工作室信息
--   提供艺术家的完整档案视图，便于快速查询艺术家背景资料
--
-- 关联表：
--   - artist_roster：艺术家基本信息
--   - art_country：国家/团队信息
--   - art_specialization：专业领域代码表
--
-- 使用场景：
--   1. 前端展示艺术家个人资料卡片
--   2. 后台管理界面查询艺术家列表
--   3. 统计各国家/团队的艺术家分布情况
--
-- 返回字段说明：
--   - artist_id：艺术家唯一标识
--   - artist_name：艺术家姓名
--   - country_id/country_name：所属国家ID和名称
--   - specialization_id/specialization_desc：专业领域代码和描述
--   - senior_artist：是否为资深艺术家(Y/N)
--   - date_of_birth：出生日期
--   - age：计算年龄
--   - prev_art_studio/cur_art_studio：之前和当前工作室
-- ============================================================================

USE ART_CONTEST;
GO

CREATE OR ALTER VIEW v_artist_complete_info
AS
SELECT
    ar.artist_id,
    ar.artist_name,
    ar.a_team_id AS country_id,
    ac.country_name,
    ar.specialization_id,
    aspt.specialization_desc,
    ar.senior_artist,
    ar.date_of_birth,
    DATEDIFF(YEAR, ar.date_of_birth, GETDATE()) AS age,
    ar.prev_art_studio,
    ar.cur_art_studio
FROM artist_roster ar
INNER JOIN art_country ac ON ar.a_team_id = ac.country_id
INNER JOIN art_specialization aspt ON ar.specialization_id = aspt.specialization_id;
GO


-- ============================================================================
-- 视图 2: v_round_detail_info - 比赛轮次详细信息视图
-- ============================================================================
-- 功能描述：
--   整合比赛轮次的完整信息，包括画廊、评委、参赛艺术家、得分等
--   提供轮次级别的综合查询视图
--
-- 关联表：
--   - round_summary：轮次汇总信息
--   - art_gallery：画廊信息
--   - judge_roster：评委信息
--   - artist_roster：艺术家信息
--   - art_country：国家信息
--
-- 使用场景：
--   1. 赛事直播/回放页面展示轮次详情
--   2. 赛事管理系统查询轮次安排
--   3. 生成赛事进展报告
--
-- 返回字段说明：
--   - round_id：轮次ID
--   - gallery_id/gallery_name：画廊ID和名称
--   - round_stage：轮次阶段(Q/F/S)
--   - round_week：轮次周次
--   - points_scored：得分
--   - head_judge_id/judge_name：主评委ID和姓名
--   - artist_of_round：参赛艺术家ID
--   - artist_name/nationality：艺术家姓名和国籍
--   - voters_no：投票人数
-- ============================================================================

CREATE OR ALTER VIEW v_round_detail_info
AS
SELECT
    rs.round_id,
    rs.gallery_id,
    ag.gallery_name,
    rs.round_stage,
    rs.round_week,
    rs.points_scored,
    rs.head_judge_id,
    jr.judge_name,
    rs.artist_of_round,
    ar.artist_name,
    ac.country_name AS nationality,
    rs.voters_no
FROM round_summary rs
INNER JOIN art_gallery ag ON rs.gallery_id = ag.gallery_id
INNER JOIN judge_roster jr ON rs.head_judge_id = jr.judge_id
INNER JOIN artist_roster ar ON rs.artist_of_round = ar.artist_id
INNER JOIN art_country ac ON ar.a_team_id = ac.country_id;
GO


-- ============================================================================
-- 视图 3: v_sales_summary - 销售汇总视图
-- ============================================================================
-- 功能描述：
--   整合销售记录信息，包括艺术品、买家、艺术家和团队信息
--   提供销售业务的核心查询视图
--
-- 关联表：
--   - sales：销售记录表
--   - artist_roster：艺术家信息
--   - art_country：国家/团队信息
--   - round_summary：轮次信息（用于获取画廊等）
--   - artwork_details：艺术品详情
--
-- 使用场景：
--   1. 销售报表生成
--   2. 艺术家销售业绩查询
--   3. 团队销售贡献统计
--   4. 买家类型分析
--
-- 返回字段说明：
--   - sale_id：销售记录ID
--   - sale_date：销售日期（从round_summary获取）
--   - artwork_id：艺术品ID
--   - artwork_title：艺术品名称
--   - artist_id/artist_name：艺术家ID和姓名
--   - team_id/team_name：团队ID和名称
--   - sale_price：销售价格
--   - buyer_type：买家类型(G/C：画廊/收藏家)
--   - gallery_name：画廊名称
-- ============================================================================

CREATE OR ALTER VIEW v_sales_summary
AS
SELECT
    s.sale_id,
    rs.round_week AS sale_date,
    s.artwork_id,
    ad.artwork_title,
    s.artist_id,
    ar.artist_name,
    s.a_team_id AS team_id,
    ac.country_name AS team_name,
    s.sale_price,
    s.buyer_type,
    ag.gallery_name
FROM sales s
INNER JOIN artist_roster ar ON s.artist_id = ar.artist_id
INNER JOIN art_country ac ON s.a_team_id = ac.country_id
INNER JOIN round_summary rs ON s.round_id = rs.round_id
INNER JOIN art_gallery ag ON rs.gallery_id = ag.gallery_id
LEFT JOIN artwork_details ad ON s.artwork_id = ad.artwork_id;
GO


-- ============================================================================
-- 视图 4: v_team_rankings - 团队排名视图
-- ============================================================================
-- 功能描述：
--   整合团队比赛成绩和排名信息
--   支持多维度排名计算（总分、专业分、投票分等）
--
-- 关联表：
--   - art_team_results：团队成绩表
--   - art_country：国家信息
--
-- 使用场景：
--   1. 赛事排行榜展示
--   2. 团队实力分析
--   3. 预测比赛走势
--
-- 排名维度：
--   - rounds_no：参赛轮次数
--   - r_won/r_lost：胜/负场次
--   - points_for_team：团队总分
--   - p_s：专业评分
--   - p_v2/p_v3：投票评分
-- ============================================================================

CREATE OR ALTER VIEW v_team_rankings
AS
SELECT
    atr.a_team_id,
    ac.country_name,
    atr.round_stage,
    atr.in_group,
    atr.rounds_no,
    atr.r_won,
    atr.r_lost,
    atr.points_for_team,
    atr.p_s,
    atr.p_v2,
    atr.p_v3,
    CASE
        WHEN atr.points_for_team = 0 THEN 0
        ELSE CAST(atr.r_won AS FLOAT) / atr.rounds_no * 100
    END AS win_rate,
    RANK() OVER (PARTITION BY atr.round_stage ORDER BY atr.points_for_team DESC) AS overall_rank,
    RANK() OVER (PARTITION BY atr.round_stage ORDER BY atr.p_s DESC) AS specialty_rank
FROM art_team_results atr
INNER JOIN art_country ac ON atr.a_team_id = ac.country_id;
GO


-- ============================================================================
-- 视图 5: v_judge_assignments - 评委分配视图
-- ============================================================================
-- 功能描述：
--   展示评委在各轮次中的分配情况
--   便于赛事组织者管理评委工作安排
--
-- 关联表：
--   - judge_roster：评委信息
--   - round_summary：轮次信息
--   - art_gallery：画廊信息
--
-- 使用场景：
--   1. 评委工作量统计
--   2. 轮次评委安排查询
--   3. 评委评审历史追溯
--
-- 特殊说明：
--   - 仅展示担任主评委(head_judge)的记录
--   - 可扩展为包含所有评审角色的完整视图
-- ============================================================================

CREATE OR ALTER VIEW v_judge_assignments
AS
SELECT
    jr.judge_id,
    jr.judge_name,
    rs.round_id,
    rs.round_stage,
    rs.round_week,
    ag.gallery_name
FROM judge_roster jr
INNER JOIN round_summary rs ON jr.judge_id = rs.head_judge_id
INNER JOIN art_gallery ag ON rs.gallery_id = ag.gallery_id;
GO


-- ============================================================================
-- 视图 6: v_liked_artists_popular - 最受欢迎艺术家视图
-- ============================================================================
-- 功能描述：
--   整合最受喜爱艺术家投票数据
--   展示艺术家的受欢迎程度和邀请情况
--
-- 关联表：
--   - liked_artist：喜爱艺术家投票记录
--   - artist_roster：艺术家信息
--   - art_country：国家信息
--   - round_summary：轮次信息
--
-- 使用场景：
--   1. 人气排行榜展示
--   2. 粉丝互动数据分析
--   3. 艺术家影响力评估
--
-- 返回字段说明：
--   - artist_id/artist_name：艺术家信息
--   - team_name：所属团队
--   - liked_count：被喜爱次数
--   - invited_count：受邀次数
--   - round_count：参赛轮次
-- ============================================================================

CREATE OR ALTER VIEW v_liked_artists_popular
AS
SELECT
    ar.artist_id,
    ar.artist_name,
    ac.country_name AS team_name,
    COUNT(la.artist_id) AS liked_count,
    SUM(CASE WHEN la.invited IS NOT NULL THEN 1 ELSE 0 END) AS invited_count,
    (SELECT COUNT(DISTINCT artist_of_round) FROM round_summary WHERE artist_of_round = ar.artist_id) AS round_count
FROM liked_artist la
INNER JOIN artist_roster ar ON la.artist_id = ar.artist_id
INNER JOIN art_country ac ON ar.a_team_id = ac.country_id
GROUP BY ar.artist_id, ar.artist_name, ac.country_name;
GO


-- ============================================================================
-- 视图 7: v_senior_artists_details - 资深艺术家详情视图
-- ============================================================================
-- 功能描述：
--   整合资深艺术家的详细信息，包括参赛成绩和获奖情况
--   用于管理和展示资深艺术家的比赛数据
--
-- 关联表：
--   - senior_artist_details：资深艺术家详情
--   - artist_roster：艺术家基本信息
--   - art_country：国家信息
--   - art_specialization：专业领域
--
-- 使用场景：
--   1. 资深艺术家档案管理
--   2. 明星选手展示页面
--   3. 资深艺术家参赛统计
--
-- 返回字段说明：
--   - artist_id/artist_name：艺术家信息
--   - country_name：所属国家
--   - specialization_desc：专业领域
--   - comp_total：参赛总场次
--   - awards_won：获奖次数
--   - career_title：职业称号
-- ============================================================================

CREATE OR ALTER VIEW v_senior_artists_details
AS
SELECT
    sad.artist_id,
    ar.artist_name,
    ac.country_name,
    aspt.specialization_desc,
    sad.comp_total,
    sad.awards_won
FROM senior_artist_details sad
INNER JOIN artist_roster ar ON sad.artist_id = ar.artist_id
INNER JOIN art_country ac ON ar.a_team_id = ac.country_id
INNER JOIN art_specialization aspt ON ar.specialization_id = aspt.specialization_id;
GO


-- ============================================================================
-- 视图 8: v_point_details_汇总 - 积分明细汇总视图
-- ============================================================================
-- 功能描述：
--   整合积分明细数据，展示各团队/艺术家在比赛中的得分情况
--   支持多维度积分分析
--
-- 关联表：
--   - point_details：积分详情表
--   - art_country：国家信息
--   - artist_roster：艺术家信息
--
-- 使用场景：
--   1. 积分排行榜展示
--   2. 得分明细查询
--   3. 积分波动分析
--
-- 积分类型说明：
--   - p_s：专业评分(Professional Score)
--   - p_v2：观众投票分 Version 2
--   - p_v3：观众投票分 Version 3
-- ============================================================================

CREATE OR ALTER VIEW v_point_details_summary
AS
SELECT
    pd.a_team_id,
    ac.country_name,
    pd.round_id,
    pd.point_type,
    ar.artist_name,
    CASE
        WHEN pd.point_type = 'p_s' THEN '专业评分'
        WHEN pd.point_type = 'p_v2' THEN '观众投票V2'
        WHEN pd.point_type = 'p_v3' THEN '观众投票V3'
        ELSE pd.point_type
    END AS point_type_desc
FROM point_details pd
INNER JOIN art_country ac ON pd.a_team_id = ac.country_id
LEFT JOIN artist_roster ar ON pd.artist_id = ar.artist_id;
GO


-- ============================================================================
-- 视图 9: v_round_captains_teams - 轮次队长分配视图
-- ============================================================================
-- 功能描述：
--   展示各轮次中各团队的队长分配情况
--   用于确认队长身份和团队领导信息
--
-- 关联表：
--   - round_captain：轮次队长表
--   - artist_roster：艺术家信息
--   - art_country：国家信息
--   - round_summary：轮次信息
--
-- 使用场景：
--   1. 队长身份确认
--   2. 团队领导查询
--   3. 队长轮换统计
--
-- 特殊说明：
--   - 队长可能来自其他团队（非本地团队）
--   - artist_captain_id 指向担任队长的艺术家ID
-- ============================================================================

CREATE OR ALTER VIEW v_round_captains_teams
AS
SELECT
    rc.round_id,
    rc.a_team_id,
    ac.country_name AS team_name,
    rc.artist_captain_id,
    ar.artist_name AS captain_name,
    rs.round_stage,
    rs.round_week
FROM round_captain rc
INNER JOIN art_country ac ON rc.a_team_id = ac.country_id
INNER JOIN artist_roster ar ON rc.artist_captain_id = ar.artist_id
INNER JOIN artist_roster ar_cur ON rc.artist_captain_id = ar_cur.artist_id
INNER JOIN round_summary rs ON rc.round_id = rs.round_id;
GO


-- ============================================================================
-- 视图 10: v_gallery_events - 画廊赛事活动视图
-- ============================================================================
-- 功能描述：
--   整合画廊举办的赛事活动信息
--   展示画廊与赛事的关联关系
--
-- 关联表：
--   - art_gallery：画廊信息
--   - art_city：城市信息
--   - round_summary：轮次信息
--
-- 使用场景：
--   1. 画廊办赛统计
--   2. 赛事场地安排查询
--   3. 画廊曝光度分析
--
-- 返回字段说明：
--   - gallery_id/gallery_name：画廊信息
--   - city_name/country_name：所在城市和国家
--   - event_count：举办赛事场次
--   - total_artists：参赛艺术家总数
-- ============================================================================

CREATE OR ALTER VIEW v_gallery_events
AS
SELECT
    ag.gallery_id,
    ag.gallery_name,
    act.city_name,
    ac.country_name,
    COUNT(DISTINCT rs.round_id) AS event_count,
    COUNT(DISTINCT rs.artist_of_round) AS total_artists,
    SUM(CAST(rs.voters_no AS INT)) AS total_voters
FROM art_gallery ag
INNER JOIN art_city act ON ag.city_id = act.city_id
INNER JOIN art_country ac ON act.country_id = ac.country_id
LEFT JOIN round_summary rs ON ag.gallery_id = rs.gallery_id
GROUP BY ag.gallery_id, ag.gallery_name, act.city_name, ac.country_name;
GO


-- ============================================================================
-- 视图使用示例
-- ============================================================================

-- 示例1: 查询所有法国艺术家的完整信息
-- SELECT * FROM v_artist_complete_info WHERE country_name = 'France';

-- 示例2: 查询决赛阶段的所有轮次详情
-- SELECT * FROM v_round_detail_info WHERE round_stage = 'F' ORDER BY round_week;

-- 示例3: 查询销售业绩排名前10的艺术家
-- SELECT TOP 10 artist_name, team_name, SUM(sale_price) AS total_sales
-- FROM v_sales_summary
-- GROUP BY artist_name, team_name
-- ORDER BY total_sales DESC;

-- 示例4: 查询各团队总分排名
-- SELECT overall_rank, country_name, points_for_team, p_s, p_v2, p_v3
-- FROM v_team_rankings
-- WHERE round_stage = 'F'
-- ORDER BY overall_rank;

-- 示例5: 查询最受欢迎艺术家TOP5
-- SELECT TOP 5 artist_name, team_name, liked_count, invited_count
-- FROM v_liked_artists_popular
-- ORDER BY liked_count DESC;

-- ============================================================================
-- 文档结束
-- ============================================================================
