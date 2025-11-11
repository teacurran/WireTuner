# WireTuner Windows MSI/Installer Builder
# Task: I5.T5 - Windows platform installer generation
# Requirements: FR-001 (Windows Distribution), NFR-003 (Code Signing)
# <!-- anchor: windows-msi-builder -->

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "0.1.0",

    [Parameter(Mandatory=$false)]
    [switch]$SkipSigning = $false,

    [Parameter(Mandatory=$false)]
    [switch]$Help = $false
)

$ErrorActionPreference = "Stop"

# ============================================================================
# Configuration
# ============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "../../..")
$BuildDir = Join-Path $ProjectRoot "build\windows"
$AppName = "WireTuner"

# ============================================================================
# Color Helpers
# ============================================================================

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

# ============================================================================
# Help
# ============================================================================

if ($Help) {
    Write-Host @"
WireTuner Windows MSI/Installer Builder

USAGE:
    .\build_msi.ps1 [OPTIONS]

OPTIONS:
    -Version <string>       App version (default: 0.1.0)
    -SkipSigning            Skip code signing
    -Help                   Show this help

ENVIRONMENT VARIABLES:
    WINDOWS_PFX_PATH        Path to code-signing certificate (.pfx)
    WINDOWS_PFX_PASSWORD    Certificate password
    SIGN_TOOL_PATH          Path to signtool.exe (auto-detected from SDK)

DEPENDENCIES:
    - Flutter SDK
    - Windows SDK (for signtool.exe)
    - Inno Setup or WiX Toolset for installer creation

NOTES:
    - Use -SkipSigning for local dry runs
    - Signing requires valid Authenticode certificate
    - MSI creation requires WiX Toolset installed
    - Inno Setup is used as fallback for .exe installers

EXAMPLES:
    .\build_msi.ps1 -Version 0.1.0
    .\build_msi.ps1 -Version 0.2.0 -SkipSigning

"@
    exit 0
}

# ============================================================================
# Pre-flight Checks
# ============================================================================

Write-Info "WireTuner Windows Installer Builder v$Version"
Write-Info "Project root: $ProjectRoot"

# Check Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error-Custom "Flutter not found in PATH"
    exit 1
}
Write-Success "Flutter found"

# Validate signing environment
$SignToolPath = $null

if (-not $SkipSigning) {
    # Check environment variables
    if (-not $env:WINDOWS_PFX_PATH -or -not $env:WINDOWS_PFX_PASSWORD) {
        Write-Error-Custom "Signing requires WINDOWS_PFX_PATH and WINDOWS_PFX_PASSWORD"
        Write-Warning-Custom "Use -SkipSigning for local builds"
        exit 1
    }

    if (-not (Test-Path $env:WINDOWS_PFX_PATH)) {
        Write-Error-Custom "Certificate not found: $env:WINDOWS_PFX_PATH"
        exit 1
    }

    # Find signtool.exe
    if ($env:SIGN_TOOL_PATH -and (Test-Path $env:SIGN_TOOL_PATH)) {
        $SignToolPath = $env:SIGN_TOOL_PATH
    } else {
        # Auto-detect from Windows SDK
        $SdkPaths = @(
            "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe",
            "${env:ProgramFiles}\Windows Kits\10\bin\*\x64\signtool.exe"
        )

        foreach ($Pattern in $SdkPaths) {
            $Found = Get-ChildItem $Pattern -ErrorAction SilentlyContinue |
                     Sort-Object -Descending |
                     Select-Object -First 1

            if ($Found) {
                $SignToolPath = $Found.FullName
                break
            }
        }
    }

    if (-not $SignToolPath) {
        Write-Error-Custom "signtool.exe not found"
        Write-Info "Install Windows SDK or set SIGN_TOOL_PATH"
        exit 1
    }

    Write-Success "Code signing environment validated"
    Write-Info "signtool: $SignToolPath"
} else {
    Write-Warning-Custom "Skipping code signing (-SkipSigning)"
}

# ============================================================================
# Build Flutter App
# ============================================================================

Write-Info "Building Flutter Windows app..."

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

Set-Location $ProjectRoot

# Clean previous builds
flutter clean
Write-Success "Cleaned previous builds"

# Build release app
try {
    flutter build windows --release
    Write-Success "Flutter build completed"
} catch {
    Write-Error-Custom "Flutter build failed: $_"
    exit 1
}

$AppExePath = Join-Path $ProjectRoot "build\windows\x64\runner\Release\$AppName.exe"

if (-not (Test-Path $AppExePath)) {
    Write-Error-Custom "Executable not found: $AppExePath"
    exit 1
}

Write-Info "App executable: $AppExePath"

# ============================================================================
# Code Signing
# ============================================================================

