# PASIR Gestión V5.0.0 — Cambios realizados

1. Se dejó **un solo JS de aplicación**: `assets/js/app-v5.0.0.js`.
2. Se eliminaron del runtime `app.js`, `app-v4.9.1.js` y `app-v4.9.2.js`.
3. Se consolidaron en una sola definición las funciones críticas de persistencia, borrado y sincronización.
4. `deleteTx()` online ahora sigue: confirmar → RPC V5 → comprobar `deleted_count` → SELECT de verificación → borrar local → renderizar.
5. `deleteTx()` offline usa una cola DELETE separada; quita el mismo ID de la cola UPSERT y lo marca con tombstone.
6. Se eliminó el fallback frontend a `pasir_delete_transaction_v480` / `v491`.
7. Se eliminó el patrón de UPSERT masivo de `state.transactions`; los movimientos usan colas de inserts/updates y deletes separadas.
8. Se agregó migración de colas/tombstones V4.7/V4.8/V4.9 hacia las estructuras V5 sin borrar datos.
9. `pasir_delete_transaction_v500` resuelve IDs legacy por fingerprint único y exige `ROW_COUNT=1` cuando debe borrar una fila viva.
10. La RPC V5 crea tombstone tanto para el ID real como para el alias legacy, evitando resurrección desde dispositivos antiguos.
11. Si el fingerprint es ambiguo, no se borra ninguna fila.
12. `clearAll()` usa una RPC de workspace; online no borra localmente hasta tener confirmación remota. Offline deja una limpieza total pendiente.
13. `removeDemoData()` usa el mismo motor de DELETE remoto verificado de V5 para movimientos demo.
14. Se reforzó RLS y la RPC para que viewer nunca pueda borrar, aunque tuviera un permiso mal configurado.
15. La gestión de cuentas, cursos, cobranzas, pagos, presupuestos, metas, proyectos, perfiles comerciales y respuestas rápidas usa metadatos por entidad (`_syncMeta`) y merge, evitando un reemplazo ciego por JSON antiguo.
16. Project URL y anon/publishable key se conservan en almacenamiento durable.
17. La sesión usa `persistSession:true`, `autoRefreshToken:true`, almacenamiento personalizado durable y respaldo de tokens de sesión.
18. Se conserva la misma `storageKey` de Auth usada por V4.9 para no invalidar sesiones existentes por cambiar solo el nombre de versión.
19. Service Worker V5 usa cache `pasir-shell-v5.0.0`, assets V5 consistentes, `skipWaiting`, `clients.claim`, network-first/no-store y eliminación automática de caches shell antiguos; no elimina caches `pasir-durable-*`.
20. `index.html`, manifest, CSS cache-buster, JS y estado visible quedaron alineados en V5.0.0.
21. Se corrigió la referencia antigua a `openGoalDetail` inexistente.
22. Los SQL históricos V4.7/V4.8/V4.9.1 y documentación histórica se conservaron en `historico-v4/` solo como referencia; no forman parte del runtime.
23. La migración retira las RPC antiguas `pasir_delete_transaction`, `v480`, `v491` y `pasir_clear_workspace_data_v491` para dejar únicamente el motor V5 activo.
24. Para un Supabase existente se debe ejecutar **solo** `SUPABASE-MIGRACION-V5.0.0.sql`; no es necesario ni recomendable volver a ejecutar todo el schema.
