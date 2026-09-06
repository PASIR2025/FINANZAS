# PASIR Gestión V5.0.0 — Diagnóstico técnico

Este diagnóstico se realizó sobre el ZIP original **PASIR-Gestion-V4.9.2-ANTI-CACHE-COMPLETA(1).zip** antes de modificar el proyecto.

## CAUSA 1 — “Eliminar movimiento” tenía una ruta local antigua
**Archivo original:** `assets/js/app-v4.9.2.js`  
**Funciones:** `deleteTx()` base (aprox. línea 108), wrapper V4.8 (aprox. línea 394)  
**Error:** la implementación base ajustaba saldos, quitaba el movimiento de `state.transactions`, llamaba a `persist()` y mostraba “Movimiento eliminado”, pero no ejecutaba DELETE remoto. El wrapper V4.8 conservaba esa implementación mediante `_v45DeleteTx`.  
**Consecuencia:** si por orden de definiciones o caché se ejecutaba esa ruta, el registro desaparecía localmente pero permanecía en `pasir_transactions`; el siguiente PULL lo recuperaba.

## CAUSA 2 — “Eliminar demo” sí seguía una ruta diferente que llegaba a Supabase
**Archivo original:** `assets/js/app-v4.9.2.js`  
**Función:** `removeDemoData()` (aprox. líneas 270–296)  
**Error estructural:** no era el mismo motor que `deleteTx()`. Esta función hacía `from('pasir_transactions').delete().eq('workspace_id',...).in('id', ids)` y luego sincronizaba.  
**Consecuencia:** explica exactamente el comportamiento observado: demo = borrado de nube; movimiento normal = podía quedarse en local.

## CAUSA 3 — “Eliminar todos los datos” también tenía una versión local-only
**Archivo original:** `assets/js/app-v4.9.2.js`  
**Función base:** `clearAll()` (aprox. línea 297)  
**Error:** la versión base vaciaba el estado local y mostraba “Datos locales eliminados”. Más adelante existían otros reemplazos de `clearAll()`, por lo que el comportamiento dependía de cuál definición terminara activa.  
**Consecuencia:** era posible ver el mensaje local y que los datos remotos permanecieran intactos.

## CAUSA 4 — RPC V4.8 podía devolver `ok=true` habiendo borrado 0 filas
**Archivo original:** `SUPABASE-PARCHE-V4.8.0.sql`  
**Función:** `pasir_delete_transaction_v480`  
**Error:** si `p_id` no existía y el usuario era manager, permitía crear una tombstone para ese ID y luego ejecutaba `DELETE ... WHERE id=p_id`. No comprobaba `ROW_COUNT=1`. Después solo comprobaba que ese mismo ID inexistente siguiera sin existir y devolvía `ok=true`.  
**Consecuencia:** con un movimiento heredado cuyo ID local no coincidía con `pasir_transactions.id`, Supabase podía responder “éxito” sin borrar la fila real.

## CAUSA 5 — V4.9.2 reintroducía el falso éxito mediante fallback a V4.8
**Archivo original:** `assets/js/app-v4.9.2.js`  
**Función:** `v491DeleteRemote()` (aprox. líneas 1087–1116)  
**Error:** primero llamaba a la RPC V4.9.1, que sí intentaba resolver IDs heredados por fingerprint, pero ante error o falta de coincidencia hacía fallback a `pasir_delete_transaction_v480`. Si V4.8 respondía `{ok:true}`, el frontend aceptaba el borrado.  
**Consecuencia:** una falla segura de V4.9.1 podía convertirse otra vez en un falso éxito V4.8.

## CAUSA 6 — Existía una rutina antigua de UPSERT masivo de movimientos
**Archivo original:** `assets/js/app-v4.9.2.js`  
**Función:** versión antigua de `cloudPushState()` (aprox. línea 472)  
**Error:** construía un arreglo desde `state.transactions` y hacía UPSERT de todo el conjunto.  
**Consecuencia:** si una copia antigua del estado aún contenía un movimiento borrado, ese motor podía volver a insertarlo. Esto es exactamente el patrón que debía eliminarse.

