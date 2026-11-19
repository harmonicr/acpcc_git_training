# Chart builders. Each function takes an indicator id and returns one chart.
#
# Interactive charts use echarts4r, the R interface to Apache ECharts (the
# same library the original report uses). The variation charts use ggplot2
# with ggiraph, so they are ordinary ggplot2 code with hover tooltips added.

library(echarts4r)
library(ggplot2)
library(ggiraph)

# --- Shared settings --------------------------------------------------------

ec_base <- function(e, measure, trigger = "axis") {
  e |>
    e_text_style(fontFamily = font_family) |>
    e_tooltip(
      trigger = trigger,
      valueFormatter = js_formatter(measure),
      backgroundColor = "rgba(255,255,255,0.97)",
      borderColor = pal$grey_200,
      textStyle = list(color = pal$slate_900, fontFamily = font_family)
    ) |>
    e_toolbox_feature("saveAsImage", title = "Save as image")
}

# Legend along the top. Pass `selected` to start some series switched off.
ec_legend <- function(e, ...) {
  e_legend(e, top = 0, textStyle = list(color = pal$slate_800, fontFamily = font_family), ...)
}

# Timeline control for stepping through time periods. Starts on the latest.
ec_timeline <- function(e, n_periods) {
  e |>
    e_timeline_opts(
      axis_type = "category",
      currentIndex = n_periods - 1,
      autoPlay = FALSE,
      playInterval = 1600,
      bottom = 0,
      left = 30,
      right = 30,
      label = list(color = pal$slate_700, fontFamily = font_family),
      lineStyle = list(color = pal$grey_200),
      itemStyle = list(color = pal$slate_500),
      checkpointStyle = list(color = pal$blue, borderColor = pal$blue_pale, borderWidth = 4),
      controlStyle = list(color = pal$slate_700, borderColor = pal$slate_700),
      progress = list(lineStyle = list(color = pal$blue), itemStyle = list(color = pal$blue))
    )
}

# `from_zero = FALSE` lets the axis zoom in on the data, for trends where
# the change matters more than the level.
value_axis <- function(e, measure, horizontal = FALSE, from_zero = TRUE) {
  axis <- if (horizontal) e_x_axis else e_y_axis
  axis(e,
    min = if (from_zero) 0 else NULL,
    max = if (measure == "rate" && from_zero) 100 else NULL,
    scale = !from_zero,
    axisLabel = list(formatter = js_formatter(measure, digits = 0), color = pal$slate_700),
    splitLine = list(lineStyle = list(color = pal$grey_200))
  )
}

series_to_show <- function(id) if (has_sex_split(id)) c("All", "Female", "Male") else "All"

# --- Compare ----------------------------------------------------------------

#' Bar chart of one breakdown, with a timeline over periods and a dashed
#' statewide reference line.
chart_compare <- function(id, by = c("Age group", "Sex", "LPHU", "PHN")) {
  by <- match.arg(by)
  ind <- indicator(id)
  d <- compare_data(id)
  victoria <- d |>
    dplyr::filter(breakdown == "Victoria", sex == "All") |>
    dplyr::select(period, Victoria = value)

  if (by == "Sex") {
    d <- d |>
      dplyr::filter(breakdown == "Victoria", sex != "All") |>
      dplyr::mutate(category = sex, sex = "All")
    show <- "All"
  } else {
    show <- series_to_show(id)
    d <- dplyr::filter(d, breakdown == by, sex %in% show)
  }

  # Long region names read better as horizontal bars, sorted by latest value.
  horizontal <- by %in% c("LPHU", "PHN")
  latest <- dplyr::filter(d, period == dplyr::last(levels(period)), sex == "All")
  order <- if (horizontal) latest$category[order(latest$value)] else sort(unique(d$category))

  wide <- d |>
    dplyr::select(period, category, sex, value) |>
    tidyr::pivot_wider(names_from = sex, values_from = value) |>
    dplyr::left_join(victoria, by = "period") |>
    dplyr::mutate(category = factor(category, levels = order)) |>
    dplyr::arrange(period, category) |>
    dplyr::mutate(category = as.character(category))

  e <- wide |>
    dplyr::group_by(period) |>
    e_charts(category, timeline = TRUE)
  for (s in show) {
    e <- e_bar_(e, s,
      name = if (s == "All") ind$focus_area else s,
      itemStyle = list(color = sex_colours[[s]], borderRadius = if (horizontal) c(0, 4, 4, 0) else c(4, 4, 0, 0)),
      barMaxWidth = 34,
      emphasis = list(itemStyle = list(color = pal$yellow))
    )
  }
  e <- e_line(e, Victoria,
    name = "Victoria",
    symbol = "none",
    lineStyle = list(type = "dashed", color = pal$ink, width = 1.5),
    itemStyle = list(color = pal$ink),
    z = 5
  )
  e <- e |>
    ec_base(ind$measure) |>
    ec_legend(selected = if (length(show) > 1) list(Female = FALSE, Male = FALSE)) |>
    ec_timeline(length(levels(d$period))) |>
    e_grid(left = 10, right = 30, top = 40, bottom = 70, containLabel = TRUE) |>
    value_axis(ind$measure)
  if (horizontal) e <- e_flip_coords(e) |> value_axis(ind$measure, horizontal = TRUE)
  e |> e_x_axis(axisLabel = list(color = pal$slate_800)) |> e_y_axis(axisLabel = list(color = pal$slate_800))
}

