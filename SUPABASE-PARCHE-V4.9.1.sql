-- =====================================================================
-- PASIR Gestión V4.9.1 — BORRADO REAL DE REGISTROS HEREDADOS + LIMPIEZA TOTAL
-- Ejecutar en Supabase > SQL Editor > Run.
-- Es idempotente. NO elimina usuarios, roles, membresías ni el workspace.
-- Requiere que el esquema multiusuario de PASIR ya exista.
-- =====================================================================

-- Borrado individual robusto. Primero busca por ID; si es un registro heredado
-- con ID local diferente, usa una huella exacta/segura para localizar UNA fila.
create or replace function public.pasir_delete_transaction_v491(
  p_workspace uuid,
  p_id text,
  p_fingerprint jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_target text;
  v_creator uuid;
  v_role text;
  v_count integer := 0;
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
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if not public.pasir_is_member(p_workspace) then raise exception 'No perteneces a este espacio PASIR'; end if;
  v_role := public.pasir_role(p_workspace);

  -- 1) Coincidencia directa por ID.
  select id, created_by into v_target, v_creator
    from public.pasir_transactions
   where workspace_id=p_workspace and id=p_id
   limit 1;

  -- 2) Si el ID heredado no coincide, intenta resolver por fingerprint.
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

    select count(*), min(id)
      into v_count, v_target
      from public.pasir_transactions t
     where t.workspace_id=p_workspace
       and (v_date is null or t.tx_date=v_date)
       and (v_type is null or t.type=v_type)
       and (v_amount is null or t.amount=v_amount)
       and (v_currency is null or t.currency=v_currency)
       and coalesce(to_char(t.tx_time,'HH24:MI'),'')=v_time
       and coalesce(t.account_id,'')=v_account
       and coalesce(t.from_account_id,'')=v_from
       and coalesce(t.to_account_id,'')=v_to
       and coalesce(t.category,'')=v_category
       and coalesce(t.concept,'')=v_concept
       and coalesce(t.notes,'')=v_notes
       and coalesce(t.course_id,'')=v_course_id
       and coalesce(t.course_name,'')=v_course
       and coalesce(t.customer,'')=v_customer
       and coalesce(t.payment_method,'')=v_payment
       and coalesce(t.operation_number,'')=v_operation
       and (public.pasir_is_manager(p_workspace) or t.created_by=auth.uid());

    -- Fallback prudente para versiones antiguas que no guardaban todos los campos.
    if v_count=0 then
      select count(*), min(id)
        into v_count, v_target
        from public.pasir_transactions t
       where t.workspace_id=p_workspace
         and (v_date is null or t.tx_date=v_date)
         and (v_type is null or t.type=v_type)
         and (v_amount is null or t.amount=v_amount)
         and (v_currency is null or t.currency=v_currency)
         and (v_concept='' or coalesce(t.concept,'')=v_concept)
         and (v_account='' or coalesce(t.account_id,'')=v_account)
         and (v_from='' or coalesce(t.from_account_id,'')=v_from)
         and (v_to='' or coalesce(t.to_account_id,'')=v_to)
         and (public.pasir_is_manager(p_workspace) or t.created_by=auth.uid());
    end if;

    if v_count <> 1 then
      v_target := null;
    else
      select created_by into v_creator
        from public.pasir_transactions
       where workspace_id=p_workspace and id=v_target;
    end if;
  end if;

  -- Si ya fue borrado por ese ID, responde OK sin resucitarlo.
  if v_target is null and exists(
    select 1 from public.pasir_transaction_tombstones
     where workspace_id=p_workspace and transaction_id=p_id
  ) then
    return jsonb_build_object('ok',true,'id',p_id,'actual_id',p_id,'already_deleted',true);
  end if;

  if v_target is null then
    return jsonb_build_object('ok',false,'id',p_id,'reason','no_unique_remote_match','message','No se encontró una única fila remota que corresponda a este movimiento heredado');
  end if;

  v_allowed := public.pasir_is_manager(p_workspace)
    or (v_creator=auth.uid() and public.pasir_has_permission(p_workspace,'delete_own_entries'));
  if not v_allowed then raise exception 'Sin permiso para eliminar este movimiento'; end if;

  -- Tombstone del ID real remoto.
  insert into public.pasir_transaction_tombstones(workspace_id,transaction_id,deleted_by,deleted_at)
  values(p_workspace,v_target,auth.uid(),now())
  on conflict(workspace_id,transaction_id)
  do update set deleted_by=excluded.deleted_by,deleted_at=excluded.deleted_at;

  -- Tombstone también del alias local heredado si era distinto.
  if p_id is not null and p_id<>'' and p_id<>v_target then
    insert into public.pasir_transaction_tombstones(workspace_id,transaction_id,deleted_by,deleted_at)
    values(p_workspace,p_id,auth.uid(),now())
    on conflict(workspace_id,transaction_id)
    do update set deleted_by=excluded.deleted_by,deleted_at=excluded.deleted_at;
  end if;

  delete from public.pasir_transactions
   where workspace_id=p_workspace and id=v_target;

  if exists(select 1 from public.pasir_transactions where workspace_id=p_workspace and id=v_target) then
    raise exception 'Supabase no pudo eliminar físicamente el movimiento';
  end if;

  return jsonb_build_object('ok',true,'id',p_id,'actual_id',v_target,'role',v_role,'legacy_id',(v_target<>p_id));
