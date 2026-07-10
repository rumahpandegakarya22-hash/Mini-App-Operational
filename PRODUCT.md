# Product

## Register

product

## Users

Staf lapangan Kost Tiga Dara Putri UGM — Staff Admin, Sales, Marketing, Maintenance, dan Inspeksi — plus Pengawas dan Owner. Mayoritas memakai HP (iPhone/Android) di lapangan, sering satu tangan, koneksi tidak stabil, kadang di bawah sinar matahari. Konteksnya selalu "sedang di tengah tugas": mencatat booking, pembayaran, temuan inspeksi, atau pengeluaran secepat mungkin lalu kembali bekerja. Bahasa antarmuka: Indonesia.

## Product Purpose

Aplikasi input operasional harian yang mengunci format data di titik masuk (dropdown, date picker, validasi server) sehingga Google Sheets sebagai source of truth tetap bersih. Sukses = waktu input < 30 detik per form, kesalahan input < 10%, dan 100% operator memakai app (bukan spreadsheet). Bukan dashboard, bukan alat analisis — murni alat catat yang cepat dan hampir mustahil salah.

## Brand Personality

Tenang, presisi, premium-tapi-ramah. Terasa seperti aplikasi sistem iOS modern (iOS 26 / Liquid Glass): material kaca pada chrome navigasi, permukaan konten solid dan sangat terbaca, gerakan halus yang mengonfirmasi aksi. Identitas warna: hijau brand kost (deep green) yang sudah dipakai di manifest & dashboard — dipertahankan, bukan diganti.

## Anti-references

- Template admin Bootstrap/generic: tabel abu-abu, tombol biru default, tanpa identitas.
- Spreadsheet-look: grid rapat, teks kecil, semua data sekaligus.
- Glassmorphism dekoratif di mana-mana: kaca pada kartu konten/form yang mengorbankan keterbacaan di luar ruangan. Kaca hanya untuk chrome (bar navigasi, dock, sidebar).
- Dashboard SaaS "hero metric" dengan gradien dan angka besar — app ini bukan dashboard.
- Font display/dekoratif pada label & tombol.

## Design Principles

1. **Form selesai ≤ 1 layar scroll.** Kecepatan submit mengalahkan segala dekorasi; setiap elemen visual harus mempercepat, bukan memperlambat.
2. **Kaca adalah chrome, bukan konten.** Liquid Glass hidup di top bar, dock, dan sidebar; form dan data selalu di permukaan solid kontras tinggi (terbaca di bawah matahari).
3. **Operasi satu jempol.** Target sentuh ≥ 44px, aksi utama di jangkauan jempol (bawah layar di mobile), tidak ada hover-only affordance.
4. **State selalu terlihat.** Loading, sukses, error, draft tersimpan, auto-fill — semua dikomunikasikan eksplisit; motion dipakai untuk mengonfirmasi state, bukan menghias.
5. **Kosakata iOS yang familiar.** Grouped inset list, kontrol standar, satu keluarga font sistem — alatnya menghilang ke dalam tugas.

## Accessibility & Inclusion

WCAG AA: kontras teks ≥ 4.5:1 (termasuk placeholder), focus ring terlihat untuk navigasi keyboard, target sentuh ≥ 44px, `prefers-reduced-motion` dihormati (semua animasi punya fallback crossfade/instan), bekerja di Chrome/Safari 2 versi terakhir, ukuran teks body ≥ 16px di mobile.
