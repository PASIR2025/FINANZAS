-- =====================================================================
-- PASIR Gestión V4.8.0 — BORRADO DEFINITIVO CON TOMBSTONES
-- Ejecutar UNA SOLA VEZ en Supabase > SQL Editor > Run.
-- Es idempotente: se puede volver a ejecutar sin borrar información.
-- NO elimina usuarios, espacio, cuentas ni movimientos existentes.
-- =====================================================================

-- 1) Registro permanente de IDs eliminados.
create table if not exists public.pasir_transaction_tombstones (
  workspace_id uuid not null references public.pasir_workspaces(id) on delete cascade,
  transaction_id text not null,
  deleted_by uuid references auth.users(id),
  deleted_at timestamptz not null default now(),
  primary key (workspace_id, transaction_id)
);

create index if not exists pasir_tx_tombstones_workspace_idx
on public.pasir_transaction_tombstones(workspace_id, deleted_at desc);

alter table public.pasir_transaction_tombstones enable row level security;

drop policy if exists "pasir tombstones read" on public.pasir_transaction_tombstones;
create policy "pasir tombstones read"
on public.pasir_transaction_tombstones
for select using (public.pasir_is_member(workspace_id));

-- No se necesita escritura directa desde el navegador: la hace la RPC segura.
grant select on public.pasir_transaction_tombstones to authenticated;

-- 2) Política DELETE compatible con propietario, administrador y operador
--    autorizado sobre sus propios registros.
drop policy if exists "pasir tx delete managers" on public.pasir_transactions;
drop policy if exists "pasir tx delete authorized" on public.pasir_transactions;
create policy "pasir tx delete authorized"
on public.pasir_transactions
for delete using (
  public.pasir_is_manager(workspace_id)
  or (
    created_by = auth.uid()
    and public.pasir_has_permission(workspace_id,'delete_own_entries')
  )
);

-- 3) RPC transaccional: primero crea la tombstone y después elimina la fila.
--    Devuelve una confirmación estructurada al frontend.
create or replace function public.pasir_delete_transaction_v480(
  p_workspace uuid,
  p_id text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_creator uuid;
  v_allowed boolean := false;
  v_exists_before boolean := false;
  v_exists_after boolean := false;
  v_role text;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión';
  end if;

  if not public.pasir_is_member(p_workspace) then
    raise exception 'No perteneces a este espacio PASIR';
  end if;

  v_role := public.pasir_role(p_workspace);

  select created_by
    into v_creator
    from public.pasir_transactions
   where workspace_id = p_workspace
     and id = p_id;

  v_exists_before := found;

  -- Si ya existe una tombstone, la eliminación ya fue solicitada anteriormente.
  if not v_exists_before and exists(
    select 1 from public.pasir_transaction_tombstones
     where workspace_id=p_workspace and transaction_id=p_id
  ) then
    return jsonb_build_object(
      'ok', true,
      'id', p_id,
      'role', v_role,
      'already_deleted', true,
      'exists_after', false,
      'tombstone', true
    );
  end if;

  if v_exists_before then
    v_allowed := public.pasir_is_manager(p_workspace)
      or (
        v_creator = auth.uid()
        and public.pasir_has_permission(p_workspace,'delete_own_entries')
      );
  else
    -- Si la fila ya no existe y quien pide es manager, se crea igualmente
    -- la tombstone para impedir que un dispositivo antiguo la restaure.
    v_allowed := public.pasir_is_manager(p_workspace);
  end if;

  if not v_allowed then
    raise exception 'Sin permiso para eliminar este movimiento';
  end if;

  insert into public.pasir_transaction_tombstones(
    workspace_id, transaction_id, deleted_by, deleted_at
  ) values (
    p_workspace, p_id, auth.uid(), now()
  )
  on conflict (workspace_id, transaction_id)
  do update set deleted_by=excluded.deleted_by, deleted_at=excluded.deleted_at;

  delete from public.pasir_transactions
   where workspace_id=p_workspace
     and id=p_id;

  select exists(
    select 1 from public.pasir_transactions
     where workspace_id=p_workspace and id=p_id
  ) into v_exists_after;

  if v_exists_after then
    raise exception 'Supabase no pudo eliminar físicamente el movimiento';
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', p_id,
    'role', v_role,
    'existed_before', v_exists_before,
    'exists_after', false,
    'tombstone', true
  );
end;
$$;

grant execute on function public.pasir_delete_transaction_v480(uuid,text) to authenticated;

-- 4) Bloqueo anti-resurrección.
--    Si un celular desactualizado intenta volver a hacer UPSERT de un ID ya
--    eliminado, PostgreSQL ignora esa fila en lugar de restaurarla.
create or replace function public.pasir_block_tombstoned_transaction_restore()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if exists(
    select 1
      from public.pasir_transaction_tombstones t
     where t.workspace_id = new.workspace_id
       and t.transaction_id = new.id
  ) then
    return null;
  end if;
  return new;
end;
$$;

drop trigger if exists pasir_transactions_block_restore on public.pasir_transactions;
create trigger pasir_transactions_block_restore
before insert or update on public.pasir_transactions
for each row execute function public.pasir_block_tombstoned_transaction_restore();

-- 5) Mantiene la RPC V4.7.1 compatible, pero la redirige al mismo concepto
--    de seguridad para instalaciones que aún la llamen.
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
  v_result jsonb;
begin
  v_result := public.pasir_delete_transaction_v480(p_workspace,p_id);
  return coalesce((v_result->>'ok')::boolean,false);
end;
$$;

grant execute on function public.pasir_delete_transaction(uuid,text) to authenticated;

-- Verificación informativa: debe devolver las columnas de la tabla creada.
select 'PASIR V4.8.0 listo' as estado;
