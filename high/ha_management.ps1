<#
SQL Server 高可用性 PowerShell 管理脚本
=========================================
文件：ha_management.ps1
版本：V1.0
日期：2026年5月
#>

function Enable-SqlAlwaysOn {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerInstance
    )
    
    try {
        Enable-SqlAlwaysOn -ServerInstance $ServerInstance -Force
        Write-Host "AlwaysOn已在 $ServerInstance 上启用" -ForegroundColor Green
    }
    catch {
        Write-Host "启用AlwaysOn失败: $_" -ForegroundColor Red
    }
}

function New-SqlAGEndpoint {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerInstance,
        [string]$EndpointName = "Hadr_endpoint",
        [int]$Port = 5022
    )
    
    try {
        $server = Get-SqlServer -ServerInstance $ServerInstance
        
        if (-not $server.Endpoints[$EndpointName]) {
            $endpoint = New-Object Microsoft.SqlServer.Management.Smo.Endpoint($server, $EndpointName)
            $endpoint.ProtocolType = [Microsoft.SqlServer.Management.Smo.ProtocolType]::Tcp
            $endpoint.Protocol.Tcp.ListenerPort = $Port
            $endpoint.EndpointType = [Microsoft.SqlServer.Management.Smo.EndpointType]::DatabaseMirroring
            $endpoint.Payload.DatabaseMirroring.ServerMirroringRole = [Microsoft.SqlServer.Management.Smo.ServerMirroringRole]::All
            $endpoint.Create()
            $endpoint.Start()
            $endpoint.Grant("CONNECT", "public")
            Write-Host "端点 $EndpointName 创建成功，端口: $Port" -ForegroundColor Green
        }
        else {
            Write-Host "端点 $EndpointName 已存在" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "创建端点失败: $_" -ForegroundColor Red
    }
}

function New-SqlAvailabilityGroup {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PrimaryServer,
        [Parameter(Mandatory=$true)]
        [string]$SecondaryServer,
        [Parameter(Mandatory=$true)]
        [string]$AGName,
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,
        [string]$ListenerName,
        [string]$ListenerIP,
        [int]$ListenerPort = 1433
    )
    
    try {
        $primary = Get-SqlServer -ServerInstance $PrimaryServer
        
        $ag = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityGroup($primary, $AGName)
        
        $primaryReplica = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityReplica($ag, $PrimaryServer)
        $primaryReplica.EndpointUrl = "TCP://$PrimaryServer`:5022"
        $primaryReplica.AvailabilityMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaAvailabilityMode]::SynchronousCommit
        $primaryReplica.FailoverMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaFailoverMode]::Automatic
        $primaryReplica.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Automatic
        $ag.AvailabilityReplicas.Add($primaryReplica)
        
        $secondaryReplica = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityReplica($ag, $SecondaryServer)
        $secondaryReplica.EndpointUrl = "TCP://$SecondaryServer`:5022"
        $secondaryReplica.AvailabilityMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaAvailabilityMode]::SynchronousCommit
        $secondaryReplica.FailoverMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaFailoverMode]::Automatic
        $secondaryReplica.SeedingMode = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaSeedingMode]::Automatic
        $secondaryReplica.SecondaryRole.AllowConnections = [Microsoft.SqlServer.Management.Smo.AvailabilityReplicaConnectionMode]::ReadOnly
        $secondaryReplica.SecondaryRole.ReadOnlyRoutingUrl = "TCP://$SecondaryServer`:1433"
        $ag.AvailabilityReplicas.Add($secondaryReplica)
        
        $ag.Create()
        $ag.AddDatabase($DatabaseName)
        
        if ($ListenerName -and $ListenerIP) {
            $listener = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityGroupListener($ag, $ListenerName)
            $ipAddress = New-Object Microsoft.SqlServer.Management.Smo.AvailabilityGroupListenerIPAddress($listener)
            $ipAddress.IPAddress = $ListenerIP
            $ipAddress.SubnetMask = "255.255.255.0"
            $listener.Port = $ListenerPort
            $listener.AvailabilityGroupListenerIPAddresses.Add($ipAddress)
            $listener.Create()
            Write-Host "侦听器 $ListenerName 创建成功，IP: $ListenerIP, 端口: $ListenerPort" -ForegroundColor Green
        }
        
        Write-Host "可用性组 $AGName 创建成功" -ForegroundColor Green
    }
    catch {
        Write-Host "创建可用性组失败: $_" -ForegroundColor Red
    }
}

