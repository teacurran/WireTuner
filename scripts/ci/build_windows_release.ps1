# build_windows_release.ps1 - Build and package Windows release installer
#
# Usage:
#   .\scripts\ci\build_windows_release.ps1 [options]
#
# Parameters:
#   -Version VERSION        Specify version string (e.g., "0.1.0")
#   -SkipSign              Skip code signing (for local builds)
#   -OutputDir DIR         Output directory for installer (default: build\release)
#   -Help                  Show this help message
#
# Environment Variables:
#   WINDOWS_PFX_PATH       Path to code signing certificate (.pfx file)
#   WINDOWS_PFX_PASSWORD   Password for .pfx certificate
#   SIGNING_CERT_THUMBPRINT Certificate thumbprint (if using cert store instead of PFX)
#   SKIP_SIGN              Set to "true" to skip signing (alternative to -SkipSign)
#
# Examples:
#   .\scripts\ci\build_windows_release.ps1 -Version 0.1.0
#   .\scripts\ci\build_windows_release.ps1 -SkipSign  # Local unsigned build
#   $env:SKIP_SIGN="true"; .\scripts\ci\build_windows_release.ps1  # CI without credentials
#
# Requirements:
#   - Windows 10 version 1809+ (x64)
#   - Visual Studio 2019+ Build Tools
#   - Flutter 3.16.0+
#   - Inno Setup 6+ (https://jrsoftware.org/isdl.php)
#   - Windows SDK (for signtool.exe)
#   - Valid code signing certificate (for signing)
#
# Exit codes:
#   0 - Success
#   1 - Build or packaging failed
#   2 - Missing dependencies or configuration

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "0.1.0",

    [Parameter(Mandatory=$false)]
    [switch]$SkipSign,

    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "",

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# ANSI color codes for Windows PowerShell
$script:RED = "`e[0;31m"
$script:GREEN = "`e[0;32m"
$script:YELLOW = "`e[1;33m"
$script:BLUE = "`e[0;34m"
$script:CYAN = "`e[0;36m"
$script:BOLD = "`e[1m"
$script:NC = "`e[0m"

# Color output helpers (matching bash script style)
function Write-Error-Custom {
    param([string]$Message)
    Write-Host "${script:RED}✗ ERROR:${script:NC} $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "${script:GREEN}✓ SUCCESS:${script:NC} $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "${script:BLUE}ℹ INFO:${script:NC} $Message" -ForegroundColor Blue
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "${script:YELLOW}⚠ WARN:${script:NC} $Message" -ForegroundColor Yellow
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "${script:CYAN}${script:BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${script:NC}" -ForegroundColor Cyan
    Write-Host "${script:CYAN}${script:BOLD}  $Message${script:NC}" -ForegroundColor Cyan
    Write-Host "${script:CYAN}${script:BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${script:NC}" -ForegroundColor Cyan
    Write-Host ""
}

