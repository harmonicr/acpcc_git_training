# ACPCC Git Training: Specification

Status: draft for review. Nothing below is implemented yet.

## 1. Purpose

A one-day introduction to Git and GitHub for ACPCC analysts who work in R and SQL and have **no prior Git knowledge**. It follows on from the earlier R session (Quarto, ggplot2, tidyverse).

The repository is both the teaching material and the worked example:

1. **Slide deck** (Quarto → Beamer PDF): Git concepts plus step-by-step usage in RStudio and Positron.
2. **Report site** (Quarto website): a recreation of <https://report.acpcc.org.au/> built on synthetic data, with interactive charts.
3. **GitHub Actions pipeline**: renders both on every PR and publishes to GitHub Pages on push to `main`.
4. **Hands-on exercises**: learners (added as collaborators) branch, edit the report, open PRs, and watch CI publish their change.

## 2. Constraints and decisions

| Topic | Decision |
|---|---|
| Audience | No Git knowledge. Familiar with R, Quarto, ggplot2, tidyverse, some SQL |
| Data | **Synthetic only.** Every page carries a visible "Training demo, synthetic data" banner so no figure can be mistaken for real ACPCC data |
| Repo | `harmonicr/acpcc_git_training`, public, GitHub Pages on the free plan |
| Learners | Added as collaborators; they branch in the shared repo, no forks |
| Charts | Interactive and as close to the original as possible (see §5) |
| IDE coverage | RStudio and Positron, written as equivalent text instructions; no screenshots |
| Branding | Recreate layout, colours and typography. **Do not copy ACPCC or Victorian Government logos**; use a text wordmark placeholder instead |
| Geography | Real public boundaries (ABS ASGS, CC BY 4.0) with synthetic values |

## 3. Reference site analysis

What the live site uses, taken from its HTML, CSS and embedded chart configs on 2026-11-20:

**Platform.** A .NET CMS front end with a client-side data API (`/dataapi/CompareCharts|MapCharts|TrendCharts/...`). Charts are **Apache ECharts**; the key-figures carousel is **Swiper**.

**Pages.**

| Page | Focus areas (tabs) |
|---|---|
| Summary | Intro text, "Key figures" carousel (9 insight cards), three program cards linking to detail pages |
| Foreword | Prose |
| Bowel Cancer | Participation · Screening numbers · Time to colonoscopy |
| Breast Cancer | Participation · Screening numbers |
| Cervical Cancer | Coverage · Screening numbers · Self-collection · Time to colposcopy |
| Instructions | How to use the charts |

**Each focus area contains:**
- Key insight card (big number + caption), interpretation text, and indicator mini-cards
- Technical notes (long numbered methodology list)
- `.xlsx` data table download
- Chart panel with three views (**Compare**, **Map** and **Trend**) and controls:
  - *Data for:* Time period (e.g. 2016-2017 … 2023-2024)
  - *Compare by:* Age group · Sex (bowel only) · LPHU · PHN · LGA
  - *Include:* Sex filter (All / Female / Male), hidden when comparing by sex

**Design tokens:**

| Role | Value |
|---|---|
| Ink | `#060709` |
| Slate scale | `#2E3438` `#454E54` `#5B6770` `#73818C` `#8F9AA3` |
| Light grey | `#E3E6E8` |
| Accent blue | `#00A8E0` `#5DBDE9` `#76C6EC`, pale `#E0F7FF` |
| Accent yellow | `#FFD457` `#FFC824`, cream `#FFFBF0` |
| Typefaces | DINPro (headings) and D-DIN (body). D-DIN is OFL-licensed and can be self-hosted; DINPro is commercial, so headings fall back to D-DIN Bold |

## 4. Repository layout

```
acpcc_git_training/
├── _quarto.yml               # website project; slides render into _site/ too
├── index.qmd                 # Summary
├── foreword.qmd
├── bowel-cancer.qmd
├── breast-cancer.qmd
├── cervical-cancer.qmd
├── instructions.qmd
├── slides/
│   └── git-foundations.qmd   # format: beamer → _site/slides/git-foundations.pdf
├── exercises/                # lab sheets (also published on the site)
├── R/                        # chart builders, theme, helpers (sourced, not a package)
├── sql/                      # one .sql per indicator, run against DuckDB
├── data-raw/
│   ├── make-synthetic.R      # seeded generator → data/screening.duckdb
│   └── make-geo.R            # one-off: ABS boundaries → simplified GeoJSON
├── data/geo/                 # committed simplified GeoJSON (LGA, PHN, LPHU) + LICENCE note
├── assets/                   # SCSS theme, fonts, carousel JS
├── renv.lock
├── .gitignore
└── .github/workflows/publish.yml
```

