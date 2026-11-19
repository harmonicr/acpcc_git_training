-- The detailed table offered as an Excel download on each focus area.
-- Parameter ?: the indicator_id.
SELECT
  s.period          AS "Time period",
  l.lga_name        AS "LGA",
  l.phn             AS "PHN",
  l.lphu            AS "LPHU",
  s.age_group       AS "Age group",
  s.sex             AS "Sex",
  s.numerator       AS "Numerator",
  s.denominator     AS "Denominator",
  round(100 * s.numerator / s.denominator, 1) AS "Rate (%)"
FROM screening AS s
JOIN lga       AS l USING (lga_code)
WHERE s.indicator_id = ?
ORDER BY s.end_year DESC, l.lga_name, s.age_group, s.sex;