## CAUSA 7 — El mismo archivo contenía varias generaciones de funciones críticas
**Archivo original:** `assets/js/app-v4.9.2.js`  
**Duplicaciones encontradas:** `persist`, `saveMovement`, `deleteTx`, `clearAll`, `removeDemoData`, `cloudPushState`, `cloudPullState`, `syncCloudNow`, `cloudUpsertTransaction`, `scheduleCloudPush`, `initCloud`, `restoreCloudSession`, `loadCloudContext` y otras.  
**Error:** V4.5/V4.6/V4.8/V4.9/V4.9.2 coexistían como capas de reasignaciones y wrappers.  
**Consecuencia:** era difícil demostrar qué ruta real quedaba activa y un JS antiguo servido por caché podía ejecutar una implementación completamente distinta.

## CAUSA 8 — El ZIP contenía tres copias completas del JavaScript de aplicación
**Archivos originales:** `assets/js/app.js`, `assets/js/app-v4.9.1.js`, `assets/js/app-v4.9.2.js`  
**Observación:** `app.js` y `app-v4.9.2.js` eran equivalentes; `index.html` cargaba solo V4.9.2, pero mantener varias copias aumentaba el riesgo de que un HTML/SW viejo apuntara a otro archivo.  
**Consecuencia:** despliegues parciales o cachés viejos podían mezclar título nuevo con lógica vieja.

## CAUSA 9 — Versiones de assets no estaban alineadas
**Archivo original:** `index.html` y `service-worker.js`  
**Error:** el HTML mostraba V4.9.2 y cargaba JS V4.9.2, pero el manifest seguía con `?v=4.9.0` y CSS con `?v=4.9.1`. El SW era V4.9.2 y estaba correctamente orientado a network-first, `skipWaiting` y `clientsClaim`, pero la mezcla de nombres/versiones y los JS duplicados mantenía riesgo de despliegue inconsistente.  
**Consecuencia:** una publicación incompleta podía mostrar una versión visual distinta de la lógica ejecutada.

## CAUSA 10 — Los datos generales podían ser reemplazados por una copia antigua de nube
**Archivo original:** `assets/js/app-v4.9.2.js`  
**Función:** `v490PullInner()`  
**Error:** cuentas, cursos, cuentas por cobrar/pagar, presupuestos, metas, proyectos e información comercial se reconstruían desde `pasir_shared_data` / `pasir_private_data`. La protección dependía de una bandera global `dirty`; datos heredados o estados sin esa marca podían perder frente a un JSON remoto antiguo.  
**Consecuencia:** después de sincronizar podían desaparecer cuentas, metas u otros registros recién guardados.

## CAUSA 11 — Había un alias a una función inexistente
**Archivo original:** `assets/js/app-v4.9.2.js`  
**Código:** `_v45OpenGoalDetail=openGoalDetail` sin una definición previa fiable de `openGoalDetail`.  
**Consecuencia:** era una fuente adicional de `ReferenceError`/comportamiento dependiente del orden de carga y fue eliminada en la consolidación.

## IDs heredados
`pasir_transactions.id` ya es **TEXT** en `supabase-schema.sql`, por lo que no hace falta cambiar el tipo de columna ni borrar datos. Admite UUID, timestamps, números convertidos a texto y strings legacy. El problema no era el tipo SQL sino la correspondencia entre el ID local y el ID real remoto.

V5 resuelve primero por ID exacto. Si falla, usa un fingerprint del movimiento y solo permite borrar cuando existe **una única coincidencia remota**. Si hay 0 o más de 1 coincidencias, devuelve error y no borra nada.

## RLS revisada
La política original ya expresaba la intención owner/admin + operador propio con permiso, pero no excluía explícitamente el rol viewer si alguien le asignaba accidentalmente `delete_own_entries`. V5 endurece tanto RLS como la RPC:

- `owner`: puede borrar cualquier movimiento del workspace.
- `admin`: puede borrar cualquier movimiento del workspace.
- `operator`: solo `created_by = auth.uid()` **y** `delete_own_entries=true`.
- `viewer`: nunca puede borrar.

## Conclusión
El problema principal no era una sola línea: coexistían rutas locales y remotas, una RPC V4.8 con falso positivo para IDs inexistentes, fallback inseguro, UPSERT masivo antiguo y varias generaciones del mismo motor de sincronización. V5 elimina esas rutas paralelas y deja un solo flujo. La migración también retira las RPC V4 antiguas para evitar que un cliente desactualizado vuelva a usar el motor de falso positivo.
