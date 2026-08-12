# TODO: remove `inst/extdata/` waterbody datasets from the package

**Status:** open — noted 2026-08-05, nothing removed yet.

## What

`inst/extdata/` holds real creel survey datasets from 13 Nebraska waterbodies
plus a `pdfs/` directory of journal PDFs. These were working inputs used to fit
the distributional parameters behind `simulate_creel_data()` (see
`data-raw/ngpc_creel_params.rda`). They were never meant to ship with the
package.

```
inst/extdata/
  benson-2021/          lake-halleck-2019/       prairie-queen-2019/
  calamus-2016/         lawrence-youngman-2022/  schwer-pond-2019/
  flanagan-2021/        mcconaughy-spawn-2022/   standing-bear-2019/
  offutt-2021/          mcconaughy-spawn-2023/   walnut-creek-2021/
  zorinsky-2022/        pdfs/
```

Total 17 MB.

## Why it matters

- **`calamus-2016/` is committed to git** (6 files: `catch.csv`, `counts.csv`,
  `interviews.csv`, `harvest_lengths.csv`, `release_lengths.csv`,
  `reference-outputs.csv`). It entered the history at `9c10dc1` ("v1.7.0 API
  Connection & Real-Data Validation") and is still present at HEAD. Deleting it
  from HEAD does **not** remove it from the public history — anyone can check it
  out of an older commit.
- **The other 12 waterbody directories and `pdfs/` are untracked**, so they have
  not been pushed. They are still in the working tree, which means any local
  `R CMD build` / `R CMD INSTALL` sweeps them into the built package.
- **`inst/extdata` is not in `.Rbuildignore`**, so it is included in source
  tarballs and installed libraries. A local install of 2.5.0 on 2026-08-05 put
  all 17 MB into the site library.
- `pdfs/` contains published journal articles (Petrere et al. 2010, Beliveau
  2015, Ida/Rivest/Daigle 2018) — redistributing those in a package is a
  copyright problem independent of the data question.

## Blast radius

Nothing in the package depends on it. `grep -rl extdata R/ tests/ vignettes/`
returns no hits, and the built pkgdown site under `docs/` references no
`extdata` paths. Removal should not break the build, tests, or vignettes —
but re-run the check gate afterwards to confirm.

## Steps

1. Move the working data somewhere outside the package tree (a sibling
   `tidycreel-data/` directory, or the NGPC source system) so the parameter
   fitting in `data-raw/` stays reproducible.
2. `git rm -r --cached inst/extdata/calamus-2016` and commit the deletion.
3. Delete the untracked directories from the working tree, or add
   `^inst/extdata$` to `.Rbuildignore` if any of it must stay locally.
4. Decide on history: `git filter-repo` (or a BFG pass) to purge
   `inst/extdata/calamus-2016` from all commits, then force-push and ask
   collaborators to re-clone. Skipping this leaves the data public.
5. Reinstall locally and confirm `extdata/` is gone from the site library:
   `du -sh $(Rscript -e 'cat(find.package("tidycreel"))')/extdata`
6. Re-run `rcmdcheck::rcmdcheck(args = c('--no-manual', '--as-cran'))`.
7. Check whether any released tarball or GitHub release asset carries the data.
   `tidycreel_1.3.0.tar.gz` in the repo root is clean (0 extdata entries);
   later releases were not checked.

## Note

Whether the Calamus data can be public at all is an NGPC data-sharing question,
not just a repo-hygiene one. Worth confirming before deciding how hard to purge
the history.