# --- Map --------------------------------------------------------------------

geo_layers <- list(
  LGA  = list(file = "data/geo/lga.geojson",  property = "lga_name"),
  PHN  = list(file = "data/geo/phn.geojson",  property = "phn"),
  LPHU = list(file = "data/geo/lphu.geojson", property = "lphu")
)

#' Choropleth of one geography, with a timeline over periods.
#' `melbourne = TRUE` starts zoomed in on metropolitan Melbourne.
chart_map <- function(id, level = c("LGA", "PHN", "LPHU"), melbourne = FALSE) {
  level <- match.arg(level)
  ind <- indicator(id)
  layer <- geo_layers[[level]]
  map_name <- paste0("vic_", tolower(level))
  d <- dplyr::filter(compare_data(id), breakdown == level, sex == "All")

  view <- if (melbourne) {
    list(center = c(145.1, -37.88), zoom = 6.5)
  } else {
    list(center = c(144.9, -36.75), zoom = 1.15)
  }

  d |>
    dplyr::select(period, category, value) |>
    dplyr::group_by(period) |>
    e_charts(category, timeline = TRUE) |>
    e_map_register(map_name, jsonlite::read_json(layer$file)) |>
    e_map(value,
      map = map_name,
      name = ind$focus_area,
      nameProperty = layer$property,
      roam = TRUE,
      showLegendSymbol = FALSE,
      center = view$center,
      zoom = view$zoom,
      scaleLimit = list(min = 1, max = 20),
      aspectScale = 0.85,
      layoutCenter = c("50%", "45%"),
      layoutSize = "95%",
      itemStyle = list(borderColor = "#ffffff", borderWidth = 0.6, areaColor = pal$grey_200),
      emphasis = list(
        label = list(show = TRUE, color = pal$ink, fontFamily = font_family, fontWeight = "bold"),
        itemStyle = list(areaColor = pal$yellow)
      ),
      select = list(disabled = TRUE)
    ) |>
    e_visual_map(
      min = floor(min(d$value)),
      max = ceiling(max(d$value)),
      inRange = list(color = map_colours),
      calculable = TRUE,
      orient = "vertical",
      left = 10,
      top = 10,
      itemHeight = 120,
      formatter = js_formatter(ind$measure, digits = 0),
      textStyle = list(color = pal$slate_700)
    ) |>
    ec_base(ind$measure, trigger = "item") |>
    e_legend(show = FALSE) |>
    ec_timeline(length(levels(d$period)))
}

# --- Trend ------------------------------------------------------------------

# Periods that overlap the main COVID-19 disruption (2020-2021).
covid_periods <- function(id) {
  p <- periods(id)
  start <- as.integer(substr(p, 1, 4))
  end <- as.integer(sub(".*-", "", p))
  p[start <= 2021 & end >= 2020 & (end - start) < 4]
}

