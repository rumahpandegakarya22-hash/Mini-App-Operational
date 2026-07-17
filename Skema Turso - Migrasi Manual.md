# Skema Tabel Turso yang Belum Ada — Acuan Buat Bikin Manual

## Context

Mini App udah migrasi sebagian modul dari Google Sheets ke Turso (daily_tasks, work_orders, rooms_transfer/occupancy_history, dokumen, feedback/tenant_complain, jurnal_transaksi). User mau lanjutin migrasi database secara manual (bikin tabel sendiri di Turso console), jadi butuh referensi pasti: **spreadsheet/field mana yang datanya betul-betul belum punya tabel Turso**, lengkap dengan struktur kolom yang cocok — bukan cuma daftar nama tabel.

Sesi eksplorasi sebelumnya (dump `PRAGMA foreign_key_list` + `sqlite_master` utk semua 21 tabel Turso yang ada, plus baca semua 18 handler submit & `registry.ts`) udah misahin dua kondisi yang keliatannya mirip tapi beda:
- **Tabel Turso ada, tapi handler Mini App belum nulis kesitu** (leads, content, promotion, maintenance_pm/cm, booking, survey, coa, kamar, payment, penghuni) — ini BUKAN scope dokumen ini, itu kerjaan "sambungin handler", bukan "bikin tabel baru".
- **Tabel Turso beneran belum ada** — ini scope dokumen ini, ada 7 titik, dirinci di bawah dgn kolom persis dari header sheet/field form aslinya.

User pilih: bikin ke-7 tabel (bukan cuma prioritas tinggi), dan gaya Primary Key **disesuaikan per tabel** (bukan satu aturan buat semua) — ngikutin 2 konvensi yang udah ada di 21 tabel existing:
- `TEXT PK prefix app-generated` (mis. `CMP-`, `RT-`, `DOC-`) — dipakai kalau baris itu "kejadian per penghuni" yang lain bisa perlu rujuk balik.
- `INTEGER PRIMARY KEY AUTOINCREMENT` — dipakai kalau baris itu cuma log/master sederhana, gak ada yang nge-FK ke situ (persis kayak `daily_tasks`, `leads`, `survey`, `content`, `promotion`, `vendor`).

## 7 Gap — Skema yang Direkomendasikan

### 1. `checkout` — dari sheet CHECKOUT ("Log Checkout")
**Kenapa TEXT PK:** analog sama `rooms_transfer`/`tenant_complain` — kejadian per penghuni, konsisten sama pola `id_penghuni` yg dipakai fitur Tunggakan Checkout yang baru jalan.

```sql
CREATE TABLE checkout (
  id_checkout          TEXT PRIMARY KEY,          -- 'CKO-YYYYMMDD-xxxxxxxx' (app-generated)
  id_penghuni           TEXT NOT NULL REFERENCES occupancy_history(id_penghuni),
  nama_penghuni         TEXT NOT NULL,             -- snapshot, sama pola kayak feedback.nama
  no_kamar              TEXT NOT NULL,
  tanggal_checkout       TEXT NOT NULL,
  tanggal_masuk          TEXT,
  ada_tunggakan          TEXT CHECK(ada_tunggakan IN ('Ya','Tidak')),
  nominal_tunggakan       INTEGER DEFAULT 0,
  pengembalian_deposit    INTEGER DEFAULT 0,
  kondisi_kamar          TEXT CHECK(kondisi_kamar IN ('Baik','Perlu Perbaikan','Rusak')),
  catatan_kerusakan      TEXT,
  diinput_oleh           TEXT,
  created_at             TEXT DEFAULT (CURRENT_TIMESTAMP)
);
```
Sumber kolom: header sheet asli (`Tanggal Checkout, Penghuni, Kamar, Tgl Masuk, Tunggakan?, Pengembalian Deposit, Kondisi Kamar, Catatan Kerusakan, Diinput Oleh, Timestamp`) — `miniapp-kost/src/lib/modules/handlers/checkout.ts` EXPECTED_HEADERS.
**Catatan wiring (di luar scope "bikin tabel"):** kalau nanti disambungin, handler juga perlu `UPDATE occupancy_history SET tanggal_selesasi = tanggal_checkout` biar riwayat penghuninya nutup — sekarang gak kejadi sama sekali.

### 2. `inspeksi_harian` — dari sheet LOG_INSPEKSI_PERAWATAN ("Log Inspeksi Harian", modul Inspeksi Fasilitas)
**Kenapa INTEGER AUTOINCREMENT:** log periodik sederhana, gak ada tabel lain yang perlu rujuk ke baris ini — sama kelasnya sama `survey`/`leads`.

