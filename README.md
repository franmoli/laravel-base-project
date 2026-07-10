# Template Laravel

Template reutilizable para arrancar proyectos Laravel nuevos, con:

- Entorno de desarrollo local 100% dockerizado con [Laravel Sail](https://laravel.com/docs/sail) (app + MySQL + Mailpit).
- Gate de tests obligatorio, tanto local (git hooks con [CaptainHook](https://captainhook.info/)) como en CI (GitHub Actions).
- Pipeline de CI/CD que hace build de los assets y despliega por SSH a **Hostinger (hPanel, hosting compartido)** en cada push a `main`.

Para usar este template en un proyecto nuevo: botón **"Use this template"** en GitHub (o `gh repo create --template <owner>/<repo> nuevo-proyecto`).

## Setup local

**Único requisito: Docker (+ Docker Compose).** No hace falta PHP, Composer ni Node instalados en el host — todo, incluyendo el bootstrap inicial, corre en contenedores. Esto es intencional: cualquier dev nuevo tiene que poder levantar el proyecto con una instalación mínima de Docker, nada más.

### Arranque en un solo comando

```bash
./start.sh          # Linux / macOS / WSL2
start.bat            # Windows (delega en WSL2, ver nota más abajo)
```

`start.sh` es idempotente — se puede correr las veces que haga falta:

1. Crea `.env` desde `.env.example` si no existe.
2. Si no existe `./vendor/bin/sail` todavía, instala las dependencias de Composer con un contenedor descartable de `composer:2` (sin depender de PHP en el host).
3. Levanta los contenedores (`sail up -d`) y espera a que MySQL pase el healthcheck.
4. Genera `APP_KEY` si falta, corre las migraciones.
5. Instala dependencias de Node si falta `node_modules`.
6. Deja corriendo `sail npm run dev` (Vite) en primer plano — `Ctrl+C` corta solo el watcher, los contenedores siguen arriba (`./vendor/bin/sail down` para apagarlos del todo).

La app queda en `http://localhost`. Mailpit (para ver los mails enviados en dev) queda en `http://localhost:8025`.

#### Instalación en Windows

Laravel Sail solo corre sobre **WSL2** en Windows (Docker Desktop expone el motor ahí, no en Windows nativo). `start.bat` delega la ejecución real a `start.sh` dentro de tu distro de WSL2, pero primero necesitás:

1. Instalar WSL2 desde PowerShell como administrador: `wsl --install` (reiniciar al terminar).
2. En Docker Desktop → Settings → General, activar **"Use the WSL 2 based engine"**; en Settings → Resources → WSL Integration, habilitar la integración con tu distro.
3. Clonar el repo **dentro del filesystem de Linux** de WSL2 (`~/proyectos/...`), no en `/mnt/c/...` — trabajar sobre la unidad de Windows montada degrada I/O severamente y puede romper Vite/Artisan.
4. Correr `start.bat` (o directamente `./start.sh` desde una terminal de WSL2, que es lo mismo).

Si ves el error `error getting credentials` al levantar Sail desde WSL2: editá `~/.docker/config.json` dentro de la distro y reemplazá el contenido por `{}` (elimina la clave `credsStore`, que apunta a un helper que no existe ahí).

### Paso a paso manual (equivalente a lo que hace `start.sh`)

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

### Comandos útiles

> Los ejemplos usan `sail` a secas — si no querés escribir `./vendor/bin/sail` cada vez, agregá `alias sail='[ -f sail ] && sh sail || sh vendor/bin/sail'` a tu `~/.bashrc` / `~/.zshrc`.

| Comando | Descripción |
|---|---|
| `sail up -d` | Levanta los contenedores en segundo plano |
| `sail down` | Detiene y elimina los contenedores |
| `sail down -v` | Ídem, y borra también el volumen de MySQL (reset total de la DB) |
| `sail restart` | Reinicia los contenedores |
| `sail artisan migrate` | Ejecuta las migraciones |
| `sail artisan migrate:fresh --seed` | Reinicia la base de datos y ejecuta los seeders |
| `sail artisan tinker` | Consola interactiva de Laravel |
| `sail npm run dev` | Compila los assets en modo desarrollo (watch) |
| `sail npm run build` | Compila los assets para producción |
| `sail logs -f` | Logs de los contenedores en tiempo real |
| `sail shell` / `sail bash` | Abre una shell dentro del contenedor de la app |
| `sail mysql` | Consola de MySQL |
| `sail composer install` | Dependencias de PHP (ya dentro del contenedor) |
| `sail npm install` | Dependencias de Node |
| `sail test` | Corre la suite de tests (`php artisan test`) |
| `sail pint --test` | Chequeo de estilo (Pint), sin corregir |
| `sail pint` | Corrige el estilo automáticamente |
| `sail php ./vendor/bin/phpstan analyse` | Análisis estático (Larastan) |
| `sail artisan down` / `sail artisan up` | Activa / sale del modo mantenimiento |
| `sail artisan optimize:clear` | Limpia todos los cachés |
| `./local-url.sh` | Apunta el proyecto a la IP local actual (acceso desde el celular, etc.) |
| `./local-url.sh --reset` | Vuelve a `http://localhost` |

> **Puerto 3306 ocupado**: si tenés un MySQL local corriendo en el host, va a chocar con el `mysql` de Sail. Frenalo antes de levantar los contenedores (`sudo systemctl stop mysql` en Linux, `sudo service mysql stop` en WSL2) o cambiá `FORWARD_DB_PORT` en tu `.env`.

### Acceso desde otros dispositivos de la red local

Como en un entorno local es común que la IP de la máquina cambie (reinicios, redes distintas, etc.), el template trae un comando para apuntar el proyecto a la IP actual y poder abrirlo desde el celular u otro equipo de la misma red:

```bash
./local-url.sh                  # autodetecta la IP del host y la aplica
./local-url.sh 192.168.1.50     # o la pasás a mano
./local-url.sh --reset          # vuelve a http://localhost
```

En Windows: `local-url.bat` (misma idea, delega en WSL2).

Esto actualiza `APP_URL` y `VITE_HOST` en `.env`, y limpia la config cacheada. Con eso:

- La app queda accesible en `http://<tu-ip>` desde cualquier dispositivo de la misma red.
- `vite.config.js` usa `VITE_HOST` para que Vite escuche en todas las interfaces y le diga al navegador la IP correcta para el cliente de HMR (sin esto, el celular intentaría conectar el HMR a "localhost", que en el celular es él mismo, no tu máquina) — ver comentario en `vite.config.js`.
- Si `sail npm run dev` ya estaba corriendo, hay que reiniciarlo para que tome el nuevo host.

**Por qué es un script del host y no directamente `sail artisan app:local-url`**: el comando Artisan (`app/Console/Commands/SetLocalUrl.php`) corre dentro del contenedor si se invoca vía `sail`, y ahí solo ve la IP interna de Docker, no la IP real de la red local — por eso la detección de IP vive en `local-url.sh` (que corre en el host) y le pasa el resultado al comando Artisan. Si preferís, también podés pasarle la IP vos mismo: `sail artisan app:local-url 192.168.1.50`.

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
