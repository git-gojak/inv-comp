# ============================================================
# INVENTARIS KOMPUTER - FINAL
# ============================================================

$ErrorActionPreference = "SilentlyContinue"

# URL Google Apps Script
$URL = "https://script.google.com/macros/s/AKfycbzBdnj815Ocdq8jkeXggPJ-iw9mcuh2F9VEZpjdgjLbdyG4B9qH6ICVsW6gw1prgmeNHw/exec"

Write-Host ""
Write-Host "============================================"
Write-Host "       INVENTARISASI KOMPUTER"
Write-Host "============================================"
Write-Host ""
Write-Host "Mengambil informasi komputer..."
Write-Host ""

# SISTEM
$cs  = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os  = Get-CimInstance Win32_OperatingSystem

$computerName = $env:COMPUTERNAME
$manufacturer = $cs.Manufacturer
$model        = $cs.Model

# Bersihkan data vendor default pada PC rakitan
if ([string]::IsNullOrWhiteSpace($manufacturer) -or
    $manufacturer -match "System manufacturer|To Be Filled|Default string") {
    $manufacturer = "-"
}

if ([string]::IsNullOrWhiteSpace($model) -or
    $model -match "System Product Name|To Be Filled|Default string") {
    $model = "-"
}

# SERIAL / ASSET ID
$serial = $bios.SerialNumber

if ([string]::IsNullOrWhiteSpace($serial) -or
    $serial -match "To Be Filled|Default string|System Serial Number") {
    $serial = "-"
}

# CPU
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name.Trim()
$core = $cpu.NumberOfCores
$thread = $cpu.NumberOfLogicalProcessors

# RAM
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

$ramInfo = foreach ($ram in $ramModules) {
    $capacityGB = [math]::Round($ram.Capacity / 1GB, 0)
    $speed = $ram.Speed
    $type = Get-RamType $ram.SMBIOSMemoryType
    "$capacityGB GB $type $speed MHz"
}

$ramInfoText = $ramInfo -join " | "

# STORAGE
$disks = @(Get-CimInstance Win32_DiskDrive)

$storageInfo = foreach ($disk in $disks) {

    $sizeGB = [math]::Round($disk.Size / 1GB, 0)
    $modelDisk = $disk.Model
    $manufacturerDisk = $disk.Manufacturer

    if ([string]::IsNullOrWhiteSpace($manufacturerDisk)) {
        $manufacturerDisk = "-"
    }

    if ($modelDisk -match "NVMe") {
        $storageType = "NVMe SSD"
    }
    elseif ($modelDisk -match "SSD") {
        $storageType = "SSD"
    }
    elseif ($disk.MediaType -match "SSD") {
        $storageType = "SSD"
    }
    elseif ($disk.MediaType -match "HDD") {
        $storageType = "HDD"
    }
    else {
        $storageType = "Storage"
    }

    "$storageType | $manufacturerDisk | $modelDisk | $sizeGB GB"
}

$storageInfoText = $storageInfo -join " || "

# GPU
$gpu = @(Get-CimInstance Win32_VideoController |
    Where-Object {$_.Name} |
    Select-Object -ExpandProperty Name)

$gpuText = $gpu -join " | "

# NETWORK
$adapters = @(Get-CimInstance Win32_NetworkAdapterConfiguration |
    Where-Object {
        $_.IPEnabled -eq $true -and $_.IPAddress
    })

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

$ipText = ($ipList | Select-Object -Unique) -join " | "
$macText = ($macList | Select-Object -Unique) -join " | "
$gatewayText = ($gatewayList | Select-Object -Unique) -join " | "

# WINDOWS
$windowsName = $os.Caption
$windowsVersion = $os.Version

if ([Environment]::Is64BitOperatingSystem) {
    $architecture = "64-bit"
}
else {
    $architecture = "32-bit"
}

# DATA INVENTARIS
$data = @{
    computerName    = $computerName
    manufacturer    = $manufacturer
    model           = $model
    assetSerialID   = $serial
    cpu             = $cpuName
    core            = $core
    thread          = $thread
    ramTotal        = "$ramTotalGB GB"
    ramModule       = $ramInfoText
    storage         = $storageInfoText
    gpu             = $gpuText
    ipAddress       = $ipText
    macAddress      = $macText
    gateway         = $gatewayText
    operatingSystem = $windowsName
    windowsVersion  = $windowsVersion
    architecture    = $architecture
}

# KIRIM KE GOOGLE SHEET
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
        Write-Host "Computer Name : $computerName"
        Write-Host "Asset/Serial  : $serial"
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
