# PASIR Gestión V4.9.0

Versión de estabilización del motor de persistencia y sincronización.

- Un único flujo de sincronización para movimientos.
- Supabase es la fuente de verdad de movimientos.
- El PUSH general no vuelve a insertar todo el historial.
- Borrado con tombstones locales/remotas y RPC V4.8 ya instalada.
- Compatibilidad con registros heredados: si el ID local no existe en Supabase, intenta resolver una coincidencia exacta y única antes de borrar.
- Configuración y sesión con almacenamiento redundante.
- Cambios locales de cuentas/metas/proyectos se suben antes de cualquier PULL para que no desaparezcan.
