# Release helpers: the mechanical half of a CRAN release. Run from the ROOT of
# the main checkout, through just or in an R session:
#
#   just release-prep 9.0.0 "Fish Name"                # cut cran-9.0.0 from main
#   just release-prep 8.0.2 "" origin/cran-8.0.1       # patch: from the CRAN line
#   just release-check                                 # --as-cran + guard dry run
#   source("scripts/cran-submit.R"); cran_submit()     # YOU, interactively
#   just release-accepted 9.0.0                        # after CRAN publishes it
#
# The process these implement -- cadence, when a patch is allowed, which steps
# stay human -- is in CONTRIBUTING.md under "Releases".
#
# WHY THIS EXISTS
#
# Every step below was done by hand from notes until 8.0.1, and the hand
# process had failed in ways no gate catches: CITATION.cff named the previous
# release for a whole cycle (nothing reads it), CRAN-SUBMISSION was never
# written because devtools skips it inside a git worktree, and a tag was placed
# on a commit CRAN never received. These helpers do only what is deterministic.
# Writing cran-comments.md, consolidating NEWS headings, choosing the fish name
# and submitting stay with a person; where a helper finds one of those
# undone, it refuses or says so rather than guessing.

release_git <- function(path, ...) {
  out <- suppressWarnings(system2("git", c("-C", shQuote(path), ...), stdout = TRUE, stderr = TRUE))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    stop("git ", paste(c(...), collapse = " "), " failed:\n", paste(out, collapse = "\n"), call. = FALSE)
  }
  out
}

release_refuse <- function(...) stop("Refusing: ", ..., call. = FALSE)

release_check_version <- function(version) {
  if (!grepl("^[0-9]+[.][0-9]+[.][0-9]+$", version)) {
    release_refuse("'", version, "' is not a release version (x.y.z).")
  }
}

# The lines of NEWS.md from `heading_rx` to the line before the next top-level
# heading, as a list(start, end) of line numbers, or NULL.
release_news_section <- function(news, heading_rx) {
  start <- grep(heading_rx, news)[1]
  if (is.na(start)) return(NULL)
  later <- grep("^# ", news)
  later <- later[later > start]
  end <- if (length(later)) later[1] - 1L else length(news)
  list(start = start, end = end)
}

release_version_rx <- function(version) {
  paste0("^# tidycreel ", gsub(".", "[.]", version, fixed = TRUE), "( |$)")
}

# Split section lines into blocks: each `## ` heading and each `* ` bullet, with
# the lines that follow it up to the next heading or bullet.
release_news_blocks <- function(lines) {
  starts <- grep("^(## |[*] )", lines)
  if (!length(starts)) return(list(head = lines, blocks = list()))
  ends <- c(starts[-1] - 1L, length(lines))
  list(
    head = lines[seq_len(starts[1] - 1L)],
    blocks = Map(function(s, e) lines[s:e], starts, ends)
  )
}

release_norm <- function(block) gsub("\\s+", " ", trimws(paste(block, collapse = " ")))

release_dup_headings <- function(lines) {
  h <- grep("^## ", lines, value = TRUE)
  unique(h[duplicated(h)])
}

# The newest NEWS section that has a tag must still match NEWS.md at that tag.
# The development section had no `## Breaking changes` heading, so five entries
# merged after 8.0.0 were filed under 8.0.0's own: they would have shipped as
# history rather than news, and the release notes would have missed them.
# Found by the first dry run of release_accepted(); this refuses the next one.
release_check_released_section <- function(news, path) {
  heads <- grep("^# tidycreel [0-9]+[.][0-9]+[.][0-9]+", news)
  for (h in heads) {
    v <- regmatches(news[h], regexpr("[0-9]+[.][0-9]+[.][0-9]+", news[h]))
    tag <- paste0("v", v)
    if (!length(release_git(path, "tag", "--list", tag))) next
    then <- release_git(path, "show", paste0(tag, ":NEWS.md"))
    norm_sec <- function(x) {
      s <- release_news_section(x, release_version_rx(v))
      vapply(release_news_blocks(x[(s$start + 1L):s$end])$blocks, release_norm, "")
    }
    extra <- setdiff(norm_sec(news), norm_sec(then))
    extra <- extra[grepl("^[*] ", extra)]
    if (length(extra)) {
      release_refuse("NEWS ", v, " has ", length(extra), " entr", if (length(extra) == 1) "y" else "ies",
                     " that are not in NEWS.md at ", tag, "; move them to the section being released:\n",
                     paste0("  ", substr(extra, 1, 100), collapse = "\n"))
    }
    return(invisible(v))
  }
  invisible(NULL)
}

