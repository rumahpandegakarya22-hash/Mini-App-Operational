# PRD — Mini App Operasional Kost (v1.1, dilengkapi)

Versi: 1.1 | Tanggal: 7 Juli 2026 | Status: Final Draft — menunggu konfirmasi eksekusi
Perubahan v1.1: melengkapi PRD v1.0 dengan keputusan PO, spesifikasi field per modul (hasil audit spreadsheet aktual), spesifikasi file baru, user management, audit log, concurrency, data cleansing, dan rencana rilis. Bagian baru ditandai **[BARU]**.

---

## 1. Product Overview

**Nama Produk:** Mini App Operasional Kost (Kost Tiga Dara Putri UGM)

**Tujuan:** Aplikasi web sederhana untuk operator (admin, sales, marketing, inspeksi, maintenance), pengawas, dan owner melakukan input administrasi harian dengan tingkat kesalahan seminimal mungkin.

**Non-Goals:** Bukan dashboard bisnis, analisis keuangan, pelaporan manajemen, atau visualisasi data (semua sudah ditangani dashboard internal yang ada). Bukan pengganti spreadsheet sebagai source of truth. Bukan aplikasi mobile native.

## 2. Business Problem

Operasional saat ini memakai Google Spreadsheet, Docs, dan Drive. Masalah: input tidak konsisten, banyak field bebas diedit, human error tinggi, sulit dipakai dari HP, spreadsheet terlalu kompleks untuk lapangan.

**[BARU] Bukti error aktual dari audit spreadsheet (7 Juli 2026):**

| Temuan | Lokasi | Dampak |
|---|---|---|
| Kolom "Luas (m²)" berisi tanggal (2026-05-10) | Log Sales → Daftar Kamar & Harga | Data master kamar korup |
| No. HP tersimpan sebagai angka (float) | Log Booking, Database Penghuni | Presisi hilang / nol depan hilang; kirim WA gagal |
| Kamar diisi angka polos (9, 27) bukan ID "KTD-9" | Log Booking kolom Kamar | Join antar sheet tidak konsisten |
| Tanggal typo "0206-04-01" | Log Input Transaksi → Input Sewa Dimuka | Jurnal salah periode |
| Nama penghuni free-text tidak konsisten ("Keiza", "Sewa Delinda", "Listrk Kamar Sella") | Input Sewa Dimuka kolom Unit/Penyewa | Tidak bisa dilacak per penghuni; typo |
| Banyak baris tanpa No. HP | Log Booking | Tagihan WA tidak terkirim |

Akar masalah: spreadsheet mengizinkan input bebas format tanpa validasi. Solusinya mengunci format di titik masuk data.

## 3. Success Metrics

1. Operasional: waktu input < 30 detik; kesalahan input < 10%.
2. Adopsi: 100% operator memakai mini app; spreadsheet hanya diakses pengawas & owner.

**[BARU] Cara mengukur:**
- Waktu input: diukur otomatis di app (timestamp buka form → submit), dicatat di audit log.
- Kesalahan input: jumlah koreksi data per bulan (baris yang diedit pengawas di spreadsheet + submit ulang di app) ÷ total submit. Baseline diambil dari bulan pertama.
- Adopsi: % baris baru di spreadsheet yang berasal dari app (ditandai kolom sumber/audit) vs manual.

## 4. User Roles

| Role | Hak Akses | Fungsi |
|---|---|---|
| Owner | Semua divisi & data | Audit & monitoring |
| Pengawas | Semua divisi | Verifikasi data & monitoring operasional |
| Staff Admin | Modul 1–6 | Input data |
| Staff Sales | Modul 7 | Input data |
| Staff Marketing | Modul 8 | Input data |
| Staff Maintenance | Modul 9, 11 | Input data |
| Staff Inspeksi | Modul 10, 12 | Input data |

**[KEPUTUSAN PO]** Fase 1 hanya 1 kost (Tiga Dara Putri UGM). Konsep "cabang" DIHAPUS dari fase 1; RBAC cukup per divisi. Multi-kost tetap di Future Phase (namun setiap tabel baru diberi kolom `kost_id` default "KTD" agar migrasi multi-kost tidak perlu restrukturisasi).

