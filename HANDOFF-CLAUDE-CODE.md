# Handoff: Mini App Operasional Kost → lanjutkan di Claude Code

Konteks lengkap dari sesi Cowork (7 Juli 2026) untuk melanjutkan development.

## Apa ini

Web app (Next.js PWA, mobile-first) untuk input administrasi harian Kost Tiga Dara Putri UGM oleh staff (admin/sales/marketing/maintenance/inspeksi), pengawas, dan owner. Tujuan: minimalisasi human error. Data tetap tersimpan di Google Spreadsheet (source of truth); app hanyalah lapisan input tervalidasi.

- **PRD lengkap:** `PRD Mini App Operasional Kost v1.1.md` (folder ini) — BACA DULU, terutama §6 (spesifikasi field per modul), §8 (aturan integrasi), §13 (data cleansing).
- **Codebase:** `miniapp-kost/`
- **Stack:** Next.js 16 (App Router, TS, Turbopack) — di-upgrade dari 14.2.x via task terpisah 7 Jul (CVE kritis di 14.2.5); `params`/`cookies()`/`headers()` sekarang async, `middleware.ts` → `proxy.ts`. React 19. Tanpa Tailwind (globals.css), jose (JWT) + bcryptjs + Upstash Redis (auth/session/lock/idempotency), googleapis (Sheets v4 + Drive v3 via Service Account), zod tersedia. Hosting target: Vercel.

## Keputusan Product Owner (sudah final)

1. Scope: **semua 12 modul** sekaligus (urutan build internal ada di PRD §14).
2. **1 kost saja** — konsep cabang dihapus; siapkan kolom `kost_id`="KTD" di tabel baru untuk masa depan.
3. Audit log → **spreadsheet terpisah** "Audit Log Mini App", append-only.
4. Modul 2 (Pembayaran): catat pembayaran + **trigger Apps Script eksisting** di file Invoice Pembayaran DP/Sewa (doPost + token), BUKAN membangun ulang invoice. Fallback: isi sheet, staff klik tombol manual.
5. Upstash: **dikonfirmasi 8 Jul — database DIPAKAI BERSAMA dashboard internal lain.** Prefix `miniapp:` ke semua key Redis (`user:`, `lock:`, `req:`, `rl:`, `master:`) **sudah diimplementasi** via `nsKey()` di `src/lib/redis.ts` — semua tempat yang menyentuh Redis (auth.ts, login route, master.ts, submit route, seed-user.mjs) sudah pakai helper ini.
6. **Auth (8 Jul, BELUM dibangun):** User mau akun pertama (`administrator`/owner) dibuat manual (sudah di-seed), tapi user SELANJUTNYA daftar sendiri pakai **akun Google**, lalu perlu **approval role Owner** sebelum aktif; role tiap akun cuma bisa diatur Owner. Ini KONTRADIKSI dengan PRD §5 asli ("Tidak ada self-registration") — PRD perlu di-update atau keputusan ini dikonfirmasi ulang. Butuh: OAuth Google client (beda dari service account Sheets/Drive), state "pending approval" per user, UI approval + role management utk Owner. **BELUM dikerjakan** — perlu keputusan scope/prioritas dulu sebelum mulai (lihat §Belum dibangun).

## Spreadsheet aktual (ID sudah di `src/config/spreadsheets.ts`)

| File | Sheet penting | Catatan |
|---|---|---|
| Log Sales `1D5DO-_1RJ...` | 1.Daftar Kamar & Harga; Log Survey; Log Booking; SETTING | Log Booking: kolom A `No. Booking` & H `Tgl Keluar (Est.)` = FORMULA, jangan ditulis. Master kamar: No. Kamar (KTD-x), Tipe, Harga/Bulan/3/6/9/Tahun, Status |
| Log Input Transaksi `1Ms7So6...` | Pengaturan; Input Sewa Dimuka; Transaksi; Daftar Akun (125 akun) | Sheet Transaksi kolom G+ = formula; tulis A–F saja. Jurnal sewa dimuka digenerate Apps Script "Kost Tools" dari sheet Input Sewa Dimuka — app mengisi sheet itu, JANGAN tulis jurnal langsung |
| Generator Tagihan `1Ji0FAE...` | (data penghuni + tgl bayar terakhir) | Ada tombol kirim tagihan WA (Apps Script) |
| Database Penghuni `17qdAMk...` | DASHBOARD; DATA; DATABASE HISTORICAL; KALKULASI; SETTING | **READ-ONLY!** Penuh formula/IMPORTRANGE. Baca master penghuni aktif dari sheet DATA |
| Log Laporan Inspeksi Perawatan Perbaikan `1UxvDvD...` | Log Inspeksi Harian; Log Perawatan Preventif; Log Perbaikan Korektif; **SETTING (struktur dikonfirmasi 8 Jul, lihat §Progress)** | Kolom `No`, `Kode`, `ID TIKET`, `Durasi Perbaikan` = formula |
| Logbook Feedback `1hNFN9...`; Logbook Inspeksi Kebersihan `1niuspa...` | — | Header belum terekstrak — **verifikasi header aktual saat build modul 6 & 10** |
| Logbook Kerja Marketing `1RIfdj7...` | — | ⚠️ **KOREKSI 8 Jul:** BUKAN target Modul 8 — dipakai staff untuk input kegiatan kerja harian mereka. Belum ada modul yang menargetkan file ini. |
| Log Marketing `1fZ4DHZx...` | — | Target Modul 8 (Leads/Konten/Promosi) yang benar — dikoreksi user 8 Jul (sebelumnya salah dikira Logbook Kerja Marketing). Sheet Log Leads Harian/Log Konten/Log Promosi **BELUM ADA** — buat saat setup (usulan kolom di PRD §6 Modul 8) |
| Invoice Pembayaran Sewa `10QJeO...`; Invoice DP `1iX_5Lt...` | — | Target trigger Apps Script Modul 2 |

