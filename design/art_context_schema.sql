/*
ART_CONTEST 数据库完整SQL脚本
==============================
文件：art_context_schema.sql
版本：V1.0
日期：2026年5月
适用：SQL Server 2016+

包含：
1. 数据库创建
2. 表结构定义
3. 约束条件设置
4. 索引创建
5. 测试数据插入
*/

-- ========================================
-- 1. 创建数据库
-- ========================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ART_CONTEST')
BEGIN
    CREATE DATABASE ART_CONTEST
    ON PRIMARY (
        NAME = ART_CONTEST_data,
        FILENAME = 'D:\SQLData\ART_CONTEST.mdf',
        SIZE = 100MB,
        MAXSIZE = UNLIMITED,
        FILEGROWTH = 10MB
    )
    LOG ON (
        NAME = ART_CONTEST_log,
        FILENAME = 'D:\SQLLogs\ART_CONTEST.ldf',
        SIZE = 50MB,
        MAXSIZE = UNLIMITED,
        FILEGROWTH = 5MB
    );
    PRINT '数据库 ART_CONTEST 创建成功';
END
GO

USE ART_CONTEST;
GO

-- ========================================
-- 2. 创建表结构
-- ========================================

-- 2.1 art_team - 艺术队伍表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'art_team')
BEGIN
    CREATE TABLE art_team (
        a_team_id INT IDENTITY(1001, 1) PRIMARY KEY,
        team_name VARCHAR(100) NOT NULL,
        country_code CHAR(3) NOT NULL,
        in_group VARCHAR(20) NOT NULL,
        established_date DATE
    );
    PRINT '表 art_team 创建成功';
END
GO

-- 2.2 specialization - 专长类型表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'specialization')
BEGIN
    CREATE TABLE specialization (
        specialization_id VARCHAR(10) PRIMARY KEY,
        specialization_name VARCHAR(50) NOT NULL,
        description VARCHAR(200)
    );
    PRINT '表 specialization 创建成功';
END
GO

-- 2.3 artist_roster - 艺术家名册表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'artist_roster')
BEGIN
    CREATE TABLE artist_roster (
        artist_id INT IDENTITY(2001, 1) PRIMARY KEY,
        artist_name VARCHAR(100) NOT NULL,
        a_team_id INT NOT NULL,
        specialization_id VARCHAR(10) NOT NULL,
        senior_artist CHAR(1) DEFAULT 'N',
        date_of_birth DATE,
        prev_art_studio VARCHAR(50),
        cur_art_studio VARCHAR(50) NOT NULL,
        
        -- 外键约束
        CONSTRAINT FK_artist_roster_team FOREIGN KEY (a_team_id)
            REFERENCES art_team(a_team_id)
            ON DELETE CASCADE,
        
        CONSTRAINT FK_artist_roster_specialization FOREIGN KEY (specialization_id)
            REFERENCES specialization(specialization_id)
            ON DELETE NO ACTION,
        
        -- 检查约束
        CONSTRAINT CK_senior_artist CHECK (senior_artist IN ('Y', 'N'))
    );
    PRINT '表 artist_roster 创建成功';
END
GO

-- 2.4 art_team_results - 队伍比赛结果表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'art_team_results')
BEGIN
    CREATE TABLE art_team_results (
        result_id INT IDENTITY(1, 1) PRIMARY KEY,
        a_team_id INT NOT NULL,
        round_stage CHAR(2) NOT NULL,
        total_points DECIMAL(10, 2),
        ranking INT,
        result_date DATETIME DEFAULT GETDATE(),
        
        -- 外键约束
        CONSTRAINT FK_results_team FOREIGN KEY (a_team_id)
            REFERENCES art_team(a_team_id)
            ON DELETE CASCADE,
        
        -- 唯一约束
        CONSTRAINT UK_team_stage UNIQUE (a_team_id, round_stage)
    );
    PRINT '表 art_team_results 创建成功';
END
GO

