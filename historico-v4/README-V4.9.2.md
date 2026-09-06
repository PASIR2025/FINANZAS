# PASIR Gestión V4.9.2

Corrección de despliegue/caché y borrado en nube.

1. Mantiene el motor de borrado V4.9.1 ya instalado en Supabase.
2. Fuerza carga del JS nuevo con `app-v4.9.2.js`.
3. Incluye `ACTUALIZAR-V4.9.2.html` para desregistrar Service Workers antiguos y limpiar solo caché de la PWA.
4. Tanto `app.js` como `app-v4.9.2.js` contienen el motor actual para evitar que un HTML viejo ejecute lógica antigua después de una actualización de red.

No requiere SQL nuevo si `PASIR V4.9.1 listo` ya apareció en Supabase.