## 5. Authentication & Authorization

- Login: username + password, hash bcrypt/argon2 (bukan plaintext). JWT, konsisten dengan Dashboard Manajemen yang ada.
- Session: persist login; auto logout setelah 3 hari tidak digunakan (refresh token dengan sliding expiry 72 jam).
- RBAC: Owner, Pengawas, Staff per divisi. Staff tidak bisa lintas divisi.

**[BARU] User Management:**
- Akun dibuat & dinonaktifkan oleh Owner melalui halaman admin sederhana (atau langsung di Upstash Redis pada fase awal — diputuskan saat build).
- Reset password: oleh Owner (generate password sementara, wajib ganti saat login pertama).
- Tidak ada self-registration.
- Estimasi user awal: 1 owner, 1–2 pengawas, ±5 staff. (Perlu konfirmasi daftar nama saat setup.)

## 6. Modul Utama — dengan Spesifikasi Field **[BARU: seluruh detail field]**

Prinsip umum semua modul:
- App hanya menulis ke kolom input; kolom berformula di spreadsheet TIDAK ditulis (nilai formula dibiarkan terhitung sendiri).
- Semua entitas (kamar, penghuni, akun, kategori, PIC) dipilih dari dropdown, bukan diketik.
- Setiap submit menambahkan metadata audit (lihat §9).
- No. HP dinormalisasi ke format `628xxxxxxxxx` dan ditulis sebagai TEKS (bukan angka).
- Nominal ditulis sebagai angka murni (integer rupiah), tanggal sebagai tanggal (bukan teks).

### Modul 1 — Penghuni Baru (Staff Admin)
Target: **Log Sales → sheet "Log Booking"**.

| Field | Tipe | Validasi |
|---|---|---|
| Tanggal Booking | date picker | default hari ini; tidak boleh masa depan >7 hari |
| Nama Penyewa | teks | wajib, min 3 karakter |
| No. HP | teks | regex `^628[0-9]{7,12}$`, unik terhadap penghuni aktif |
| Kamar | dropdown | dari Daftar Kamar & Harga, hanya status ≠ "Terisi"; ditulis sebagai ID "KTD-x" |
| Tgl Masuk | date picker | ≥ tanggal booking − 1 hari |
| Durasi (bulan) | dropdown 1/2/3/6/9/12 | wajib |
| Harga Disepakati | angka (auto dari master harga sesuai durasi, boleh override) | > 0 |
| Status Booking | dropdown (sesuai daftar di sheet SETTING) | wajib |
| Sumber Leads | dropdown (Mami Kos, Referral, Facebook, dst — dari SETTING) | wajib |
| Catatan | teks | opsional |
| Upload KTP & Kontrak | file | → Google Drive (lihat §7) |

Kolom yang TIDAK ditulis app: `No. Booking` (formula) dan `Tgl Keluar (Est.)` (formula) — baris baru harus menyalin formula atau dibiarkan (diverifikasi saat build).

### Modul 2 — Pencatatan Pembayaran Sewa (Staff Admin)
**[KEPUTUSAN PO]** App mencatat pembayaran DAN men-trigger Apps Script yang sudah ada di file **Invoice Pembayaran DP** dan **Invoice Pembayaran Sewa** (bukan membangun ulang generator invoice). Alur:

1. Pilih penghuni (dropdown dari Database Penghuni → DATA, status Aktif) → kamar & harga tampil otomatis.
2. Input: jenis pembayaran (DP / Sewa), tanggal bayar, nominal, jumlah bulan, akun kas/bank tujuan (dropdown KasList dari Log Input Transaksi → Pengaturan), upload bukti transfer.
3. App menulis 1 baris ke **Log Input Transaksi → "Input Sewa Dimuka"** (Tanggal Mulai, Unit/Penyewa dalam format baku `KTD-x — Nama`, Nominal per Bulan, Jumlah Bulan, Akun Kas/Bank, Sudah Digenerate? = "Belum") — jurnal tetap digenerate oleh Apps Script "Kost Tools" yang ada, TIDAK ditulis langsung ke sheet Transaksi (menghindari duplikasi jurnal).
4. App memperbarui **Generator Tagihan** (tanggal pembayaran terakhir & durasi penghuni terkait).
5. App memanggil endpoint Apps Script (doPost web app + token rahasia) untuk generate invoice; PDF invoice tersimpan di Drive dan link-nya dicatat.

