-- PASIR Gestión V4.7.1 — parche de borrado y permisos
-- Ejecutar UNA SOLA VEZ en Supabase > SQL Editor.
-- No borra datos, usuarios, roles ni movimientos.

-- 1) Permitir borrado directo a managers o al creador con permiso explícito.
drop policy if exists "pasir tx delete managers" on public.pasir_transactions;
drop policy if exists "pasir tx delete authorized" on public.pasir_transactions;
create policy "pasir tx delete authorized" on public.pasir_transactions
for delete using (
  public.pasir_is_manager(workspace_id)
  or (created_by=auth.uid() and public.pasir_has_permission(workspace_id,'delete_own_entries'))
);

-- 2) RPC segura: confirma de verdad si el movimiento quedó eliminado.
create or replace function public.pasir_delete_transaction(
  p_workspace uuid,
  p_id text
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_creator uuid;
  v_allowed boolean;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión';
  end if;

  select created_by into v_creator
  from public.pasir_transactions
  where workspace_id=p_workspace and id=p_id;

  -- Si ya no existe, el objetivo ya está cumplido.
  if not found then
    return true;
  end if;

  v_allowed := public.pasir_is_manager(p_workspace)
    or (v_creator=auth.uid() and public.pasir_has_permission(p_workspace,'delete_own_entries'));

  if not v_allowed then
    raise exception 'Sin permiso para eliminar este movimiento';
  end if;

  delete from public.pasir_transactions
  where workspace_id=p_workspace and id=p_id;

  return not exists (
    select 1 from public.pasir_transactions
    where workspace_id=p_workspace and id=p_id
  );
end;
$$;

grant execute on function public.pasir_delete_transaction(uuid,text) to authenticated;
