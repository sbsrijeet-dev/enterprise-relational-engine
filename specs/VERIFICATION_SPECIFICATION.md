# Forensic Verification Specification & Invariant Standards
**Enterprise Relational Normalization & Forensic SQL Engine**  
*Deterministic Data Governance, Zero-Float Financial Ledgers & Schema Invariants*

---

> [!IMPORTANT]
> **PROPRIETARY ARCHITECTURE & INTELLECTUAL PROPERTY NOTICE**  
> The automated test execution engines (`verify_package.py`, `verify_excel.py`, and `verify_excel_sqlite.py`) and the offline Zero-Trust Cryptographic Airlock (`AES-256 / PBKDF2-HMAC-SHA256, 480k iterations`) are proprietary, closed-source engineering infrastructure. They are protected against unauthorized copying, reverse-engineering, and public distribution.  
> 
> This document formalizes the **mathematical invariants, structural constraints, and auditing rules** enforced across all relational architectures and case studies within this repository.

---

## 1. System Philosophy: Deterministic Verification

Standard data pipelines rely on optimistic transformations—assuming that if an ETL script finishes without throwing an unhandled exception, the underlying data must be correct. In enterprise environments, this assumption introduces silent data corruption: floating-point drift, unflagged orphaned records, altered line endings, uncalibrated currency conversions, and timezone boundary skews.

Our architecture enforces **Hostile Auditability**: every normalized database must survive an automated, multi-pass adversarial test battery. We assume the auditor has root-level SQLite access, re-parses raw inputs independently, checks line endings byte-for-byte, and actively searches for unflagged data mutations.

---

## 2. The 8 Forensic Invariant Test Suites