-- 2.5 point_details - 评分详情表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'point_details')
BEGIN
    CREATE TABLE point_details (
        point_id INT IDENTITY(1, 1) PRIMARY KEY,
        artist_id INT NOT NULL,
        round_stage CHAR(2) NOT NULL,
        point_amt DECIMAL(5, 2) NOT NULL,
        judge_id INT,
        point_date DATETIME DEFAULT GETDATE(),
        
        -- 外键约束
        CONSTRAINT FK_points_artist FOREIGN KEY (artist_id)
            REFERENCES artist_roster(artist_id)
            ON DELETE CASCADE
    );
    PRINT '表 point_details 创建成功';
END
GO

-- 2.6 products - 产品信息表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'products')
BEGIN
    CREATE TABLE products (
        product_id VARCHAR(20) PRIMARY KEY,
        product_name VARCHAR(100) NOT NULL,
        price DECIMAL(10, 2) NOT NULL,
        version INT DEFAULT 1
    );
    PRINT '表 products 创建成功';
END
GO

-- 2.7 inventory - 库存信息表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'inventory')
BEGIN
    CREATE TABLE inventory (
        product_id VARCHAR(20) PRIMARY KEY,
        stock_qty INT DEFAULT 0,
        last_update DATETIME DEFAULT GETDATE(),
        
        -- 外键约束
        CONSTRAINT FK_inventory_product FOREIGN KEY (product_id)
            REFERENCES products(product_id)
            ON DELETE CASCADE
    );
    PRINT '表 inventory 创建成功';
END
GO

-- 2.8 orders - 订单信息表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'orders')
BEGIN
    CREATE TABLE orders (
        order_id VARCHAR(20) PRIMARY KEY,
        customer_id VARCHAR(20) NOT NULL,
        order_date DATETIME DEFAULT GETDATE(),
        status VARCHAR(20) DEFAULT 'Pending'
    );
    PRINT '表 orders 创建成功';
END
GO

-- 2.9 order_items - 订单项表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'order_items')
BEGIN
    CREATE TABLE order_items (
        item_id INT IDENTITY(1, 1) PRIMARY KEY,
        order_id VARCHAR(20) NOT NULL,
        product_id VARCHAR(20) NOT NULL,
        quantity INT NOT NULL,
        price DECIMAL(10, 2) NOT NULL,
        
        -- 外键约束
        CONSTRAINT FK_orderitems_order FOREIGN KEY (order_id)
            REFERENCES orders(order_id)
            ON DELETE CASCADE,
        
        CONSTRAINT FK_orderitems_product FOREIGN KEY (product_id)
            REFERENCES products(product_id)
            ON DELETE NO ACTION
    );
    PRINT '表 order_items 创建成功';
END
GO

-- 2.10 log_entries - 日志记录表
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'log_entries')
BEGIN
    CREATE TABLE log_entries (
        log_id INT IDENTITY(1, 1) PRIMARY KEY,
        message VARCHAR(500) NOT NULL,
        log_time DATETIME DEFAULT GETDATE()
    );
    PRINT '表 log_entries 创建成功';
END
GO

-- ========================================
-- 3. 创建索引
-- ========================================

-- 3.1 artist_roster 表索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_artist_roster_team')
BEGIN
    CREATE NONCLUSTERED INDEX IX_artist_roster_team 
        ON artist_roster(a_team_id);
    PRINT '索引 IX_artist_roster_team 创建成功';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_artist_roster_specialization')
BEGIN
    CREATE NONCLUSTERED INDEX IX_artist_roster_specialization 
        ON artist_roster(specialization_id);
    PRINT '索引 IX_artist_roster_specialization 创建成功';
END
GO

-- 3.2 art_team_results 表索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_results_team_stage')
BEGIN
    CREATE NONCLUSTERED INDEX IX_results_team_stage 
        ON art_team_results(a_team_id, round_stage);
    PRINT '索引 IX_results_team_stage 创建成功';
END
GO

-- 3.3 point_details 表索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_points_artist_stage')
BEGIN
    CREATE NONCLUSTERED INDEX IX_points_artist_stage 
        ON point_details(artist_id, round_stage);
    PRINT '索引 IX_points_artist_stage 创建成功';
END
GO

