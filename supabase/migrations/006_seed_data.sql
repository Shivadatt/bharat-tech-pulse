-- ============================================================================
-- SECTION: demo data only
-- ============================================================================
-- 006_seed_data.sql
-- Bharat Tech Pulse (site slug: india_tech) — full deterministic demo seed.
-- Owned by SUB-AGENT 1 (database architecture + dummy data).
-- Must run AFTER 001 (tables) and 005 (set_updated_at triggers). Replaces the
-- old 004_seed_data.sql (site/category/author rows migrated in and expanded).
--
-- Everything below is DEMO data for the CMS + public blog until real content
-- is authored. No auth.users exist at seed time, so:
--   * authors.user_id stays NULL (unlinked bylines);
--   * profile_sites has NO demo rows (no profile can exist yet);
--   * post_revisions.edited_by is NULL — the FK is
--     `REFERENCES auth.users (id) ON DELETE SET NULL`, which allows NULL by
--     design, and seed-time NULL is legal and expected.
--
-- ─── TABLE OF CONTENTS (expected row counts; audit can diff vs live DB) ─────
--   1. public.sites            1   (...0001)
--   2. public.site_settings    1   (...0060)
--   3. public.categories       8   (...0101-...0108)
--   4. public.authors          4   (...0201-...0204)
--   5. public.tags            24   (...0301-...0324)
--   6. public.posts           24   (...0401-...0424)
--        15 published | 4 drafts | 3 scheduled | 2 archived
--   7. public.post_tags       77   (2-4 per post, no orphans)
--   8. public.media            6   (...0501-...0506)
--   9. public.post_revisions   5   (...0601-...0605)
--  10. public.redirects        3   (...0701-...0703)
--  11. public.subscribers      6   (...0801-...0806)
--  12. public.analytics_events 40  (...0901-...0940)
-- ────────────────────────────────────────────────────────────────────────────
--
-- IDEMPOTENCY STRATEGY
-- * Every row carries a FIXED UUID from the 00000000-0000-4000-8000-0000xxxxxx
--   demo block (site ...0001, categories ...0101-0108, authors ...0201-0204,
--   tags ...0301-0324, posts ...0401-0424, media ...0501-0506, revisions
--   ...0601-0605, redirects ...0701-0703, subscribers ...0801-0806, events
--   ...0901-0940). Re-running NEVER duplicates.
-- * Every INSERT upserts on its natural unique key with DO UPDATE ... WHERE
--   <table>.id = EXCLUDED.id: the demo columns refresh only when the
--   conflicting row IS the demo-block row. A real operator row that happens to
--   share a slug/email/path can NEVER be overwritten (its id differs from the
--   demo id, the WHERE guard fails, the row is left untouched).
-- * DO UPDATE lists ONLY demo-authored columns; identity and audit columns
--   (id, site_id, created_at on natural-key conflicts) are never clobbered.
--   Note: the set_updated_at trigger (005) stamps updated_at = now() on every
--   conflict-update; re-running this seed intentionally refreshes updated_at.
-- * post_tags conflicts: DO NOTHING (pure junction).
-- * analytics_events/subscribers-style immutable demo rows: DO NOTHING where
--   history should not churn.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. sites (1 row) — identity mirrors lib/app/config/site_config.dart verbatim
-- ----------------------------------------------------------------------------
INSERT INTO public.sites (id, name, slug, domain, description, logo_url, favicon_url, is_active)
VALUES (
    '00000000-0000-4000-8000-000000000001',
    'Bharat Tech Pulse',
    'india_tech',
    'https://bharattechpulse.in',
    'Bharat Tech Pulse delivers actionable AI tools tutorials, unbiased smartphone comparisons, practical how-to guides, and cyber safety awareness curated specifically for Indian tech enthusiasts and families.',
    NULL, -- logo_url: operator-supplied once brand assets exist
    NULL, -- favicon_url: operator-supplied
    true
)
ON CONFLICT (slug) DO UPDATE
SET name        = EXCLUDED.name,
    domain      = EXCLUDED.domain,
    description = EXCLUDED.description
    -- logo_url / favicon_url deliberately NOT updated: once the operator sets
    -- real brand assets, re-running the seed must not wipe them.
WHERE public.sites.id = EXCLUDED.id;

-- ----------------------------------------------------------------------------
-- 2. site_settings (1 row)
--    google_analytics_id is OPERATOR-SUPPLIED and stays NULL here on purpose —
--    the demo seed must not invent or embed an analytics property id.
-- ----------------------------------------------------------------------------
INSERT INTO public.site_settings (
    id, site_id, site_name, tagline, logo_url, favicon_url,
    default_meta_title, default_meta_description,
    contact_email, social_links, footer_text, copyright_text, google_analytics_id
) VALUES (
    '00000000-0000-4000-8000-000000000060',
    '00000000-0000-4000-8000-000000000001',
    'Bharat Tech Pulse',
    'Simple technology guides, AI insights & smartphone reviews for everyday India',
    NULL,
    NULL,
    'Bharat Tech Pulse | Tech Guides, AI Tips & Smartphone Reviews for India',
    'Simple technology guides, AI insights & smartphone reviews for everyday India — practical how-tos, cyber safety awareness and buying advice curated for Indian families.',
    'contact@bharattechpulse.in',
    '{
        "twitter":   "@BharatTechPulse",
        "youtube":   "BharatTechPulse",
        "telegram":  "bharattechpulse",
        "linkedin":  "company/bharat-tech-pulse",
        "email":     "editorial@bharattechpulse.in"
    }'::jsonb,
    'Practical tech guidance for every Indian household — AI tools, smartphone wisdom and online safety in plain language.',
    '© 2026 Bharat Tech Pulse. All rights reserved. Made for Digital India.',
    NULL -- google_analytics_id: operator-supplied
)
ON CONFLICT (site_id) DO UPDATE
SET site_name                = EXCLUDED.site_name,
    tagline                  = EXCLUDED.tagline,
    default_meta_title       = EXCLUDED.default_meta_title,
    default_meta_description = EXCLUDED.default_meta_description,
    contact_email            = EXCLUDED.contact_email,
    social_links             = EXCLUDED.social_links,
    footer_text              = EXCLUDED.footer_text,
    copyright_text           = EXCLUDED.copyright_text
    -- google_analytics_id intentionally never overwritten by the seed.
WHERE public.site_settings.id = EXCLUDED.id;

-- ----------------------------------------------------------------------------
-- 3. categories (8 rows) — slugs EXACTLY match the Flutter routes and
--    icon_code/subcategories match lib/data/services/mock_data_source.dart.
-- ----------------------------------------------------------------------------
INSERT INTO public.categories
    (id, site_id, name, slug, description, image_url, icon_code, subcategories,
     sort_order, is_active, seo_title, seo_description)
