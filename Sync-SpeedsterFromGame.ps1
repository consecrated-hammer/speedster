param(
    [string]$Source = "D:\stuff\games\battlenet\World of Warcraft\_anniversary_\Interface\AddOns\Speedster",
    [string]$Target = "D:\stuff\games\MyAddons\Speedster"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $Source)) { throw "Missing source: $Source" }
New-Item -ItemType Directory -Force -Path $Target | Out-Null
Copy-Item -Path (Join-Path $Source '*') -Destination $Target -Recurse -Force
Write-Host "Synced Speedster source to repo: $Target"
