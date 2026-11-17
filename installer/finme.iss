; Instalador do FinMe (Inno Setup 6).
; Antes: flutter build windows --release
; Gerar: ISCC.exe installer\finme.iss  →  build\installer\FinMe-Setup-<versão>.exe

#define AppName "FinMe"
#define AppVersion "1.0.0"
#define ReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
; AppId fixo: atualizações reconhecem a instalação anterior.
AppId={{6F1D8C2A-4B7E-4E0F-9C3A-F1A5B2D7E914}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=FinMe
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; Instala sem admin (pasta do usuário); quem tiver admin pode escolher "para todos".
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\build\installer
OutputBaseFilename=FinMe-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\finme.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\finme.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\finme.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\finme.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

; Dados do usuário (Hive em Documentos\finme) não são apagados na desinstalação.
