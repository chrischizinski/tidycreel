# Extract survey design object from a creel_design

This helper bridges tidycreel design objects to the survey package. It
returns the embedded
[`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html) or
[`survey::svrepdesign`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
object for downstream analysis.

## Usage

``` r
as_survey_design(design)
```

## Arguments

- design:

  A `creel_design` object (or subclass)

## Value

A [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
or
[`survey::svrepdesign`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
object

## Details

This function provides a clear, pipe-friendly way to access the
underlying survey design object created by tidycreel constructors. Use
this for analysis with survey or srvyr functions.

- For access-point, roving, and bus route designs, returns a
  [`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html).

- For replicate weights designs, returns a
  [`survey::svrepdesign`](https://rdrr.io/pkg/survey/man/svrepdesign.html).

- Raises an error if no embedded survey design is found.

## Examples

``` r
if (FALSE) { # \dontrun{
access_design <- design_access(
  interviews = utils::read.csv(system.file("extdata", "toy_interviews.csv",
    package = "tidycreel"
  )),
  calendar = utils::read.csv(system.file("extdata", "toy_calendar.csv",
    package = "tidycreel"
  ))
)
svy <- as_survey_design(access_design)
summary(svy)
} # }
```
