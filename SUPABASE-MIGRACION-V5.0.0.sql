-- ============================================================================
-- PASIR Gestión V5.0.0 — MIGRACIÓN SEGURA DE BORRADO/SINCRONIZACIÓN
-- Ejecutar en Supabase > SQL Editor DESPUÉS del schema y parches ya existentes.
-- Es idempotente y NO borra los datos actuales.
-- NO ejecutar supabase-schema.sql nuevamente para aplicar esta versión.
-- ============================================================================

begin;

-- 1) Tombstones anti-resurrección. Conserva los existentes de V4.8/V4.9.
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
  for select
  using (public.pasir_is_member(workspace_id));

grant select on public.pasir_transaction_tombstones to authenticated;

-- 2) DELETE RLS definitivo.
-- Propietario/Administrador: cualquier movimiento del workspace.
-- Operador: solo su propio movimiento + permiso delete_own_entries=true.
-- Viewer: no cumple ninguna condición.
drop policy if exists "pasir tx delete managers" on public.pasir_transactions;
drop policy if exists "pasir tx delete authorized" on public.pasir_transactions;
create policy "pasir tx delete authorized"
  on public.pasir_transactions
  for delete
  using (
    public.pasir_is_manager(workspace_id)
    or (
      public.pasir_role(workspace_id) = 'operator'
      and created_by = auth.uid()
      and public.pasir_has_permission(workspace_id,'delete_own_entries')
    )
  );

grant select,insert,update,delete on public.pasir_transactions to authenticated;