-- 3.4 orders 表索引
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_orders_customer')
BEGIN
    CREATE NONCLUSTERED INDEX IX_orders_customer 
        ON orders(customer_id);
    PRINT '索引 IX_orders_customer 创建成功';
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_orders_status')
BEGIN
    CREATE NONCLUSTERED INDEX IX_orders_status 
        ON orders(status);
    PRINT '索引 IX_orders_status 创建成功';
END
GO

-- ========================================
-- 4. 插入基础数据
-- ========================================

-- 4.1 插入专长类型数据
IF NOT EXISTS (SELECT * FROM specialization)
BEGIN
    INSERT INTO specialization (specialization_id, specialization_name, description)
    VALUES 
        ('PT', 'Painter', '油画/水彩画家'),
        ('PH', 'Photographer', '摄影师'),
        ('SC', 'Sculptor', '雕塑家');
    PRINT '专长类型数据插入成功';
END
GO

-- 4.2 插入队伍数据
IF NOT EXISTS (SELECT * FROM art_team)
BEGIN
    INSERT INTO art_team (team_name, country_code, in_group, established_date)
    VALUES 
        ('Team Alpha', 'USA', 'Group A', '2020-01-15'),
        ('Team Beta', 'CHN', 'Group A', '2019-06-20'),
        ('Team Gamma', 'ESP', 'Group B', '2021-03-10'),
        ('Team Delta', 'IND', 'Group B', '2020-09-01'),
        ('Team Epsilon', 'CZE', 'Group A', '2018-11-25');
    PRINT '队伍数据插入成功';
END
GO

-- 4.3 插入艺术家数据
IF NOT EXISTS (SELECT * FROM artist_roster)
BEGIN
    INSERT INTO artist_roster (artist_name, a_team_id, specialization_id, senior_artist, date_of_birth, prev_art_studio, cur_art_studio)
    VALUES 
        ('John Smith', 1001, 'PT', 'Y', '1985-03-15', 'Sunset Studio', 'New York Art Studio'),
        ('Emily Davis', 1001, 'PH', 'N', '1992-07-28', NULL, 'Bright Light Studio'),
        ('Michael Brown', 1002, 'SC', 'Y', '1980-11-05', 'Beijing Studio', 'Shanghai Art Center'),
        ('Li Wei', 1002, 'PT', 'N', '1995-04-12', 'Hangzhou Studio', 'Beijing Art Studio'),
        ('Maria Garcia', 1003, 'PH', 'Y', '1988-09-30', 'Madrid Studio', 'Barcelona Gallery'),
        ('Carlos Ruiz', 1003, 'PT', 'N', '1993-02-18', NULL, 'Valencia Art House'),
        ('Ravi Patel', 1004, 'SC', 'Y', '1982-06-22', 'Mumbai Studio', 'Delhi Art Workshop'),
        ('Anjali Sharma', 1004, 'PH', 'N', '1996-08-14', NULL, 'Bangalore Arts'),
        ('Jan Novak', 1005, 'PT', 'Y', '1979-05-08', 'Prague Studio', 'Brno Art Space'),
        ('Eva Horakova', 1005, 'SC', 'N', '1994-12-03', NULL, 'Ostrava Gallery');
    PRINT '艺术家数据插入成功';
END
GO

-- 4.4 插入比赛结果数据
IF NOT EXISTS (SELECT * FROM art_team_results)
BEGIN
    INSERT INTO art_team_results (a_team_id, round_stage, total_points, ranking)
    VALUES 
        (1001, 'G', 85.50, 2),
        (1002, 'G', 92.00, 1),
        (1003, 'G', 78.75, 3),
        (1004, 'G', 88.25, 2),
        (1005, 'G', 90.00, 1);
    PRINT '比赛结果数据插入成功';
END
GO

-- 4.5 插入评分详情数据
IF NOT EXISTS (SELECT * FROM point_details)
BEGIN
    INSERT INTO point_details (artist_id, round_stage, point_amt, judge_id)
    VALUES 
        (2001, 'G', 9.5, 1),
        (2001, 'G', 8.8, 2),
        (2002, 'G', 9.2, 1),
        (2002, 'G', 8.5, 2),
        (2003, 'G', 9.8, 1),
        (2003, 'G', 9.4, 2),
        (2004, 'G', 9.0, 1),
        (2004, 'G', 8.7, 2),
        (2005, 'G', 9.3, 1),
        (2005, 'G', 9.0, 2);
    PRINT '评分详情数据插入成功';
