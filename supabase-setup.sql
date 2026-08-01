-- ==========================================================
-- کافه صابینا | Sabina Cafe — اسکریپت کامل Supabase
-- کل این فایل را در Supabase → SQL Editor → New query پیست کنید
-- و دکمه Run را بزنید. هم جدول‌ها، هم دسترسی‌ها (RLS)، هم باکت
-- عکس‌ها را یکجا می‌سازد.
-- ==========================================================

-- ---------- ۱) جدول دسته‌بندی‌ها ----------
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

-- ---------- ۲) جدول آیتم‌های منو ----------
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

-- چند آیتم نمونه (اختیاری) — بعداً از پنل مدیریت می‌توانید حذف/ویرایش کنید
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

-- ---------- ۳) جدول ثبت بازدیدها ----------
create table if not exists visits (
  id bigint generated always as identity primary key,
  visited_at timestamptz not null default now(),
  session_id text
);
create index if not exists idx_visits_time on visits (visited_at);

-- ==========================================================
-- ۴) دسترسی‌ها (Row Level Security)
-- منو برای همه (حتی بدون ورود) قابل خواندن است، اما فقط کاربر
-- مدیر (لاگین‌شده) می‌تواند آیتم اضافه/ویرایش/حذف کند.
-- ==========================================================
alter table categories enable row level security;
alter table items enable row level security;
alter table visits enable row level security;

drop policy if exists "categories readable by everyone" on categories;
create policy "categories readable by everyone"
  on categories for select using (true);

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

drop policy if exists "anyone can log a visit" on visits;
create policy "anyone can log a visit"
  on visits for insert with check (true);

drop policy if exists "only admins can read visit stats" on visits;
create policy "only admins can read visit stats"
  on visits for select using (auth.role() = 'authenticated');

-- ==========================================================
-- ۵) باکت ذخیره‌سازی عکس آیتم‌های منو
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
-- این‌ها را هر وقت خواستید آمار بگیرید، در SQL Editor اجرا کنید.
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
