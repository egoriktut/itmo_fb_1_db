-- ЭТАП 1

CREATE schema raw_data;

CREATE table raw_data.sales (
    id INTEGER PRIMARY KEY,
    auto VARCHAR(100),
    gasoline_consumption NUMERIC default NULL,
    price NUMERIC,
    date DATE,
    person_name VARCHAR(150),
    phone VARCHAR(25),
    discount SMALLINT,
    brand_origin VARCHAR(50)
);

-- Код наполнения  сырой таблицы стоило оставить, чтобы можно было весь скрип целиком выполнить.
--     ОТВЕТ:
-- Заполнял через импорт в ide, вроде так можно было :)
-- -- -- -- --


CREATE schema car_shop;

-- Запросы для понятия ограничений
select length(phone) from raw_data.sales ORDER BY length(phone) DESC LIMIT 1;
select length(person_name) from raw_data.sales ORDER BY length(person_name) DESC LIMIT 1;
select length(brand_origin) from raw_data.sales ORDER BY length(person_name) DESC LIMIT 1;

-- Создание таблиц
CREATE table car_shop.countries (
    id SERIAL PRIMARY KEY,
    -- Из проанализированных данных название состоит из eng букв и максимум 11 символов длина, берем с запасом
    name VARCHAR(15) CHECK ( name ~ '^[A-Za-z\s]+$') not null UNIQUE
);

CREATE table car_shop.colors (
     id SERIAL PRIMARY KEY,
    -- По цвету не нашел инфы, думаю 150 знаков точно хватит
     name varchar(150) CHECK ( name ~ '^[A-Za-z0-9\s\-\.]+$' ) not null UNIQUE
);

-- FIXME: Если бы не задание, в одной схеме, хотел бы вынести МИНИМУМ
--  (А то если начать придумывать и масштабировать будет слишком много....)
--  countries и colors в другую схему,
--  по типу extra_information
-- Почему в другую схему?
-- Можешь поподробнее расписать. Не совсем понял, что ты имеешь ввиду.
--     ОТВЕТ:
-- Я считаю, что схемы должны логический делить таблицы на подгруппы, и так как схема car_shop является схемой автосалона,
-- то к ней не имеют отношения цвета и старны, как в примере.
-- У меня была похожая тема на КР в вузе, а именно детейлинг-центр для авто. И я сделал вот такое разбиение.
-- https://github.com/egoriktut/detail_center_db_kursach_8/blob/main/init-scripts/02-create-schemas.sql
-- Правда в проде отдельно я такого не встречал, обычно все пишут в одной схеме
-- Интересно узнать, что ты думаешь на этот счет, излишки это или нет.


CREATE table car_shop.customers (
    id SERIAL PRIMARY KEY,
    -- Из проанализированных данных имя состоит из eng букв и максимум 26 символов длина, берем с запасом
    full_name VARCHAR(30) CHECK ( full_name ~ '^[A-Za-z\s\.]+$') not null,
    -- Из проанализированных номер состоит из цифр - () x + и максимум 22 символов длина, берем с запасом
    phone VARCHAR(22) CHECK ( phone ~ '^[0-9\-x()\.+]+$')
    -- TODO: phone - UNIQUE но не проходят все данные для вставки
);

CREATE table car_shop.brands (
    id SERIAL PRIMARY KEY,
    origin_id INTEGER REFERENCES car_shop.countries (id) on delete set null,
    -- Самое длинное имя бренда авто: Doktor Ingenieur honoris causa Ferdinand Porsche Aktiengesellschaft
    name VARCHAR(67) CHECK ( name ~ '^[A-Za-z0-9\s\-\.]+$' ) not null UNIQUE
);

CREATE table car_shop.brand_models (
    id SERIAL PRIMARY KEY,
    brand_id INTEGER REFERENCES car_shop.brands (id) on delete cascade,
    -- Самое длинное название модели авто Lamborghini Murciélago LP 670-4 SuperVeloce
    name varchar(43) CHECK ( name ~ '^[A-Za-z0-9\s\-\.]+$' ) not null,
    -- Когда говорят про расход, не называют больше одной цифры после ','.
    -- И не бывает расхода у НОРМАЛЬНЫХ машин, больше 100
    gasoline_consumption NUMERIC(3, 1) CHECK (gasoline_consumption BETWEEN 0 and 99)
);

create table car_shop.cars (
    id SERIAL PRIMARY KEY,
    car_name_id INTEGER REFERENCES car_shop.brand_models (id) on delete cascade,
    color_id INTEGER REFERENCES car_shop.colors (id) on delete set null
);

CREATE table car_shop.sales (
    id SERIAL PRIMARY KEY,
    car_id INTEGER REFERENCES car_shop.cars (id) on delete cascade,
    customer_id INTEGER REFERENCES car_shop.customers (id) on delete cascade,
    -- Адекватная цена, до 7 знаков, два знака после запятой, так во всех валютах. Цена не нулевая
    price NUMERIC(9, 2) CHECK (price > 0),
    -- Скида 0-100 %
    discount SMALLINT CHECK ( discount BETWEEN 0 and 100),
    -- По умолчанию проставляем дату продажи сейчас
    date DATE default CURRENT_TIMESTAMP not null
);

-- Вставка данных из raw_data
SELECT * from raw_data.sales;

INSERT INTO
    car_shop.countries (name)
SELECT DISTINCT
    brand_origin
FROM
    raw_data.sales
WHERE
    brand_origin IS NOT NULL;


INSERT INTO
    car_shop.customers (full_name, phone)
SELECT DISTINCT
    person_name, phone
FROM
    raw_data.sales
WHERE
    person_name IS NOT NULL AND phone IS NOT NULL ;


INSERT INTO
    car_shop.colors (name)
