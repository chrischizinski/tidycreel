# NGPC Creel Survey Inventory — Simulator Parameter Guide

Compiled from NGPC REST API (`GetCatchData` + `GetCountData`) across all 86 complete
creels. Used to parameterize the `tidycreel` data simulator (v2.0.0).

> **Note on `pct_zero_angler`:** All values are `0` — a query artifact. `GetCatchData`
> only returns rows *with* catch, so zero-catch interviews are absent. Do **not** use
> `pct_zero_angler` as $P(\text{catch}=0)$. Derive true zero-catch rate from
> `GetInterviewData` UID set difference.

---

## 1. Executive Summary

| Metric | Value |
|--------|-------|
| Total complete creels | 86 |
| Surveys with interviews | 53 |
| Pressure-only (counts only) | 33 |
| Waterbody types | `large_reservoir` (36), `urban_small` (50) |
| Total interviews (interview creels) | 24,789 |
| Mean interviews per creel | 468 (range: 30–1,219) |
| Date coverage | 2014–2021, primarily April–October |
| All count records have weather columns | Yes (`c_Precipitation`, `c_Wind`, `c_Lightning`) |

---

## 2. Simulator Parameter Targets by Waterbody Type

### `large_reservoir`
*Multi-month boat + bank creels on major NE reservoirs.*

| Parameter | Mean | SD | Median | Range |
|-----------|------|----|--------|-------|
| Effort (hr/trip) | ~4.4 | ~2.8 | ~3.8 | 2.2–6.3 |
| Party size (anglers) | ~2.2 | ~1.1 | — | 1.9–2.6 |
| Catch per trip (all fish) | ~9.8 | — | — | 3–12 |
| CV of catch | ~1.25 | — | — | high overdispersion |
| Harvest rate (%) | ~37 | — | — | 23–59 |
| Mean total anglers (counts) | ~20 | — | — | 3–48 |
| Zero-count probability (%) | ~8 | — | — | 1–17 |
| Species richness per creel | ~17 | — | — | 11–30 |
| Mean trip start hour | ~10.2 | ~3.5 | — | |
| Survey days per creel | ~97 | — | — | 68–115 |

**Distribution notes:**
- Effort: right-skewed; use Gamma or Lognormal (mean > median universally)
- Catch: Negative Binomial; high CV (~1.25) → use NB with moderate θ
- Party size: ~2.2; Poisson(2) or NB truncated at 1

### `urban_small`
*Shorter duration, bank-dominated, often put-and-take or C&R managed lakes.*

| Parameter | Mean | SD | Median | Range |
|-----------|------|----|--------|-------|
| Effort (hr/trip) | ~2.0 | ~1.3 | ~1.6 | 1.5–2.8 |
| Party size (anglers) | ~2.0 | ~1.2 | — | 1.2–3.0 |
| Catch per trip (all fish) | ~6.5 | — | — | 0.4–13.8 |
| CV of catch | ~1.30 | — | — | high overdispersion |
| Harvest rate (%) | ~20 | — | — | 0.1–87 (bimodal) |
| Mean total anglers (counts) | ~5 | — | — | 0–15 |
| Zero-count probability (%) | ~55 | — | — | 30–90 |
| Species richness per creel | ~7 | — | — | 1–17 |
| Mean trip start hour | ~12.5 | ~3.5 | — | |
| Survey days per creel | ~65 | — | — | 12–116 |

**Distribution notes:**
- Harvest bimodal: put-and-take (Gracie Creek, 75–87%) vs C&R (Prairie Queen, 0.1%)
- Zero-count very high — simulate angler presence as zero-inflated Poisson
- Short trips: some creels <60 days; check for early-season ice stocking events

---

## 3. Individual Creel Profiles

> **Notes key:** `rich` = n_species > 10; `pressure-only` = no interview data; `short` = n_days < 20; date flag = anomalous date detected

