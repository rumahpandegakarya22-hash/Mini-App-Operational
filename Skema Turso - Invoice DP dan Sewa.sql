-- ============================================================================
-- Skema Turso: invoice_dp & invoice_sewa
-- Sumber:
--   1. Spreadsheet Invoice DP   (1iX_5LtIpTBwnwB4-krUe_GlvIfef9MtqWfadDsosnzo, gid=0)
--   2. Spreadsheet Invoice Sewa (10QJeO3j6mFqXJNS_4763z6Ct6-4HP6LGNP_gq4Ovyaw, gid=0)
--
-- STATUS: sudah dieksekusi ke Turso (2026-07-16). File ini adalah dokumentasi
-- final yang cocok dengan state database saat ini — bukan lagi draft.
-- invoice_dp = 29 baris, invoice_sewa = 31 baris, FK bersih (foreign_key_check = 0).
--
-- Konvensi ngikutin tabel existing (occupancy_history, payment) &
-- "Skema Turso - Migrasi Manual.md":
--   - Uang           : INTEGER rupiah utuh ("Rp850.000" -> 850000)
--   - Tanggal        : TEXT 'YYYY-MM-DD' ("30 Mei 2026" -> '2026-05-30')
--   - Checkbox sheet : INTEGER 0/1 (kolom "Check" -> `checked`)
--   - PK             : INTEGER AUTOINCREMENT (log invoice, gak ada tabel lain
--                      yang nge-FK ke sini — kelasnya sama kayak daily_tasks)
--   - id_penghuni    : FK ke occupancy_history(id_penghuni), NULLABLE di kedua
--                      tabel — dibackfill lewat UPDATE terpisah, BUKAN diisi
--                      langsung dari sheet
--
-- PENTING — pelajaran dari percobaan pertama (jangan diulang):
--   Kolom "id" di sheet Invoice DP (KTD-1, KTD-2, ...) BUKAN id_penghuni asli.
--   Format id_penghuni asli di occupancy_history adalah KTD-YYMM-NNN
--   (mis. KTD-2604-001). Insert langsung pakai kolom "id" sheet sebagai FK
--   akan gagal SQLITE_CONSTRAINT (foreign key). Solusinya: insert dengan
--   id_penghuni NULL dulu, lalu UPDATE ... SET id_penghuni = (SELECT ...
--   WHERE TRIM(nama) = TRIM(nama)) — persis pola yang dipakai invoice_sewa.
--
-- Konversi data yang dilakukan:
--   - No Inv berakhiran "/12/1899" = tanggal pembayaran kosong di sheet
--     (epoch zero Google Sheets). No Inv dibiarkan apa adanya, tanggal -> NULL.
--   - Sel kosong -> NULL; sel "Rp0" / "0" eksplisit -> 0.
--   - Nama dengan spasi buntut di sheet sudah di-TRIM.
--
-- Anomali data yang ditemukan & cara ditangani:
--   - "Anindya Farah" (INV/18/DPU & INV/18/TDU, no_kamar 18): TIDAK ADA sama
--     sekali di occupancy_history — kamar 18 gak pernah tercatat sebagai
--     riwayat penghuni. id_penghuni dibiarkan NULL di kedua tabel. Kalau
--     penghuni ini memang pernah check-in, datanya perlu ditambahkan dulu ke
--     occupancy_history baru di-link manual.
--   - "Dina Riva" (INV/31/DPU, no_kamar 31): nama di sheet gak persis sama
--     dengan occupancy_history ("Dini Ariva", KTD-2607-004) — kemungkinan
--     typo, tapi no_kamar & status Check-in cocok. Di-link manual ke
--     KTD-2607-004 (dikonfirmasi user).
-- ============================================================================


-- ============================================================================
-- 1. TABEL invoice_dp  (sheet Invoice DP, No Inv format INV/x/DPU/bln/thn)
--    UNIQUE(no_inv): di data DP satu invoice per penghuni, aman di-unique-kan.
-- ============================================================================

