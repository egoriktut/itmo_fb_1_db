CREATE DATABASE baza;

CREATE SCHEMA bank;

-- или можно руками из эксл сделать экспорт
-- libreoffice --headless --convert-to csv --outdir school/itmo_fb/1_db/SQL/baza/ school/itmo_fb/1_db/SQL/baza/bank_transactions.xlsx

CREATE TABLE bank.temp_data (
    client_name text,
    birth_day text,
    bill_number text,
    balance text,
    currency text,
    transaction_id text,
    type_operation text,
    sum_operation text,
    transaction_data text
);

copy bank.temp_data FROM '/home/bank_transactions.csv' WITH (
    FORMAT csv,
    DELIMITER ',',
    HEADER true,
    ENCODING 'UTF8'
);

CREATE TABLE bank.raw_data
(
    client_name text,
    birth_day date,
    bill_number text,
    balance numeric(16, 2),
    currency varchar(3),
    transaction_id text,
    type_operation text,
    sum_operation numeric(16, 2),
    transaction_data date
);

INSERT INTO bank.raw_data
SELECT
    client_name,
    TO_DATE(birth_day, 'DD.MM.YYYY'),
    bill_number,
    REPLACE(REPLACE(balance, ',', '.'), ' ', '')::numeric(16,2),
    currency,
    transaction_id,
    type_operation,
    REPLACE(REPLACE(sum_operation, ',', '.'), ' ', '')::numeric(16,2),
    TO_DATE(transaction_data, 'DD.MM.YYYY')
FROM bank.temp_data;

DROP TABLE bank.temp_data;


CREATE TABLE bank.clients (
    id SERIAL PRIMARY KEY,
    name text,
    birth_day date
);

SELECT DISTINCT currency from bank.raw_data;
-- EUR, RUB, USD
CREATE TYPE currency_type AS ENUM ('EUR', 'RUB', 'USD');

CREATE TABLE bank.clients_bill (
    id SERIAL PRIMARY KEY,
    bill_number text,
    balance numeric(16, 2),
    currency currency_type,
    client_id integer REFERENCES bank.clients(id) ON DELETE CASCADE
);

SELECT DISTINCT type_operation from bank.raw_data;
-- списание, пополнение
CREATE TYPE operation_type AS ENUM ('списание', 'пополнение');

CREATE TABLE bank.client_transaction (
    id SERIAL PRIMARY KEY,
    transaction_id text,
    type_operation operation_type,
    sum_operation numeric(16, 2),
    transaction_data date,
    bill_id integer REFERENCES bank.clients_bill(id) ON DELETE CASCADE
);

INSERT INTO
    bank.clients (name, birth_day)
SELECT DISTINCT
    client_name,
    birth_day
FROM bank.raw_data;

-- DROP VIEW bank.last_balance;
CREATE VIEW bank.last_balance AS
SELECT DISTINCT
    bill_number,
    first_value(balance) over (PARTITION BY bill_number ORDER BY transaction_data DESC) as last_balance
FROM bank.raw_data;

INSERT INTO
    bank.clients_bill (bill_number, balance, currency, client_id)
SELECT DISTINCT
    rw.bill_number,
    last_balance,
    cast(rw.currency AS currency_type),
    c.id
FROM bank.raw_data rw
JOIN bank.clients c ON
    rw.client_name = c.name
        AND
    rw.birth_day = c.birth_day
JOIN bank.last_balance lb ON lb.bill_number = rw.bill_number;

INSERT INTO
    bank.client_transaction (transaction_id, type_operation, sum_operation, transaction_data, bill_id)
SELECT
    transaction_id,
    cast(type_operation as operation_type),
    sum_operation,
    transaction_data,
    cb.id
FROM bank.raw_data
JOIN bank.clients_bill cb ON raw_data.bill_number = cb.bill_number;

-- Запросы для проверки
SELECT count(*) FROM bank.clients;
SELECT count(*) FROM  bank.clients_bill;
SELECT count(*) FROM  bank.client_transaction;
SELECT count(*) FROM bank.last_balance;

SELECT
    c.id as client_id,
    cb.id as client_bill_id,
    name,
    birth_day,
    bill_number,
    currency
FROM
    bank.clients c
JOIN bank.clients_bill cb ON c.id = cb.client_id
ORDER BY c.birth_day, c.name;

SELECT
    c.id as client_id,
    cb.id as client_bill_id,
    ct.id as transacction_id,
    name,
    birth_day,
    bill_number,
    type_operation,
    balance,
    sum_operation,
    transaction_data
FROM
    bank.clients c
JOIN bank.clients_bill cb ON c.id = cb.client_id
JOIN bank.client_transaction ct on cb.id = ct.bill_id
ORDER BY c.name, ct.transaction_data;