-- Every breakdown the charts need for one indicator, in one pass.
--
-- GROUPING SETS runs several GROUP BYs at once: statewide, by age group,
-- LPHU, PHN and LGA, each for all sexes combined and for each sex.
-- Columns left out of a grouping set come back as NULL, which the CASE
-- and COALESCE turn into readable labels.
--
-- Parameter ?: the indicator_id, e.g. 'bowel_participation'.
SELECT
  s.period,
  s.end_year,
  CASE
    WHEN grouping(s.age_group) = 0 THEN 'Age group'
    WHEN grouping(l.lphu)      = 0 THEN 'LPHU'
    WHEN grouping(l.phn)       = 0 THEN 'PHN'
    WHEN grouping(l.lga_name)  = 0 THEN 'LGA'
    ELSE 'Victoria'
  END AS breakdown,
  coalesce(s.age_group, l.lphu, l.phn, l.lga_name, 'Victoria') AS category,
  l.lga_code,
  coalesce(s.sex, 'All') AS sex,
  sum(s.numerator)   AS numerator,
  sum(s.denominator) AS denominator,
  sum(s.numerator) / sum(s.denominator) AS rate
FROM screening AS s
JOIN lga       AS l USING (lga_code)
WHERE s.indicator_id = ?
GROUP BY GROUPING SETS (
  (s.period, s.end_year),
  (s.period, s.end_year, s.sex),
  (s.period, s.end_year, s.age_group),
  (s.period, s.end_year, s.age_group, s.sex),
  (s.period, s.end_year, l.lphu),
  (s.period, s.end_year, l.lphu, s.sex),
  (s.period, s.end_year, l.phn),
  (s.period, s.end_year, l.phn, s.sex),
  (s.period, s.end_year, l.lga_code, l.lga_name),
  (s.period, s.end_year, l.lga_code, l.lga_name, s.sex)
)
ORDER BY breakdown, category, sex, s.end_year;
