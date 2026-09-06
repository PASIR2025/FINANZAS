# PASIR Gestión V5.0.0 — Pruebas realizadas

## Validación técnica ejecutada
- `node --check assets/js/app-v5.0.0.js` → PASS.
- `node --check service-worker.js` → PASS.
- Auditoría de funciones nombradas → 0 duplicadas.
- Solo existe un JS de aplicación en `assets/js/`.
- `index.html` importa un único JS de PASIR.
- No aparecen referencias a `pasir_delete_transaction_v480` ni `pasir_delete_transaction_v491` en el runtime V5.
- No existe el patrón `state.transactions -> map(dbTx) -> upsert masivo`.

## TEST 1 — movimiento antiguo
Simulación determinista: una fila remota con ID `uuid-remoto-001` y una copia local heredada con ID distinto, pero fingerprint único.

**Resultado:** PASS. La RPC V5 resuelve el ID real, exige 1 fila borrada, crea tombstones para ID real + alias y el movimiento no reaparece después del pull.

## TEST 2 — movimiento nuevo
Crear → upsert individual → borrar por ID exacto → pull.

**Resultado:** PASS. El remoto queda vacío y el ID queda tombstoned.

## TEST 3 — dos dispositivos
A crea → servidor → B hace pull y lo ve. A elimina → B hace pull.

**Resultado:** PASS. B deja de verlo y un intento posterior de reinsertar el ID tombstoned es bloqueado.

## TEST 4 — cuenta
Cuenta local nueva + JSON remoto legacy que no la contiene.

**Resultado:** PASS. El merge V5 conserva la cuenta local y también los registros remotos no conflictivos; una recarga del estado reconciliado conserva la cuenta.

## TEST 5 — sesión/configuración
Auditoría del código real.

**Resultado:** PASS. `persistSession:true`, `autoRefreshToken:true`, `storage:PASIR_SUPABASE_STORAGE`, configuración durable y backup de sesión en localStorage + IndexedDB + Cache Storage.

## TEST 6 — datos demo
Dos movimientos demo se eliminan con el mismo contrato de DELETE V5.

**Resultado:** PASS. Ambos desaparecen y sus tombstones impiden reinsertarlos.

## TEST 7 — permisos
Casos comprobados:
- owner sobre registro ajeno → permitido.
- admin sobre registro ajeno → permitido.
- operator propio + `delete_own_entries=true` → permitido.
- operator ajeno → rechazado.
- operator propio sin permiso → rechazado.
- viewer → rechazado.

**Resultado:** PASS.

## Prueba extra — fingerprint ambiguo
Dos filas remotas con el mismo fingerprint y un ID legacy que no coincide.

**Resultado:** PASS. V5 devuelve `no_unique_remote_match` y borra 0 filas; no adivina.

## Runtime smoke test
`tests/runtime-smoke.js` ejecuta el JS completo dentro de un DOM simulado y comprueba que la UI base se renderice sin `ReferenceError`.

**Resultado:** PASS.

## Límite de esta validación
El ZIP no contiene las credenciales privadas ni una sesión utilizable de tu proyecto Supabase, por lo que no es correcto afirmar que estas pruebas ejecutaron DELETEs contra **tu base real** o que se probaron físicamente dos teléfonos reales. Lo que sí se validó aquí es el código, el contrato SQL/RLS, el orden de operaciones y una simulación determinista de los siete flujos. Después de ejecutar la migración V5 en tu Supabase, conviene repetir TEST 1–7 en la instalación publicada antes de considerar el despliegue productivo cerrado.
