# PASIR Gestión — PWA

Aplicación web progresiva (PWA) de **Escuela PASIR** para finanzas, cursos, proyectos, metas, ventas y rentabilidad.

## Esta versión

- Basada en PASIR Gestión V4.1 y convertida a PWA V4.3.
- No necesita `npm`, Node.js ni compilación.
- Lista para publicar como sitio estático en GitHub Pages.
- Instalable en Android/Windows desde Chrome o Edge una vez publicada por HTTPS.
- Funciona sin conexión después de la primera carga gracias al Service Worker.
- Incluye **Información comercial**: fichas por producto, mensajes para WhatsApp, temario, beneficios, precio, medios de pago, FAQ y botones de copiar.
- Incluye **Respuestas rápidas** generales reutilizables.
- Los datos de esta versión se guardan en `localStorage` del navegador/dispositivo.

> Importante: esta versión todavía **no sincroniza datos entre dispositivos**. Para eso la siguiente etapa es conectar Supabase/autenticación y migrar el almacenamiento local a base de datos.

## Estructura

```text
PASIR-Gestion-PWA-GITHUB/
├─ index.html
├─ manifest.webmanifest
├─ service-worker.js
├─ .nojekyll
├─ .gitignore
├─ README.md
├─ GITHUB-PAGES.md
├─ assets/
│  ├─ css/styles.css
│  ├─ js/app.js
│  └─ icons/
│     ├─ icon-192.png
│     ├─ icon-512.png
│     ├─ icon-maskable-512.png
│     ├─ apple-touch-icon.png
│     ├─ favicon-64.png
│     └─ pasir-logo.svg
└─ .github/workflows/deploy-pages.yml
```

## Subir al repositorio

Sube **el contenido de esta carpeta a la raíz del repositorio**, de forma que `index.html` quede directamente en la raíz.

Después habilita GitHub Pages. Lee `GITHUB-PAGES.md`.

## Instalación como PWA

Una vez desplegada por HTTPS:

- **Windows / Edge o Chrome:** abre la web y usa el botón **Instalar app** o el icono de instalación del navegador.
- **Android / Chrome:** abre la web y selecciona **Instalar aplicación / Añadir a pantalla de inicio**.

## Actualizaciones

Cuando subas una versión nueva y modifiques archivos importantes, cambia `CACHE_NAME` en `service-worker.js`. Esto fuerza al Service Worker a reemplazar la caché anterior.
