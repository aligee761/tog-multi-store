# TOG Multi-Store Magento 2.4.8 (Docker)

This repository contains a Dockerized Magento 2.4.8 Open Source setup prepared for a GCC multi-store (UAE, KSA, Oman, Kuwait, Qatar). It uses PHP 8.1, MySQL 8, Redis, and OpenSearch 2.x.

Features
- Multi-store scaffold for UAE, KSA, Oman, Kuwait, Qatar
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
3. Install Magento (requires Adobe Marketplace auth keys):
   ```powershell
   ./scripts/magento-install.ps1
   ```
4. Create GCC stores (UAE, KSA, Oman, Kuwait, Qatar):
   ```powershell
   ./scripts/create-stores.ps1
   ```
5. Access the site at: http://localhost/

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
- If you prefer per-store subdomains locally (e.g., `uae.localhost`), update Nginx and `hosts` accordingly.
- For Arabic (RTL) support, add Arabic language packs and enable per store view.