**Deliberate teaching choices:**
- The DuckDB file and rendered `_site/` are **not committed**. CI regenerates them from code, which illustrates "commit code, not outputs".
- The simplified GeoJSON **is** committed. It is small, external and slow to fetch, which gives the "when is it OK to commit data" discussion a concrete case.

## 5. Report site

### 5.1 Data pipeline
1. `make-synthetic.R` (seeded) builds tables for each program × indicator × period × age group × sex × LGA. Values are shaped to be plausible: realistic age gradients, a dip in 2020-2022 for COVID-19, metro vs regional differences, and a rising trend in self-collection. Eligible-population denominators come from synthetic LGA populations.
2. Data is written to DuckDB. Each indicator has a `sql/*.sql` query, so SQL is used for real, not as decoration.
3. R reads the query results via `DBI`/`duckdb` and shapes them for charts with dplyr/tidyr.
4. `writexl` writes each focus area's data table to `.xlsx` for the download link.

### 5.2 Interactive graphics

The primary library is **echarts4r**, an R wrapper for the same ECharts library the real site uses, so the look and feel match closely.

| Original view | Recreation |
|---|---|
| Compare | Horizontal bar charts for the selected breakdown, with tooltips showing the numerator, denominator and rate. A statewide reference line. An ECharts `timeline` steps through time periods with animated transitions |
| Map | Choropleth of LGA, PHN or LPHU from the committed GeoJSON (`e_map_register`), a sequential blue scale from the design tokens, a hover tooltip, and a timeline over periods |
| Trend | Multi-series line chart with a toggleable legend (sex, age groups), a shaded band over the COVID-19 period, and data zoom |
| Compare by / Sex filter | Nested Quarto `panel-tabset` for *Compare by*; sex handled by ECharts legend toggles. No server needed, so the site stays static |

**Extras beyond the original** (advanced R graphics, showcase-quality):
- A **funnel plot** of LGA participation vs eligible population with 95%/99.8% control limits, built with ggplot2 + ggiraph. It is the standard screening-epidemiology view for spotting genuine outliers versus small-number noise. Hover shows the LGA; clicking an LGA highlights it in a linked table.
- A **dumbbell chart** comparing pre- and post-COVID participation by PHN.
- **Sparklines** in indicator mini-cards (via echarts4r).

Every chart builder lives in `R/` as a function, e.g. `chart_compare(data, by = "age_group")`. Each one is small enough to edit in an exercise, such as changing a colour, a label or a reference line.

### 5.3 Layout and styling
- Custom SCSS theme mapped to the tokens in §3, with D-DIN self-hosted.
- Header with wordmark and "Return to main site" link (to acpcc.org.au); sidebar navigation matching the original order.
- Summary page: hero text and a key-figures carousel. The carousel uses Bootstrap 5's built-in carousel, which ships with Quarto, so it needs no Swiper dependency. It has 9 cards with "Insight n of 9" and next/previous controls, followed by three program cards.
- Focus area layout: two columns (key insight + interpretation | chart panel). Technical notes sit in a collapsible callout, with the download link styled like the original's link-button.
- A footer with copyright and the synthetic-data notice.
- Mobile behaviour: responsive layout, plus the original's "best viewed on desktop" notice as a dismissible banner.

## 6. Slide deck: Git foundations for analysts

Built from Quarto into Beamer, with a custom colour theme from the same tokens. Code is shown in `--` shell blocks; IDE steps are shown as side-by-side **RStudio | Positron** two-column slides.

1. **Why version control.** `report_final_v3_REAL.qmd`, lost work, "who changed this query?", and reproducibility for published statistics.
2. **Mental model.** Repository, working directory, staging area, commit, history. A commit is a snapshot with a message.
3. **Setup.** Install Git; configure `user.name`/`user.email`; GitHub account; authentication with a PAT via `gitcreds` / `usethis::create_github_token()` (RStudio) or GitHub sign-in (Positron).
4. **First steps.**
   - Clone this repo: RStudio's *New Project → Version Control*, or Positron's *Clone Git Repository*.
   - Status, diff, stage, commit.
   - The RStudio Git pane vs Positron's Source Control view, side by side.
5. **What belongs in Git for data work.**
   - Commit: code, `.qmd`, `.sql`, `renv.lock`.
   - Don't commit: rendered outputs, data extracts, credentials, `.Renviron`.
   - `.gitignore` walkthrough using this repo's file.
   - Spotting identifiable data before it is committed; what to do if it happens (history is public).
