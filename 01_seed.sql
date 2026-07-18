-- ============================================================
-- Course Qualified Lead (CQL) Engine - Sandbox Seed
-- ============================================================
-- Synthetic data modeling a course seller with an evergreen library.
-- NOT real data. Demonstrates the method on Postgres.
--
--   users              - people who signed up. Historical ones have a
--                        known outcome (bought / no_buy) and, if they
--                        bought, WHICH upsell. 'active' = current leads.
--   consumption_events - one row per content action (lesson_complete,
--                        download), tagged with which content.
--
-- The data is shaped so real patterns exist to find:
--   - buyers actually complete lessons; non-buyers mostly grab freebie
--     downloads and bounce (so downloads look like intent but aren't)
--   - buyers of each upsell consumed the content that leads to it
--     (resume content -> Career Coaching, business -> Scaling Mastermind,
--      investing -> Portfolio Program)
-- Which behaviors and which content matter is DISCOVERED by the queries,
-- not hardcoded.
-- ============================================================

DROP TABLE IF EXISTS consumption_events;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    id         SERIAL PRIMARY KEY,
    email      TEXT,
    phone      TEXT,
    outcome    TEXT,        -- 'bought' / 'no_buy' / 'active'
    upsell     TEXT,        -- which upsell a buyer bought (else NULL)
    signed_up  TIMESTAMP
);

CREATE TABLE consumption_events (
    id          SERIAL PRIMARY KEY,
    user_id     INT,
    content     TEXT,
    event_type  TEXT,       -- 'lesson_complete', 'download'
    occurred_at TIMESTAMP
);

-- Historical buyers, grouped by the upsell they bought
INSERT INTO users (email, phone, outcome, upsell, signed_up)
SELECT 'career'||g||'@ex.com', '555-01'||LPAD(g::text,4,'0'), 'bought', 'Career Coaching',
       NOW()-((random()*120)||' days')::interval FROM generate_series(1,45) g;
INSERT INTO users (email, phone, outcome, upsell, signed_up)
SELECT 'biz'||g||'@ex.com', '555-02'||LPAD(g::text,4,'0'), 'bought', 'Scaling Mastermind',
       NOW()-((random()*120)||' days')::interval FROM generate_series(1,45) g;
INSERT INTO users (email, phone, outcome, upsell, signed_up)
SELECT 'invest'||g||'@ex.com', '555-03'||LPAD(g::text,4,'0'), 'bought', 'Portfolio Program',
       NOW()-((random()*120)||' days')::interval FROM generate_series(1,40) g;
INSERT INTO users (email, phone, outcome, upsell, signed_up)
SELECT 'nobuy'||g||'@ex.com', '555-04'||LPAD(g::text,4,'0'), 'no_buy', NULL,
       NOW()-((random()*120)||' days')::interval FROM generate_series(1,170) g;

-- Buyers consume the content matching their upsell
INSERT INTO consumption_events (user_id, content, event_type, occurred_at)
SELECT u.id, (ARRAY['resume_basics','resume_advanced','interview_prep'])[1+floor(random()*3)],
       'lesson_complete', NOW()-((random()*20)||' days')::interval
FROM users u, generate_series(1,5) WHERE u.upsell='Career Coaching' AND random()<0.7;
INSERT INTO consumption_events (user_id, content, event_type, occurred_at)
SELECT u.id, (ARRAY['business_start','business_scale','marketing_101'])[1+floor(random()*3)],
       'lesson_complete', NOW()-((random()*20)||' days')::interval
FROM users u, generate_series(1,5) WHERE u.upsell='Scaling Mastermind' AND random()<0.7;
INSERT INTO consumption_events (user_id, content, event_type, occurred_at)
SELECT u.id, (ARRAY['invest_basics','invest_stocks','invest_realestate'])[1+floor(random()*3)],
       'lesson_complete', NOW()-((random()*20)||' days')::interval
FROM users u, generate_series(1,5) WHERE u.upsell='Portfolio Program' AND random()<0.7;

-- Non-buyers: freebie downloads across everything + a little light watching
INSERT INTO consumption_events (user_id, content, event_type, occurred_at)
SELECT u.id, (ARRAY['resume_basics','business_start','invest_basics'])[1+floor(random()*3)],
       'download', NOW()-((random()*20)||' days')::interval
FROM users u, generate_series(1,3) WHERE u.outcome='no_buy' AND random()<0.6;
INSERT INTO consumption_events (user_id, content, event_type, occurred_at)
SELECT u.id, (ARRAY['resume_basics','business_start','invest_basics'])[1+floor(random()*3)],
       'lesson_complete', NOW()-((random()*20)||' days')::interval
FROM users u, generate_series(1,1) WHERE u.outcome='no_buy' AND random()<0.3;

-- Active users (current) to score
INSERT INTO users (email, phone, outcome, upsell, signed_up)
SELECT 'active'||g||'@ex.com', '555-09'||LPAD(g::text,4,'0'), 'active', NULL,
       NOW()-((random()*10)||' days')::interval FROM generate_series(1,50) g;

-- Active consumption (varied). If active users come back with no events on a
-- single-batch run, re-run this INSERT once.
INSERT INTO consumption_events (user_id, content, event_type, occurred_at)
SELECT u.id,
   (ARRAY['resume_basics','resume_advanced','business_start','business_scale','invest_basics','invest_stocks'])[1+floor(random()*6)],
   CASE WHEN random()<0.6 THEN 'lesson_complete' ELSE 'download' END,
   NOW()-((random()*7)||' days')::interval
FROM users u, generate_series(1,4) WHERE u.outcome='active' AND random()<0.7;