Spreadsheet baru (buat manual, ID via env): Audit Log Mini App, Log Pindah Kamar, Log Checkout.

## Data quality (app harus defensif)

No. HP tersimpan sebagai angka/float di sheet lama; ada tanggal typo "0206-04-01"; kolom Luas berisi tanggal. Helper `normalizePhone`, `normalizeRoomId`, `parseDateISO`, `parseRupiah` sudah ada di `src/lib/validate.ts`. Tulis No. HP selalu sebagai TEKS.

### ⚠️ KOREKSI PENTING 8 Juli: format ID kamar vs ID Penghuni

Asumsi awal sesi Cowork **SALAH** dan sudah diperbaiki: `KTD-x` **BUKAN** format nomor kamar — itu **ID Penghuni Aktif** (identitas penyewa). Nomor kamar sebenarnya adalah **angka polos tanpa leading zero** (`"1".."31"`, tidak ada kamar nomor **28 dan 30** — dikonfirmasi user, bukan data hilang).

Dampak & yang sudah diperbaiki:
- `normalizeRoomId()` di `validate.ts`: sekarang menghasilkan angka polos (bukan `"KTD-x"`).
- `Tenant` interface di `master.ts`: dipecah jadi `id` (ID Penghuni, format `KTD-x`, dipakai utk kolom "Unit/Penyewa" & label dropdown penghuni sesuai format baku PRD) dan `kamar` (nomor kamar polos, kolom TERPISAH di sheet Database Penghuni). Ditambah `getTenantByLabel(label)` utk lookup penghuni dari nilai dropdown.
- Handler yang SEBELUMNYA salah mem-parse nomor kamar dari prefix label penghuni (`penghuni.split('—')[0]`, mengira itu nomor kamar padahal itu ID Penghuni): `pembayaran-sewa.ts`, `pindah-kamar.ts`, `checkout.ts` — semua sudah diperbaiki pakai `getTenantByLabel()` utk ambil `tenant.kamar` yang benar.
- Kolom `ID Penghuni` di sheet Database Penghuni → DATA: header-nya BELUM diverifikasi (dicari via `findHeader` dgn kandidat 'ID Penghuni'/'id penghuni'/'no. penghuni'/'ktd') — kalau tidak ketemu, error jelas muncul saat runtime, sesuaikan kandidat di `getActiveTenants()`.
- Modul 1 (Penghuni Baru) TIDAK terpengaruh — field "Kamar" di situ memang selalu nomor kamar polos (booking kamar baru, belum ada ID Penghuni), sudah benar sejak awal setelah `normalizeRoomId()` diperbaiki.

Pelajaran: jangan asumsikan format ID dari nama variabel yang familiar (KTD terlihat seperti kode kamar) — konfirmasi ke user/struktur sheet asli dulu, terutama untuk identifier yang dipakai lintas-modul.

### 8 Juli (lanjutan): prefix Redis, akun real, cascading dropdown Modul 5

- **Prefix `miniapp:` Redis** — diimplementasi via `nsKey()` di `redis.ts`. Semua key (`user:`, `lock:`, `req:`, `rl:`, `master:`) sekarang `miniapp:user:...` dst. Akun test `owner-test` (key lama tanpa prefix) sudah dihapus dari Redis. Akun real pertama sudah di-seed: username `administrator`, role `owner` (password sudah diset user langsung, tidak dicatat di sini — key Redis `miniapp:user:administrator`), dikonfirmasi login berhasil via tes langsung.
- **Modul 5 (Pengeluaran): cascading dropdown Tipe Akun → Kategori Pengeluaran.** User kasih daftar 125 akun asli (Nama + Tipe, TANPA kolom Kode — beda dari asumsi PRD yg sebut ada Kode). Implementasi:
  - `FieldDef` ditambah `dependsOn`/`filterBy`; `DynamicForm.tsx` fetch semua data master sekali (`masterRaw`), lalu filter client-side sesuai nilai field pengontrol — tidak ada round-trip API tambahan per pilihan Tipe. Field dependent otomatis ke-reset kalau field pengontrolnya berubah, dan disabled dgn placeholder "Pilih di atas dulu..." sebelum pengontrolnya diisi.
  - Registry `pengeluaran`: field baru `tipeAkun` (select tetap, 8 opsi: Aset/Kontra Aset/Liabilitas/Ekuitas/Kontra Ekuitas/Pendapatan/Beban/Beban Non-Operasional) sebelum `akunDebit` (select-async, `dependsOn:'tipeAkun'`, `filterBy:'tipe'`).
  - `getAccounts()` di `master.ts`: kolom `Kode`/`Saldo Normal` dijadikan OPSIONAL (`findHeaderOptional`, tidak throw kalau tidak ada) — sebelumnya kalau kolom Kode benar-benar tidak ada, seluruh fungsi ini akan error total. `masterValue` utk `akunDebit` diganti dari `'kode'` ke `'nama'` (selalu ada, aman).
  - Diverifikasi via browser: dropdown Tipe Akun tampil 8 opsi benar, Kategori Pengeluaran disabled dgn placeholder yg benar sebelum Tipe Akun dipilih. Belum bisa verifikasi filter END-TO-END dgn data akun asli (private key masih invalid).