function Invoke-SqlFailover {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerInstance,
        [Parameter(Mandatory=$true)]
        [string]$AGName,
        [switch]$Force
    )
    
    try {
        $server = Get-SqlServer -ServerInstance $ServerInstance
        
        if ($Force) {
            $server.AvailabilityGroups[$AGName].ForceFailoverAllowDataLoss()
            Write-Host "强制故障转移完成: $AGName" -ForegroundColor Yellow
        }
        else {
            $server.AvailabilityGroups[$AGName].Failover()
            Write-Host "故障转移完成: $AGName" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "故障转移失败: $_" -ForegroundColor Red
    }
}

function Get-SqlAGStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerInstance
    )
    
    try {
        $server = Get-SqlServer -ServerInstance $ServerInstance
        
        foreach ($ag in $server.AvailabilityGroups) {
            Write-Host "`n可用性组: $($ag.Name)" -ForegroundColor Cyan
            
            foreach ($replica in $ag.AvailabilityReplicas) {
                $state = $replica.GetState()
                Write-Host "  副本: $($replica.Name)"
                Write-Host "    角色: $($state.Role)"
                Write-Host "    同步状态: $($state.SynchronizationHealth)"
                Write-Host "    可用性模式: $($replica.AvailabilityMode)"
                Write-Host "    故障转移模式: $($replica.FailoverMode)"
            }
        }
    }
    catch {
        Write-Host "获取AG状态失败: $_" -ForegroundColor Red
    }
}

function Invoke-SqlBackup {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerInstance,
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,
        [string]$BackupType = "Full",
        [string]$BackupPath = "D:\SQLBackup"
    )
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $extension = switch ($BackupType) {
            "Full" { ".bak" }
            "Diff" { ".bak" }
            "Log" { ".trn" }
            default { ".bak" }
        }
        
        $fileName = "$DatabaseName`_$BackupType`_$timestamp$extension"
        $fullPath = Join-Path $BackupPath $fileName
        
        if (-not (Test-Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath | Out-Null
        }
        
        $query = switch ($BackupType) {
            "Full" { "BACKUP DATABASE $DatabaseName TO DISK = '$fullPath' WITH INIT, COMPRESSION;" }
            "Diff" { "BACKUP DATABASE $DatabaseName TO DISK = '$fullPath' WITH DIFFERENTIAL, COMPRESSION;" }
            "Log" { "BACKUP LOG $DatabaseName TO DISK = '$fullPath' WITH COMPRESSION;" }
            default { "BACKUP DATABASE $DatabaseName TO DISK = '$fullPath' WITH INIT, COMPRESSION;" }
        }
        
        Invoke-SqlCmd -ServerInstance $ServerInstance -Query $query
        Write-Host "$BackupType 备份完成: $fullPath" -ForegroundColor Green
    }
    catch {
        Write-Host "备份失败: $_" -ForegroundColor Red
    }
}

function Get-SqlBackupStatus {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerInstance,
        [string]$DatabaseName
    )
    
    try {
        $query = @"
SELECT 
    database_name AS DatabaseName,
    MAX(CASE WHEN type = 'D' THEN backup_finish_date END) AS LastFullBackup,
    MAX(CASE WHEN type = 'I' THEN backup_finish_date END) AS LastDiffBackup,
    MAX(CASE WHEN type = 'L' THEN backup_finish_date END) AS LastLogBackup
FROM msdb.dbo.backupset
WHERE database_name = '$DatabaseName'
GROUP BY database_name;
"@
        
        $result = Invoke-SqlCmd -ServerInstance $ServerInstance -Query $query
        
        Write-Host "`n备份状态: $DatabaseName" -ForegroundColor Cyan
        Write-Host "  最后完整备份: $($result.LastFullBackup)"
        Write-Host "  最后差异备份: $($result.LastDiffBackup)"
        Write-Host "  最后日志备份: $($result.LastLogBackup)"
    }
    catch {
        Write-Host "获取备份状态失败: $_" -ForegroundColor Red
    }
}

