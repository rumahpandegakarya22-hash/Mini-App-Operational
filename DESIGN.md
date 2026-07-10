# DESIGN.md — Mini App Kost Tiga Dara

Sistem visual "iOS 26 / Liquid Glass" di atas identitas hijau brand kost. Kaca hanya untuk chrome navigasi; konten selalu solid dan kontras tinggi. Semua token hidup di `miniapp-kost/src/app/globals.css`.

## Theme

Dua tema: light (default) dan dark, via `prefers-color-scheme` + `[data-theme]` override. Warna dalam OKLCH.

### Light

| Token | Nilai | Peran |
|---|---|---|
| `--bg` | `oklch(0.965 0.006 165)` | Latar body (grouped background, tint hijau sangat tipis) |
| `--surface` | `oklch(1 0 0)` | Kartu / grouped inset |
| `--surface-2` | `oklch(0.945 0.008 165)` | Fill sekunder (input, segmen) |
| `--ink` | `oklch(0.22 0.015 170)` | Teks utama |
| `--ink-2` | `oklch(0.45 0.02 168)` | Teks sekunder (≥ 4.5:1 di atas surface) |
| `--brand` | `oklch(0.47 0.09 164)` | Aksi utama, seleksi, ikon aktif (≈ #0f6b4f) |
| `--brand-strong` | `oklch(0.40 0.09 164)` | Pressed / hover gelap |
| `--brand-tint` | `oklch(0.94 0.025 164)` | Fill lembut ikon/badge |
| `--danger` | `oklch(0.50 0.19 27)` | Error |
| `--border` | `oklch(0.89 0.01 165)` | Hairline |
| `--glass` | `rgba(252,253,252,0.72)` + `blur(24px) saturate(1.8)` | Material chrome |

### Dark

`--bg oklch(0.15 0.01 170)`, `--surface oklch(0.21 0.012 170)`, `--surface-2 oklch(0.26 0.012 170)`, `--ink oklch(0.95 0.005 170)`, `--ink-2 oklch(0.73 0.015 168)`, `--brand oklch(0.72 0.11 163)` (teks/ikon) & tombol fill `oklch(0.56 0.10 164)`, `--border oklch(0.30 0.01 170)`, glass `rgba(20,24,22,0.62)`.

## Typography

Satu keluarga: font stack sistem (`-apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI Variable", "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif`) — nol beban jaringan (koneksi lapangan), tampil sebagai SF di iOS. Skala tetap (rem), rasio ±1.2:

| Step | Ukuran / berat | Pakai |
|---|---|---|
| Display | 28px / 700, ls -0.02em | Sapaan home |
| Title | 22px / 700, ls -0.015em | Judul halaman |
| Headline | 17px / 600 | Judul kartu, label grup |
| Body | 16px / 400 | Isi form, teks umum |
| Footnote | 13px / 400 | Help text, meta |
| Caption | 12px / 500 uppercase-off | Label kecil |

`text-wrap: balance` untuk h1–h3.

## Spacing, Radius, Elevation

- Spacing: 4 / 8 / 12 / 16 / 20 / 24 / 32.
- Radius (continuous, iOS 26): `--r-sm 10px`, `--r-md 14px`, `--r-lg 20px`, `--r-xl 28px` (dock/sheet), kontrol pill penuh untuk tombol dock.
- Shadow: `--shadow-card 0 1px 2px oklch(0 0 0 / .04), 0 4px 16px oklch(0 0 0 / .06)`; chrome kaca memakai shadow lebih lebar + border `1px solid rgba(255,255,255,.35)` (light) / `rgba(255,255,255,.08)` (dark).
- Z-scale: `--z-dropdown 10, --z-sticky 20, --z-chrome 30, --z-backdrop 40, --z-sheet 50, --z-toast 60`.

## Layout (adaptif)

- **< 900px (mobile/tablet):** top bar kaca menempel atas (safe-area aware), konten `max-width 640px`, dock kaca mengambang di bawah (`bottom: max(16px, safe-area)`), padding bawah konten menghindari dock.
- **≥ 900px (desktop):** sidebar kaca kiri 280px (navigasi modul dikelompokkan per divisi), konten `max-width 720px` di area kanan; dock disembunyikan.
- Grid modul home: `repeat(auto-fill, minmax(160px, 1fr))`.

## Icons

`lucide-react`, stroke 24×24, ukuran 18–22px di UI, satu gaya di semua komponen. Peta ikon modul di `src/components/module-icons.tsx` (mis. `penghuni-baru → UserRoundPlus`, `pembayaran-sewa → Wallet`, `checkout → DoorOpen`). Tidak ada emoji sebagai ikon.

## Components

- **GlassTopBar** — bar kaca; kiri tombol back (chevron), tengah judul, kanan aksi.
- **Dock (mobile)** — pill kaca mengambang: Beranda, Kelola User (owner), Keluar.
- **Sidebar (desktop)** — kaca; header brand, grup navigasi per divisi, item aktif berlatar `--brand-tint` + teks `--brand`.
- **ModuleCard** — surface solid, ikon dalam tile `--brand-tint` radius `--r-md`, judul headline; press scale 0.97.
- **Form grouped inset** — field dalam kartu `--surface` radius `--r-lg`; label caption di atas kontrol; kontrol fill `--surface-2` radius `--r-md`, min-height 48px; select dengan chevron custom; focus ring 2px `--brand` offset 2px.
- **PrimaryButton** — fill `--brand`, teks putih, radius `--r-md`, min-height 50px; loading = spinner inline; pressed scale 0.98.
- **StatusBanner** — error (danger tint), warning (amber tint), info auto-fill (brand tint); selalu dengan ikon.
- **SuccessCheck** — lingkaran brand + path checkmark digambar (SVG stroke dash), lalu detail & tombol "Input Lagi".
- **PreviewSheet** — ringkasan label/nilai ala receipt sebelum konfirmasi kirim.

Setiap kontrol punya state: default, hover (desktop), focus-visible, active/pressed, disabled, loading, error.

## Motion (framer-motion)

- Durasi 150–250ms; easing keluar `[0.32, 0.72, 0, 1]` (kurva sheet iOS); spring lembut untuk press (`whileTap scale 0.97`), tanpa bounce berlebih.
- Stagger kartu home 30ms/item, sekali saat mount — bukan orchestrasi panjang.
- Field kondisional (`showIf`) masuk/keluar dengan height+opacity via `AnimatePresence`.
- Sukses: checkmark path draw 400ms; preview sheet slide-up 250ms.
- `MotionConfig reducedMotion="user"` global — `prefers-reduced-motion` memotong ke crossfade/instan.

## Aturan keras

- Kaca (backdrop-filter) hanya di top bar, dock, sidebar. Form, kartu, dan banner selalu solid.
- Placeholder & teks sekunder tetap ≥ 4.5:1.
- Tidak ada gradient text, side-stripe border, emoji icon, atau font display.
