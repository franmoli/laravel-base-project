<?php

namespace App\Console\Commands;

use Illuminate\Console\Attributes\Description;
use Illuminate\Console\Attributes\Signature;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Artisan;

#[Signature('app:local-url {ip? : IP local a usar (ej. 192.168.1.50)} {--reset : Volver a http://localhost}')]
#[Description('Actualiza APP_URL/VITE_HOST en .env para acceder al proyecto desde otros dispositivos de la red local')]
class SetLocalUrl extends Command
{
    public function handle(): int
    {
        if (app()->isProduction()) {
            $this->error('Este comando no puede ejecutarse en producción.');

            return self::FAILURE;
        }

        $envPath = base_path('.env');

        if (! file_exists($envPath)) {
            $this->error('Archivo .env no encontrado.');

            return self::FAILURE;
        }

        if ($this->option('reset')) {
            $this->writeEnv($envPath, 'localhost');
            $this->info('APP_URL reseteado a: http://localhost');

            return self::SUCCESS;
        }

        $ip = $this->argument('ip') ?: $this->detectLocalIp();

        if (! $ip) {
            $this->error('No se pudo detectar la IP local automáticamente.');
            $this->line('Pasala como argumento: sail artisan app:local-url 192.168.1.50');

            return self::FAILURE;
        }

        if (! filter_var($ip, FILTER_VALIDATE_IP) && $ip !== 'localhost') {
            $this->error("«{$ip}» no parece una IP válida.");

            return self::FAILURE;
        }

        $this->writeEnv($envPath, $ip);

        $this->info("APP_URL actualizado a: http://{$ip}");
        $this->line("Accedé desde cualquier dispositivo de la misma red (ej. el celular) a: http://{$ip}");
        $this->newLine();
        $this->warn("Si tenías 'sail npm run dev' corriendo, reinicialo para que Vite tome el nuevo host (Ctrl+C y volver a correrlo).");

        return self::SUCCESS;
    }

    private function writeEnv(string $envPath, string $host): void
    {
        $env = file_get_contents($envPath);
        $env = preg_replace('/^APP_URL=.*/m', 'APP_URL=http://'.$host, $env);
        $env = $this->setOrAppend($env, 'VITE_HOST', $host === 'localhost' ? '' : $host);
        file_put_contents($envPath, $env);

        Artisan::call('config:clear');
    }

    private function setOrAppend(string $env, string $key, string $value): string
    {
        if (preg_match('/^'.preg_quote($key, '/').'=.*/m', $env)) {
            return preg_replace('/^'.preg_quote($key, '/').'=.*/m', "{$key}={$value}", $env);
        }

        return rtrim($env).PHP_EOL."{$key}={$value}".PHP_EOL;
    }

    /**
     * Intenta autodetectar la IP local del host.
     *
     * Ojo: si este comando corre dentro de un contenedor Docker (ej. via
     * `sail artisan app:local-url`), esto detecta la IP interna del
     * contenedor, no la del host físico visible en la red local. Para uso
     * dentro de Sail, pasá la IP como argumento (la detecta bien el
     * script `local-url.sh` del host, pensado justamente para esto).
     */
    private function detectLocalIp(): ?string
    {
        if (file_exists('/.dockerenv')) {
            return null;
        }

        $output = shell_exec("hostname -I 2>/dev/null | awk '{print $1}'");

        if ($output) {
            return trim($output);
        }

        $output = shell_exec('ipconfig getifaddr en0 2>/dev/null');

        return $output ? trim($output) : null;
    }
}
