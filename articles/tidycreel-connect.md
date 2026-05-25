# tidycreel.connect: Companion Package for Database Integration

## What is tidycreel.connect?

**tidycreel.connect** is a companion package that bridges tidycreel with
relational and embedded database back-ends. It targets agencies and
research groups that collect creel survey data through field
applications or custom data entry systems and need a reproducible,
validated path to get that data into a form that tidycreel can analyse.

The package focuses on three layers of the data pipeline that tidycreel
itself deliberately leaves out of scope:

1.  **Connection management** — opening validated connections to
    DBI-backed databases (SQL Server, DuckDB, SQLite), CSV file
    collections, or REST API endpoints with a consistent interface.
2.  **Schema-aware data loading** — reading counts, interviews, catch,
    and length records from the connected source, renaming raw fields to
    canonical tidycreel column names, and coercing types at import time.
3.  **Survey discovery** — listing and searching available creel surveys
    on API-backed connections before pulling data.

## Installation

tidycreel.connect is available from GitHub:

``` r

# Using remotes
remotes::install_github("chrischizinski/tidycreel.connect")

# Or using pak
pak::pak("chrischizinski/tidycreel.connect")
```

## How tidycreel.connect relates to tidycreel

tidycreel handles **design, estimation, and reporting**: building a
`creel_design` object, running effort and catch estimators, producing
publication-ready plots and tables.

tidycreel.connect handles the **data-ingestion and storage layer** that
feeds it: connecting to a field database or API, loading validated data
frames, and handing them off to tidycreel estimation functions.

The two packages are designed to work together but can be used
independently:

- You can use tidycreel with data that lives in plain CSV files or an
  in-memory data frame — tidycreel.connect is not required.
- You can use tidycreel.connect to manage and query your field database
  without calling any tidycreel estimation functions.

A typical integrated workflow looks like this:

``` r

library(tidycreel)
library(tidycreel.connect)

# 1. Connect to a DBI-backed database (SQL Server, DuckDB, SQLite)
con <- creel_connect(dbi_connection, schema = "creel")

# -- or connect using a YAML configuration file --
con <- creel_connect_from_yaml("config/creel.yml")

# 2. Discover available surveys (API connections only)
list_creels(con)
search_creels(con, keyword = "2025")

# 3. Load validated data and hand off to tidycreel
counts     <- fetch_counts(con)
interviews <- fetch_interviews(con)

design <- creel_design(counts = counts, ...) |>
  add_interviews(interviews)

estimate_effort(design)
```

## Exported functions

### Connection management

- `creel_connect(con, schema)` — opens a `creel_connection` object
  backed by a DBI connection (SQL Server, DuckDB, SQLite) or a named
  list of CSV file paths.
- `creel_connect_api(...)` — opens a `creel_connection` to a REST API
  endpoint.
- `creel_connect_from_yaml(path, config = "default")` — convenience
  wrapper that reads connection parameters from a YAML file; supports
  environment variable injection for credentials.
- `creel_check_driver(con)` — validates that the underlying DBI driver
  is supported; useful for pre-flight checks in automated pipelines.

### Data loading

These functions use S3 dispatch so they work identically across DBI,
CSV, and API back-ends. Each renames raw fields to canonical tidycreel
column names and coerces data types at import time.

- `fetch_counts(conn, ...)` — loads survey count records (bank anglers,
  angler boats, non-angler boats) into a data frame ready for
  [`creel_design()`](https://chrischizinski.github.io/tidycreel/reference/creel_design.md).
- `fetch_interviews(conn, ...)` — loads interview records including IDs,
  dates, catch counts, effort, and trip status.
- `fetch_catch(conn, ...)` — loads catch detail records associated with
  interviews; species codes are coerced to character.
- `fetch_harvest_lengths(conn, ...)` — loads fish length measurements
  for harvested fish, injecting `length_type = "harvest"`.
- `fetch_release_lengths(conn, ...)` — loads fish length measurements
  for released fish, injecting `length_type = "release"`.

### Survey discovery (API connections only)

- `list_creels(conn, ...)` — returns a data frame of all available
  surveys on the connected API, with UIDs, titles, descriptions, and
  active status.
- `search_creels(conn, keyword, ...)` — client-side filter of
  `list_creels()` output; matches keyword (case-insensitive) against
  title and description fields.

## CSV back-end

tidycreel.connect also supports a pure-CSV workflow for users who store
survey data as flat files rather than in a database. Pass a named list
of file paths to `creel_connect()`:

``` r

con <- creel_connect(
  list(
    counts     = "data/counts.csv",
    interviews = "data/interviews.csv",
    catch      = "data/catch.csv"
  )
)

counts     <- fetch_counts(con)
interviews <- fetch_interviews(con)
```

## More information

- Source and documentation: `chrischizinski/tidycreel.connect` on GitHub
- Main package: <https://github.com/chrischizinski/tidycreel>
- Bug reports and feature requests: open an issue on the
  tidycreel.connect repository.
