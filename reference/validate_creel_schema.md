# Validate a creel_schema object

Checks that all columns required for the schema's `survey_type` are
mapped (non-NULL). Aborts with an informative `cli_abort()` listing each
missing column and its table.

## Usage

``` r
validate_creel_schema(schema)
```

## Arguments

- schema:

  A `creel_schema` object created by
  [`creel_schema()`](https://chrischizinski.github.io/tidycreel/reference/creel_schema.md).

## Value

`invisible(schema)` if all required columns are mapped.
