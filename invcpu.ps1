# INVENTARIS KOMPUTER V6

$ErrorActionPreference = 'Continue'

# ============================================================

# URL WEB APP V6

# ============================================================

$WebAppUrl = 'https://script.google.com/macros/s/AKfycbxgisOungxy6BFG3F20VA_xCrAucobxqYGYljO5sk5SpHYO3_MhyYKu5dlCXf-KOxOCRw/exec'

# ============================================================

# FUNGSI BANTU

# ============================================================

function Safe($v) {
if ($null -eq $v) {
return '-'
}

```
$s = "$v".Trim()

if ([string]::IsNullOrWhiteSpace($s)) {
    return '-'
}

return $s
```

}

function Serial($v) {
$s = Safe $v

```
$bad = @(
    'TO BE FILLED BY O.E.M.',
    'TO BE FILLED BY OEM',
    'DEFAULT STRING',
    'SYSTEM SERIAL NUMBER',
    'UNKNOWN',
    'NONE',
    'NOT SPECIFIED'
)

if ($bad -contains $s.ToUpperInvariant()) {
    return '-'
}

return $s
```

}

function RamType($smbios, $legacy) {

```
$map = @{
    20 = 'DDR'
    21 = 'DDR2'
    22 = 'DDR2 FB-DIMM'
    24 = 'DDR3'
    26 = 'DDR4'
    27 = 'LPDDR'
    28 = 'LPDDR2'
    29 = 'LPDDR3'
    30 = 'LPDDR4'
    31 = 'LPDDR5'
    34 = 'DDR5'
}

$n = 0

if ([int]::TryParse("$smbios", [ref]$n)) {
    if ($map.ContainsKey($n)) {
        return $map[$n]
    }
}

if ([int]::TryParse("$legacy", [ref]$n)) {
    switch ($n) {
        20 { return 'DDR' }
        21 { return 'DDR2' }
        22 { return 'DDR2 FB-DIMM' }
        24 { return 'DDR3' }
        26 { return 'DDR4' }
        30 { return 'DDR4' }
    }
}

return 'Unknown'
```

}

function Manufacturer($v) {

```
$s = Safe $v
$u = $s.ToUpperInvariant()

if ($u -match 'DELL') {
    return 'Dell'
}

if ($u -match 'HP|HEWLETT') {
    return 'HP'
}

if ($u -match 'ASUSTEK|ASUS') {
    return 'ASUS'
}

if ($u -match 'ACER') {
    return 'Acer'
}

if ($u -match 'ZYREX') {
    return 'Zyrex'
}

return $s
```

}

# ============================================================

# AMBIL DATA SISTEM

# ============================================================

Write-Host ''
Write-Host 'Mengambil data komputer...' -ForegroundColor Cyan

$cs = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os = Get-CimInstance Win32_OperatingSystem
$cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1

$computerName = Safe $env:COMPUTERNAME
$manufacturer = Manufacturer $cs.Manufacturer
$model = Safe $cs.Model
$assetSerialID = Serial $bios.SerialNumber

$cpu = Safe $cpuInfo.Name
$core = Safe $cpuInfo.NumberOfCores
$thread = Safe $cpuInfo.NumberOfLogicalProcessors

# ============================================================

# RAM

# ============================================================

$ramModules = @(Get-CimInstance Win32_PhysicalMemory)

$total = ($ramModules | Measure-Object Capacity -Sum).Sum

if ($total) {
$totalGB = [math]::Round($total / 1GB, 0)
}
else {
$totalGB = '-'
}

$parts = @()

foreach ($r in $ramModules) {

```
if ($r.Capacity) {
    $gb = [math]::Round($r.Capacity / 1GB, 0)
}
else {
    $gb = '-'
}

$type = RamType $r.SMBIOSMemoryType $r.MemoryType

$speed = $r.ConfiguredClockSpeed

if (!$speed) {
    $speed = $r.Speed
}

if ($speed) {
    $parts += "$gb GB $type $speed MHz"
}
else {
    $parts += "$gb GB $type"
}
```

}

if ($parts.Count -gt 0) {
$ram = "$totalGB GB (" + ($parts -join ' + ') + ')'
}
else {
$ram = '-'
}

# ============================================================

# STORAGE

# ============================================================

$disks = @(Get-CimInstance Win32_DiskDrive)

$sp = @()

foreach ($d in $disks) {

```
if ($d.Size) {
    $cap = "$([math]::Round($d.Size / 1GB, 0)) GB"
}
else {
    $cap = '-'
}

$sp += "$(Safe $d.Model) ($cap)"
```

}