```sql
CREATE TABLE inspeksi_harian (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  tanggal                TEXT NOT NULL,
  area_fasilitas         TEXT NOT NULL,
  kondisi_ditemukan      TEXT NOT NULL,
  kategori               TEXT NOT NULL,
  tindak_lanjut_perlu    TEXT,
  petugas                TEXT NOT NULL,
  catatan                TEXT,
  created_at             TEXT DEFAULT (CURRENT_TIMESTAMP)
);
```
Sumber kolom: `miniapp-kost/src/lib/modules/handlers/inspeksi-fasilitas.ts` EXPECTED_HEADERS + field form registry (`areaFasilitas, kondisiDitemukan, kategori, tindakLanjutPerlu, petugas, catatan`).

### 3. `inspeksi_kebersihan` — dari sheet LOGBOOK_INSPEKSI_KEBERSIHAN
**Kenapa INTEGER AUTOINCREMENT:** sama alasan #2. Sheet aslinya cuma 4 kolom generik (Tanggal/Aktivitas/Lokasi/Keterangan, digabung dari 5 field form) — tabel baru sebaiknya pisah per field form asli, lebih rapi drpd nge-gabung ke teks bebas kayak sekarang.

```sql
CREATE TABLE inspeksi_kebersihan (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  tanggal                TEXT NOT NULL,
  area                   TEXT NOT NULL,
  hasil_kondisi          TEXT NOT NULL,
  temuan                 TEXT,
  tindak_lanjut          TEXT,
  petugas                TEXT NOT NULL,
  created_at             TEXT DEFAULT (CURRENT_TIMESTAMP)
);
```
Sumber kolom: field form registry modul `inspeksi-kebersihan` (`area, hasilKondisi, temuan, tindakLanjut, petugas`) — `miniapp-kost/src/lib/modules/registry.ts:589-608`.

### 4. `audit_log` — dari sheet AUDIT_LOG (env `SHEET_ID_AUDIT_LOG`)
**Kenapa INTEGER AUTOINCREMENT:** log sistem, volume tinggi, sekuensial — persis kelas `daily_tasks`.

```sql
CREATE TABLE audit_log (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  request_id             TEXT NOT NULL,
  username               TEXT NOT NULL,
  role                   TEXT NOT NULL,
  module_id              TEXT NOT NULL,
  action                 TEXT NOT NULL CHECK(action IN ('CREATE','UPDATE')),
  target                 TEXT,
  row_ref                TEXT,        -- nomor baris sheet ATAU id insert Turso, TEXT biar fleksibel dua-duanya
  new_data                TEXT,        -- JSON snapshot payload submit
  duration_sec            REAL,
  status                 TEXT NOT NULL CHECK(status IN ('sukses','gagal')),
  error                  TEXT,
  created_at             TEXT DEFAULT (CURRENT_TIMESTAMP)
);
```
Sumber kolom: `AuditEntry` interface — `miniapp-kost/src/lib/audit.ts`. Kolom `oldData` sengaja DIBUANG — di kode sekarang selalu kosong (gak pernah dipakai, cuma dead field), gak usah diikutin.

### 5. `kas_bank` — dari sheet LOG_INPUT_TRANSAKSI ("Pengaturan" kolom D3:D30, KasList)
**Kenapa INTEGER AUTOINCREMENT:** master kecil & stabil, gak ada kode akuntansi resmi kayak `coa` (cuma nama, mis. "BCA", "Cash", "GoPay") — polanya lebih deket ke `vendor`.

```sql
CREATE TABLE kas_bank (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  nama_akun               TEXT NOT NULL UNIQUE,
  aktif                  INTEGER NOT NULL DEFAULT 1   -- 0/1, sembunyiin akun lama tanpa hapus baris
);
```
Sumber: `miniapp-kost/src/lib/master.ts:205-210` `getKasList()`.

### 6. `app_settings` — pengganti generik semua dropdown "SETTING" (28 grup dropdown tersebar di 5 spreadsheet)
**Kenapa INTEGER AUTOINCREMENT + composite unique:** ini bukan satu tabel per dropdown (kebanyakan & repetitif), tapi satu tabel key-value ter-grup — pola umum utk "lookup list".

```sql
CREATE TABLE app_settings (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  group_key              TEXT NOT NULL,     -- lihat daftar 28 grup di bawah
  value                  TEXT NOT NULL,
  urutan                 INTEGER DEFAULT 0, -- urutan tampil di dropdown
  UNIQUE(group_key, value)
);
```
28 `group_key` yang perlu diisi (nama saran, boleh diganti asal konsisten dgn yang dipakai app nanti saat wiring) — digali dari semua `master: 'setting:...'` di `registry.ts`:

