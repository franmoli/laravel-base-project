#!/usr/bin/env bash

# Detecta la IP local del HOST (no la del contenedor) y actualiza
# APP_URL/VITE_HOST via `php artisan app:local-url`, para poder acceder
# al proyecto desde otros dispositivos de la misma red (celular, etc).
#
# La detección tiene que correr en el host: un comando artisan corriendo
# adentro del contenedor (`sail artisan app:local-url`) solo ve la IP
# interna de Docker, no la IP real de la red local.
#
# Uso:
#   ./local-url.sh            # autodetecta y aplica
#   ./local-url.sh 192.168.1.50   # usa una IP puntual
#   ./local-url.sh --reset    # vuelve a http://localhost

set -e

cd "$(dirname "$0")"

SAIL="./vendor/bin/sail"

if [ "$1" = "--reset" ]; then
    "$SAIL" artisan app:local-url --reset
    exit $?
fi

if [ -n "$1" ]; then
    IP="$1"
elif grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL2: Docker Desktop expone los contenedores a través de la red de
    # Windows, así que la IP que hay que anunciar es la del host Windows,
    # no la de la interfaz virtual de WSL2.
    IP="$(ipconfig.exe 2>/dev/null | grep -A 5 'Wi-Fi\|Ethernet adapter' | grep 'IPv4' | awk -F': ' '{print $2}' | tr -d '\r' | grep -v '^169\.254\.' | head -n1)"
elif [ "$(uname -s)" = "Darwin" ]; then
    IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)"
else
    IP="$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')"
    [ -z "$IP" ] && IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi

if [ -z "$IP" ]; then
    echo "No se pudo detectar la IP local automáticamente."
    echo "Pasala a mano: ./local-url.sh 192.168.1.50"
    exit 1
fi

echo "==> IP local detectada: $IP"
"$SAIL" artisan app:local-url "$IP"
