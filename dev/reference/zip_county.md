# Zip code to county and state lookup

One row per 2020 ZIP Code Tabulation Area (ZCTA) with the county and
state it is assigned to.
[`summarize_by_county()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_county.md)
uses it unless you pass your own `lookup`.

## Usage

``` r
zip_county
```

## Format

A data frame with 33,791 rows and 6 columns:

- zip:

  ZCTA code, 5-digit text with any leading zero (`"02134"`).

- county:

  County or county-equivalent name as the Census Bureau writes it
  (`"Lancaster County"`, `"Añasco Municipio"`), UTF-8.

- state:

  Two-letter USPS state or territory abbreviation.

- county_fips:

  5-digit county FIPS code.

- n_counties:

  Number of counties the ZCTA's area overlaps.

- land_share:

  Share of the ZCTA's land area in the assigned county, rounded to 3
  decimals; 1 when it lies in one county.

## Source

U.S. Census Bureau, 2020 ZCTA to County Relationship File
(`tab20_zcta520_county20_natl.txt`),
<https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/>.
Public domain. Built by `data-raw/zip_county.R` in the package source.

## Details

A ZCTA that crosses a county line (10,186 of 33,791) is assigned to the
county holding the largest share of its land area. Land area is not
where people live, so anglers from a split ZCTA may mostly live in
another county; `n_counties` and `land_share` show how split each ZCTA
is.

ZCTAs are the Census Bureau's areal approximation of USPS ZIP code
service areas, not the ZIP codes themselves. ZIPs used only for PO boxes
or a single organisation have no ZCTA and are not in this table.

## See also

[`summarize_by_county()`](https://chrischizinski.com/tidycreel/dev/reference/summarize_by_county.md)

## Examples

``` r
data(zip_county)
zip_county[zip_county$zip %in% c("55082", "68008"), ]
#>         zip            county state county_fips n_counties land_share
#> 18871 55082 Washington County    MN       27163          1          1
#> 23964 68008 Washington County    NE       31177          1          1

# How often the county is a land-area majority call
summary(zip_county$land_share[zip_county$n_counties > 1])
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#>  0.3010  0.6660  0.8290  0.7965  0.9460  1.0000 
```
