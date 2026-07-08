# Langkah Selanjutnya: Mini App Operasional Kost

Status kode: **semua 12 modul (14 handler, termasuk 3 sub-form Modul 8) sudah dibangun**, `npm run typecheck` + `npm run build` lolos, **DAN sekarang terhubung live ke Google Sheets produksi** (`GOOGLE_PRIVATE_KEY` sudah benar). Modul 1, 2, 5, 7 header-nya sudah dicocokkan langsung ke sheet asli — bukan tebakan lagi. Detail teknis lengkap ada di `HANDOFF-CLAUDE-CODE.md`.

Kerjakan berurutan — tiap tahap bergantung pada tahap sebelumnya.

## 1. Kredensial & environment

- [x] **`GOOGLE_PRIVATE_KEY` sudah BENAR** — sempat ada 2 percobaan gagal (fingerprint salah, lalu paste kepencet masuk baris komentar), sekarang sudah direkonstruksi & DIVERIFIKASI JALAN (app berhasil baca data live dari Log Sales & Log Input Transaksi).
- [x] `SHEET_ID_AUDIT_LOG`, `SHEET_ID_PINDAH_KAMAR`, `SHEET_ID_CHECKOUT` — sudah terisi (belum diverifikasi header sheet-nya sendiri sudah dibuat/belum — lihat §2).
- [x] `APPS_SCRIPT_INVOICE_DP_URL`, `APPS_SCRIPT_TOKEN` — sudah terisi (belum diverifikasi bisa dipanggil eksternal).
- [x] `DRIVE_FOLDER_PENGHUNI`/`PEMBAYARAN`/`NOTA`/`FEEDBACK`/`MAINTENANCE` — sudah terisi.
- [ ] (Opsional tapi disarankan) Rotasi `JWT_SECRET` dan `UPSTASH_REDIS_REST_TOKEN` — sempat tertulis di `.env.example` sebelum dibersihkan.

### ⚠️ Perlu klarifikasi dari kamu
Data live kamar menunjukkan kamar **nomor 30 ADA** (Comfy AC, status Terisi) — kamu sebelumnya bilang kamar 28 DAN 30 keduanya tidak ada. Yang terverifikasi hilang cuma **28**. Bisa dicek ulang? (Tidak berdampak ke kode — app baca apa adanya dari sheet — tapi supaya datamu sendiri konsisten.)

## 2. Buat spreadsheet & sheet baru (header harus PERSIS sama teksnya)

- [ ] **Audit Log Mini App** (spreadsheet baru) — sheet "Log", kolom:
  `Timestamp (ISO) | Request ID | User | Role | Modul | Aksi | File & Sheet Target | Baris | Data Lama (JSON) | Data Baru (JSON) | Durasi Input (detik) | Status | Pesan Error`
  → isi ID ke `SHEET_ID_AUDIT_LOG`.
- [ ] **Log Pindah Kamar** (spreadsheet baru) — sheet "Log Pindah Kamar", kolom:
  `Tanggal | Penghuni | Kamar Lama | Kamar Baru | Harga Lama | Harga Baru | Alasan | Efektif Mulai | Catatan | Diinput Oleh | Timestamp`
  → isi ID ke `SHEET_ID_PINDAH_KAMAR`.
- [ ] **Log Checkout** (spreadsheet baru) — sheet "Log Checkout", kolom:
  `Tanggal Checkout | Penghuni | Kamar | Tgl Masuk | Tunggakan? | Pengembalian Deposit | Kondisi Kamar | Catatan Kerusakan | Diinput Oleh | Timestamp`
  → isi ID ke `SHEET_ID_CHECKOUT`.
- [ ] Di file **Log Marketing** (`1fZ4DHZx8uasta5mfttWhQhfrPOpprb8VrpEPFUGI2FE`, sudah ada — BUKAN "Logbook Kerja Marketing", itu file berbeda), buat 3 sheet baru:
  - **Log Leads Harian**: `Tanggal | Kanal | Jumlah Leads | Leads Respon | Leads Survey | Catatan`
  - **Log Konten**: `Tanggal | Platform | Jenis Konten | Judul/Tema | Link | Status | PIC`
  - **Log Promosi**: `Tanggal Mulai | Tanggal Selesai | Nama Promo | Kanal | Budget | Target | Realisasi | Status`

## 3. Pastikan/buat sheet SETTING (sumber dropdown)

Cek apakah sheet "SETTING" berikut sudah ada dengan kolom-kolom ini (kalau belum ada, dropdown terkait akan kosong — bukan error keras, tapi form tidak bisa dipakai):