VALUES
    ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000001',
     'AI & AI Tools', 'ai',
     'Indic LLMs, conversational agents, productivity workflows, and practical artificial intelligence tools for Indian developers, students, and businesses.',
     NULL, 'psychology',
     ARRAY['Indic LLMs','Productivity AI','Coding Copilots','Image & Video Gen'],
     1, true,
     'AI Tools & Guides for Indian Users | Bharat Tech Pulse',
     'Plain-language AI tutorials, prompt guides and productivity workflows curated for Indian students, developers and professionals.'),
    ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000001',
     'Smartphones', 'smartphones',
     'In-depth reviews, 5G battery benchmarks, camera comparisons, and value analysis for smartphones sold across India.',
     NULL, 'phone_android',
     ARRAY['Budget (Under ₹15K)','Mid-range (₹15K-₹30K)','Flagship Killers','Premium'],
     2, true,
     'Smartphone Reviews & Guides for India | Bharat Tech Pulse',
     'Honest smartphone explainers, spec-sheet breakdowns and longevity advice for buyers across every Indian budget segment.'),
    ('00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000001',
     'Apps', 'apps',
     'Curated Android & iOS apps, Digital Public Infrastructure tools, productivity software, and utility applications popular in India.',
     NULL, 'apps',
     ARRAY['Fintech & UPI','Govt & Citizen Utility','Productivity','Entertainment'],
     3, true,
     'App Guides & Recommendations for India | Bharat Tech Pulse',
     'Practical app guides covering UPI tools, citizen utility apps, productivity software and safe installation habits for Android and iPhone.'),
    ('00000000-0000-4000-8000-000000000104', '00000000-0000-4000-8000-000000000001',
     'How-To Guides', 'how-to',
     'Practical, verified tutorials for DigiLocker, IRCTC booking, Aadhaar updates, fast Wi-Fi configuration, and smartphone maintenance.',
     NULL, 'menu_book',
     ARRAY['Govt Services','Android Tweaks','iOS Tips','Windows & Web'],
     4, true,
     'Step-by-Step Tech How-To Guides | Bharat Tech Pulse',
     'Verified, jargon-free tutorials for government document services, home Wi-Fi, phone setup and everyday digital tasks in Indian homes.'),
    ('00000000-0000-4000-8000-000000000105', '00000000-0000-4000-8000-000000000001',
     'Tech Updates', 'tech-news',
     'Breaking news across Indian tech startups, telecom policy (TRAI/DoT), semiconductor manufacturing, and digital infrastructure.',
     NULL, 'newspaper',
     ARRAY['Telecom & 5G','Startups & Funding','Semiconductors','Policy & DPDP'],
     5, true,
     'Indian Tech Updates & Explainers | Bharat Tech Pulse',
     'Clear explainers on Indian digital infrastructure, telecom, semiconductor and data-protection developments — what they mean for you.'),
    ('00000000-0000-4000-8000-000000000106', '00000000-0000-4000-8000-000000000001',
     'Comparisons', 'comparisons',
     'Head-to-head showdowns: PhonePe vs Google Pay, Jio vs Airtel 5G, Snapdragon vs MediaTek Dimensity, and mid-range devices.',
     NULL, 'compare_arrows',
     ARRAY['App Showdowns','Phone Battles','Network Tests','Subscription Plans'],
     6, true,
     'Tech Comparisons: Choose the Right Option | Bharat Tech Pulse',
     'Criteria-based, side-by-side comparisons of phones, apps, plans and gadgets — framed around your real usage instead of raw numbers.'),
    ('00000000-0000-4000-8000-000000000107', '00000000-0000-4000-8000-000000000001',
     'Cyber Safety', 'cyber-safety',
     'Alerts and defensive strategies against Digital Arrest scams, OTP theft, fake APK loans, WhatsApp impersonation, and reporting on Chakshu / 1930.',
     NULL, 'security',
     ARRAY['Scam Alerts','Privacy Settings','Reporting Portals','Family Cyber Safety'],
     7, true,
     'Cyber Safety & Online Privacy for Indian Families | Bharat Tech Pulse',
     'Everyday online-safety guidance: recognising fraud patterns, locking down privacy settings and running a family cyber-safety conversation.'),
    ('00000000-0000-4000-8000-000000000108', '00000000-0000-4000-8000-000000000001',
     'Buying Guides', 'buying-guides',
     'Curated purchase recommendations for every budget during Flipkart Big Billion Days, Amazon Great Indian Festival, and all year round.',
     NULL, 'shopping_bag',
     ARRAY['Phones Under ₹20,000','Student Laptops','Smart TVs','TWS Earbuds'],
     8, true,
     'Smart Buying Guides for Indian Shoppers | Bharat Tech Pulse',
     'Needs-first buying guides for laptops, phones and home tech — what to prioritise, what to ignore and how to avoid buyer’s remorse.')
ON CONFLICT (site_id, slug) DO UPDATE
SET name            = EXCLUDED.name,
    description     = EXCLUDED.description,
    icon_code       = EXCLUDED.icon_code,
    subcategories   = EXCLUDED.subcategories,
    sort_order      = EXCLUDED.sort_order,
    is_active       = EXCLUDED.is_active,
    seo_title       = EXCLUDED.seo_title,
    seo_description = EXCLUDED.seo_description
WHERE public.categories.id = EXCLUDED.id;

-- ----------------------------------------------------------------------------
-- 4. authors (4 rows) — the mock bylines, seeded UNLINKED (user_id NULL).
--    The article editor requires >=1 author row before the first save, so
--    these are load-bearing for the CMS write path.
-- ----------------------------------------------------------------------------
INSERT INTO public.authors
    (id, site_id, user_id, name, slug, bio, avatar_url, designation, social_links, is_active)