Validasi: tidak bisa input pembayaran 2× untuk penghuni & periode yang sama (cek kombinasi penghuni + rentang periode); nominal harus > 0; warning jika nominal ≠ harga × jumlah bulan.

⚠️ Prasyarat teknis: Apps Script di kedua file Invoice harus di-deploy sebagai Web App (executable by anyone with token). Diverifikasi saat build; jika script tidak bisa dipanggil eksternal, fallback = app menulis ke sheet input invoice dan staff menekan tombol kirim seperti biasa.

### Modul 3 — Pindah Kamar (Staff Admin)
Target: **file spreadsheet BARU "Log Pindah Kamar"** (dibuat saat setup) dengan kolom:
`Tanggal | Penghuni (KTD-x — Nama) | Kamar Lama | Kamar Baru | Harga Lama | Harga Baru | Alasan | Efektif Mulai | Catatan | Diinput Oleh | Timestamp`

Aturan: Kamar Baru harus berstatus kosong (cek real-time ke master); Kamar Lama otomatis dari data penghuni; setelah submit, app memperbarui status kedua kamar di Daftar Kamar & Harga. Selisih harga ditampilkan sebagai info (penyesuaian tagihan dilakukan di Modul 2).

### Modul 4 — Checkout (Staff Admin)
Target: **file spreadsheet BARU "Log Checkout"** dengan kolom:
`Tanggal Checkout | Penghuni | Kamar | Tgl Masuk | Tunggakan? (Ya/Tidak + nominal) | Pengembalian Deposit (Rp) | Kondisi Kamar (dropdown: Baik/Perlu Perbaikan/Rusak) | Catatan Kerusakan | Diinput Oleh | Timestamp`

Aturan: warning (bukan blokir) jika penghuni masih punya tunggakan (dihitung dari jatuh tempo di Generator Tagihan/Database Penghuni); setelah submit, status kamar → "Kosong", status penghuni → "Non-aktif"; jika kondisi kamar "Perlu Perbaikan/Rusak", app menawarkan membuat tiket di Modul 11.

### Modul 5 — Pencatatan Pengeluaran (Staff Admin)
Target: **Log Input Transaksi → sheet "Transaksi"** (kolom A–F saja; kolom G+ berformula, tidak ditulis).

| Field | Tipe | Validasi |
|---|---|---|
| Tanggal | date picker | dalam periode berjalan |
| Kategori Pengeluaran | dropdown bertingkat | dipetakan dari **Daftar Akun** (125 akun sudah ada: Kode, Nama, Tipe, Saldo Normal). App menampilkan kategori ramah-user; pemetaan ke Akun Debit dilakukan DI APP, struktur spreadsheet tidak berubah (sesuai catatan PRD v1.0) |
| Dibayar Dari | dropdown | KasList (Uang Kas, Aset Bank, Rekening Ops, Rekening Profit) → jadi Akun Kredit |
| Nominal | angka | > 0, format ribuan di UI, disimpan angka murni |
| Keterangan | teks | wajib, template terstruktur `[Item] - [Vendor/Toko]` |
| Kategori | dropdown | Operasional/Non-operasional (mengikuti kolom F sheet) |
| Upload Nota | file | → Drive |

Aturan double-entry dijaga otomatis: 1 input = 1 baris debit-kredit seimbang (Akun Debit = akun beban hasil pemetaan, Akun Kredit = kas/bank, 1 nominal).

### Modul 6 — Feedback (Staff Admin)
Target: **Logbook Feedback**. Header sheet diverifikasi saat build (struktur pasti: logbook per baris). Field minimal: Tanggal, Sumber (Penghuni — dropdown / Lainnya), Kategori Feedback (dropdown), Isi, Tindak Lanjut, Status (dropdown), PIC, Foto (upload → Drive).

