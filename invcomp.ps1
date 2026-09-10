# ============================================================
# INVENTARIS KOMPUTER V5
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

# Google Apps Script Web App
$URL = "https://script.google.com/macros/s/AKfycbzBdnj815Ocdq8jkeXggPJ-iw9mcuh2F9VEZpjdgjLbdyG4B9qH6ICVsW6gw1prgmeNHw/exec"

Write-Host ""
Write-Host "============================================"
Write-Host "       INVENTARISASI KOMPUTER"
Write-Host "============================================"
Write-Host ""
Write-Host "Mengambil informasi komputer..."
Write-Host ""

# ------------------------------------------------------------
# SISTEM
# ------------------------------------------------------------

$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem

$computerName = $env:COMPUTERNAME
$manufacturer = $cs.Manufacturer
$model = $cs.Model

if ([string]::IsNullOrWhiteSpace($manufacturer) -or
    $manufacturer -match "System manufacturer|To Be Filled|Default string") {
    $manufacturer = "-"
}

if ([string]::IsNullOrWhiteSpace($model) -or
    $model -match "System Product Name|To Be Filled|Default string") {
    $model = "-"
}

# Rapikan vendor untuk inventaris
if ($manufacturer -match '^Dell') {
    $manufacturer = "Dell"
}
elseif ($manufacturer -match '^HP|Hewlett') {
    $manufacturer = "HP"
}
elseif ($manufacturer -match '^ASUSTeK|^ASUS') {
    $manufacturer = "ASUS"
}
elseif ($manufacturer -match '^Acer') {
    $manufacturer = "Acer"
}
elseif ($manufacturer -match '^Zyrex') {
    $manufacturer = "Zyrex"
}
elseif ($manufacturer -eq "-") {
    $manufacturer = "Rakitan"
}

# ------------------------------------------------------------
# ASSET / SERIAL ID
# ------------------------------------------------------------

$serialCandidates = @(
    Get-CimInstance Win32_BIOS |
        Select-Object -ExpandProperty SerialNumber
)

$serial = ($serialCandidates | Where-Object {
    $_ -and $_ -notmatch "To Be Filled|Default string|System Serial Number"
} | Select-Object -First 1)

if ([string]::IsNullOrWhiteSpace($serial)) {
    $serial = "-"
}

# ------------------------------------------------------------
# CPU
# ------------------------------------------------------------

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1

$cpuName = if ($cpu.Name) {
    ($cpu.Name.Trim() -replace '\(R\)|\(TM\)', '' -replace '\s+', ' ').Trim()
}
else {
    "-"
}

$core = if ($cpu.NumberOfCores) {
    $cpu.NumberOfCores
}
else {
    "-"
}

$thread = if ($cpu.NumberOfLogicalProcessors) {
    $cpu.NumberOfLogicalProcessors
}
else {
    "-"
}

# ------------------------------------------------------------
# RAM
# Format:
# 8 GB (8 GB) | DDR5 | 5600 MHz
# 8 GB (4 GB + 4 GB) | DDR4 | 3200 / 2667 MHz
# 16 GB (8 GB + 8 GB) | DDR4 | 3200 MHz
# ------------------------------------------------------------

$ramModules = @(Get-CimInstance Win32_PhysicalMemory)