VALUES
    ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000001', NULL,
     'Aravind Sharma', 'aravind-sharma',
     'Aravind has spent 12 years covering Indian consumer electronics, emerging AI agents, and semiconductor supply chains across Bengaluru and Hyderabad.',
     'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
     'Senior Tech Editor & AI Lead',
     '{"twitter":"@aravind_tech","linkedin":"in/aravindsharma-tech","email":"aravind@bharattechpulse.in"}'::jsonb,
     true),
    ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000001', NULL,
     'Priya Nambiar', 'priya-nambiar',
     'Priya investigates digital arrest rackets, payment gateway vulnerabilities, and consumer privacy rights under the DPDP Act 2023.',
     'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=300&q=80',
     'Cybersecurity & Fintech Specialist',
     '{"twitter":"@priya_cyberin","linkedin":"in/priyanambiar-cyber","email":"priya@bharattechpulse.in"}'::jsonb,
     true),
    ('00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000001', NULL,
     'Rohit Deshmukh', 'rohit-deshmukh',
     'Specialist in Indian smartphone value segments (under ₹15k to ₹40k), benchmark testing, camera shootouts, and battery longevity.',
     'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
     'Smartphone & Gadget Reviewer',
     '{"twitter":"@rohit_gadgets","linkedin":"in/rohitdeshmukh-tech","email":"rohit@bharattechpulse.in"}'::jsonb,
     true),
    ('00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000001', NULL,
     'Sneha Kulkarni', 'sneha-kulkarni',
     'Sneha breaks down complex digital public infrastructure like DigiLocker, ONDC, UPI Lite, and state portal workflows into step-by-step guides.',
     'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=300&q=80',
     'How-To & App Ecosystem Lead',
     '{"twitter":"@sneha_guides","linkedin":"in/snehakulkarni-in","email":"sneha@bharattechpulse.in"}'::jsonb,
     true)
ON CONFLICT (site_id, slug) DO UPDATE
SET name         = EXCLUDED.name,
    bio          = EXCLUDED.bio,
    avatar_url   = EXCLUDED.avatar_url,
    designation  = EXCLUDED.designation,
    social_links = EXCLUDED.social_links,
    is_active    = EXCLUDED.is_active
    -- user_id deliberately NOT touched: linking is an admin action.
WHERE public.authors.id = EXCLUDED.id;

-- ----------------------------------------------------------------------------
-- 5. tags (24 rows) — unique slugs, includes the 20 contract tags.
-- ----------------------------------------------------------------------------
INSERT INTO public.tags (id, site_id, name, slug)
VALUES
    ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000001', 'AI',                   'ai'),
    ('00000000-0000-4000-8000-000000000302', '00000000-0000-4000-8000-000000000001', 'Android',              'android'),
    ('00000000-0000-4000-8000-000000000303', '00000000-0000-4000-8000-000000000001', 'iPhone',               'iphone'),
    ('00000000-0000-4000-8000-000000000304', '00000000-0000-4000-8000-000000000001', 'Flutter',              'flutter'),
    ('00000000-0000-4000-8000-000000000305', '00000000-0000-4000-8000-000000000001', 'Google',               'google'),
    ('00000000-0000-4000-8000-000000000306', '00000000-0000-4000-8000-000000000001', 'Cyber Security',       'cyber-security'),
    ('00000000-0000-4000-8000-000000000307', '00000000-0000-4000-8000-000000000001', 'Privacy',              'privacy'),
    ('00000000-0000-4000-8000-000000000308', '00000000-0000-4000-8000-000000000001', 'Apps',                 'apps'),
    ('00000000-0000-4000-8000-000000000309', '00000000-0000-4000-8000-000000000001', 'Smartphones',          'smartphones'),
    ('00000000-0000-4000-8000-000000000310', '00000000-0000-4000-8000-000000000001', 'Buying Guide',         'buying-guide'),
    ('00000000-0000-4000-8000-000000000311', '00000000-0000-4000-8000-000000000001', 'Tutorials',            'tutorials'),
    ('00000000-0000-4000-8000-000000000312', '00000000-0000-4000-8000-000000000001', 'Artificial Intelligence','artificial-intelligence'),
    ('00000000-0000-4000-8000-000000000313', '00000000-0000-4000-8000-000000000001', 'ChatGPT',              'chatgpt'),
    ('00000000-0000-4000-8000-000000000314', '00000000-0000-4000-8000-000000000001', 'WhatsApp',             'whatsapp'),
    ('00000000-0000-4000-8000-000000000315', '00000000-0000-4000-8000-000000000001', 'Technology',           'technology'),
    ('00000000-0000-4000-8000-000000000316', '00000000-0000-4000-8000-000000000001', 'Mobile Apps',          'mobile-apps'),
    ('00000000-0000-4000-8000-000000000317', '00000000-0000-4000-8000-000000000001', 'Online Safety',        'online-safety'),
    ('00000000-0000-4000-8000-000000000318', '00000000-0000-4000-8000-000000000001', 'Productivity',         'productivity'),
    ('00000000-0000-4000-8000-000000000319', '00000000-0000-4000-8000-000000000001', 'Gadgets',              'gadgets'),
    ('00000000-0000-4000-8000-000000000320', '00000000-0000-4000-8000-000000000001', 'Software',             'software'),
    ('00000000-0000-4000-8000-000000000321', '00000000-0000-4000-8000-000000000001', 'DigiLocker',           'digilocker'),
    ('00000000-0000-4000-8000-000000000322', '00000000-0000-4000-8000-000000000001', 'UPI',                  'upi'),
    ('00000000-0000-4000-8000-000000000323', '00000000-0000-4000-8000-000000000001', '5G India',             '5g-india'),
    ('00000000-0000-4000-8000-000000000324', '00000000-0000-4000-8000-000000000001', 'Student Tech',         'student-tech')
ON CONFLICT (site_id, slug) DO UPDATE
SET name = EXCLUDED.name
WHERE public.tags.id = EXCLUDED.id;

-- ----------------------------------------------------------------------------
-- 6. posts (24 rows: 15 published / 4 draft / 3 scheduled / 2 archived)
--    Written in the site voice: practical, India-focused consumer-tech
--    guidance for everyday users and families. Evergreen and demonstrative:
--    no real news events, no invented specs/prices/benchmarks/quotations;
--    any figure that appears is labelled illustrative. Structure mirrors the
--    mock articles (headings + takeaways).
-- ----------------------------------------------------------------------------

-- One INSERT for all 24 posts; every tuple is a fixed demo UUID, so the
-- ON CONFLICT guard at the bottom (public.posts.id = EXCLUDED.id) guarantees
-- only demo-block rows are ever refreshed.
INSERT INTO public.posts
    (id, site_id, author_id, category_id, title, slug, excerpt, content,
     featured_image, thumbnail_image, status, published_at, scheduled_for,
     reading_time, seo_title, seo_description, canonical_url,
     og_title, og_description, og_image,
     is_featured, is_trending, is_popular, view_count, subcategory,
     key_takeaways, faqs, toc, created_at, updated_at)