### Modul 7 — Survey (Staff Sales)
Target: **Log Sales → sheet "Log Survey"**, kolom persis mengikuti header eksisting:
`Tanggal Survey | Nama Calon Penyewa | No. HP | Dari Mana (dropdown) | Kamar Ditinjau (dropdown, multi) | Jam Survey | Durasi (mnt) | Feedback/Kesan | Keberatan/Kendala | Hasil Survey (dropdown) | Tindak Lanjut (dropdown) | PIC (dropdown) | Tanggal FU`

### Modul 8 — Leads, Konten, Promosi (Staff Marketing)
Target: **Logbook Kerja Marketing** → sheet `Log Leads Harian`, `Log Konten`, `Log Promosi`.
⚠️ **Temuan audit: ketiga sheet ini BELUM ADA** (file Logbook Kerja Marketing masih kosong, hanya header dokumen). Struktur sheet harus dibuat dulu saat setup. Usulan kolom (dikonfirmasi ke tim marketing saat build):
- Log Leads Harian: `Tanggal | Kanal (dropdown) | Jumlah Leads | Leads Respon | Leads Survey | Catatan`
- Log Konten: `Tanggal | Platform (dropdown) | Jenis Konten (dropdown) | Judul/Tema | Link | Status (dropdown) | PIC`
- Log Promosi: `Tanggal Mulai | Tanggal Selesai | Nama Promo | Kanal | Budget (Rp) | Target | Realisasi | Status`

### Modul 9 — Perawatan Preventif (Staff Maintenance)
Target: **Log Laporan Inspeksi Perawatan Perbaikan → "Log Perawatan Preventif"**. Kolom input: `Tanggal Jadwal, Tanggal Selesai, Fasilitas/Item, Jenis Perawatan (dropdown), Kategori (dropdown), Penyebab (dropdown), Deskripsi Pekerjaan, Prioritas (dropdown), Pelaksana (dropdown), Vendor, Biaya (Rp), Status (dropdown), Catatan/Dokumentasi (+upload foto)`. TIDAK ditulis: `No`, `Kode`, `ID TIKET` (formula).

### Modul 10 — Inspeksi Kebersihan (Staff Inspeksi)
Target: **Logbook Inspeksi Kebersihan**. Header diverifikasi saat build; field minimal: Tanggal, Area (dropdown), Hasil/Kondisi (dropdown skala), Temuan, Tindak Lanjut, Petugas, Foto.

### Modul 11 — Perbaikan Korektif (Staff Maintenance)
Target: **"Log Perbaikan Korektif"**. Kolom input: `Tanggal Kerusakan, Tanggal Lapor, Tanggal Selesai, Sumber Laporan (dropdown), Lokasi/Item Rusak, Kategori (dropdown), Penyebab (dropdown), Deskripsi Kerusakan, Prioritas (dropdown), Pelaksana, Vendor, Biaya (Rp), Status (dropdown), Catatan/Dokumentasi (+upload)`. TIDAK ditulis: `No`, `Kode`, `Durasi Perbaikan`, `ID Tiket` (formula).

### Modul 12 — Inspeksi Fasilitas (Staff Inspeksi)
Target: **"Log Inspeksi Harian"**. Kolom input: `Tanggal, Area/Fasilitas (dropdown), Kondisi Ditemukan, Kategori (dropdown), Tindak Lanjut Diperlukan? (dropdown), Petugas Inspeksi (dropdown), Catatan`. TIDAK ditulis: `No` (formula). Jika "Tindak Lanjut = Ya", app menawarkan buat entri Modul 9/11.

## 7. File Management **[dilengkapi]**

Dokumen: KTP, Kontrak, Bukti Transfer, Nota Pengeluaran, Foto Komplain/Temuan. Penyimpanan: Google Drive.

