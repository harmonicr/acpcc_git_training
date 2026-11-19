# Boundary sources

Built by `data-raw/make-geo.sh`. Boundaries are real; every value mapped onto them in this repo is synthetic.

| File | Source | Licence |
|---|---|---|
| `lga.geojson` | Australian Bureau of Statistics, ASGS Edition 3, Local Government Areas 2024 (79 Victorian LGAs, simplified) | CC BY 4.0 |
| `phn.geojson` | LGAs dissolved by Primary Health Network. PHN membership taken from Department of Health, *PHN Boundaries used by the NBRA* (May 2017 V7, data.gov.au), using each LGA's interior point | CC BY 2.5 AU |
| `lphu.geojson` | LGAs dissolved by Local Public Health Unit, using `data-raw/lga_lphu.csv` transcribed from health.vic.gov.au/local-public-health-units | CC BY 4.0 |

Simplifications: LGAs split between PHNs (e.g. Macedon Ranges) are assigned whole to one PHN, and the Melbourne Airport carve-out between the North Eastern and Western LPHUs is ignored.
