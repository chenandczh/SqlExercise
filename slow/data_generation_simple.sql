-- ========================================
-- SQL Server 数据生成脚本 - 最终版
-- 适用于 ART_CONTEST 数据库慢查询测试
-- ========================================
SET NOCOUNT ON;
PRINT '========================================';
PRINT '开始生成测试数据...';
PRINT '========================================';

-- 步骤1：清空所有测试表
PRINT '';
PRINT '[步骤1] 清空测试表...';
TRUNCATE TABLE slow_query_test;
TRUNCATE TABLE slow_query_orders;
TRUNCATE TABLE slow_query_transactions;
TRUNCATE TABLE slow_query_products;
PRINT '测试表已清空';

-- 步骤2：创建临时数字表
PRINT '';
PRINT '[步骤2] 创建临时数字表...';
IF OBJECT_ID('tempdb..#temp') IS NOT NULL DROP TABLE #temp;
CREATE TABLE #temp (n INT);

DECLARE @i INT = 1;
WHILE @i <= 1000
BEGIN
    INSERT INTO #temp VALUES (@i);
    SET @i = @i + 1;
END
PRINT '临时数字表已创建 (1000行)';

-- 步骤3：生成slow_query_test 100万行
PRINT '';
PRINT '[步骤3] 生成 slow_query_test (100万行)...';
;WITH nums AS (
    SELECT a.n + (b.n - 1) * 1000 AS rn
    FROM #temp a CROSS JOIN #temp b
)
INSERT INTO slow_query_test (user_id, username, email, registration_date, status, score, department, last_login, ip_address, metadata)
SELECT TOP 1000000
    ABS(CHECKSUM(NEWID())) % 100000 + 1,
    'user_' + CAST(rn AS VARCHAR),
    'user' + CAST(rn AS VARCHAR) + '@test.com',
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 3650, '2015-01-01'),
    ABS(CHECKSUM(NEWID())) % 3,
    CAST(RAND(CHECKSUM(NEWID())) * 1000 AS DECIMAL(10,2)),
    CASE
        WHEN ABS(CHECKSUM(NEWID())) % 5 = 0 THEN '技术部'
        WHEN ABS(CHECKSUM(NEWID())) % 5 = 1 THEN '市场部'
        WHEN ABS(CHECKSUM(NEWID())) % 5 = 2 THEN '销售部'
        WHEN ABS(CHECKSUM(NEWID())) % 5 = 3 THEN '财务部'
        ELSE '人力资源部'
    END,
    DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % 168, GETDATE()),
    CAST(ABS(CHECKSUM(NEWID())) % 256 AS VARCHAR) + '.' +
    CAST(ABS(CHECKSUM(NEWID())) % 256 AS VARCHAR) + '.' +
    CAST(ABS(CHECKSUM(NEWID())) % 256 AS VARCHAR) + '.' +
    CAST(ABS(CHECKSUM(NEWID())) % 256 AS VARCHAR),
    '{"level":"gold","points":' + CAST(ABS(CHECKSUM(NEWID())) % 10000 AS VARCHAR) + '}'
FROM nums;
PRINT 'slow_query_test 已完成: ' + CAST((SELECT COUNT(*) FROM slow_query_test) AS VARCHAR) + ' 行';

-- 步骤4：生成slow_query_orders 50万行
PRINT '';
PRINT '[步骤4] 生成 slow_query_orders (50万行)...';
;WITH nums AS (
    SELECT TOP 500000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM #temp a CROSS JOIN #temp b
)
INSERT INTO slow_query_orders (user_id, order_date, amount, product_type, status)
SELECT
    ABS(CHECKSUM(NEWID())) % 100000 + 1,
    DATEADD(HOUR, ABS(CHECKSUM(NEWID())) % 8760, '2023-01-01'),
    CAST(RAND(CHECKSUM(NEWID())) * 10000 AS DECIMAL(12,2)),
    CASE
        WHEN ABS(CHECKSUM(NEWID())) % 6 = 0 THEN '电子产品'
        WHEN ABS(CHECKSUM(NEWID())) % 6 = 1 THEN '服装'
        WHEN ABS(CHECKSUM(NEWID())) % 6 = 2 THEN '食品'
        WHEN ABS(CHECKSUM(NEWID())) % 6 = 3 THEN '家居用品'
        WHEN ABS(CHECKSUM(NEWID())) % 6 = 4 THEN '图书'
        ELSE '运动器材'
    END,
    ABS(CHECKSUM(NEWID())) % 4
FROM nums;
PRINT 'slow_query_orders 已完成: ' + CAST((SELECT COUNT(*) FROM slow_query_orders) AS VARCHAR) + ' 行';

