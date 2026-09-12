# INVENTARIS KOMPUTER V6
$ErrorActionPreference = 'SilentlyContinue'

# Isi dengan URL Web App V6 setelah deployment Apps Script.

$WebAppUrl = 'https://script.google.com/macros/s/AKfycbxvesg8H0dFcaIflLMAxawxS_Vd0ya6jOD20q79mgycFVusoycM9Wc2QexL15rTgXqTPQ/exec'


function Safe($v) {
    if ($null -eq $v) { return '-' }
    $s = "$v".Trim()
    if ([string]::IsNullOrWhiteSpace($s)) { return '-' }
    return $s
}

function Serial($v) {
    $s = Safe $v
    $bad = @('TO BE FILLED BY O.E.M.','TO BE FILLED BY OEM','DEFAULT STRING','SYSTEM SERIAL NUMBER','UNKNOWN','NONE','NOT SPECIFIED')
    if ($bad -contains $s.ToUpperInvariant()) { return '-' }
    return $s
}

function RamType($smbios,$legacy) {
    $map = @{20='DDR';21='DDR2';22='DDR2 FB-DIMM';24='DDR3';26='DDR4';27='LPDDR';28='LPDDR2';29='LPDDR3';30='LPDDR4';31='LPDDR5';34='DDR5'}
    $n=0
    if ([int]::TryParse("$smbios",[ref]$n) -and $map.ContainsKey($n)) { return $map[$n] }
    if ([int]::TryParse("$legacy",[ref]$n)) {
        switch($n){20{return 'DDR'}21{return 'DDR2'}22{return 'DDR2 FB-DIMM'}24{return 'DDR3'}26{return 'DDR4'}30{return 'DDR4'}}
    }
    return 'Unknown'
}

function Manufacturer($v) {
    $s=Safe $v; $u=$s.ToUpperInvariant()
    if($u -match 'DELL'){return 'Dell'}
    if($u -match 'HP|HEWLETT'){return 'HP'}
    if($u -match 'ASUSTEK|ASUS'){return 'ASUS'}
    if($u -match 'ACER'){return 'Acer'}
    if($u -match 'ZYREX'){return 'Zyrex'}
    return $s
}

$cs=Get-CimInstance Win32_ComputerSystem
$bios=Get-CimInstance Win32_BIOS
$os=Get-CimInstance Win32_OperatingSystem
$cpuInfo=Get-CimInstance Win32_Processor | Select-Object -First 1

$computerName=Safe $env:COMPUTERNAME
$manufacturer=Manufacturer $cs.Manufacturer
$model=Safe $cs.Model
$assetSerialID=Serial $bios.SerialNumber
$cpu=Safe $cpuInfo.Name
$cpu = $cpu -replace '\(R\)', '' -replace '\(TM\)', ''
$cpu = ($cpu -replace '\s+', ' ').Trim()
$core=Safe $cpuInfo.NumberOfCores
$thread=Safe $cpuInfo.NumberOfLogicalProcessors

$ramModules=@(Get-CimInstance Win32_PhysicalMemory)
$total=($ramModules|Measure-Object Capacity -Sum).Sum
$totalGB=if($total){[math]::Round($total/1GB,0)}else{'-'}
$parts=@()
foreach($r in $ramModules){
    $gb=if($r.Capacity){[math]::Round($r.Capacity/1GB,0)}else{'-'}
    $type=RamType $r.SMBIOSMemoryType $r.MemoryType
    $speed=$r.ConfiguredClockSpeed; if(!$speed){$speed=$r.Speed}
    if($speed){$parts += "$gb GB $type $speed MHz"}else{$parts += "$gb GB $type"}
}
$ram=if($parts.Count){"$totalGB GB ("+($parts -join ' + ')+')'}else{'-'}

$disks=@(Get-CimInstance Win32_DiskDrive)
$sp=@()
foreach($d in $disks){$cap=if($d.Size){"$([math]::Round($d.Size/1GB,0)) GB"}else{'-'};$sp += "$(Safe $d.Model) ($cap)"}
$storage=if($sp.Count){$sp -join ' + '}else{'-'}

