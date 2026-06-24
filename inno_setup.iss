[Setup]
; Ganti AppId dengan GUID unik aplikasi Anda (generate GUID baru jika untuk aplikasi lain)
AppId={{8B2F3A8A-5D1A-4C9D-9F2F-3F0D1E7B9C4A}}
AppName=SuntikRadar
AppVersion=0.1.10
AppPublisher=Lahaula
DefaultDirName={autopf}\SuntikRadar
DisableProgramGroupPage=yes
OutputDir=build\installer
OutputBaseFilename=SuntikRadar-Setup-v0.1.10
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Menyalin file .exe utama
Source: "build\windows\x64\runner\Release\lahaula_desktop.exe"; DestDir: "{app}"; Flags: ignoreversion
; Menyalin semua file .dll yang dibutuhkan Flutter dan plugin
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
; Menyalin folder data (berisi aset dan kompilan kode Dart)
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\SuntikRadar"; Filename: "{app}\lahaula_desktop.exe"
Name: "{autodesktop}\SuntikRadar"; Filename: "{app}\lahaula_desktop.exe"; Tasks: desktopicon

[Run]
; Dijalankan otomatis setelah instalasi selesai, tetapi di-skip jika instalasi berjalan secara "Silent" (mode update dari auto_updater)
Filename: "{app}\lahaula_desktop.exe"; Description: "{cm:LaunchProgram,SuntikRadar}"; Flags: nowait postinstall skipifsilent
