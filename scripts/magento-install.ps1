param(
    [switch]$WithSampleData,
    [switch]$WithArabic
)

$ErrorActionPreference = "Stop"

# Load .env variables
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

# Ensure Docker is up
Write-Host "Starting Docker services..." -ForegroundColor Cyan
pushd (Join-Path $PSScriptRoot "..")
docker compose up -d
popd

# Ensure src exists
$srcPath = Join-Path $PSScriptRoot "..\src"
if (-not (Test-Path $srcPath)) { New-Item -ItemType Directory -Path $srcPath | Out-Null }

# Configure Composer auth inside php container
if (-not $env:MAGENTO_PUBLIC_KEY -or -not $env:MAGENTO_PRIVATE_KEY) {
    Write-Warning "MAGENTO_PUBLIC_KEY and MAGENTO_PRIVATE_KEY are not set in your PowerShell session. Set them before running this script."
    Write-Host "Example:" -ForegroundColor Yellow
    Write-Host "$env:MAGENTO_PUBLIC_KEY = 'xxxx'; $env:MAGENTO_PRIVATE_KEY = 'yyyy'" -ForegroundColor Yellow
    throw "Adobe Marketplace keys are required to install Magento."
}

Write-Host "Configuring Composer auth in container..." -ForegroundColor Cyan
$composerAuthCmd = @(
    'bash','-lc',
    "composer config -g http-basic.repo.magento.com $MAGENTO_PUBLIC_KEY $MAGENTO_PRIVATE_KEY"
)

docker compose exec -e MAGENTO_PUBLIC_KEY="$($env:MAGENTO_PUBLIC_KEY)" -e MAGENTO_PRIVATE_KEY="$($env:MAGENTO_PRIVATE_KEY)" php @composerAuthCmd

# Install Magento if not present
$magentoComposerJson = Join-Path $srcPath "composer.json"
if (-not (Test-Path $magentoComposerJson)) {
    Write-Host "Running Composer create-project for Magento 2.4.8..." -ForegroundColor Cyan
    $createProject = @(
        'bash','-lc',
        "cd /var/www/html && composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition=2.4.8 ."
    )
    docker compose exec php @createProject
}
else {
    Write-Host "Magento composer.json found, skipping create-project." -ForegroundColor Green
}

# Run setup:install
Write-Host "Running Magento setup:install..." -ForegroundColor Cyan
$baseUrl = $envMap['BASE_URL']
$baseUrlSecure = $envMap['BASE_URL_SECURE']
$dbName = $envMap['MYSQL_DATABASE']
$dbUser = $envMap['MYSQL_USER']
$dbPass = $envMap['MYSQL_PASSWORD']
$adminFirst = $envMap['MAGENTO_ADMIN_FIRSTNAME']
$adminLast = $envMap['MAGENTO_ADMIN_LASTNAME']
$adminEmail = $envMap['MAGENTO_ADMIN_EMAIL']
$adminUser = $envMap['MAGENTO_ADMIN_USER']
$adminPass = $envMap['MAGENTO_ADMIN_PASSWORD']

$installCmd = @(
    'bash','-lc',
    @"
cd /var/www/html && \
php -d memory_limit=-1 bin/magento setup:install \
 --base-url=$baseUrl \
 --base-url-secure=$baseUrlSecure \
 --db-host=db --db-name=$dbName --db-user=$dbUser --db-password=$dbPass \
 --admin-firstname=$adminFirst --admin-lastname=$adminLast \
 --admin-email=$adminEmail --admin-user=$adminUser --admin-password=$adminPass \
 --backend-frontname=admin \
 --language=en_US --currency=AED --timezone=Asia/Dubai \
 --use-rewrites=1 \
 --search-engine=opensearch --opensearch-host=opensearch --opensearch-port=9200 \
 --session-save=redis \
 --session-save-redis-host=redis --session-save-redis-port=6379 \
 --cache-backend=redis --cache-backend-redis-server=redis --cache-backend-redis-port=6379 \
 --page-cache=redis --page-cache-redis-server=redis --page-cache-redis-port=6379
"@
)

try {
    docker compose exec php @installCmd
}
catch {
    Write-Warning "setup:install may have already been run. Attempting to continue... $_"
}

# Optional: sample data
if ($WithSampleData) {
    Write-Host "Deploying sample data..." -ForegroundColor Cyan
    $sampleCmd = @(
        'bash','-lc',
        "cd /var/www/html && php -d memory_limit=-1 bin/magento sampledata:deploy && php -d memory_limit=-1 bin/magento setup:upgrade"
    )
    docker compose exec php @sampleCmd
}

# Optional: Arabic language pack and static content
if ($WithArabic) {
    Write-Host "Installing Arabic (ar_SA) language pack and deploying static content..." -ForegroundColor Cyan
    $langInstall = @(
        'bash','-lc',
        @"
cd /var/www/html && \
composer require magento2translations/language_ar_sa:* --no-interaction && \
php -d memory_limit=-1 bin/magento setup:upgrade && \
php -d memory_limit=-1 bin/magento setup:static-content:deploy -f en_US ar_SA
"@
    )
    docker compose exec php @langInstall
}

# Dev mode and indexers
$finalizeCmd = @(
    'bash','-lc',
    "cd /var/www/html && bin/magento deploy:mode:set developer && bin/magento indexer:reindex && bin/magento cache:flush"
)
docker compose exec php @finalizeCmd

Write-Host "Magento installation completed." -ForegroundColor Green