function Get-SqlDiskSpace {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerInstance
    )
    
    try {
        $query = @"
SELECT 
    LEFT(physical_name, 1) AS Drive,
    SUM(size * 8 / 1024) AS TotalMB,
    SUM(FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024) AS UsedMB,
    SUM(size * 8 / 1024) - SUM(FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024) AS FreeMB,
    CAST((SUM(size * 8 / 1024) - SUM(FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024)) * 100.0 / SUM(size * 8 / 1024) AS DECIMAL(5,2)) AS FreePercent
FROM sys.master_files
GROUP BY LEFT(physical_name, 1);
"@
        
        $result = Invoke-SqlCmd -ServerInstance $ServerInstance -Query $query
        
        Write-Host "`n磁盘空间状态:" -ForegroundColor Cyan
        foreach ($row in $result) {
            $color = if ($row.FreePercent -lt 10) { "Red" } elseif ($row.FreePercent -lt 20) { "Yellow" } else { "Green" }
            Write-Host "  驱动器 $($row.Drive):" -ForegroundColor $color
            Write-Host "    总空间: $($row.TotalMB) MB"
            Write-Host "    已使用: $($row.UsedMB) MB"
            Write-Host "    可用空间: $($row.FreeMB) MB ($($row.FreePercent)%)"
        }
    }
    catch {
        Write-Host "获取磁盘空间失败: $_" -ForegroundColor Red
    }
}

function Clear-OldBackups {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BackupPath,
        [int]$RetentionDays = 30
    )
    
    try {
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        
        Get-ChildItem -Path $BackupPath -Recurse -Include "*.bak", "*.trn" | `
            Where-Object { $_.LastWriteTime -lt $cutoffDate } | `
            Remove-Item -Force
        
        Write-Host "已删除 $RetentionDays 天前的备份文件" -ForegroundColor Green
    }
    catch {
        Write-Host "清理备份失败: $_" -ForegroundColor Red
    }
}

function Get-SqlServer {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServerInstance
    )
    
    Add-Type -Path "C:\Program Files\Microsoft SQL Server\150\SDK\Assemblies\Microsoft.SqlServer.Smo.dll"
    return New-Object Microsoft.SqlServer.Management.Smo.Server($ServerInstance)
}

function Show-MainMenu {
    Clear-Host
    Write-Host "="*60
    Write-Host "    SQL Server 高可用性管理脚本"
    Write-Host "="*60
    Write-Host "1. AlwaysOn 管理"
    Write-Host "2. 备份管理"
    Write-Host "3. 状态监控"
    Write-Host "4. 退出"
    Write-Host "="*60
    $choice = Read-Host "请选择操作 (1-4)"
    
    switch ($choice) {
        1 { Show-AlwaysOnMenu }
        2 { Show-BackupMenu }
        3 { Show-MonitorMenu }
        4 { exit }
        default { 
            Write-Host "无效选择" -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-MainMenu 
        }
    }
}