# Show help
function Show-Help {
    @"
WireTuner Windows Release Build Script

Usage:
  .\scripts\ci\build_windows_release.ps1 [options]

Parameters:
  -Version VERSION        Specify version string (e.g., "0.1.0")
  -SkipSign              Skip code signing (for local builds)
  -OutputDir DIR         Output directory for installer (default: build\release)
  -Help                  Show this help message

Environment Variables:
  WINDOWS_PFX_PATH       Path to code signing certificate (.pfx file)
  WINDOWS_PFX_PASSWORD   Password for .pfx certificate
  SIGNING_CERT_THUMBPRINT Certificate thumbprint (if using cert store)
  SKIP_SIGN              Set to "true" to skip signing

Examples:
  # Full signed release build (using PFX file)
  `$env:WINDOWS_PFX_PATH="C:\certs\certificate.pfx"
  `$env:WINDOWS_PFX_PASSWORD="your-password"
  .\scripts\ci\build_windows_release.ps1 -Version 0.1.0

  # Local unsigned build for testing
  .\scripts\ci\build_windows_release.ps1 -SkipSign

Requirements:
  - Windows 10 version 1809+ (x64)
  - Visual Studio 2019+ Build Tools
  - Flutter 3.16.0+
  - Inno Setup 6+ (https://jrsoftware.org/isdl.php)
  - Windows SDK (for signtool.exe)
  - Valid code signing certificate (for signing)

Exit codes:
  0 - Success
  1 - Build or packaging failed
  2 - Missing dependencies or configuration
"@
}

if ($Help) {
    Show-Help
    exit 0
}

# Script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..") | Select-Object -ExpandProperty Path

Set-Location $ProjectRoot

# Default output directory
if ([string]::IsNullOrEmpty($OutputDir)) {
    $OutputDir = Join-Path $ProjectRoot "build\release"
}

# Check environment variables for skip flags
if ($env:SKIP_SIGN -eq "true") {
    $SkipSign = $true
}

$AppName = "WireTuner"

# Header
Write-Host "${script:CYAN}${script:BOLD}"
@"
╦ ╦┬┬─┐┌─┐╔╦╗┬ ┬┌┐┌┌─┐┬─┐
║║║│├┬┘├┤  ║ │ │││││├┤ ├┬┘
╚╩╝┴┴└─└─┘ ╩ └─┘┘└┘└─┘┴└─
Windows Release Build
"@
Write-Host "${script:NC}`n"

Write-Info "Version: $Version"
Write-Info "Project Root: $ProjectRoot"
Write-Info "Output Directory: $OutputDir"
Write-Host ""

# Pre-flight checks
Write-Header "Pre-flight Checks"

# Check Windows
if ($IsLinux -or $IsMacOS) {
    Write-Error-Custom "This script must be run on Windows"
    exit 2
}
Write-Success "Running on Windows"

# Check Flutter
try {
    $FlutterVersion = (flutter --version 2>$null | Select-String -Pattern "Flutter" | Select-Object -First 1).ToString()
    Write-Success "Flutter installed: $FlutterVersion"
} catch {
    Write-Error-Custom "Flutter is not installed or not in PATH"
    exit 2
}

# Check Visual Studio Build Tools
$VSWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $VSWhere) {
    $VSInstall = & $VSWhere -latest -property installationPath
    if ($VSInstall) {
        Write-Success "Visual Studio Build Tools found: $VSInstall"
    } else {
        Write-Warning-Custom "Visual Studio Build Tools not found"
        Write-Info "Install from: https://visualstudio.microsoft.com/downloads/"
    }
} else {
    Write-Warning-Custom "Visual Studio installer not found (vswhere.exe)"
}

# Check Inno Setup
$InnoSetupPaths = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 5\ISCC.exe"
)

$InnoSetupPath = $null
foreach ($path in $InnoSetupPaths) {
    if (Test-Path $path) {
        $InnoSetupPath = $path
        break
    }
}

if ($InnoSetupPath) {
    Write-Success "Inno Setup found: $InnoSetupPath"
} else {
    Write-Error-Custom "Inno Setup not found"
    Write-Info "Download from: https://jrsoftware.org/isdl.php"
    Write-Info "Expected locations:"
    $InnoSetupPaths | ForEach-Object { Write-Info "  $_" }
    exit 2
}