end;
$$;

grant execute on function public.pasir_delete_transaction_v491(uuid,text,jsonb) to authenticated;

-- Limpieza TOTAL del workspace. No depende de los IDs que tenga el navegador.
-- Esto es lo que corrige definitivamente "Eliminar todos los datos".
create or replace function public.pasir_clear_workspace_data_v491(p_workspace uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_deleted integer := 0;
  v_now timestamptz := now();
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  if not public.pasir_is_manager(p_workspace) then raise exception 'Solo Propietario/Administrador puede borrar todos los datos'; end if;

  -- Protege TODOS los IDs actuales para que otro dispositivo viejo no los restaure.
  insert into public.pasir_transaction_tombstones(workspace_id,transaction_id,deleted_by,deleted_at)
  select p_workspace,id,auth.uid(),v_now
    from public.pasir_transactions
   where workspace_id=p_workspace
  on conflict(workspace_id,transaction_id)
  do update set deleted_by=excluded.deleted_by,deleted_at=excluded.deleted_at;

  delete from public.pasir_transactions where workspace_id=p_workspace;
  get diagnostics v_deleted = row_count;

  -- Escribe listas vacías explícitas, para que todos los dispositivos reciban el reset.
  insert into public.pasir_shared_data(workspace_id,data,updated_by,updated_at)
  values(
    p_workspace,
    jsonb_build_object(
      'version','4.9.1','resetAt',v_now,
      'courses','[]'::jsonb,'commercialProfiles','[]'::jsonb,'quickReplies','[]'::jsonb,
      'goals','[]'::jsonb,'projects','[]'::jsonb,'paymentMethods','[]'::jsonb
    ),
    auth.uid(),v_now
  )
  on conflict(workspace_id) do update
    set data=excluded.data,updated_by=excluded.updated_by,updated_at=excluded.updated_at;

  insert into public.pasir_private_data(workspace_id,data,updated_by,updated_at)
  values(
    p_workspace,
    jsonb_build_object(
      'version','4.9.1','resetAt',v_now,
      'rates',jsonb_build_object('USD',3.65,'USDT',3.65),
      'accounts','[]'::jsonb,'receivables','[]'::jsonb,'payables','[]'::jsonb,
      'budgets','[]'::jsonb,'goals','[]'::jsonb,'projects','[]'::jsonb
    ),
    auth.uid(),v_now
  )
  on conflict(workspace_id) do update
    set data=excluded.data,updated_by=excluded.updated_by,updated_at=excluded.updated_at;

  return jsonb_build_object('ok',true,'deleted_transactions',v_deleted,'reset_at',v_now);
end;
$$;

grant execute on function public.pasir_clear_workspace_data_v491(uuid) to authenticated;

select 'PASIR V4.9.1 listo' as estado;
