param(
    [string]$DownloadUrlBase = "https://suntikradar.com/downloads"
)

Write-Host "==========================================="
Write-Host "Membaca versi dari pubspec.yaml..."
Write-Host "==========================================="
$pubspec = Get-Content pubspec.yaml
$versionLine = $pubspec | Select-String -Pattern "^version:\s*(.*?)(?:\+.*)?$"
if (-not $versionLine) {
    Write-Error "Tidak dapat menemukan 'version:' di pubspec.yaml"
    exit 1
}

# Ambil versi saja tanpa build number (misal 0.1.1 dari 0.1.1+2)
$appVersion = $versionLine.Matches.Groups[1].Value
Write-Host "Versi yang terdeteksi: $appVersion"

Write-Host "`n==========================================="
Write-Host "Memperbarui inno_setup.iss dengan versi $appVersion..."
Write-Host "==========================================="
$issPath = "inno_setup.iss"
$issContent = Get-Content $issPath
$issContent = $issContent -replace "^AppVersion=.*", "AppVersion=$appVersion"
$issContent = $issContent -replace "^OutputBaseFilename=.*", "OutputBaseFilename=SuntikRadar-Setup-v$appVersion"
$issContent | Set-Content $issPath
Write-Host "inno_setup.iss berhasil diperbarui."

Write-Host "`n==========================================="
Write-Host "Membangun Aplikasi Flutter untuk Windows..."
Write-Host "==========================================="
cmd.exe /c "flutter build windows"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal membangun aplikasi Flutter."
    exit $LASTEXITCODE
}

Write-Host "`n==========================================="
Write-Host "Membuat Installer dengan Inno Setup..."
Write-Host "==========================================="
$isccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $isccPath)) {
    Write-Error "Inno Setup 6 tidak ditemukan di $isccPath."
    exit 1
}

& $isccPath $issPath
if ($LASTEXITCODE -ne 0) {
    Write-Error "Gagal membuat installer."
    exit $LASTEXITCODE
}

Write-Host "`n==========================================="
Write-Host "Meng-generate Kode untuk Laravel Controller..."
Write-Host "==========================================="
$dateStr = (Get-Date).ToString("R") # RFC 2822 format, misal: Wed, 10 Jun 2026 15:00:00 GMT
$exeName = "SuntikRadar-Setup-v$appVersion.exe"
$fullUrl = "$DownloadUrlBase/$exeName"

$phpCode = @"
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class AppcastController extends Controller
{
    public function appcast()
    {
        // HASIL GENERATE OTOMATIS SAAT BUILD:
        `$latestVersion = "$appVersion";
        `$releaseDate = "$dateStr";
        `$downloadUrl = "$fullUrl";
        
        // Silakan ubah Changelog di bawah ini jika ada fitur baru:
        `$changelog = <<<HTML
            <b>Apa yang baru di rilis ini:</b>
            <ul>
                <li>Perbaikan bug dan peningkatan performa</li>
            </ul>
HTML;

        `$xml = <<<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>SuntikRadar Desktop Appcast</title>
        <description>Pembaruan SuntikRadar Desktop</description>
        <language>id</language>
        
        <item>
            <title>Pembaruan Versi {`$latestVersion}</title>
            <description>
                <![CDATA[
                    {`$changelog}
                ]]>
            </description>
            <pubDate>{`$releaseDate}</pubDate>
            <sparkle:version>{`$latestVersion}</sparkle:version>
            <sparkle:shortVersionString>{`$latestVersion}</sparkle:shortVersionString>
            <enclosure url="{`$downloadUrl}" 
                       sparkle:version="{`$latestVersion}" 
                       sparkle:os="windows"
                       type="application/octet-stream" />
        </item>
    </channel>
</rss>
XML;

        return response(`$xml, 200)
                ->header('Content-Type', 'text/xml');
    }
}
"@

$phpCode | Set-Content "appcast_controller_snippet.php"
Write-Host "Berhasil! File installer ada di: build\installer\$exeName"
Write-Host "Silakan copy isi file 'appcast_controller_snippet.php' ke Laravel Controller Anda!"
Write-Host "==========================================="