-- 3) Bloqueo anti-resurrección.
-- Un cliente antiguo que intente reinsertar un ID tombstoned no lo restaura.
create or replace function public.pasir_block_tombstoned_transaction_restore()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
begin
  if exists (
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

-- 4) RPC V5: elimina UNA fila real o devuelve ok=false.
-- Diferencia esencial respecto de V4.8:
-- NO considera éxito que p_id simplemente no exista.
-- Si el ID local es heredado, primero intenta resolver una única fila viva
-- mediante fingerprint; incluso si existe una tombstone antigua para el alias.
create or replace function public.pasir_delete_transaction_v500(
  p_workspace uuid,
  p_id text,
  p_fingerprint jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_target text;
  v_creator uuid;
  v_role text;
  v_count integer := 0;
  v_deleted integer := 0;
  v_allowed boolean := false;
  v_date date;
  v_amount numeric;
  v_type text;
  v_currency text;
  v_time text;
  v_account text;
  v_from text;
  v_to text;
  v_category text;
  v_concept text;
  v_notes text;
  v_course_id text;
  v_course text;
  v_customer text;
  v_payment text;
  v_operation text;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión';
  end if;
  if p_workspace is null then
    raise exception 'workspace_id requerido';
  end if;
  if coalesce(p_id,'') = '' then
    raise exception 'id requerido';
  end if;
  if not public.pasir_is_member(p_workspace) then
    raise exception 'No perteneces a este espacio PASIR';
  end if;

  v_role := public.pasir_role(p_workspace);

  -- A. Coincidencia exacta por el ID local/remoto.
  select t.id, t.created_by
    into v_target, v_creator
    from public.pasir_transactions t
   where t.workspace_id = p_workspace
     and t.id = p_id
   limit 1;

  -- B. Registro heredado: resolver por fingerprint si el ID no coincide.
  -- Importante: esta búsqueda ocurre ANTES de aceptar una tombstone del alias.
  if v_target is null and coalesce(p_fingerprint,'{}'::jsonb) <> '{}'::jsonb then
    begin v_date := nullif(p_fingerprint->>'date','')::date; exception when others then v_date := null; end;
    begin v_amount := nullif(p_fingerprint->>'amount','')::numeric; exception when others then v_amount := null; end;
    v_type := nullif(p_fingerprint->>'type','');
    v_currency := nullif(p_fingerprint->>'currency','');
    v_time := coalesce(p_fingerprint->>'time','');
    v_account := coalesce(p_fingerprint->>'account','');
    v_from := coalesce(p_fingerprint->>'from','');
    v_to := coalesce(p_fingerprint->>'to','');
    v_category := coalesce(p_fingerprint->>'category','');
    v_concept := coalesce(p_fingerprint->>'concept','');
    v_notes := coalesce(p_fingerprint->>'notes','');
    v_course_id := coalesce(p_fingerprint->>'courseId','');
    v_course := coalesce(p_fingerprint->>'course','');
    v_customer := coalesce(p_fingerprint->>'customer','');
    v_payment := coalesce(p_fingerprint->>'paymentMethod','');
    v_operation := coalesce(p_fingerprint->>'operation','');

    -- B1. Coincidencia estricta.
    select count(*), min(t.id)
      into v_count, v_target
      from public.pasir_transactions t
     where t.workspace_id = p_workspace
       and (v_date is null or t.tx_date = v_date)
       and (v_type is null or t.type = v_type)
       and (v_amount is null or t.amount = v_amount)
       and (v_currency is null or t.currency = v_currency)
       and coalesce(to_char(t.tx_time,'HH24:MI'),'') = v_time
       and coalesce(t.account_id,'') = v_account
       and coalesce(t.from_account_id,'') = v_from
       and coalesce(t.to_account_id,'') = v_to
       and coalesce(t.category,'') = v_category
       and coalesce(t.concept,'') = v_concept
       and coalesce(t.notes,'') = v_notes
       and coalesce(t.course_id,'') = v_course_id
       and coalesce(t.course_name,'') = v_course
       and coalesce(t.customer,'') = v_customer
       and coalesce(t.payment_method,'') = v_payment
       and coalesce(t.operation_number,'') = v_operation;

    -- B2. Fallback para versiones que no guardaban todos los campos.
    -- Sigue exigiendo UNA única coincidencia; nunca adivina entre duplicados.
    if v_count = 0 then
      select count(*), min(t.id)
        into v_count, v_target
        from public.pasir_transactions t
       where t.workspace_id = p_workspace
         and (v_date is null or t.tx_date = v_date)
         and (v_type is null or t.type = v_type)
         and (v_amount is null or t.amount = v_amount)
         and (v_currency is null or t.currency = v_currency)
         and (v_concept = '' or coalesce(t.concept,'') = v_concept)
         and (v_account = '' or coalesce(t.account_id,'') = v_account)
         and (v_from = '' or coalesce(t.from_account_id,'') = v_from)
         and (v_to = '' or coalesce(t.to_account_id,'') = v_to);
    end if;

    if v_count = 1 then
      select t.created_by
        into v_creator
        from public.pasir_transactions t
       where t.workspace_id = p_workspace
         and t.id = v_target;
    else
      v_target := null;
    end if;
  end if;

  -- C. Solo si NO existe ninguna fila viva identificable se permite idempotencia.
  -- Esto repara el caso V4.8: una tombstone del alias equivocado ya no impide
  -- encontrar y borrar la fila real mediante fingerprint.
  if v_target is null then
    if exists (
      select 1
        from public.pasir_transaction_tombstones d
       where d.workspace_id = p_workspace
         and d.transaction_id = p_id
    ) then
      return jsonb_build_object(
        'ok', true,
        'id', p_id,
        'actual_id', p_id,
        'already_deleted', true,
        'deleted_count', 0,
        'role', v_role
      );
    end if;

    return jsonb_build_object(
      'ok', false,
      'id', p_id,
      'reason', 'no_unique_remote_match',
      'deleted_count', 0,
      'message', 'No se encontró una única fila remota correspondiente a este movimiento; no se borró nada'
    );
  end if;

  -- D. Permisos se evalúan sobre la fila REAL encontrada.
  v_allowed := public.pasir_is_manager(p_workspace)
    or (
      v_role = 'operator'
      and v_creator = auth.uid()
      and public.pasir_has_permission(p_workspace,'delete_own_entries')
    );

  if not v_allowed then
    raise exception 'Sin permiso para eliminar este movimiento';
  end if;

  -- E. Tombstone del ID real y, si aplica, del alias heredado.
  insert into public.pasir_transaction_tombstones(workspace_id,transaction_id,deleted_by,deleted_at)
  values(p_workspace,v_target,auth.uid(),now())
  on conflict(workspace_id,transaction_id)
  do update set deleted_by=excluded.deleted_by,deleted_at=excluded.deleted_at;

  if p_id <> v_target then
    insert into public.pasir_transaction_tombstones(workspace_id,transaction_id,deleted_by,deleted_at)
    values(p_workspace,p_id,auth.uid(),now())
    on conflict(workspace_id,transaction_id)
    do update set deleted_by=excluded.deleted_by,deleted_at=excluded.deleted_at;
  end if;

  -- F. DELETE físico + row_count obligatorio.
  delete from public.pasir_transactions
   where workspace_id = p_workspace
     and id = v_target;
  get diagnostics v_deleted = row_count;

  if v_deleted <> 1 then
    raise exception 'DELETE no confirmado: se esperó 1 fila y se eliminaron %', v_deleted;
  end if;

  if exists (
    select 1 from public.pasir_transactions
     where workspace_id = p_workspace
       and id = v_target
  ) then
    raise exception 'Supabase no pudo eliminar físicamente el movimiento';
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', p_id,
    'actual_id', v_target,
    'legacy_id', (v_target <> p_id),
    'already_deleted', false,
    'deleted_count', v_deleted,
    'role', v_role
  );