⚠️ **BELUM DIKERJAKAN — butuh keputusan scope:** user minta alur auth baru (self-registration via Google + approval Owner, role management UI utk Owner) — lihat §Keputusan PO poin 6. Ini perubahan besar (OAuth client baru, state pending-approval, UI admin) yang kontradiksi PRD asli. JANGAN mulai membangun ini tanpa konfirmasi scope/prioritas ke user dulu.

## Progress

**✅ Tahap 1 selesai (fondasi):** package.json, tsconfig, next.config, .env.example, README; `src/lib/`: redis.ts (withLock + claimRequestId), auth.ts (JWT 72h sliding, bcrypt), roles.ts (RBAC 7 role → 14 modul-id), google.ts (Sheets/Drive client + withRetry), sheets.ts (readRange/appendRow/updateRange + assertHeaders kontrak kolom + guard read-only + anti `=`-injection), validate.ts, audit.ts; middleware.ts; halaman login + menu per role; `src/lib/modules/registry.ts` (stub 14 entri, `ready:false`); scripts/seed-user.mjs; PWA manifest.

**✅ Tahap 2 selesai (engine):** `src/lib/sheets.ts` +`readTable()` (baca header+baris sbg objek); `src/lib/master.ts` — cache Redis 5 menit (`cached()`), `findHeader()` (pencocokan nama kolom case-insensitive/partial, biar tahan sedikit perubahan wording header), `getRooms`/`getAvailableRooms` (Daftar Kamar & Harga), `getAccounts` (Daftar Akun), `getActiveTenants` (Database Penghuni DATA, read-only), `getKasList` (Pengaturan), `getSettingList` generik, dispatcher `getMasterData(type)`; API `GET /api/master/[type]` (rooms, rooms-available, accounts, tenants, kaslist). Form engine: `src/lib/modules/types.ts` (FieldDef/SubmitHandler kontrak), `registry.ts` diperluas dgn `fields?: FieldDef[]`, komponen client `src/components/DynamicForm.tsx` (render field dari definisi, opsi dropdown async dari `/api/master`, draft localStorage, request_id per submit), dispatcher generik `POST /api/submit/[moduleId]` (`src/app/api/submit/[moduleId]/route.ts` — RBAC via `canAccess`, `claimRequestId` idempotency + lepas klaim saat gagal, `writeAudit`, 501 jika modul belum ready) + `getSessionUser()` baru di `auth.ts`, handler map kosong di `src/lib/modules/handlers/index.ts` siap diisi. Halaman `src/app/m/[id]/page.tsx` merender `DynamicForm` bila `ready && fields`, else placeholder "segera hadir". `npm install` + `npm run typecheck` + `npm run build` semua lolos.

⚠️ Catatan header sheet: kolom Daftar Kamar & Harga / Daftar Akun / Database Penghuni DATA dicocokkan via `findHeader()` (partial match) berdasar deskripsi di handoff — BELUM divalidasi ke sheet asli (butuh kredensial live). Kalau saat run nyata error "Kolom X tidak ditemukan", pesan errornya akan menampilkan header aktual — sesuaikan kandidat string di `master.ts`.

**✅ Tahap 3 — Modul 1 selesai (Penghuni Baru):** `src/lib/modules/handlers/penghuni-baru.ts` — validasi lengkap PRD §6/§10 (nama min 3 char, No. HP unik thd penghuni aktif, tanggal booking ≤ H+7, tgl masuk ≥ booking−1 hari, durasi harus salah satu 1/2/3/6/9/12); double-occupancy dicegah dgn `withLock('kamar:<id>')` + `getRoomFresh()` (baca status kamar TANPA cache, bukan dari `getRooms()` yg 5 menit); No. HP ditulis dgn prefix apostrof (`'628...`) agar Sheets simpan sbg TEKS bukan angka; append ke `'Log Booking'!B:N` dgn kolom H (formula) dibiarkan `null`. `master.ts` ditambah `getRoomFresh()`, `label` di `Room` (utk teks dropdown kamar "KTD-x — Tipe · Rp.../bln"), `getStatusBookingOptions`/`getSumberLeadsOptions` (dari Log Sales → SETTING). Registry `penghuni-baru` sekarang `ready:true` dgn 10 field lengkap. Handler terdaftar di `handlers/index.ts`. `npm run typecheck` + `npm run build` lolos (termasuk setelah Next 16 upgrade selesai berjalan paralel — lihat catatan di bawah).

⚠️ **`EXPECTED_HEADERS` di `penghuni-baru.ts` (untuk `assertHeaders`) adalah TEBAKAN dari label field PRD §6, BELUM diverifikasi ke teks header asli sheet "Log Booking".** Ini disengaja — `assertHeaders` akan menolak submit dgn pesan jelas (menampilkan header aktual) kalau teksnya beda, alih-alih diam-diam menulis ke kolom salah. Perbaiki array `EXPECTED_HEADERS` begitu sheet asli bisa diakses (kredensial live), sebelum UAT Modul 1. Field upload KTP/Kontrak (kolom M/N) sengaja belum ada di form — ditulis string kosong; UI upload dibangun Tahap 4.

