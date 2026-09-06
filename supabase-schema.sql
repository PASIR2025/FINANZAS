-- PASIR Gestión V4.7.0 · Supabase multiusuario
-- Ejecutar una sola vez en Supabase > SQL Editor.
-- Luego usa en la PWA únicamente Project URL + anon/publishable key.

create extension if not exists pgcrypto;

create table if not exists public.pasir_workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'ESCUELA PASIR',
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.pasir_memberships (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.pasir_workspaces(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  invited_email text,
  display_name text,
  role text not null default 'operator' check (role in ('owner','admin','operator','viewer')),
  permissions jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,user_id)
);
create unique index if not exists pasir_memberships_pending_email_uq
on public.pasir_memberships(workspace_id,lower(invited_email)) where user_id is null and invited_email is not null;

create table if not exists public.pasir_shared_data (
  workspace_id uuid primary key references public.pasir_workspaces(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.pasir_private_data (
  workspace_id uuid primary key references public.pasir_workspaces(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table if not exists public.pasir_transactions (
  workspace_id uuid not null references public.pasir_workspaces(id) on delete cascade,
  id text not null,
  tx_date date not null,
  tx_time time,
  type text not null check (type in ('income','expense','personal','transfer','owner_withdrawal','capital')),
  amount numeric(16,2) not null check (amount > 0),
  currency text not null default 'PEN' check (currency in ('PEN','USD','USDT')),
  account_id text,
  from_account_id text,
  to_account_id text,
  category text,
  concept text,
  notes text,
  course_id text,
  course_name text,
  customer text,
  payment_method text,
  operation_number text,
  created_by uuid not null references auth.users(id),
  created_by_name text,
  updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key(workspace_id,id)
);
create index if not exists pasir_transactions_date_idx on public.pasir_transactions(workspace_id,tx_date desc);
create index if not exists pasir_transactions_creator_idx on public.pasir_transactions(workspace_id,created_by,tx_date desc);

create table if not exists public.pasir_audit_log (
  id bigint generated always as identity primary key,
  workspace_id uuid not null references public.pasir_workspaces(id) on delete cascade,
  entity_type text not null,
  entity_id text,
  action text not null,
  actor_id uuid references auth.users(id),
  actor_email text,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);
create index if not exists pasir_audit_workspace_idx on public.pasir_audit_log(workspace_id,created_at desc);

-- Helpers SECURITY DEFINER para evitar recursión RLS.
create or replace function public.pasir_role(p_workspace uuid)
returns text
language sql
stable
security definer
set search_path=public
as $$
  select case
    when exists(select 1 from public.pasir_workspaces w where w.id=p_workspace and w.owner_id=auth.uid()) then 'owner'
    else coalesce((select m.role from public.pasir_memberships m where m.workspace_id=p_workspace and m.user_id=auth.uid() and m.active limit 1),'')
  end;
$$;

create or replace function public.pasir_is_member(p_workspace uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select public.pasir_role(p_workspace) <> '';
$$;

create or replace function public.pasir_is_manager(p_workspace uuid)
returns boolean
language sql
stable
security definer
set search_path=public
as $$
  select public.pasir_role(p_workspace) in ('owner','admin');
$$;

create or replace function public.pasir_has_permission(p_workspace uuid, p_permission text)
returns boolean
language plpgsql
stable
security definer
set search_path=public
as $$
declare
  r text;
  p jsonb;
begin
  r := public.pasir_role(p_workspace);
  if r in ('owner','admin') then return true; end if;
  select permissions into p from public.pasir_memberships
   where workspace_id=p_workspace and user_id=auth.uid() and active limit 1;
  return coalesce((p->>p_permission)::boolean,false);
end;
$$;

-- Crear un espacio de trabajo desde el cliente sin service_role.
create or replace function public.pasir_create_workspace(p_name text default 'ESCUELA PASIR')
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_id uuid;
  v_email text;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  select email into v_email from auth.users where id=auth.uid();
  insert into public.pasir_workspaces(name,owner_id) values(coalesce(nullif(trim(p_name),''),'ESCUELA PASIR'),auth.uid()) returning id into v_id;
  insert into public.pasir_memberships(workspace_id,user_id,invited_email,display_name,role,permissions,active)
  values(v_id,auth.uid(),v_email,coalesce(v_email,'Propietario'),'owner','{}'::jsonb,true)
  on conflict(workspace_id,user_id) do nothing;
  insert into public.pasir_shared_data(workspace_id,updated_by) values(v_id,auth.uid()) on conflict do nothing;
  insert into public.pasir_private_data(workspace_id,updated_by) values(v_id,auth.uid()) on conflict do nothing;
  return v_id;
end;
$$;

-- Invitar por correo. Si el usuario ya existe, se vincula inmediatamente.
create or replace function public.pasir_invite_member(
  p_workspace uuid,
  p_email text,
  p_display_name text,
  p_role text,
  p_permissions jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user uuid;
  v_id uuid;
begin
  if not public.pasir_is_manager(p_workspace) then raise exception 'Sin permiso'; end if;
  if p_role not in ('admin','operator','viewer') then raise exception 'Rol no válido'; end if;
  select id into v_user from auth.users where lower(email)=lower(trim(p_email)) limit 1;
  if v_user is not null then
    insert into public.pasir_memberships(workspace_id,user_id,invited_email,display_name,role,permissions,active)
    values(p_workspace,v_user,lower(trim(p_email)),coalesce(nullif(trim(p_display_name),''),p_email),p_role,coalesce(p_permissions,'{}'::jsonb),true)
    on conflict(workspace_id,user_id) do update set invited_email=excluded.invited_email,display_name=excluded.display_name,role=excluded.role,permissions=excluded.permissions,active=true,updated_at=now()
    returning id into v_id;
  else
    insert into public.pasir_memberships(workspace_id,user_id,invited_email,display_name,role,permissions,active)
    values(p_workspace,null,lower(trim(p_email)),coalesce(nullif(trim(p_display_name),''),p_email),p_role,coalesce(p_permissions,'{}'::jsonb),true)
    on conflict (workspace_id, lower(invited_email)) where user_id is null and invited_email is not null
    do update set display_name=excluded.display_name,role=excluded.role,permissions=excluded.permissions,active=true,updated_at=now()
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

-- Cuando un invitado crea su cuenta, reclama automáticamente su invitación.
create or replace function public.pasir_claim_invites()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  update public.pasir_memberships
     set user_id=new.id, updated_at=now()
   where user_id is null and invited_email is not null and lower(invited_email)=lower(new.email);
  return new;
end;
$$;
drop trigger if exists pasir_claim_invites_after_signup on auth.users;
create trigger pasir_claim_invites_after_signup
after insert on auth.users
for each row execute function public.pasir_claim_invites();

-- Auditoría de movimientos.
create or replace function public.pasir_audit_transaction()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_ws uuid;
  v_id text;
  v_email text;
begin
  v_ws := coalesce(new.workspace_id,old.workspace_id);
  v_id := coalesce(new.id,old.id);
  select email into v_email from auth.users where id=auth.uid();
  insert into public.pasir_audit_log(workspace_id,entity_type,entity_id,action,actor_id,actor_email,old_data,new_data)
  values(v_ws,'transaction',v_id,TG_OP,auth.uid(),v_email,to_jsonb(old),to_jsonb(new));
  if TG_OP='DELETE' then return old; else return new; end if;
end;
$$;
drop trigger if exists pasir_transactions_audit on public.pasir_transactions;
create trigger pasir_transactions_audit
after insert or update or delete on public.pasir_transactions
for each row execute function public.pasir_audit_transaction();

-- Timestamps.
create or replace function public.pasir_touch_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists pasir_memberships_touch on public.pasir_memberships;
create trigger pasir_memberships_touch before update on public.pasir_memberships for each row execute function public.pasir_touch_updated_at();
drop trigger if exists pasir_shared_touch on public.pasir_shared_data;
create trigger pasir_shared_touch before update on public.pasir_shared_data for each row execute function public.pasir_touch_updated_at();
drop trigger if exists pasir_private_touch on public.pasir_private_data;
create trigger pasir_private_touch before update on public.pasir_private_data for each row execute function public.pasir_touch_updated_at();
drop trigger if exists pasir_transactions_touch on public.pasir_transactions;
create trigger pasir_transactions_touch before update on public.pasir_transactions for each row execute function public.pasir_touch_updated_at();

-- RLS
alter table public.pasir_workspaces enable row level security;
alter table public.pasir_memberships enable row level security;
alter table public.pasir_shared_data enable row level security;
alter table public.pasir_private_data enable row level security;
alter table public.pasir_transactions enable row level security;
alter table public.pasir_audit_log enable row level security;

-- Workspaces
drop policy if exists "pasir workspace read" on public.pasir_workspaces;
create policy "pasir workspace read" on public.pasir_workspaces for select using (public.pasir_is_member(id) or owner_id=auth.uid());

-- Memberships
drop policy if exists "pasir membership read" on public.pasir_memberships;
create policy "pasir membership read" on public.pasir_memberships for select using (user_id=auth.uid() or public.pasir_is_manager(workspace_id));
drop policy if exists "pasir membership owner insert" on public.pasir_memberships;
create policy "pasir membership owner insert" on public.pasir_memberships for insert with check (exists(select 1 from public.pasir_workspaces w where w.id=workspace_id and w.owner_id=auth.uid()));
drop policy if exists "pasir membership update" on public.pasir_memberships;
create policy "pasir membership update" on public.pasir_memberships for update using (public.pasir_is_manager(workspace_id)) with check (public.pasir_is_manager(workspace_id));

-- Shared: productos, fichas, metas visibles y medios sin saldo.
drop policy if exists "pasir shared read" on public.pasir_shared_data;
create policy "pasir shared read" on public.pasir_shared_data for select using (public.pasir_is_member(workspace_id));
drop policy if exists "pasir shared write" on public.pasir_shared_data;
create policy "pasir shared write" on public.pasir_shared_data for all using (public.pasir_is_manager(workspace_id)) with check (public.pasir_is_manager(workspace_id));

-- Private: saldos, caja, presupuestos, por cobrar/pagar, etc.
drop policy if exists "pasir private manager only" on public.pasir_private_data;
create policy "pasir private manager only" on public.pasir_private_data for all using (public.pasir_is_manager(workspace_id)) with check (public.pasir_is_manager(workspace_id));

-- Transactions: managers see all; operators only their own when permitted.
drop policy if exists "pasir tx read" on public.pasir_transactions;
create policy "pasir tx read" on public.pasir_transactions for select using (
  public.pasir_is_manager(workspace_id)
  or (created_by=auth.uid() and public.pasir_has_permission(workspace_id,'view_own_entries'))
);
drop policy if exists "pasir tx insert" on public.pasir_transactions;
create policy "pasir tx insert" on public.pasir_transactions for insert with check (
  created_by=auth.uid()
  and public.pasir_is_member(workspace_id)
  and (
    public.pasir_is_manager(workspace_id)
    or (type='income' and public.pasir_has_permission(workspace_id,'create_sales'))
    or (type='expense' and public.pasir_has_permission(workspace_id,'create_expenses'))
  )
);
drop policy if exists "pasir tx update" on public.pasir_transactions;
create policy "pasir tx update" on public.pasir_transactions for update using (
  public.pasir_is_manager(workspace_id)
  or (created_by=auth.uid() and public.pasir_has_permission(workspace_id,'edit_own_entries'))
) with check (
  public.pasir_is_manager(workspace_id)
  or (created_by=auth.uid() and public.pasir_has_permission(workspace_id,'edit_own_entries'))
);
drop policy if exists "pasir tx delete managers" on public.pasir_transactions;
drop policy if exists "pasir tx delete authorized" on public.pasir_transactions;
create policy "pasir tx delete authorized" on public.pasir_transactions for delete using (
  public.pasir_is_manager(workspace_id)
  or (created_by=auth.uid() and public.pasir_has_permission(workspace_id,'delete_own_entries'))
);

-- Audit only manager.
drop policy if exists "pasir audit manager read" on public.pasir_audit_log;
create policy "pasir audit manager read" on public.pasir_audit_log for select using (public.pasir_is_manager(workspace_id));

-- Borrado verificado de movimientos.
create or replace function public.pasir_delete_transaction(p_workspace uuid,p_id text)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_creator uuid;
  v_allowed boolean;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión'; end if;
  select created_by into v_creator from public.pasir_transactions where workspace_id=p_workspace and id=p_id;
  if not found then return true; end if;
  v_allowed := public.pasir_is_manager(p_workspace)
    or (v_creator=auth.uid() and public.pasir_has_permission(p_workspace,'delete_own_entries'));
  if not v_allowed then raise exception 'Sin permiso para eliminar este movimiento'; end if;
  delete from public.pasir_transactions where workspace_id=p_workspace and id=p_id;
  return not exists(select 1 from public.pasir_transactions where workspace_id=p_workspace and id=p_id);
end;
$$;

-- RPC execution for authenticated users.
grant execute on function public.pasir_create_workspace(text) to authenticated;
grant execute on function public.pasir_invite_member(uuid,text,text,text,jsonb) to authenticated;
grant execute on function public.pasir_role(uuid) to authenticated;
grant execute on function public.pasir_is_member(uuid) to authenticated;
grant execute on function public.pasir_is_manager(uuid) to authenticated;
grant execute on function public.pasir_has_permission(uuid,text) to authenticated;
grant execute on function public.pasir_delete_transaction(uuid,text) to authenticated;

-- Table grants; RLS still decides which rows/actions are allowed.
grant select on public.pasir_workspaces to authenticated;
grant select,insert,update on public.pasir_memberships to authenticated;
grant select,insert,update on public.pasir_shared_data to authenticated;
grant select,insert,update on public.pasir_private_data to authenticated;
grant select,insert,update,delete on public.pasir_transactions to authenticated;
grant select on public.pasir_audit_log to authenticated;
