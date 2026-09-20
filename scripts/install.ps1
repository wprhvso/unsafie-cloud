$ErrorActionPreference = 'Stop'
$Repo = "wprhvso/unsafie-cloud"

try {
    $Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
    $Asset = $Release.assets | Where-Object { $_.name -like "*windows-x86_64*.zip" -or $_.name -like "*windows-x86_64*.exe" } | Select-Object -First 1
    $DownloadUrl = $Asset.browser_download_url
} catch {
    $DownloadUrl = "https://github.com/$Repo/releases/latest/download/unsafie-windows-x86_64.exe"
}

$InstallDir = "$env:ProgramFiles\Unsafie"
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
$Dest = Join-Path $InstallDir "unsafie.exe"

Write-Host "Downloading Unsafie Cloud..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $Dest

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
}

Write-Host "Unsafie Cloud installed successfully to $Dest"