if ($ramModules.Count -gt 0) {

    $ramTotalGB = [math]::Round(
        (($ramModules | Measure-Object Capacity -Sum).Sum / 1GB), 0
    )

    function Get-RamType($type) {
        switch ($type) {
            20 { "DDR" }
            21 { "DDR2" }
            22 { "DDR2 FB-DIMM" }
            24 { "DDR3" }
            26 { "DDR4" }
            27 { "LPDDR" }
            28 { "LPDDR2" }
            29 { "LPDDR3" }
            30 { "LPDDR4" }
            34 { "DDR5" }
            default { "Unknown" }
        }
    }

    $ramTypes = @()
    $ramSpeeds = @()
    $ramModuleList = @()

    foreach ($ram in $ramModules) {

        $capacityGB = [math]::Round($ram.Capacity / 1GB, 0)
        $type = Get-RamType $ram.SMBIOSMemoryType
        $speed = $ram.Speed

        $ramTypes += $type

        if ($speed) {
            $ramSpeeds += "$speed MHz"
        }

        $ramModuleList += "$capacityGB GB"
    }

    $ramTypeText = ($ramTypes | Select-Object -Unique) -join " / "
    $ramSpeedText = ($ramSpeeds | Select-Object -Unique) -join " / "
    $ramModuleText = $ramModuleList -join " + "

    if ([string]::IsNullOrWhiteSpace($ramTypeText)) {
        $ramTypeText = "-"
    }

    if ([string]::IsNullOrWhiteSpace($ramSpeedText)) {
        $ramSpeedText = "-"
    }

    if ([string]::IsNullOrWhiteSpace($ramModuleText)) {
        $ramModuleText = "-"
    }

    $ramText = "$ramTotalGB GB ($ramModuleText) | $ramTypeText | $ramSpeedText"
}
else {
    $ramText = "-"
}

# ------------------------------------------------------------
# STORAGE
# Model/nama storage + kapasitas aktual yang terdeteksi Windows.
#
# Contoh:
# P0327 Phison 512GB (477 GB)
# WDC WD10EZEX-60WN4A1 (931 GB)
# ADATA LEGEND 850 LITE (477 GB)
# ------------------------------------------------------------

$disks = @(Get-CimInstance Win32_DiskDrive)

$storageInfo = foreach ($disk in $disks) {

    $modelDisk = if ($disk.Model) {
        $disk.Model.Trim()
    }
    else {
        ""
    }

    if ([string]::IsNullOrWhiteSpace($modelDisk)) {
        continue
    }

    $modelDisk = $modelDisk -replace '^\s*\(Standard disk drives\)\s*\|?\s*', ''
    $modelDisk = $modelDisk -replace '^\s*Standard disk drives\s*\|?\s*', ''
    $modelDisk = $modelDisk.Trim()

    if ($disk.Size) {

        $sizeGB = [math]::Round($disk.Size / 1GB, 0)

        "$modelDisk ($sizeGB GB)"
    }
    else {

        $modelDisk
    }
}

$storageText = ($storageInfo | Select-Object -Unique) -join " + "

if ([string]::IsNullOrWhiteSpace($storageText)) {
    $storageText = "-"
}

# ------------------------------------------------------------
# GPU
# Hanya GPU fisik.
# Adapter virtual/remote diabaikan.
# ------------------------------------------------------------

$gpu = @(
    Get-CimInstance Win32_VideoController |
    Where-Object {
        $_.Name -and
        $_.Name -notmatch 'Microsoft Remote Display Adapter|Microsoft Basic Display Adapter|Remote Display|Virtual|VMware|VirtualBox|Hyper-V'
    } |
    Select-Object -ExpandProperty Name
)

$gpuText = ($gpu |
    ForEach-Object {
        ($_ -replace '\(R\)|\(TM\)', '' -replace '\s+', ' ').Trim()
    } |
    Select-Object -Unique) -join " / "

if ([string]::IsNullOrWhiteSpace($gpuText)) {
    $gpuText = "-"
}


# ------------------------------------------------------------
# NETWORK
# Hanya adapter jaringan fisik yang aktif.
# VirtualBox, VMware, Hyper-V dan adapter virtual lainnya diabaikan.
# ------------------------------------------------------------

$adapters = @(
    Get-CimInstance Win32_NetworkAdapterConfiguration |
    Where-Object {
        $_.IPEnabled -eq $true -and
        $_.IPAddress -and
        $_.Description -notmatch 'VirtualBox|VMware|Hyper-V|Virtual Ethernet|TAP|TUN|Loopback|Container|WSL'
    }
)

$ipList = @()
$macList = @()
$gatewayList = @()

foreach ($adapter in $adapters) {

    foreach ($ip in $adapter.IPAddress) {

        if (
            $ip -match '^\d{1,3}(\.\d{1,3}){3}$' -and
            $ip -notmatch '^169\.254\.'
        ) {
            $ipList += $ip
        }
    }

    if ($adapter.MACAddress) {
        $macList += $adapter.MACAddress
    }

    if ($adapter.DefaultIPGateway) {
        $gatewayList += $adapter.DefaultIPGateway
    }
}