⚠️ **Catatan kolaborasi:** sesi ini (Modul 1) berjalan PARALEL dengan task lain yang meng-upgrade Next.js 14→16 di folder yang sama (bukan worktree terisolasi, repo ini masih belum `git init`). Kedua pekerjaan sudah dicek kompatibel (`typecheck`+`build` lolos bersamaan), tapi kalau ada task background lain berjalan di direktori ini lagi, cek dulu state file sebelum menimpa — tidak ada git buat rollback.

**✅ Tahap 3, 4, 5 — SEMUA 14 modul (12 modul PRD, Modul 8 pecah 3 sub-form) selesai di-*build*, `ready:true`, `npm run typecheck` + `npm run build` lolos.** Ini **belum** UAT — lihat tabel tingkat keyakinan di bawah sebelum go-live.

### Modul yang dibangun sesi ini (setelah Modul 1)

| Modul | Handler | Target | Fitur khusus |
|---|---|---|---|
| 2 — Pembayaran Sewa | `pembayaran-sewa.ts` | Input Sewa Dimuka A:F | Anti bayar-2× (cek overlap periode), `warning` non-blokir jika nominal ≠ harga×bulan, trigger Apps Script invoice (best-effort, gagal tidak batalkan pencatatan) |
| 5 — Pengeluaran | `pengeluaran.ts` | Transaksi A:F | Kategori Pengeluaran = pilih langsung dari 125 Daftar Akun (bukan mapping kategori-ramah-user seperti PRD ideal — lihat catatan §Kategori di bawah) |
| 7 — Survey | `survey.ts` | Log Survey A:M | Header PRD bilang "sesuai eksisting" → confidence lebih tinggi |
| 3 — Pindah Kamar | `pindah-kamar.ts` | Log Pindah Kamar A:K (sheet baru) | Update status Kamar Lama→Kosong & Kamar Baru→Terisi otomatis, `warning` selisih harga |
| 4 — Checkout | `checkout.ts` | Log Checkout A:J (sheet baru) | Update status kamar→Kosong; status penghuni→Non-aktif TIDAK ditulis (Database Penghuni read-only, diasumsikan formula otomatis dari baris checkout — **verifikasi asumsi ini saat UAT**) |
| 9 — Perawatan Preventif | `perawatan-preventif.ts` | Log Perawatan Preventif D:P | ⚠️ posisi kolom tebakan |
| 11 — Perbaikan Korektif | `perbaikan-korektif.ts` | Log Perbaikan Korektif E:R | ⚠️ posisi kolom tebakan |
| 12 — Inspeksi Fasilitas | `inspeksi-fasilitas.ts` | Log Inspeksi Harian B:H | ⚠️ posisi kolom tebakan |
| 6 — Feedback | `feedback.ts` | Logbook Feedback, sheet ditebak "Logbook" A:G | ⚠️ nama sheet DAN kolom tebakan (PRD: "diverifikasi saat build") |
| 10 — Inspeksi Kebersihan | `inspeksi-kebersihan.ts` | Logbook Inspeksi Kebersihan, sheet ditebak "Logbook" A:F | ⚠️ sama seperti Modul 6 |
| 8a/b/c — Leads/Konten/Promosi | `leads.ts`/`konten.ts`/`promosi.ts` | 3 sheet baru di Logbook Kerja Marketing | Kontrak kolom didefinisikan app (sheet belum ada) — confidence tinggi utk header, tapi field SETTING dropdown (Kanal/Platform/dst) nebak sheet "SETTING" ada di file ini |

### Infrastruktur baru yang menopang semua modul di atas
- `src/lib/sheets.ts`: `readTableWithRowNum()` (readTable + nomor baris asli, dipakai update status kamar).
- `src/lib/master.ts`: `updateRoomStatus(roomId, status)` (cari baris kamar via header match, `updateRange` sel Status, invalidasi cache `master:rooms`); dropdown SETTING generik — `type` API master bisa berupa `"setting:<SHEETS_KEY>:<namaSheet>:<namaKolom>"` (mis. `setting:LOG_SALES:SETTING:Dari Mana`) tanpa perlu fungsi baru per dropdown; `label` ditambahkan ke `Room`/`Account`/`Tenant` utk teks dropdown siap-pakai.
- `src/lib/modules/handlers/helpers.ts`: `createAppendHandler(config)` — factory utk modul append-only sederhana (assertHeaders+appendRow+return), dipakai 9 dari 13 handler baru.
- `src/lib/modules/types.ts`: `SubmitResult.warning?` — peringatan non-blokir setelah submit sukses (dipakai Modul 2, 3, 4); `FieldType` tambah `'time'`.
- `src/components/DynamicForm.tsx`: render `warning` setelah sukses; fetch master di-`encodeURIComponent` (perlu krn key setting bisa berisi spasi/titik dua).

### ✅✅✅ 8 Juli (sesi lanjutan): GOOGLE_PRIVATE_KEY DIPERBAIKI — akses live ke Sheets berhasil, banyak struktur terverifikasi nyata

User memperbaiki `GOOGLE_PRIVATE_KEY` (paste sebelumnya salah taruh di baris komentar, bukan value — sudah dibetulkan, key sekarang valid & bisa connect). Ini membuka jendela langka: app benar-benar terhubung ke spreadsheet produksi. Dipakai untuk verifikasi read-only (TIDAK ada submit/write test dilakukan ke sheet produksi — sengaja dihindari) terhadap banyak `EXPECTED_HEADERS`/kolom yang sebelumnya tebakan. Hasil:

