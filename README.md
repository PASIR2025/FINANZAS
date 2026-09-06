# PASIR Gestión / Escuela PASIR — V5.0.0

Esta carpeta es el proyecto COMPLETO para GitHub Pages.

## Para actualizar la PWA existente

1. Haz una copia de seguridad de tu repositorio actual.
2. Reemplaza el contenido publicado del repositorio por TODO el contenido de esta carpeta V5.0.0.
3. En Supabase SQL Editor ejecuta UNA SOLA VEZ: `SUPABASE-MIGRACION-V5.0.0.sql`.
4. NO ejecutes de nuevo el schema completo y NO ejecutes los SQL dentro de `historico-v4/`.
5. Publica GitHub Pages y abre `ACTUALIZAR-V5.0.0.html` una vez si necesitas forzar la limpieza de una PWA instalada con caché antiguo.

## Runtime V5

- `index.html`
- `assets/js/app-v5.0.0.js` — único JavaScript de aplicación
- `assets/css/styles.css`
- `service-worker.js`
- `manifest.webmanifest`
- `assets/icons/`

Los archivos V4 se guardan únicamente en `historico-v4/` como referencia y no son cargados por `index.html` ni por el Service Worker.
