# Page components: small pieces of HTML built from the data.
# Prose (interpretation, technical notes) lives in the .qmd files instead,
# so it can be edited without touching R.

library(htmltools)

programs <- list(
  bowel    = list(title = "Bowel Cancer",    href = "bowel-cancer.html",    icon = "bi-clipboard2-pulse",
                  blurb = "National Bowel Cancer Screening Program: participation, kits completed and time to colonoscopy."),
  breast   = list(title = "Breast Cancer",   href = "breast-cancer.html",   icon = "bi-heart-pulse",
                  blurb = "BreastScreen Victoria: participation and screening numbers."),
  cervical = list(title = "Cervical Cancer", href = "cervical-cancer.html", icon = "bi-shield-plus",
                  blurb = "National Cervical Screening Program: coverage, tests, self-collection and time to colposcopy.")
)

# --- Inline values (use inside `r ...` in text) ------------------------------

key_figure <- function(id) {
  ind <- indicator(id)
  fmt_value(if (ind$measure == "rate") 100 * ind$rate else ind$numerator, ind$measure)
}

latest_period <- function(id) indicator(id)$period

# --- Mini cards under the key insight ---------------------------------------

mini_card <- function(label, value, note = NULL) {
  div(class = "mini-card",
    div(class = "mini-card-label", label),
    div(class = "mini-card-value", value),
    if (!is.null(note)) div(class = "mini-card-note", note)
  )
}

insight_cards <- function(id) {
  ind <- indicator(id)
  d <- compare_data(id)
  p <- levels(d$period)
  vic <- dplyr::filter(d, breakdown == "Victoria", sex == "All")
  now <- vic$value[vic$period == dplyr::last(p)]
  before <- vic$value[vic$period == p[length(p) - 1]]
  change <- if (ind$measure == "rate") {
    sprintf("%+.1f pts", now - before)
  } else {
    sprintf("%+.1f%%", 100 * (now / before - 1))
  }

  lga <- dplyr::filter(d, breakdown == "LGA", sex == "All", period == dplyr::last(p))
  top <- dplyr::slice_max(lga, value, n = 1, with_ties = FALSE)
  bottom <- dplyr::slice_min(lga, value, n = 1, with_ties = FALSE)

  cards <- list(
    mini_card(paste("Change since", p[length(p) - 1]), change),
    mini_card("Highest LGA", fmt_value(top$value, ind$measure), top$category),
    mini_card("Lowest LGA", fmt_value(bottom$value, ind$measure), bottom$category)
  )
  if (has_sex_split(id)) {
    sx <- dplyr::filter(d, breakdown == "Victoria", period == dplyr::last(p), sex != "All")
    cards <- c(cards, list(mini_card("Female / Male",
      paste(fmt_value(sx$value[sx$sex == "Female"], ind$measure), "/", fmt_value(sx$value[sx$sex == "Male"], ind$measure)))))
  }
  div(class = "mini-cards", cards)
}

# --- Excel download ----------------------------------------------------------

download_link <- function(id, label = NULL) {
  ind <- indicator(id)
  dir.create("downloads", showWarnings = FALSE)
  file <- file.path("downloads", paste0(id, ".xlsx"))
  writexl::write_xlsx(list(Data = run_sql("data_table.sql", id)), file)
  label <- label %||% paste(programs[[ind$program]]$title, ind$focus_area, "data table (synthetic)")
  HTML(as.character(
    a(class = "download-link", href = file, download = NA,
      tags$i(class = "bi bi-file-earmark-spreadsheet"), span(label))
  ))
}

# --- Chart panel -------------------------------------------------------------

.ids <- new.env()
next_id <- function(prefix) {
  .ids[[prefix]] <- (.ids[[prefix]] %||% 0) + 1
  paste0(prefix, "-", .ids[[prefix]])
}

# Bootstrap pills that switch between panes. Each pane is a chart.
pill_tabs <- function(panes, label = NULL, class = "chart-pills", icons = NULL) {
  ids <- vapply(seq_along(panes), function(i) next_id("pane"), character(1))
  first <- seq_along(panes) == 1
  tagList(
    div(class = class, role = "tablist",
      if (!is.null(label)) span(class = "pill-label", label),
      lapply(seq_along(panes), function(i) {
        tags$button(
          class = paste("chart-pill", if (first[i]) "active"),
          type = "button", role = "tab",
          `data-bs-toggle` = "pill", `data-bs-target` = paste0("#", ids[i]),
          if (!is.null(icons)) tags$i(class = paste("bi", icons[i])),
          names(panes)[i]
        )
      })
    ),
    div(class = "tab-content",
      lapply(seq_along(panes), function(i) {
        div(class = paste("tab-pane fade", if (first[i]) "show active"), id = ids[i], role = "tabpanel", panes[[i]])
      })
    )
  )
}