function Show-AlwaysOnMenu {
    Clear-Host
    Write-Host "="*60
    Write-Host "    AlwaysOn 管理"
    Write-Host "="*60
    Write-Host "1. 启用AlwaysOn"
    Write-Host "2. 创建端点"
    Write-Host "3. 创建可用性组"
    Write-Host "4. 执行故障转移"
    Write-Host "5. 检查AG状态"
    Write-Host "6. 返回主菜单"
    Write-Host "="*60
    $choice = Read-Host "请选择操作 (1-6)"
    
    switch ($choice) {
        1 { 
            $server = Read-Host "输入服务器实例"
            Enable-SqlAlwaysOn -ServerInstance $server
        }
        2 { 
            $server = Read-Host "输入服务器实例"
            New-SqlAGEndpoint -ServerInstance $server
        }
        3 { 
            $primary = Read-Host "输入主服务器"
            $secondary = Read-Host "输入辅助服务器"
            $agname = Read-Host "输入AG名称"
            $dbname = Read-Host "输入数据库名称"
            $listener = Read-Host "输入侦听器名称（可选）"
            $listenerip = Read-Host "输入侦听器IP（可选）"
            New-SqlAvailabilityGroup -PrimaryServer $primary -SecondaryServer $secondary -AGName $agname -DatabaseName $dbname -ListenerName $listener -ListenerIP $listenerip
        }
        4 { 
            $server = Read-Host "输入服务器实例"
            $agname = Read-Host "输入AG名称"
            $force = Read-Host "是否强制故障转移 (Y/N)"
            if ($force -eq "Y") {
                Invoke-SqlFailover -ServerInstance $server -AGName $agname -Force
            }
            else {
                Invoke-SqlFailover -ServerInstance $server -AGName $agname
            }
        }
        5 { 
            $server = Read-Host "输入服务器实例"
            Get-SqlAGStatus -ServerInstance $server
        }
        6 { Show-MainMenu; return }
        default { Write-Host "无效选择" -ForegroundColor Red }
    }
    
    Read-Host "按 Enter 键继续..."
    Show-AlwaysOnMenu
}

function Show-BackupMenu {
    Clear-Host
    Write-Host "="*60
    Write-Host "    备份管理"
    Write-Host "="*60
    Write-Host "1. 执行完整备份"
    Write-Host "2. 执行差异备份"
    Write-Host "3. 执行日志备份"
    Write-Host "4. 检查备份状态"
    Write-Host "5. 清理旧备份"
    Write-Host "6. 返回主菜单"
    Write-Host "="*60
    $choice = Read-Host "请选择操作 (1-6)"
    
    switch ($choice) {
        1 { 
            $server = Read-Host "输入服务器实例"
            $db = Read-Host "输入数据库名称"
            Invoke-SqlBackup -ServerInstance $server -DatabaseName $db -BackupType "Full"
        }
        2 { 
            $server = Read-Host "输入服务器实例"
            $db = Read-Host "输入数据库名称"
            Invoke-SqlBackup -ServerInstance $server -DatabaseName $db -BackupType "Diff"
        }
        3 { 
            $server = Read-Host "输入服务器实例"
            $db = Read-Host "输入数据库名称"
            Invoke-SqlBackup -ServerInstance $server -DatabaseName $db -BackupType "Log"
        }
        4 { 
            $server = Read-Host "输入服务器实例"
            $db = Read-Host "输入数据库名称"
            Get-SqlBackupStatus -ServerInstance $server -DatabaseName $db
        }
        5 { 
            $path = Read-Host "输入备份路径"
            $days = Read-Host "保留天数"
            Clear-OldBackups -BackupPath $path -RetentionDays $days
        }
        6 { Show-MainMenu; return }
        default { Write-Host "无效选择" -ForegroundColor Red }
    }
    
    Read-Host "按 Enter 键继续..."
    Show-BackupMenu
}

function Show-MonitorMenu {
    Clear-Host
    Write-Host "="*60
    Write-Host "    状态监控"
    Write-Host "="*60
    Write-Host "1. 检查磁盘空间"
    Write-Host "2. 检查备份状态"
    Write-Host "3. 检查AG状态"
    Write-Host "4. 返回主菜单"
    Write-Host "="*60
    $choice = Read-Host "请选择操作 (1-4)"
    
    switch ($choice) {
        1 { 
            $server = Read-Host "输入服务器实例"
            Get-SqlDiskSpace -ServerInstance $server
        }
        2 { 
            $server = Read-Host "输入服务器实例"
            $db = Read-Host "输入数据库名称"
            Get-SqlBackupStatus -ServerInstance $server -DatabaseName $db
        }
        3 { 
            $server = Read-Host "输入服务器实例"
            Get-SqlAGStatus -ServerInstance $server
        }
        4 { Show-MainMenu; return }
        default { Write-Host "无效选择" -ForegroundColor Red }
    }
    
    Read-Host "按 Enter 键继续..."
    Show-MonitorMenu
}

Show-MainMenu