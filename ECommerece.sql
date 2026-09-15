CREATE TABLE customers (
    customer_id     BIGSERIAL PRIMARY KEY,
    full_name       TEXT NOT NULL,
    email           TEXT UNIQUE NOT NULL,
    region          TEXT NOT NULL,
    metadata        JSONB DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE categories (
    category_id     BIGSERIAL PRIMARY KEY,
    parent_id       BIGINT REFERENCES categories(category_id),
    name            TEXT NOT NULL
);

CREATE TABLE products (
    product_id      BIGSERIAL PRIMARY KEY,
    category_id     BIGINT NOT NULL REFERENCES categories(category_id),
    name            TEXT NOT NULL,
    unit_price      NUMERIC(12,2) NOT NULL CHECK (unit_price >= 0),
    attributes      JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE orders (
    order_id        BIGSERIAL,
    customer_id     BIGINT NOT NULL REFERENCES customers(customer_id),
    order_date      TIMESTAMPTZ NOT NULL DEFAULT now(),
    status          TEXT NOT NULL DEFAULT 'pending',
    PRIMARY KEY (order_id, order_date)
) PARTITION BY RANGE (order_date);

CREATE TABLE orders_2026_01 PARTITION OF orders
    FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE orders_2026_02 PARTITION OF orders
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE orders_default PARTITION OF orders DEFAULT;

CREATE TABLE order_items (
    order_item_id   BIGSERIAL PRIMARY KEY,
    order_id        BIGINT NOT NULL,
    order_date      TIMESTAMPTZ NOT NULL,
    product_id      BIGINT NOT NULL REFERENCES products(product_id),
    quantity        INT NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12,2) NOT NULL,
    FOREIGN KEY (order_id, order_date) REFERENCES orders(order_id, order_date)
);

CREATE TABLE order_audit_log (
    audit_id        BIGSERIAL PRIMARY KEY,
    order_id        BIGINT NOT NULL,
    old_status      TEXT,
    new_status      TEXT,
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_customers_metadata ON customers USING GIN (metadata);
CREATE INDEX idx_products_attributes ON products USING GIN (attributes);
CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_order_items_product ON order_items (product_id);

CREATE OR REPLACE FUNCTION log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
        INSERT INTO order_audit_log (order_id, old_status, new_status)
        VALUES (NEW.order_id, OLD.status, NEW.status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_status_change
AFTER UPDATE ON orders
FOR EACH ROW
EXECUTE FUNCTION log_order_status_change();

CREATE OR REPLACE FUNCTION place_order(
    p_customer_id BIGINT,
    p_items JSONB
) RETURNS BIGINT AS $$
DECLARE
    v_order_id BIGINT;
    v_order_date TIMESTAMPTZ := now();
    v_item JSONB;
BEGIN
    INSERT INTO orders (customer_id, order_date, status)
    VALUES (p_customer_id, v_order_date, 'confirmed')
    RETURNING order_id INTO v_order_id;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
    LOOP
        INSERT INTO order_items (order_id, order_date, product_id, quantity, unit_price)
        SELECT v_order_id,
               v_order_date,
               (v_item->>'product_id')::BIGINT,
               (v_item->>'quantity')::INT,
               p.unit_price
        FROM products p
        WHERE p.product_id = (v_item->>'product_id')::BIGINT;
    END LOOP;

    RETURN v_order_id;
END;
$$ LANGUAGE plpgsql;

WITH RECURSIVE category_tree AS (
    SELECT category_id, parent_id, name, name::TEXT AS path, 0 AS depth
    FROM categories
    WHERE parent_id IS NULL

    UNION ALL

    SELECT c.category_id, c.parent_id, c.name,
           ct.path || ' > ' || c.name,
           ct.depth + 1
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.category_id
)
SELECT * FROM category_tree ORDER BY path;

SELECT
    c.customer_id,
    c.full_name,
    o.order_id,
    o.order_date,
    SUM(oi.quantity * oi.unit_price) AS order_total,
    SUM(SUM(oi.quantity * oi.unit_price)) OVER (
        PARTITION BY c.customer_id
        ORDER BY o.order_date
    ) AS running_customer_total,
    RANK() OVER (
        PARTITION BY date_trunc('month', o.order_date)
        ORDER BY SUM(oi.quantity * oi.unit_price) DESC
    ) AS rank_in_month,
    LAG(o.order_date) OVER (
        PARTITION BY c.customer_id
        ORDER BY o.order_date
    ) AS previous_order_date
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id AND oi.order_date = o.order_date
GROUP BY c.customer_id, c.full_name, o.order_id, o.order_date
ORDER BY c.customer_id, o.order_date;

CREATE MATERIALIZED VIEW monthly_category_sales AS
SELECT
    date_trunc('month', o.order_date) AS month,
    cat.name AS category_name,
    SUM(oi.quantity * oi.unit_price) AS total_sales,
    COUNT(DISTINCT o.order_id) AS order_count,
    COUNT(DISTINCT o.customer_id) AS unique_customers
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id AND oi.order_date = o.order_date
JOIN products p ON p.product_id = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
GROUP BY 1, 2
WITH DATA;

CREATE UNIQUE INDEX idx_monthly_category_sales
ON monthly_category_sales (month, category_name);

SELECT
    customer_id,
    full_name,
    (metadata->>'segment') AS segment
FROM customers
WHERE metadata @> '{"vip": true}'::jsonb;
