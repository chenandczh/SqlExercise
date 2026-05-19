# ART_CONTEST 数据库结构分析文档

## 文档概述

- **数据库名称**: ART_CONTEST
- **数据库版本**: SQL Server 2022
- **兼容性级别**: 150 (SQL Server 2019)
- **分析日期**: 2026-05-17
- **文档目的**: 全面分析数据库表结构、字段定义、约束条件及表间关系

---

## 目录

1. [数据库概览](#数据库概览)
2. [表结构详细分析](#表结构详细分析)
3. [表间关系分析](#表间关系分析)
4. [实体关系图](#实体关系图)
5. [数据约束说明](#数据约束说明)

---

## 数据库概览

### 数据库基本信息

| 属性 | 值 |
|------|-----|
| 数据库名称 | ART_CONTEST |
| 服务器实例 | DESKTOP-4FGJ7U3 |
| 兼容性级别 | 150 (SQL Server 2019/2022) |
| 恢复模式 | SIMPLE |
| 文件流 | 已禁用 |
| 全文搜索 | 已安装并启用 |

### 数据库包含的表数量

本数据库共包含 **15** 个数据表，用于管理艺术大赛的完整业务流程。

---

## 表结构详细分析

### 1. art_country（国家/参赛团队表）

**功能说明**: 存储参赛国家信息，同时作为团队（Team）的标识。每个国家分配一个唯一的国家ID，该ID同时作为团队的a_team_id使用。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| country_id | int | NOT NULL | PRIMARY KEY | 国家ID（同时作为参赛团队ID） |
| country_name | varchar(20) | NOT NULL | - | 国家名称 |
| continent_name | varchar(20) | NOT NULL | - | 所属洲名 |

**示例数据**:

| country_id | country_name | continent_name |
|------------|--------------|----------------|
| 1021 | Spain | Europe |
| 1025 | Czech Republic | Europe |
| 1034 | France | Europe |
| 1046 | Sri Lanka | Asia |
| 1049 | USA | North America |
| 1055 | Canada | North America |
| 1058 | Chile | South America |
| 1076 | China | Asia |

---

### 2. art_city（城市表）

**功能说明**: 存储画廊所在城市信息，通过country_id与国家表关联，建立城市与国家的从属关系。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| city_id | int | NOT NULL | PRIMARY KEY | 城市唯一标识符 |
| city_name | varchar(25) | NOT NULL | - | 城市名称 |
| country_id | int | NULL | FOREIGN KEY -> art_country(country_id) | 所属国家ID |

**外键关系**:
- `country_id` -> `art_country(country_id)` (一对多：每个城市属于一个国家)

**示例数据**:

| city_id | city_name | country_id |
|---------|-----------|------------|
| 1200 | Los Angeles | 1049 |
| 1388 | New York | 1049 |
| 1455 | Boston | 1049 |
| 1677 | Toronto | 1055 |

---

### 3. art_gallery（画廊表）

**功能说明**: 存储画廊信息，记录画廊名称、所在城市及所有权性质。画廊是艺术品销售和展览的场所。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| gallery_id | int | NOT NULL | PRIMARY KEY | 画廊唯一标识符 |
| gallery_name | varchar(25) | NOT NULL | - | 画廊名称 |
| city_id | int | NULL | FOREIGN KEY -> art_city(city_id) | 所在城市ID |
| privately_owned | char(1) | NULL | - | 是否为私人所有 (Y/N) |

**外键关系**:
- `city_id` -> `art_city(city_id)` (一对多：每个城市可以有多个画廊)

**示例数据**:

| gallery_id | gallery_name | city_id | privately_owned |
|------------|--------------|---------|-----------------|
| 3114 | Gerard Gallery of Art | 1388 | Y |
| 3225 | Dali Art Gallery | 1677 | NULL |
| 3453 | Danbi Studio | 1455 | Y |
| 3988 | Grand Gallery | 1200 | NULL |

---

### 4. art_specialization（专业领域表）

**功能说明**: 定义艺术家的专业领域类别，用于对参赛艺术家进行分类管理。大赛接受三种专业类型的艺术家参赛。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| specialization_id | char(2) | NOT NULL | PRIMARY KEY | 专业领域代码 |
| specialization_desc | varchar(20) | NOT NULL | - | 专业领域描述 |

**专业领域代码说明**:

| 代码 | 描述 | 英文 |
|------|------|------|
| PH | 摄影师 | photographer |
| PT | 画家 | painter |
| SC | 雕塑家 | sculptor |

---

### 5. artist_roster（艺术家花名册表）

**功能说明**: 存储所有参赛艺术家的详细信息，包括个人基本信息、所属团队、专业领域及工作室信息。每个艺术家都必须属于一个参赛团队。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| artist_id | int | NOT NULL | PRIMARY KEY | 艺术家唯一标识符 |
| artist_name | varchar(50) | NOT NULL | - | 艺术家姓名 |
| a_team_id | int | NOT NULL | FOREIGN KEY -> art_country(country_id) | 所属团队/国家ID |
| specialization_id | char(2) | NOT NULL | FOREIGN KEY -> art_specialization(specialization_id) | 专业领域代码 |
| senior_artist | char(1) | NULL | - | 是否为资深艺术家 (Y/N) |
| date_of_birth | date | NOT NULL | - | 出生日期 |
| prev_art_studio | varchar(50) | NULL | - | 前工作室名称 |
| cur_art_studio | varchar(50) | NOT NULL | - | 当前工作室名称 |

**外键关系**:
- `a_team_id` -> `art_country(country_id)` (多对一：多个艺术家属于同一个团队)
- `specialization_id` -> `art_specialization(specialization_id)` (多对一：多个艺术家属于同一专业)

**业务规则**:
- 每个艺术家必须属于一个国家团队
- 艺术家必须指定一个专业领域

---

### 6. art_team_results（团队成绩表）

**功能说明**: 记录各参赛团队在各个比赛阶段（小组赛、半决赛）的竞技成绩，包括胜负场次、积分等信息。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| a_team_id | int | NOT NULL | FOREIGN KEY -> art_country(country_id), PRIMARY KEY(复合) | 团队/国家ID |
| round_stage | char(1) | NOT NULL | PRIMARY KEY(复合), CHECK(G/S) | 比赛阶段 |
| in_group | char(1) | NOT NULL | - | 所在小组 (A/B/C) |
| rounds_no | int | NOT NULL | - | 参加轮次数 |
| r_won | int | NOT NULL | - | 获胜场次 |
| r_lost | int | NOT NULL | - | 失败场次 |
| points_for_team | int | NOT NULL | - | 团队总积分 |
| p_s | int | NOT NULL | - | 销售积分 (Points-Sale) |
| p_v2 | int | NOT NULL | - | 第二名票数积分 (Points-Vote2) |
| p_v3 | int | NOT NULL | - | 第三名票数积分 (Points-Vote3) |

**外键关系**:
- `a_team_id` -> `art_country(country_id)` (多对一)

**约束条件**:
- `round_stage` 只能为 'G'（Group Stage/小组赛）或 'S'（Semi-final/半决赛）

**复合主键说明**:
- 主键由 `(a_team_id, round_stage)` 组合构成，确保每个团队在每个阶段只有一条成绩记录

---

### 7. artwork_details（艺术品详情表）

**功能说明**: 存储参赛艺术品的详细信息，包括作品名称、原创作者、原始定价等。艺术品是大赛交易和评审的核心对象。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| artwork_id | varchar(7) | NOT NULL | PRIMARY KEY | 艺术品唯一标识符 |
| artwork_title | varchar(40) | NOT NULL | - | 艺术品标题/名称 |
| a_team_id | int | NOT NULL | FOREIGN KEY -> art_country(country_id) | 所属团队ID |
| artist_id | int | NOT NULL | FOREIGN KEY -> artist_roster(artist_id) | 创作者ID |
| orig_price | int | NOT NULL | - | 原始定价 |

**外键关系**:
- `a_team_id` -> `art_country(country_id)` (多对一)
- `artist_id` -> `artist_roster(artist_id)` (多对一)

**ID编码规则**: artwork_id由数字+专业代码组成（如55183PT），最后两位表示创作者的专业领域。

---

### 8. judge_roster（评审团花名册表）

**功能说明**: 存储大赛评委的详细信息，包括姓名、职业、国籍及是否为首席评委。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| judge_id | int | NOT NULL | PRIMARY KEY | 评委唯一标识符 |
| judge_name | varchar(50) | NOT NULL | - | 评委姓名 |
| judge_occupation | varchar(50) | NOT NULL | - | 评委职业/头衔 |
| country_id | int | NOT NULL | FOREIGN KEY -> art_country(country_id) | 国籍ID |
| head_judge | char(1) | NULL | - | 是否为首席评委 (Y/N) |

**外键关系**:
- `country_id` -> `art_country(country_id)` (多对一)

**示例数据**:

| judge_id | judge_name | judge_occupation | country_id | head_judge |
|----------|------------|-------------------|------------|------------|
| 1234 | Anaya Raj | Curator | 1046 | Y |
| 1409 | Jonathan Welsh | Artistic Director | 1055 | Y |
| 1427 | Juliette Monet | Art critic | 1034 | Y |
| 1519 | Mateo Diaz | Philantropist | 1058 | Y |

---

### 9. round_summary（轮次汇总表）

**功能说明**: 记录每轮比赛的总体信息，包括举办画廊、比赛阶段、周次、总得分及本轮最佳艺术家等核心数据。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| round_id | int | NOT NULL | PRIMARY KEY, IDENTITY(1,1) | 轮次ID（自动增长） |
| gallery_id | int | NOT NULL | FOREIGN KEY -> art_gallery(gallery_id) | 举办画廊ID |
| round_stage | char(1) | NOT NULL | CHECK(G/S/F) | 比赛阶段 |
| round_week | int | NOT NULL | - | 比赛周次 |
| points_scored | varchar(5) | NOT NULL | - | 本轮得分 |
| head_judge_id | int | NOT NULL | FOREIGN KEY -> judge_roster(judge_id) | 首席评委ID |
| artist_of_round | int | NOT NULL | FOREIGN KEY -> artist_roster(artist_id) | 本轮最佳艺术家ID |
| voters_no | int | NOT NULL | - | 投票人数 |

**外键关系**:
- `gallery_id` -> `art_gallery(gallery_id)` (多对一)
- `head_judge_id` -> `judge_roster(judge_id)` (多对一)
- `artist_of_round` -> `artist_roster(artist_id)` (多对一)

**约束条件**:
- `round_stage` 只能为 'G'（Group）、'S'（Semi）或 'F'（Final）

---

### 10. round_details（轮次详情表）

**功能说明**: 记录各团队在每轮比赛中的具体表现数据，包括胜负结果、获得的积分及负责评审的评委。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| round_id | int | NOT NULL | FOREIGN KEY -> round_summary(round_id), PRIMARY KEY(复合) | 轮次ID |
| a_team_id | int | NOT NULL | FOREIGN KEY -> art_country(country_id), PRIMARY KEY(复合) | 团队ID |
| round_stage | char(1) | NOT NULL | CHECK(G/S/F) | 比赛阶段 |
| round_results | char(1) | NOT NULL | CHECK(W/L) | 比赛结果 (Win/Lose) |
| points_earned | int | NOT NULL | - | 获得积分 |
| sale_points | int | NOT NULL | - | 销售积分 |
| prom_artists_no | int | NOT NULL | - | 晋升艺术家数量 |
| judge_id | int | NOT NULL | FOREIGN KEY -> judge_roster(judge_id) | 评审评委ID |

**外键关系**:
- `round_id` -> `round_summary(round_id)` (多对一)
- `a_team_id` -> `art_country(country_id)` (多对一)
- `judge_id` -> `judge_roster(judge_id)` (多对一)

**约束条件**:
- `round_stage` 只能为 'G'、'S' 或 'F'
- `round_results` 只能为 'W'（Win）或 'L'（Lose）

**复合主键**: 由 `(round_id, a_team_id)` 组合构成

---

### 11. round_captain（轮次队长表）

**功能说明**: 指定每轮比赛中各团队的队长（艺术家代表），队长负责代表团队参与特定环节和决策。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| round_id | int | NOT NULL | FOREIGN KEY -> round_summary(round_id), PRIMARY KEY(复合) | 轮次ID |
| a_team_id | int | NOT NULL | FOREIGN KEY -> art_country(country_id), PRIMARY KEY(复合) | 团队ID |
| artist_captain_id | int | NOT NULL | FOREIGN KEY -> artist_roster(artist_id) | 队长艺术家ID |

**外键关系**:
- `round_id` -> `round_summary(round_id)` (多对一)
- `a_team_id` -> `art_country(country_id)` (多对一)
- `artist_captain_id` -> `artist_roster(artist_id)` (多对一)

**复合主键**: 由 `(round_id, a_team_id)` 组合构成

---

### 12. liked_artist（最受喜爱艺术家表）

**功能说明**: 记录每轮投票中最受公众喜爱的艺术家信息，包括获得的票数及是否被邀请参加后续活动。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| round_id | int | NOT NULL | FOREIGN KEY -> round_summary(round_id), PRIMARY KEY(复合) | 轮次ID |
| round_stage | char(1) | NOT NULL | CHECK(G/S/F), PRIMARY KEY(复合) | 比赛阶段 |
| a_team_id | int | NOT NULL | FOREIGN KEY -> art_country(country_id) | 艺术家所属团队ID |
| artist_id | int | NOT NULL | FOREIGN KEY -> artist_roster(artist_id) | 艺术家ID |
| like_no | int | NOT NULL | - | 获得的喜爱票数 |
| invited | char(1) | NULL | - | 是否被邀请 (Y/N) |

**外键关系**:
- `round_id` -> `round_summary(round_id)` (多对一)
- `a_team_id` -> `art_country(country_id)` (多对一)
- `artist_id` -> `artist_roster(artist_id)` (多对一)

**约束条件**:
- `round_stage` 只能为 'G'、'S' 或 'F'

**复合主键**: 由 `(round_id, round_stage, a_team_id, artist_id)` 组合构成

---

### 13. point_details（积分详情表）

**功能说明**: 详细记录每位艺术家在每轮比赛中获得的具体积分类型和积分值，支持多种积分来源的精细化追踪。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| point_id | int | NOT NULL | PRIMARY KEY, IDENTITY(1,1) | 积分记录ID（自动增长） |
| round_id | int | NOT NULL | FOREIGN KEY -> round_summary(round_id) | 轮次ID |
| a_team_id | int | NOT NULL | FOREIGN KEY -> art_country(country_id) | 团队ID |
| artist_id | int | NOT NULL | FOREIGN KEY -> artist_roster(artist_id) | 艺术家ID |
| point_amt | int | NOT NULL | - | 积分数量 |
| point_type | char(4) | NULL | CHECK(p_v3/p_v2/p_s) | 积分类型 |
| point_day_no | int | NOT NULL | - | 积分记录对应日期 |
| round_stage | char(1) | NOT NULL | CHECK(G/S/F) | 比赛阶段 |

**外键关系**:
- `round_id` -> `round_summary(round_id)` (多对一)
- `a_team_id` -> `art_country(country_id)` (多对一)
- `artist_id` -> `artist_roster(artist_id)` (多对一)

**积分类型说明**:

| 类型代码 | 描述 | 含义 |
|----------|------|------|
| p_s | Sale Points | 销售积分 |
| p_v2 | Vote2 Points | 第二名票数积分 |
| p_v3 | Vote3 Points | 第三名票数积分 |

**约束条件**:
- `point_type` 只能为 'p_v3'、'p_v2' 或 'p_s'
- `round_stage` 只能为 'G'、'S' 或 'F'

---

### 14. sales（销售记录表）

**功能说明**: 记录艺术品在比赛期间的销售交易信息，包括成交价格、买家类型等，是大赛商业化的核心数据记录。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| sale_id | int | NOT NULL | PRIMARY KEY, IDENTITY(1,1) | 销售记录ID（自动增长） |
| round_id | int | NOT NULL | FOREIGN KEY -> round_summary(round_id) | 轮次ID |
| a_team_id | int | NOT NULL | FOREIGN KEY -> art_country(country_id) | 团队ID |
| artist_id | int | NOT NULL | FOREIGN KEY -> artist_roster(artist_id) | 艺术家ID |
| artwork_id | varchar(7) | NOT NULL | FOREIGN KEY -> artwork_details(artwork_id) | 艺术品ID |
| sale_price | numeric(18,0) | NOT NULL | - | 销售价格 |
| buyer_type | char(3) | NOT NULL | CHECK(IND/ORG) | 买家类型 |
| sale_no | int | NOT NULL | - | 销售序号 |

**外键关系**:
- `round_id` -> `round_summary(round_id)` (多对一)
- `a_team_id` -> `art_country(country_id)` (多对一)
- `artist_id` -> `artist_roster(artist_id)` (多对一)
- `artwork_id` -> `artwork_details(artwork_id)` (多对一)

**买家类型说明**:

| 类型代码 | 描述 |
|----------|------|
| IND | 个人买家 (Individual) |
| ORG | 机构买家 (Organization) |

**约束条件**:
- `buyer_type` 只能为 'IND' 或 'ORG'

---

### 15. senior_artist_details（资深艺术家详情表）

**功能说明**: 存储被认定为资深艺术家（Senior Artist）的额外信息，包括其历史参赛总次数和所获奖项数量。

**表结构**:

| 字段名 | 数据类型 | 是否可空 | 约束 | 说明 |
|--------|----------|----------|------|------|
| a_team_id | int | NOT NULL | FOREIGN KEY -> art_country(country_id), PRIMARY KEY(复合) | 团队ID |
| artist_id | int | NOT NULL | FOREIGN KEY -> artist_roster(artist_id), PRIMARY KEY(复合) | 艺术家ID |
| comp_total | int | NOT NULL | - | 历史参赛总次数 |
| awards_won | int | NOT NULL | - | 获得奖项总数 |

**外键关系**:
- `a_team_id` -> `art_country(country_id)` (多对一)
- `artist_id` -> `artist_roster(artist_id)` (多对一)

**复合主键**: 由 `(a_team_id, artist_id)` 组合构成

---

## 表间关系分析

### 核心实体关系说明

#### 1. 层级结构关系（地理/组织维度）

```
art_country (国家/团队)
    ├── art_city (城市) → 1:N 关系
    │       └── art_gallery (画廊) → 1:N 关系
    │
    └── judge_roster (评委) → 1:N 关系（每位评委属于一个国家）
```

#### 2. 参赛团队与艺术家关系

```
art_country (国家/团队)
    │
    ├── artist_roster (艺术家) → 1:N 关系
    │       ├── artwork_details (艺术品) → 1:N 关系
    │       ├── senior_artist_details (资深艺术家) → 1:1 关系（仅资深艺术家）
    │       └── art_team_results (团队成绩) → 汇总数据
    │
    └── art_team_results (团队成绩)
            └── round_details (轮次详情) → 1:N 关系
```

#### 3. 比赛流程关系（核心业务维度）

```
round_summary (轮次汇总)
    │
    ├── round_details (团队表现) → 1:N
    │       └── judge_roster (评委评审)
    │
    ├── round_captain (轮次队长) → 1:N
    │
    ├── liked_artist (最受欢迎艺术家) → 1:N
    │
    ├── point_details (积分详情) → 1:N
    │       └── artist_roster (艺术家)
    │
    └── sales (销售记录) → 1:N
            ├── artist_roster (艺术家)
            └── artwork_details (艺术品)
```

### 一对多关系（1:N）

| 父表 | 子表 | 关系说明 |
|------|------|----------|
| art_country | art_city | 一个国家拥有多个城市 |
| art_country | artist_roster | 一个团队拥有多名艺术家 |
| art_country | judge_roster | 一个国家派出多名评委 |
| art_country | art_team_results | 一个团队有多个阶段成绩 |
| art_city | art_gallery | 一个城市拥有多个画廊 |
| art_specialization | artist_roster | 一种专业包含多名艺术家 |
| artist_roster | artwork_details | 一位艺术家创作多件艺术品 |
| artist_roster | liked_artist | 一位艺术家可多次获最受欢迎 |
| artist_roster | point_details | 一位艺术家有多条积分记录 |
| artist_roster | sales | 一位艺术家有多个销售记录 |
| round_summary | round_details | 一个轮次包含多个团队表现 |
| round_summary | liked_artist | 一个轮次有多位最受欢迎艺术家 |
| round_summary | point_details | 一个轮次有多条积分明细 |
| round_summary | sales | 一个轮次有多条销售记录 |
| round_summary | round_captain | 一个轮次有多个团队队长 |
| judge_roster | round_details | 一位评委可评审多轮比赛 |
| judge_roster | round_summary | 一位评委可担任多轮首席评委 |
| artwork_details | sales | 一件艺术品可产生多次销售 |
| art_gallery | round_summary | 一个画廊可举办多轮比赛 |

### 一对一关系（1:1）

| 表1 | 表2 | 关系说明 |
|-----|-----|----------|
| artist_roster (senior_artist='Y') | senior_artist_details | 资深艺术家才有详细记录 |

---

## 实体关系图

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              ART_CONTEST 数据库 ER 关系图                              │
└─────────────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────────┐         ┌─────────────────┐
    │  art_country    │         │ art_specialization│
    │─────────────────│         │─────────────────│
    │ PK country_id   │         │ PK specialization_id│
    │    country_name │         │    specialization_desc│
    │    continent_name│        └────────┬────────┘
    └────────┬────────┘                 │
             │                          │
             │ 1:N                       │ 1:N
             ▼                          ▼
    ┌─────────────────────────────────────────────────────┐
    │                  artist_roster                      │
    │─────────────────────────────────────────────────────│
    │ PK artist_id      │ FK→country_id                   │
    │    artist_name    │ FK→specialization_id            │
    │    senior_artist  │    date_of_birth                │
    │    prev_art_studio│    cur_art_studio                │
    └────────┬────────────────────────────────────────────┘
             │
             │ 1:N         1:N          1:N
             ├─────────────┼────────────┤
             ▼             ▼            ▼
    ┌─────────────┐ ┌───────────┐ ┌──────────────┐
    │artwork_details│ │point_details│ │   sales      │
    │─────────────│ │───────────│ │──────────────│
    │ PK artwork_id│ │ PK point_id │ │ PK sale_id   │
    │    title     │ │ FK→round_id │ │ FK→round_id  │
    │    FK→artist_id│ │ FK→artist_id│ │ FK→artist_id │
    │    FK→team_id │ │ point_amt   │ │ FK→artwork_id│
    │    orig_price │ │ point_type  │ │ sale_price   │
    └─────────────┘ │ point_day_no │ │ buyer_type   │
                     └─────────────┘ └──────────────┘
                              ▲
                              │
                    ┌─────────┴─────────┐
                    │  round_summary    │
                    │──────────────────│
                    │ PK round_id      │
                    │ FK→gallery_id    │
                    │    round_stage   │
                    │    round_week    │
                    │    points_scored │
                    │    head_judge_id │
                    │    artist_of_round│
                    │    voters_no      │
                    └────────┬─────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │ 1:N               │ 1:N               │ 1:N
          ▼                   ▼                   ▼
    ┌─────────────┐    ┌───────────┐     ┌─────────────┐
    │round_details│    │round_captain│    │liked_artist │
    │─────────────│    │───────────│    │─────────────│
    │ PK round_id │    │ PK round_id│    │ PK round_id │
    │ PK a_team_id│    │ PK a_team_id│   │ PK a_team_id│
    │ FK→team_id  │    │ FK→team_id │    │ FK→team_id  │
    │ round_stage │    │ artist_captain│  │ artist_id   │
    │ round_results│   └───────────┘    │ like_no     │
    │ points_earned│                    │ invited     │
    │ sale_points  │                    └─────────────┘
    │ judge_id     │
    └─────────────┘

    ┌─────────────────┐         ┌─────────────────┐
    │  art_gallery     │         │   art_city      │
    │─────────────────│         │─────────────────│
    │ PK gallery_id   │ 1:N    │ PK city_id      │
    │    gallery_name │─────────│ FK→country_id  │
    │    FK→city_id   │         │    city_name    │
    │    privately_owned│        └────────┬────────┘
    └─────────────────┘                  │ 1:N
                                         ▼
                                  ┌─────────────────┐
                                  │  judge_roster   │
                                  │─────────────────│
                                  │ PK judge_id    │
                                  │    judge_name   │
                                  │    judge_occupation│
                                  │ FK→country_id   │
                                  │    head_judge   │
                                  └─────────────────┘
```

---

## 数据约束说明

### CHECK 约束

| 表名 | 约束字段 | 允许值 | 说明 |
|------|----------|--------|------|
| art_team_results | round_stage | 'G', 'S' | 小组赛或半决赛 |
| liked_artist | round_stage | 'G', 'S', 'F' | 小组赛、半决赛或决赛 |
| point_details | point_type | 'p_v3', 'p_v2', 'p_s' | 积分类型 |
| point_details | round_stage | 'G', 'S', 'F' | 比赛阶段 |
| round_details | round_stage | 'G', 'S', 'F' | 比赛阶段 |
| round_details | round_results | 'W', 'L' | 胜或负 |
| round_summary | round_stage | 'G', 'S', 'F' | 比赛阶段 |
| sales | buyer_type | 'IND', 'ORG' | 个人或机构 |

### 业务规则总结

1. **团队标识统一**: `a_team_id` 与 `country_id` 共用同一套ID体系，简化了团队与国家的关系映射

2. **比赛阶段定义**:
   - G (Group): 小组赛阶段
   - S (Semi): 半决赛阶段
   - F (Final): 决赛阶段

3. **资深艺术家**: 只有 `senior_artist = 'Y'` 的艺术家才会在 `senior_artist_details` 表中有对应记录

4. **积分体系**:
   - p_s: 销售积分（通过艺术品销售获得）
   - p_v2: 第二名投票积分
   - p_v3: 第三名投票积分

5. **艺术品ID编码规则**: 艺术品ID末尾两位字符标识创作者的专业领域（如 "PT" 代表画家）

---

## 总结

ART_CONTEST 数据库设计合理、结构清晰，完整覆盖了艺术大赛的完整业务流程：

- **参赛管理**: 国家、团队、艺术家的层级管理体系
- **赛事管理**: 轮次、阶段、评委的赛事运行体系
- **作品管理**: 艺术品、画廊、销售的商业化体系
- **积分体系**: 多维度积分记录，支撑公平竞技

所有表通过外键约束形成有机的数据关联，确保了数据的一致性和完整性。