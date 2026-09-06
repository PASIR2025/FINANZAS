# Publicar PASIR Gestión V5.0.0 en GitHub Pages

## GitHub Actions
El proyecto incluye `.github/workflows/deploy-pages.yml`.

1. Sube **todo el contenido** de esta carpeta a la raíz del repositorio.
2. Settings → Pages → Source: **GitHub Actions**.
3. Espera que finalice el workflow.
4. Abre primero `ACTUALIZAR-V5.0.0.html` en dispositivos que ya tenían V4.x instalada.
5. Luego abre la URL normal y confirma `V5.0.0` en la parte inferior.

## Importante
No subas solo `index.html`. Deben publicarse juntos el JS V5, Service Worker, manifest, CSS, iconos y demás archivos.

Cuando Supabase está conectado, Supabase es la fuente central y el almacenamiento del navegador funciona como caché/offline. Antes de una actualización importante, crea un respaldo JSON.