**[BARU] Struktur & aturan:**
- Folder: `[Administrasi Penghuni]/Form Penghuni/{KTD-x — Nama}/` untuk KTP & kontrak; `Pembayaran Sewa Penghuni/{tahun-bulan}/` untuk bukti transfer; `[Feedback Penghuni]/` untuk foto komplain; folder maintenance untuk foto temuan. (Menyesuaikan folder eksisting di Drive.)
- Penamaan file: `{YYYYMMDD}_{modul}_{KTD-x|umum}_{jenis}.{ext}`.
- Batas: maks 10 MB/file; format jpg/png/pdf.
- Setelah upload, app menulis link file ke kolom catatan/dokumentasi baris terkait.
- Akses folder via Service Account yang sama (folder di-share ke service account).

## 8. Integrasi Spreadsheet **[dilengkapi]**

Alur: Mini App → API Layer (Next.js API Routes) → Google Sheets API v4 (Service Account).

**[BARU] Aturan penting hasil audit:**
1. **Database Penghuni → sheet DATA & DASHBOARD bersifat READ-ONLY untuk app.** Kolom-kolomnya berisi formula/IMPORTRANGE. App membacanya sebagai master penghuni & okupansi, tetapi TIDAK PERNAH menulis ke sana. Penulisan penghuni baru terjadi di Log Booking (sumber datanya).
2. **Sheet Transaksi & sheet log lain memiliki kolom formula** — app menulis hanya ke kolom input (didefinisikan per modul di §6) menggunakan `values.append` dengan range kolom eksplisit.
3. **Jurnal sewa dimuka digenerate Apps Script "Kost Tools"** — app tidak menduplikasi logika itu (lihat Modul 2).
4. Master data dropdown dibaca dari: Daftar Kamar & Harga (kamar + harga + status), Daftar Akun (akun & KasList), Database Penghuni DATA (penghuni aktif), sheet SETTING masing-masing file (nilai dropdown). Di-cache di server 5 menit untuk hemat kuota API.
5. Kuota Sheets API: 300 req/menit/project — cukup untuk ±8 user; semua penulisan lewat 1 service account dengan retry + exponential backoff.

## 9. Audit Log **[dilengkapi]**

**[KEPUTUSAN PO]** Disimpan di **spreadsheet terpisah "Audit Log Mini App"** (dibuat saat setup), append-only, hanya bisa diakses Owner & Pengawas.

Kolom: `Timestamp (ISO) | Request ID | User | Role | Modul | Aksi (CREATE/UPDATE) | File & Sheet Target | Baris | Data Lama (JSON) | Data Baru (JSON) | Durasi Input (detik) | Status (sukses/gagal) | Pesan Error`

Setiap submit dari app menghasilkan tepat 1 baris audit (termasuk yang gagal). Durasi input dipakai untuk mengukur success metric §3.

## 10. Error Prevention **[dilengkapi]**

Prinsip: minimalisasi typing — dropdown, radio button, date picker, search select; hindari free text.

Validasi bisnis (server-side, bukan hanya di form):
1. Penghuni: No. HP unik (terhadap penghuni aktif).
2. Kamar: tidak boleh double occupancy — sebelum tulis, server membaca ulang status kamar; jika sudah terisi, submit ditolak.
3. Pembayaran: tidak bisa input bayar 2× untuk penghuni + periode sama.
4. Checkout: warning jika ada tunggakan.

**[BARU] Concurrency & keandalan:**
- Idempotency: setiap submit membawa `request_id` unik; server menolak `request_id` yang sudah pernah diproses (mencegah baris dobel saat koneksi buruk/dobel klik).
- Race condition dicegah dengan lock ringan per-resource (per kamar / per penghuni) di Redis selama proses tulis.
- Koneksi lapangan buruk: form menyimpan draft di localStorage; jika submit gagal, data tidak hilang dan bisa dikirim ulang. (Full offline-mode BUKAN scope fase 1.)
- Semua kegagalan tulis ke spreadsheet ditampilkan jelas ke user + tercatat di audit log.

## 11. Mobile Requirements

Target utama mobile (iPhone & Android) + desktop; responsive; PWA (Add to Home Screen, full screen, mobile-first UI). **[BARU]** Ukuran target: form selesai ≤ 1 layar scroll; tombol minimal 44px; bekerja di Chrome/Safari 2 versi terakhir.

