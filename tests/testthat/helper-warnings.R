# Data warnings (tier 2) print once per design (GH #496). A test that edits a
# design by hand, or asks the same design for the same warning again, is
# asking about new data -- which in real use arrives through an add_*() step,
# and that step gives the design a new id. This gives it one directly.
as_new_design <- function(design) {
  design$warning_id <- tidycreel:::new_warning_id()
  design
}
