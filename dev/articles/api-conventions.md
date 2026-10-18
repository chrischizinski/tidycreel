# API Conventions

This page is the contract for how tidycreel’s functions are named, what
they take and what they return. It is written for two readers: users,
who should be able to guess a function’s name and arguments from its
job, and contributors, who add functions without making the first
reader’s guess wrong.

A rule here that a test can check is checked, by
`tests/testthat/test-api-conventions.R`. Where the package does not yet
meet a rule, the test carries the gap as a named exception with the
issue that tracks it, and fails if an exception is no longer needed. The
exception list can only shrink.

## The shape of an analysis

Every design-based analysis has the same shape:

``` r

design <- creel_design(calendar, date = date, strata = day_type) |>  # 1. structure
  add_counts(counts, count_col = n_anglers) |>                       # 2. data
  add_interviews(interviews, catch = catch_total, effort = hours,
                 trip_status = trip_status)

est <- estimate_effort(design, by = day_type)                        # 3. estimate
est |> tibble::as_tibble()                                           # 4. use (#476)
```

1.  [`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md)
    describes how the season was sampled. It is the only constructor;
    the survey type is an argument, not a different function.
2.  `add_*()` attaches one kind of observation and returns the design,
    so the steps pipe.
3.  `estimate_*()` turns the design into an estimate with a standard
    error and a confidence interval.
4.  The result prints, plots with `autoplot()`, and converts to a plain
    tibble.

New functions fit one of these steps or one of the families below. A
function that fits none is a sign it belongs in a different package, or
that the design of the feature needs discussing in an issue first.

## Function families

The prefix says what the function does. Within a family, the first
argument is the same kind of object.

| Prefix | Job | First argument | Returns |
|----|----|----|----|
| [`creel_design()`](https://chrischizinski.com/tidycreel/dev/reference/creel_design.md) | Construct a design | `calendar` | `creel_design` |
| `add_*()` | Attach observations to a design | `design` | `creel_design` |
| `prep_*()` | Reshape raw field data into what an `add_*()` takes | `data` | data frame |
| `estimate_*()` | Design-based estimate with uncertainty | `design` | `creel_estimates` |
| `summarize_*()` | Unexpanded description of the sample | `design` | data frame |
| `validate_*()`, `check_*()` | Check inputs; report problems | the thing checked | a report |
| `generate_*()` | Build a sampling schedule or count times | schedule inputs | schedule |
| `creel_n_*()` | Plan sample sizes before a season | planning numbers | numbers |
| `compare_*()` | Compare estimators, designs or variance methods | the things compared | a comparison |
| `simulate_*()` | Simulated data for planning and testing | simulation settings | data frame |
| `get_*()` | Read a component out of a design | `design` | data frame |
| `as_*()` | Convert a design to another package’s object | `design` | that object |
| `write_*()`, `read_*()` | Files | the object / the path | — |
| `autoplot()` | Plot a result | the result | ggplot |
| [`theme_creel()`](https://chrischizinski.com/tidycreel/dev/reference/theme_creel.md), [`creel_palette()`](https://chrischizinski.com/tidycreel/dev/reference/creel_palette.md) | Plot styling | style settings | a theme / colours |

Spelling: `summarize`, not `summarise`, in function names.

A few `estimate_*()` functions are calculators: they take summary
numbers
([`estimate_angler_n()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_angler_n.md),
[`estimate_exploitation_rate()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_exploitation_rate.md))
or another estimate
([`estimate_mr_harvest()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_mr_harvest.md),
[`estimate_angler_trips()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_angler_trips.md),
[`estimate_effort_per_acre()`](https://chrischizinski.com/tidycreel/dev/reference/estimate_effort_per_acre.md))
rather than a design. They are listed as exceptions in the test so that
a new calculator is a deliberate choice.

Known gaps. The first three are listed as exceptions in the test; the
last is a mismatch of meaning that a name check cannot see, and is
recorded here only:

- `est_*()` and `estimate_*()` coexist (#477).
- Planning functions use several patterns besides `creel_n_*()`:
  [`creel_power()`](https://chrischizinski.com/tidycreel/dev/reference/creel_power.md)
  and
  [`power_creel()`](https://chrischizinski.com/tidycreel/dev/reference/power_creel.md),
  [`optimal_n()`](https://chrischizinski.com/tidycreel/dev/reference/optimal_n.md),
  [`cv_from_n()`](https://chrischizinski.com/tidycreel/dev/reference/cv_from_n.md),
  [`reallocate_strata()`](https://chrischizinski.com/tidycreel/dev/reference/reallocate_strata.md).
- About twenty data-preparation, scheduling and diagnostic helpers sit
  outside any family
  ([`compute_effort()`](https://chrischizinski.com/tidycreel/dev/reference/compute_effort.md),
  [`standardize_species()`](https://chrischizinski.com/tidycreel/dev/reference/standardize_species.md),
  [`attach_count_times()`](https://chrischizinski.com/tidycreel/dev/reference/attach_count_times.md),
  [`audit_strata()`](https://chrischizinski.com/tidycreel/dev/reference/audit_strata.md),
  …). Each is listed in the test with its reason.
- [`validate_design()`](https://chrischizinski.com/tidycreel/dev/reference/validate_design.md)
  plans a sample size; it does not validate a `creel_design`.

## Arguments

**Order.** The object being worked on comes first (`design`, then the
data being attached), so every step pipes. Options come after the data.

**Shared argument names.** These mean the same thing everywhere they
appear, and appear in this relative order:

| Argument | Meaning |
|----|----|
| `by` | Grouping columns, as bare names (`by = c(day_type, species)`) |
| `variance` | `"taylor"`, `"bootstrap"` or `"jackknife"` |
| `conf_level` | Confidence level, default `0.95` |
| `target` | What the estimate totals over (`"sampled_days"`, …) |

Do not add a synonym (`level`, `group`, `strata_var`) for one of these.

**Columns are bare names.** Arguments that name a column take it
unquoted (`date = date`, `count_col = n_anglers`) and are resolved with
tidyselect, which also accepts a string. Documentation and examples use
bare names.

Two spellings of column arguments exist today: a bare role name
(`creel_design(date = )`, `add_interviews(catch = , effort = )`) and a
`_col` suffix (`add_counts(count_col = )`,
`add_sections(section_col = )`). The rule for new arguments is open
(#479). Until it is settled, match the function you are extending.

**Column names are never assumed.** The package ships no organisation’s
field names. A column is named by the user through an argument or
[`creel_schema()`](https://chrischizinski.com/tidycreel/dev/reference/creel_schema.md),
inferred from the data’s structure where only one column can qualify (as
[`add_counts()`](https://chrischizinski.com/tidycreel/dev/reference/add_counts.md)
does when `count_col` is omitted and exactly one non-design numeric
column remains; with two or more it refuses rather than pick), or
created by the package. Examples name the column anyway, so the reader
sees which one is used.

## Results

**Estimates** are `creel_estimates` objects: a tibble of estimates plus
the metadata that says what the numbers mean (method, estimator,
variance method, confidence level, unit, standard-error components). The
metadata travels beside the table rather than in attributes on it,
because an ordinary `select()` or
[`filter()`](https://rdrr.io/r/stats/filter.html) drops attributes
without telling anyone.

Every result class must convert with `as_tibble()` and
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html), and the
conversion copies the metadata a reader needs into columns (#476). A
result that cannot leave the package as data is not finished.

**Units are derived, never declared.** A unit comes from the data’s own
definition (party-hours vs angler-hours, a period length, `h_open`).
When it cannot be derived it is `NA`, meaning unknown. There is no
default unit.

**`NA`, `NULL` and zero are different.** A standard-error component that
was not propagated is absent (`NULL`, or left out of `se_components`):
either it does not apply to the design, or the quantity was supplied
without its own standard error, so the reported `se` treats it as fixed.
One that applies but is unknown is `NA`, and makes `se` `NA`. Zero means
a known zero. Never report `0` for “not propagated”;
[`vignette("refusals-and-na")`](https://chrischizinski.com/tidycreel/dev/articles/refusals-and-na.md)
shows all three. The one exception is a bootstrap `se` that already
contains a part it cannot report separately: the aerial GLMM’s
visibility and angler-ratio parts are inside `se` there but not listed.

**Refuse rather than guess.** When the data cannot support an estimate
(unsampled strata, units that do not combine, a design the estimator
does not cover), stop with an error that says what is missing and how to
supply it. Do not drop records, impute, or fall back to a different
estimator silently.

## Messages

- Errors, warnings and messages use cli
  ([`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html),
  [`cli::cli_warn()`](https://cli.r-lib.org/reference/cli_abort.html),
  [`cli::cli_inform()`](https://cli.r-lib.org/reference/cli_abort.html)),
  with the argument or column named in `{.arg}` / `{.field}` markup.
- Errors a caller may want to catch carry a class from the
  `creel_error_*` family (`creel_error_invalid_input`,
  `creel_error_schema_validation`, …).
- Every warning carries a class, `creel_warning_<fact>`, and the parent
  `creel_warning`, so a caller can handle one warning for one call
  ([`?creel_warnings`](https://chrischizinski.com/tidycreel/dev/reference/creel_warnings.md)
  lists them). A fact raised in several places uses one class. A tier-3
  message carries `creel_message_<fact>` and the parent `creel_message`
  in the same way.
- A warning should be rare enough to read. Every warning has a tier
  ([`?creel_warnings`](https://chrischizinski.com/tidycreel/dev/reference/creel_warnings.md)).
  Information (tier 3) is not a warning: raise it with the internal
  `creel_inform()`, as a message with a `creel_message_<fact>` class,
  and it is recorded like a warning. A data-quality warning (tier 2)
  prints once per design: later repeats on the same design are recorded
  on the result, readable with
  [`get_warnings()`](https://chrischizinski.com/tidycreel/dev/reference/get_warnings.md),
  but not printed. A warning that the estimate may be wrong (tier 1)
  prints every time. Raise warnings with the internal `creel_warn()`,
  which records them and handles the repeats; do not use `.frequency`,
  which hid repeats on a different design for the rest of the session. A
  test fails if either rule is broken.
- Examples, vignettes and the README run without warnings, unless the
  page is demonstrating the warning. A documentation page that warns
  teaches readers to ignore warnings.

## Code style

- Base pipe `|>` (the package requires R \>= 4.1). Not `%>%`.
- tidyverse style: `snake_case` for functions, arguments and columns.
- Every export has roxygen documentation with a runnable example, and is
  listed in `_pkgdown.yml`.

## Adding a function: checklist

1.  Which step or family is it? Use that prefix and that first argument.
2.  Reuse the shared argument names and their order.
3.  Columns as bare names; no assumed column names.
4.  Return the family’s type. A new result class gets `as_tibble()`,
    [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html),
    [`print()`](https://rdrr.io/r/base/print.html) and
    [`format()`](https://rdrr.io/r/base/format.html) methods.
5.  Units derived; `NA`/`NULL`/zero kept distinct; refuse rather than
    guess.
6.  Example runs warning-free.
7.  `tests/testthat/test-api-conventions.R` passes without adding an
    exception. If it needs one, the PR says why and links an issue.