if ($sp.Count -gt 0) {
$storage = $sp -join ' + '
}
else {
$storage = '-'
}

# ============================================================

# GPU

# ============================================================

$gpuParts = @()

$videoControllers = @(Get-CimInstance Win32_VideoController)

foreach ($g in $videoControllers) {

```
$n = Safe $g.Name
$u = $n.ToUpperInvariant()

if ($u -match 'MICROSOFT REMOTE|BASIC DISPLAY|REMOTE|VIRTUAL|VMWARE|VIRTUALBOX|HYPER-V') {
    continue
}

if ($n -ne '-') {
    $gpuParts += $n
}
```

}

$gpuParts = @($gpuParts | Select-Object -Unique)

if ($gpuParts.Count -gt 0) {
$gpu = $gpuParts -join ' + '
}
else {
$gpu = '-'
}

# ============================================================

# NETWORK

# ============================================================

$ip = @()
$mac = @()
$gw = @()

$networkAdapters = @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True')

foreach ($n in $networkAdapters) {

```
$u = (Safe $n.Description).ToUpperInvariant()

if ($u -match 'VIRTUALBOX|VMWARE|HYPER-V|VIRTUAL ETHERNET|TAP|TUN|LOOPBACK|CONTAINER|WSL|VPN') {
    continue
}

foreach ($x in @($n.IPAddress)) {

    if (
        $x -match '^\d{1,3}(\.\d{1,3}){3}$' -and
        $x -notmatch '^169\.254\.'
    ) {
        $ip += $x
    }
}

if ($n.MACAddress) {
    $mac += $n.MACAddress
}

foreach ($x in @($n.DefaultIPGateway)) {

    if ($x -match '^\d{1,3}(\.\d{1,3}){3}$') {
        $gw += $x
    }
}
```

}

if ($ip.Count -gt 0) {
$ipAddress = ($ip | Select-Object -Unique) -join ', '
}
else {
$ipAddress = '-'
}

if ($mac.Count -gt 0) {
$macAddress = ($mac | Select-Object -Unique) -join ', '
}
else {
$macAddress = '-'
}

if ($gw.Count -gt 0) {
$gateway = ($gw | Select-Object -Unique) -join ', '
}
else {
$gateway = '-'
}

$operatingSystem = Safe $os.Caption

# ============================================================

# TAMPILKAN HASIL

# ============================================================

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

# ============================================================

# NAMA PENGGUNA

# ============================================================

$userName = Read-Host 'Nama Pengguna'

if ([string]::IsNullOrWhiteSpace($userName)) {
$userName = '-'
}
else {
$userName = $userName.Trim()
}

# ============================================================

# DATA JSON

# ============================================================

$data = [ordered]@{
computerName    = $computerName
manufacturer    = $manufacturer
model           = $model
assetSerialID   = $assetSerialID
cpu             = $cpu
core            = "$core"
thread          = "$thread"
ram             = $ram
storage         = $storage
gpu             = $gpu
ipAddress       = $ipAddress
macAddress      = $macAddress
gateway         = $gateway
operatingSystem = $operatingSystem
userName        = $userName
}

# ============================================================

# VALIDASI URL

# ============================================================

if (
[string]::IsNullOrWhiteSpace($WebAppUrl) -or
$WebAppUrl -eq 'PASTE_URL_WEB_APP_V6_DI_SINI'
) {

```
Write-Host ''
Write-Host 'ERROR: URL Web App V6 belum diisi.' -ForegroundColor Red
```

}
else {

```
# ========================================================
# KIRIM KE GOOGLE APPS SCRIPT
# ========================================================

try {

    $json = $data | ConvertTo-Json -Depth 5

    Write-Host ''
    Write-Host 'Mengirim data ke DB-Main...' -ForegroundColor Cyan

    $response = Invoke-RestMethod `
        -Uri $WebAppUrl `
        -Method Post `
        -ContentType 'application/json; charset=utf-8' `
        -Body $json `
        -ErrorAction Stop

    Write-Host ''
    Write-Host "Status : $($response.status)" -ForegroundColor Green

    if ($response.message) {
        Write-Host "Pesan  : $($response.message)"
    }

    if ($response.changes) {

        Write-Host 'Perubahan:'

        $response.changes | ForEach-Object {
            Write-Host " - $_"
        }
    }

}
catch {

    Write-Host ''
    Write-Host 'PENGIRIMAN GAGAL' -ForegroundColor Red
    Write-Host "Error : $($_.Exception.Message)" -ForegroundColor Red

}
```

}

Write-Host ''
Read-Host 'Tekan Enter untuk keluar'
