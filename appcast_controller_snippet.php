<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class AppcastController extends Controller
{
    public function appcast()
    {
        // HASIL GENERATE OTOMATIS SAAT BUILD:
        $latestVersion = "0.1.10";
        $releaseDate = "Wed, 24 Jun 2026 10:01:00 GMT";
        $downloadUrl = "https://suntikradar.com/downloads/SuntikRadar-Setup-v0.1.10.exe";
        
        // Silakan ubah Changelog di bawah ini jika ada fitur baru:
        $changelog = <<<HTML
            <b>Apa yang baru di rilis ini:</b>
            <ul>
                <li>Perbaikan bug dan peningkatan performa</li>
            </ul>
HTML;

        $xml = <<<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>SuntikRadar Desktop Appcast</title>
        <description>Pembaruan SuntikRadar Desktop</description>
        <language>id</language>
        
        <item>
            <title>Pembaruan Versi {$latestVersion}</title>
            <description>
                <![CDATA[
                    {$changelog}
                ]]>
            </description>
            <pubDate>{$releaseDate}</pubDate>
            <sparkle:version>{$latestVersion}</sparkle:version>
            <sparkle:shortVersionString>{$latestVersion}</sparkle:shortVersionString>
            <enclosure url="{$downloadUrl}" 
                       sparkle:version="{$latestVersion}" 
                       sparkle:os="windows"
                       type="application/octet-stream" />
        </item>
    </channel>
</rss>
XML;

        return response($xml, 200)
                ->header('Content-Type', 'text/xml');
    }
}
