-- =====================================================================
-- E-COMMERCE ANALYTICS: UK Online Retail Dataset (2010-2011)
-- Источник: Kaggle (carrie1/ecommerce-data)
-- БД: PostgreSQL
-- =====================================================================


-- =====================================================================
-- РАЗДЕЛ 1. СОЗДАНИЕ ТАБЛИЦЫ И ЗАГРУЗКА ДАННЫХ
-- =====================================================================

-- Создаём таблицу под структуру исходного CSV
CREATE TABLE ecommerce_orders (
    invoice_no      VARCHAR(20),
    stock_code      VARCHAR(20),
    description     TEXT,
    quantity        INTEGER,
    invoice_date    VARCHAR(30),   -- сначала как текст, конвертируем позже
    unit_price      NUMERIC(10,2),
    customer_id     INTEGER,
    country         VARCHAR(100)
);

-- Загрузка данных выполнена через pgAdmin: 
-- Import/Export Data -> Import -> data.csv, encoding LATIN1, delimiter ','
-- Результат: 541 909 строк

-- Конвертируем дату из текста в нормальный TIMESTAMP
ALTER TABLE ecommerce_orders ADD COLUMN invoice_date_ts TIMESTAMP;

UPDATE ecommerce_orders
SET invoice_date_ts = TO_TIMESTAMP(invoice_date, 'MM/DD/YYYY HH24:MI');


-- =====================================================================
-- РАЗДЕЛ 2. ОЧИСТКА ДАННЫХ
-- =====================================================================

-- Создаём VIEW с очищенными данными:
-- - убираем отменённые заказы (InvoiceNo начинается на 'C')
-- - убираем отрицательные количества (возвраты)
-- - убираем нулевые/отрицательные цены
-- - убираем строки без customer_id
CREATE VIEW clean_orders AS
SELECT *,
    quantity * unit_price AS total_amount
FROM ecommerce_orders
WHERE invoice_no NOT LIKE 'C%'
    AND quantity > 0
    AND unit_price > 0
    AND customer_id IS NOT NULL;

-- Проверка: сколько строк осталось после очистки
SELECT COUNT(*) FROM clean_orders;
-- Результат: 397 880 строк (из 541 909 исходных)


-- =====================================================================
-- РАЗДЕЛ 3. КЛЮЧЕВЫЕ ПОКАЗАТЕЛИ (KPI)
-- =====================================================================

SELECT
    COUNT(DISTINCT invoice_no)        AS total_orders,
    COUNT(DISTINCT customer_id)       AS total_customers,
    ROUND(SUM(total_amount), 2)       AS total_revenue,
    ROUND(AVG(total_amount), 2)       AS avg_order_line_value,
    MIN(invoice_date_ts)              AS first_order,
    MAX(invoice_date_ts)              AS last_order
FROM clean_orders;


-- =====================================================================
-- РАЗДЕЛ 4. ДИНАМИКА И СТРУКТУРА ПРОДАЖ
-- =====================================================================

-- 4.1 Помесячная динамика продаж
SELECT
    DATE_TRUNC('month', invoice_date_ts) AS month,
    COUNT(DISTINCT invoice_no)            AS orders,
    ROUND(SUM(total_amount), 2)           AS revenue
FROM clean_orders
GROUP BY month
ORDER BY month;

-- 4.2 Топ-10 стран по выручке (без Великобритании, чтобы увидеть
--     международную картину отдельно от основного рынка)
SELECT
    country,
    COUNT(DISTINCT invoice_no) AS orders,
    ROUND(SUM(total_amount), 2) AS revenue
FROM clean_orders
WHERE country != 'United Kingdom'
GROUP BY country
ORDER BY revenue DESC
LIMIT 10;

-- 4.3 Топ-10 товаров по выручке
SELECT
    stock_code,
    description,
    SUM(quantity) AS total_quantity,
    ROUND(SUM(total_amount), 2) AS revenue
FROM clean_orders
GROUP BY stock_code, description
ORDER BY revenue DESC
LIMIT 10;


-- =====================================================================
-- РАЗДЕЛ 5. RFM-АНАЛИЗ КЛИЕНТОВ (CRM Analytics)
-- =====================================================================
-- R (Recency)   - сколько дней назад была последняя покупка
-- F (Frequency) - сколько раз клиент покупал (число уникальных заказов)
-- M (Monetary)  - сколько денег всего потратил

-- 5.1 Базовая таблица RFM-метрик для всех клиентов
DROP TABLE IF EXISTS rfm_base;

CREATE TABLE rfm_base AS
WITH customer_metrics AS (
    SELECT
        customer_id,
        MAX(invoice_date_ts) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(total_amount), 2) AS monetary
    FROM clean_orders
    GROUP BY customer_id
),
reference_date AS (
    SELECT MAX(invoice_date_ts) AS max_date FROM clean_orders
)
SELECT
    cm.customer_id,
    (rd.max_date::date - cm.last_purchase::date) AS recency_days,
    cm.frequency,
    cm.monetary
FROM customer_metrics cm, reference_date rd;

-- Проверка: сколько всего уникальных клиентов
SELECT COUNT(*) FROM rfm_base;
-- Результат: 4 338 клиентов

-- 5.2 Топ-20 клиентов по сумме трат (для ручной проверки логики)
SELECT *
FROM rfm_base
ORDER BY monetary DESC
LIMIT 20;

-- 5.3 Сегментация клиентов: VIP / Loyal / New / At Risk / Lost / Regular
DROP TABLE IF EXISTS rfm_segments;

CREATE TABLE rfm_segments AS
SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    CASE
        WHEN recency_days <= 30 AND frequency >= 10 AND monetary >= 1000 THEN 'VIP'
        WHEN recency_days <= 90 AND frequency >= 5 THEN 'Loyal'
        WHEN recency_days <= 30 AND frequency < 5 THEN 'New'
        WHEN recency_days BETWEEN 91 AND 180 THEN 'At Risk'
        WHEN recency_days > 180 THEN 'Lost'
        ELSE 'Regular'
    END AS segment
FROM rfm_base;

-- 5.4 Сводка по сегментам: сколько клиентов и сколько денег приносят
SELECT
    segment,
    COUNT(*) AS customers,
    ROUND(AVG(monetary), 2) AS avg_spent,
    ROUND(SUM(monetary), 2) AS total_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;


-- =====================================================================
-- РАЗДЕЛ 6. ПОДГОТОВКА К ЭКСПОРТУ (для Python и Power BI)
-- =====================================================================

-- VIEW нельзя экспортировать напрямую через интерфейс pgAdmin,
-- поэтому превращаем его в обычную таблицу-копию
DROP TABLE IF EXISTS clean_orders_export;

CREATE TABLE clean_orders_export AS 
SELECT * FROM clean_orders;

-- Далее обе таблицы (clean_orders_export, rfm_segments) экспортированы
-- в CSV через: правый клик на таблице -> Import/Export Data -> Экспорт
-- Файлы: clean_orders.csv, rfm_segments.csv
