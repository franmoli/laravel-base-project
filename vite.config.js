import { defineConfig, loadEnv } from 'vite';
import laravel from 'laravel-vite-plugin';
import { bunny } from 'laravel-vite-plugin/fonts';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig(({ mode }) => {
    // VITE_HOST lo setea `php artisan app:local-url` (o `local-url.sh`) para
    // que se pueda acceder al proyecto desde otros dispositivos de la red
    // local (celular, etc). Sin esto, el cliente de HMR intenta conectar a
    // "localhost", que en el celular no apunta a esta máquina.
    const env = loadEnv(mode, process.cwd());

    return {
        plugins: [
            laravel({
                input: ['resources/css/app.css', 'resources/js/app.js'],
                refresh: true,
                fonts: [
                    bunny('Instrument Sans', {
                        weights: [400, 500, 600],
                    }),
                ],
            }),
            tailwindcss(),
        ],
        server: {
            ...(env.VITE_HOST ? {
                host: '0.0.0.0',
                hmr: { host: env.VITE_HOST },
            } : {}),
            watch: {
                ignored: ['**/storage/framework/views/**'],
            },
        },
    };
});
