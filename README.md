# PASIR Gestión PWA V4.6

Sistema PWA de ESCUELA PASIR para planificación, producción, ventas y finanzas.

## Novedades V4.6
- Centro de Análisis separado en Ventas, Gastos, Utilidad, Inversión, Flujo de caja y Comparativo general.
- Filtros por periodo, agrupación por día/semana/mes/trimestre/año y desglose por curso/categoría/cuenta según el análisis.
- Barras y filas clicables para abrir las operaciones que forman cada dato.
- Supabase opcional para trabajar desde varios dispositivos.
- Roles: Propietario, Administrador, Operador y Consulta.
- Permisos individuales.
- Panel seguro de operador sin saldos ni caja.
- Identificación de quién registró cada movimiento.
- Auditoría de transacciones en Supabase.
- RLS para impedir que operadores descarguen datos privados.

## Probar en local
Puedes abrir `index.html`. La parte local funciona sin Supabase. La sincronización en nube requiere Internet y es recomendable probarla desde GitHub Pages/HTTPS.

## Publicar en GitHub
Sube **el contenido de esta carpeta** a la raíz del repositorio. El workflow incluido puede publicar con GitHub Pages.

## Activar multiusuario
Lee `SUPABASE-CONFIG.md` y ejecuta primero `supabase-schema.sql` en tu proyecto Supabase.

> Nunca coloques la service_role key en el frontend. Usa únicamente Project URL y anon/publishable key.
