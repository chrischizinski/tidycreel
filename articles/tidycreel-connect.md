# tidycreel.connect: Companion Package for Database Integration

## What is tidycreel.connect?

**tidycreel.connect** is a companion package that bridges tidycreel with
relational and embedded database back-ends. It targets agencies and
research groups that collect creel survey data through field
applications or custom data entry systems and need a reproducible,
validated path to get that data into a form that tidycreel can analyse.

The package focuses on three layers of the data pipeline that tidycreel
itself deliberately leaves out of scope:

1.  **Schema validation** — confirming that tables arriving from the
    field meet the structural requirements that tidycreel functions
    assume (column names, data types, allowed factor levels).
2.  **Database I/O** — reading from and writing to DuckDB, SQLite, or
    PostgreSQL using a consistent DBI-based interface, without requiring
    users to write raw SQL.
3.  **Batch import** — ingesting exports from common field data
    collection formats (CSV bundles, spreadsheet workbooks) and loading
    them into a persistent database in a single reproducible step.

## How tidycreel.connect relates to tidycreel

tidycreel handles **design, estimation, and reporting**: building a
`creel_design` object, running effort and catch estimators, producing
publication-ready plots and tables.

tidycreel.connect handles the **data-ingestion and storage layer** that
feeds it: validating incoming field data, persisting it in a structured
database, and exposing it to tidycreel through a clean read interface.

The two packages are designed to work together but can be used
independently:

- You can use tidycreel with data that lives in plain CSV files or an
  in-memory data frame — tidycreel.connect is not required.
- You can use tidycreel.connect to manage and validate your field
  database without calling any tidycreel estimation functions.

A typical integrated workflow would look like this:

``` r

library(tidycreel)
library(tidycreel.connect)   # not yet on CRAN

# 1. Connect to a local DuckDB database
con <- tc_connect("survey_data.duckdb")

# 2. Batch-import a season's worth of field exports
tc_import_batch(con, path = "exports/2025/", season = "2025")

# 3. Validate the imported data against the tidycreel schema
tc_validate(con, season = "2025")

# 4. Load validated data and hand off to tidycreel
counts      <- tc_read_counts(con, season = "2025")
interviews  <- tc_read_interviews(con, season = "2025")

design <- creel_design(counts = counts, ...) |>
  add_interviews(interviews)

estimate_effort(design)
```

## What tidycreel.connect will provide

When released, tidycreel.connect is planned to include:

**Schema validation**

- `tc_validate()` — checks that tables in a connected database conform
  to the tidycreel schema; returns a structured validation report
  compatible with `print.creel_data_validation`.
- `tc_check_columns()` — column-level checks for required names, types,
  and allowed values.

**DBI-based read/write helpers**

- `tc_connect()` — opens a DBI connection to DuckDB (default), SQLite,
  or PostgreSQL with sensible defaults for creel survey databases.
- `tc_read_counts()`, `tc_read_interviews()`, `tc_read_catch()` — read
  validated tables from the database into R data frames ready for
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).
- `tc_write_estimates()` — persist estimation results back to the
  database for longitudinal tracking.

**Batch import**

- `tc_import_batch()` — reads a directory of field exports (CSV, XLSX)
  and loads them into the database, applying schema checks at ingestion
  time.
- `tc_import_csv()`, `tc_import_xlsx()` — single-file variants for
  interactive use.

**Reproducible pipeline templates**

- Project templates (via `usethis`-style helpers) that set up a
  standardised directory structure and a minimal `targets` or `drake`
  pipeline connecting field data imports to tidycreel analyses.

## How to stay notified

tidycreel.connect is under development and not yet publicly available.
To stay informed:

- **Watch the tidycreel GitHub repository** at
  <https://github.com/chrischizinski/tidycreel> — announcements will be
  posted in the News / Releases section when the companion package
  reaches a public preview.
- **Watch the tidycreel.connect repository** (placeholder; not yet
  public) at <https://github.com/chrischizinski/tidycreel.connect> —
  star or watch the repository to receive notifications once it is made
  public.

If you have use-case requirements or schema feedback you would like
considered during development, please open an issue on the tidycreel
repository.