$gpuParts=@()
foreach($g in @(Get-CimInstance Win32_VideoController)){
    $n=Safe $g.Name;$u=$n.ToUpperInvariant()
    if($u -match 'MICROSOFT REMOTE|BASIC DISPLAY|REMOTE|VIRTUAL|VMWARE|VIRTUALBOX|HYPER-V'){continue}
    if($n -ne '-'){ $gpuParts += $n }
}
$gpuParts=@($gpuParts|Select-Object -Unique)
$gpu=if($gpuParts.Count){$gpuParts -join ' + '}else{'-'}

$ip=@();$mac=@();$gw=@()
foreach($n in @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True')){
    $u=(Safe $n.Description).ToUpperInvariant()
    if($u -match 'VIRTUALBOX|VMWARE|HYPER-V|VIRTUAL ETHERNET|TAP|TUN|LOOPBACK|CONTAINER|WSL|VPN'){continue}
    foreach($x in @($n.IPAddress)){if($x -match '^\d{1,3}(\.\d{1,3}){3}$' -and $x -notmatch '^169\.254\.'){ $ip+=$x }}
    if($n.MACAddress){$mac+=$n.MACAddress}
    foreach($x in @($n.DefaultIPGateway)){if($x -match '^\d{1,3}(\.\d{1,3}){3}$'){$gw+=$x}}
}
$ipAddress=if($ip.Count){($ip|Select-Object -Unique)-join ', '}else{'-'}
$macAddress=if($mac.Count){($mac|Select-Object -Unique)-join ', '}else{'-'}
$gateway=if($gw.Count){($gw|Select-Object -Unique)-join ', '}else{'-'}
$operatingSystem=Safe $os.Caption

Write-Host ''
Write-Host '========== INVENTARIS KOMPUTER V6 ==========' -ForegroundColor Cyan
Write-Host "Computer Name : $computerName"
Write-Host "Manufacturer  : $manufacturer"
Write-Host "Model         : $model"
Write-Host "Asset/Serial  : $assetSerialID"
Write-Host "CPU           : $cpu"
Write-Host "Core          : $core"
Write-Host "Thread        : $thread"
Write-Host "RAM           : $ram"
Write-Host "Storage       : $storage"
Write-Host "GPU           : $gpu"
Write-Host "IP Address    : $ipAddress"
Write-Host "MAC Address   : $macAddress"
Write-Host "Gateway       : $gateway"
Write-Host "Operating Sys : $operatingSystem"
Write-Host ''

$userName=Read-Host 'Nama Pengguna'
if([string]::IsNullOrWhiteSpace($userName)){$userName='-'}else{$userName=$userName.Trim()}

$data=[ordered]@{
 computerName=$computerName; manufacturer=$manufacturer; model=$model; assetSerialID=$assetSerialID
 cpu=$cpu; core="$core"; thread="$thread"; ram=$ram; storage=$storage; gpu=$gpu
 ipAddress=$ipAddress; macAddress=$macAddress; gateway=$gateway; operatingSystem=$operatingSystem
 userName=$userName
}

try{
    $json=$data | ConvertTo-Json -Depth 5

    Write-Host ''
    Write-Host 'Mengirim data ke DB-Main...' -ForegroundColor Yellow

    $response=Invoke-RestMethod `
        -Uri $WebAppUrl `
        -Method Post `
        -ContentType 'application/json; charset=utf-8' `
        -Body $json `
        -TimeoutSec 60 `
        -ErrorAction Stop

    Write-Host ''
    Write-Host '========== HASIL ==========' -ForegroundColor Green

    if($response.status){
        Write-Host "Status : $($response.status)" -ForegroundColor Green
    }

    if($response.message){
        Write-Host "Pesan  : $($response.message)"
    }

    if($response.changes){
        Write-Host 'Perubahan:'
        $response.changes | ForEach-Object {
            Write-Host " - $_"
        }
    }

    if(-not $response.status){
        $response | ConvertTo-Json -Depth 10
    }
}
catch{
    Write-Host ''
    Write-Host 'PENGIRIMAN GAGAL' -ForegroundColor Red
    Write-Host "Error : $($_.Exception.Message)" -ForegroundColor Red
}

Read-Host 'Tekan Enter untuk keluar'