CREATE TABLE invoice_dp (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  no_inv              TEXT NOT NULL UNIQUE,
  id_penghuni         TEXT REFERENCES occupancy_history(id_penghuni), -- nullable, dibackfill (lihat bag. 4)
  nama                TEXT NOT NULL,              -- snapshot, sama pola kayak payment
  email               TEXT,
  tanggal_pembayaran  TEXT,                       -- 'YYYY-MM-DD', NULL = belum bayar
  no_kamar            TEXT NOT NULL,              -- TEXT, konsisten dgn occupancy_history.no_kamar
  tipe_kamar          TEXT,                       -- Eco / Classic / Comfy (tanpa CHECK, ngikutin kamar.tipe_kamar)
  jumlah              INTEGER DEFAULT 1,          -- qty item invoice (di sheet selalu 1)
  harga_kamar         INTEGER,                    -- harga penuh kamar per bulan
  subtotal            INTEGER,
  pajak               INTEGER,
  diskon              INTEGER,
  grand_total         INTEGER NOT NULL,           -- nominal DP yang ditagih
  checked             INTEGER NOT NULL DEFAULT 0, -- 0/1, kolom checkbox "Check" di sheet
  created_at          TEXT DEFAULT (CURRENT_TIMESTAMP)
);

CREATE INDEX idx_invoice_dp_penghuni ON invoice_dp(id_penghuni);


-- ============================================================================
-- 2. TABEL invoice_sewa  (sheet Invoice Sewa, No Inv format INV/x/TDU/bln/thn)
--    no_inv SENGAJA TIDAK unique: di sheet asli, invoice yang di-generate ulang
--    memakai nomor yang sama utk periode berbeda (kasus INV/31/TDU/7/2026:
--    satu versi 3 bulan + dua versi 1 bulan, ketiganya baris valid berbeda).
-- ============================================================================

CREATE TABLE invoice_sewa (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  no_inv              TEXT NOT NULL,
  id_penghuni         TEXT REFERENCES occupancy_history(id_penghuni), -- nullable, dibackfill (lihat bag. 4)
  nama                TEXT NOT NULL,
  email               TEXT,
  tanggal_pembayaran  TEXT,                       -- 'YYYY-MM-DD', NULL = belum bayar
  periode_awal        TEXT,                       -- 'YYYY-MM-DD'
  periode_akhir       TEXT,                       -- 'YYYY-MM-DD'
  no_kamar            TEXT NOT NULL,
  jumlah_bulan        INTEGER,                    -- kolom "Jumlah" di sheet = jumlah bulan sewa
  jumlah_denda        INTEGER,                    -- kolom "Jumlah Denda" = qty denda
  harga_sewa          INTEGER,                    -- kolom "Sewa" = tarif per bulan
  tambahan_listrik    INTEGER,                    -- tarif listrik per bulan
  denda               INTEGER,                    -- tarif denda per unit
  total_sewa          INTEGER,                    -- harga_sewa x jumlah_bulan
  total_listrik       INTEGER,                    -- tambahan_listrik x jumlah_bulan
  total_denda         INTEGER,                    -- denda x jumlah_denda
  diskon              INTEGER,
  pajak               INTEGER,
  subtotal            INTEGER,
  grand_total         INTEGER,                    -- total_sewa + total_listrik + total_denda - diskon + pajak
  tipe_kamar          TEXT,
  checked             INTEGER NOT NULL DEFAULT 0, -- 0/1, kolom checkbox "Check" di sheet
  created_at          TEXT DEFAULT (CURRENT_TIMESTAMP)
);

CREATE INDEX idx_invoice_sewa_no_inv   ON invoice_sewa(no_inv);
CREATE INDEX idx_invoice_sewa_penghuni ON invoice_sewa(id_penghuni);


-- ============================================================================
-- 3. SEED DATA invoice_dp (29 baris; id_penghuni sengaja NULL, diisi bag. 4)
--    Catatan: baris no_kamar 31 di sheet DP no_inv-nya tertulis "TDU" (bukan
--    DPU) dan namanya "Dina Riva" — dibiarkan verbatim sesuai sheet, id-nya
--    dibackfill manual ke KTD-2607-004 (Dini Ariva) di bagian 4.
-- ============================================================================

