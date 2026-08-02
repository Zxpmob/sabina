-- ==========================================================
-- کافه صابینا | Sabina Cafe — اسکریپت کامل و نهایی دیتابیس
-- ==========================================================
-- کل این فایل را یکجا در Supabase → SQL Editor → New query
-- پیست کنید و دکمه Run را بزنید. همه‌چیز را می‌سازد:
-- جدول‌ها، دسترسی‌ها (RLS)، باکت عکس‌ها، رویدادها، و امکان
-- ساخت دسته‌بندی جدید از پنل مدیریت.
--
-- این اسکریپت idempotent است، یعنی اگر قبلاً بخشی از آن را
-- اجرا کرده باشید (مثلاً setup اولیه)، دوباره اجرای کل فایل
-- مشکلی ایجاد نمی‌کند و فقط چیزهای جدید را اضافه می‌کند.
-- ==========================================================

-- ==========================================================
-- ۱) جدول دسته‌بندی‌ها
-- ==========================================================
create table if not exists categories (
  slug text primary key,
  name text not null,
  icon text not null,
  sort_order int not null default 0
);

insert into categories (slug, name, icon, sort_order) values
('special',  'نوشیدنی‌های ویژه', '⭐', 1),
('cold',     'نوشیدنی‌های سرد',  '🧊', 2),
('hot',      'نوشیدنی‌های گرم',  '☕', 3),
('icetea',   'ایس‌تی',           '🍹', 4),
('tea',      'چای',              '🍵', 5),
('mocktail', 'ماکتیل',           '🍸', 6),
('shake',    'شیک',              '🥤', 7),
('dessert',  'دسر',              '🍰', 8)
on conflict (slug) do update set name = excluded.name, icon = excluded.icon;

-- ==========================================================
-- ۲) جدول آیتم‌های منو
-- ==========================================================
create table if not exists items (
  id bigint generated always as identity primary key,
  name text not null,
  ingredients text,
  category_slug text not null references categories(slug),
  price integer not null default 0,
  image_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- چند آیتم نمونه (اختیاری) — بعداً از پنل مدیریت می‌توانید حذف/ویرایش کنید.
-- توجه: این آیتم‌ها هیچ محدودیت یکتابودن ندارند — اگر این اسکریپت را
-- دوباره روی همان دیتابیس اجرا کنید، همین ۸ آیتم دوباره تکرار می‌شوند.
-- برای اجرای دوباره‌ی فایل (مثلاً فقط برای به‌روزرسانی دسترسی‌ها)،
-- این بلوک insert را با گذاشتن -- در ابتدای هر خط، کامنت کنید.
insert into items (name, ingredients, category_slug, price) values
('اسپرسو صابینا', 'اسپرسو دوبل، کف ملایم', 'special', 75000),
('آیس آمریکانو', 'اسپرسو، آب سرد، یخ', 'cold', 85000),
('کاپوچینو گرم', 'اسپرسو، شیر بخارداده', 'hot', 95000),
('ایس‌تی هلو', 'چای سرد، شربت هلو، یخ', 'icetea', 80000),
('چای ماسالا', 'چای دم‌کرده، دارچین، هل، زنجبیل', 'tea', 65000),
('ماکتیل توت‌فرنگی', 'پوره توت‌فرنگی، سودا، نعنا', 'mocktail', 110000),
('شیک شکلات', 'بستنی وانیل، شکلات، شیر', 'shake', 120000),
('چیزکیک زرشکی', 'پنیر خامه‌ای، سس زرشک', 'dessert', 135000);

-- به‌روزرسانی خودکار updated_at هنگام ویرایش آیتم
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists items_updated_at on items;
create trigger items_updated_at
before update on items
for each row execute function set_updated_at();

-- ==========================================================
-- ۳) جدول ثبت بازدیدها
-- ==========================================================
create table if not exists visits (
  id bigint generated always as identity primary key,
  visited_at timestamptz not null default now(),
  session_id text
);
create index if not exists idx_visits_time on visits (visited_at);

-- ==========================================================
-- ۴) جدول رویدادها (اسلایدر بالای دکمه «مشاهده منو»)
-- ==========================================================
create table if not exists events (
  id bigint generated always as identity primary key,
  title text not null,
  description text,
  image_url text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- ==========================================================
-- ۵) دسترسی‌ها (Row Level Security)
-- منو و رویدادهای فعال برای همه (حتی بدون ورود) قابل خواندن است،
-- اما فقط مدیر لاگین‌شده می‌تواند چیزی اضافه/ویرایش/حذف کند.
-- ==========================================================
alter table categories enable row level security;
alter table items enable row level security;
alter table visits enable row level security;
alter table events enable row level security;

