# TOG Multi-Store Magento 2.4.8 (Docker)

This repository contains a Dockerized Magento 2.4.8 Open Source setup prepared for a GCC multi-store (UAE, KSA, Oman, Kuwait), each with two languages (English and Arabic). It uses PHP 8.1, MySQL 8, Redis, and OpenSearch 2.x.

Features
- Multi-store scaffold for UAE, KSA, Oman, Kuwait
- Two store views per country: `en` and `ar`
- SEO-friendly subdomains + language paths, e.g. `uae.localhost/en/` and `uae.localhost/ar/`
- Docker Compose for local development on Windows
- Redis for cache/session, OpenSearch for search
- PowerShell scripts to install Magento and create stores

Prerequisites
- Windows 10/11 with WSL2
- Docker Desktop (with WSL2 backend)
- PowerShell 7+ (recommended)

Quick Start
1. Copy `.env.example` to `.env` and review values (admin user, DB, base URLs).
2. Start services:
   ```powershell
   docker compose up -d
   ```
3. Add hosts file entries (Windows) for local subdomains:
   Edit `C:\Windows\System32\drivers\etc\hosts` as Administrator and add:
   ```
   127.0.0.1   uae.localhost
   127.0.0.1   ksa.localhost
   127.0.0.1   oman.localhost
   127.0.0.1   kuwait.localhost
   ```
4. Install Magento (requires Adobe Marketplace auth keys):
   ```powershell
   ./scripts/magento-install.ps1
   ```
5. Create GCC stores and language views (UAE, KSA, Oman, Kuwait with EN+AR):
   ```powershell
   ./scripts/create-stores.ps1
   ```
   This creates websites for UAE, KSA, Oman, and Kuwait, sets base/default currencies (AED, SAR, OMR, KWD), and two store views per country with locales `en_US` and the appropriate Arabic locale. Base URLs use subdomains; Nginx maps `/en` and `/ar` prefixes to the corresponding Magento store views. Access paths:
   - http://uae.localhost/en/
   - http://uae.localhost/ar/
   - http://ksa.localhost/en/
   - http://ksa.localhost/ar/
   - http://oman.localhost/en/
   - http://oman.localhost/ar/
   - http://kuwait.localhost/en/
   - http://kuwait.localhost/ar/
6. Access the default site root: http://uae.localhost/

Environment Variables
- See `.env` for database, base URL, and credentials.
- Adobe Marketplace keys are required for Composer installation (repo.magento.com). Set them in your PowerShell session before running the install script:
  ```powershell
  $env:MAGENTO_PUBLIC_KEY = "<your-public-key>"
  $env:MAGENTO_PRIVATE_KEY = "<your-private-key>"
  ```

Git & GitHub
- Initialize and push to your GitHub repo:
  ```powershell
  git init
  git remote add origin https://github.com/aligee761/tog-multi-store.git
  git add .
  git commit -m "Initial scaffold: Docker + scripts + multi-store"
  git branch -M main
  git push -u origin main
  ```

Notes
- Magento files will be installed into `src/` by Composer.
- Subdomains + language paths are preconfigured in `nginx/default.conf`. Ensure your hosts file contains the entries above.
- For Arabic (RTL) support in the UI, install Arabic language packs and ensure your theme supports RTL.
