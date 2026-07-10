#!/usr/bin/env bash

# Levanta el proyecto completo con un solo comando: bootstrap de Composer
# (si hace falta), containers de Sail, migraciones, dependencias de Node
# y el watcher de Vite. Pensado para no requerir PHP/Composer/Node en el
# host: solo Docker.
#
# Uso: ./start.sh

set -e

cd "$(dirname "$0")"

SAIL="./vendor/bin/sail"

if [ ! -f .env ]; then
    echo "==> Creando .env a partir de .env.example"
    cp .env.example .env
fi

if [ ! -f "$SAIL" ]; then
    echo "==> Instalando dependencias de Composer (contenedor descartable, sin PHP en el host)"
    docker run --rm \
        -u "$(id -u):$(id -g)" \
        -v "$(pwd):/var/www/html" \
        -w /var/www/html \
        composer:2 composer install --ignore-platform-reqs
fi

echo "==> Levantando contenedores (sail up -d)"
"$SAIL" up -d

echo "==> Esperando a que MySQL esté listo (healthcheck)"
export WWWUSER="${WWWUSER:-$(id -u)}"
export WWWGROUP="${WWWGROUP:-$(id -g)}"
until [ "$(docker compose ps -q mysql 2>/dev/null | xargs -r docker inspect -f '{{.State.Health.Status}}' 2>/dev/null)" = "healthy" ]; do
    sleep 2
done

if ! grep -q '^APP_KEY=base64:' .env; then
    echo "==> Generando APP_KEY"
    "$SAIL" artisan key:generate
fi

echo "==> Corriendo migraciones"
"$SAIL" artisan migrate --force

if [ ! -d node_modules ]; then
    echo "==> Instalando dependencias de Node"
    "$SAIL" npm install
fi

echo "==> Listo. La app está en http://localhost (Mailpit en http://localhost:8025)"
echo "==> Arrancando Vite (Ctrl+C para salir; los contenedores siguen corriendo, usá './vendor/bin/sail down' para apagarlos)"
"$SAIL" npm run dev