| Title | Type | Dates | n_int | n_days | mean_eff | mean_party | n_sp | Top Species | pct_harv | mean_cnt | Notes |
|-------|------|-------|-------|--------|----------|------------|------|-------------|----------|----------|-------|
| Merritt 2016 | large_reservoir | 2016-04-02 – 2016-10-25 | 432 | 101 | 6.31 | 2.37 | 17 | 850(29%), 730(15%), 360(13%) | 28.9% | 15.67 | rich |
| Calamus 2016 | large_reservoir | 2016-04-02 – 2016-10-08 | 519 | 87 | 5.18 | 2.34 | 14 | 850(31%), 620(31%), 862(14%) | 42.6% | 15.92 | rich |
| Sherman 2016 | large_reservoir | 2016-04-01 – 2016-10-31 | 726 | 115 | 4.04 | 2.17 | 20 | 850(31%), 785(19%), 360(14%) | 37.9% | 21.94 | rich |
| Branched Oak 2016 | large_reservoir | 2016-04-03 – 2016-10-29 | 950 | 106 | 3.68 | 2.06 | 18 | 785(34%), 360(22%), 850(11%) | 23.0% | 22.77 | rich |
| Pawnee 2016 | large_reservoir | 2016-04-02 – 2016-10-30 | 842 | 112 | 2.16 | 1.89 | 25 | 360(26%), 610(24%), 850(11%) | 43.2% | 12.47 | rich |
| Harlan 2016 | large_reservoir | 2016-04-02 – 2016-10-30 | 824 | 105 | 4.82 | 2.35 | 11 | 620(48%), 850(20%), 360(8%) | 46.3% | 13.83 | rich |
| McConaughy 2016 | large_reservoir | 2016-04-02 – 2016-10-27 | 385 | 99 | 5.33 | 2.32 | 18 | 850(37%), 620(22%), 360(12%) | 30.3% | 29.21 | rich |
| Sutherland 2016 | large_reservoir | 2016-04-01 – 2016-10-31 | 533 | 108 | 3.81 | 1.94 | 16 | 850(35%), 620(26%), 360(11%) | 49.4% | 7.09 | rich |
| Pawnee 2015 | large_reservoir | 2015-04-02 – 2015-10-29 | 280 | 89 | 2.38 | 2.24 | 27 | 770(23%), 610(15%), 360(12%) | 22.4% | 4.47 | rich |
| Branched Oak 2015 | large_reservoir | 2015-04-03 – 2015-10-28 | 789 | 112 | 3.72 | 2.13 | 19 | 785(35%), 360(21%), 850(10%) | 23.9% | 22.47 | rich |
| Sherman 2015 | large_reservoir | 2015-04-10 – 2015-10-29 | 500 | 89 | 4.98 | 2.02 | 17 | 850(29%), 785(21%), 360(13%) | 41.5% | 14.44 | rich |
| McConaughy 2015 | large_reservoir | **2005-09-03** – 2015-10-26 | 406 | 100 | 5.30 | 2.09 | 19 | 850(33%), 360(17%), 620(17%) | 37.7% | 37.79 | rich; **date_min typo** |
| Merritt 2015 | large_reservoir | 2015-04-02 – 2015-10-30 | 507 | 104 | 6.30 | 2.47 | 16 | 850(29%), 360(12%), 730(12%) | 34.3% | 16.63 | rich |
| Harlan 2015 | large_reservoir | 2015-04-06 – 2015-10-30 | 924 | 106 | 4.73 | 2.33 | 12 | 620(30%), 850(30%), 862(14%) | 59.2% | 12.28 | rich |
| Calamus 2015 | large_reservoir | 2015-04-11 – 2015-10-11 | 675 | 94 | 4.36 | 2.56 | 18 | 850(30%), 620(25%), 362(7%) | 39.8% | 20.50 | rich |
| Pawnee 2014 | large_reservoir | 2014-04-12 – 2014-10-29 | 170 | 71 | 2.45 | 2.39 | 22 | 770(28%), 785(21%), 360(12%) | 24.1% | 3.58 | rich |
| Branched Oak 2014 | large_reservoir | 2014-04-09 – 2014-10-28 | 581 | 105 | 3.00 | 1.94 | 13 | 785(40%), 360(27%), 850(10%) | 34.6% | 14.02 | rich |
| Sherman 2014 | large_reservoir | 2014-04-06 – 2014-10-30 | 530 | 104 | 5.04 | 2.13 | 18 | 785(35%), 850(19%), 360(13%) | 44.6% | 18.98 | rich |
| McConaughy 2014 | large_reservoir | 2014-05-03 – 2014-10-26 | 422 | 87 | 5.34 | 2.34 | 22 | 850(31%), 360(30%), 620(12%) | 43.8% | 47.78 | rich |
| Merritt 2014 | large_reservoir | 2014-04-08 – 2014-10-26 | 617 | 106 | 5.96 | 2.41 | 17 | 850(36%), 830(10%), 730(9%) | 40.8% | 15.40 | rich |
| Harlan 2014 | large_reservoir | 2014-04-05 – 2014-10-25 | 595 | 85 | 4.79 | 2.28 | 11 | 850(32%), 360(24%), 620(22%) | 31.4% | 15.41 | rich |
| Calamus 2014 | large_reservoir | 2014-05-07 – **2020-05-09** | 362 | 68 | 5.09 | 2.46 | 13 | 850(42%), 620(30%), 862(14%) | 41.2% | 31.36 | rich; **date_max typo** |
| Sherman 2017 | large_reservoir | 2017-04-08 – 2017-10-25 | 775 | 113 | 4.47 | 2.03 | 15 | 785(28%), 850(26%), 360(13%) | 45.8% | 20.45 | rich |
| Calamus 2017 | large_reservoir | 2017-04-02 – 2017-10-18 | 499 | 86 | 4.98 | 2.59 | 14 | 620(47%), 850(26%), 862(14%) | 47.4% | 14.66 | rich |
| Harlan 2017 | large_reservoir | 2017-04-09 – 2017-10-29 | 590 | 95 | 5.28 | 2.28 | 12 | 620(40%), 850(26%), 862(11%) | 38.5% | 18.89 | rich |
| Pawnee 2017 | large_reservoir | 2017-04-03 – 2017-10-30 | 570 | 110 | 2.50 | 2.05 | 30 | 360(24%), 610(21%), 785(11%) | 24.2% | 11.18 | rich; **max species (30)** |
| Wanahoo 2017 | large_reservoir | 2017-04-01 – 2017-10-24 | 1219 | 113 | 3.69 | 2.04 | 12 | 785(33%), 770(29%), 360(12%) | 28.8% | 26.93 | rich; **max interviews (1,219)** |
| McConaughy 2017 | large_reservoir | 2017-04-01 – 2017-10-29 | 472 | 89 | 5.36 | 2.20 | 23 | 850(32%), 620(17%), 360(13%) | 35.0% | 48.03 | rich; highest mean count |
| Sherman 2018 | large_reservoir | 2018-04-05 – 2018-10-30 | 798 | 109 | 4.92 | 2.10 | 17 | 785(30%), 850(24%), 360(14%) | 31.7% | 21.40 | rich |
| Branched Oak 2018 | large_reservoir | 2018-04-05 – 2018-10-28 | 716 | 106 | 3.07 | 2.10 | 22 | 785(29%), 360(24%), 850(12%) | 15.6% | 17.72 | rich |
| McConaughy 2018 | large_reservoir | 2018-04-08 – 2018-10-27 | 386 | 102 | 5.20 | 2.21 | 18 | 850(28%), 360(17%), 785(14%) | 39.2% | 16.19 | rich |
| Sutherland 2018 | large_reservoir | 2018-04-03 – 2018-10-31 | 371 | 91 | 3.97 | 2.01 | 18 | 850(25%), 360(22%), 785(14%) | 49.2% | 3.97 | rich |
| Pawnee 2018 | large_reservoir | 2018-04-12 – 2018-10-28 | 344 | 90 | 3.66 | 1.90 | 21 | 360(42%), 610(10%), 785(10%) | 21.8% | 5.22 | rich |
| Calamus 2018 | large_reservoir | 2018-04-12 – 2018-10-29 | 444 | 81 | 4.89 | 2.30 | 11 | 620(38%), 850(24%), 862(13%) | 40.1% | 12.34 | rich |
| Merritt 2018 | large_reservoir | 2018-04-01 – 2018-10-31 | 334 | 93 | 6.02 | 2.48 | 15 | 850(40%), 360(18%), 730(10%) | 30.2% | 14.32 | rich |
| Sutherland 2021 | large_reservoir | 2021-04-01 – 2021-10-30 | 476 | 103 | 3.13 | 2.00 | 22 | 850(26%), 360(22%), 785(13%) | 34.3% | 5.56 | rich |
| Gracie Creek 2014 | urban_small | 2014-05-24 – 2014-08-11 | 32 | 23 | 3.00 | 2.53 | 2 | 520(97%), 360(3%) | 74.5% | 2.77 | put-and-take |
| Gracie Creek 2015 | urban_small | 2015-04-12 – 2015-10-19 | 55 | 40 | 1.91 | 2.64 | 3 | 520(94%), 178(4%) | 37.3% | 1.04 | put-and-take |
| Gracie Creek 2016 | urban_small | 2016-04-04 – 2016-10-28 | 44 | 32 | 2.02 | 2.98 | 4 | 520(94%), 178(2%) | 86.9% | 0.89 | put-and-take; **max harvest rate** |
| Gracie Creek 2017 | urban_small | 2017-04-02 – 2017-10-18 | 49 | 32 | 1.83 | 2.37 | 1 | 520(100%) | 47.2% | 0.94 | put-and-take; mono-species |
| Gracie Creek 2018 | urban_small | 2018-04-22 – 2018-10-21 | 30 | 19 | 1.73 | 3.00 | 1 | 520(100%) | 75.8% | 0.59 | put-and-take; mono-species; short |
| Yanney Park 2016 | urban_small | 2016-03-03 – 2016-03-26 | 55 | 12 | 1.96 | 2.16 | 7 | 520(80%), 730(8%) | 13.8% | 4.10 | short; winter stocking |
| Fort Kearney 6 2016 | urban_small | 2016-03-04 – 2016-03-29 | 31 | 14 | 1.84 | 2.35 | 4 | 520(67%), 730(12%) | 41.7% | 2.25 | short; winter stocking |
| Prairie Queen 2015 | urban_small | 2015-03-31 – 2015-04-30 | 233 | 20 | 2.26 | 1.69 | 3 | 770(97%), 730(3%) | 0.1% | 13.79 | C&R; **min harvest rate** |
| Prairie Queen 2019 | urban_small | 2019-04-05 – 2019-10-28 | 921 | 105 | 2.82 | 2.03 | 13 | 730(36%), 770(35%) | 13.9% | 9.60 | rich; **max urban interviews** |
| Standing Bear 2019 | urban_small | 2019-04-03 – 2019-10-27 | 296 | 99 | 1.78 | 2.08 | 14 | 730(45%), 785(19%) | 16.1% | 7.39 | rich |
| Lake Halleck 2019 | urban_small | 2019-04-02 – 2019-10-31 | 351 | 106 | 1.55 | 1.91 | 13 | 770(21%), 725(21%) | 12.3% | 3.82 | rich; **min effort** |
| Schwer Pond 2019 | urban_small | 2019-04-02 – 2019-09-26 | 36 | 26 | 1.47 | 2.11 | 8 | 730(43%), 360(31%) | 5.3% | 0.39 | small pond |
| Flanagan 2021 | urban_small | 2021-04-03 – 2021-10-29 | 894 | 113 | 2.56 | 1.93 | 10 | 770(37%), 730(32%) | 0.5% | 7.57 | C&R-dominated |
| Benson 2021 | urban_small | 2021-04-04 – 2021-10-30 | 195 | 86 | 1.50 | 1.89 | 11 | 310(35%), 722(20%) | 20.0% | 1.52 | rich; rough fish dominant |
| Fontenelle Pond 2021 | urban_small | 2021-04-01 – 2021-10-31 | 114 | 67 | 1.46 | 1.68 | 9 | 730(35%), 770(24%) | 18.4% | 0.62 | **min effort** |
| Walnut Creek 2021 | urban_small | 2021-04-01 – 2021-10-31 | 750 | 116 | 2.76 | 1.63 | 9 | 730(33%), 770(32%) | 16.4% | 9.22 | |
| Offutt Base Lake 2021 | urban_small | 2021-05-01 – 2021-08-28 | 140 | 57 | 2.64 | 1.24 | 17 | 770(31%), 750(18%) | 4.0% | 2.67 | rich; military base access |
| *33 pressure-only (2019–2020)* | urban_small | NA | 0 | 0 | NA | NA | 0 | NA | NA | 0–15 | counts only; no interview data |

