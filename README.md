# INVENTARIS KOMPUTER V6

Sistem inventarisasi komputer berbasis **PowerShell + Google Apps Script + Google Sheets**.

Versi V6 menggunakan dua sheet utama:

* **DB-Main** — menyimpan kondisi terakhir setiap komputer.
* **Riwayat** — menyimpan seluruh hasil pendataan dari waktu ke waktu.

V6 dirancang agar data lama pada Riwayat **tidak dihapus** dan komputer yang tidak ikut dalam pendataan terbaru tetap berada di DB-Main.

---

## Struktur Project

```text
inv-comp/
│
├── invcpu.ps1
├── README.md
└── CHANGELOG.md
```

### File

| File           | Fungsi                                                                              |
| -------------- | ----------------------------------------------------------------------------------- |
| `invcpu.ps1`   | Script PowerShell untuk mengambil data komputer dan mengirimkannya ke Google Sheets |
| `README.md`    | Dokumentasi project                                                                 |
| `CHANGELOG.md` | Catatan perubahan versi                                                             |

---

# 1. Arsitektur Sistem

```text
PC Windows
    │
    │ invcpu.ps1
    ▼
PowerShell
    │
    │ JSON / HTTP POST
    ▼
Google Apps Script Web App
    │
    ├───────────────┐
    ▼               ▼
 DB-Main         Riwayat
```

### DB-Main

DB-Main merupakan database kondisi terakhir komputer.

Satu komputer pada prinsipnya memiliki satu record aktif di DB-Main.

Jika komputer tidak ikut pendataan berikutnya, data sebelumnya **tetap dipertahankan**.

### Riwayat

Riwayat menyimpan setiap hasil scan.

Setiap kali komputer berhasil dikirim ke Apps Script:

* jika komputer baru → dibuat record histori pertama;
* jika komputer sudah ada → dibuat record histori baru;
* histori sebelumnya tidak dihapus.

---

# 2. Data yang Dikumpulkan

`invcpu.ps1` mengambil informasi berikut dari Windows:

### Identitas

* Computer Name
* Manufacturer
* Model
* Asset/Serial ID

### CPU

* CPU
* Core
* Thread

### Memory

* Total RAM
* Kapasitas masing-masing modul RAM
* Jenis RAM
* Kecepatan RAM

### Storage

* Model storage
* Kapasitas storage

### GPU

* Nama GPU

Adapter virtual/remote tertentu difilter agar tidak masuk sebagai GPU utama inventaris.

### Network

* IP Address
* MAC Address
* Gateway

Interface virtual tertentu juga difilter.

### Operating System

* Nama sistem operasi Windows

### Administratif

* Pengguna

Nama Pengguna dimasukkan secara manual saat script dijalankan.

---

# 3. Normalisasi Data

Beberapa data dinormalisasi agar lebih konsisten.

## Manufacturer

Beberapa nama vendor disederhanakan:

```text
Dell Inc.       → Dell
HP              → HP
Hewlett-Packard → HP
ASUSTeK         → ASUS
ASUS            → ASUS
Acer            → Acer
Zyrex           → Zyrex
```

Jika manufacturer tidak tersedia atau tidak valid, sistem dapat menggunakan:

```text
Rakitan
```

---

## CPU

Simbol:

```text
(R)
(TM)
```

dihilangkan.

Contoh:

```text
Intel(R) Core(TM) i3-14100
```

menjadi:

```text
Intel Core i3-14100
```

---

## GPU

Simbol `(R)` dan `(TM)` juga dibersihkan.

---

## Serial

Nilai serial yang umum digunakan sebagai placeholder, seperti:

```text
TO BE FILLED BY O.E.M.
TO BE FILLED BY OEM
DEFAULT STRING
SYSTEM SERIAL NUMBER
UNKNOWN
NONE
NOT SPECIFIED
```

dianggap tidak valid dan diubah menjadi:

```text
-
```

---

# 4. Identifikasi Komputer

Apps Script menggunakan **Asset/Serial ID sebagai identitas utama**.

Jika Asset/Serial ID valid dan sama dengan data yang sudah ada di DB-Main, komputer dianggap sebagai komputer yang sama.

Jika Asset/Serial ID tidak valid, sistem menggunakan kombinasi:

```text
Computer Name + MAC Address
```

sebagai pencarian alternatif.

Dengan mekanisme ini, pendataan ulang komputer yang sama tidak membuat record baru selama identitasnya dapat dikenali.

---

# 5. Deteksi Perubahan

Saat komputer sudah ditemukan di DB-Main, data terbaru dibandingkan dengan data sebelumnya.

Field yang dibandingkan:

```text
Computer Name
Manufacturer
Model
Asset/Serial ID
CPU
Core
Thread
RAM
Storage
GPU
IP Address
MAC Address
Gateway
Operating System
Pengguna
```

Jika terdapat perbedaan, status menjadi:

```text
ADA PERUBAHAN
```

Jika tidak terdapat perbedaan:

```text
TIDAK ADA PERUBAHAN
```

Detail perubahan disimpan di kolom **Perubahan** pada sheet Riwayat.

Contoh:

```text
RAM: 8 GB DDR5 4400 MHz → 16 GB DDR5 4400 MHz
```

atau:

```text
Pengguna: Pusdatin-Komputer → LPPM-staf
```

---

# 6. Struktur DB-Main

Kolom DB-Main:

```text
Tanggal Perolehan
Computer Name
Manufacturer
Model
Asset/Serial ID
CPU
Core
Thread
RAM
Storage
GPU
IP Address
MAC Address
Gateway
Operating System
Pengguna
Scan Terakhir
Status Perubahan
Catatan Admin
```

