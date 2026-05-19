-- ========================================
-- 磁盘空间监控脚本（显示所有磁盘状态）
-- ========================================
SELECT 
    Drive,
    TotalGB,
    AvailableGB,
    UsedPercent,
    CASE 
        WHEN UsedPercent >= 95 THEN 'CRITICAL'
        WHEN UsedPercent >= 85 THEN 'WARNING'
        ELSE 'NORMAL'
    END AS Status
FROM (
    SELECT 
        volume_mount_point AS Drive,
        CAST(SUM(total_bytes) / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS TotalGB,
        CAST(SUM(available_bytes) / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(10,2)) AS AvailableGB,
        CAST((1 - (SUM(available_bytes) * 1.0 / SUM(total_bytes))) * 100 AS DECIMAL(5,2)) AS UsedPercent
    FROM sys.master_files mf
    CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id)
    WHERE volume_mount_point IN ('D:\', 'E:\')
    GROUP BY volume_mount_point
) AS VolumeStats
ORDER BY UsedPercent DESC;  -- 移除 WHERE 条件，显示所有磁盘