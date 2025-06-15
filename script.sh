#!/usr/bin/env bash
set -euo pipefail

# Interactive one-click installer for Soketi-UI (multi-app dashboard)
# Prompts for all required installation details and allows adding multiple Soketi apps.

# 1. Gather user input
read -rp "Install directory (default: soketi-ui): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-soketi-ui}

read -rp "HTTP port for UI (default: 80): " APP_PORT
APP_PORT=${APP_PORT:-80}

read -rp "MySQL root password: " MYSQL_ROOT_PASSWORD
read -rp "App database name (default: soketidb): " MYSQL_DATABASE
MYSQL_DATABASE=${MYSQL_DATABASE:-soketidb}
read -rp "App DB user (default: soketi): " MYSQL_USER
MYSQL_USER=${MYSQL_USER:-soketi}
read -rp "App DB password: " MYSQL_PASSWORD

# 2. Gather multiple Soketi apps
echo -e "\nEnter details for your Soketi apps. To stop adding, leave App ID blank and press Enter."
declare -a APP_IDS APP_KEYS APP_SECRETS
while true; do
  read -rp "Soketi App ID: " APP_ID
  [[ -z "$APP_ID" ]] && break
  read -rp "Soketi Key for $APP_ID: " APP_KEY
  read -rp "Soketi Secret for $APP_ID: " APP_SECRET
  APP_IDS+=("$APP_ID")
  APP_KEYS+=("$APP_KEY")
  APP_SECRETS+=("$APP_SECRET")
done

# 3. Clone installer repo and enter directory
echo "\n🚀 Cloning Soketi-UI installer into ./${INSTALL_DIR}..."
git clone https://github.com/Sirimewan25/Soketi-Ui-One-CLick-Installer.git "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 4. Write environment file
echo "\n📝 Writing .env with your configuration..."
cat > .env <<EOF
APP_PORT=${APP_PORT}

# Database settings
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=${MYSQL_DATABASE}
DB_USERNAME=${MYSQL_USER}
DB_PASSWORD=${MYSQL_PASSWORD}
EOF

# Append Soketi apps JSON
# Build JSON array of apps
APPS_JSON="["
for i in "${!APP_IDS[@]}"; do
  APPS_JSON+="{\"id\":\"${APP_IDS[$i]}\",\"key\":\"${APP_KEYS[$i]}\",\"secret\":\"${APP_SECRETS[$i]}\"},"
done
APPS_JSON=\"${APPS_JSON%,}]\"
# Add to .env
cat >> .env <<EOF

# Soketi apps configuration (JSON array)
SOKETI_APPS_JSON='${APPS_JSON}'
EOF

# 5. Build & start services
echo "\n🔧 Building and launching containers..."
docker-compose up -d --build

# 6. Migrate database and seed included apps
echo "\n⏳ Running migrations & seeding database..."
docker-compose exec -T app php artisan migrate --seed

# 7. Import apps into UI (if supported)
# Loop through apps and seed into the dashboard via artisan commands
for i in "${!APP_IDS[@]}"; do
  echo "Seeding Soketi app ${APP_IDS[$i]} into UI..."
  docker-compose exec -T app php artisan soketi:register-app \
    --id="${APP_IDS[$i]}" \
    --key="${APP_KEYS[$i]}" \
    --secret="${APP_SECRETS[$i]}"
done || true

# 8. Completion message
echo -e "\n✅ Installation complete!"
echo "Visit the UI at http://localhost:${APP_PORT}"