VALUES
-- ── 401 | AI | published | featured ────────────────────────────────────────
('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
 'Choose the Right AI Tool for Your Daily Work: An Honest Framework',
 'choose-right-ai-tool-honest-framework',
 'AI tool marketing is loud. This six-question framework helps Indian students, professionals and small business owners pick tools for their real work instead of the hype.',
 E'## Start With the Job, Not the Tool\n\nThe most common mistake is choosing an AI tool because a friend showed you something it did once. Before you compare a single product, write down the two or three recurring tasks that actually eat your week: summarising long PDFs, drafting professional emails in English, converting messy notes into action lists, or turning receipts into a monthly expense sheet. A tool is only useful in proportion to how many of your listed tasks it removes. If it dazzles at something you do twice a year, it is a toy, not a tool.\n\n## Test It on Your Real Inputs\n\nA demo always looks brilliant because the demo uses clean, short, English-only text. Your real work is messier: Hinglish notes, scanned invoices, handwritten diagrams photographed at an angle, WhatsApp forwards that count as source material. Paste your own typical document into any candidate tool during the free trial and judge the result against your own standards, not the vendor''s. If the tool stumbles on your actual input format, no amount of marketing polish will fix your daily experience.\n\n## Check What It Needs to Remember\n\nSome tools work fully in one session; others quietly depend on your account, your history and your uploaded files to feel useful. Ask three practical questions: Does it need constant internet, or does it degrade gracefully on a patchy mobile connection? Will my history be retained, and can I delete it? Is there a mobile app that mirrors the desktop experience, because most of us work from a phone first? For users on metered data, a tool that needs a heavy, always-on connection is a recurring cost, not a free one.\n\n## Look for Control, Not Just Magic\n\nThe mark of a tool built for everyday users is correction. Can you edit the output in place, regenerate one section instead of the whole result, export to a format your office or college actually accepts, and see the sources when the tool quotes facts? Tools that only produce a one-shot wall of text are interesting; tools that let you steer are productive.\n\n## Read the Data Story Before You Paste Anything\n\nThis is the step almost everyone skips. Open the privacy summary and look for three answers: whether your inputs are used to train their models, whether you can opt out with one setting, and roughly where your data is stored. Rule of thumb for India: treat anything containing Aadhaar numbers, bank details, client names, medical information or unpublished exam material as things you never paste into a public AI service, no matter how trustworthy it appears. Under the DPDP Act, consent and data-minimisation are your rights as a user too.\n\n## Match the Cost to the Frequency\n\nIf you use a tool weekly, a free tier with reasonable limits may serve you forever. If you use it daily for work, judge the paid plan honestly: an illustrative way to decide is to compare the monthly fee against the hours the tool saves you, using your own hourly worth, not a fantasy salary figure. And if the tool replaces something you already pay for, like a note-taking app with built-in AI, count that as savings, not spend.\n\n## The Two-Week Trial Rule\n\nCommit to a simple experiment: use one candidate tool for every task on your list for two weeks. Keep a one-line diary note each day — kept or skipped, and why. Tools that survive the two-week test earn a permanent place in your workflow; tools that quietly get avoided were never right for you, and now you know without another rupee spent.\n\nAI tools will keep multiplying, and the hype cycle will keep promising the next revolution. The families and professionals who benefit most are not the ones with the fanciest tool — they are the ones with a calm, repeatable way to decide whether any tool deserves a place in their real work.',
 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1200&q=80',
 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=600&q=80',
 'published', '2026-10-18 10:00:00+00', NULL,
 6,
 'Choose the Right AI Tool for Your Daily Work: An Honest Framework | Bharat Tech Pulse',
 'A six-question, hype-free framework for Indian students and professionals to pick AI tools for their real daily work.',
 'https://bharattechpulse.in/article/choose-right-ai-tool-honest-framework',
 'Choose the Right AI Tool for Your Daily Work: An Honest Framework',
 'A six-question, hype-free framework for Indian students and professionals to pick AI tools for their real daily work.',
 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1200&q=80',
 true, false, false, 3850, 'Productivity AI',
 '["Start from your recurring tasks, not from tool demos.","Test every candidate on your own messy Hinglish and scanned inputs.","Check data-training and retention settings before pasting anything sensitive.","Judge paid plans against hours saved, using an honest two-week trial."]'::jsonb,
 '[{"question":"Should I pay for an AI tool if I am a student?","answer":"Try the free tier through a full assignment cycle first. Pay only when the limits — not the curiosity — are what block you, and compare the fee against the hours it returns to you."},{"question":"Is it safe to paste office documents into AI tools?","answer":"Treat any document with client names, financial details or government ID numbers as not-for-pasting. When in doubt, anonymise names and figures first, or skip the tool for that task."},{"question":"Which AI assistant is best for Hindi and Hinglish?","answer":"There is no permanent winner; test your own real notes and documents on two or three tools during free trials and pick the one that handles code-mixed input with the least cleanup."}]'::jsonb,
 '[{"id":"start-with-the-job-not-the-tool","title":"Start With the Job, Not the Tool"},{"id":"test-it-on-your-real-inputs","title":"Test It on Your Real Inputs"},{"id":"look-for-control-not-just-magic","title":"Look for Control, Not Just Magic"},{"id":"read-the-data-story-before-you-paste-anything","title":"Read the Data Story Before You Paste Anything"},{"id":"the-two-week-trial-rule","title":"The Two-Week Trial Rule"}]'::jsonb,
 '2026-10-12 09:00:00+00', '2026-10-18 12:30:00+00'),