END
GO

-- 4.6 插入产品数据
IF NOT EXISTS (SELECT * FROM products)
BEGIN
    INSERT INTO products (product_id, product_name, price)
    VALUES 
        ('P001', '油画颜料套装', 199.99),
        ('P002', '专业相机', 2999.00),
        ('P003', '雕塑工具包', 150.00),
        ('P004', '画架', 250.00),
        ('P005', '摄影灯光设备', 899.00);
    PRINT '产品数据插入成功';
END
GO

-- 4.7 插入库存数据
IF NOT EXISTS (SELECT * FROM inventory)
BEGIN
    INSERT INTO inventory (product_id, stock_qty)
    VALUES 
        ('P001', 100),
        ('P002', 20),
        ('P003', 50),
        ('P004', 30),
        ('P005', 15);
    PRINT '库存数据插入成功';
END
GO

-- ========================================
-- 5. 创建视图
-- ========================================

-- 5.1 艺术家队伍视图
IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'v_artist_team')
BEGIN
    CREATE VIEW v_artist_team AS
    SELECT 
        ar.artist_id,
        ar.artist_name,
        ar.specialization_id,
        s.specialization_name,
        ar.cur_art_studio,
        t.team_name,
        t.country_code,
        t.in_group
    FROM artist_roster ar
    JOIN art_team t ON ar.a_team_id = t.a_team_id
    JOIN specialization s ON ar.specialization_id = s.specialization_id;
    PRINT '视图 v_artist_team 创建成功';
END
GO

-- 5.2 比赛成绩视图
IF NOT EXISTS (SELECT * FROM sys.views WHERE name = 'v_team_results')
BEGIN
    CREATE VIEW v_team_results AS
    SELECT 
        t.team_name,
        t.country_code,
        t.in_group,
        r.round_stage,
        r.total_points,
        r.ranking,
        r.result_date
    FROM art_team t
    JOIN art_team_results r ON t.a_team_id = r.a_team_id;
    PRINT '视图 v_team_results 创建成功';
END
GO

-- ========================================
-- 6. 创建存储过程
-- ========================================

-- 6.1 获取艺术家评分
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetArtistPoints')
BEGIN
    CREATE PROCEDURE GetArtistPoints
        @ArtistID INT
    AS
    BEGIN
        SELECT 
            pd.round_stage,
            pd.point_amt,
            pd.judge_id,
            pd.point_date
        FROM point_details pd
        WHERE pd.artist_id = @ArtistID
        ORDER BY pd.round_stage, pd.point_date;
    END
    PRINT '存储过程 GetArtistPoints 创建成功';
END
GO

-- 6.2 获取队伍排名
IF NOT EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetTeamRankings')
BEGIN
    CREATE PROCEDURE GetTeamRankings
        @RoundStage CHAR(2)
    AS
    BEGIN
        SELECT 
            t.team_name,
            t.country_code,
            r.total_points,
            r.ranking
        FROM art_team t
        JOIN art_team_results r ON t.a_team_id = r.a_team_id
        WHERE r.round_stage = @RoundStage
        ORDER BY r.ranking;
    END
    PRINT '存储过程 GetTeamRankings 创建成功';
END
GO

-- ========================================
-- 7. 创建用户和权限
-- ========================================
IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = 'ART_CONTEST_User')
BEGIN
    CREATE LOGIN ART_CONTEST_User WITH PASSWORD = 'Art@Contest2026!';
    CREATE USER ART_CONTEST_User FOR LOGIN ART_CONTEST_User;
    GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO ART_CONTEST_User;
    PRINT '用户 ART_CONTEST_User 创建并授权成功';
END
GO

PRINT '========================================';
PRINT 'ART_CONTEST 数据库初始化完成！';
PRINT '========================================';
GO