## 12. Technical Architecture

- Front-End: Next.js (React) — *catatan koreksi: v1.0 menulis "Node.js" sebagai front-end; yang dimaksud adalah stack JavaScript dengan Next.js*.
- Hosting: Vercel.
- Auth: JWT + Upstash Redis (kredensial akun & session), pola sama dengan Dashboard Manajemen eksisting.
- API: Next.js API Routes (serverless) → Google Sheets API v4 via Service Account; Google Drive API untuk upload file; HTTPS only.
- Data source: Google Spreadsheet (source of truth); Redis hanya untuk auth/session/lock/idempotency, bukan data bisnis.
- Invoice: trigger Apps Script Web App (Modul 2).
- **[BARU] Keamanan:** kredensial Service Account & token Apps Script disimpan sebagai environment variables di Vercel (tidak pernah di repo); service account hanya di-share ke spreadsheet/folder yang diperlukan; validasi & sanitasi semua input di server.

## 13. Data Cleansing Pra-Go-Live **[BARU]**

Wajib dibereskan sebelum app dipakai (app tidak memperbaiki data lama otomatis):
1. Perbaiki kolom Luas (m²) di Daftar Kamar & Harga (saat ini berisi tanggal).
2. Normalisasi seluruh No. HP ke teks format 628… (Log Booking, Database Penghuni, Generator Tagihan).
3. Seragamkan kolom Kamar di Log Booking ke format "KTD-x".
4. Perbaiki tanggal typo (mis. 0206-04-01 di Input Sewa Dimuka).
5. Konfirmasi penomoran kamar (KTD-27 → KTD-29, tidak ada KTD-28: disengaja atau data hilang?).
6. Lengkapi No. HP penghuni aktif yang kosong.
7. Buat 3 sheet marketing (Modul 8) + 2 file baru (Log Pindah Kamar, Log Checkout) + spreadsheet Audit Log.

## 14. Rencana Rilis & UAT **[BARU]**

**[KEPUTUSAN PO]** Scope build: SEMUA 12 modul sekaligus. Urutan pengerjaan internal (agar dependensi benar): fondasi (auth, RBAC, integrasi Sheets/Drive, audit log) → master data & cache → Modul 1, 2, 5 (alur uang) → Modul 3, 4 → Modul 7, 8 → Modul 9–12 → Modul 6.

UAT: setiap divisi menguji modulnya dengan data dummy di salinan spreadsheet (bukan file produksi); go-live per divisi setelah UAT lolos; 2 minggu pertama pengawas memverifikasi sampel input harian.

## 15. Risiko Utama **[BARU]**

| Risiko | Mitigasi |
|---|---|
| Build 12 modul sekaligus → lama sampai ada nilai nyata, risiko rework besar | Urutan internal §14 + UAT per divisi; jika molor, go-live bisa per divisi |
| Apps Script Invoice tidak bisa dipanggil eksternal | Fallback: app isi sheet input, staff tekan tombol manual |
| Struktur sheet berubah manual oleh pengawas/owner | Kontrak kolom diverifikasi saat startup app; mismatch → alert, tulis ditolak |
| Kuota / error Google API | Cache master data, retry + backoff, antrian tulis |
| Sheet Feedback/Kebersihan/Marketing belum terdefinisi penuh | Diverifikasi/dibuat saat setup (§13 no. 7) sebelum modul terkait di-build |

## 16. Future Phase

Reminder (jatuh tempo sewa, pembayaran operasional), approval workflow, multi-kost management, integrasi akses kontrol pintu (Hikvision), offline mode penuh.

## 17. Log Keputusan Product Owner (7 Juli 2026)

1. Scope fase 1: semua 12 modul sekaligus.
2. Cabang: 1 kost saja; konsep cabang dihapus dari fase 1 (disiapkan kolom `kost_id` untuk masa depan).
3. Audit log: spreadsheet terpisah, append-only.
4. Modul 2: catat pembayaran + generate invoice dengan MEN-TRIGGER Apps Script eksisting di file Invoice Pembayaran DP & Invoice Pembayaran Sewa (bukan membangun ulang).
