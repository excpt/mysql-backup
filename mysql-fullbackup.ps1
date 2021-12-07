$ErrorActionPreference = "Stop" # Beim ersten Fehler abbrechen

function Write-Log {
    Param([string] $message)

    $logformat = "yyyy-MM-dd HH:mm:ss.fff"
    
    Write-Output "[$(Get-Date -Format $logformat)][MySQL][Fullbackup] $message"
}

$format = "yyyy-MM-dd_HH-mm-ss"
$zipPassword = "s3crEt!"

$zipBinPath = "C:\Program Files\7-Zip"
$mysqlBinPath = "C:\Program Files\MySQL\MySQL Server 5.7\bin"
$mysqlBinLogPath = "C:\ProgramData\MySQL\MySQL Server 5.7\Data"
$localBackupDir = "C:\Temp\MySQL\Local\$(Get-Date -Format yyyy-MM-dd)"
$remoteBackupDir = "C:\Temp\MySQL\Remote\$(Get-Date -Format yyyy-MM-dd)"

Write-Log 'Create backup'

if (-NOT (Test-Path $localBackupDir)) {
    New-Item $localBackupDir -ItemType Directory | Out-Null
}

# Datenbank 
# `Select-Object -Skip 1`  Erste Zeile �berspringen, da Header Zeile vom query result
foreach ($databaseName in .$mysqlBinPath\mysql -e "SHOW DATABASES" | Select-Object -Skip 1) {

    # Systemdatenbanken �erspringen die nicht gesichert werden k�nnen oder
    # es keinen Sinn macht diese als Backup zu haben
    #
    # information_schema - beinhaltet aktuelle Tabellen Informationen
    # performance_schema - interne Daten zum aktuellen Stand der
    if ($databaseName -eq 'information_schema' -or $databaseName -eq 'performance_schema') {
        continue
    }

    $timestamp = $((Get-Date).ToString($format))
    $filename = $databaseName + '_' + $timestamp
    
    Write-Log "Dump '$databaseName' ($filename)"

    # Datenbank sichern
    # --hex-blob formattiert Bin�rdaten korrekt f�r den Restore
    # --triggers sichern aller Trigger
    # --routines sichern aller StoredProcedures und Functions
    # --events sichern aller Events
    # --disabe-keys erzeugt kommentierte Zeilen um ggf. Duplicate Keys zu erlauben
    # --source-data=2 schreibt BinLogs Infos an den Anfang der Datei als Kommentar
    # --flush-privileges f�r korrektes sichern der Benutzerrechte und fehlerfreien Restore
    .$mysqlBinPath\mysqldump.exe --hex-blob --triggers --routines --events --extended-insert --disable-keys --master-data=2 --flush-privileges --max-allowed-packet=512M --result-file="$localBackupDir/$filename.sql" $databaseName

    Write-Log 'Compress data'
    # Fullbackup komprimieren mit 7-ZIP
    .$zipBinPath\7z.exe a $localBackupDir\$filename.7z $localBackupDir\$filename.sql -p"$zipPassword"
}

Write-Log "Copy files to '$remoteBackupDir'"

# Ordner erstellen
if (-NOT (Test-Path $remoteBackupDir)) {
    New-Item -ItemType Directory $remoteBackupDir | Out-Null
}

# Fullbackup kopieren
Copy-Item -Path $localBackupDir\*.7z -Destination $remoteBackupDir
# Bin Logs kopieren
Copy-Item -Path "$mysqlBinLogPath\*-bin.*" -Destination $remoteBackupDir

Write-Log "Clean up"

# SQL Dumps l�schen
# Remove-Item $localBackupDir -Recurse

Write-Log 'Done'

####### -executionpolicy bypass -file d:\Skripte\mysql-fullbackup.ps1