| group_key saran | Sheet sumber | Kolom asli |
|---|---|---|
| `feedback_kategori` | LOGBOOK_FEEDBACK | Kategori |
| `feedback_status` | LOGBOOK_FEEDBACK | Status |
| `booking_status` | LOG_SALES | Status Booking |
| `booking_sumber_leads` | LOG_SALES | Sumber Leads |
| `survey_dari_mana` | LOG_SALES | Dari Mana |
| `survey_hasil` | LOG_SALES | Hasil Survey |
| `survey_tindak_lanjut` | LOG_SALES | Tindak Lanjut |
| `survey_pic` | LOG_SALES | PIC |
| `leads_kanal` | LOG_MARKETING | Kanal Leads |
| `konten_platform` | LOG_MARKETING | Platform |
| `konten_jenis` | LOG_MARKETING | Jenis Konten |
| `konten_status` | LOG_MARKETING | Status Konten |
| `promosi_kanal` | LOG_MARKETING | Kanal Promosi |
| `promosi_status` | LOG_MARKETING | Status Promosi |
| `maintenance_jenis_preventif` | LOG_INSPEKSI_PERAWATAN | Jenis Perawatan |
| `maintenance_kategori_preventif` | LOG_INSPEKSI_PERAWATAN | Kategori Preventif |
| `maintenance_penyebab` | LOG_INSPEKSI_PERAWATAN | Penyebab (dipakai preventif & korektif) |
| `maintenance_prioritas` | LOG_INSPEKSI_PERAWATAN | Prioritas (dipakai preventif & korektif) |
| `maintenance_pic` | LOG_INSPEKSI_PERAWATAN | PIC (dipakai preventif, korektif, inspeksi fasilitas) |
| `maintenance_status` | LOG_INSPEKSI_PERAWATAN | Status (dipakai preventif & korektif) |
| `maintenance_sumber_laporan_korektif` | LOG_INSPEKSI_PERAWATAN | Sumber Laporan Korektif |
| `maintenance_kategori_korektif` | LOG_INSPEKSI_PERAWATAN | kategori korektif |
| `inspeksi_area` | LOG_INSPEKSI_PERAWATAN | Area |
| `inspeksi_kategori` | LOG_INSPEKSI_PERAWATAN | Kategori Inspeksi |
| `inspeksi_tindak_lanjut` | LOG_INSPEKSI_PERAWATAN | Tindak Lanjut |
| `kebersihan_area` | LOGBOOK_INSPEKSI_KEBERSIHAN | Area |
| `kebersihan_hasil` | LOGBOOK_INSPEKSI_KEBERSIHAN | Hasil |
| `kebersihan_petugas` | LOGBOOK_INSPEKSI_KEBERSIHAN | Petugas |

### 7. Matriks harga Invoice Sewa/DP (INVOICE_SEWA + INVOICE_DP) — **rekomendasi: JANGAN bikin tabel baru dulu**
Ini beda kondisi dari 6 lainnya — bukan gap struktur, tapi kemungkinan **udah kecover** tabel yang ada:
- `kamar` udah punya `harga_bulan/harga_3bulan/harga_6bulan/harga_9bulan/harga_tahun` **per kamar** (lebih presisi drpd matriks INVOICE_SEWA yang cuma per **tipe** kamar).
- `penghuni.email` udah ada, jadi data penyewa+email di INVOICE_DP juga udah ke-cover.
- Yang bikin ini beda kelas: Apps Script (Invoice Generator) itu terpisah dari Turso — dia baca langsung dari sheet INVOICE_SEWA/DP, bukan dari app. Bikin tabel Turso baru gak otomatis dipakai Apps Script itu; butuh nulis ulang Apps Script-nya juga (scope besar, bukan sekadar bikin tabel). Kalau ini emang mau dikejar, sebaiknya jadi item terpisah ("ganti Apps Script baca dari Turso"), bukan "bikin tabel #7" gaya di atas.

## Verifikasi

Setelah tabel dibikin manual, verifikasi cepat (baca-saja, sesuai konvensi introspeksi yang udah dipakai sesi ini):
```bash
node --env-file=.env.local -e "
const { createClient } = require('@libsql/client');
const db = createClient({ url: process.env.TURSO_DATABASE_URL, authToken: process.env.TURSO_AUTH_TOKEN });
db.execute(\"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name\").then(r => console.log(r.rows.map(x=>x.name).join('\n')));
"
```
Jalanin dari `miniapp-kost/` — pastiin 7 nama tabel baru (`checkout`, `inspeksi_harian`, `inspeksi_kebersihan`, `audit_log`, `kas_bank`, `app_settings`) muncul di daftar, plus `PRAGMA foreign_key_list(checkout)` buat mastiin FK ke `occupancy_history` kepasang bener.

Ini dokumen referensi doang (gak ada kode yang diubah) — nyambungin handler ke tabel-tabel ini adalah task terpisah, nanti tinggal minta lagi kalau tabelnya udah jadi.