**Dikonfirmasi & DIPERBAIKI (sebelumnya salah):**
- **Daftar Kamar & Harga**: header asli pakai "Bln" bukan "Bulan" utk kolom 3/6/9 bulan (`Harga/3 Bln\n(Rp)` dst, dgn newline literal di dalam sel) — `findHeader` di `getRooms()` diperbaiki. Kolom lain yg baru diketahui ada: `Lantai`, `Fasilitas Termasuk`, `Catatan` (belum dipakai app).
- **No. Kamar kolom masih berisi "KTD-1" dkk di sebagian baris** (data lama, persis seperti yang PRD §13 flag) — `normalizeRoomId()` dikembalikan toleran menerima prefix "KTD-" sbg INPUT (matching original Cowork code), tapi tetap OUTPUT angka polos. Kamar 1-27, 29, 30 terverifikasi ada (28 hilang) — ⚠️ **user sebelumnya bilang kamar 28 DAN 30 hilang, tapi data live menunjukkan kamar 30 ADA** (Comfy AC, Terisi). Perlu klarifikasi/double-check ke user.
- **Database Penghuni → DATA**: kolom ID penghuni cuma bernama **"ID"** (bukan "ID Penghuni") — `getActiveTenants()` diperbaiki. Kolom lain: "No Kamar" (tanpa titik), "Nama Lengkap", "No HP Penghuni", "Status" — semua sudah benar berkat fallback candidate yg longgar. Format `Tenant.id` terverifikasi PERSIS "KTD-1", "KTD-2" dst — mengonfirmasi 100% koreksi user soal KTD-x = ID Penghuni.
- **Daftar Akun**: kolom "Kode" TERNYATA ADA (mis. "1101" utk Uang Kas) — kontradiksi dgn tabel yg user kirim (yg cuma tampilkan Nama+Tipe), tapi `getAccounts()` sudah dibuat toleran (kolom Kode/Saldo Normal opsional) jadi tidak masalah baik ada maupun tidak. 122 akun terverifikasi, distribusi Tipe PERSIS cocok dgn 8 opsi `tipeAkun` di registry (Aset 76, Kontra Aset 4, Liabilitas 6, Ekuitas 2, Kontra Ekuitas 1, Pendapatan 4, Beban 25, Beban Non-Operasional 4).
- **Pengaturan (KasList)**: ⚠️ BUKAN sheet tabel dgn header baris 1 seperti sheet SETTING lain — ini sheet **key-value** (Nama Usaha/Tahun/Bulan di kolom A-B), dan KasList adalah daftar nilai di **kolom D mulai baris 3** (D2 cuma label "Daftar Akun Kas/Bank (KasList):"). `getKasList()` ditulis ulang total, baca `readRange` langsung bukan `readTable`/`findHeader`. Terverifikasi 4 nilai persis sesuai PRD: Uang Kas, Aset Bank, Rekening Ops, Rekening Profit.
- **Log Booking (Modul 1)**: header asli **A:M (13 kolom, BUKAN B:N)** — `No. Booking, Tanggal Booking, Nama Penyewa, No. HP, Kamar, Tgl Masuk, Durasi (bulan), Tgl Keluar (Est.), Harga Disepakati (Rp), Status Booking, Alasan Cancel, Sumber Leads, Catatan`. **TIDAK ADA kolom Upload KTP/Kontrak** (dihapus dari kode — link file kalau nanti dibangun harusnya masuk ke kolom Catatan per PRD §7, bukan kolom sendiri) tapi ADA kolom **"Alasan Cancel"** (posisi K, antara Status Booking & Sumber Leads) yg sebelumnya tidak diketahui sama sekali — sudah ditambahkan (kosong saat create, diisi manual kalau booking dibatalkan). Range diperbaiki ke B:M (12 kolom).
- **Log Survey (Modul 7)**: 2 kolom pakai spasi di sekitar garis miring — `"Feedback / Kesan"`, `"Keberatan / Kendala"` (bukan `Feedback/Kesan` tanpa spasi seperti tebakan awal). Selebihnya PERSIS cocok.
- **Input Sewa Dimuka (Modul 2)**: kolom `"Unit / Penyewa"` pakai spasi (bukan `Unit/Penyewa`). Selebihnya PERSIS cocok.
- **Transaksi (Modul 5)**: PERSIS cocok 100% dgn tebakan awal, tidak ada perubahan.
- **LOG_SALES → SETTING**: semua 6 dropdown (`Status Booking`, `Sumber Leads`, `Dari Mana`, `Hasil Survey`, `Tindak Lanjut`, `PIC`) terverifikasi WORKING dgn data asli & masuk akal (mis. Status Booking: Pending/Konfirmasi/Check-In/Check-Out/Dibatalkan; PIC: A/B/C). Modul 1 & 7 sekarang **confidence TINGGI**, bukan lagi tebakan.

**Belum diverifikasi sesi ini** (masih tebakan, prioritas berikutnya kalau ada kesempatan live lagi): Log Laporan Inspeksi Perawatan Perbaikan (posisi kolom Modul 9/11/12 — SETTING sheet-nya sudah dikonfirmasi user via screenshot sebelumnya, tapi kolom TARGET tulis D:P/E:R/B:H belum), Logbook Feedback, Logbook Inspeksi Kebersihan, Log Marketing (3 sheet baru belum dibuat jadi belum bisa dicek).

### ⚠️ Tingkat keyakinan struktur sheet per modul (URUTKAN prioritas verifikasi saat UAT)