-- 步骤5：生成slow_query_transactions 30万行
PRINT '';
PRINT '[步骤5] 生成 slow_query_transactions (30万行)...';
;WITH nums AS (
    SELECT TOP 300000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rn
    FROM #temp a CROSS JOIN #temp b
)
INSERT INTO slow_query_transactions (user_id, transaction_date, transaction_type, amount, description)
SELECT
    ABS(CHECKSUM(NEWID())) % 100000 + 1,
    DATEADD(MINUTE, ABS(CHECKSUM(NEWID())) % 525600, '2024-01-01'),
    CASE
        WHEN ABS(CHECKSUM(NEWID())) % 3 = 0 THEN 'deposit'
        WHEN ABS(CHECKSUM(NEWID())) % 3 = 1 THEN 'withdraw'
        ELSE 'transfer'
    END,
    CAST(RAND(CHECKSUM(NEWID())) * 50000 AS DECIMAL(12,2)),
    'Transaction'
FROM nums;
PRINT 'slow_query_transactions 已完成: ' + CAST((SELECT COUNT(*) FROM slow_query_transactions) AS VARCHAR) + ' 行';

-- 步骤6：生成slow_query_products 1万行
PRINT '';
PRINT '[步骤6] 生成 slow_query_products (1万行)...';
;WITH nums AS (
    SELECT n FROM #temp a CROSS JOIN #temp b WHERE (a.n - 1) * 1000 + b.n <= 10000
)
INSERT INTO slow_query_products (product_name, category, price, stock, created_at)
SELECT TOP 10000
    'product_' + CAST((a.n - 1) * 1000 + b.n AS VARCHAR),
    CASE
        WHEN ABS(CHECKSUM(NEWID())) % 8 = 0 THEN '手机'
        WHEN ABS(CHECKSUM(NEWID())) % 8 = 1 THEN '电脑'
        WHEN ABS(CHECKSUM(NEWID())) % 8 = 2 THEN '平板'
        WHEN ABS(CHECKSUM(NEWID())) % 8 = 3 THEN '耳机'
        WHEN ABS(CHECKSUM(NEWID())) % 8 = 4 THEN '手表'
        WHEN ABS(CHECKSUM(NEWID())) % 8 = 5 THEN '相机'
        WHEN ABS(CHECKSUM(NEWID())) % 8 = 6 THEN '游戏机'
        ELSE '配件'
    END,
    CAST(RAND(CHECKSUM(NEWID())) * 50000 AS DECIMAL(10,2)),
    ABS(CHECKSUM(NEWID())) % 1000 + 1,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 730, '2022-01-01')
FROM #temp a CROSS JOIN #temp b;
PRINT 'slow_query_products 已完成: ' + CAST((SELECT COUNT(*) FROM slow_query_products) AS VARCHAR) + ' 行';

-- 步骤7：生成slow_query_order_details 100万行
PRINT '';
PRINT '[步骤7] 生成 slow_query_order_details (100万行)...';
;WITH nums AS (
    SELECT a.n + (b.n - 1) * 1000 AS rn
    FROM #temp a CROSS JOIN #temp b
)
INSERT INTO slow_query_order_details (order_id, product_id, quantity, unit_price)
SELECT TOP 1000000
    ABS(CHECKSUM(NEWID())) % 500000 + 1,
    ABS(CHECKSUM(NEWID())) % 10000 + 1,
    ABS(CHECKSUM(NEWID())) % 10 + 1,
    CAST(RAND(CHECKSUM(NEWID())) * 10000 AS DECIMAL(10,2))
FROM nums;
PRINT 'slow_query_order_details 已完成: ' + CAST((SELECT COUNT(*) FROM slow_query_order_details) AS VARCHAR) + ' 行';

-- 最终统计
PRINT '';
PRINT '========================================';
PRINT '数据生成完成！最终统计：';
PRINT '========================================';
SELECT
    'slow_query_test' AS 表名,
    COUNT(*) AS 行数
FROM slow_query_test
UNION ALL
SELECT 'slow_query_orders', COUNT(*) FROM slow_query_orders
UNION ALL
SELECT 'slow_query_transactions', COUNT(*) FROM slow_query_transactions
UNION ALL
SELECT 'slow_query_products', COUNT(*) FROM slow_query_products
UNION ALL
SELECT 'slow_query_order_details', COUNT(*) FROM slow_query_order_details
ORDER BY 表名;

-- 清理
DROP TABLE #temp;
PRINT '';
PRINT '临时表已清理';
PRINT '========================================';
PRINT '所有数据生成任务完成！';
PRINT '========================================';