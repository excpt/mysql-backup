$ErrorActionPreference = "Stop" # Beim ersten Fehler abbrechen

function Write-Log {
    Param([string] $message)

    $logformat = "yyyy-MM-dd HH:mm:ss.fff"
    
    Write-Output "[$(Get-Date -Format $logformat)][MySQL][BinLogBackup] $message"
}

$mysqlBinPath = "C:\Program Files\MySQL\MySQL Server 5.7\bin"

# Ablaufdatum festlegen f�r BinLogs
$expirationDate = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd HH:mm:ss")

Write-Log 'Flush Bin Logs'

# BinLogs schreiben
.$mysqlBinPath\mysqladmin.exe flush-logs

Write-Log "Purge old bin logs older than $expirationDate"

# Alte Bin Logs l�schen die bereits auf einen anderen Server kopiert wurden beim Fullbackup
.$mysqlBinPath\mysql.exe -e "PURGE BINARY LOGS BEFORE '$expirationDate'"

Write-Log 'Done'


####### -executionpolicy bypass -file d:\Skripte\mysql-binlog.ps1