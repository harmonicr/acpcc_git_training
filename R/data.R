# Data access: every number on the site comes through these functions.
#
# Queries live in sql/ so they can be read, reviewed and diffed on their own.
# Results are cached for the rest of the R session, so a page that asks for
# the same indicator several times only queries the database once.

db_path <- "data/screening.duckdb"

.cache <- new.env(parent = emptyenv())

db <- function() {
  if (is.null(.cache$con) || !DBI::dbIsValid(.cache$con)) {
    if (!file.exists(db_path)) source("data-raw/make-synthetic.R", local = new.env())
    .cache$con <- DBI::dbConnect(duckdb::duckdb(db_path, read_only = TRUE, shared_home = FALSE))
  }
  .cache$con
}

# Run a query from sql/, passing any `?` parameters in order.
run_sql <- function(file, ...) {
  key <- paste(file, ..., sep = "|")
  if (is.null(.cache[[key]])) {
    sql <- paste(readLines(file.path("sql", file), warn = FALSE), collapse = "\n")
    params <- list(...)
    .cache[[key]] <- tibble::as_tibble(
      if (length(params)) DBI::dbGetQuery(db(), sql, params = params) else DBI::dbGetQuery(db(), sql)
    )
  }
  .cache[[key]]
}

indicators <- function() run_sql("key_figures.sql")

indicator <- function(id) {
  ind <- dplyr::filter(indicators(), indicator_id == id)
  if (nrow(ind) != 1) stop("Unknown indicator: ", id)
  as.list(ind)
}

# All breakdowns for one indicator, with `value` in display units:
# a percentage for rates, a count for counts.
compare_data <- function(id) {
  ind <- indicator(id)
  run_sql("compare.sql", id) |>
    dplyr::mutate(
      value = if (ind$measure == "rate") round(100 * rate, 1) else numerator,
      period = factor(period, levels = unique(period[order(end_year)]))
    )
}

periods <- function(id) levels(compare_data(id)$period)

has_sex_split <- function(id) any(compare_data(id)$sex == "Male")
