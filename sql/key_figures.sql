-- Statewide result for the most recent period of every indicator.
-- Feeds the "Key figures" carousel and the key insight cards.
WITH latest AS (
  SELECT indicator_id, max(end_year) AS end_year
  FROM screening
  GROUP BY indicator_id
)
SELECT
  i.sort_order,
  i.indicator_id,
  i.program,
  i.focus_area,
  i.measure,
  i.headline,
  i.variation,
  s.period,
  sum(s.numerator)   AS numerator,
  sum(s.denominator) AS denominator,
  sum(s.numerator) / sum(s.denominator) AS rate
FROM screening AS s
JOIN latest    USING (indicator_id, end_year)
JOIN indicator AS i USING (indicator_id)
GROUP BY ALL
ORDER BY i.sort_order;
