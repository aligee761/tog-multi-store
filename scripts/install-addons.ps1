$ErrorActionPreference = "Stop"

Write-Host "Ensuring Docker services are running..." -ForegroundColor Cyan
pushd (Join-Path $PSScriptRoot "..")
docker compose up -d
popd

# Inside-container bash routine to install all addons from /var/www/addons
$installScript = @(
  'bash','-lc',
  @'
set -euo pipefail
cd /var/www/html

mkdir -p /tmp/addons-work
mkdir -p app/code

found=0
shopt -s globstar nullglob
for z in /var/www/addons/**/*.zip; do
  echo "Processing $z"
  found=1
  workdir="/tmp/addons-work/$(basename "$z" .zip)"
  rm -rf "$workdir" && mkdir -p "$workdir"
  unzip -q "$z" -d "$workdir"

  # Case A: archive contains app/code structure
  if [ -d "$workdir/app/code" ]; then
    echo "Detected app/code structure, merging into project..."
    rsync -a "$workdir/app/code/" "/var/www/html/app/code/"
    continue
  fi

  # Case B: find module roots (directories that contain registration.php and etc/module.xml)
  while IFS= read -r -d '' moddir; do
    echo "Detected Magento module at $moddir"
    # Determine Vendor/Module name by directory path under moddir
    vendor=$(basename "$(dirname "$moddir")")
    module=$(basename "$moddir")

    # If directory name looks like Vendor_Module, split
    if [[ "$vendor" == *_* && "$module" == "etc" ]]; then
      # when structure is Vendor_Module/etc/module.xml under a single folder
      combo="$vendor"
      vendor="${combo%%_*}"
      module="${combo#*_}"
      modroot="$(dirname "$moddir")"
    else
      modroot="$(dirname "$moddir")"
    fi

    target="/var/www/html/app/code/$vendor/$module"
    mkdir -p "$(dirname "$target")"
    rsync -a "$modroot/" "$target/"
  done < <(find "$workdir" -type f -path '*/etc/module.xml' -print0)

done

if [ "$found" -eq 0 ]; then
  echo "No ZIP files found under /var/www/addons/. Nothing to install."
  exit 0
fi

# Discover modules under app/code and enable them
mods=$(php -r 'foreach (glob("app/code/*/*/etc/module.xml") as $f){$xml=simplexml_load_file($f); $name=(string)$xml->module["name"]; echo $name,PHP_EOL; }')

if [ -n "$mods" ]; then
  echo "Enabling modules:"; echo "$mods"
  php -d memory_limit=-1 bin/magento module:enable $mods || true
else
  echo "No modules discovered under app/code."
fi

php -d memory_limit=-1 bin/magento setup:upgrade
php -d memory_limit=-1 bin/magento setup:di:compile
php -d memory_limit=-1 bin/magento setup:static-content:deploy -f en_US ar_SA
php -d memory_limit=-1 bin/magento indexer:reindex
php -d memory_limit=-1 bin/magento cache:flush

echo "Addon installation complete."
'@
)

docker compose exec php @installScript

Write-Host "All addons processed and Magento updated." -ForegroundColor Green