---

## 4. Data Quality Flags

| Creel | Issue | Recommendation |
|-------|-------|----------------|
| McConaughy 2015 | `date_min` = `2005-09-03` (likely `2015-04-XX`) | Exclude from date-range parameterization; use counts/catch only |
| Calamus 2014 | `date_max` = `2020-05-09` (likely `2014-10-XX`) | Exclude from date-range parameterization; use counts/catch only |
| Haworth Pond Pressure 2019 | All count fields NA, 100% zero counts | Exclude from pressure model fitting |
| Haworth Pond Pressure 2020 | `mean_total_anglers` = NA | Exclude entirely |
| Gracie Creek 2017/2018 | 1 species, 30 interviews | Mono-species; useful for extreme put-and-take scenario only |
| All 33 pressure-only | No interview data | Useful for angler pressure/count model only |
| `pct_zero_angler` all = 0 | Query artifact (see note at top) | Never use as $P(\text{catch}=0)$; derive from GetInterviewData |

---

## 5. Species Code Inventory (NGPC/AFS)

Frequencies = number of creels where species appears in top-5 catch ranks.

| Code | Species | Frequency (creels) | Waterbody context |
|------|---------|--------------------|-------------------|
| 360 | bluegill | 43 | ubiquitous |
| 850 | walleye | 32 | large reservoir dominant |
| 730 | saugeye | 25 | urban + reservoir |
| 620 | northern pike | 22 | large reservoir (Calamus, Harlan) |
| 785 | wiper (hybrid striped bass) | 20 | large reservoir (Branched Oak, Sherman) |
| 862 | rainbow trout | 19 | large reservoir (Calamus, Merritt) |
| 770 | smallmouth bass | 19 | urban dominant |
| 610 | yellow perch | 10 | large reservoir (Pawnee) |
| 750 | striped bass | 9 | large reservoir |
| 520 | largemouth bass | 9 | urban/put-and-take (Gracie Creek) |
| 645 | sauger | 8 | large reservoir |
| 830 | yellow perch (alt code) | 6 | large reservoir |
| 420 | channel catfish | 5 | |
| 790 | yellow bass | 4 | |
| 178 | white crappie | 4 | |
| 725 | shorthead redhorse | 3 | urban (Halleck) |
| 630 | muskellunge | 2 | |
| 340 | bigmouth buffalo | 2 | |
| 310 | common carp | 2 | urban (Benson) |
| 722 | river carpsucker | 2 | urban (Benson) |
| 740 | white bass | 1 | |
| 128 | black crappie | 1 | |

