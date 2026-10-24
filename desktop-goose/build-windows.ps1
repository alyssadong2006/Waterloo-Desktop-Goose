param(
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET 8 SDK is required. Install it from https://dotnet.microsoft.com/download/dotnet/8.0"
}

$version = [version]((dotnet --version).Split('-')[0])
if ($version.Major -lt 8) { throw ".NET 8 SDK or newer is required (found $version)." }

# Keep Windows figures byte-for-byte in sync with the canonical macOS grids when
# Python is available. The generated file is also committed for Python-free PCs.
if (Get-Command python -ErrorAction SilentlyContinue) {
    python "tools\sync-pixel-art.py"
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    py -3 "tools\sync-pixel-art.py"
}

$out = Join-Path $PSScriptRoot "dist\Goose-$Runtime"
Remove-Item $out -Recurse -Force -ErrorAction SilentlyContinue

dotnet publish "windows\Goose.Windows.csproj" `
    --configuration Release `
    --runtime $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    --output $out

$zip = Join-Path $PSScriptRoot "dist\Goose-$Runtime.zip"
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$out\*" -DestinationPath $zip
Write-Host "Built $out\DesktopGoose.exe"
Write-Host "Packaged $zip"
