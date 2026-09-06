# PASIR Gestión V4.8.0 — configuración multiusuario con Supabase

## 1. Crear el proyecto
1. Crea un proyecto en Supabase.
2. Abre **SQL Editor**.
3. Copia y ejecuta todo el archivo `supabase-schema.sql` de este repositorio.

El SQL crea el espacio de trabajo, membresías, datos compartidos y privados, transacciones, auditoría y las políticas **RLS**.

## 2. Autenticación
En Supabase revisa **Authentication > Providers > Email** y mantén habilitado Email/Password.

Si está activa la confirmación de correo, cada persona tendrá que confirmar su dirección antes de iniciar sesión. Para pruebas puedes modificar esa opción desde Supabase; en producción es recomendable conservar la verificación.

## 3. Conectar la PWA
1. Publica la PWA en GitHub Pages o ábrela desde un servidor HTTPS.
2. En PASIR entra a **Configuración** o **Equipo y permisos**.
3. Pulsa **Configurar Supabase**.
4. Pega:
   - **Project URL**
   - **Anon / publishable key**
5. Nunca pegues la `service_role` key en la aplicación.

La anon key es una clave pública de cliente; la seguridad de los datos la aplican las políticas RLS del archivo SQL.

## 4. Crear al propietario
1. Pulsa **Iniciar sesión > Crear cuenta**.
2. Regístrate con tu correo.
3. Una vez autenticado, abre **Equipo y permisos**.
4. Pulsa **Crear ESCUELA PASIR**.
5. PASIR subirá los datos locales actuales a la nube.

## 5. Agregar a tus tres personas
Desde **Equipo y permisos > Agregar persona**:
1. Escribe nombre y correo exacto.
2. Usa el rol **Operador**.
3. Activa los permisos que necesites.

Configuración recomendada para tus operadores:
- Registrar ventas / ingresos: Sí
- Registrar gastos / compras: Sí
- Ver productos: Sí
- Ver precios: Sí
- Ver metas: Sí
- Ver información comercial: Sí
- Ver sus propios registros: Sí
- Ver proyectos: opcional
- Ver saldos y caja: No
- Ver análisis financiero: No
- Administrar equipo: No

Cada persona entra a la misma URL de PASIR, crea su cuenta con **el mismo correo que invitaste** e inicia sesión. La invitación se vincula automáticamente.

## 6. Qué protege RLS
Un operador no recibe la información privada de saldos/caja. Sí recibe el directorio de medios (por ejemplo, “Yape” o “BCP”) para poder registrar dónde entró o salió el dinero. Las transacciones quedan identificadas con el usuario que las creó.

Los operadores solo pueden leer sus propios registros si tienen ese permiso. Propietario/administrador puede revisar todas las operaciones.

## 7. Primer uso recomendado
Antes de activar nube haz un **respaldo JSON** desde Configuración. Después crea el espacio PASIR y pulsa **Sincronizar**.
