param(
  [string]$ConfigFile = "supabase.local.json"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot $ConfigFile

if (-not (Test-Path -LiteralPath $configPath)) {
  throw "Missing $ConfigFile. Create it from supabase.local.example.json before building a Play release."
}

$config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
foreach ($key in @("SUPABASE_URL", "SUPABASE_ANON_KEY")) {
  $value = [string]$config.$key
  if ([string]::IsNullOrWhiteSpace($value) -or $value -eq "YOUR_SUPABASE_ANON_KEY") {
    throw "$key is missing in $ConfigFile. Refusing to build an offline/mock Play release."
  }
}

Push-Location $projectRoot
try {
  flutter build appbundle --release --dart-define-from-file=$ConfigFile
} finally {
  Pop-Location
}
