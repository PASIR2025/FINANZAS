# PASIR Gestión V4.9.1 — corrección real de borrado

Esta versión corrige dos rutas distintas:

1. **Eliminar movimiento**: usa `pasir_delete_transaction_v491` y puede localizar registros heredados cuyo ID local no coincide con el ID guardado en Supabase.
2. **Eliminar todos los datos**: usa `pasir_clear_workspace_data_v491`, que borra por `workspace_id` directamente en Supabase y no depende de los IDs locales.

Además, el JavaScript principal se publica con un nombre nuevo (`app-v4.9.1.js`) para evitar que la PWA reutilice un `app.js` antiguo desde caché.

## Instalación

1. Reemplaza el repositorio por esta carpeta.
2. Ejecuta **solo** `SUPABASE-PARCHE-V4.9.1.sql` en Supabase SQL Editor.
3. Abre PASIR y verifica **V4.9.1**.
4. Prueba un movimiento antiguo y luego `Eliminar todos los datos` solo si realmente deseas vaciar la información financiera/gestión.