# Check signtool (Windows SDK)
$SignToolPath = $null
if (-not $SkipSign) {
    # Common locations for signtool.exe
    $SDKPaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe",
        "${env:ProgramFiles}\Windows Kits\10\bin\*\x64\signtool.exe"
    )

    foreach ($pattern in $SDKPaths) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $SignToolPath = $found.FullName
            break
        }
    }

    if ($SignToolPath) {
        Write-Success "signtool.exe found: $SignToolPath"
    } else {
        Write-Error-Custom "signtool.exe not found (Windows SDK required)"
        Write-Info "Install Windows SDK from: https://developer.microsoft.com/windows/downloads/windows-sdk/"
        exit 2
    }

    # Check signing configuration
    $PfxPath = $env:WINDOWS_PFX_PATH
    $PfxPassword = $env:WINDOWS_PFX_PASSWORD
    $CertThumbprint = $env:SIGNING_CERT_THUMBPRINT

    if ($PfxPath) {
        if (Test-Path $PfxPath) {
            Write-Success "Using PFX certificate: $PfxPath"
        } else {
            Write-Error-Custom "PFX file not found: $PfxPath"
            exit 2
        }

        if ([string]::IsNullOrEmpty($PfxPassword)) {
            Write-Warning-Custom "WINDOWS_PFX_PASSWORD not set (required for PFX signing)"
            Write-Info "Either set environment variable or use -SkipSign for local builds"
            exit 2
        }
    } elseif ($CertThumbprint) {
        Write-Success "Using certificate from store: $CertThumbprint"
    } else {
        Write-Warning-Custom "No signing configuration found"
        Write-Info "Set WINDOWS_PFX_PATH + WINDOWS_PFX_PASSWORD or SIGNING_CERT_THUMBPRINT"
        Write-Info "Or use -SkipSign for local unsigned builds"
        exit 2
    }
} else {
    Write-Warning-Custom "Code signing will be skipped"
}

Write-Host ""

# Step 1: Get Flutter dependencies
Write-Header "1. Getting Flutter Dependencies"

flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Failed to get Flutter dependencies"
    exit 1
}
Write-Success "Dependencies fetched"

# Step 2: Clean previous builds
Write-Header "2. Cleaning Previous Builds"

flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Warning-Custom "Flutter clean had issues (non-fatal)"
}

# Create output directory
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
Write-Success "Build directory cleaned"

# Step 3: Build Windows release
Write-Header "3. Building Windows Release"

flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Flutter build failed"
    exit 1
}

$BuildDir = Join-Path $ProjectRoot "build\windows\runner\Release"

if (-not (Test-Path $BuildDir)) {
    Write-Error-Custom "Build failed - release directory not found at $BuildDir"
    exit 1
}

Write-Success "Windows app built successfully"
Write-Info "Build directory: $BuildDir"