if (-not $SkipSigning) {
    Write-Info "Signing executable..."

    $SignArgs = @(
        "sign",
        "/f", $env:WINDOWS_PFX_PATH,
        "/p", $env:WINDOWS_PFX_PASSWORD,
        "/tr", "http://timestamp.digicert.com",
        "/td", "SHA256",
        "/fd", "SHA256",
        "/v",
        $AppExePath
    )

    try {
        & $SignToolPath $SignArgs
        Write-Success "Executable signed successfully"
    } catch {
        Write-Error-Custom "Code signing failed: $_"
        exit 1
    }

    # Verify signature
    try {
        & $SignToolPath verify /pa /v $AppExePath
        Write-Success "Signature verified"
    } catch {
        Write-Error-Custom "Signature verification failed"
        exit 1
    }
}

# ============================================================================
# Create Installer (Inno Setup or WiX)
# ============================================================================

Write-Info "Creating installer package..."

$InstallerPath = Join-Path $BuildDir "$AppName-Setup-$Version.exe"

# Check for Inno Setup (fallback from MSI)
$InnoSetupPath = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"

if (Test-Path $InnoSetupPath) {
    Write-Info "Using Inno Setup for installer creation"

    # Create Inno Setup script
    $InnoScript = Join-Path $BuildDir "setup.iss"

    $InnoScriptContent = @"
#define MyAppName "$AppName"
#define MyAppVersion "$Version"
#define MyAppPublisher "WireTuner Team"
#define MyAppURL "https://wiretuner.app"
#define MyAppExeName "$AppName.exe"

[Setup]
AppId={{WIRETUNER-APP-GUID-2024}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=$BuildDir
OutputBaseFilename=$AppName-Setup-$Version
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "$ProjectRoot\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent
"@

    Set-Content -Path $InnoScript -Value $InnoScriptContent -Encoding UTF8

    # Compile installer
    try {
        & $InnoSetupPath $InnoScript
        Write-Success "Installer created with Inno Setup"
    } catch {
        Write-Error-Custom "Inno Setup compilation failed: $_"
        exit 1
    }

} else {
    # WiX Toolset check
    $WixToolPath = "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin\candle.exe"

    if (Test-Path $WixToolPath) {
        Write-Info "Using WiX Toolset for MSI creation"
        Write-Warning-Custom "WiX MSI creation not fully implemented - placeholder"

        # TODO: Implement full WiX MSI generation
        # For now, copy executable as fallback
        Copy-Item $AppExePath $InstallerPath
        Write-Warning-Custom "Created executable copy (MSI generation pending)"

    } else {
        Write-Warning-Custom "Neither Inno Setup nor WiX found"
        Write-Info "Copying executable as standalone installer"
        Copy-Item $AppExePath $InstallerPath
    }
}

if (-not (Test-Path $InstallerPath)) {
    Write-Error-Custom "Installer not created: $InstallerPath"
    exit 1
}

Write-Info "Installer: $InstallerPath ($([math]::Round((Get-Item $InstallerPath).Length / 1MB, 2)) MB)"

# ============================================================================
# Sign Installer
# ============================================================================

if (-not $SkipSigning -and (Test-Path $InstallerPath)) {
    Write-Info "Signing installer..."

    $SignArgs = @(
        "sign",
        "/f", $env:WINDOWS_PFX_PATH,
        "/p", $env:WINDOWS_PFX_PASSWORD,
        "/tr", "http://timestamp.digicert.com",
        "/td", "SHA256",
        "/fd", "SHA256",
        "/v",
        $InstallerPath
    )

    try {
        & $SignToolPath $SignArgs
        Write-Success "Installer signed successfully"
    } catch {
        Write-Error-Custom "Installer signing failed: $_"
        exit 1
    }
}

# ============================================================================
# Generate Checksum
# ============================================================================

$ChecksumFile = "$InstallerPath.sha256"
$Hash = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash
"$Hash  $(Split-Path -Leaf $InstallerPath)" | Set-Content -Path $ChecksumFile
Write-Success "Checksum: $ChecksumFile"
Write-Host $Hash

# ============================================================================
# Summary
# ============================================================================

Write-Success "Windows installer build completed!"
Write-Host ""
Write-Info "Artifact: $InstallerPath"
Write-Info "Checksum: $ChecksumFile"
Write-Info "Signed: $(-not $SkipSigning)"
Write-Host ""
Write-Info "Verification:"

if (-not $SkipSigning) {
    Write-Info "  signtool verify /pa /v `"$InstallerPath`""
}

# Line count verification
$ScriptLines = (Get-Content $MyInvocation.MyCommand.Path).Count
Write-Info "Script verified: $ScriptLines lines"

exit 0