6. **Good commits.** Small and focused, a message that says why, reading diffs of `.qmd` and `.sql` files.
7. **Branches.** Why work never happens on `main`; creating and switching branches in each IDE.
8. **GitHub collaboration.** Push, open a pull request, review, request changes, merge. Branch protection on `main`.
9. **Merge conflicts.** What they look like in a `.qmd` file and how to resolve them in each IDE.
10. **Undoing things.** Discard changes, amend, revert, restoring a deleted file. When *not* to rewrite history.
11. **Reproducibility.** renv, pinned containers, "works on my machine".
12. **CI/CD.** What GitHub Actions does, reading this repo's workflow line by line, and how this site gets published.
13. **Cheat sheet.** Command / RStudio / Positron equivalence table (also in `exercises/`).

## 7. Exercises

Each exercise is a page under `exercises/` and on the site, with numbered steps for RStudio, Positron and the command line.

| # | Exercise | Teaches |
|---|---|---|
| 0 | Setup check: Git installed, identity set, GitHub auth, clone, `renv::restore()`, render locally | Setup |
| 1 | Edit your name into `exercises/attendees.qmd` on a branch `<yourname>/hello` → commit → push → PR | Core loop |
| 2 | Change a chart (colour, reference line or label in `R/`) → PR → watch the CI check → merge after review → see Pages update | CI/CD |
| 3 | Edit a SQL query (e.g. change an age band) and read the diff | Diffs of code vs data |
| 4 | Scripted merge conflict: pairs edit the same Key insight line | Conflict resolution |
| 5 | "Oops": commit a fake `data/extract.csv`, then remove it and add it to `.gitignore` | Hygiene, `.gitignore` |
| 6 | Revert a merged change | Undoing safely |

## 8. CI/CD pipeline (`.github/workflows/publish.yml`)

```yaml
on:
  push: { branches: [main] }
  pull_request:
  workflow_dispatch:
permissions: { contents: read, pages: write, id-token: write }
concurrency: { group: pages, cancel-in-progress: true }   # PRs use a per-ref group
jobs:
  build:
    runs-on: ubuntu-latest
    container: rocker/verse:4.5.x        # pinned exact tag at implementation
    steps:
      - checkout
      - cache renv library (key: hash of renv.lock)
      - Rscript -e 'renv::restore()'      # binaries from Posit Package Manager
      - tlmgr install <explicit beamer/font package list>
      - Rscript data-raw/make-synthetic.R
      - quarto render
      - upload-pages-artifact (main only)   # PRs upload _site as a downloadable artifact instead
  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    environment: github-pages
    steps: [deploy-pages]
```

**Why `rocker/verse`:** it ships R, tidyverse, TinyTeX, pandoc and Quarto in one image, so the free runner only adds echarts4r, ggiraph, duckdb, writexl and their dependencies.

**Things to verify during implementation:**
- Is Quarto in the pinned image recent enough? If not, add `quarto-dev/quarto-actions/setup`.
- PPM binary URL matches the image's Ubuntu release.
- No `sf`/GDAL needed in CI. Geography is pre-simplified GeoJSON, which echarts4r reads as JSON, so the larger `rocker/geospatial` image isn't needed.
- Beamer LaTeX packages installed explicitly, not left to auto-install on first render (that's flaky in CI).
- `git config --global --add safe.directory` for the container checkout.
- Target time: under 5 min warm cache, under 10 min cold.

**Manual GitHub settings** (done in the web UI by you; I can't run `gh` here):
- Settings → Pages → Source: **GitHub Actions**
- Branch protection on `main`: require a PR, require the `build` check
- Add learners as collaborators (Write role)

## 9. Tasks

| ID | Task | Depends on |
|---|---|---|
| T1 | Repo scaffold: `_quarto.yml`, `.gitignore`, `.Rproj`, Positron settings, renv init, README | n/a |
| T2 | Geography: ABS LGA/PHN/LPHU boundaries → simplified GeoJSON + licence note | T1 |
| T3 | Synthetic data generator + DuckDB + SQL queries | T1, T2 |
| T4 | Theme: SCSS, fonts, header/sidebar/footer, synthetic-data banner | T1 |
| T5 | Chart builders in `R/` (compare, map, trend, funnel, dumbbell, sparkline) | T3, T4 |
| T6 | Report pages: Summary + carousel, Foreword, 3 program pages, Instructions | T5 |
| T7 | Beamer theme + slide deck content | T4 |
| T8 | Exercises + cheat sheet | T6, T7 |
| T9 | GitHub Actions workflow; verify on real runner + Pages publish | T6, T7 |
| T10 | Facilitator notes: run sheet, timings, prerequisites email, common failure fixes | T8, T9 |

## 10. Open questions

1. **Session length.** This spec assumes one full day. If it's a half day, cut exercises 3, 5 and 6 and deck sections 10 and 11.
2. **R version for learners.** Pin to the version on ACPCC machines if known; otherwise 4.5.
3. **Fonts.** OK to self-host D-DIN (OFL), or prefer a Google Fonts near-match (Barlow) for simplicity?
4. **Positron/RStudio versions** on learner machines, so menu names in the instructions match.
