# Lahaula Desktop Admin

Flutter desktop client untuk admin/operator Lahaula. Aplikasi ini memakai Laravel API sebagai backend utama dan menyimpan token Sanctum secara lokal.

## Build Windows Installer

Build Windows harus dijalankan di Windows karena Flutter membutuhkan toolchain Visual Studio untuk menghasilkan aplikasi Windows.

1. Install Flutter stable.
2. Install Visual Studio 2022 dengan workload **Desktop development with C++**.
3. Opsional untuk installer `.exe`: install Inno Setup.
4. Jalankan:

```bat
build_windows.bat
```

Hasil build aplikasi ada di:

```text
build\windows\x64\runner\Release
```

Jika Inno Setup tersedia, installer ada di:

```text
dist\LahaulaDesktopSetup-0.1.0.exe
```

## Development

```bash
flutter pub get
flutter run -d windows
```

Konfigurasi API ada di `.env`.