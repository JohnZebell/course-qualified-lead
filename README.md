# Course Qualified Lead (CQL) Engine
 
Tell a course seller's closers exactly who to call and what to pitch them, using signals learned from the seller's own sales history instead of guesswork.
 
Built and tested on a Postgres sandbox. This is the method demonstrated on synthetic data.
 
## The problem
 
Course and info-product sellers spend heavily on ads to drive signups. Then their closers work down a list of everyone who opted in, most of whom grabbed a free lesson and vanished. Meanwhile the people who are actually bingeing the content right now, the ones with real buying intent, sit in the same undifferentiated list and get called days later or never.
 
The platform (Kajabi, Skool, Teachable, GoHighLevel memberships) already tracks all of it: who watched what, who downloaded what, who bought which upsell. Almost nobody connects that consumption data to the sales process. So closers guess, and the hot leads go cold.
 
## What this does
 
Two things, both learned from the seller's own data, not hardcoded:
 
1. **Who to call (hotness).** It learns which behaviors actually separated past buyers from non-buyers, then scores current leads on that. In the demo, completing lessons is a strong positive signal and downloads come out *negative*, because freebie-grabbers download and don't buy. That's the catch most people miss: download counts look like interest and aren't. A lead can be "active" and still be cold if their activity is the wrong kind.
2. **What to pitch (upsell match).** It learns which content each upsell's buyers consumed, then matches each hot lead to the upsell their own consumption most resembles. Someone deep in the resume content gets matched to career coaching; someone in the business content gets matched to the scaling program. Learned from what actually converted, not assigned by hand.
The output is one list a closer can work top to bottom: name, contact, how hot, and which upsell to lead with.
 
## Example output
 
| email | intent_score | priority | recommended_upsell | upsell_fit |
|---|---|---|---|---|
| active17 | 2.80 | HOT - call now | Portfolio Program | 2.00 |
| active32 | 2.80 | HOT - call now | Career Coaching | 2.00 |
| active46 | 0.70 | Warm | Career Coaching | 1.00 |
| active1 | -0.97 | Cold | (none) | |
 
The cold leads with no upsell recommendation are the freebie-grabbers, real activity, wrong kind, nothing worth a closer's time. The tool refuses to invent a recommendation where there's no signal, which is the difference between this and a tool that slaps a confidence score on everyone.
 
## What's in here
 
- `sql/01_seed.sql` — builds users and consumption events, with historical buyers (tagged by which upsell they bought) and non-buyers to learn from, plus current active leads to score. If active leads come back with no events on a single-batch run, re-run the last INSERT once.
- `sql/02_learn_and_score.sql` — the two-layer engine: learns behavior weights (hotness) and content-to-upsell signals (what to pitch), then scores and matches every active lead.
## How it deploys
 
The SQL is the decision engine. In production it runs on a schedule against the seller's consumption and sales data (pulled from their platform via API/webhooks into Postgres), and the output writes back to their CRM so closers get a live, ranked call list with the recommended upsell per lead. No AI needed for the decision, it's deterministic and learned from real outcomes, which makes it reliable and explainable.
 
## Honest scope
 
The synthetic data models clean patterns so the method is easy to see; real consumption is noisier and the signals blur. The score bands and the upsell-match thresholds are tunable to each seller's data. Two natural extensions: consumption *velocity* (a binge in a tight window is hotter than the same activity spread over months) and drop-off detection (a lead who was active then stalled on a specific lesson). The engine is only as good as the tracking feeding it, so confirming the seller's data is clean and complete is the first step before any of this routes a real lead. Which is a ten-minute check, not a leap of faith.