#' Line chart over all periods: Victoria (and by sex where relevant), with
#' each PHN available from the legend. COVID-19 periods are shaded.
chart_trend <- function(id) {
  ind <- indicator(id)
  d <- compare_data(id)
  vic <- d |>
    dplyr::filter(breakdown == "Victoria", sex %in% series_to_show(id)) |>
    dplyr::mutate(series = dplyr::if_else(sex == "All", "Victoria", sex))
  phn <- d |>
    dplyr::filter(breakdown == "PHN", sex == "All") |>
    dplyr::mutate(series = paste(category, "PHN"))

  wide <- dplyr::bind_rows(vic, phn) |>
    dplyr::select(period, series, value) |>
    tidyr::pivot_wider(names_from = series, values_from = value) |>
    dplyr::arrange(period) |>
    dplyr::mutate(period = as.character(period))

  phn_series <- sort(unique(phn$series))
  phn_colours <- c(pal$slate_500, pal$blue_light, pal$red, "#7A9E7E", "#9C6ADE", "#E58E3A")
  e <- e_charts(wide, period)
  e <- e_line(e, Victoria,
    lineStyle = list(width = 4, color = pal$blue), itemStyle = list(color = pal$blue),
    symbolSize = 9)
  for (s in intersect(c("Female", "Male"), names(wide))) {
    e <- e_line_(e, s, lineStyle = list(width = 2.5, color = sex_colours[[s]]),
                 itemStyle = list(color = sex_colours[[s]]), symbolSize = 7)
  }
  for (i in seq_along(phn_series)) {
    e <- e_line_(e, phn_series[i], lineStyle = list(width = 1.5, type = "dashed"),
                 itemStyle = list(color = phn_colours[i]), symbolSize = 5)
  }

  covid <- covid_periods(id)
  if (length(covid)) {
    e <- e_mark_area(e, serie = "Victoria",
      data = list(list(xAxis = covid[1]), list(xAxis = covid[length(covid)])),
      itemStyle = list(color = "rgba(255,212,87,0.22)"),
      label = list(formatter = "COVID-19", color = pal$slate_700, fontFamily = font_family)
    )
  }

  off <- c(phn_series, intersect(c("Female", "Male"), names(wide)))
  hidden <- stats::setNames(as.list(rep(FALSE, length(off))), off)
  e |>
    ec_base(ind$measure) |>
    ec_legend(type = "scroll", selected = hidden) |>
    e_grid(left = 10, right = 30, top = 50, bottom = 20, containLabel = TRUE) |>
    value_axis(ind$measure, from_zero = FALSE) |>
    e_x_axis(boundaryGap = FALSE, axisLabel = list(color = pal$slate_800))
}

# --- Sparkline --------------------------------------------------------------

sparkline <- function(id) {
  ind <- indicator(id)
  compare_data(id) |>
    dplyr::filter(breakdown == "Victoria", sex == "All") |>
    dplyr::mutate(period = as.character(period)) |>
    e_charts(period, height = "64px", width = "100%") |>
    e_line(value,
      symbol = "circle", symbolSize = 4, smooth = TRUE, smoothMonotone = "x",
      lineStyle = list(width = 2, color = pal$blue), itemStyle = list(color = pal$blue),
      areaStyle = list(color = "rgba(0,168,224,0.12)")
    ) |>
    e_x_axis(show = FALSE, boundaryGap = FALSE) |>
    e_y_axis(show = FALSE, scale = TRUE) |>
    e_grid(left = 4, right = 4, top = 6, bottom = 4) |>
    e_legend(show = FALSE) |>
    e_tooltip(trigger = "axis", valueFormatter = js_formatter(ind$measure),
              textStyle = list(fontFamily = font_family))
}

# --- Variation (ggplot2 + ggiraph) ------------------------------------------

gg_theme <- function() {
  theme_minimal(base_size = 12, base_family = "sans") +
    theme(
      text = element_text(colour = pal$slate_900),
      axis.text = element_text(colour = pal$slate_700),
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = pal$grey_200),
      legend.position = "top",
      legend.title = element_blank(),
      plot.title.position = "plot",
      plot.caption = element_text(colour = pal$slate_600, hjust = 0)
    )
}

# The page already loads Barlow, so tell ggiraph to use it without embedding
# its default font files (about 18 MB of Liberation fonts).
barlow_font_set <- function() {
  fs <- gdtools::font_set_liberation()
  fs$dsvg_fonts$sans <- "Barlow"
  fs$dependencies <- list()
  fs
}

girafe_opts <- function(p, height = 5) {
  girafe(
    ggobj = p, width_svg = 8, height_svg = height,
    font_set = barlow_font_set(),
    options = list(
      opts_hover(css = sprintf("fill:%s;stroke:%s;stroke-width:1.5px;", pal$yellow, pal$ink)),
      opts_hover_inv(css = "opacity:0.35;"),
      opts_tooltip(
        css = sprintf(
          "background:#fff;color:%s;border:1px solid %s;border-radius:6px;padding:8px 10px;font-family:Barlow,sans-serif;font-size:13px;box-shadow:0 4px 14px rgba(0,0,0,.08);",
          pal$slate_900, pal$grey_200
        ),
        use_fill = FALSE
      ),
      opts_selection(type = "none"),
      opts_toolbar(saveaspng = TRUE, pngname = "variation"),
      opts_sizing(rescale = TRUE)
    )
  )
}

