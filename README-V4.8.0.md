# PASIR Gestión V4.8.0 ESTABLE

Versión de estabilidad para Escuela PASIR.

## Correcciones principales

- Persistencia redundante de todos los datos locales (localStorage + IndexedDB).
- Recuperación automática de la configuración de Supabase al cerrar y volver a abrir la PWA.
- Sesión de usuario persistente con respaldo y renovación automática.
- Las cuentas, cursos, metas, proyectos, presupuestos y demás cambios ya no deben desaparecer por una sincronización posterior.
- Las sincronizaciones se ejecutan en cola para evitar que una descarga de nube pise cambios locales pendientes.
- El borrado de movimientos elimina también la fila en Supabase; si no hay Internet, queda una eliminación pendiente que se aplica al reconectar.
- Los movimientos creados sin conexión quedan en cola y se envían después.
- Eliminar datos de demostración limpia dispositivo y nube sin borrar usuarios ni permisos.
- Service Worker actualizado a V4.8.0 para evitar cargar archivos antiguos.

## Actualización

Puedes reemplazar todo el contenido del repositorio con este paquete. El proyecto Supabase, usuarios y datos de nube no se eliminan al actualizar archivos de GitHub Pages.

Después de publicar, abre PASIR y verifica que en el pie aparezca **V4.8.0**. Si el navegador conserva una versión anterior, cierra todas las pestañas/PWA y vuelve a abrirla; una recarga forzada puede ayudar en PC.

No vuelvas a ejecutar `supabase-schema.sql` si ya lo ejecutaste correctamente.