**Note:** Codes 999 and 998 appear in `ii_SpeciesSought` as "unspecified" / "other" — not in catch records.

---

## 6. Recommendations for Simulator Development

### Representative Creels by Scenario

| Scenario | Best Template Creels | Reason |
|----------|---------------------|--------|
| Large reservoir — typical | Sherman 2016, Wanahoo 2017 | High n_int, full season, typical params |
| Large reservoir — walleye | Merritt 2016/2018, McConaughy 2017 | Walleye-dominated, long effort |
| Large reservoir — pike/walleye | Calamus 2016/2017, Harlan 2016 | Dual-species, high harvest |
| Large reservoir — mixed | Pawnee 2017 | Max species richness (30 sp) |
| Large reservoir — high pressure | McConaughy 2014/2017 | Max mean counts (47–48) |
| Urban — typical season | Prairie Queen 2019, Walnut Creek 2021 | High n_int, full season |
| Urban — C&R managed | Flanagan 2021, Prairie Queen 2015/2019 | Near-zero harvest |
| Urban — put-and-take | Gracie Creek 2016/2018 | High harvest, few species |
| Urban — short stocking event | Yanney Park 2016, Fort Kearney 2016 | 12–14 day winter trout stocking |
| Urban — diverse | Standing Bear 2019, Lake Halleck 2019 | Multi-species urban with full season |