SELECT DISTINCT
    SUBSTRING(auto FROM POSITION(',' IN auto) + 2)
FROM
    raw_data.sales
WHERE auto IS NOT NULL;


INSERT INTO
    car_shop.brands (name, origin_id)
SELECT DISTINCT
    SUBSTRING(auto FROM 0 FOR POSITION(' ' IN auto)) as brand,
    country.id
FROM
    raw_data.sales c
JOIN
    car_shop.countries country ON name =c.brand_origin
WHERE c.brand_origin IS NOT NULL AND c.auto IS NOT NULL;


INSERT INTO
    car_shop.brand_models (name, brand_id, gasoline_consumption)
SELECT DISTINCT
    SUBSTRING(
            auto FROM POSITION(' ' IN auto) + 1 FOR (
        POSITION(',' IN auto) - POSITION(' ' IN auto) - 1
        )
    ) as model,
    brand.id,
    gasoline_consumption
FROM
    raw_data.sales c
JOIN
    car_shop.brands brand ON brand.name = SUBSTRING(auto FROM 0 FOR POSITION(' ' IN auto))
WHERE c.brand_origin IS NOT NULL AND c.auto IS NOT NULL;


INSERT INTO
    car_shop.cars (car_name_id, color_id)
SELECT DISTINCT
    b_m.id,
    color.id
FROM
    raw_data.sales c
JOIN
    car_shop.brand_models b_m ON b_m.name =
        SUBSTRING(
            c.auto FROM POSITION(' ' IN c.auto) + 1 FOR (
                POSITION(',' IN c.auto) - POSITION(' ' IN c.auto) - 1
            )
        )
JOIN
    car_shop.colors color ON color.name = SUBSTRING(c.auto FROM POSITION(',' IN c.auto) + 2) ;


INSERT INTO
    car_shop.sales (car_id, customer_id, price, discount, date)
SELECT DISTINCT
    car.id,
    customer.id,
    c.price,
    discount,
    date
FROM
    raw_data.sales c
JOIN
    car_shop.customers customer ON
        customer.full_name = person_name AND customer.phone = c.phone
JOIN car_shop.brand_models model ON model.name =
    SUBSTRING(
        auto FROM POSITION(' ' IN auto) + 1 FOR (
            POSITION(',' IN auto) - POSITION(' ' IN auto) - 1
        )
    )
JOIN
    car_shop.colors color ON color.name = SUBSTRING(c.auto FROM POSITION(',' IN c.auto) + 2)
JOIN
    car_shop.cars car ON car.car_name_id = model.id
WHERE
    car.color_id = color.id;


-- ЭТАП 2

-- Запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption
SELECT
    (
        SELECT COUNT(*) FROM car_shop.brand_models WHERE COALESCE(gasoline_consumption, 0.0) = 0.0
    )::numeric / (
        SELECT COUNT(*) FROM car_shop.brand_models
    ) * 100
    AS nulls_percentage_gasoline_consumption;

-- Для упрощения запросов создаю представление
CREATE OR REPLACE VIEW
    car_shop.cars_with_info
AS
    SELECT
        car.id AS car_id,
        customer_id,
        concat(brand.name, ' ', bm.name) AS full_name_model,
        brand.name AS brand_name,
        bm.name AS model,
        date,
        color_id,
        price,
        discount,
        origin_id
    FROM
        car_shop.sales
    JOIN
        car_shop.cars car on sales.car_id = car.id
    JOIN
        car_shop.brand_models bm on bm.id = car.car_name_id
    JOIN
        car_shop.brands brand on brand.id = bm.brand_id;


--  Запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам
--  с учётом скидки. Итоговый результат отсортируйте по названию бренда и году в восходящем порядке.
--  Среднюю цену округлите до второго знака после запятой.
SELECT
    brand_name,
    EXTRACT(YEAR FROM date) as year,
    ROUND(AVG(price), 2)
FROM
    car_shop.cars_with_info
GROUP BY
    year, brand_name
ORDER BY
    brand_name;

-- Среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.
-- Результат отсортируйте по месяцам в восходящем порядке.
-- Среднюю цену округлите до второго знака после запятой.
SELECT
    EXTRACT(MONTH FROM date) as month,
    '2022' AS year,
    ROUND(AVG(price), 2)
FROM
    car_shop.cars_with_info
WHERE
    EXTRACT(YEAR FROM date) = '2022'
GROUP BY
    month;

--  Запрос, который выведет список купленных машин у каждого пользователя через запятую.
--  Пользователь может купить две одинаковые машины — это нормально.
--  Название машины покажите полное, с названием бренда — например: Tesla Model 3.
--  Отсортируйте по имени пользователя в восходящем порядке. Сортировка внутри самой строки с машинами не нужна.
SELECT
    cust.full_name,
    STRING_AGG(car_info.full_name_model, ', ') AS cars
FROM
    car_shop.cars_with_info car_info
JOIN
    car_shop.customers cust on cust.id = car_info.customer_id
GROUP BY cust.full_name;


-- Запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране
-- без учёта скидки. Цена в колонке price дана с учётом скидки.
SELECT
    countries.name AS brand_origin,
    MAX(price / (1 - 0.01 * discount)) as price_max,
    MIN(price / (1 - 0.01 * discount)) as price_min
FROM
    car_shop.cars_with_info
JOIN
    car_shop.countries ON countries.id = origin_id
GROUP BY
    countries.name;

-- Запрос, который покажет количество всех пользователей из США.
-- Это пользователи, у которых номер телефона начинается на +1
SELECT
    COUNT(*) AS persons_from_usa_count
FROM
    car_shop.customers
WHERE
    phone ~ '^\+1[0-9\-()x]+$';