1. **Terverifikasi live (confidence tertinggi)** — Modul 1, 2, 5, 7 (lihat di atas — header sudah dicocokkan langsung ke sheet asli 8 Jul, bukan tebakan lagi).
2. **Tinggi (by design)** — Modul 3/4/8a/8b/8c: sheet BARU, app yang definisikan kontraknya, header belum dibuat user jadi belum bisa dicek — tapi begitu dibuat sesuai spesifikasi ini seharusnya langsung cocok.
3. **Sedang** — Modul 9, 11, 12: teks kolom SETTING sudah dikonfirmasi (lihat bagian "Dropdown SETTING dipisah per sub-modul"), tapi posisi kolom TARGET TULIS (Log Perawatan Preventif D:P, Log Perbaikan Korektif E:R, Log Inspeksi Harian B:H) masih tebakan posisi.
4. **Rendah** — Modul 6, 10: PRD eksplisit bilang "header diverifikasi saat build" (belum sempat) — nama SHEET (ditebak "Logbook") dan semua kolom perlu dicek dari nol.

Semua kasus di atas AMAN secara data (assertHeaders menolak submit dgn pesan jelas kalau header tak cocok — tidak akan menulis ke kolom salah), tapi modul akan **non-fungsional** sampai teks di `EXPECTED_HEADERS` (tiap file `handlers/<id>.ts`) disesuaikan ke sheet asli. Cara verifikasi tercepat: coba submit form modul terkait, baca pesan error assertHeaders (menampilkan header aktual sheet), copy-paste ke `EXPECTED_HEADERS`. ⚠️ Semua verifikasi live sesi ini dilakukan lewat `/api/master/*` (read-only) dan skrip diagnostik terpisah yang baca header saja — **TIDAK PERNAH submit/tulis data test ke sheet produksi**, supaya tidak mengotori data asli.

### ✅ 8 Juli: Self-registration via Google + approval Owner (dibangun, DIVERIFIKASI ujung-ke-ujung kecuali OAuth handshake sungguhan)

User eksplisit minta ini sebagai **peningkatan dari PRD** (PRD asli §5 bilang "Tidak ada self-registration" — sudah dioverride oleh keputusan user 8 Jul). Dibangun TANPA menambah library auth baru (tidak pakai NextAuth) — reuse JWT (`jose`) + session cookie + Redis yang sudah ada, supaya konsisten dgn arsitektur eksisting.

**Alur:** User klik "Daftar / Masuk dengan Google" di halaman login → redirect ke Google consent screen → callback tukar `code` jadi `id_token` (diverifikasi via JWKS resmi Google, BUKAN percaya begitu saja) → cari/buat user by email (username = email) → kalau baru/masih pending → redirect ke `/pending` (TANPA cookie sesi — belum bisa akses apapun) → Owner buka `/admin/users`, approve + pilih role → user login lagi via Google → sekarang dapat sesi penuh.

**File baru:**
- `src/lib/google-oauth.ts` — `buildGoogleAuthUrl`, `exchangeGoogleCode`, `verifyGoogleIdToken` (pakai `jose` `createRemoteJWKSet` thd `https://www.googleapis.com/oauth2/v3/certs`, cek issuer+audience).
- `src/app/api/auth/google/login/route.ts` — redirect ke Google, state CSRF disimpan di cookie sementara 10 menit.
- `src/app/api/auth/google/callback/route.ts` — tukar code, verifikasi state, cari/buat user, redirect sesuai status.
- `src/app/pending/page.tsx` — halaman statis "menunggu approval".
- `src/app/admin/users/page.tsx` + `src/components/UserAdminPanel.tsx` — daftar Pending/Aktif/Nonaktif, tombol Approve (+pilih role)/ubah role/Nonaktifkan/Aktifkan lagi. Owner-only (cek `user.role === 'owner'` langsung, bukan lewat `canAccess` krn ini bukan modul registry).
- `src/app/api/admin/users/route.ts` (GET list) + `approve|role|deactivate|reactivate/route.ts` (POST) — semua Owner-gated.