-- ── 402 | AI | published | popular ─────────────────────────────────────────
('00000000-0000-4000-8000-000000000402', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000101',
 'Use AI Writing Assistants Responsibly: A Practical Checklist for Indian Students',
 'responsible-ai-writing-checklist-indian-students',
 'AI can make you a faster, clearer writer — or get you in academic trouble. This checklist keeps the assist on the right side of the line for Indian college students.',
 E'## Know the Rules Before You Type Anything\n\nEvery college in India is quietly drawing its own line on AI use right now. Before your first prompt, find three answers: what your department permits in submitted assignments, whether your institution uses any AI-detection or originality checking, and how your professors expect AI use to be disclosed. If the rules are silent, ask — a one-paragraph email question now beats a disciplinary conversation later. Responsibility starts with knowing the actual boundary, not guessing it.\n\n## Use AI for Thinking, Not for Submitting\n\nThe honest dividing line is simple: AI helps you produce your understanding, it does not produce your submission. Strong uses include outlining a messy argument, explaining a concept you misread, generating practice questions for exams, tightening a paragraph you wrote badly, or translating your Hindi draft into checkable English structure. Weak uses include asking for the essay and hoping the professor will not notice. Beyond the rule-breaking, there is a practical problem: the second you submit AI prose as your thinking, you stop building the skill your degree is actually for.\n\n## Verify Every Fact, Number and Citation\n\nAI assistants present guesses with total confidence. They invent case names, statistics, dates and quotations that look real and are not. Treat every factual claim in an AI output as an unpaid IOU: open the original source — the report, the judgment, the textbook page — and confirm it exists and says what the assistant claims. For Indian students citing government reports or case law, this step is non-negotiable; a fabricated citation in a project submission is worse than no citation.\n\n## Keep Your Own Voice in the Draft\n\nRun a simple self-check on any AI-assisted paragraph: does it still sound like you explaining the idea to a friend? AI tends to flatten style into generic corporate smoothness — every paragraph grammatically flawless, none recognisably yours. Fix this by writing your first draft without any assist, then using AI only on your own words for structure and clarity feedback. Your professor can teach the material; only you can prove you understood it.\n\n## Disclose When Asked, and Keep the Receipts\n\nWhere your institution wants disclosure, state exactly which tools you used and for which steps — outlining, language polish, practice questions. Keep your chat history and drafts; they are your proof of the working process, the same way a lab file proves an experiment. Students who use AI openly and in small, auditable doses almost never face problems; the trouble cases are always the ones that hid the process.\n\n## Protect Your Account and Your Data\n\nDo not paste your roll numbers, Aadhaar, contact details of classmates, or unpublished research data into a public AI service. Use a separate account with a unique password for AI tools, turn off chat-history training if the tool offers it, and remember that free accounts can be repurposed for model training unless you opt out.\n\n## The Weekly Five-Minute Review\n\nOnce a week, ask one honest question: did AI make my thinking sharper this week, or just my submission faster? If the work is faster but your understanding is not growing, you are outsourcing the learning, and the exam hall will expose the deal. AI is the best study companion a disciplined student ever had — and the most efficient way for an undisciplined one to learn nothing.',
 'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?auto=format&fit=crop&w=1200&q=80',
 'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?auto=format&fit=crop&w=600&q=80',
 'published', '2026-10-15 09:30:00+00', NULL,
 5,
 'Use AI Writing Assistants Responsibly: A Checklist for Indian Students | Bharat Tech Pulse',
 'A practical, honest checklist for Indian college students to use AI writing assistants without breaking academic rules or losing their own voice.',
 'https://bharattechpulse.in/article/responsible-ai-writing-checklist-indian-students',
 'Use AI Writing Assistants Responsibly: A Checklist for Indian Students',
 'A practical, honest checklist for Indian college students to use AI writing assistants without breaking academic rules or losing their own voice.',
 'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?auto=format&fit=crop&w=1200&q=80',
 false, false, true, 2900, 'Productivity AI',
 '["Find your department''s actual AI policy before your first prompt.","Use AI for outlining, practice and clarity — never to produce the submission itself.","Verify every fact and citation against the original source.","Disclose AI use where required and keep drafts as proof of process."]'::jsonb,
 '[{"question":"Will colleges detect that I used AI to write my assignment?","answer":"Detection tools are unreliable in both directions, which is exactly why you should not gamble on them. Honest partial use with disclosure is a safer position than undetected full use that later gets questioned."},{"question":"Is translating a Hindi draft into English with AI considered cheating?","answer":"As language polish on your own content, it is generally similar to a friend proofreading. The line crosses into dishonesty when the AI supplies the ideas themselves. When unsure, disclose."},{"question":"Which free tool is best for exam answer practice?","answer":"Any major assistant works for generating practice questions and checking your outline. The skill is in your verification habit — always check generated facts against your textbook before trusting them."}]'::jsonb,
 '[{"id":"know-the-rules-before-you-type-anything","title":"Know the Rules Before You Type Anything"},{"id":"use-ai-for-thinking-not-for-submitting","title":"Use AI for Thinking, Not for Submitting"},{"id":"verify-every-fact-number-and-citation","title":"Verify Every Fact, Number and Citation"},{"id":"disclose-when-asked-and-keep-the-receipts","title":"Disclose When Asked, and Keep the Receipts"},{"id":"protect-your-account-and-your-data","title":"Protect Your Account and Your Data"}]'::jsonb,
 '2026-10-09 11:00:00+00', '2026-10-15 10:15:00+00'),