Every relational package must satisfy **143+ distinct deterministic assertions** distributed across 8 core test suites:

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      THE 8 FORENSIC INVARIANT SUITES                            │
├───────────────────┬─────────────────────────────────────────────────────────────┤
│ Suite 1           │ PRAGMA Health & Relational Integrity (WAL, FKs, Indexes)     │
│ Suite 2           │ Double-Entry Ledger, Integer Minor Units & Currency Parity   │
│ Suite 3           │ Referential Integrity & Zero Orphans (Parent-Child DAG)     │
│ Suite 4           │ Artifact Alignment & CSV Export Parity (Row-for-Row)        │
│ Suite 5           │ File Format Standards (Strict Unix LF \n, UTF-8 Purity)      │
│ Suite 6           │ Domain, Format, Primary Key & Logic Invariants              │
│ Suite 7           │ Production Views & Financial Reporting Parity                │
│ Suite 8           │ In-Memory Blank Database Rebuild Stress Test (5x-10x Passes) │
└───────────────────┴─────────────────────────────────────────────────────────────┘
```

---

### Suite 1: PRAGMA Health & Relational Integrity
* **PRAGMA integrity_check:** The compiled `.sqlite` binary must return strictly `ok` with 0 page corruptions, 0 fragmented cells, and 0 B-Tree index misalignments.
* **PRAGMA quick_check:** Must return strictly `ok`.
* **PRAGMA foreign_key_check:** Must return `0 violations` with foreign keys enabled (`PRAGMA foreign_keys = ON`).
* **Performance B-Tree Index Roster:** Every foreign key and high-cardinality query column must have a corresponding explicit B-Tree index (`idx_<table_name>_<column_name>`), achieving $<5\text{ms}$ execution times on multi-table joins.
* **Journal Mode:** Databases must run under Write-Ahead Logging (`PRAGMA journal_mode = WAL;`) with normal synchronous flushing (`PRAGMA synchronous = NORMAL;`).

---

### Suite 2: Double-Entry Ledger & Multi-Currency Parity
* **Global Imbalance Invariant:** The global net imbalance across all double-entry ledger entries must evaluate to exactly:
  $$\sum \text{Debits} - \sum \text{Credits} = \$0.0000 \quad (\text{0 cents})$$
* **Native Currency Imbalance Invariant:** For every operating currency (e.g., USD, EUR, GBP, AUD, CAD, JPY), the currency-specific net imbalance must evaluate to strictly **`0`** native units.
* **Integer Minor Units:** All financial values must be stored as signed 64-bit integers (`INTEGER`) representing minor units (cents, pence, or whole yen). Floating-point datatypes (`REAL`, `FLOAT`, `DOUBLE`) are strictly forbidden in transaction ledgers to eliminate IEEE 754 rounding drift.
* **Zero-Decimal Currency Handling:** Currencies without minor units (such as Japanese Yen `JPY`) must be stored as exact whole integers without fractional division corruption.

---

### Suite 3: Referential Integrity & Zero Orphans
* **DAG Hierarchical Decoupling:** Relational schemas must form a strict Directed Acyclic Graph (DAG) with zero circular foreign key dependencies.
* **Zero Orphaned Records:** Every foreign key reference across all child tables must resolve to an existing, valid primary key in the parent entity.
* **Dispute & Dispute Item 1:1 Mapping:** Transaction dispute records must reconcile 1:1 with corresponding transactional events.

---

### Suite 4: Artifact Alignment & CSV Export Parity
* **Row-for-Row Conservation:** For every table in the relational database, the corresponding standalone CSV export must match the database row count exactly:
  $$\text{COUNT}(*)_{\text{SQLite}} == \text{COUNT}(*)_{\text{CSV}}$$
* **Header Concordance:** Column names in exported CSVs must align identically in name, order, and casing with the SQLite table schema.

---

### Suite 5: File Format Standards & Byte-Level Purity
* **Strict Unix Line Endings (LF `\n`):** Every `.sql` distribution dump and every exported `.csv` file is individually byte-scanned. The presence of a single Windows carriage return (`\r` / `0x0D`) causes immediate failure:
  $$\text{Carriage Returns } (\backslash\text{r}) == 0$$
* **UTF-8 Encoding:** All artifacts must conform strictly to UTF-8 without byte-order marks (BOM `0xEF 0xBB 0xBF`).

---

### Suite 6: Domain, Format, Primary Key & Logic Invariants
* **Primary Key Non-Null & Uniqueness:** Every primary key column must contain strictly unique values and `0` NULLs.
* **Law of Row Conservation:** Raw input rows must reconcile with clean output rows through documented lineage, accounting for explicit deduplication and quarantine filtering.
* **UTC Timestamp Canon:** All datetime fields must be stored as canonical ISO-8601 strings (`YYYY-MM-DD HH:MM:SS`) in Coordinated Universal Time (UTC). All local offsets (e.g., UTC+05:30) and Excel serial epochs must be converted deterministically.
* **Anti-Money Laundering (AML) Quarantine:** In financial datasets, transactions falling into structuring bands (e.g., $\$9,900.00$ to $\$9,999.99$ USD) designed to evade $\$10,000$ BSA Currency Transaction Reporting must be systematically flagged and quarantined:
  $$\text{Quarantine Rate } = 100.00\% \quad (\text{is\_flagged\_aml} = 1)$$
* **Ternary Logic Safety:** Categorical status columns must contain zero `NULL` values; default or sentinel statuses must be explicitly populated.
* **Sentinel Value Sanitization:** Legacy dummy values (`-999`, `999999999`) must be scrubbed or assigned explicit data quality flags.

---

### Suite 7: Production Views & Financial Reporting Parity
* **Analytical View Completeness:** Pre-computed production views (General Ledger, Annual Conglomerate Performance, Division Health, Currency Exposure) must execute without warnings.
* **Trial Balance Parity:** Analytical trial balance views must confirm exact mathematical equality between debits and credits.

---

### Suite 8: In-Memory Blank Database Rebuild Stress Test
* **Deterministic Rebuild:** The master `.sql` distribution script must be executed against a completely blank in-memory SQLite database (`:memory:`):
  1. Recreate all 11+ tables, constraints, and indexes from zero.
  2. Ingest all seed records and views.
  3. Execute across **10 consecutive iterations** with zero warnings and zero foreign key failures.

---

## 3. The Offline Zero-Trust Privacy Airlock Specification

When processing sensitive data (clinical health records, personal payment ledgers, proprietary enterprise logs), our architecture mandates an **Offline Zero-Trust Airlock**:

```text
[ Raw Input Data ]
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│             OFFLINE ZERO-TRUST PRIVACY AIRLOCK              │
│  • AES-256-GCM / PBKDF2-HMAC-SHA256 (480,000 Iterations)   │
│  • Deterministic 1:1 PII Pseudonymization                   │
│  • Zero External Network Access / Physical Code Air-Gap     │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
[ Tokenized / Masked Datasets ] ──> [ 3NF Normalization Engine ]
        │
        ▼
[ Clean Relational Database ]
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│               LOCAL SECURE UNMASKING ENGINE                 │
│  • Re-links Real Identifiers Locally on Target Hardware     │
│  • Ephemeral Memory Execution (Zero Residual Disk Tokens)   │
└─────────────────────────────────────────────────────────────┘
        │
        ▼
[ Final Certified Delivery ]
```

* **Cryptographic Strength:** Storage containers utilize AES-256 with key derivation via PBKDF2-HMAC-SHA256 across 480,000 rounds. A 57-character key space ($94^{57} \approx 2.94 \times 10^{112}$ combinations) renders brute-force attacks mathematically impossible.
* **Deterministic Join Preservation:** PII tokens (names, email addresses, tax identifiers) are pseudorandomly substituted with consistent surrogate tokens (e.g., `cust_00042@maskeddomain.local`), preserving 100% of foreign key joinability and deduplication logic while ensuring zero personal data ever leaves the local machine.
