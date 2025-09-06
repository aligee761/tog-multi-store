$ErrorActionPreference = "Stop"

Write-Host "Ensuring Docker services are running..." -ForegroundColor Cyan
pushd (Join-Path $PSScriptRoot "..")
docker compose up -d
popd

<#
  Load BASE_URL and BASE_URL_SECURE from .env so we can pass them into
  the container environment for the PHP helper script.
#>
$envPath = Join-Path $PSScriptRoot "..\.env"
if (-not (Test-Path $envPath)) { throw ".env not found at $envPath" }
$envContent = Get-Content $envPath | Where-Object { $_ -match '=' -and -not $_.StartsWith('#') }
$envMap = @{}
foreach ($line in $envContent) {
    $kv = $line -split '=',2
    $key = $kv[0].Trim()
    $val = $kv[1].Trim()
    if ($key) { $envMap[$key] = $val }
}
$baseUrl = $envMap['BASE_URL']
$baseUrlSecure = $envMap['BASE_URL_SECURE']
if (-not $baseUrl) { $baseUrl = 'http://localhost/' }
if (-not $baseUrlSecure) { $baseUrlSecure = 'https://localhost/' }

# Run the store creation script using container's PHP
Write-Host "Creating GCC stores (UAE, KSA, Oman, Kuwait, Qatar)..." -ForegroundColor Cyan
$runScript = @(
  'bash','-lc',
  "php -d memory_limit=-1 /var/www/html/tools/create-stores.php"
)
docker compose exec -e BASE_URL="$baseUrl" -e BASE_URL_SECURE="$baseUrlSecure" php @runScript

# Reindex & flush cache
$afterCmd = @(
  'bash','-lc',
  "cd /var/www/html && bin/magento indexer:reindex && bin/magento cache:flush"
)
docker compose exec php @afterCmd

Write-Host "Stores created and cache flushed." -ForegroundColor Green
