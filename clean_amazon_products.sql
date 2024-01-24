begin;

create schema if not exists raw;

create table if not exists raw.products (
	id bigint,
	name text,
	main_category text,
	sub_category text,
	image text,
	link text,
	ratings text,
	no_of_ratings text,
	discount_price text,
	actual_price text
);


\COPY raw.products from PROGRAM 'gzip -c -d ./amazon-products.csv.gz' delimiter ',' csv header;

commit;


begin;
create schema if not exists ebisaan;
create table if not exists ebisaan.main_categories (
	id bigserial primary key,
	name text
);

create table if not exists ebisaan.sub_categories (
	id bigserial primary key,
	name text,
	main_category_id integer
);

create table if not exists ebisaan.currencies (
	id bigserial primary key,
	code text,
	symbol text
);

create table if not exists ebisaan.products(
	id bigserial primary key,
	name text,
	main_category_id integer,
	sub_category_id integer,
	stock_number bigint,
	image text,
	discount_price numeric,
	actual_price numeric,
	currency_id bigint
);

create or replace function ebisaan.random(a int, b int)
	returns int
	VOLATILE
	LANGUAGE sql
as $$
	select a + ((b - a) * random())::int;
$$;

insert into ebisaan.currencies (code, symbol) values ('USD', '$'), ('INR', '₹'), ('VND', '₫');

insert into ebisaan.main_categories (name)
SELECT distinct main_category from raw.products;

insert into ebisaan.sub_categories (name, main_category_id)
select c.sub_category, mc.id from (select distinct main_category, sub_category from raw.products) c join ebisaan.main_categories mc on c.main_category = mc.name;

insert into ebisaan.products (name, main_category_id, sub_category_id, stock_number, image, discount_price, actual_price, currency_id)
select rp.name, mc.id, sc.id, ebisaan.random(1, 1000), rp.image, regexp_replace(rp.discount_price, '[₹,]', '', 'g')::numeric, regexp_replace(rp.actual_price, '[₹,]', '', 'g')::numeric, c.id
from raw.products rp join ebisaan.main_categories mc on rp.main_category = mc.name join ebisaan.sub_categories sc on rp.sub_category = sc.name left join ebisaan.currencies c on substring(rp.actual_price from 1 for 1) = c.symbol
where rp.actual_price is not NULL;

alter table if exists ebisaan.main_categories add constraint main_categories_name_unique_idx unique (id);
alter table if exists ebisaan.sub_categories add constraint sub_categories_name_unique_idx unique (id);
alter table if exists ebisaan.currencies add constraint currencies_code_unique_idx unique (code);
alter table if exists ebisaan.currencies add constraint currencies_symbol_unique_idx unique (symbol);
alter table if exists ebisaan.currencies add constraint currencies_code_symbol_unique_idx unique (code, symbol);

alter table if exists ebisaan.sub_categories add constraint sub_categories_main_category_id_fkey foreign key (main_category_id) REFERENCES ebisaan.main_categories(id);
alter table if exists ebisaan.products add constraint products_main_category_id_fkey foreign key (main_category_id) REFERENCES ebisaan.main_categories(id);
alter table if exists ebisaan.products add constraint products_sub_category_id_fkey foreign key (sub_category_id) REFERENCES ebisaan.sub_categories(id);
alter table if exists ebisaan.products add constraint products_currency_id_fkey foreign key (currency_id) REFERENCES ebisaan.currencies(id);

drop schema if exists raw cascade;
commit;
