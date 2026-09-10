# ============================================================
# INVENTARIS KOMPUTER V2
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

$cpuName = if ($cpu.Name) { $cpu.Name.Trim() } else { "-" }
$core = if ($cpu.NumberOfCores) { $cpu.NumberOfCores } else { "-" }
$thread = if ($cpu.NumberOfLogicalProcessors) {
    $cpu.NumberOfLogicalProcessors
} else {
    "-"
}

# ------------------------------------------------------------
# RAM
# ------------------------------------------------------------

$ramModules = @(Get-CimInstance Win32_PhysicalMemory)

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

if ([string]::IsNullOrWhiteSpace($ramTotalGB)) {
    $ramTotalGB = "-"
}

if ([string]::IsNullOrWhiteSpace($ramTypeText)) {
    $ramTypeText = "-"
}

if ([string]::IsNullOrWhiteSpace($ramSpeedText)) {
    $ramSpeedText = "-"
}

if ([string]::IsNullOrWhiteSpace($ramModuleText)) {
    $ramModuleText = "-"
}

# ------------------------------------------------------------
# STORAGE
# Tampilkan hanya model/nama storage, tanpa tipe generik dan kapasitas
# yang terdeteksi oleh Windows.
# Contoh: P0327 Phison 512GB
# ------------------------------------------------------------

$disks = @(Get-CimInstance Win32_DiskDrive)

$storageInfo = foreach ($disk in $disks) {

    $modelDisk = if ($disk.Model) { $disk.Model.Trim() } else { "" }

    if ([string]::IsNullOrWhiteSpace($modelDisk)) {
        continue
    }

    # Buang teks generik Windows jika muncul di awal/akhir.
    $modelDisk = $modelDisk -replace '^\s*\(Standard disk drives\)\s*\|?\s*', ''
    $modelDisk = $modelDisk -replace '^\s*Standard disk drives\s*\|?\s*', ''
    $modelDisk = $modelDisk.Trim()

    if ($modelDisk) {
        $modelDisk
    }
}

$storageText = ($storageInfo | Select-Object -Unique) -join " + "

if ([string]::IsNullOrWhiteSpace($storageText)) {
    $storageText = "-"
}

# ------------------------------------------------------------
# GPU
# ------------------------------------------------------------

$gpu = @(
    Get-CimInstance Win32_VideoController |
    Where-Object { $_.Name } |
    Select-Object -ExpandProperty Name
)

$gpuText = ($gpu | Select-Object -Unique) -join " / "

if ([string]::IsNullOrWhiteSpace($gpuText)) {
    $gpuText = "-"
}

# ------------------------------------------------------------
# NETWORK
# ------------------------------------------------------------

$adapters = @(
    Get-CimInstance Win32_NetworkAdapterConfiguration |
    Where-Object {
        $_.IPEnabled -eq $true -and $_.IPAddress
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

if ([string]::IsNullOrWhiteSpace($ipText)) { $ipText = "-" }
if ([string]::IsNullOrWhiteSpace($macText)) { $macText = "-" }
if ([string]::IsNullOrWhiteSpace($gatewayText)) { $gatewayText = "-" }

# ------------------------------------------------------------
# WINDOWS
# Format ringkas:
# Microsoft Windows 11 Pro -> Win 11 Pro 64Bit
# Microsoft Windows 10 Home -> Win 10 Home 64Bit
# ------------------------------------------------------------

$architecture = if ([Environment]::Is64BitOperatingSystem) {
    "64Bit"
} else {
    "32Bit"
}

$caption = if ($os.Caption) { $os.Caption.Trim() } else { "" }

if ($caption -match 'Windows\s+11\s+(.+)$') {

    $edition = $Matches[1].Trim()
    $windowsName = "Win 11 $edition $architecture"

}
elseif ($caption -match 'Windows\s+10\s+(.+)$') {

    $edition = $Matches[1].Trim()
    $windowsName = "Win 10 $edition $architecture"

}
elseif ($caption -match 'Windows\s+11$') {

    $windowsName = "Win 11 $architecture"

}
elseif ($caption -match 'Windows\s+10$') {

    $windowsName = "Win 10 $architecture"

}
elseif ($caption) {

    $windowsName = "$caption $architecture"

}
else {

    $windowsName = "-"

}

# ------------------------------------------------------------
# DATA INVENTARIS
# ------------------------------------------------------------

$data = @{
    computerName    = $computerName
    manufacturer    = $manufacturer
    model           = $model
    assetSerialID   = $serial

    cpu             = $cpuName
    core            = $core
    thread          = $thread

    ramTotal        = "$ramTotalGB GB"
    ramModule       = "$ramModuleText | $ramTypeText | $ramSpeedText"

    storage         = $storageText
    gpu             = $gpuText

    ipAddress       = $ipText
    macAddress      = $macText
    gateway         = $gatewayText

    operatingSystem = $windowsName
    windowsVersion  = ""
    architecture    = $architecture
}

# ------------------------------------------------------------
# KIRIM KE GOOGLE SHEET
# ------------------------------------------------------------

Write-Host "Computer Name : $computerName"
Write-Host "Manufacturer  : $manufacturer"
Write-Host "Model         : $model"
Write-Host "Asset/Serial  : $serial"
Write-Host "CPU           : $cpuName"
Write-Host "RAM           : $ramTotalGB GB"
Write-Host "Storage       : $storageText"
Write-Host "OS            : $windowsName"
Write-Host ""
Write-Host "Mengirim data ke Google Sheet..."
Write-Host ""

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