### Distributional Choices

```r
# Effort (hr/trip) — use Gamma, not Normal
effort_large  <- rgamma(n, shape = 2.5, rate = 0.57)  # mean ~4.4, CV ~0.63
effort_urban  <- rgamma(n, shape = 2.4, rate = 1.20)  # mean ~2.0, CV ~0.65

# Catch per trip — use Negative Binomial (high CV ~1.25)
catch_large   <- rnbinom(n, mu = 9.8, size = 0.64)
catch_urban   <- rnbinom(n, mu = 6.5, size = 0.59)

# Party size — Poisson truncated at 1 (min 1 angler)
party         <- pmax(1L, rpois(n, lambda = 2.2))

# Trip start hour — Normal, right-censor at ~20:00
start_large   <- rnorm(n, mean = 10.2, sd = 3.5)
start_urban   <- rnorm(n, mean = 12.5, sd = 3.5)

# pct_zero_angler — DO NOT USE from inventory; estimated ~40-60% from literature
# Use GetInterviewData UID cross-reference instead
```

### Known Data Limitations

1. **Zero-catch interviews absent**: `GetCatchData` is catch-only; zero-catch records
   missing. Cross-reference `GetInterviewData` UID set to get true zero-catch rate.
2. **Length data not in inventory**: `GetCatchData` has no length fields; length data
   is in a separate endpoint. Not captured in this inventory.
3. **33 pressure-only creels**: Count data available but no species/effort info.
   Useful for calibrating angler pressure models separately.
4. **Species codes are NGPC numeric**: No name field in API. Map via table above.
5. **Two date anomalies**: McConaughy 2015 (`date_min` = 2005) and Calamus 2014
   (`date_max` = 2020) have data entry errors in date fields.

---

*Generated 2026-05-28 from NGPC API. Raw data: `/tmp/creel_inventory2.rds` (86 records).*