#' Funnel plot: each LGA's rate against its eligible population, with 95% and
#' 99.8% control limits around the statewide rate. LGAs outside the 99.8%
#' limits differ by more than chance alone would explain.
chart_funnel <- function(id) {
  ind <- indicator(id)
  d <- compare_data(id)
  last_period <- dplyr::last(levels(d$period))
  p0 <- d |>
    dplyr::filter(breakdown == "Victoria", sex == "All", period == last_period) |>
    dplyr::pull(rate)
  lga <- d |>
    dplyr::filter(breakdown == "LGA", sex == "All", period == last_period) |>
    dplyr::mutate(
      se = sqrt(p0 * (1 - p0) / denominator),
      z = (rate - p0) / se,
      flag = dplyr::case_when(
        z > 3.09 ~ "Above 99.8% limit",
        z < -3.09 ~ "Below 99.8% limit",
        TRUE ~ "Within limits"
      ),
      tooltip = sprintf(
        "<b>%s</b><br>%s: %.1f%%<br>%s of %s<br>z = %.1f",
        category, ind$focus_area, 100 * rate,
        format(numerator, big.mark = ","), format(denominator, big.mark = ","), z
      )
    )

  n <- exp(seq(log(min(lga$denominator) * 0.8), log(max(lga$denominator) * 1.15), length.out = 200))
  limits <- tibble::tibble(
    n = n,
    se = sqrt(p0 * (1 - p0) / n),
    lo95 = p0 - 1.96 * se, hi95 = p0 + 1.96 * se,
    lo998 = p0 - 3.09 * se, hi998 = p0 + 3.09 * se
  )

  p <- ggplot(lga, aes(denominator, rate)) +
    geom_ribbon(data = limits, aes(n, ymin = lo998, ymax = hi998), inherit.aes = FALSE,
                fill = pal$blue_pale, alpha = 0.7) +
    geom_ribbon(data = limits, aes(n, ymin = lo95, ymax = hi95), inherit.aes = FALSE,
                fill = pal$blue_light, alpha = 0.25) +
    geom_hline(yintercept = p0, colour = pal$ink, linewidth = 0.6, linetype = "dashed") +
    geom_point_interactive(
      aes(fill = flag, tooltip = tooltip, data_id = category),
      shape = 21, size = 3.2, colour = "white", stroke = 0.4
    ) +
    scale_fill_manual(values = c(
      "Above 99.8% limit" = pal$blue_dark,
      "Within limits" = pal$slate_500,
      "Below 99.8% limit" = pal$red
    )) +
    scale_x_log10(labels = scales::label_comma()) +
    scale_y_continuous(labels = scales::label_percent(accuracy = 1)) +
    labs(
      x = "Denominator (log scale)", y = NULL,
      caption = sprintf("Each point is an LGA, %s. Shaded bands: 95%% and 99.8%% control limits around the Victorian rate (dashed).", last_period)
    ) +
    gg_theme()

  girafe_opts(p)
}

#' Dumbbell chart: each LPHU's count before COVID-19 (2019) against the
#' latest year, so recovery (or growth) is easy to compare across regions.
chart_dumbbell <- function(id) {
  ind <- indicator(id)
  d <- compare_data(id) |> dplyr::filter(breakdown == "LPHU", sex == "All")
  first <- if ("2019" %in% levels(d$period)) "2019" else levels(d$period)[1]
  last <- dplyr::last(levels(d$period))

  w <- d |>
    dplyr::filter(period %in% c(first, last)) |>
    dplyr::select(category, period, value) |>
    tidyr::pivot_wider(names_from = period, values_from = value) |>
    dplyr::rename(from = !!first, to = !!last) |>
    dplyr::mutate(
      change = to / from - 1,
      category = forcats_reorder(category, change),
      tooltip = sprintf("<b>%s</b><br>%s: %s<br>%s: %s<br>Change: %+.0f%%",
                        category, first, format(from, big.mark = ","),
                        last, format(to, big.mark = ","), 100 * change)
    )

  p <- ggplot(w, aes(y = category)) +
    geom_segment(aes(x = from, xend = to, yend = category), colour = pal$grey_200, linewidth = 3) +
    geom_point_interactive(aes(x = from, tooltip = tooltip, data_id = category, fill = first),
                           shape = 21, size = 4, colour = "white") +
    geom_point_interactive(aes(x = to, tooltip = tooltip, data_id = category, fill = last),
                           shape = 21, size = 4.5, colour = "white") +
    geom_text(aes(x = pmax(from, to), label = sprintf("%+.0f%%", 100 * change)),
              hjust = -0.4, size = 3.4, colour = pal$slate_700) +
    scale_fill_manual(values = stats::setNames(c(pal$slate_500, pal$blue), c(first, last))) +
    scale_x_continuous(labels = scales::label_comma(), expand = expansion(mult = c(0.05, 0.12))) +
    labs(x = ind$focus_area, y = NULL,
         caption = "Each row is a Local Public Health Unit. Labels show the change between the two years.") +
    gg_theme()

  girafe_opts(p, height = 4.6)
}

forcats_reorder <- function(x, by) factor(x, levels = unique(x[order(by)]))

chart_variation <- function(id) {
  switch(indicator(id)$variation, funnel = chart_funnel(id), dumbbell = chart_dumbbell(id))
}