- [x] Log Sales → SETTING: `Dari Mana`, `Hasil Survey`, `Tindak Lanjut`, `PIC`, `Status Booking`, `Sumber Leads` — **sudah dikonfirmasi live 8 Jul**, semua 6 dropdown terverifikasi jalan dgn data asli (mis. Status Booking: Pending/Konfirmasi/Check-In/Check-Out/Dibatalkan).
- [x] Log Input Transaksi → Pengaturan (KasList) — **sudah dikonfirmasi live 8 Jul**. ⚠️ Ternyata BUKAN sheet tabel biasa — "Pengaturan" adalah sheet key-value (Nama Usaha/Tahun/Bulan di kolom A-B), KasList adalah daftar nilai di kolom D mulai baris 3 (Uang Kas, Aset Bank, Rekening Ops, Rekening Profit — 4 nilai, sudah sesuai PRD). Kode sudah disesuaikan ke struktur asli ini.
- [x] Log Laporan Inspeksi Perawatan Perbaikan → SETTING — **sudah dikonfirmasi via screenshot user (8 Jul)**, struktur aktual 11 kolom:
  `Jenis Perawatan | Kategori Inspeksi | Tindak Lanjut | Kategori Preventif | Sumber Laporan Korektif | kategori korektif | Penyebab | Prioritas | Status | Area | PIC`
  Catatan: `Penyebab`, `Prioritas`, `Status`, `PIC` DIPAKAI BERSAMA Modul 9 & 11 (bukan dipisah — sudah disesuaikan di kode); `Kategori Preventif`/`kategori korektif`/`Kategori Inspeksi` masing-masing punya kolom sendiri per modul; `Tindak Lanjut` (Ya, Perbaikan / Ya, jadwalkan Perawatan / Tidak) khusus Modul 12.
- [ ] Logbook Feedback → SETTING: `Kategori`, `Status`, `PIC`
- [ ] Logbook Inspeksi Kebersihan → SETTING: `Area`, `Hasil`, `Petugas`
- [ ] Log Marketing → SETTING: `Kanal Leads` (khusus Log Leads Harian), `Platform`, `Jenis Konten`, `Status Konten` (khusus Log Konten), `Kanal Promosi`, `Status Promosi` (khusus Log Promosi), `PIC` — sengaja dipisah per sub-form, tidak ada kolom yang dipakai bersama antar Leads/Konten/Promosi

## 4. Akses & deployment eksternal

- [ ] Share SEMUA spreadsheet (Log Sales, Log Input Transaksi, Generator Tagihan, **Log Marketing**, Logbook Feedback/Inspeksi Kebersihan, Log Laporan Inspeksi Perawatan Perbaikan, + 3 spreadsheet baru di §2) ke email service account sebagai **Editor**. "Logbook Kerja Marketing" tidak perlu di-share dulu — belum ada modul yang menargetkannya.
- [ ] Share **Database Penghuni** sebagai **Viewer** saja (app tidak pernah menulis ke sana).
- [ ] Share 5 folder Drive ke email service account, isi ID-nya: `DRIVE_FOLDER_PENGHUNI`, `DRIVE_FOLDER_PEMBAYARAN`, `DRIVE_FOLDER_NOTA`, `DRIVE_FOLDER_FEEDBACK`, `DRIVE_FOLDER_MAINTENANCE`.
- [ ] Deploy Apps Script di file **Invoice Pembayaran DP** sebagai Web App (doPost) → isi `APPS_SCRIPT_INVOICE_DP_URL`.
- [ ] Verifikasi Apps Script di **Invoice Pembayaran Sewa** (URL sudah ada di env) bisa dipanggil eksternal dengan token.

## 5. Data cleansing (PRD §13) — sebelum go-live

- [ ] Perbaiki kolom Luas (m²) di Daftar Kamar & Harga (saat ini berisi tanggal).
- [ ] Normalisasi semua No. HP lama ke teks format `628...` (Log Booking, Database Penghuni, Generator Tagihan).
- [ ] Seragamkan kolom Kamar di Log Booking ke format angka polos tanpa leading zero (mis. "9", bukan "09" atau "KTD-9") — **dikoreksi 8 Jul**: "KTD-x" itu ID Penghuni, BUKAN format kamar.
- [x] Konfirmasi penomoran kamar: **sudah dikonfirmasi user** — tidak ada kamar nomor 28 dan 30 (disengaja, bukan data hilang). Tidak perlu tindakan lebih lanjut.
- [ ] Perbaiki tanggal typo (mis. "0206-04-01" di Input Sewa Dimuka).
- [ ] Lengkapi No. HP penghuni aktif yang kosong.

## 6. Keputusan yang masih kamu perlu ambil

- [x] Upstash Redis dipakai bersama dashboard internal lain — **dikonfirmasi**, prefix `miniapp:` **sudah diimplementasi** di semua key.
- [x] Kategori pengeluaran → akun: **diselesaikan dengan cara berbeda dari rencana awal** — bukan mapping kategori-custom, tapi dropdown 2 tingkat (Tipe Akun dulu, baru Nama Akun difilter sesuai Tipe), pakai 125 akun asli yang kamu kirim.
- [x] Self-registration via Google + approval Owner — **DIBANGUN 8 Jul** (peningkatan dari PRD, dikonfirmasi user). Lihat §10.