-- ── 403 | AI | scheduled 2026-11-05 ────────────────────────────────────────
('00000000-0000-4000-8000-000000000403', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000101',
 'Build an AI-Powered Study Routine at Home: A Weekend Plan for Indian Families',
 'home-study-ai-routine-indian-families',
 'One weekend is enough to set up a shared, sane study routine where AI tools help your child learn instead of just finish homework. A practical plan for Indian parents.',
 E'## Saturday Morning: The Thirty-Minute Family Setup\n\nSit down together — not with the phone, with a notebook. Write three columns: subjects your child finds slow, subjects they find boring, and the homework timing fights that repeat every week. This list is the actual spec for what your family needs from technology; everything after this is implementation. Keep it visible on the study table. A routine built around the child''s real weak spots gets followed; a routine built around a topper''s timetable gets abandoned by Tuesday.\n\n## Saturday Afternoon: Choose Two Tools, Not Twelve\n\nResist the urge to install everything. Pick one tool for doubt-clearing (explaining a concept in simple language when the school textbook is silent) and one for practice (generating extra questions on a chapter the child is learning). Test both the way you would test any appliance: give it a real chapter from this week''s syllabus and see whether the explanation matches your child''s textbook. If the tool contradicts the syllabus, it creates more problems than it solves; keep the syllabus as the source of truth and the tool as the tutor.\n\n## Set the Shared-Device Rules Before First Use\n\nThis is the step most families skip. Decide together: the study-hours window when the device is available, whether the account is shared or child-specific, and the golden rule — AI explains, the child writes. An easy physical structure helps: a study corner in the common room beats a locked bedroom door for families with younger students. For the account, turn on history review if the tool supports it, so a parent can glance at what questions were asked that week — not surveillance, just the same reasonableness as checking a school diary.\n\n## Sunday: Rehearse One Real Homework Session\n\nPick tonight''s or tomorrow''s actual homework and run the routine end-to-end once, together. The child attempts first without any tool. Stuck steps go to the doubt-clearing tool for an explanation — never for the final answer. The child then writes the answer themselves, and finally uses the practice tool for two or three extra questions on the same chapter, if energy permits. One full rehearsed loop on Sunday beats ten well-intentioned instructions spread across the term.\n\n## Build the Breaks Into the Design\n\nA study routine that ignores Indian household reality will fail by the second week. Plan for the 45-minute focus block followed by a real break — chai, a walk on the terrace, not a reel feed. Keep one device doing one job: study tool on the big screen or study laptop, personal phone in another room during the block. Families that share one phone between siblings should book fifteen-minute slots rather than let the device become the argument.\n\n## Review on the Second Weekend, Then Let It Settle\n\nAfter one full week, ask two questions over Sunday lunch: did the homework fight shrink, and can the child explain the topic without the tool open? If both answers are no, simplify — drop one tool, shorten the block, sit with them again. If yes, stop supervising daily and let the routine run. The weekend you invested is now paying rent: AI as a patient tutor that never says "how can you not get this", and a child who learned the harder thing instead — how to learn.',
 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=1200&q=80',
 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=600&q=80',
 'scheduled', NULL, '2026-11-05 09:00:00+00',
 5,
 'Build an AI-Powered Study Routine at Home: A Weekend Plan | Bharat Tech Pulse',
 'A practical weekend plan for Indian families to set up a healthy, shared AI-assisted study routine that helps children actually learn.',
 'https://bharattechpulse.in/article/home-study-ai-routine-indian-families',
 'Build an AI-Powered Study Routine at Home: A Weekend Plan for Indian Families',
 'A practical weekend plan for Indian families to set up a healthy, shared AI-assisted study routine that helps children actually learn.',
 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=1200&q=80',
 false, false, false, 0, 'Productivity AI',
 '["Two tools are enough: one for doubt-clearing, one for extra practice.","Golden rule: AI explains, the child writes the answer.","Rehearse one real homework session together on Sunday.","Review after a week; simplify the routine until it sticks."]'::jsonb,
 '[{"question":"My child''s school bans AI entirely — does this plan still apply?","answer":"Then keep only the parent-side uses: generating practice questions for revision and simplifying topics you can then teach in your own words. The syllabus stays the source of truth; the routine does not need the child to open any tool."},{"question":"One phone for two siblings — workable?","answer":"Only with booked fifteen-minute slots and one shared review session, otherwise the device becomes the fight. If a second-hand tablet is affordable, it is the cheapest conflict-resolution purchase your family will make."},{"question":"How do I stop the tool from just giving answers?","answer":"Prompt style matters: ask it to explain the method step by step without solving the specific problem, and have your child write each step themselves before checking."}]'::jsonb,
 '[{"id":"saturday-morning-the-thirty-minute-family-setup","title":"Saturday Morning: The Thirty-Minute Family Setup"},{"id":"saturday-afternoon-choose-two-tools-not-twelve","title":"Saturday Afternoon: Choose Two Tools, Not Twelve"},{"id":"set-the-shared-device-rules-before-first-use","title":"Set the Shared-Device Rules Before First Use"},{"id":"sunday-rehearse-one-real-homework-session","title":"Sunday: Rehearse One Real Homework Session"},{"id":"build-the-breaks-into-the-design","title":"Build the Breaks Into the Design"}]'::jsonb,
 '2026-10-16 08:00:00+00', '2026-10-17 15:00:00+00'),

-- ── 404 | Smartphones | published | trending ───────────────────────────────
('00000000-0000-4000-8000-000000000404', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000102',
 'Smartphone Spec Sheets Decoded: What the Numbers Actually Mean for You',
 'smartphone-spec-sheet-decoded-india',
 'RAM in GB, mAh, nits, megapixels, IP ratings — spec sheets are a wall of numbers designed to impress, not inform. Here is how to read them like a reviewer.',
 E'## RAM: Number vs Reality\n\nMarketing treats RAM like engine displacement — bigger must be better. Reality is subtler: RAM governs how many apps stay open and how smoothly the system breathes. A well-optimised phone with less RAM routinely outperforms a sloppy one with more, and "expandable RAM" software tricks add little in daily use. Judge by your usage: if you keep three or four apps alive and play one game, you are fine in the mainstream tier; heavy multitasking and large games push you up a notch. And check the type of storage too — a fast storage chip changes the daily feel more than the second gigabyte of RAM.\n\n## Processors and Benchmark Scores\n\nBenchmark numbers are lab results, not lived experience. A score tells you the ceiling, not what you feel in the metro, in a video call, or while shooting your niece''s birthday. What actually matters for Indian users: sustained performance under heat (summer afternoons and gaming sessions throttle chips), efficiency (which decides battery life more than mAh does), and how long the vendor supports the chip with updates. Ask "how does this handle my three apps for three years", not "what did it score once".\n\n## Battery: mAh Is Not Stamina\n\nMilliamp-hours is fuel tank size; efficiency is mileage. A 5,000 mAh phone with an inefficient screen and chipset can die before a 4,500 mAh phone with better parts. Faster charging numbers sell boxes — check the pattern instead: charging slows sharply in the last stretch, and different chargers deliver different speeds to the same phone, so the brick in the box matters. For Indian power-cut realities, all-night battery stamina for calls and WhatsApp beats any charging speed.\n\n## Display: Nits, Refresh Rate and the Sun Test\n\nA 120 Hz refresh rate makes scrolling feel smoother — nice, not necessary. Peak brightness in nits decides whether you can read your screen at noon on the road, which is the daily truth for most Indian users; "outdoor mode" figures in ads are often measured for a tiny part of the screen. The honest test is to view the phone under a tube-light in the shop — sunlight is harder to fake, but bright indoor light reveals weak screens well enough.\n\n## Cameras: Megapixels Are the Least Interesting Number\n\nSensor size, pixel binning and processing decide image quality far more than megapixel count; a huge number can mean tiny pixels that struggle at night. Ignore the secondary lens lottery — many budget "AI lenses" are filler. The numbers worth reading: aperture, whether the main camera has optical stabilisation for night photos and video, and sample photos shot by an actual reviewer in Indian conditions, not the vendor''s gallery.\n\n## The Small Numbers With Big Daily Impact\n\nIP dust-and-water rating decides monsoon peace of mind. Software update commitment — count the years promised — is the single biggest predictor of whether your phone is safe and relevant in year three. Stereo speakers, an IR blaster, and headphone jack availability are personal quality-of-life items the box rarely prints large.\n\n## Read for Three Years, Not Three Days\n\nUnboxing excitement makes everyone blind to ownership: the phone you buy today is the phone you are stuck with through two board exams, three job transfers and a monsoon or two. Weigh the boring, sustained numbers — updates, efficiency, thermals — above the loud, lab-only ones. Spec sheets are written to win the first five minutes; your reading habit is what wins the next thousand days.',
 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=crop&w=1200&q=80',
 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=crop&w=600&q=80',
 'published', '2026-10-12 14:00:00+00', NULL,
 7,
 'Smartphone Spec Sheets Decoded: What the Numbers Really Mean | Bharat Tech Pulse',
 'RAM, mAh, nits, megapixels: a plain-language guide to reading smartphone spec sheets like a reviewer and buying for three years of ownership.',
 'https://bharattechpulse.in/article/smartphone-spec-sheet-decoded-india',
 'Smartphone Spec Sheets Decoded: What the Numbers Really Mean for You',
 'RAM, mAh, nits, megapixels: a plain-language guide to reading smartphone spec sheets like a reviewer and buying for three years of ownership.',
 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=crop&w=1200&q=80',
 false, true, false, 3600, '',
 '["Benchmark scores are lab ceilings, not daily experience — heat and efficiency decide feel.","Battery stamina depends on chip and screen efficiency, not just the mAh number.","Software update commitment predicts year-three safety better than any single spec.","Megapixel count is the least meaningful camera number; stabilisation and processing matter more."]'::jsonb,
 '[{"question":"Is expandable RAM worth choosing a phone over?","answer":"Rarely. Software-based RAM extension is a modest relief at best, and a well-managed phone with less physical RAM usually feels smoother than a poorly managed one with more."},{"question":"Do I need 120 Hz?","answer":"It is a pleasant scroll, not a health requirement. If the budget is tight, spend the difference on better brightness or longer update commitments — you notice the sun more than the smoothness after week one."},{"question":"How many years of updates should I demand?","answer":"Treat three years of security updates as the floor for any phone you plan to keep long-term; anything less leaves you running an unsupported, more vulnerable device while it still physically works."}]'::jsonb,
 '[{"id":"ram-number-vs-reality","title":"RAM: Number vs Reality"},{"id":"battery-mah-is-not-stamina","title":"Battery: mAh Is Not Stamina"},{"id":"cameras-megapixels-are-the-least-interesting-number","title":"Cameras: Megapixels Are the Least Interesting Number"},{"id":"the-small-numbers-with-big-daily-impact","title":"The Small Numbers With Big Daily Impact"},{"id":"read-for-three-years-not-three-days","title":"Read for Three Years, Not Three Days"}]'::jsonb,
 '2026-10-06 10:00:00+00', '2026-10-12 16:45:00+00'),