sized <- function(widget, height = "460px") {
  widget$width <- "100%"
  widget$height <- height
  widget
}

#' The chart panel for one focus area: Compare, Map, Trend and Variation
#' views, each with its own options.
chart_panel <- function(id) {
  ind <- indicator(id)
  compare_by <- c("Age group", if (has_sex_split(id)) "Sex", "LPHU", "PHN")
  compare <- stats::setNames(lapply(compare_by, function(by) sized(chart_compare(id, by))), compare_by)

  maps <- list(
    "LGA"       = sized(chart_map(id, "LGA"), "520px"),
    "Melbourne" = sized(chart_map(id, "LGA", melbourne = TRUE), "520px"),
    "PHN"       = sized(chart_map(id, "PHN"), "520px"),
    "LPHU"      = sized(chart_map(id, "LPHU"), "520px")
  )

  variation_note <- if (ind$variation == "funnel") {
    "Funnel plot: points outside the shaded bands differ from the Victorian rate by more than chance would explain."
  } else {
    "Change in each Local Public Health Unit between 2019, before COVID-19, and the latest year."
  }

  div(class = "chart-panel",
    pill_tabs(
      list(
        Compare = div(class = "chart-view", pill_tabs(compare, "Compare by", "chart-pills chart-pills-sub")),
        Map = div(class = "chart-view", pill_tabs(maps, "Area", "chart-pills chart-pills-sub"),
                  p(class = "chart-hint", "Scroll to zoom, drag to pan. Use the timeline to change the period.")),
        Trend = div(class = "chart-view", sized(chart_trend(id), "440px"),
                    p(class = "chart-hint", "Select a PHN in the legend to add it to the chart.")),
        Variation = div(class = "chart-view", p(class = "chart-hint", variation_note), chart_variation(id))
      ),
      class = "chart-pills chart-pills-main",
      icons = c("bi-bar-chart-line", "bi-geo-alt", "bi-graph-up", "bi-bullseye")
    )
  )
}

# --- Summary page ------------------------------------------------------------

key_figures_carousel <- function() {
  inds <- indicators()
  id <- "key-figures"
  slides <- lapply(seq_len(nrow(inds)), function(i) {
    ind <- inds[i, ]
    prog <- programs[[ind$program]]
    div(class = paste("carousel-item", if (i == 1) "active"),
      div(class = "insight-slide",
        div(class = "insight-slide-program", tags$i(class = paste("bi", prog$icon)), prog$title, " · ", ind$focus_area),
        div(class = "insight-slide-value", key_figure(ind$indicator_id)),
        div(class = "insight-slide-text", paste0(ind$headline, " in ", ind$period, ".")),
        a(class = "insight-slide-link", href = paste0(prog$href, "#", tolower(gsub("[^A-Za-z]+", "-", ind$focus_area))),
          "View ", tolower(ind$focus_area), tags$i(class = "bi bi-arrow-right"))
      )
    )
  })
  div(class = "key-figures",
    div(class = "key-figures-header",
      h2("Key figures"),
      div(class = "key-figures-controls",
        span(class = "key-figures-count", `data-carousel` = id, sprintf("Insight 1 of %d", nrow(inds))),
        tags$button(class = "kf-btn", type = "button", `data-bs-target` = paste0("#", id), `data-bs-slide` = "prev",
                    `aria-label` = "Previous insight", tags$i(class = "bi bi-chevron-left")),
        tags$button(class = "kf-btn kf-btn-next", type = "button", `data-bs-target` = paste0("#", id), `data-bs-slide` = "next",
                    "Next insight ", tags$i(class = "bi bi-chevron-right"))
      )
    ),
    div(id = id, class = "carousel slide", `data-bs-ride` = "false", `data-bs-interval` = "false",
      div(class = "carousel-inner", slides)
    )
  )
}

program_cards <- function() {
  div(class = "program-cards",
    lapply(programs, function(prog) {
      a(class = "program-card", href = prog$href,
        tags$i(class = paste("bi", prog$icon, "program-card-icon")),
        h3(prog$title),
        p(prog$blurb),
        span(class = "program-card-link", "Detailed report ", tags$i(class = "bi bi-arrow-right"))
      )
    })
  )
}