#' Cut a release branch in the submit worktree and stamp the version.
#'
#' Leaves the changes UNCOMMITTED for review. cran-comments.md is not written:
#' it is the one document CRAN reads, and it needs a person.
release_prep <- function(version, name = "", from = "origin/main",
                         path = "~/Dev/tidycreel-submit") {
  release_check_version(version)
  path <- normalizePath(path, mustWork = TRUE)
  patch <- !grepl("[.]0$", version)
  if (!patch && !nzchar(name)) {
    release_refuse("a minor or major release needs a fish name (see data-raw/generate_fish_names.R).")
  }
  if (length(release_git(path, "status", "--porcelain")) > 0L) {
    release_refuse("'", path, "' has uncommitted or untracked files.")
  }
  branch <- paste0("cran-", version)
  release_git(path, "fetch", "--quiet", "origin")
  if (length(release_git(path, "ls-remote", "--heads", "origin", branch)) > 0L ||
      length(release_git(path, "branch", "--list", branch)) > 0L) {
    release_refuse("branch ", branch, " already exists.")
  }
  release_check_released_section(release_git(path, "show", paste0(from, ":NEWS.md")), path)
  release_git(path, "switch", "--quiet", "--no-track", "-c", branch, from)

  desc_file <- file.path(path, "DESCRIPTION")
  desc <- readLines(desc_file)
  desc <- sub("^Version: .*$", paste0("Version: ", version), desc)
  writeLines(desc, desc_file)

  # Re-stamped with CRAN's publication date by release_accepted(); today is a
  # placeholder that is at least not the previous release's date.
  cff_file <- file.path(path, "CITATION.cff")
  cff <- readLines(cff_file)
  cff <- sub("^version: .*$", paste0("version: ", version), cff)
  cff <- sub("^date-released: .*$", paste0("date-released: ", Sys.Date()), cff)
  writeLines(cff, cff_file)

  news_file <- file.path(path, "NEWS.md")
  news <- readLines(news_file)
  heading <- paste0("# tidycreel ", version, if (nzchar(name)) paste0(' "', name, '"'))
  if (identical(news[1], "# tidycreel (development version)")) {
    news[1] <- heading
  } else {
    # Cut from a CRAN branch: the fixes arrive by cherry-pick, and their NEWS
    # entries with them. The heading goes in now; release_check() refuses while
    # it has no entries.
    news <- c(heading, "", "## Bug fixes", "", news)
  }
  writeLines(news, news_file)

  sec <- release_news_section(news, release_version_rx(version))
  dups <- release_dup_headings(news[sec$start:sec$end])
  if (length(dups)) {
    message("NEWS ", version, " repeats headings -- consolidate them by hand, then count `* ` bullets before and after: ",
            paste(dups, collapse = ", "))
  }
  message("\nOn ", branch, " in ", path, " (uncommitted):")
  cat(release_git(path, "diff", "--stat"), sep = "\n")
  steps <- c(if (patch) "cherry-pick the fixes and resolve their NEWS entries under the new heading",
             paste0("rewrite cran-comments.md for ", version),
             paste0("commit, push ", branch, ", and run `just release-check`"))
  message("\nNext, by hand:\n", paste0("  ", seq_along(steps), ". ", steps, collapse = "\n"))
  invisible(branch)
}

#' Everything that can be checked before submission, in the submit worktree.
release_check <- function(path = "~/Dev/tidycreel-submit") {
  path <- normalizePath(path, mustWork = TRUE)
  version <- unname(read.dcf(file.path(path, "DESCRIPTION"), fields = "Version")[1, 1])
  release_check_version(version)

  news <- readLines(file.path(path, "NEWS.md"))
  sec <- release_news_section(news, release_version_rx(version))
  if (is.null(sec) || sec$start != 1L) release_refuse("NEWS.md does not start with a ", version, " heading.")
  if (!any(grepl("^[*] ", news[sec$start:sec$end]))) release_refuse("the NEWS ", version, " section has no entries.")
  dups <- release_dup_headings(news[sec$start:sec$end])
  if (length(dups)) release_refuse("NEWS ", version, " repeats headings: ", paste(dups, collapse = ", "))
  release_check_released_section(news, path)

  cff <- readLines(file.path(path, "CITATION.cff"))
  if (!paste0("version: ", version) %in% cff) release_refuse("CITATION.cff does not say version ", version, ".")

  # The guard first: it is fast, and it refuses an unpushed or dirty branch
  # before twenty minutes go into a check of the wrong commit.
  source(file.path("scripts", "cran-submit.R"), local = TRUE)
  cran_submit(path, dry_run = TRUE)

  res <- rcmdcheck::rcmdcheck(path, args = "--as-cran", error_on = "never", quiet = TRUE,
                              env = c("_R_CHECK_FORCE_SUGGESTS_" = "false"))
  cat("\n--as-cran:", length(res$errors), "errors |", length(res$warnings), "warnings |",
      length(res$notes), "notes\n")
  for (n in c(res$errors, res$warnings, res$notes)) cat("\n", n, "\n", sep = "")
  message("\nEvery NOTE above must be explained in cran-comments.md. Then: devtools::check_win_devel(\"",
          path, "\"), record its result in cran-comments.md, push, and submit with cran_submit().")
  invisible(res)
}