-- دسته‌بندی‌ها
drop policy if exists "categories readable by everyone" on categories;
create policy "categories readable by everyone"
  on categories for select using (true);

drop policy if exists "categories insertable by admins only" on categories;
create policy "categories insertable by admins only"
  on categories for insert with check (auth.role() = 'authenticated');

drop policy if exists "categories updatable by admins only" on categories;
create policy "categories updatable by admins only"
  on categories for update using (auth.role() = 'authenticated');

-- آیتم‌های منو
drop policy if exists "items readable by everyone" on items;
create policy "items readable by everyone"
  on items for select using (true);

drop policy if exists "items insertable by admins only" on items;
create policy "items insertable by admins only"
  on items for insert with check (auth.role() = 'authenticated');

drop policy if exists "items updatable by admins only" on items;
create policy "items updatable by admins only"
  on items for update using (auth.role() = 'authenticated');

drop policy if exists "items deletable by admins only" on items;
create policy "items deletable by admins only"
  on items for delete using (auth.role() = 'authenticated');

-- بازدیدها
drop policy if exists "anyone can log a visit" on visits;
create policy "anyone can log a visit"
  on visits for insert with check (true);

drop policy if exists "only admins can read visit stats" on visits;
create policy "only admins can read visit stats"
  on visits for select using (auth.role() = 'authenticated');

-- رویدادها
drop policy if exists "events readable when active" on events;
create policy "events readable when active"
  on events for select using (active = true);

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

-- ==========================================================
-- ۶) باکت ذخیره‌سازی عکس‌ها (آیتم‌های منو + رویدادها)
-- ==========================================================
insert into storage.buckets (id, name, public)
values ('menu-images', 'menu-images', true)
on conflict (id) do nothing;

drop policy if exists "public read menu images" on storage.objects;
create policy "public read menu images"
  on storage.objects for select
  using (bucket_id = 'menu-images');

drop policy if exists "admins can upload menu images" on storage.objects;
create policy "admins can upload menu images"
  on storage.objects for insert
  with check (bucket_id = 'menu-images' and auth.role() = 'authenticated');

drop policy if exists "admins can update menu images" on storage.objects;
create policy "admins can update menu images"
  on storage.objects for update
  using (bucket_id = 'menu-images' and auth.role() = 'authenticated');

drop policy if exists "admins can delete menu images" on storage.objects;
create policy "admins can delete menu images"
  on storage.objects for delete
  using (bucket_id = 'menu-images' and auth.role() = 'authenticated');


-- ==========================================================
-- کوئری‌های کلی و مفید برای مدیریت (نمونه — نیازی به اجرا الان نیست)
-- این‌ها را هر وقت خواستید آمار بگیرید، جداگانه در SQL Editor
-- اجرا کنید (خط موردنظر را از حالت کامنت -- خارج کنید).
-- ==========================================================

-- تعداد کل بازدید سایت
-- select count(*) as total_visits from visits;

-- بازدید ۲۴ ساعت گذشته
-- select count(*) as last_24h from visits where visited_at >= now() - interval '24 hours';

-- بازدید هر روز، در ۳۰ روز اخیر
-- select date(visited_at) as day, count(*) as visits
-- from visits
-- where visited_at >= now() - interval '30 days'
-- group by day order by day desc;

-- تعداد آیتم‌های هر دسته‌بندی
-- select c.name, count(i.id) as item_count
-- from categories c left join items i on i.category_slug = c.slug
-- group by c.name order by item_count desc;

-- گران‌ترین آیتم‌های منو
-- select name, price from items order by price desc limit 10;

-- ارزان‌ترین آیتم‌های منو
-- select name, price from items order by price asc limit 10;

-- آخرین آیتم‌های اضافه‌شده به منو
-- select name, category_slug, price, created_at from items order by created_at desc limit 10;

-- میانگین قیمت هر دسته‌بندی
-- select category_slug, round(avg(price)) as avg_price from items group by category_slug;

-- جست‌وجوی یک آیتم با نام
-- select * from items where name ilike '%اسپرسو%';

-- همه رویدادهای فعال
-- select title, active, created_at from events where active = true order by created_at desc;
