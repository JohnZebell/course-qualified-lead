-- ============================================================
-- Course Qualified Lead (CQL) Engine - Learn, score, and match
-- ============================================================
-- Two layers, both learned from the seller's own history:
--
-- LAYER 1 (hotness): which behaviors separated buyers from non-buyers?
--   Learns a weight per behavior. In the demo, lesson_complete comes out
--   strongly positive, download comes out NEGATIVE -- freebie-grabbers
--   download and don't buy, so a download is not intent. That's the
--   "distrust the surface metric" catch: download counts look like
--   interest and aren't.
--
-- LAYER 2 (upsell match): which content did each upsell's buyers consume?
--   Learns which content points to which upsell, then matches each active
--   user to the upsell their consumption most resembles.
--
-- Output: for each active lead -> how hot they are (who to call first)
-- AND which upsell to pitch (what to sell them). Learned, not hardcoded.
-- ============================================================

WITH
historical AS (
    SELECT u.outcome, e.event_type, u.id AS user_id
    FROM users u JOIN consumption_events e ON e.user_id = u.id
    WHERE u.outcome IN ('bought','no_buy')
),
weights AS (
    SELECT event_type,
        ROUND(
          (COUNT(DISTINCT user_id) FILTER (WHERE outcome='bought')::numeric
            / NULLIF((SELECT COUNT(*) FROM users WHERE outcome='bought'),0))
        - (COUNT(DISTINCT user_id) FILTER (WHERE outcome='no_buy')::numeric
            / NULLIF((SELECT COUNT(*) FROM users WHERE outcome='no_buy'),0))
        , 3) AS weight
    FROM historical GROUP BY event_type
),
hotness AS (
    SELECT u.id, ROUND(SUM(w.weight),3) AS intent_score
    FROM users u
    JOIN consumption_events e ON e.user_id = u.id
    JOIN weights w ON w.event_type = e.event_type
    WHERE u.outcome='active'
    GROUP BY u.id
),
upsell_content AS (
    SELECT u.upsell, e.content, COUNT(*) AS completes
    FROM users u JOIN consumption_events e ON e.user_id=u.id
    WHERE u.outcome='bought' AND e.event_type='lesson_complete'
    GROUP BY u.upsell, e.content
),
content_to_upsell AS (
    SELECT content, upsell,
           ROUND(completes::numeric / SUM(completes) OVER (PARTITION BY content),2) AS share
    FROM upsell_content
),
active_content AS (
    SELECT u.id, e.content, COUNT(*) AS completes
    FROM users u JOIN consumption_events e ON e.user_id=u.id
    WHERE u.outcome='active' AND e.event_type='lesson_complete'
    GROUP BY u.id, e.content
),
active_upsell_scores AS (
    SELECT ac.id, cu.upsell, ROUND(SUM(ac.completes*cu.share),2) AS upsell_fit
    FROM active_content ac JOIN content_to_upsell cu ON cu.content=ac.content
    GROUP BY ac.id, cu.upsell
),
best_upsell AS (
    SELECT DISTINCT ON (id) id, upsell AS recommended_upsell, upsell_fit
    FROM active_upsell_scores ORDER BY id, upsell_fit DESC
)
SELECT
    u.email, u.phone,
    h.intent_score,
    CASE
        WHEN h.intent_score >= 1.0 THEN 'HOT - call now'
        WHEN h.intent_score >= 0.4 THEN 'Warm'
        WHEN h.intent_score >= 0   THEN 'Nurture'
        ELSE 'Cold'
    END AS priority,
    b.recommended_upsell,
    b.upsell_fit
FROM users u
JOIN hotness h ON h.id = u.id
LEFT JOIN best_upsell b ON b.id = u.id
WHERE u.outcome='active'
ORDER BY h.intent_score DESC;
