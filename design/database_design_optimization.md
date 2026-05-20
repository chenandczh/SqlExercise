# ART_CONTEST 数据库设计教程：规范化与优化

## 文档概述

本文档以 ART_CONTEST（艺术比赛）数据库为例，系统讲解数据库规范化设计、反规范化策略、索引设计原则和数据类型选择的最佳实践。

---

## 目录

1. [规范化设计（1NF-3NF）](#1-规范化设计1nf-3nf)
2. [反规范化策略](#2-反规范化策略)
3. [索引设计原则](#3-索引设计原则)
4. [数据类型选择最佳实践](#4-数据类型选择最佳实践)
5. [综合案例实践](#5-综合案例实践)

---

## 1. 规范化设计（1NF-3NF）

### 1.1 规范化概述

**规范化**是一种数据库设计方法，通过消除数据冗余和更新异常，提高数据的一致性和完整性。

| 范式 | 核心目标 | 解决的问题 |
|------|----------|-----------|
| **1NF** | 消除重复组 | 列不可再分 |
| **2NF** | 消除部分依赖 | 非主键字段完全依赖主键 |
| **3NF** | 消除传递依赖 | 非主键字段之间无依赖 |

### 1.2 第一范式（1NF）

#### 定义
- 每一列都是不可分割的原子值
- 同一列中不能有多个值
- 不能有重复的列组

#### 反例：非规范化表

```sql
-- 非规范化表（违反1NF）
CREATE TABLE NonNormalizedArtists (
    artist_id INT,
    artist_name VARCHAR(100),
    specializations VARCHAR(200),  -- 多个专长用逗号分隔
    team_members VARCHAR(500)     -- 多个成员用逗号分隔
);
```

**问题**：`specializations` 和 `team_members` 包含多个值，无法单独查询和更新。

#### 正例：符合1NF的表

```sql
-- 符合1NF的表结构
CREATE TABLE artists (
    artist_id INT PRIMARY KEY,
    artist_name VARCHAR(100) NOT NULL,
    a_team_id INT NOT NULL,
    specialization_id VARCHAR(10) NOT NULL
);

CREATE TABLE specialization (
    specialization_id VARCHAR(10) PRIMARY KEY,
    specialization_name VARCHAR(50) NOT NULL
);
```

**改进**：将多值字段拆分为独立的表，实现原子性。

### 1.3 第二范式（2NF）

#### 定义
- 满足1NF
- 所有非主键字段完全依赖于整个主键（不能只依赖主键的一部分）

#### 反例：违反2NF的表

```sql
-- 违反2NF的表（复合主键：artist_id + round_stage）
CREATE TABLE artist_scores (
    artist_id INT,
    round_stage CHAR(2),
    artist_name VARCHAR(100),  -- 只依赖artist_id
    team_name VARCHAR(100),    -- 只依赖artist_id
    score DECIMAL(5,2),
    judge_id INT,
    PRIMARY KEY (artist_id, round_stage)
);
```

**问题**：`artist_name` 和 `team_name` 只依赖于 `artist_id`，不依赖于 `round_stage`。

#### 正例：符合2NF的表

```sql
-- 拆分后的表结构
CREATE TABLE artist_roster (
    artist_id INT PRIMARY KEY,
    artist_name VARCHAR(100) NOT NULL,
    a_team_id INT NOT NULL
);

CREATE TABLE art_team (
    a_team_id INT PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL
);

CREATE TABLE point_details (
    artist_id INT,
    round_stage CHAR(2),
    score DECIMAL(5,2),
    judge_id INT,
    PRIMARY KEY (artist_id, round_stage)
);
```

**改进**：将部分依赖的字段分离到独立的表中。

### 1.4 第三范式（3NF）

#### 定义
- 满足2NF
- 非主键字段之间不存在传递依赖

#### 反例：违反3NF的表

```sql
-- 违反3NF的表
CREATE TABLE artist_roster (
    artist_id INT PRIMARY KEY,
    artist_name VARCHAR(100) NOT NULL,
    a_team_id INT NOT NULL,
    team_name VARCHAR(100) NOT NULL,  -- 通过a_team_id传递依赖
    country_code CHAR(3)              -- 通过a_team_id传递依赖
);
```

**问题**：`team_name` 和 `country_code` 通过 `a_team_id` 传递依赖。

#### 正例：符合3NF的表

```sql
-- 符合3NF的表结构
CREATE TABLE artist_roster (
    artist_id INT PRIMARY KEY,
    artist_name VARCHAR(100) NOT NULL,
    a_team_id INT NOT NULL,
    FOREIGN KEY (a_team_id) REFERENCES art_team(a_team_id)
);

CREATE TABLE art_team (
    a_team_id INT PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL,
    country_code CHAR(3) NOT NULL
);
```

**改进**：消除传递依赖，`team_name` 和 `country_code` 只在 `art_team` 表中维护。

### 1.5 ART_CONTEST 数据库规范化演变

| 阶段 | 表数量 | 特征 |
|------|--------|------|
| 非规范化 | 1 | 所有数据在一个表中 |
| 1NF | 3 | 拆分多值字段 |
| 2NF | 5 | 消除部分依赖 |
| 3NF | 7 | 消除传递依赖 |

---

## 2. 反规范化策略

### 2.1 反规范化概述

**反规范化**是在规范化的基础上，通过适当增加冗余来提高查询性能的技术。

### 2.2 适用场景分析

| 场景 | 说明 | ART_CONTEST 示例 |
|------|------|-----------------|
| **频繁查询** | 查询多于更新 | 比赛结果统计 |
| **复杂JOIN** | 多表关联查询 | 艺术家+队伍+成绩 |
| **报表需求** | 需要汇总数据 | 各阶段排名统计 |
| **性能瓶颈** | 查询响应慢 | 大数据量评分查询 |

### 2.3 反规范化方法

#### 方法1：增加冗余字段

```sql
-- 规范化设计
SELECT 
    ar.artist_name,
    t.team_name,
    t.country_code
FROM artist_roster ar
JOIN art_team t ON ar.a_team_id = t.a_team_id;

-- 反规范化设计（增加冗余字段）
CREATE TABLE artist_roster_denorm (
    artist_id INT PRIMARY KEY,
    artist_name VARCHAR(100) NOT NULL,
    a_team_id INT NOT NULL,
    team_name VARCHAR(100),      -- 冗余字段
    country_code CHAR(3)         -- 冗余字段
);
```

**优点**：减少JOIN操作，提高查询性能
**风险**：数据一致性问题，需要触发器维护

#### 方法2：创建汇总表

```sql
-- 创建汇总表
CREATE TABLE team_score_summary (
    a_team_id INT PRIMARY KEY,
    team_name VARCHAR(100),
    group_stage_points DECIMAL(10,2),
    semi_final_points DECIMAL(10,2),
    final_points DECIMAL(10,2),
    total_points DECIMAL(10,2),
    last_updated DATETIME DEFAULT GETDATE()
);

-- 汇总数据
INSERT INTO team_score_summary
SELECT 
    t.a_team_id,
    t.team_name,
    SUM(CASE WHEN r.round_stage = 'G' THEN r.total_points ELSE 0 END),
    SUM(CASE WHEN r.round_stage = 'S' THEN r.total_points ELSE 0 END),
    SUM(CASE WHEN r.round_stage = 'F' THEN r.total_points ELSE 0 END),
    SUM(r.total_points),
    GETDATE()
FROM art_team t
LEFT JOIN art_team_results r ON t.a_team_id = r.a_team_id
GROUP BY t.a_team_id, t.team_name;
```

**优点**：查询速度极快
**风险**：数据延迟，需要定时更新

#### 方法3：合并表

```sql
-- 规范化设计
SELECT 
    pd.point_amt,
    ar.artist_name,
    s.specialization_name
FROM point_details pd
JOIN artist_roster ar ON pd.artist_id = ar.artist_id
JOIN specialization s ON ar.specialization_id = s.specialization_id;

-- 反规范化设计（合并表）
CREATE TABLE score_details_denorm (
    point_id INT PRIMARY KEY,
    artist_id INT,
    artist_name VARCHAR(100),      -- 冗余
    specialization_name VARCHAR(50),-- 冗余
    round_stage CHAR(2),
    point_amt DECIMAL(5,2)
);
```

**优点**：消除JOIN，查询更快
**风险**：存储增加，更新复杂

### 2.4 反规范化风险与规避

| 风险 | 规避措施 |
|------|----------|
| **数据不一致** | 使用触发器或存储过程维护 |
| **存储增加** | 定期清理历史数据 |
| **更新性能下降** | 批量更新，减少事务时间 |
| **维护复杂度** | 文档化冗余字段，建立更新机制 |

### 2.5 ART_CONTEST 反规范化案例

**场景**：实时排行榜查询

```sql
-- 规范化查询（需要多表JOIN）
SELECT 
    t.team_name,
    SUM(r.total_points) AS total_score,
    RANK() OVER (ORDER BY SUM(r.total_points) DESC) AS ranking
FROM art_team t
JOIN art_team_results r ON t.a_team_id = r.a_team_id
GROUP BY t.team_name;

-- 反规范化方案：创建排行榜汇总表
CREATE TABLE team_ranking_summary (
    ranking INT,
    team_name VARCHAR(100),
    total_score DECIMAL(10,2),
    last_updated DATETIME
);

-- 使用触发器自动更新
CREATE TRIGGER trg_update_ranking
ON art_team_results AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- 重新计算排名
    UPDATE team_ranking_summary
    SET last_updated = GETDATE();
    
    -- 实际实现需要更复杂的逻辑
END
```

---

## 3. 索引设计原则

### 3.1 索引概述

**索引**是一种数据结构，用于加速数据库查询。索引通过牺牲写性能来换取读性能的提升。

### 3.2 索引类型与适用场景

| 索引类型 | 特点 | 适用场景 |
|----------|------|----------|
| **主键索引** | 唯一且非空 | 主键字段 |
| **唯一索引** | 唯一但可空 | 唯一约束字段 |
| **普通索引** | 可重复 | 经常用于WHERE条件 |
| **复合索引** | 多个字段组合 | 多条件查询 |
| **覆盖索引** | 包含查询所需所有字段 | 避免回表 |

### 3.3 ART_CONTEST 索引设计

#### 3.3.1 主键索引（自动创建）

```sql
-- 主键索引会自动创建
CREATE TABLE artist_roster (
    artist_id INT PRIMARY KEY,  -- 自动创建PK_artist_roster
    ...
);
```

#### 3.3.2 普通索引

```sql
-- 经常用于查询条件的字段
CREATE NONCLUSTERED INDEX IX_artist_roster_team
ON artist_roster(a_team_id);

CREATE NONCLUSTERED INDEX IX_artist_roster_specialization
ON artist_roster(specialization_id);
```

#### 3.3.3 复合索引

```sql
-- 多条件查询场景
CREATE NONCLUSTERED INDEX IX_results_team_stage
ON art_team_results(a_team_id, round_stage);

CREATE NONCLUSTERED INDEX IX_points_artist_stage
ON point_details(artist_id, round_stage);
```

#### 3.3.4 覆盖索引

```sql
-- 包含查询所需的所有字段，避免回表
CREATE NONCLUSTERED INDEX IX_orders_customer_include
ON orders(customer_id)
INCLUDE (order_id, order_date, status);
```

### 3.4 索引设计步骤

```
1. 分析查询需求
    ↓
2. 识别WHERE和JOIN条件
    ↓
3. 确定索引字段顺序（选择性高的字段在前）
    ↓
4. 考虑覆盖索引
    ↓
5. 评估索引数量和维护成本
```

### 3.5 索引设计误区

| 误区 | 说明 |
|------|------|
| **索引越多越好** | 过多索引会降低写性能 |
| **索引字段顺序无关** | 复合索引遵循最左匹配原则 |
| **所有字段都建索引** | 只在查询条件字段上建索引 |
| **忽略统计信息** | 定期更新统计信息 |

### 3.6 ART_CONTEST 索引优化建议

| 表名 | 索引建议 | 理由 |
|------|----------|------|
| artist_roster | IX_team, IX_specialization | 常用查询条件 |
| art_team_results | IX_team_stage | 组合查询 |
| point_details | IX_artist_stage | 评分查询 |
| orders | IX_customer, IX_status | 订单查询 |

---

## 4. 数据类型选择最佳实践

### 4.1 数据类型分类

| 类别 | 类型 | 特点 |
|------|------|------|
| **数值型** | INT, BIGINT, DECIMAL, FLOAT | 存储数字 |
| **字符型** | VARCHAR, CHAR, TEXT | 存储文本 |
| **日期型** | DATE, DATETIME, DATETIME2 | 存储时间 |
| **特殊类型** | BIT, UNIQUEIDENTIFIER | 特殊用途 |

### 4.2 数值型数据选择

| 类型 | 范围 | 存储空间 | 适用场景 |
|------|------|----------|----------|
| TINYINT | 0-255 | 1字节 | 状态码、小计数 |
| INT | -2^31~2^31-1 | 4字节 | 一般ID、数量 |
| BIGINT | -2^63~2^63-1 | 8字节 | 大数量、自增ID |
| DECIMAL(p,s) | 精确数值 | 可变 | 金额、评分 |
| FLOAT | 近似数值 | 4/8字节 | 科学计算 |

**ART_CONTEST 示例**：

```sql
CREATE TABLE artist_roster (
    artist_id INT,           -- 够用，无需BIGINT
    senior_artist BIT,       -- 布尔值用BIT
    ...
);

CREATE TABLE point_details (
    point_amt DECIMAL(5,2),  -- 评分精确到小数点后2位
    ...
);
```

### 4.3 字符型数据选择

| 类型 | 特点 | 适用场景 |
|------|------|----------|
| CHAR(n) | 固定长度 | 固定长度编码（如国家代码） |
| VARCHAR(n) | 可变长度 | 可变长度文本（如姓名） |
| NVARCHAR(n) | 可变长度Unicode | 需要存储中文等Unicode字符 |

**ART_CONTEST 示例**：

```sql
CREATE TABLE art_team (
    country_code CHAR(3),          -- 固定3位
    team_name NVARCHAR(100),       -- 可能包含中文
    ...
);

CREATE TABLE specialization (
    specialization_id VARCHAR(10),  -- 短编码
    specialization_name VARCHAR(50),-- 英文名称
    ...
);
```

### 4.4 日期时间型数据选择

| 类型 | 精度 | 存储空间 | 适用场景 |
|------|------|----------|----------|
| DATE | 日期 | 3字节 | 出生日期、成立日期 |
| DATETIME | 3.33ms | 8字节 | 一般时间记录 |
| DATETIME2 | 100ns | 6-8字节 | 高精度时间记录 |
| TIME | 时间 | 3-5字节 | 仅时间部分 |

**ART_CONTEST 示例**：

```sql
CREATE TABLE artist_roster (
    date_of_birth DATE,        -- 只需日期
    ...
);

CREATE TABLE point_details (
    point_date DATETIME2(0),   -- 需要时间，精确到秒
    ...
);
```

### 4.5 数据类型选择原则

| 原则 | 说明 |
|------|------|
| **最小够用** | 选择满足需求的最小类型 |
| **精确优先** | 金额等精确数据用DECIMAL |
| **语义清晰** | 使用最合适的类型（如BIT表示布尔） |
| **考虑国际化** | 需要Unicode时用NVARCHAR |
| **未来扩展** | 预留适当空间但不浪费 |

### 4.6 ART_CONTEST 数据类型推荐

| 字段 | 推荐类型 | 理由 |
|------|----------|------|
| artist_id | INT | 预计不超过20亿 |
| artist_name | NVARCHAR(100) | 支持中文姓名 |
| country_code | CHAR(3) | ISO 3166-1代码 |
| point_amt | DECIMAL(5,2) | 评分范围0-100 |
| date_of_birth | DATE | 只需日期 |
| team_name | NVARCHAR(100) | 支持中文队名 |

---

## 5. 综合案例实践

### 5.1 需求分析

**业务场景**：查询艺术家在各阶段的评分详情，包含艺术家姓名、队伍名称、专长、评分和评委信息。

### 5.2 规范化设计

```sql
-- 规范化表结构
CREATE TABLE art_team (
    a_team_id INT PRIMARY KEY,
    team_name NVARCHAR(100) NOT NULL,
    country_code CHAR(3) NOT NULL
);

CREATE TABLE specialization (
    specialization_id VARCHAR(10) PRIMARY KEY,
    specialization_name VARCHAR(50) NOT NULL
);

CREATE TABLE artist_roster (
    artist_id INT PRIMARY KEY,
    artist_name NVARCHAR(100) NOT NULL,
    a_team_id INT FOREIGN KEY REFERENCES art_team(a_team_id),
    specialization_id VARCHAR(10) FOREIGN KEY REFERENCES specialization(specialization_id)
);

CREATE TABLE point_details (
    point_id INT PRIMARY KEY,
    artist_id INT FOREIGN KEY REFERENCES artist_roster(artist_id),
    round_stage CHAR(2) NOT NULL,
    point_amt DECIMAL(5,2) NOT NULL,
    judge_id INT
);
```

### 5.3 查询优化

```sql
-- 创建必要的索引
CREATE INDEX IX_artist_team ON artist_roster(a_team_id);
CREATE INDEX IX_points_artist_stage ON point_details(artist_id, round_stage);

-- 查询示例
SELECT 
    ar.artist_name,
    t.team_name,
    s.specialization_name,
    pd.round_stage,
    pd.point_amt,
    pd.judge_id
FROM point_details pd
JOIN artist_roster ar ON pd.artist_id = ar.artist_id
JOIN art_team t ON ar.a_team_id = t.a_team_id
JOIN specialization s ON ar.specialization_id = s.specialization_id
WHERE pd.round_stage = 'G'
ORDER BY pd.point_amt DESC;
```

### 5.4 反规范化优化

```sql
-- 创建反规范化视图
CREATE VIEW v_artist_score_details AS
SELECT 
    pd.point_id,
    pd.artist_id,
    ar.artist_name,
    t.team_name,
    t.country_code,
    s.specialization_name,
    pd.round_stage,
    pd.point_amt,
    pd.judge_id
FROM point_details pd
JOIN artist_roster ar ON pd.artist_id = ar.artist_id
JOIN art_team t ON ar.a_team_id = t.a_team_id
JOIN specialization s ON ar.specialization_id = s.specialization_id;

-- 或创建物化视图（汇总表）
CREATE TABLE artist_score_summary (
    artist_id INT,
    artist_name NVARCHAR(100),
    team_name NVARCHAR(100),
    total_points DECIMAL(10,2),
    avg_points DECIMAL(5,2),
    last_updated DATETIME
);
```

---

## 附录

### A. 规范化检查清单

- [ ] 所有字段都是原子值（1NF）
- [ ] 非主键字段完全依赖主键（2NF）
- [ ] 非主键字段之间无传递依赖（3NF）
- [ ] 合理使用外键约束
- [ ] 避免数据冗余

### B. 索引设计检查清单

- [ ] 主键字段有索引
- [ ] 常用WHERE条件字段有索引
- [ ] 复合索引遵循最左匹配原则
- [ ] 考虑创建覆盖索引
- [ ] 索引数量合理

### C. 数据类型选择检查清单

- [ ] 使用最小够用的类型
- [ ] 金额使用DECIMAL类型
- [ ] 日期使用DATE/DATETIME2
- [ ] 需要Unicode时使用NVARCHAR
- [ ] 状态字段使用合适的数值类型