$ipText = ($ipList | Select-Object -Unique) -join " / "
$macText = ($macList | Select-Object -Unique) -join " / "
$gatewayText = ($gatewayList | Select-Object -Unique) -join " / "

if ([string]::IsNullOrWhiteSpace($ipText)) {
    $ipText = "-"
}

if ([string]::IsNullOrWhiteSpace($macText)) {
    $macText = "-"
}

if ([string]::IsNullOrWhiteSpace($gatewayText)) {
    $gatewayText = "-"
}

# ------------------------------------------------------------
# WINDOWS
# Format ringkas:
# Microsoft Windows 11 Pro -> Win 11 Pro
# Microsoft Windows 10 Home -> Win 10 Home
# ------------------------------------------------------------

$caption = if ($os.Caption) {
    $os.Caption.Trim()
}
else {
    ""
}

if ($caption -match 'Windows\s+11\s+(.+)$') {

    $edition = $Matches[1].Trim()
    $windowsName = "Win 11 $edition"

}
elseif ($caption -match 'Windows\s+10\s+(.+)$') {

    $edition = $Matches[1].Trim()
    $windowsName = "Win 10 $edition"

}
elseif ($caption -match 'Windows\s+11$') {

    $windowsName = "Win 11"

}
elseif ($caption -match 'Windows\s+10$') {

    $windowsName = "Win 10"

}
elseif ($caption) {

    $windowsName = $caption -replace '^Microsoft\s+', ''

}
else {

    $windowsName = "-"

}

# ------------------------------------------------------------
# DATA INVENTARIS
# TOTAL = 15 FIELD
# ------------------------------------------------------------

$data = @{
    computerName    = $computerName
    manufacturer    = $manufacturer
    model           = $model
    assetSerialID   = $serial

    cpu             = $cpuName
    core            = $core
    thread          = $thread

    ram             = $ramText

    storage         = $storageText
    gpu             = $gpuText

    ipAddress       = $ipText
    macAddress      = $macText
    gateway         = $gatewayText

    operatingSystem = $windowsName
}

# ------------------------------------------------------------
# TAMPILKAN HASIL
# ------------------------------------------------------------

Write-Host "Computer Name : $computerName"
Write-Host "Manufacturer  : $manufacturer"
Write-Host "Model         : $model"
Write-Host "Asset/Serial  : $serial"
Write-Host "CPU           : $cpuName"
Write-Host "Core          : $core"
Write-Host "Thread        : $thread"
Write-Host "RAM           : $ramText"
Write-Host "Storage       : $storageText"
Write-Host "GPU           : $gpuText"
Write-Host "IP Address    : $ipText"
Write-Host "MAC Address   : $macText"
Write-Host "Gateway       : $gatewayText"
Write-Host "OS            : $windowsName"
Write-Host ""
Write-Host "Mengirim data ke Google Sheet..."
Write-Host ""

# ------------------------------------------------------------
# KIRIM KE GOOGLE SHEET
# ------------------------------------------------------------

try {

    $json = $data | ConvertTo-Json -Compress

    $response = Invoke-RestMethod `
        -Uri $URL `
        -Method POST `
        -ContentType "application/json" `
        -Body $json

    if ($response.status -eq "OK") {

        Write-Host "============================================"
        Write-Host "       INVENTARIS BERHASIL"
        Write-Host "============================================"
        Write-Host ""
        Write-Host "Data sudah masuk ke Google Sheet."
        Write-Host ""

    }
    else {

        Write-Host "============================================"
        Write-Host "       GAGAL MENGIRIM DATA"
        Write-Host "============================================"
        Write-Host ""
        Write-Host $response.message
        Write-Host ""

    }

}
catch {

    Write-Host ""
    Write-Host "============================================"
    Write-Host "       KONEKSI GAGAL"
    Write-Host "============================================"
    Write-Host ""
    Write-Host $_.Exception.Message
    Write-Host ""

}

Write-Host "Tekan ENTER untuk selesai..."
Read-Host
