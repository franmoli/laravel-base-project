# Template Laravel

Template reutilizable para arrancar proyectos Laravel nuevos, con:

- Entorno de desarrollo local 100% dockerizado con [Laravel Sail](https://laravel.com/docs/sail) (app + MySQL + Mailpit).
- Gate de tests obligatorio, tanto local (git hooks con [CaptainHook](https://captainhook.info/)) como en CI (GitHub Actions).
- Pipeline de CI/CD que hace build de los assets y despliega por SSH a **Hostinger (hPanel, hosting compartido)** en cada push a `main`.

Para usar este template en un proyecto nuevo: botón **"Use this template"** en GitHub (o `gh repo create --template <owner>/<repo> nuevo-proyecto`).

## Setup local

**Único requisito: Docker (+ Docker Compose).** No hace falta PHP, Composer ni Node instalados en el host — todo, incluyendo el bootstrap inicial, corre en contenedores. Esto es intencional: cualquier dev nuevo tiene que poder levantar el proyecto con una instalación mínima de Docker, nada más.

```bash
cp .env.example .env

# Bootstrap: instala las dependencias de Composer sin necesitar PHP en el host
# (necesario una sola vez, antes de que exista ./vendor/bin/sail)
docker run --rm \
    -u "$(id -u):$(id -g)" \
    -v "$(pwd):/var/www/html" \
    -w /var/www/html \
    composer:2 composer install --ignore-platform-reqs

./vendor/bin/sail up -d
./vendor/bin/sail artisan key:generate
./vendor/bin/sail artisan migrate
./vendor/bin/sail npm install
./vendor/bin/sail npm run dev
```

La app queda en `http://localhost`. Mailpit (para ver los mails enviados en dev) queda en `http://localhost:8025`.

Comandos frecuentes:

```bash
sail artisan test          # correr tests
sail artisan tinker
sail down                  # apagar los contenedores
```

## Git hooks (CaptainHook)

Se instalan solos con el `composer install` del bootstrap (plugin `captainhook/plugin-composer`). Configuración en [`captainhook.json`](./captainhook.json):

- **pre-commit**: corre `pint --test` (chequeo de estilo, rápido).
- **pre-push**: corre la suite completa de tests (`php artisan test`). Si falla, bloquea el push.

Importante: los hooks **corren dentro del contenedor `laravel.test`**, no en el host (`captainhook.json` → `config.run.mode: "docker"`, ejecuta vía `./vendor/bin/sail exec laravel.test`). Esto es lo que permite que un dev nuevo nunca necesite PHP instalado localmente — pero como contrapartida, **Sail tiene que estar levantado (`sail up -d`) para poder commitear o pushear**; si los contenedores están abajo, el hook falla con `service "laravel.test" is not running` en vez de silenciosamente saltarse el chequeo.

Si necesitás saltarte un hook puntualmente: `git commit --no-verify` / `git push --no-verify`. Igual te va a frenar el gate de CI, así que solo tiene sentido para iterar localmente.

## CI (GitHub Actions)

`.github/workflows/ci.yml`, job `tests`: corre en cada push/PR a `main` — Pint, Larastan (análisis estático) y la suite de tests contra un MySQL de servicio. El job `deploy` depende de `tests` (`needs: tests`), así que nunca se despliega código que no pasa el gate.

## Deploy a Hostinger (hPanel, shared hosting)

hPanel expone `public_html` como webroot fijo: no se puede symlinkear ni cambiar el document root. Por eso el repo entero (con `vendor/` incluido) vive clonado directamente dentro de `public_html/`, y el [`.htaccess`](./.htaccess) en la raíz reescribe todo el tráfico hacia `public/`:

```apache
Options +FollowSymLinks
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/public/
    RewriteRule ^(.*)$ public/$1 [L]
</IfModule>
```

El deploy (job `deploy` en `ci.yml`) en cada push a `main`:

1. Buildea los assets de Vite en el runner de CI (Hostinger shared hosting no tiene Node).
2. Sube `public/build/` por `rsync` (está gitignored, así que no llega con el `git pull`).
3. Por SSH, en el servidor: modo mantenimiento → `git pull origin main --ff-only` → `composer install --no-dev` → `migrate --force` → cache de config/route/view → `queue:restart` → salir de mantenimiento.

### Setup inicial en Hostinger (una sola vez, manual)

1. En hPanel: habilitar acceso SSH, anotar host/usuario/puerto.
2. Crear la base de datos MySQL y anotar usuario/password/nombre de la base.
3. Confirmar en hPanel la versión de PHP (fijar la misma que usa este template, ver `composer.json` → `config.platform.php`) y el nombre del binario de Composer disponible por SSH (`composer` o `composer2`, varía según el plan).
4. Generar un par de claves SSH para el deploy y agregar la **pública** como "Deploy key" en el repo de GitHub (Settings → Deploy keys) o como clave autorizada del usuario SSH de Hostinger, según cómo se configure el `git pull` remoto.
5. Por SSH al servidor: clonar el repo dentro de `public_html/` (si ya tiene contenido del panel, vaciarlo antes o inicializar el repo ahí con `git init` + `remote add` + `pull`).
6. Crear a mano el `.env` de producción dentro de `public_html/` (queda gitignored — el pipeline nunca lo toca ni lo sobreescribe).
7. Dar permisos de escritura a `storage/` y `bootstrap/cache/` (`chmod -R` para el usuario de PHP-FPM).

### Secrets a cargar en GitHub (Settings → Secrets and variables → Actions)

| Secret | Descripción |
|---|---|
| `SSH_HOST` | Host/IP de Hostinger |
| `SSH_PORT` | Puerto SSH |
| `SSH_USER` | Usuario SSH |
| `SSH_KEY` | Clave privada SSH de deploy |
| `DEPLOY_PATH` | Ruta absoluta a `public_html` en el servidor (ej. `/home/usuario/domains/midominio.com/public_html`) |

## Base de datos

MySQL, corriendo dockerizado en desarrollo (servicio `mysql` de Sail, con volumen persistente) y nativo en Hostinger en producción.