end;
$$;

revoke all on function public.pasir_delete_transaction_v500(uuid,text,jsonb) from public;
grant execute on function public.pasir_delete_transaction_v500(uuid,text,jsonb) to authenticated;

-- 5) Limpieza total del workspace, exclusivamente para manager.
create or replace function public.pasir_clear_workspace_data_v500(p_workspace uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_deleted integer := 0;
  v_now timestamptz := now();
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if not public.pasir_is_manager(p_workspace) then
    raise exception 'Solo Propietario/Administrador puede borrar todos los datos';
  end if;

  insert into public.pasir_transaction_tombstones(workspace_id,transaction_id,deleted_by,deleted_at)
  select p_workspace,t.id,auth.uid(),v_now
    from public.pasir_transactions t
   where t.workspace_id = p_workspace
  on conflict(workspace_id,transaction_id)
  do update set deleted_by=excluded.deleted_by,deleted_at=excluded.deleted_at;

  delete from public.pasir_transactions where workspace_id = p_workspace;
  get diagnostics v_deleted = row_count;

  if exists(select 1 from public.pasir_transactions where workspace_id=p_workspace) then
    raise exception 'No se pudo vaciar completamente pasir_transactions';
  end if;

  insert into public.pasir_shared_data(workspace_id,data,updated_by,updated_at)
  values(
    p_workspace,
    jsonb_build_object(
      'version','5.0.0','resetAt',v_now,
      'courses','[]'::jsonb,'commercialProfiles','[]'::jsonb,'quickReplies','[]'::jsonb,
      'goals','[]'::jsonb,'projects','[]'::jsonb,'paymentMethods','[]'::jsonb,
      '_syncMeta',jsonb_build_object('collections','{}'::jsonb,'ratesUpdatedAt',extract(epoch from v_now)*1000)
    ),
    auth.uid(),v_now
  )
  on conflict(workspace_id) do update
    set data=excluded.data,updated_by=excluded.updated_by,updated_at=excluded.updated_at;

  insert into public.pasir_private_data(workspace_id,data,updated_by,updated_at)
  values(
    p_workspace,
    jsonb_build_object(
      'version','5.0.0','resetAt',v_now,
      'rates',jsonb_build_object('USD',3.65,'USDT',3.65),
      'accounts','[]'::jsonb,'receivables','[]'::jsonb,'payables','[]'::jsonb,
      'budgets','[]'::jsonb,'goals','[]'::jsonb,'projects','[]'::jsonb,
      '_syncMeta',jsonb_build_object('collections','{}'::jsonb,'ratesUpdatedAt',extract(epoch from v_now)*1000)
    ),
    auth.uid(),v_now
  )
  on conflict(workspace_id) do update
    set data=excluded.data,updated_by=excluded.updated_by,updated_at=excluded.updated_at;

  return jsonb_build_object('ok',true,'deleted_transactions',v_deleted,'reset_at',v_now);
end;
$$;

revoke all on function public.pasir_clear_workspace_data_v500(uuid) from public;
grant execute on function public.pasir_clear_workspace_data_v500(uuid) to authenticated;

-- 6) Retirar RPC antiguas de borrado. No eliminan datos; solo se retiran
-- implementaciones V4 para que ningún cliente actualizado pueda caer en ellas.
drop function if exists public.pasir_delete_transaction(uuid,text);
drop function if exists public.pasir_delete_transaction_v480(uuid,text);
drop function if exists public.pasir_delete_transaction_v491(uuid,text,jsonb);
drop function if exists public.pasir_clear_workspace_data_v491(uuid);

commit;

-- ============================================================================
-- DIAGNÓSTICO OPCIONAL (solo lectura)
-- 1) El ID de pasir_transactions es TEXT, por lo que admite UUID, timestamps,
--    números convertidos a texto y IDs legacy sin cambiar el tipo de columna.
-- 2) La consulta siguiente ayuda a detectar movimientos potencialmente duplicados.
--    NO borra ni modifica nada.
-- ============================================================================
-- select workspace_id, tx_date, type, amount, currency,
--        coalesce(account_id,''), coalesce(from_account_id,''), coalesce(to_account_id,''),
--        coalesce(concept,''), count(*) as posibles_duplicados,
--        array_agg(id order by id) as ids
--   from public.pasir_transactions
--  group by workspace_id, tx_date, type, amount, currency,
--           coalesce(account_id,''), coalesce(from_account_id,''), coalesce(to_account_id,''),
--           coalesce(concept,'')
-- having count(*) > 1
--  order by posibles_duplicados desc, tx_date desc;