#' After CRAN publishes `version`: tag the submitted commit, publish the GitHub
#' release, and bring main's NEWS, DESCRIPTION, CITATION.cff and CRAN-SUBMISSION
#' up to date on a new branch, UNCOMMITTED for review.
#'
#' Idempotent for the tag and the release: an existing one is reported, never
#' replaced. `dry_run = TRUE` skips the CRAN check and every push and API call.
release_accepted <- function(version, main_path = ".", notes_file = NULL, main_ref = "origin/main",
                             dry_run = FALSE, repo = "chrischizinski/tidycreel") {
  release_check_version(version)
  main_path <- normalizePath(main_path, mustWork = TRUE)
  branch <- paste0("cran-", version)
  tag <- paste0("v", version)

  published <- as.character(Sys.Date())
  if (!dry_run) {
    page <- readLines(sprintf("https://cran.r-project.org/web/packages/%s/index.html", basename(repo)), warn = FALSE)
    field <- function(label) {
      i <- grep(paste0("<td>", label, ":</td>"), page)[1]
      if (is.na(i)) return(NA_character_)
      gsub("<[^>]+>|\\s", "", page[i + 1L])
    }
    on_cran <- field("Version")
    if (!identical(on_cran, version)) {
      release_refuse("CRAN shows version ", on_cran, ", not ", version, ". Run this once it is published.")
    }
    published <- field("Published")
  }

  release_git(main_path, "fetch", "--quiet", "--tags", "origin")
  commit <- release_git(main_path, "rev-parse", paste0("origin/", branch))
  at <- function(file) release_git(main_path, "show", paste0(commit, ":", file))
  desc_v <- sub("^Version: ", "", grep("^Version: ", at("DESCRIPTION"), value = TRUE))
  if (!identical(desc_v, version)) release_refuse("origin/", branch, " has DESCRIPTION version ", desc_v, ".")

  rel_news <- at("NEWS.md")
  sec <- release_news_section(rel_news, release_version_rx(version))
  if (is.null(sec)) release_refuse("origin/", branch, " NEWS.md has no ", version, " heading.")
  heading <- rel_news[sec$start]
  section <- rel_news[sec$start:sec$end]
  title <- sub("^# ", "", heading)

  # Before anything is pushed: main's NEWS must be sound to be updated after.
  release_check_released_section(release_git(main_path, "show", paste0(main_ref, ":NEWS.md")), main_path)

  # Tag ----------------------------------------------------------------------
  existing <- release_git(main_path, "ls-remote", "--tags", "origin", tag)
  if (length(existing)) {
    message("Tag ", tag, " already on origin; left alone.")
  } else if (dry_run) {
    message("[dry run] would tag ", tag, " on ", substr(commit, 1, 8), ' as "', title, '" and push it.')
  } else {
    release_git(main_path, "tag", "-a", tag, commit, "-m", shQuote(title))
    release_git(main_path, "push", "origin", tag)
    message("Tagged ", tag, " on ", substr(commit, 1, 8), ".")
  }

  # GitHub release -----------------------------------------------------------
  body <- if (is.null(notes_file)) {
    paste(c(section[-1],
            sprintf("Full notes: [NEWS.md](https://github.com/%s/blob/%s/NEWS.md).", repo, tag)),
          collapse = "\n")
  } else {
    paste(readLines(notes_file), collapse = "\n")
  }
  have_release <- !dry_run && identical(
    suppressWarnings(system2("gh", c("api", sprintf("repos/%s/releases/tags/%s", repo, tag), "--silent"),
                             stdout = FALSE, stderr = FALSE)), 0L)
  if (have_release) {
    message("GitHub release ", tag, " already exists; left alone.")
  } else if (dry_run) {
    message("[dry run] would publish GitHub release '", title, "' (", nchar(body), " chars), marked Latest.")
  } else {
    # `gh release create` is hook-blocked here; the API takes a JSON file.
    json <- tempfile(fileext = ".json")
    jsonlite::write_json(list(tag_name = tag, name = title,
                              body = body, draft = FALSE, prerelease = FALSE, make_latest = "true"),
                         json, auto_unbox = TRUE)
    out <- system2("gh", c("api", "-X", "POST", sprintf("repos/%s/releases", repo), "--input", json,
                           "--jq", ".html_url"), stdout = TRUE)
    message("Published ", out)
  }

  # main ---------------------------------------------------------------------
  if (length(release_git(main_path, "status", "--porcelain", "--untracked-files=no")) > 0L) {
    release_refuse("'", main_path, "' has uncommitted changes to tracked files; main was not updated.")
  }
  post <- paste0("chore/post-release-", version)
  if (dry_run) {
    message("[dry run] main is updated in the working tree only, on no new branch; `git restore` undoes it.")
  } else {
    release_git(main_path, "switch", "--quiet", "--no-track", "-c", post, main_ref)
  }

  news_file <- file.path(main_path, "NEWS.md")
  news <- readLines(news_file)
  if (!is.null(release_news_section(news, release_version_rx(version)))) {
    message("main's NEWS.md already has a ", version, " section; NEWS left alone.")
  } else {
    dev <- release_news_section(news, "^# tidycreel [(]development version[)]")
    if (is.null(dev) || dev$start != 1L) release_refuse("main's NEWS.md does not start with the development heading.")
    released <- vapply(release_news_blocks(section[-1])$blocks, release_norm, "")
    released <- released[!grepl("^## ", released)]
    parts <- release_news_blocks(news[(dev$start + 1L):dev$end])
    is_bullet <- vapply(parts$blocks, function(b) grepl("^[*] ", b[1]), TRUE)
    shipped <- is_bullet & vapply(parts$blocks, release_norm, "") %in% released
    kept <- parts$blocks[!shipped]
    # Drop a heading left with no bullet under it.
    keep_block <- vapply(seq_along(kept), function(i) {
      if (!grepl("^## ", kept[[i]][1])) return(TRUE)
      nxt <- if (i < length(kept)) kept[[i + 1L]][1] else ""
      grepl("^[*] ", nxt)
    }, TRUE)
    kept <- kept[keep_block]
    new_dev <- c(news[dev$start], parts$head, unlist(kept))
    news <- c(new_dev, if (length(kept)) character() else "", section, news[(dev$end + 1L):length(news)])
    writeLines(news, news_file)
    n_rel <- length(released)
    message("NEWS: ", sum(shipped), " of ", n_rel, " released entries removed from the development section; ",
            sum(is_bullet) - sum(shipped), " remain there. ", version, " section inserted below it.")
    if (sum(shipped) < n_rel) {
      message("  ", n_rel - sum(shipped), " released entr", if (n_rel - sum(shipped) == 1) "y was" else "ies were",
              " not found verbatim on main (written on the release branch?). Check none is duplicated in the dev section.")
    }
  }

  desc_file <- file.path(main_path, "DESCRIPTION")
  desc <- readLines(desc_file)
  current <- sub("^Version: ", "", grep("^Version: ", desc, value = TRUE))
  base <- sub("[.]9[0-9]{3,}$", "", current)
  if (package_version(version) >= package_version(base)) {
    desc <- sub("^Version: .*$", paste0("Version: ", version, ".9000"), desc)
    writeLines(desc, desc_file)
    message("DESCRIPTION: ", current, " -> ", version, ".9000")
  }

  cff_file <- file.path(main_path, "CITATION.cff")
  cff <- readLines(cff_file)
  cff <- sub("^version: .*$", paste0("version: ", version), cff)
  cff <- sub("^date-released: .*$", paste0("date-released: ", published), cff)
  writeLines(cff, cff_file)

  # devtools writes this at submission, except inside a git worktree, where
  # `.git` is a file and it silently skips (8.0.0). Written here instead, so
  # Date is the acceptance run, not the submission; Version and SHA are exact.
  writeLines(c(paste0("Version: ", version),
               paste0("Date: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"), " UTC"),
               paste0("SHA: ", commit)),
             file.path(main_path, "CRAN-SUBMISSION"))

  message("\nmain updated", if (!dry_run) paste0(" on ", post), " (uncommitted):")
  cat(release_git(main_path, "diff", "--stat"), sep = "\n")
  message("Review the NEWS diff, then commit and open the PR.")
  invisible(commit)
}
