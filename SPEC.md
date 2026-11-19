# ACPCC Git Training: Specification

Status: draft for review. Nothing below is implemented yet.

## 1. Purpose

A **1-hour** introduction to Git and GitHub for ACPCC analysts who work in R and SQL and have **no prior Git knowledge**. It is one hour of a 3-hour session and follows on from the earlier R content (Quarto, ggplot2, tidyverse).

One hour is enough for concepts, one demo and one hands-on loop, and no more. Setup (Git install, GitHub account, authentication) must happen **before** the session via a prerequisites email. The report site is a finished showcase that learners make small edits to; nobody builds it live.

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
| Typefaces | Original: DINPro (headings), D-DIN (body). Recreation: **Barlow** (Google Fonts), the closest free DIN-style match |

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
├── assets/                   # SCSS theme, carousel JS
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
- Custom SCSS theme mapped to the tokens in §3, with Barlow loaded from Google Fonts.
- Header with wordmark and "Return to main site" link (to acpcc.org.au); sidebar navigation matching the original order.
- Summary page: hero text and a key-figures carousel. The carousel uses Bootstrap 5's built-in carousel, which ships with Quarto, so it needs no Swiper dependency. It has 9 cards with "Insight n of 9" and next/previous controls, followed by three program cards.
- Focus area layout: two columns (key insight + interpretation | chart panel). Technical notes sit in a collapsible callout, with the download link styled like the original's link-button.
- A footer with copyright and the synthetic-data notice.
- Mobile behaviour: responsive layout, plus the original's "best viewed on desktop" notice as a dismissible banner.

## 6. Session plan (60 minutes)

| Time | Segment | Format |
|---|---|---|
| 0–5 | Why version control: `report_final_v3_REAL.qmd`, "who changed this query?", reproducible published statistics | Slides |
| 5–15 | Mental model (repo, working directory, staging, commit, branch, remote, PR) and what belongs in Git for data work | Slides |
| 15–25 | **Live demo** of the full loop on this repo: clone, branch, change a chart colour, diff, commit, push, PR, CI check goes green, merge, Pages updates | Instructor in RStudio; Positron equivalents on slides |
| 25–45 | **Hands-on**: Exercise 1, with Exercise 2 as a stretch goal | Learners |
| 45–52 | Merge conflict: instructor resolves a pre-staged conflict live | Demo |
| 52–57 | Undoing things, renv and containers, and how the CI workflow publishes the site (brief) | Slides |
| 57–60 | Cheat sheet, where to go next, Q&A | Slides |

## 7. Slide deck: Git foundations for analysts

Quarto → Beamer, about 25 core slides plus a reference appendix for self-study after the session. A custom colour theme uses the §3 tokens. IDE steps are two-column **RStudio | Positron** slides, with the command-line equivalent in a footnote-style strip.

**Core (presented):**
1. Why version control
2. Mental model: snapshots, staging area, history. A commit is a snapshot with a message
3. What belongs in Git for data work:
   - Commit: code, `.qmd`, `.sql`, `renv.lock`
   - Don't commit: rendered outputs, data extracts, credentials, `.Renviron`
   - This repo's `.gitignore` as the example
   - Identifiable data: history is public and hard to scrub, so check before you commit
4. The daily loop in each IDE:
   - **RStudio**: Git pane, Diff, Commit, Push
   - **Positron**: Source Control view, stage, commit, Sync
5. Branches and pull requests: why work never happens on `main`, and what branch protection does
6. Merge conflicts: the markers in a `.qmd` file and resolving them in each IDE
7. Good commits: small, focused, a message that says why
8. CI/CD in one slide: this repo's workflow, annotated
9. Cheat sheet: command / RStudio / Positron equivalence table

**Appendix (not presented; linked from the site):**
- Setup and authentication in detail
- Undoing things: discard, amend, revert, restore a deleted file, and when not to rewrite history
- renv and pinned containers
- The full workflow file explained line by line

## 8. Exercises

Each exercise is a page under `exercises/` and on the site, with numbered steps for RStudio, Positron and the command line.

| # | Exercise | When |
|---|---|---|
| 0 | Setup check: Git installed, identity set, GitHub auth, accepted collaborator invite, cloned the repo, `renv::restore()`, rendered locally | **Before the session** (prerequisites email) |
| 1 | Branch `<yourname>/hello` → add `exercises/attendees/<yourname>.qmd` → commit → push → open a PR | In session |
| 2 | On a new branch, change a chart in `R/` (colour, label or reference line) → PR → watch the CI check | In session (stretch) |
| 3 | Edit a SQL query and read the diff | Take-home |
| 4 | Commit a fake `data/extract.csv`, then remove it and add it to `.gitignore` | Take-home |
| 5 | Revert a merged change | Take-home |

Each learner adds their **own** file for Exercise 1, and a Quarto listing page collects them. That way 20 PRs merge cleanly, and conflicts only appear in the controlled demo. The instructor merges PRs during the session. Pages redeploys after each merge (`cancel-in-progress` keeps this quick).

The conflict demo uses two pre-staged branches that edit the same Key insight line, so it doesn't depend on learners.

## 9. CI/CD pipeline (`.github/workflows/publish.yml`)

```yaml
on:
  push:            # every branch gets a check; only main deploys
  workflow_dispatch:
permissions: { contents: read, pages: write, id-token: write }
concurrency: { group: pages, cancel-in-progress: true }   # PRs use a per-ref group
jobs:
  build:
    runs-on: ubuntu-latest
    container: rocker/verse:<latest R>   # exact tag pinned at implementation
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

## 10. Tasks

| ID | Task | Depends on |
|---|---|---|
| T1 | Repo scaffold: `_quarto.yml`, `.gitignore`, `.Rproj`, Positron settings, renv init, README | n/a |
| T2 | Geography: ABS LGA/PHN/LPHU boundaries → simplified GeoJSON + licence note | T1 |
| T3 | Synthetic data generator + DuckDB + SQL queries | T1, T2 |
| T4 | Theme: SCSS, Barlow, header/sidebar/footer, synthetic-data banner | T1 |
| T5 | Chart builders in `R/` (compare, map, trend, funnel, dumbbell, sparkline) | T3, T4 |
| T6 | Report pages: Summary + carousel, Foreword, 3 program pages, Instructions | T5 |
| T7 | Beamer theme + slide deck content | T4 |
| T8 | Exercises + cheat sheet | T6, T7 |
| T9 | GitHub Actions workflow; verify on real runner + Pages publish | T6, T7 |
| T10 | Facilitator notes: §6 run sheet, prerequisites email (Exercise 0, send a week ahead), pre-staged conflict branches, common failure fixes | T8, T9 |

## 11. Resolved questions

1. **Session length:** 1 hour within a 3-hour session (see §6).
2. **R version:** latest release, used in both `renv.lock` and the pinned `rocker/verse` tag.
3. **Fonts:** Barlow from Google Fonts.
4. **IDE versions:** latest RStudio and Positron releases at implementation time; menu names are written against those.