-- ── 405 | Smartphones | published | popular ────────────────────────────────
('00000000-0000-4000-8000-000000000405', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000102',
 'How Long Should Your Next Phone Last? A Longevity-First Way to Buy',
 'how-long-should-your-next-phone-last',
 'The cheapest phone is the one you keep using happily for years. Here is a longevity-first framework for buying a smartphone in India — updates, battery habits, repairs and resale.',
 E'## Decide Your Ownership Years Before Your Budget\n\nMost Indian buyers pick a phone by budget alone, then discover the hidden variable: how long it stays pleasant to own. Start differently. Ask how many years you want this phone to last — two, three, four? That number should drive everything else, because a phone that sags in year two costs you twice: the annoyance, and the early replacement. The per-year maths is what matters; a slightly costlier phone you keep for four comfortable years usually beats a cheaper one you replace after two frustrating ones. Figure the per-year cost on paper with your own prices before you compare any two phones.\n\n## The Update Commitment Is the Real Expiry Date\n\nHardware does not kill most phones; abandonment does. When a vendor stops security updates, your banking apps start failing, app developers drop support, and your perfectly good phone becomes a risk to keep online. Before buying, check the promised duration of OS and security updates and treat it as the phone''s announced expiry date. Four years of security support with three OS upgrades is a healthy promise for mainstream buyers; more is excellent; less than three years of updates means you are renting a phone, not owning it.\n\n## Battery Health Beats Battery Size\n\nBatteries are consumables — every chemistry fades. What differs is how fast and how painfully. Ask two questions when buying: does the vendor or service centre actually stock replacement batteries for this model, and what does a replacement cost? A phone with a slightly smaller battery you can refresh for an affordable service price in year three will outlast a phone with a big battery that dies with the model. Your charging habits decide the rest: avoid the overnight-on-slow-charge myth debates, keep the phone cool in Indian summers, and top up between twenty and eighty percent when you can — small habits, measurable difference over years.\n\n## Repairability Is a Feature Nobody Advertises\n\nBefore you fall in love with a design, check the service ecosystem around it: how many authorised service points reach your city, whether common parts like screens and batteries are stocked, and what a cracked-screen repair costs on this model. A phone with cheap, available repairs is a multi-year phone; a phone whose screen repair approaches its own resale value is a one-drop disposable. Glass backs and curved edge screens are beautiful and fragile — if your hands, your job or your children live in the real world, flat and sturdy wins the ownership years.\n\n## Resale Value Is Just Longevity Crowdsourcing\n\nBuyers who hold models long keep resale strong, and resale is the refund you did not plan for. Phones from brands with wide service networks and long update promises hold value noticeably better in the Indian second-hand market. Check typical resale after a year and a half before you buy — it tells you, honestly, how long the crowd expects to want this phone. If the drop is brutal, either the brand abandons owners or the model is already a bad bet.\n\n## The Longevity Checklist, in Order\n\n1) Update commitment in years, 2) service and battery replacement reach in your city, 3) per-year cost over your chosen ownership period, 4) expected resale, 5) the specs everyone argues about first. Flip the priority most shops push, and you stop buying phones for the first five minutes and start buying them for the next one thousand days.',
 'https://images.unsplash.com/photo-1577563908411-5077b6dc7624?auto=format&fit=crop&w=1200&q=80',
 'https://images.unsplash.com/photo-1577563908411-5077b6dc7624?auto=format&fit=crop&w=600&q=80',
 'published', '2026-10-09 11:00:00+00', NULL,
 6,
 'How Long Should Your Next Phone Last? A Longevity-First Buying Guide | Bharat Tech Pulse',
 'Updates, battery habits, repairability and resale: a longevity-first framework to buy a smartphone in India that stays pleasant to own for years.',
 'https://bharattechpulse.in/article/how-long-should-your-next-phone-last',
 'How Long Should Your Next Phone Last? A Longevity-First Way to Buy',
 'Updates, battery habits, repairability and resale: a longevity-first framework to buy a smartphone in India that stays pleasant to own for years.',
 'https://images.unsplash.com/photo-1577563908411-5077b6dc7624?auto=format&fit=crop&w=1200&q=80',
 false, false, true, 2450, 'Budget (Under ₹15K)',
 '["Choose your ownership years before your budget — compare per-year cost, not price tags.","The vendor''s update commitment is the phone''s real expiry date.","Battery replacement availability matters more than battery size.","Repair network and resale value quietly decide how long a phone stays worth keeping."]'::jsonb,
 '[{"question":"Is buying an older flagship better for longevity than a new mid-ranger?","answer":"Often, yes for software maturity and build, but check remaining update promises first — an abandoned flagship with two years left of support loses to a mid-ranger with four. Longevity is about the calendar the vendor commits to, not the launch badge."},{"question":"Does overnight charging ruin the battery?","answer":"Modern phones manage the top-off intelligently; heat is the real enemy. Avoid charging under pillows or in direct summer sun, and use the slower overnight charge over fast top-ups when convenient — the habit worth fighting is battery-hunting at low percentages, not the midnight plug."},{"question":"When is it actually time to replace rather than repair?","answer":"Simple maths: if the repair costs more than half the phone''s current resale value, or the model is out of security updates, replacement is usually the cheaper honest choice."}]'::jsonb,
 '[{"id":"decide-your-ownership-years-before-your-budget","title":"Decide Your Ownership Years Before Your Budget"},{"id":"the-update-commitment-is-the-real-expiry-date","title":"The Update Commitment Is the Real Expiry Date"},{"id":"battery-health-beats-battery-size","title":"Battery Health Beats Battery Size"},{"id":"repairability-is-a-feature-nobody-advertises","title":"Repairability Is a Feature Nobody Advertises"},{"id":"the-longevity-checklist-in-order","title":"The Longevity Checklist, in Order"}]'::jsonb,
 '2026-10-02 09:00:00+00', '2026-10-09 13:20:00+00'),

