#!/usr/bin/env bash
set -euo pipefail

# ——— CONFIG ———
# Change these if you like:
REPO="https://github.com/rahulhaque/soketi-app-manager-filament.git"
INSTALL_DIR="${1:-soketi-app-manager}"
# If you want a custom HTTP port, export APP_PORT before running:
APP_PORT="${APP_PORT:-80}"
# —————————

echo "🚀 Installing Soketi App Manager UI into ./${INSTALL_DIR} …"
git clone "$REPO" "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "📝 Copying example env and injecting APP_PORT=$APP_PORT …"
cp .env.docker.example .env
# substitute only the APP_PORT value; leave others for you to edit later if needed
sed -i "s|APP_PORT=.*|APP_PORT=${APP_PORT}|g" .env

echo "🔧 Building and starting containers…"
docker compose build
docker compose up -d

echo "⏳ Waiting for containers to initialize…"
# give the app container a moment to be ready
sleep 10

echo "📦 Running migrations & seeding database…"
docker compose exec -T soketi-app-manager bash -c "php artisan migrate --seed"

echo
echo "✅ Done! Visit your UI at http://localhost:${APP_PORT}"
echo "   • Default login: admin@email.com / password"
echo
echo "🔑 Don’t forget to secure your .env, change the default password, and point it at your Soketi servers."
