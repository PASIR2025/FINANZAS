# Publicar PASIR Gestión en GitHub Pages

## Opción recomendada — GitHub Actions

Este proyecto ya incluye `.github/workflows/deploy-pages.yml`.

1. Crea o abre tu repositorio en GitHub.
2. Sube todos los archivos de esta carpeta a la **raíz** del repositorio.
3. En GitHub entra a **Settings → Pages**.
4. En **Build and deployment → Source**, selecciona **GitHub Actions**.
5. Ve a **Actions** y espera que termine `Deploy PASIR PWA to GitHub Pages`.
6. En **Settings → Pages** aparecerá la dirección publicada.
7. Abre esa dirección en Chrome o Edge. PASIR podrá instalarse como PWA.

## Si prefieres “Deploy from a branch”

También funciona porque la app es totalmente estática:

1. Settings → Pages.
2. Source: **Deploy from a branch**.
3. Branch: `main`.
4. Folder: `/ (root)`.
5. Guardar.

Si usas este método y no quieres GitHub Actions, puedes eliminar `.github/workflows/deploy-pages.yml`.

## Datos

Los datos financieros y de gestión se guardan actualmente en el navegador de cada dispositivo. No borres los datos del sitio sin antes usar **Configuración → Exportar respaldo JSON**.
