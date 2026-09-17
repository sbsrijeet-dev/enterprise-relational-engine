-- ===============================================================================
-- VANGUARD GLOBAL HOLDINGS INC. — ENTERPRISE CONGLOMERATE RELATIONAL SCHEMA
-- 10-Year Multi-Divisional Financial Ledger Architecture (2016–2026)
-- Standard: 3NF Normalized, Double-Entry Integer Minor Units, Strict Foreign Key DAG
-- ===============================================================================

PRAGMA foreign_keys = ON;

CREATE TABLE accounts (
    account_id TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    account_type TEXT NOT NULL,
    currency_code TEXT NOT NULL,
    is_test INTEGER NOT NULL DEFAULT 0,
    created_at_utc TEXT NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES entities_customers(customer_id),
    FOREIGN KEY (currency_code) REFERENCES currencies(currency_code)
);

CREATE TABLE catalog_items (
    catalog_item_code TEXT PRIMARY KEY,
    division_code TEXT NOT NULL,
    item_name TEXT NOT NULL,
    unit_price_cents INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (division_code) REFERENCES divisions(division_code)
);

CREATE TABLE currencies (
    currency_code TEXT PRIMARY KEY,
    currency_name TEXT NOT NULL,
    symbol TEXT NOT NULL,
    minor_units INTEGER NOT NULL CHECK(minor_units IN (0, 2))
);

CREATE TABLE disputes_claims (
    dispute_id TEXT PRIMARY KEY,
    transaction_id TEXT NOT NULL UNIQUE,
    division_code TEXT NOT NULL,
    dispute_reason TEXT NOT NULL,
    dispute_status TEXT NOT NULL CHECK(dispute_status IN ('WON', 'LOST', 'UNDER_REVIEW')),
    disputed_amount_minor INTEGER NOT NULL,
    disputed_amount_usd_cents INTEGER NOT NULL,
    arbitration_fee_usd_cents INTEGER NOT NULL DEFAULT 1500,
    filed_at_utc TEXT NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    FOREIGN KEY (division_code) REFERENCES divisions(division_code)
);

CREATE TABLE divisions (
    division_code TEXT PRIMARY KEY,
    division_name TEXT NOT NULL,
    description TEXT NOT NULL
);

CREATE TABLE entities_customers (
    customer_id TEXT PRIMARY KEY,
    customer_name TEXT NOT NULL,
    customer_email TEXT NOT NULL,
    customer_phone TEXT,
    referred_by TEXT,
    tier TEXT NOT NULL DEFAULT 'Standard',
    created_at_utc TEXT NOT NULL,
    FOREIGN KEY (referred_by) REFERENCES entities_customers(customer_id)
);

CREATE TABLE exchange_rates (
    rate_date TEXT NOT NULL,
    currency_code TEXT NOT NULL,
    rate_to_usd REAL NOT NULL CHECK(rate_to_usd > 0),
    inverse_rate REAL NOT NULL CHECK(inverse_rate > 0),
    PRIMARY KEY (rate_date, currency_code),
    FOREIGN KEY (currency_code) REFERENCES currencies(currency_code)
);

CREATE TABLE ledger_entries (
    entry_id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    direction TEXT NOT NULL CHECK(direction IN ('DEBIT', 'CREDIT')),
    amount_minor INTEGER NOT NULL CHECK(amount_minor >= 0),
    amount_usd_cents INTEGER NOT NULL CHECK(amount_usd_cents >= 0),
    currency_code TEXT NOT NULL,
    entry_type TEXT NOT NULL,
    created_at_utc TEXT NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    FOREIGN KEY (currency_code) REFERENCES currencies(currency_code)
);

