-- ==========================================================
-- کافه صابینا | افزودن جدول «رویدادها» (اسلایدر بالای دکمه منو)
-- این اسکریپت را فقط یک‌بار، جدا از setup.sql، در
-- Supabase → SQL Editor → New query اجرا کنید.
-- (اگر setup.sql را از قبل اجرا کرده‌اید، دوباره لازم نیست
-- اجرایش کنید — این فایل فقط چیزهای جدید را اضافه می‌کند.)
-- ==========================================================

create table if not exists events (
  id bigint generated always as identity primary key,
  title text not null,
  description text,
  image_url text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table events enable row level security;

-- بازدیدکننده‌های عادی فقط رویدادهای «فعال» را می‌بینند
drop policy if exists "events readable when active" on events;
create policy "events readable when active"
  on events for select using (active = true);

-- مدیر لاگین‌شده همه رویدادها (فعال و غیرفعال) را می‌بیند
drop policy if exists "events readable by admins" on events;
create policy "events readable by admins"
  on events for select using (auth.role() = 'authenticated');

drop policy if exists "events insertable by admins only" on events;
create policy "events insertable by admins only"
  on events for insert with check (auth.role() = 'authenticated');

drop policy if exists "events updatable by admins only" on events;
create policy "events updatable by admins only"
  on events for update using (auth.role() = 'authenticated');

drop policy if exists "events deletable by admins only" on events;
create policy "events deletable by admins only"
  on events for delete using (auth.role() = 'authenticated');

-- عکس رویدادها هم در همان باکت menu-images (پوشه events/) ذخیره می‌شود
-- که از قبل در setup.sql ساخته و عمومی شده — نیازی به کار اضافه نیست.
