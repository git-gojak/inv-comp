# CHANGELOG

Semua perubahan penting pada project **Inventaris Komputer V6** dicatat di file ini.

Format mengikuti perkembangan project dan bukan merupakan dokumentasi perubahan Google Apps Script secara otomatis.

---

# V6.0

## Inventaris Komputer

* Membuat script PowerShell `invcpu.ps1`.
* Mengambil informasi komputer menggunakan CIM/Windows.
* Mengambil:

  * Computer Name
  * Manufacturer
  * Model
  * Asset/Serial ID
  * CPU
  * Core
  * Thread
  * RAM
  * Storage
  * GPU
  * IP Address
  * MAC Address
  * Gateway
  * Operating System
* Menambahkan input manual `Nama Pengguna`.

## Normalisasi Data

* Normalisasi manufacturer:

  * Dell → Dell
  * HP/Hewlett → HP
  * ASUSTeK/ASUS → ASUS
  * Acer → Acer
  * Zyrex → Zyrex
* Manufacturer yang tidak valid dapat ditandai sebagai `Rakitan`.
* Membersihkan simbol `(R)` dan `(TM)` dari CPU.
* Membersihkan simbol `(R)` dan `(TM)` dari GPU.
* Membersihkan placeholder serial BIOS yang tidak valid.
* Menambahkan normalisasi jenis RAM.
* Menampilkan kapasitas dan kecepatan RAM.
* Memfilter adapter GPU virtual/remote tertentu.
* Memfilter network adapter virtual tertentu.

## Google Apps Script

* Membuat Web App untuk menerima data inventaris.
* Menggunakan sheet `DB-Main` sebagai database kondisi terakhir.
* Menggunakan sheet `Riwayat` sebagai database histori.
* Menambahkan pembuatan header otomatis jika diperlukan.
* Menambahkan penguncian proses menggunakan `LockService`.

## DB-Main

* Satu record digunakan untuk kondisi terakhir komputer.
* Data komputer lama tidak otomatis dihapus.
* `Tanggal Perolehan` dipertahankan ketika komputer didata kembali.
* `Scan Terakhir` diperbarui setiap kali scan berhasil.
* `Catatan Admin` dipertahankan saat update.

## Riwayat

* Setiap proses scan disimpan sebagai record baru.
* Data histori tidak ditimpa.
* Data histori tidak dihapus secara otomatis.
* Menyimpan detail perubahan antara data lama dan data terbaru.

## Identifikasi Komputer

* Menggunakan `Asset/Serial ID` sebagai identitas utama.
* Jika serial tidak valid, menggunakan kombinasi:

  * Computer Name
  * MAC Address

## Deteksi Perubahan

Membandingkan:

* Computer Name
* Manufacturer
* Model
* Asset/Serial ID
* CPU
* Core
* Thread
* RAM
* Storage
* GPU
* IP Address
* MAC Address
* Gateway
* Operating System
* Pengguna

Status yang digunakan:

```text
PC BARU TERDATA
ADA PERUBAHAN
TIDAK ADA PERUBAHAN
```

---

# Repository Structure

```text
inv-comp/
│
├── invcpu.ps1
├── README.md
└── CHANGELOG.md
```

---

# Catatan Versi

Versi V6 saat ini berfokus pada kestabilan proses:

```text
PC
 ↓
PowerShell
 ↓
Apps Script
 ↓
DB-Main + Riwayat
```

Fitur tambahan seperti Dashboard, Periode Pendataan, dan autentikasi API belum termasuk dalam V6.0.

---

# Rencana Pengembangan

Rencana berikut merupakan kandidat untuk versi selanjutnya dan **belum dianggap sebagai fitur V6.0**.

## V6.x

Kemungkinan pengembangan:

* Dashboard monitoring.
* Periode pendataan.
* Penyempurnaan normalisasi Model.
* Penyempurnaan informasi CPU.
* Peningkatan identifikasi komputer.
* Validasi data yang lebih ketat.
* Monitoring komputer yang belum didata.

## Security

Kemungkinan pengembangan:

* API Key / Token.
* Validasi request.
* Pengamanan endpoint Web App.

Fitur keamanan hanya akan diterapkan setelah alur inventaris V6 saat ini stabil.