**File diubah:**
- `src/lib/auth.ts` — `StoredUser` diperluas: `status` (`pending`/`active`/`disabled`), `authProvider` (`password`/`google`), `email`, `googleId`, `createdAt`; `passwordHash`/`role` jadi opsional/nullable. Ada `normalizeStoredUser()` supaya user lama (seed sebelum perubahan ini, tanpa field `status`) tetap kebaca benar (dianggap `active` kalau `active !== false`) — TIDAK perlu migrasi data manual. Fungsi baru: `findOrCreateGoogleUser`, `listAllUsers` (pakai `redis.keys()`, aman utk skala puluhan user), `approveUser`, `setUserRole`, `deactivateUser`, `reactivateUser`.
- `scripts/seed-user.mjs` — set `status:'active'`, `authProvider:'password'` eksplisit.
- `src/proxy.ts` — tambah `/api/auth/google`, `/pending` ke PUBLIC_PATHS.
- `src/app/login/page.tsx` — tombol Google + tampilkan `?error=` dari callback; harus dibungkus `<Suspense>` krn pakai `useSearchParams` (build gagal tanpa ini, sudah diperbaiki).
- `src/app/page.tsx` — link "👤 Kelola User" muncul cuma utk role owner.
- `.env.example` + `.env.local` — tambah `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `APP_BASE_URL`.

**Diverifikasi 8 Jul (live, via browser + API, lalu dibersihkan):**
- `typecheck` + `build` lolos (termasuk fix Suspense boundary di /login).
- Login `administrator` tetap jalan normal (backward compat dgn user lama terbukti).
- `/admin/users` menampilkan user aktif dgn benar (role dropdown, "(kamu)" utk diri sendiri, tombol Nonaktifkan disembunyikan utk diri sendiri).
- Dibuat 1 user pending SIMULASI langsung di Redis (bukan lewat OAuth sungguhan, krn belum ada credential Google OAuth) → muncul benar di "Menunggu Persetujuan" → di-approve dgn role `staff_admin` via tombol Approve sungguhan di UI → pindah ke "User Aktif" dgn role benar → di-nonaktifkan via tombol → pindah ke "Dinonaktifkan" dgn tombol "Aktifkan lagi". Semua lewat UI+API asli, bukan simulasi. User test dihapus total dari Redis setelah verifikasi (tidak ada sisa data test).
- **BELUM diverifikasi: handshake OAuth Google sungguhan** (redirect ke accounts.google.com, tukar code, verifikasi id_token) — perlu `GOOGLE_OAUTH_CLIENT_ID`/`GOOGLE_OAUTH_CLIENT_SECRET` asli dari Google Cloud Console (OAuth client, BEDA dari Service Account Sheets/Drive). Sampai diisi, tombol "Daftar/Masuk dengan Google" akan gagal saat diklik.

**Setup yang masih perlu user:**
1. Google Cloud Console → APIs & Services → Credentials → **Create OAuth client ID** → Web application → Authorized redirect URI: `{APP_BASE_URL}/api/auth/google/callback` (mis. `http://localhost:3000/api/auth/google/callback` utk dev, domain asli utk prod).
2. Isi `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `APP_BASE_URL` di `.env.local` (dan Vercel env vars saat deploy).
3. Setelah itu tes end-to-end: klik tombol Google di /login, pastikan redirect ke consent screen Google sungguhan, lanjut ke /pending, lalu approve via /admin/users.

### ⚠️ Koreksi 8 Juli: Modul 8 salah target spreadsheet (sudah diperbaiki)
`leads.ts`/`konten.ts`/`promosi.ts` semula menulis ke `SHEETS.LOGBOOK_MARKETING` (`1RIfdj7...`) — user mengoreksi: file itu sebenarnya untuk staff input kegiatan kerja harian, BUKAN data leads/konten/promosi. Target benar adalah spreadsheet baru **Log Marketing** (`1fZ4DHZx8uasta5mfttWhQhfrPOpprb8VrpEPFUGI2FE`), sudah ditambahkan sebagai `SHEETS.LOG_MARKETING` di `config/spreadsheets.ts` dan ketiga handler + field SETTING dropdown terkait (Kanal/Platform/Jenis Konten/Status Konten/Status Promosi/PIC di `registry.ts`) sudah dialihkan ke sana. `typecheck` lolos.

**Belum diputuskan:** apakah "Logbook Kerja Marketing" (staff input kegiatan kerja harian) perlu modul baru sendiri — ini BUKAN bagian dari 12 modul asli PRD. Belum ada field spec, target sheet/kolom, atau keputusan PO soal ini. Tanyakan ke user sebelum membangun kalau muncul lagi di sesi depan.

### Dropdown SETTING dipisah per sub-modul (8 Juli)
User minta dropdown Kanal/Kategori/dst tidak boleh berbagi kolom SETTING antar sub-modul dalam 1 spreadsheet — masing-masing harus independen:
- **Log Marketing** (Modul 8): `Kanal Leads` (Leads), `Platform`/`Jenis Konten`/`Status Konten` (Konten), `Kanal Promosi`/`Status Promosi` (Promosi) — sebelumnya Leads & Promosi berbagi kolom "Kanal".
- **Log Laporan Inspeksi Perawatan Perbaikan** (Modul 9/11/12) — awalnya dipisah semua (`Kategori Preventif`/`Penyebab Preventif`/dst per modul), TAPI user lalu kirim screenshot struktur SETTING sheet asli (8 Jul) yang menunjukkan struktur SEBENARNYA:
  `Jenis Perawatan | Kategori Inspeksi | Tindak Lanjut | Kategori Preventif | Sumber Laporan Korektif | kategori korektif | Penyebab | Prioritas | Status | Area | PIC`
  Jadi dikoreksi lagi mengikuti struktur nyata ini: `Penyebab`/`Prioritas`/`Status`/`PIC` ternyata memang SATU kolom dipakai bersama Modul 9 & 11 (bukan salah — itu strukturnya), sedangkan `Kategori Preventif` (Modul 9) / `kategori korektif` (Modul 11, huruf kecil) / `Kategori Inspeksi` (Modul 12) tetap masing-masing kolom sendiri. `Tindak Lanjut` (Modul 12, field "Tindak Lanjut Diperlukan?") diubah dari hardcoded Ya/Tidak jadi select-async — nilai asli 3 opsi: "Tidak", "Ya, Perbaikan", "Ya, jadwalkan Perawatan". Modul 9 "Pelaksana" & Modul 12 "Petugas" dipetakan ke kolom "PIC" (tidak ada kolom Pelaksana/Petugas terpisah di sheet asli); Modul 11 "Pelaksana" ikut diupgrade dari text biasa jadi dropdown PIC juga (opsional).

⚠️ Pelajaran: JANGAN asumsikan semua dropdown harus dipisah per modul hanya karena nama field sama — kadang memang satu kolom SETTING dipakai bersama beberapa modul by design (khususnya untuk field generik seperti Penyebab/Prioritas/Status/PIC). Base keputusan pada struktur sheet asli (screenshot/akses langsung), bukan asumsi. Sisanya (Log Sales, Log Input Transaksi, Logbook Feedback, Logbook Inspeksi Kebersihan, Log Marketing) MASIH tebakan — belum ada konfirmasi struktur asli seperti ini.

### Belum dibangun / diketahui belum lengkap
- **Upload file ke Drive** (`/api/upload`) — semua field foto/dokumen (KTP, Kontrak, Nota, bukti transfer, dsb.) sengaja TIDAK ada di form manapun; kolom terkait di-tulis string kosong. Perlu: endpoint upload (maks 10MB, folder per PRD §7), lalu tambah field `type:'file'` ke registry modul terkait + field link di buildRow handler.
- **Update Generator Tagihan** (Modul 2 langkah 4 PRD) — tidak diimplementasi, struktur sheet tidak diverifikasi. Saat ini hanya baris Input Sewa Dimuka yang ditulis + trigger Apps Script; Generator Tagihan harus di-update manual atau diverifikasi strukturnya dulu.
- **Kategori Pengeluaran ramah-user → Akun Debit** (Modul 5): PRD minta app memetakan kategori sehari-hari ke kode akun; saat ini staff langsung pilih dari 125 akun (fungsional tapi kurang ergonomis). Perlu daftar mapping kategori↔akun dari user.
- **Kamar Ditinjau multi-select** (Modul 7): disederhanakan jadi text field "pisahkan koma" — form engine belum punya tipe multi-select.
- **"Tawarkan buat tiket Modul 9/11" saat Inspeksi kondisi buruk** (Modul 4/12): tidak diimplementasi (UX prompt lintas-modul, bukan scope backend).
- **Prefix `miniapp:` di Redis key** — belum diimplementasi (lihat §Keputusan PO poin 5), masih perlu konfirmasi user apakah Upstash database dipakai bersama dashboard lain.
- **UAT & data cleansing PRD §13** — belum dilakukan (butuh kredensial live + salinan spreadsheet test).

Detail validasi per modul (aturan double-occupancy, anti bayar 2×, warning tunggakan checkout, dsb.) semuanya di PRD §6 & §10.

## ⚠️ PENTING: keamanan env

**✅ Sudah diperbaiki (7 Jul, sesi Tahap 2):** nilai nyata dipindah ke `.env.local` (di-.gitignore, belum pernah ter-commit — repo ini belum `git init`), `.env.example` dikembalikan jadi placeholder kosong.

**✅ GOOGLE_PRIVATE_KEY sudah BENAR (diperbaiki user 8 Jul).** Sempat ada insiden kedua: waktu user coba tempel key asli, isinya kepencet masuk ke BARIS KOMENTAR (bukan ke value `GOOGLE_PRIVATE_KEY=`), dan juga hilang marker `-----BEGIN/END PRIVATE KEY-----`-nya. Sudah direkonstruksi & diverifikasi BENAR-BENAR JALAN (app berhasil connect ke Google Sheets live, lihat bagian "GOOGLE_PRIVATE_KEY DIPERBAIKI" di §Progress). Kalau di sesi depan koneksi Google tiba-tiba gagal lagi dgn error `DECODER routines::unsupported`, cek dulu apakah `.env.local` masih utuh (satu baris, ada `-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n`) sebelum curiga ke hal lain.

Sisa PR keamanan: token Upstash & JWT secret sempat tertulis di file yang lazim di-commit (`.env.example`, sudah dibersihkan) — sebaiknya **rotasi keduanya** sebelum repo ini di-share/di-push ke remote manapun.

## Setup yang masih harus dilakukan user

Lihat `miniapp-kost/README.md`: share spreadsheet ke service account (Editor; Database Penghuni cukup Viewer — **belum dikonfirmasi sudah di-share atau belum, tapi koneksi ke Log Sales & Log Input Transaksi sudah terbukti jalan 8 Jul**), buat 3 spreadsheet baru (Audit Log, Log Pindah Kamar, Log Checkout — **ID sudah diisi user di env, tapi header sheet-nya sendiri belum dikonfirmasi sudah dibuat/belum**) + 3 sheet baru di **Log Marketing** (BUKAN Logbook Kerja Marketing — lihat koreksi di bawah) dgn header persis sesuai tabel di §Progress, deploy Apps Script Invoice sebagai Web App + token (**URL & token sudah diisi user di env, belum diverifikasi bisa dipanggil eksternal**), isi folder ID Drive (**sudah diisi user**), seed akun user (**akun pertama `administrator` sudah dibuat**), data cleansing PRD §13.

**Belum dijalankan sesi ini (sengaja, butuh keputusan/akses user):**
- `node scripts/seed-user.mjs` — tidak dijalankan otomatis krn akan menulis user sungguhan ke Upstash Redis yang **dipakai bersama dashboard internal lain**; jalankan manual setelah keputusan prefix `miniapp:` (§Keputusan PO poin 5) final.
- Login/E2E browser test — tidak bisa dilakukan tanpa user Redis nyata (lihat poin di atas) dan `GOOGLE_PRIVATE_KEY` yang valid; setelah kedua hal itu beres, jalankan `npm run dev` lalu login dan coba tiap modul satu-satu, catat error `assertHeaders` (kalau ada) dan sesuaikan `EXPECTED_HEADERS` di handler terkait.