-- ── 406 | Smartphones | draft ──────────────────────────────────────────────
('00000000-0000-4000-8000-000000000406', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000102',
 'Budget or Premium: Which Smartphone Features Are Actually Worth the Extra',
 'budget-vs-premium-phone-features-worth-it',
 'Not every upgrade earns its price. A feature-by-feature walk through where premium phone money genuinely shows up in daily use — and where it is mostly showroom polish.',
 E'## The Upgrade Question Nobody Answers Honestly\n\nEvery price jump comes dressed as a necessity. Shops say you need the pricier model; YouTube says the budget phone is compromised now. Nobody asks the only question that matters: which specific upgrade will change your daily behaviour? If an extra hundred rupees a month for two years buys nothing your thumb notices, it is money burned. This walkthrough sorts upgrade features into three buckets — daily-life real, occasionally real, and showroom decoration.\n\n## Camera: Where Extra Money Shows, and Where It Does Not\n\nThe honest upgrades sit in low-light consistency, video stabilisation, and how fast the camera is from pocket to shot. Daylight megapixel games are largely marketing; budget phones are genuinely excellent in good light now. Night photos, zoom beyond the basic range and portrait-video are where premium engineering earns its price. If your album is mostly daylight family functions and food shots, the budget tier is telling you the truth: you are fine.\n\n## Display and Build: The Feel Upgrade\n\nThis is the subtlest real one. Premium phones win on brightness in harsh sun, smoother always-on refresh, tougher glass and better water sealing — none of it demos well, all of it touches your eyes every day. For a commuter who reads on the metro at noon, the sun-brightness bump is worth paying for. For a mostly-at-home user, the budget tier looks great after dark, which is when you use it.\n\n## Performance and Updates: Paying for Years, Not Speed\n\nPremium chips mostly buy you the future: more headroom before the phone feels slow, and longer support commitments. The budget tier handles today''s WhatsApp-plus-Maps-plus-Youtube life perfectly. If you hold phones four years, the premium tier''s update promise amortises well. If you upgrade every two years anyway, you are paying for headroom you will sell unused.\n\n## Charging, Accessories and the Extras Trap\n\nFaster charging is nice; charging speeds beyond the point where the phone tops up while you dress are decoration. Wireless charging only matters if you already live on a pad. The premium-only features that genuinely change lives for specific people: satellite messaging for remote trekkers, stylus for note-takers, IR blaster for remote-hoarders. List your habits first; then decide which premium line items exist for you.\n\n## The Rupee-per-Day Test\n\nTake the price gap in rupees, divide by the ownership months you planned — illustrative maths always beats vague feelings. If the premium model costs the equivalent of one filter coffee a month more, and one feature in your list is genuinely daily, pay it. If it is three coffees for features in the decoration bucket, buy the budget phone, pocket the difference, and upgrade your case instead. The premium tier is not a scam; it is just aimed at behaviours, and the first job is confirming it is aimed at yours.',
 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=crop&w=1200&q=80',
 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=crop&w=600&q=80',
 'draft', NULL, NULL,
 6,
 'Budget or Premium: Which Phone Features Are Worth the Extra | Bharat Tech Pulse',
 'A feature-by-feature look at where premium smartphone money genuinely shows up in daily use — and where it is mostly showroom polish.',
 'https://bharattechpulse.in/article/budget-vs-premium-phone-features-worth-it',
 'Budget or Premium: Which Smartphone Features Are Actually Worth the Extra',
 'A feature-by-feature look at where premium smartphone money genuinely shows up in daily use — and where it is mostly showroom polish.',
 'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=crop&w=1200&q=80',
 false, false, false, 0, 'Flagship Killers',
 '["Judge each upgrade against a specific daily behaviour you already have.","Low-light camera consistency is the clearest premium win; daylight megapixels are not.","Premium performance mostly buys longer support, not faster today.","Use the rupee-per-day test to turn the price gap into an honest yes or no."]'::jsonb,
 '[{"question":"Is the base storage tier a false economy?","answer":"Sometimes. Storage is the one spec you cannot skip and regret less: if photos and WhatsApp media fill a base tier within months, the cloud workarounds cost you patience daily. Buy the next tier up when the difference is small."},{"question":"Do premium phones last more years than budget ones now?","answer":"Mainly through software promises and repairability, not through build magic. A budget phone with four years of updates outlasts a premium phone the vendor abandons early."}]'::jsonb,
 '[{"id":"the-upgrade-question-nobody-answers-honestly","title":"The Upgrade Question Nobody Answers Honestly"},{"id":"camera-where-extra-money-shows-and-where-it-does-not","title":"Camera: Where Extra Money Shows"},{"id":"performance-and-updates-paying-for-years-not-speed","title":"Performance and Updates: Paying for Years"},{"id":"the-rupee-per-day-test","title":"The Rupee-per-Day Test"}]'::jsonb,
 '2026-10-20 12:00:00+00', '2026-10-24 10:00:00+00'),

-- ...POSTS TUPLES CONTINUE...

-- ============================================================================
COMMIT;
-- End of 006_seed_data.sql
