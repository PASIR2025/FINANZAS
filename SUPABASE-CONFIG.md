# PASIR Gestión V5.0.0 — Supabase

## Si YA tienes PASIR conectado a Supabase
1. Haz un respaldo JSON en la PWA.
2. Abre Supabase → SQL Editor.
3. Ejecuta **solo** `SUPABASE-MIGRACION-V5.0.0.sql`.
4. No vuelvas a ejecutar `supabase-schema.sql` desde cero.
5. Publica después la PWA V5.0.0 completa.

La migración V5 conserva los datos existentes. Crea/actualiza tombstones, RLS DELETE, el trigger anti-resurrección y las RPC V5.

## Si es un proyecto Supabase completamente nuevo
1. Ejecuta `supabase-schema.sql`.
2. Después ejecuta `SUPABASE-MIGRACION-V5.0.0.sql`.
3. En PASIR pega Project URL y anon/publishable key.
4. Nunca uses la `service_role` key en el frontend.

## Roles de borrado V5
- Propietario: cualquier movimiento.
- Administrador: cualquier movimiento.
- Operador: solo sus propios movimientos y únicamente con `delete_own_entries=true`.
- Consulta/viewer: no puede eliminar movimientos.

## Persistencia
V5 usa `persistSession:true`, `autoRefreshToken:true` y almacenamiento durable para conservar configuración/sesión al cerrar y volver a abrir la PWA.