INSERT INTO invoice_dp
  (no_inv, nama, email, tanggal_pembayaran, no_kamar, tipe_kamar, jumlah, harga_kamar, subtotal, pajak, diskon, grand_total, checked)
VALUES
  ('INV/1/DPU/12/1899',  'Syifa Zuhro Alwana',                'syifazuhro07@gmail.com',                NULL,         '1',  'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/2/DPU/12/1899',  'Delinda Vivia Angela',              'delindavva@gmail.com',                  NULL,         '2',  'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/3/DPU/12/1899',  'Putri Hazna Nabilla',               'putrihazn61@gmail.com',                 NULL,         '3',  'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/4/DPU/12/1899',  'Grisella Aurelia Disanda',          'aureliadisanda@gmail.com',              NULL,         '4',  'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/5/DPU/12/1899',  'Khalisa Ardhi Dhayinta',            'lisadhayinta@gmail.com',                NULL,         '5',  'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/6/DPU/12/1899',  'Fika Zahra Fauziah',                'fikazahraf@gmail.com',                  NULL,         '6',  'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/7/DPU/12/1899',  'Nathania Keiza Yusivana Nugraheni', 'nathaniakeiza06@gmail.com',             NULL,         '7',  'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/8/DPU/12/1899',  'Christya Dewi Anugraheni',          'christyadewianugraheni@mail.ugm.ac.id', NULL,         '8',  'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/9/DPU/12/1899',  'Nurul Rizki Isnaeni',               'isnaeninurulrizki@gmail.com',           NULL,         '9',  'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/10/DPU/12/1899', 'Sukma Tri Wahyuningrum',            'sukmawahyuningrum3@gmail.com',          NULL,         '10', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/11/DPU/12/1899', 'Mutiara Balqis Aqidatulizah',       'baalqismutiara@gmail.com',              NULL,         '11', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/12/DPU/12/1899', 'Dewi Anisa Tsany Kurniadi',         'dewiaanisatsy@gmail.com',               NULL,         '12', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/13/DPU/12/1899', 'Fadhila Rahmah Wijaya',             'fadhlaw1574@gmail.com',                 NULL,         '13', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/14/DPU/12/1899', 'Nisrina Nadhira',                   'nisrinadhira2580@gmail.com',            NULL,         '14', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/15/DPU/12/1899', 'Rheina Meuthia Ashari',             'rheinameuthiaa@gmail.com',              NULL,         '15', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/16/DPU/12/1899', 'Isna Laela Ramadani',               'isnaramadani596@gmail.com',             NULL,         '16', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/17/DPU/12/1899', 'Raudina Yasmine',                   'raudinayasmine2@gmail.com',             NULL,         '17', 'Classic', 1, 1200000, 600000, NULL, NULL, 600000, 0),
  ('INV/18/DPU/12/1899', 'Anindya Farah',                     'fadhilariansyah10@gmail.com',           NULL,         '18', 'Classic', 1, 1200000, 600000, NULL, NULL, 600000, 0),
  ('INV/19/DPU/12/1899', 'Bunga Aya Lalangsa',                'bungaayalalangsa@gmail.com',            NULL,         '19', 'Classic', 1, 1200000, 600000, NULL, NULL, 600000, 0),
  ('INV/20/DPU/12/1899', 'Nadya Zhafira Cahya Putri',         'nadyazhafira32@gmail.com',              NULL,         '20', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/21/DPU/5/2026',  'Nafisah Khairul Syifa',             'nafisahkhairull@gmail.com',             '2026-05-27', '21', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/22/DPU/12/1899', 'Yumna Putri Damayanti',             'yumna8261@gmail.com',                   NULL,         '22', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/23/DPU/12/1899', 'Najwa Athaya',                      'fadhilariansyah10@gmail.com',           NULL,         '23', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/24/DPU/12/1899', 'Jessica Putri Masyayu',             'jesicatrimas@gmail.com',                NULL,         '24', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/25/DPU/12/1899', 'Ulum Orizhasativa Widianti',        'tifapulum@gmail.com',                   NULL,         '25', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/26/DPU/12/1899', 'Qonita Rahma Farahdila',            'qonitarahmafarahdila@gmail.com',        NULL,         '26', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/27/DPU/12/1899', 'Talitha Palupi Putri Anindita',     'talithapalupi1805@gmail.com',           NULL,         '27', 'Eco',     1, 800000,  400000, NULL, NULL, 400000, 0),
  ('INV/29/DPU/5/2026',  'Tiffani Budiarjo',                  'fanenocent@gmail.com',                  '2026-05-21', '29', 'Comfy',   1, 1600000, 800000, NULL, NULL, 800000, 0),
  ('INV/31/TDU/6/2026',  'Dina Riva',                         'fadhilariansyah10@gmail.com',           '2026-06-21', '31', 'Comfy',   1, 1600000, 800000, NULL, NULL, 800000, 1);


-- ============================================================================
-- 4. SEED DATA invoice_sewa (31 baris setelah dibersihkan dari 37 baris sheet)
--    Pembersihan:
--    - 5 baris INV/31/TDU/7/2026 yang identik persis -> 1 baris.
--    - Baris INV/31/TDU/6/2026 (Najwa Fauzia, semua kolom #N/A) -> DILEWATI
--      total, kelihatan superseded oleh INV/31/TDU/7/2026 di bawahnya.
--    - Sisa 3 baris INV/31/TDU/7/2026 (1 versi 3-bulan + 2 versi 1-bulan beda
--      tanggal 07-01/07-03) SEMUANYA legit & disimpan — no_inv sama tapi
--      grand_total/periode beda, bukan duplikat (sudah diverifikasi manual).
-- ============================================================================

INSERT INTO invoice_sewa
  (no_inv, nama, email, tanggal_pembayaran, periode_awal, periode_akhir, no_kamar, jumlah_bulan, jumlah_denda, harga_sewa, tambahan_listrik, denda, total_sewa, total_listrik, total_denda, diskon, pajak, subtotal, grand_total, tipe_kamar, checked)
VALUES
  ('INV/1/TDU/5/2026',   'Syifa Zuhro Alwana',                'syifazuhro07@gmail.com',                '2026-05-30', '2026-05-30', '2026-06-30', '1',  1,    0,    850000,  0,     0,    850000,  NULL,   NULL, NULL, 0, 850000,  850000,  'Eco',     0),
  ('INV/2/TDU/6/2026',   'Delinda Vivia Angela',              'delindavva@gmail.com',                  '2026-06-23', '2026-06-22', '2026-09-22', '2',  3,    0,    800000,  25000, 0,    2400000, 75000,  NULL, NULL, 0, 2475000, 2475000, 'Eco',     0),
  ('INV/3/TDU/12/1899',  'Putri Hazna Nabilla',               'putrihazn61@gmail.com',                 NULL,         '2026-04-22', NULL,         '3',  NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Eco',     0),
  ('INV/4/TDU/6/2026',   'Grisella Aurelia Disanda',          'aureliadisanda@gmail.com',              '2026-06-30', '2026-06-30', '2026-09-30', '4',  3,    0,    800000,  25000, 0,    2400000, 75000,  NULL, NULL, 0, 2475000, 2475000, 'Eco',     0),
  ('INV/5/TDU/6/2026',   'Khalisa Ardhi Dhayinta',            'lisadhayinta@gmail.com',                '2026-06-07', '2026-06-06', '2026-09-06', '5',  3,    0,    800000,  25000, 0,    2400000, 75000,  NULL, NULL, 0, 2475000, 2475000, 'Eco',     0),
  ('INV/6/TDU/12/1899',  'Fika Zahra Fauziah',                'fikazahraf@gmail.com',                  NULL,         NULL,         NULL,         '6',  NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Eco',     0),
  ('INV/7/TDU/12/1899',  'Nathania Keiza Yusivana Nugraheni', 'nathaniakeiza06@gmail.com',             NULL,         NULL,         NULL,         '7',  NULL, NULL, NULL,    25000, NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Eco',     0),
  ('INV/8/TDU/12/1899',  'Christya Dewi Anugraheni',          'christyadewianugraheni@mail.ugm.ac.id', NULL,         NULL,         NULL,         '8',  NULL, NULL, NULL,    25000, NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Eco',     0),
  ('INV/9/TDU/12/1899',  'Nurul Rizki Isnaeni',               'isnaeninurulrizki@gmail.com',           NULL,         NULL,         NULL,         '9',  NULL, 0,    NULL,    25000, 0,    NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Eco',     0),
  ('INV/10/TDU/6/2026',  'Sukma Tri Wahyuningrum',            'sukmawahyuningrum3@gmail.com',          '2026-06-29', '2026-06-28', '2026-09-28', '10', 3,    0,    800000,  25000, 0,    2400000, 75000,  NULL, NULL, 0, 2475000, 2475000, 'Eco',     0),
  ('INV/11/TDU/12/1899', 'Mutiara Balqis Aqidatulizah',       'baalqismutiara@gmail.com',              NULL,         NULL,         NULL,         '11', NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Eco',     0),
  ('INV/12/TDU/5/2026',  'Dewi Anisa Tsany Kurniadi',         'dewiaanisatsy@gmail.com',               '2026-05-02', '2026-05-02', '2026-08-02', '12', 3,    NULL, 800000,  50000, 0,    2400000, 150000, NULL, NULL, 0, 2550000, 2550000, 'Eco',     0),
  ('INV/13/TDU/6/2026',  'Fadhila Rahmah Wijaya',             'fadhlaw1574@gmail.com',                 '2026-06-28', '2026-06-30', '2026-07-30', '13', 1,    0,    850000,  25000, 0,    850000,  25000,  NULL, NULL, 0, 875000,  875000,  'Eco',     0),
  ('INV/14/TDU/5/2026',  'Nisrina Nadhira',                   'nisrinadhira2580@gmail.com',            '2026-05-06', '2026-04-30', '2026-06-30', '14', 2,    0,    850000,  0,     0,    1700000, NULL,   NULL, NULL, 0, 1700000, 1700000, 'Eco',     0),
  ('INV/15/TDU/6/2026',  'Rheina Meuthia Ashari',             'rheinameuthiaa@gmail.com',              '2026-06-15', '2026-06-15', '2026-07-15', '15', 1,    0,    850000,  0,     0,    850000,  NULL,   NULL, NULL, 0, 850000,  850000,  'Eco',     0),
  ('INV/16/TDU/5/2026',  'Isna Laela Ramadani',               'isnaramadani596@gmail.com',             '2026-05-24', '2026-05-25', '2026-06-25', '16', 1,    0,    850000,  25000, 0,    850000,  25000,  NULL, NULL, 0, 875000,  875000,  'Eco',     0),
  ('INV/17/TDU/12/1899', 'Raudina Yasmine',                   'raudinayasmine2@gmail.com',             NULL,         NULL,         NULL,         '17', NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Classic', 0),
  ('INV/18/TDU/12/1899', 'Anindya Farah',                     'fadhilariansyah10@gmail.com',           NULL,         NULL,         NULL,         '18', NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Classic', 0),
  ('INV/19/TDU/12/1899', 'Bunga Aya Lalangsa',                'bungaayalalangsa@gmail.com',            NULL,         NULL,         NULL,         '19', NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Classic', 0),
  ('INV/20/TDU/12/1899', 'Nadya Zhafira Cahya Putri',         'nadyazhafira32@gmail.com',              NULL,         NULL,         NULL,         '20', NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Eco',     0),
  ('INV/21/TDU/6/2026',  'Nafisah Khairul Syifa',             'nafisahkhairull@gmail.com',             '2026-06-03', '2026-06-04', '2026-09-04', '21', 3,    0,    800000,  0,     0,    2400000, NULL,   NULL, NULL, 0, 2400000, 2400000, 'Eco',     0),
  ('INV/22/TDU/12/1899', 'Yumna Putri Damayanti',             'yumna8261@gmail.com',                   NULL,         NULL,         NULL,         '22', NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Eco',     0),
  ('INV/23/TDU/12/1899', 'Najwa Athaya',                      'fadhilariansyah10@gmail.com',           NULL,         NULL,         NULL,         '23', NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Eco',     0),
  ('INV/24/TDU/4/2026',  'Jessica Putri Masyayu',             'jesicatrimas@gmail.com',                '2026-04-14', '2026-04-15', '2026-06-15', '24', 2,    NULL, 850000,  50000, NULL, 1700000, 100000, NULL, NULL, 0, 1800000, 1800000, 'Eco',     0),
  ('INV/25/TDU/12/1899', 'Ulum Orizhasativa Widianti',        'tifapulum@gmail.com',                   NULL,         NULL,         NULL,         '25', NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Eco',     0),
  ('INV/26/TDU/6/2026',  'Qonita Rahma Farahdila',            'qonitarahmafarahdila@gmail.com',        '2026-06-29', '2026-06-29', '2026-09-29', '26', 3,    0,    800000,  25000, 0,    2400000, 75000,  NULL, NULL, 0, 2475000, 2475000, 'Eco',     0),
  ('INV/27/TDU/6/2026',  'Talitha Palupi Putri Anindita',     'talithapalupi1805@gmail.com',           '2026-06-30', '2026-06-30', '2026-09-30', '27', 3,    0,    800000,  50000, 0,    2400000, 150000, NULL, NULL, 0, 2550000, 2550000, 'Eco',     0),
  ('INV/29/TDU/12/1899', 'Tiffani Budiarjo',                  'fanenocent@gmail.com',                  NULL,         NULL,         NULL,         '29', NULL, NULL, NULL,    0,     NULL, NULL,    NULL,   NULL, NULL, 0, 0,       0,       'Comfy',   0),
  ('INV/31/TDU/7/2026',  'Najwa Fauzia',                      'freelanceariansyah@gmail.com',          '2026-07-01', '2026-07-01', '2026-10-01', '31', 3,    0,    1550000, 0,     0,    4650000, 0,      0,    0,    0, 4650000, 4650000, 'Comfy',   0),
  ('INV/31/TDU/7/2026',  'Najwa Fauzia',                      'freelanceariansyah@gmail.com',          '2026-07-01', '2026-07-01', '2026-08-01', '31', 1,    0,    1600000, 0,     0,    1600000, 0,      0,    0,    0, 1600000, 1600000, 'Comfy',   0),
  ('INV/31/TDU/7/2026',  'Najwa Fauzia',                      'freelanceariansyah@gmail.com',          '2026-07-03', '2026-07-03', '2026-08-03', '31', 1,    0,    1600000, 0,     0,    1600000, 0,      0,    0,    0, 1600000, 1600000, 'Comfy',   0);


-- ============================================================================
-- 5. BACKFILL id_penghuni (nama exact match dulu, lalu 2 fix manual)
-- ============================================================================

UPDATE invoice_dp
SET id_penghuni = (
  SELECT oh.id_penghuni FROM occupancy_history oh WHERE TRIM(oh.nama) = TRIM(invoice_dp.nama)
)
WHERE id_penghuni IS NULL;

UPDATE invoice_sewa
SET id_penghuni = (
  SELECT oh.id_penghuni FROM occupancy_history oh WHERE TRIM(oh.nama) = TRIM(invoice_sewa.nama)
)
WHERE id_penghuni IS NULL;

-- Fix manual: "Dina Riva" di sheet DP = typo dari "Dini Ariva" (KTD-2607-004,
-- no_kamar 31, status Check-in) — dikonfirmasi user, gak match otomatis by nama.
UPDATE invoice_dp
SET id_penghuni = 'KTD-2607-004'
WHERE nama = 'Dina Riva' AND id_penghuni IS NULL;

-- "Anindya Farah" TETAP NULL di invoice_dp & invoice_sewa (by design) — gak
-- ada baris manapun di occupancy_history utk kamar 18. Cek sisa NULL:
-- SELECT no_inv, nama, no_kamar FROM invoice_dp WHERE id_penghuni IS NULL;
-- SELECT no_inv, nama, no_kamar FROM invoice_sewa WHERE id_penghuni IS NULL;


-- ============================================================================
-- 6. VERIFIKASI
-- ============================================================================

-- SELECT COUNT(*) FROM invoice_dp;                        -- 29
-- SELECT COUNT(*) FROM invoice_sewa;                       -- 31
-- PRAGMA foreign_key_check(invoice_dp);                    -- 0 baris
-- PRAGMA foreign_key_check(invoice_sewa);                  -- 0 baris


-- ============================================================================
-- 7. LINK payment -> invoice_dp / invoice_sewa (dieksekusi 2026-07-16)
--    Tabel payment sudah ada (kosong, 0 baris) — user pilih ALTER, bukan
--    drop+recreate. Ditambah 2 kolom nullable + index; "exactly satu terisi"
--    TIDAK bisa dipaksa CHECK lewat ALTER TABLE di SQLite (harus recreate
--    table), jadi aturan itu wajib ditegakkan di handler saat insert nanti.
-- ============================================================================

ALTER TABLE payment ADD COLUMN invoice_dp_id INTEGER REFERENCES invoice_dp(id);
ALTER TABLE payment ADD COLUMN invoice_sewa_id INTEGER REFERENCES invoice_sewa(id);
CREATE INDEX idx_payment_penghuni     ON payment(id_penghuni);
CREATE INDEX idx_payment_invoice_dp   ON payment(invoice_dp_id);
CREATE INDEX idx_payment_invoice_sewa ON payment(invoice_sewa_id);

-- CAVEAT yang masih ada di payment (dipertahankan sesuai pilihan user):
--   no_invoice TEXT UNIQUE NOT NULL -- bisa gagal kalau 2 payment beda invoice
--   kebetulan share no_inv yang sama (kasus invoice_sewa no_kamar 31, 3 baris
--   dengan no_inv 'INV/31/TDU/7/2026' yang legit beda periode/grand_total).
--   Kalau kejadian nyata, perlu recreate table buat drop UNIQUE constraint ini.

-- Query contoh utk 3 kebutuhan dashboard (jatuh tempo / tunggakan / pembayaran terakhir):
--
-- Daftar jatuh tempo (dari invoice_sewa.periode_akhir, invoice yg sudah ada barisnya):
-- SELECT oh.nama, s.no_kamar, s.no_inv, s.periode_akhir AS jatuh_tempo, p.status
-- FROM invoice_sewa s
-- JOIN occupancy_history oh ON oh.id_penghuni = s.id_penghuni
-- LEFT JOIN payment p ON p.invoice_sewa_id = s.id
-- WHERE s.periode_akhir <= DATE('now', '+7 days')
--   AND (p.status IS NULL OR p.status IN ('Pending','Partial','Overdue'))
-- ORDER BY s.periode_akhir;
--
-- Filter tunggakan per penghuni:
-- SELECT id_penghuni, SUM(amount) AS total_tunggakan
-- FROM payment WHERE status IN ('Pending','Partial','Overdue')
-- GROUP BY id_penghuni;
--
-- Pembayaran terakhir per orang:
-- SELECT * FROM (
--   SELECT *, ROW_NUMBER() OVER (PARTITION BY id_penghuni ORDER BY payment_date DESC) rn
--   FROM payment
-- ) WHERE rn = 1;


-- ============================================================================
-- 8. FIX terkait: src/lib/modules/handlers/checkout-lookup.ts (2026-07-16)
--    Handler ini query `payment WHERE id_penghuni = ?` pakai Tenant.id dari
--    Google Sheet "Database Penghuni" (format 'KTD-x') — BUKAN id_penghuni
--    Turso occupancy_history (format 'KTD-YYMM-NNN') yang jadi target FK
--    payment.id_penghuni. Dua ID itu gak pernah cocok. Fix: tambah
--    resolveOccupancyId(kamar) yang query occupancy_history by no_kamar +
--    status='Check-in' + tanggal_selesasi IS NULL, dipakai sebelum query
--    payment. Sudah diverifikasi terhadap kamar 1/9/21/31 (yang masing2
--    punya riwayat check-out+check-in) — hasil resolve selalu penghuni AKTIF,
--    bukan yang sudah checkout.
-- ============================================================================
