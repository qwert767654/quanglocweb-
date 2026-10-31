-- QLOC Reward v1: Supabase schema for a DEMO rewards app.
-- Run this in Supabase SQL Editor. Never put the service_role key in the frontend.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Member',
  role text not null default 'user' check (role in ('user','admin')),
  created_at timestamptz not null default now()
);
create table if not exists public.wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance bigint not null default 0 check (balance >= 0),
  updated_at timestamptz not null default now()
);
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  reward bigint not null check (reward > 0 and reward <= 10000),
  category text not null default 'General',
  duration text not null default '2 phút',
  task_type text not null default 'internal' check (task_type in ('internal','link')),
  destination_url text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.task_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid not null references public.tasks(id),
  reward bigint not null check (reward > 0),
  status text not null default 'approved' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  unique(user_id, task_id)
);
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  amount bigint not null,
  kind text not null default 'task',
  reference_id uuid,
  created_at timestamptz not null default now()
);

create index if not exists task_completions_user_idx on public.task_completions(user_id, created_at desc);
create index if not exists transactions_user_idx on public.transactions(user_id, created_at desc);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, display_name) values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email,'@',1)));
  insert into public.wallets(user_id) values (new.id);
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- A user can complete each active task only once. Credits are written atomically on the server.
create or replace function public.complete_demo_task(p_task_id uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_task public.tasks%rowtype; v_new_balance bigint;
begin
  if v_user is null then raise exception 'Bạn cần đăng nhập.'; end if;
  select * into v_task from public.tasks where id = p_task_id and active = true;
  if not found then raise exception 'Nhiệm vụ không tồn tại hoặc đã tạm dừng.'; end if;
  insert into public.task_completions(user_id, task_id, reward, status)
  values (v_user, v_task.id, v_task.reward, 'approved');
  insert into public.wallets(user_id, balance) values (v_user, v_task.reward)
  on conflict (user_id) do update set balance = public.wallets.balance + excluded.balance, updated_at = now()
  returning balance into v_new_balance;
  insert into public.transactions(user_id, title, amount, kind, reference_id)
  values (v_user, v_task.title, v_task.reward, 'task', v_task.id);
  return v_new_balance;
exception when unique_violation then
  raise exception 'Bạn đã hoàn thành nhiệm vụ này rồi.';
end; $$;

alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.tasks enable row level security;
alter table public.task_completions enable row level security;
alter table public.transactions enable row level security;

drop policy if exists "profile read own" on public.profiles;
create policy "profile read own" on public.profiles for select to authenticated using (id = (select auth.uid()));
drop policy if exists "wallet read own" on public.wallets;
create policy "wallet read own" on public.wallets for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "active tasks visible" on public.tasks;
create policy "active tasks visible" on public.tasks for select to anon, authenticated using (active = true or exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));
drop policy if exists "completion read own" on public.task_completions;
create policy "completion read own" on public.task_completions for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "transactions read own" on public.transactions;
create policy "transactions read own" on public.transactions for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists "admin manage tasks" on public.tasks;
create policy "admin manage tasks" on public.tasks for all to authenticated using (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin')) with check (exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'admin'));

revoke all on function public.complete_demo_task(uuid) from public;
grant execute on function public.complete_demo_task(uuid) to authenticated;

-- Seed demo tasks (safe to run more than once).
insert into public.tasks(title,description,reward,category,duration,task_type,destination_url)
select v.title,v.description,v.reward,v.category,v.duration,v.task_type,v.destination_url
from (values
 ('Khám phá QLOC Reward','Làm quen với bảng điều khiển và các tính năng cơ bản.',40,'Khởi động','1 phút','internal',null),
 ('Hoàn thiện hồ sơ demo','Kiểm tra thông tin hồ sơ và tùy chỉnh tài khoản.',60,'Hồ sơ','2 phút','internal',null),
 ('Trải nghiệm luồng vượt link','Mở trang đích minh họa rồi quay lại xác nhận hoàn thành demo.',100,'Link demo','2 phút','link','https://example.com'),
 ('Đọc hướng dẫn an toàn','Tìm hiểu cách điểm thưởng và xác minh nhiệm vụ hoạt động.',50,'Kiến thức','3 phút','internal',null)
) as v(title,description,reward,category,duration,task_type,destination_url)
where not exists (select 1 from public.tasks t where t.title = v.title);