### Tanggal Perolehan

Di V6 saat ini tanggal perolehan tidak otomatis diisi oleh script.

Kolom tersebut dapat digunakan sebagai data administratif yang diisi secara manual.

Tanggal perolehan berbeda dengan tanggal pendataan.

### Scan Terakhir

Diisi otomatis ketika komputer berhasil diproses.

### Status Perubahan

Menunjukkan hasil pendataan terakhir:

```text
PC BARU TERDATA
ADA PERUBAHAN
TIDAK ADA PERUBAHAN
```

### Catatan Admin

Catatan administratif yang sudah ada di DB-Main dipertahankan ketika komputer discan kembali.

---

# 7. Struktur Riwayat

Kolom Riwayat:

```text
Tanggal Scan
Tanggal Perolehan
Computer Name
Manufacturer
Model
Asset/Serial ID
CPU
Core
Thread
RAM
Storage
GPU
IP Address
MAC Address
Gateway
Operating System
Pengguna
Status
Perubahan
Catatan Admin
```

Riwayat tidak digunakan untuk menggantikan data lama.

Setiap scan menambahkan record baru.

---

# 8. Menjalankan Script

Script dapat dijalankan langsung dari repository GitHub menggunakan PowerShell:

```powershell
irm "https://raw.githubusercontent.com/git-gojak/inv-comp/main/invcpu.ps1" | iex
```

Setelah script berjalan, sistem akan menampilkan data komputer.

Contoh:

```text
========== INVENTARIS KOMPUTER V6 ==========

Computer Name : SHARELOCK
Manufacturer  : Dell
Model         : Inspiron 3030S
Asset/Serial  : 59D3674
CPU           : Intel Core i3-14100
Core          : 4
Thread        : 8
RAM           : 8 GB (8 GB DDR5 4400 MHz)
Storage       : P0327 Phison 512GB (477 GB)
GPU           : Intel UHD Graphics 730
IP Address    : 10.41.0.8
MAC Address   : AC:B4:80:35:5F:F2
Gateway       : 10.41.0.1
Operating Sys : Microsoft Windows 11 Pro
```

Kemudian script meminta:

```text
Nama Pengguna:
```

Masukkan nama pengguna komputer.

---

# 9. Pengiriman Data

Setelah data dikumpulkan, PowerShell mengubah data menjadi JSON dan mengirimkannya melalui HTTP POST ke Google Apps Script Web App.

URL Web App yang digunakan oleh V6 saat ini dikonfigurasi di dalam:

```text
invcpu.ps1
```

pada variabel:

```powershell
$WebAppUrl
```

Jika deployment Apps Script berubah, URL tersebut harus diperbarui pada script.

---

# 10. Respons Server

Jika berhasil, PowerShell menampilkan:

```text
========== HASIL ==========

Status : OK
Pesan  : ...
```

Untuk komputer baru:

```text
Status : OK
Pesan  : PC baru berhasil ditambahkan.

Perubahan:
 - PC baru terdata
```

Untuk komputer yang sudah ada:

```text
Status : OK
Pesan  : DB-Main diperbarui dan Riwayat disimpan.
```

Jika terjadi perubahan, detailnya ditampilkan.

---

# 11. Alur Komputer Baru

Jika komputer belum ditemukan:

```text
PowerShell
    ↓
Apps Script
    ↓
Computer belum ditemukan
    ↓
DB-Main
    └── PC BARU TERDATA

Riwayat
    └── PC BARU TERDATA
```

---

# 12. Alur Pendataan Ulang

Jika komputer sudah ada:

```text
PowerShell
    ↓
Apps Script
    ↓
Cari PC di DB-Main
    ↓
Ditemukan
    ↓
Bandingkan data
    ↓
Update DB-Main
    +
Tambah record Riwayat
```

Data lama pada Riwayat tetap ada.

---

# 13. Persyaratan

Script membutuhkan:

* Windows dengan PowerShell
* Koneksi jaringan/internet ke Google Apps Script
* Google Spreadsheet yang digunakan sebagai database
* Google Apps Script Web App yang aktif

---

# 14. Catatan Penting

### Jangan menghapus Riwayat secara otomatis

Riwayat merupakan arsip pendataan.

### Jangan menggunakan tanggal scan sebagai tanggal perolehan

Tanggal scan menunjukkan kapan komputer didata.

Tanggal perolehan merupakan informasi administratif yang berbeda.

### Jangan mengubah struktur kolom secara sembarangan

Apps Script menggunakan nama dan urutan kolom yang telah ditentukan.

Jika struktur kolom ingin diubah, lakukan perubahan pada Apps Script dan spreadsheet secara terkontrol.

---

# 15. Status Project

Versi saat ini:

```text
INVENTARIS KOMPUTER V6
```

Komponen aktif:

```text
[✓] PowerShell inventory
[✓] Google Apps Script
[✓] DB-Main
[✓] Riwayat
[✓] Deteksi PC baru
[✓] Deteksi perubahan
[✓] Input Pengguna
[✓] Normalisasi Manufacturer
[✓] Normalisasi CPU/GPU
[✓] Penyaringan network virtual
```

Fitur berikut **belum menjadi bagian V6 saat ini**:

```text
[ ] API Key / Token
[ ] Dashboard monitoring
[ ] Periode Pendataan
[ ] Otomatisasi tanggal perolehan
[ ] Sistem autentikasi khusus
```

Fitur tersebut dapat dikembangkan pada versi berikutnya tanpa mengubah konsep dasar DB-Main dan Riwayat.