CREATE TABLE settlement_batches (
    batch_id TEXT PRIMARY KEY,
    batch_date TEXT NOT NULL,
    cleared_at_utc TEXT NOT NULL,
    total_settled_cents INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE transaction_items (
    item_id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id TEXT NOT NULL,
    catalog_item_code TEXT NOT NULL,
    quantity REAL NOT NULL DEFAULT 1.0,
    unit_price_minor INTEGER NOT NULL,
    total_price_minor INTEGER NOT NULL,
    total_price_usd_cents INTEGER NOT NULL,
    FOREIGN KEY (transaction_id) REFERENCES transactions(transaction_id),
    FOREIGN KEY (catalog_item_code) REFERENCES catalog_items(catalog_item_code)
);

CREATE TABLE transactions (
    transaction_id TEXT PRIMARY KEY,
    division_code TEXT NOT NULL,
    source_account_id TEXT NOT NULL,
    destination_account_id TEXT NOT NULL,
    currency_code TEXT NOT NULL,
    gross_amount_minor INTEGER NOT NULL CHECK(gross_amount_minor >= 0),
    fee_amount_minor INTEGER NOT NULL CHECK(fee_amount_minor >= 0),
    net_amount_minor INTEGER NOT NULL CHECK(net_amount_minor >= 0),
    gross_amount_usd_cents INTEGER NOT NULL CHECK(gross_amount_usd_cents >= 0),
    fee_amount_usd_cents INTEGER NOT NULL CHECK(fee_amount_usd_cents >= 0),
    net_amount_usd_cents INTEGER NOT NULL CHECK(net_amount_usd_cents >= 0),
    status TEXT NOT NULL DEFAULT 'COMPLETED',
    is_flagged_aml INTEGER NOT NULL DEFAULT 0 CHECK(is_flagged_aml IN (0, 1)),
    is_test INTEGER NOT NULL DEFAULT 0 CHECK(is_test IN (0, 1)),
    is_imputed INTEGER NOT NULL DEFAULT 0 CHECK(is_imputed IN (0, 1)),
    data_quality_flag TEXT NOT NULL DEFAULT 'CLEAN',
    settlement_batch_id TEXT NOT NULL,
    created_at_utc TEXT NOT NULL,
    updated_at_utc TEXT NOT NULL,
    FOREIGN KEY (division_code) REFERENCES divisions(division_code),
    FOREIGN KEY (source_account_id) REFERENCES accounts(account_id),
    FOREIGN KEY (destination_account_id) REFERENCES accounts(account_id),
    FOREIGN KEY (currency_code) REFERENCES currencies(currency_code),
    FOREIGN KEY (settlement_batch_id) REFERENCES settlement_batches(batch_id)
);

CREATE INDEX idx_fx_date_curr ON exchange_rates(rate_date, currency_code);

CREATE INDEX idx_le_acc ON ledger_entries(account_id);

CREATE INDEX idx_le_curr ON ledger_entries(currency_code);

CREATE INDEX idx_le_dir ON ledger_entries(direction);

CREATE INDEX idx_le_trans ON ledger_entries(transaction_id);

CREATE INDEX idx_ti_trans ON transaction_items(transaction_id);

CREATE INDEX idx_trans_batch ON transactions(settlement_batch_id);

CREATE INDEX idx_trans_created ON transactions(created_at_utc);

CREATE INDEX idx_trans_curr ON transactions(currency_code);

CREATE INDEX idx_trans_div ON transactions(division_code);

CREATE INDEX idx_trans_dq ON transactions(data_quality_flag);

CREATE INDEX idx_trans_imputed ON transactions(is_imputed);

CREATE INDEX idx_trans_status ON transactions(status);

CREATE VIEW v_annual_conglomerate_performance AS
SELECT 
    STRFTIME('%Y', created_at_utc) AS reporting_year,
    COUNT(CASE WHEN status = 'COMPLETED' THEN 1 END) AS completed_transactions_count,
    COUNT(CASE WHEN status = 'REFUNDED' THEN 1 END) AS refunded_transactions_count,
    COUNT(CASE WHEN status = 'DISPUTED' THEN 1 END) AS disputed_transactions_count,
    COUNT(CASE WHEN status IN ('COMPLETED', 'REFUNDED', 'DISPUTED') THEN 1 END) AS total_settled_transactions_count,
    ROUND(SUM(CASE WHEN status IN ('COMPLETED', 'REFUNDED', 'DISPUTED') THEN gross_amount_usd_cents ELSE 0 END) / 100.0, 2) AS gross_payment_volume_usd,
    ROUND(SUM(CASE WHEN status IN ('COMPLETED', 'REFUNDED', 'DISPUTED') THEN fee_amount_usd_cents ELSE 0 END) / 100.0, 2) AS platform_fee_revenue_usd,
    ROUND(SUM(CASE WHEN status = 'COMPLETED' THEN net_amount_usd_cents ELSE 0 END) / 100.0, 2) AS net_merchant_payouts_usd,
    ROUND(SUM(CASE WHEN status = 'REFUNDED' THEN gross_amount_usd_cents ELSE 0 END) / 100.0, 2) AS refunded_volume_usd,
    ROUND(SUM(CASE WHEN status = 'DISPUTED' THEN gross_amount_usd_cents ELSE 0 END) / 100.0, 2) AS disputed_volume_usd,
    ROUND(
        (CAST(SUM(CASE WHEN status IN ('COMPLETED', 'REFUNDED', 'DISPUTED') THEN fee_amount_usd_cents ELSE 0 END) AS REAL) / 
         NULLIF(SUM(CASE WHEN status IN ('COMPLETED', 'REFUNDED', 'DISPUTED') THEN gross_amount_usd_cents ELSE 0 END), 0)) * 100.0, 
        3
    ) AS blended_take_rate_pct
FROM transactions
WHERE is_test = 0
GROUP BY STRFTIME('%Y', created_at_utc)
ORDER BY reporting_year;

CREATE VIEW v_currency_volume_exposure AS
SELECT 
    c.currency_code,
    c.currency_name,
    c.symbol,
    c.minor_units,
    COUNT(t.transaction_id) AS transaction_count,
    ROUND(
        SUM(
            CASE 
                WHEN c.minor_units = 0 THEN t.gross_amount_minor 
                ELSE t.gross_amount_minor / 100.0 
            END
        ), 2
    ) AS total_volume_native,
    ROUND(SUM(t.gross_amount_usd_cents) / 100.0, 2) AS total_volume_usd_equiv,
    ROUND(SUM(t.fee_amount_usd_cents) / 100.0, 2) AS total_fees_usd_equiv,
    ROUND(
        (CAST(SUM(t.gross_amount_usd_cents) AS REAL) / 
         (SELECT SUM(gross_amount_usd_cents) FROM transactions WHERE is_test = 0 AND status IN ('COMPLETED', 'REFUNDED', 'DISPUTED'))) * 100.0,
        2
    ) AS volume_exposure_pct
FROM currencies c
LEFT JOIN transactions t ON c.currency_code = t.currency_code AND t.is_test = 0 AND t.status IN ('COMPLETED', 'REFUNDED', 'DISPUTED')
GROUP BY c.currency_code, c.currency_name, c.symbol, c.minor_units
ORDER BY total_volume_usd_equiv DESC;

CREATE VIEW v_division_financial_health AS
SELECT 
    d.division_code,
    d.division_name,
    COUNT(t.transaction_id) AS total_transactions,
    ROUND(SUM(CASE WHEN t.status IN ('COMPLETED', 'REFUNDED', 'DISPUTED') THEN t.gross_amount_usd_cents ELSE 0 END) / 100.0, 2) AS gross_volume_usd,
    ROUND(SUM(CASE WHEN t.status IN ('COMPLETED', 'REFUNDED', 'DISPUTED') THEN t.fee_amount_usd_cents ELSE 0 END) / 100.0, 2) AS fee_revenue_usd,
    ROUND(SUM(CASE WHEN t.status = 'COMPLETED' THEN t.net_amount_usd_cents ELSE 0 END) / 100.0, 2) AS net_settled_usd,
    COUNT(CASE WHEN t.status = 'DISPUTED' THEN 1 END) AS disputed_incident_count
FROM divisions d
LEFT JOIN transactions t ON d.division_code = t.division_code AND t.is_test = 0
GROUP BY d.division_code, d.division_name
ORDER BY gross_volume_usd DESC;

CREATE VIEW v_general_ledger_journal AS
SELECT 
    le.entry_id,
    le.created_at_utc,
    le.transaction_id,
    t.division_code,
    le.account_id,
    a.account_type,
    le.currency_code,
    le.direction,
    CASE 
        WHEN le.currency_code = 'JPY' THEN le.amount_minor 
        ELSE le.amount_minor / 100.0 
    END AS amount_native,
    ROUND(le.amount_usd_cents / 100.0, 2) AS amount_usd,
    le.entry_type
FROM ledger_entries le
JOIN transactions t ON le.transaction_id = t.transaction_id
JOIN accounts a ON le.account_id = a.account_id;

CREATE VIEW v_healthcare_claims_adjudication AS
SELECT 
    ci.catalog_item_code AS procedure_code,
    ci.item_name AS procedure_description,
    COUNT(ti.item_id) AS claim_lines_count,
    ROUND(SUM(ti.total_price_usd_cents) / 100.0, 2) AS total_billed_usd,
    ROUND(SUM(ti.total_price_usd_cents * 0.20) / 100.0, 2) AS patient_copay_coinsurance_usd,
    ROUND(SUM(ti.total_price_usd_cents * 0.80) / 100.0, 2) AS plan_paid_usd
FROM catalog_items ci
JOIN transaction_items ti ON ci.catalog_item_code = ti.catalog_item_code
JOIN transactions t ON ti.transaction_id = t.transaction_id
WHERE ci.division_code = 'HEALTHCARE' AND t.is_test = 0
GROUP BY ci.catalog_item_code, ci.item_name
ORDER BY total_billed_usd DESC;
