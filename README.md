# LED Bar 8-bit Marquee — iCESugar v1.5 (iCE40UP5K)

Delapan pola animasi untuk modul **8 Bit LED Bar (S0..S7)** yang berganti otomatis
(default tiap 8 detik). LED RGB onboard menampilkan nomor pola yang sedang aktif.

| Mode | Pola | RGB (R/G/B) |
|---|---|---|
| 0 | Selang-seling `10101010` ↔ `01010101` | padam |
| 1 | Satu LED berjalan S0 → S7, ulang terus | R |
| 2 | Ping-pong (Knight Rider) S0 ↔ S7 | G |
| 3 | Menyala berurutan sampai penuh, lalu padam berurutan | R+G |
| 4 | Melebar dari tengah sampai penuh, lalu menyempit | B |
| 5 | Counter biner 0..255 | R+B |
| 6 | Dua LED dari kiri-kanan bertemu di tengah, lalu menjauh | G+B |
| 7 | Kedip acak (LFSR 8-bit) | R+G+B |

## 1. Pemasangan kabel

Modul LED bar tidak punya pin GND: anoda semua LED terhubung ke VCC, sedangkan
S0..S7 adalah sisi katoda. Jadi LED **menyala saat pin FPGA = LOW** (`ACTIVE_LOW = 1`).

| Modul LED bar | iCESugar (header PMOD2) |
|---|---|
| VCC | **3.3V** (jangan 5V) |
| S0 | P46 |
| S1 | P45 |
| S2 | P44 |
| S3 | P43 |
| S4 | P42 |
| S5 | P38 |
| S6 | P37 |
| S7 | P36 |

Kenapa PMOD2, bukan PMOD1 seperti di slide TM1638? Pin P4 dan P6 di PMOD1 juga
terhubung ke UART iCELink, jadi dihindari agar tidak bentrok dengan debugger.
Cocokkan label P46..P36 dengan sablon di papan Anda sebelum menyalakan.

Kalau saat dicoba LED justru menyala di pola yang seharusnya mati (terbalik),
modul Anda aktif-HIGH. Build ulang dengan `make ACTIVE_LOW=0`.

## 2. Toolchain (OSS CAD Suite)

Rilis yang dicek: https://github.com/YosysHQ/oss-cad-suite-build/releases/tag/2026-07-27
(berisi yosys, nextpnr-ice40, icestorm/icepack, iverilog, gtkwave).

File unduhan yang terlihat di rilis tersebut:

- `oss-cad-suite-windows-x64-20260727.exe`
- `oss-cad-suite-linux-x64-20260727.tgz`
- `oss-cad-suite-darwin-x64-20260727.tgz`

README repo menyarankan **WSL + versi linux-x64** untuk pengguna Windows.
Catatan di README repo: image build diperbarui 2026-07-28, dan rilis 2026-07-27 ini
disebut sebagai versi "sebelum perubahan" jika ada masalah di rilis terbaru.

Aktifkan environment:

```
# Linux / macOS / WSL
source <lokasi>/oss-cad-suite/environment

# Windows (CMD)
<lokasi>\oss-cad-suite\environment.bat
```

Ekstrak ke path tanpa spasi.

## 3. Build dan upload

```
make            # menghasilkan top.bin
make sim        # simulasi iverilog (waktu dipercepat), cetak pola per mode
make flash      # build lalu salin otomatis ke drive iCELink
```

Upload: sambungkan iCESugar lewat USB, lalu **salin `top.bin` ke drive virtual
iCELink** (drag & drop). FPGA langsung berjalan setelah salinan selesai.

Bila memakai WSL, salin dari Explorer Windows atau mount drive iCELink
(`sudo mount -t drvfs E: /mnt/e`) lalu `cp top.bin /mnt/e/`.

## 4. Mengubah perilaku

Semua ada di parameter `top` pada `top.v`:

- `STEP_HZ` : kecepatan animasi (default 8 langkah/detik)
- `MODE_STEPS` : jumlah langkah per pola (default 64 = 8 detik)
- `ACTIVE_LOW` : polaritas LED bar

## 5. Status verifikasi

Di lingkungan tempat file ini dibuat, yosys/nextpnr/iverilog tidak tersedia, jadi
`make` dan `make sim` **belum dijalankan**. Yang sudah dicek: logika tiap pola
dimodelkan ulang di Python dengan lebar bit 8-bit seperti di Verilog, dan urutan
semua mode serta periode LFSR (255, tanpa lock-up) sesuai rancangan. Pin clock 35
(12 MHz) dan paket SG48 sesuai pcf iCESugar/iCEBreaker yang beredar; pin PMOD2
dibaca dari diagram papan di slide.

Tes pertama yang disarankan: jalankan `make sim`, lalu upload dan cek bahwa
mode 1 menjalankan satu LED dari S0 ke S7.
# icesugar-ledbar