## 7. Buat akun user

- [x] **Akun pertama sudah dibuat:** username `administrator`, role `owner` (password sudah kamu set sendiri) — sudah dites login berhasil.
- [x] Akun test `owner-test` sudah dihapus dari Redis.
- [ ] Akun staff lain: SEKARANG BISA lewat 2 jalur — (a) staff daftar sendiri via tombol "Daftar/Masuk dengan Google" di /login (butuh `GOOGLE_OAUTH_CLIENT_ID`/`SECRET` diisi dulu, lihat §10), lalu Owner approve di `/admin/users`; atau (b) `node scripts/seed-user.mjs <username> <password> <role> "<Nama Lengkap>"` manual per staff (masih berfungsi, tidak dihapus).

## 8. UAT (uji coba) — pakai SALINAN spreadsheet, bukan produksi

- [ ] Duplikat spreadsheet yang dipakai testing (jangan langsung ke file produksi) — atau minimal sadari test-submit akan masuk ke data asli. **Belum ada submit test yang dilakukan ke sheet manapun sesi ini** — semua verifikasi 8 Jul murni baca (read-only), jadi belum ada data test yang perlu dibersihkan.
- [ ] Jalankan `npm run dev`, login sebagai `administrator`, coba tiap modul satu per satu.
- [ ] Kalau muncul error "Struktur sheet berubah (kolom tidak cocok: ...)" — itu `assertHeaders` menolak karena teks header di sheet asli beda dari yang ditebak di kode. Baca pesan error (menampilkan header aktual), lalu edit `EXPECTED_HEADERS` di file `src/lib/modules/handlers/<nama-modul>.ts` yang sesuai.
- [ ] Urutan verifikasi disarankan (dari confidence tertinggi ke terendah): **Modul 1, 2, 5, 7 (header sudah dicocokkan live 8 Jul — harusnya langsung jalan)** → Modul 3, 4, 8a/8b/8c (sheet baru, tinggal dibuat sesuai §2) → Modul 9, 11, 12 (kolom SETTING sudah pasti, kolom target tulis masih tebakan posisi) → Modul 6, 10 (paling belum pasti, bahkan nama sheet-nya tebakan).
- [ ] 2 minggu pertama setelah go-live: pengawas verifikasi sampel input harian (PRD §14).

## 9. Fitur yang belum dibangun (di luar checklist deployment, untuk sesi development berikutnya)

- Upload file ke Google Drive (`/api/upload`) — semua field foto/dokumen belum fungsional.
- Update otomatis Generator Tagihan setelah pembayaran (Modul 2).
- Multi-select untuk field "Kamar Ditinjau" (Modul 7) — saat ini text field biasa.
- Prompt otomatis "buat tiket Modul 9/11" saat inspeksi menemukan kondisi buruk (Modul 4/12).

## 10. Self-registration via Google — DIBANGUN 8 Jul, tinggal 1 langkah setup

Sudah selesai dikerjakan & diverifikasi (approve/role/nonaktifkan semua dites lewat UI+API asli, lihat `HANDOFF-CLAUDE-CODE.md` utk detail). **Satu-satunya yang kurang: kredensial OAuth Google asli.**

- [ ] Buka Google Cloud Console → APIs & Services → Credentials → **Create OAuth client ID** → Web application.
- [ ] Authorized redirect URI: `http://localhost:3000/api/auth/google/callback` (dev). Nanti tambah URI produksi juga setelah deploy ke Vercel.
- [ ] Isi `GOOGLE_OAUTH_CLIENT_ID` dan `GOOGLE_OAUTH_CLIENT_SECRET` di `.env.local` (saat ini kosong — tombol Google di /login akan error kalau diklik sebelum ini diisi).
- [ ] Tes: klik "Daftar / Masuk dengan Google" di /login → pastikan sampai ke consent screen Google sungguhan → setelah login, harus mendarat di `/pending` (karena user baru) → buka `/admin/users` sebagai `administrator` → Approve user itu dgn role yang sesuai → login Google lagi → sekarang harus dapat akses penuh.
- [ ] Setelah approve, coba juga: ubah role user aktif, nonaktifkan, aktifkan lagi — semua tombol ini sudah dites jalan lewat simulasi, tapi ada baiknya dicoba sekali dgn akun Google sungguhan.

## 11. Deploy ke Vercel (setelah semua di atas beres & UAT lolos)

- [ ] Push kode ke GitHub (repo ini belum `git init` — perlu inisialisasi dulu).
- [ ] Import project di Vercel.
- [ ] Set semua environment variable yang sama seperti `.env.local` di Vercel project settings.
- [ ] Deploy, lalu ulangi uji login + 1-2 submit per modul di environment production sebelum dibagikan ke staff.
