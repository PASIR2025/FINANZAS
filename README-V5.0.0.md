# PASIR Gestión V5.0.0 — Escuela PASIR

PWA de gestión de ESCUELA PASIR con persistencia local/offline y Supabase como base central cuando la nube está configurada.

## Antes de publicar
1. Haz un respaldo JSON desde PASIR.
2. En un proyecto Supabase **existente**, ejecuta únicamente `SUPABASE-MIGRACION-V5.0.0.sql` en SQL Editor.
3. No vuelvas a ejecutar `supabase-schema.sql` sobre tu base existente.
4. Sube **todo el contenido** de esta carpeta a la raíz del repositorio GitHub Pages.
5. Abre `ACTUALIZAR-V5.0.0.html` una vez en cada dispositivo que hubiera usado V4.x para retirar Service Workers/cachés shell antiguos sin borrar datos ni credenciales.
6. Abre PASIR y confirma que abajo aparezca `V5.0.0`.

## Archivos principales
- `index.html` — interfaz V5.
- `assets/js/app-v5.0.0.js` — única implementación de aplicación/sincronización.
- `service-worker.js` — Service Worker V5 anti-cache obsoleto.
- `SUPABASE-MIGRACION-V5.0.0.sql` — migración no destructiva para una base existente.
- `supabase-schema.sql` — solo para una instalación Supabase nueva y vacía.
- `DIAGNOSTICO-V5.0.0.md` — causas encontradas en V4.9.2.
- `CAMBIOS-V5.0.0.md` — lista exacta de cambios.
- `PRUEBAS-V5.0.0.md` — pruebas y límites de validación.
- `tests/` — pruebas reproducibles con Node.js.
- `historico-v4/` — SQL/documentación V4 conservados como referencia; **no ejecutar como actualización V5**.

## Regla de sincronización V5
- Crear/editar movimiento: cola UPSERT individual → Supabase → confirmación.
- Eliminar online: Supabase/RPC → verificación real → local.
- Eliminar offline: tombstone + cola DELETE; el mismo ID queda fuera de la cola UPSERT.
- PULL: respeta tombstones y no puede reinsertar IDs eliminados.
- Datos de gestión: merge por entidad/metadatos en lugar de reemplazo ciego de todo el estado.

## Seguridad
Usa únicamente Project URL + anon/publishable key. Nunca coloques `service_role` en el frontend.