# Step 4: Code signing (EXE)
if (-not $SkipSign) {
    Write-Header "4. Code Signing Executables"

    $ExePath = Join-Path $BuildDir "$AppName.exe"

    if (-not (Test-Path $ExePath)) {
        Write-Error-Custom "Executable not found: $ExePath"
        exit 1
    }

    Write-Info "Signing: $ExePath"

    # Build signtool arguments
    $SignToolArgs = @("sign")

    if ($PfxPath) {
        $SignToolArgs += "/f", "`"$PfxPath`""
        $SignToolArgs += "/p", $PfxPassword
    } elseif ($CertThumbprint) {
        $SignToolArgs += "/sha1", $CertThumbprint
    }

    # Add timestamp server (DigiCert)
    $SignToolArgs += "/tr", "http://timestamp.digicert.com"
    $SignToolArgs += "/td", "sha256"
    $SignToolArgs += "/fd", "sha256"
    $SignToolArgs += "`"$ExePath`""

    # Execute signtool
    $SignToolCmd = "& `"$SignToolPath`" $($SignToolArgs -join ' ')"
    Invoke-Expression $SignToolCmd

    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Code signing failed"
        exit 1
    }

    # Verify signature
    & "$SignToolPath" verify /pa /v "`"$ExePath`""

    Write-Success "Executable signed successfully"
} else {
    Write-Warning-Custom "Skipping code signing"
}

# Step 5: Create Inno Setup script
Write-Header "5. Creating Installer"

$InnoScriptPath = Join-Path $OutputDir "wiretuner-setup.iss"

# Create Inno Setup script content
$InnoScript = @"
; WireTuner Inno Setup Script
; Auto-generated by build_windows_release.ps1

#define MyAppName "$AppName"
#define MyAppVersion "$Version"
#define MyAppPublisher "WireTuner Team"
#define MyAppURL "https://wiretuner.com"
#define MyAppExeName "$AppName.exe"

[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
; LicenseFile=$ProjectRoot\LICENSE
OutputDir=$OutputDir
OutputBaseFilename=$AppName-$Version-Windows-Setup
SetupIconFile=$ProjectRoot\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "$BuildDir\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Name: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
"@

# Write Inno Setup script
Set-Content -Path $InnoScriptPath -Value $InnoScript -Encoding UTF8

Write-Info "Inno Setup script created: $InnoScriptPath"

# Compile installer with Inno Setup
Write-Info "Compiling installer..."

& "$InnoSetupPath" "$InnoScriptPath"

if ($LASTEXITCODE -ne 0) {
    Write-Error-Custom "Installer compilation failed"
    exit 1
}

$InstallerPath = Join-Path $OutputDir "$AppName-$Version-Windows-Setup.exe"

if (-not (Test-Path $InstallerPath)) {
    Write-Error-Custom "Installer not found: $InstallerPath"
    exit 1
}

Write-Success "Installer created: $InstallerPath"

# Step 6: Sign installer
if (-not $SkipSign) {
    Write-Header "6. Signing Installer"

    Write-Info "Signing: $InstallerPath"

    # Build signtool arguments (same as EXE signing)
    $SignToolArgs = @("sign")

    if ($PfxPath) {
        $SignToolArgs += "/f", "`"$PfxPath`""
        $SignToolArgs += "/p", $PfxPassword
    } elseif ($CertThumbprint) {
        $SignToolArgs += "/sha1", $CertThumbprint
    }

    $SignToolArgs += "/tr", "http://timestamp.digicert.com"
    $SignToolArgs += "/td", "sha256"
    $SignToolArgs += "/fd", "sha256"
    $SignToolArgs += "`"$InstallerPath`""

    # Execute signtool
    $SignToolCmd = "& `"$SignToolPath`" $($SignToolArgs -join ' ')"
    Invoke-Expression $SignToolCmd

    if ($LASTEXITCODE -ne 0) {
        Write-Error-Custom "Installer signing failed"
        exit 1
    }

    # Verify signature
    & "$SignToolPath" verify /pa /v "`"$InstallerPath`""

    Write-Success "Installer signed successfully"
} else {
    Write-Warning-Custom "Skipping installer signing"
}

# Step 7: Generate SHA256 hash
Write-Header "7. Generating SHA256 Hash"

$HashFile = Join-Path $OutputDir "$AppName-$Version-Windows-Setup.sha256"
$HashValue = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash

Set-Content -Path $HashFile -Value $HashValue

Write-Success "SHA256 hash generated"
Write-Info "Hash: $HashValue"
Write-Info "Hash file: $HashFile"

# Final summary
Write-Host ""
Write-Header "Build Summary"

$InstallerSize = (Get-Item $InstallerPath).Length / 1MB
$InstallerSizeStr = "{0:N2} MB" -f $InstallerSize

Write-Success "Windows release build completed successfully!"
Write-Host ""
Write-Host "${script:BOLD}Build Information:${script:NC}"
Write-Host "  Version:        $Version"
Write-Host "  Installer:      $InstallerPath"
Write-Host "  Installer Size: $InstallerSizeStr"
Write-Host "  SHA256:         $HashValue"
Write-Host "  Signed:         $(if (-not $SkipSign) { '✓ Yes' } else { '✗ No' })"
Write-Host ""

if ($SkipSign) {
    Write-Warning-Custom "This build is NOT suitable for public distribution"
    Write-Info "For release builds, ensure code signing is enabled"
    Write-Host ""
}

Write-Success "All steps completed!"
Write-Host ""

exit 0
