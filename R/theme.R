# Colours and number formats shared by every chart.
# The palette matches assets/acpcc.scss; change both together.

pal <- list(
  ink        = "#060709",
  slate_900  = "#2E3438",
  slate_800  = "#454E54",
  slate_700  = "#5B6770",
  slate_600  = "#73818C",
  slate_500  = "#8F9AA3",
  grey_200   = "#E3E6E8",
  blue       = "#00A8E0",
  blue_dark  = "#00698C",
  blue_mid   = "#5DBDE9",
  blue_light = "#76C6EC",
  blue_pale  = "#E0F7FF",
  yellow     = "#FFD457",
  yellow_dark = "#FFC824",
  cream      = "#FFFBF0",
  red        = "#D1495B"
)

# One colour per series wherever sex is shown.
sex_colours <- c(All = pal$blue, Female = pal$slate_800, Male = pal$yellow_dark)

# Sequential scale for maps: pale to dark blue.
map_colours <- c(pal$blue_pale, pal$blue_light, pal$blue, pal$blue_dark)

font_family <- "Barlow, system-ui, sans-serif"

fmt_value <- function(x, measure) {
  if (measure == "rate") paste0(formatC(x, format = "f", digits = 1), "%")
  else formatC(x, format = "d", big.mark = ",")
}

# The same formatter in JavaScript, for chart tooltips and axes.
js_formatter <- function(measure, digits = 1) {
  htmlwidgets::JS(if (measure == "rate") {
    sprintf("function(v) { return v == null ? '-' : Number(v).toFixed(%d) + '%%'; }", digits)
  } else {
    "function(v) { return v == null ? '-' : Number(v).toLocaleString('en-AU'); }"
  })
}
