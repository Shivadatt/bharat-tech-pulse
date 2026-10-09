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
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/aravind-sharma-avatar.jpg',
     'Senior Tech Editor & AI Lead',
     '{"twitter":"@aravind_tech","linkedin":"in/aravindsharma-tech","email":"aravind@bharattechpulse.in"}'::jsonb,
     true),
    ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000001', NULL,
     'Priya Nambiar', 'priya-nambiar',
     'Priya investigates digital arrest rackets, payment gateway vulnerabilities, and consumer privacy rights under the DPDP Act 2023.',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/priya-nambiar-avatar.jpg',
     'Cybersecurity & Fintech Specialist',
     '{"twitter":"@priya_cyberin","linkedin":"in/priyanambiar-cyber","email":"priya@bharattechpulse.in"}'::jsonb,
     true),
    ('00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000001', NULL,
     'Rohit Deshmukh', 'rohit-deshmukh',
     'Specialist in Indian smartphone value segments (under ₹15k to ₹40k), benchmark testing, camera shootouts, and battery longevity.',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/rohit-deshmukh-avatar.jpg',
     'Smartphone & Gadget Reviewer',
     '{"twitter":"@rohit_gadgets","linkedin":"in/rohitdeshmukh-tech","email":"rohit@bharattechpulse.in"}'::jsonb,
     true),
    ('00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000001', NULL,
     'Sneha Kulkarni', 'sneha-kulkarni',
     'Sneha breaks down complex digital public infrastructure like DigiLocker, ONDC, UPI Lite, and state portal workflows into step-by-step guides.',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/sneha-kulkarni-avatar.jpg',
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
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
 'published', '2026-10-18 10:00:00+00', NULL,
 6,
 'Choose the Right AI Tool for Your Daily Work: An Honest Framework | Bharat Tech Pulse',
 'A six-question, hype-free framework for Indian students and professionals to pick AI tools for their real daily work.',
 'https://bharattechpulse.in/article/choose-right-ai-tool-honest-framework',
 'Choose the Right AI Tool for Your Daily Work: An Honest Framework',
 'A six-question, hype-free framework for Indian students and professionals to pick AI tools for their real daily work.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
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
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
 'published', '2026-10-15 09:30:00+00', NULL,
 5,
 'Use AI Writing Assistants Responsibly: A Checklist for Indian Students | Bharat Tech Pulse',
 'A practical, honest checklist for Indian college students to use AI writing assistants without breaking academic rules or losing their own voice.',
 'https://bharattechpulse.in/article/responsible-ai-writing-checklist-indian-students',
 'Use AI Writing Assistants Responsibly: A Checklist for Indian Students',
 'A practical, honest checklist for Indian college students to use AI writing assistants without breaking academic rules or losing their own voice.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
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
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
 'scheduled', NULL, '2026-11-05 09:00:00+00',
 5,
 'Build an AI-Powered Study Routine at Home: A Weekend Plan | Bharat Tech Pulse',
 'A practical weekend plan for Indian families to set up a healthy, shared AI-assisted study routine that helps children actually learn.',
 'https://bharattechpulse.in/article/home-study-ai-routine-indian-families',
 'Build an AI-Powered Study Routine at Home: A Weekend Plan for Indian Families',
 'A practical weekend plan for Indian families to set up a healthy, shared AI-assisted study routine that helps children actually learn.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
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
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
 'published', '2026-10-12 14:00:00+00', NULL,
 7,
 'Smartphone Spec Sheets Decoded: What the Numbers Really Mean | Bharat Tech Pulse',
 'RAM, mAh, nits, megapixels: a plain-language guide to reading smartphone spec sheets like a reviewer and buying for three years of ownership.',
 'https://bharattechpulse.in/article/smartphone-spec-sheet-decoded-india',
 'Smartphone Spec Sheets Decoded: What the Numbers Really Mean for You',
 'RAM, mAh, nits, megapixels: a plain-language guide to reading smartphone spec sheets like a reviewer and buying for three years of ownership.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
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
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
 'published', '2026-10-09 11:00:00+00', NULL,
 6,
 'How Long Should Your Next Phone Last? A Longevity-First Buying Guide | Bharat Tech Pulse',
 'Updates, battery habits, repairability and resale: a longevity-first framework to buy a smartphone in India that stays pleasant to own for years.',
 'https://bharattechpulse.in/article/how-long-should-your-next-phone-last',
 'How Long Should Your Next Phone Last? A Longevity-First Way to Buy',
 'Updates, battery habits, repairability and resale: a longevity-first framework to buy a smartphone in India that stays pleasant to own for years.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
 false, false, false, 2450, 'Budget (Under ₹15K)',
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
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
 'draft', NULL, NULL,
 6,
 'Budget or Premium: Which Phone Features Are Worth the Extra | Bharat Tech Pulse',
 'A feature-by-feature look at where premium smartphone money genuinely shows up in daily use — and where it is mostly showroom polish.',
 'https://bharattechpulse.in/article/budget-vs-premium-phone-features-worth-it',
 'Budget or Premium: Which Smartphone Features Are Actually Worth the Extra',
 'A feature-by-feature look at where premium smartphone money genuinely shows up in daily use — and where it is mostly showroom polish.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
 false, false, false, 0, 'Flagship Killers',
 '["Judge each upgrade against a specific daily behaviour you already have.","Low-light camera consistency is the clearest premium win; daylight megapixels are not.","Premium performance mostly buys longer support, not faster today.","Use the rupee-per-day test to turn the price gap into an honest yes or no."]'::jsonb,
 '[{"question":"Is the base storage tier a false economy?","answer":"Sometimes. Storage is the one spec you cannot skip and regret less: if photos and WhatsApp media fill a base tier within months, the cloud workarounds cost you patience daily. Buy the next tier up when the difference is small."},{"question":"Do premium phones last more years than budget ones now?","answer":"Mainly through software promises and repairability, not through build magic. A budget phone with four years of updates outlasts a premium phone the vendor abandons early."}]'::jsonb,
 '[{"id":"the-upgrade-question-nobody-answers-honestly","title":"The Upgrade Question Nobody Answers Honestly"},{"id":"camera-where-extra-money-shows-and-where-it-does-not","title":"Camera: Where Extra Money Shows"},{"id":"performance-and-updates-paying-for-years-not-speed","title":"Performance and Updates: Paying for Years"},{"id":"the-rupee-per-day-test","title":"The Rupee-per-Day Test"}]'::jsonb,
 '2026-10-20 12:00:00+00', '2026-10-24 10:00:00+00'),

-- ── 407 | Apps | published | trending ──────────────────────────────────────
('00000000-0000-4000-8000-000000000407', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000103',
 'The Permission Check: Settings to Review After Installing Any New App',
 'app-permission-check-after-install',
 'That install popup asked for contacts, location and photos before you even opened the app. Here is the five-minute permission audit every new app should pass before it settles onto your phone.',
 E'## Why the First Five Minutes Matter\n\nApps are most forgiving about settings right after install, and most intrusive by default. The permissions an app requests on first launch are rarely all needed on day one — they are requests for the day the developers hope you will need them. A five-minute audit after install, before habits form, keeps your contacts list, location history and photo gallery your business instead of a data broker''s. Make it the app''s honeymoon period; do the audit before the first real login.\n\n## Step One: The OS Permission Sheet\n\nAndroid and iOS both keep a master list of what each app can reach: camera, microphone, location, contacts, photos, calendar, notifications, and the sneakier ones like background location and nearby devices. Open it — Settings, then Apps, then the app, then Permissions. For each entry ask one question: can I use this app''s core purpose without this permission today? A flashlight does not need contacts. A utility bill app does not need the camera at install. Wherever possible, choose "only while using" over "always", and "ask every time" over blanket access.\n\n## Step Two: Deny First, Regret Later\n\nDenials are cheap and reversible. If an app truly needs a permission for a feature, it will ask again at the moment you use that feature — that second ask, in context, is the honest one. An app that refuses to open without accepting every permission at once is telling you its business model before you read a word of its policy; decide whether you want to be that model''s product today.\n\n## Step Three: The In-App Settings Minefield\n\nBeyond OS permissions, each app hides its own toggles: personalised ads, data-sharing with partners, voice-assistant recordings, history retention, and the ad-personalisation switches required under India''s digital consent rules. Dig into the app''s own settings menu — usually under Account or Privacy — and switch off personalised ads and external data sharing. This is the audit step users skip and data brokers fund.\n\n## Step Four: Notifications Are a Permission Too\n\nFifty daily notifications is not engagement, it is rent-free occupation of your lock screen. Turn off everything that is not a human message or a real alert; keep the app''s badge off if the content can wait. You will be shocked how much of your attention budget an app spends without asking.\n\n## Step Five: The Thirty-Day Recheck\n\nPermissions drift: apps re-ask, updates re-enable, your needs change. Once a month, skim your permission sheet for anything you granted in a hurry and quietly regret. Uninstall apps that grabbed gallery access and then never used the feature — they were collecting, not serving.\n\n## The Family Shortcut\n\nSet up this five-minute audit once with each family member on their primary phone, then teach the ritual instead of the list. When your parents install the next "mandatory" app, the habit — open permissions, deny first, check the in-app toggles — protects them better than any single conversation could. The app store will never stop asking for more than it needs; the audit is how you keep answering only what you choose.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
 'published', '2026-10-07 08:30:00+00', NULL,
 4,
 'The Permission Check: App Settings to Review After Install | Bharat Tech Pulse',
 'A five-minute permission audit every new Android or iPhone app should pass before it settles in — deny first, check in-app toggles, protect the family.',
 'https://bharattechpulse.in/article/app-permission-check-after-install',
 'The Permission Check: Settings to Review After Installing Any New App',
 'A five-minute permission audit every new Android or iPhone app should pass before it settles in — deny first, check in-app toggles, protect the family.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
 false, true, false, 3100, 'Productivity',
 '["Deny non-essential permissions at install; apps can ask again in context.","Check both the OS permission sheet and the app''s own privacy toggles.","Turn off personalised ads and partner data-sharing in every app that offers them.","Recheck the whole permission list once every thirty days."]'::jsonb,
 '[{"question":"Does denying permissions break the app?","answer":"Rarely at first launch, and never permanently — permissions are one toggle away. The only genuine failures are apps that hold core function hostage for irrelevant access, which is exactly the behaviour the audit is designed to catch."},{"question":"My app says ''recommended permissions'' — should I allow all?","answer":"That phrase is marketing, not a requirement. ''Recommended'' means recommended for their analytics, not your function. Deny, use the app, and allow only what a missing feature actually demands."},{"question":"Is this audit needed on a basic feature phone?","answer":"Even more so — small screens make permission prompts easy to tap past without reading. The same deny-first rule applies on every platform."}]'::jsonb,
 '[{"id":"step-one-the-os-permission-sheet","title":"Step One: The OS Permission Sheet"},{"id":"step-two-deny-first-regret-later","title":"Step Two: Deny First, Regret Later"},{"id":"step-three-the-in-app-settings-minefield","title":"Step Three: The In-App Settings Minefield"},{"id":"step-five-the-thirty-day-recheck","title":"Step Five: The Thirty-Day Recheck"},{"id":"the-family-shortcut","title":"The Family Shortcut"}]'::jsonb,
 '2026-10-01 09:00:00+00', '2026-10-07 11:00:00+00'),

-- ── 408 | Apps | draft ─────────────────────────────────────────────────────
('00000000-0000-4000-8000-000000000408', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000103',
 'The Weekend App Audit: Declutter Your Family''s Phones in an Hour',
 'weekend-app-audit-indian-families',
 'Duplicate apps, abandoned subscriptions, storage-hoarding and notification noise: a one-hour weekend ritual that leaves every family phone lighter, faster and safer.',
 E'## Why an Hour Beats a Lifetime of Tidying\n\nPhones accumulate like drawers: one app installed for a single delivery order, one duplicate notes app per migration, one subscription quietly billing. Nobody ever finds time to fix it, because a full cleanup feels like a weekend project. It is not — with a checklist, one focused hour cleans every phone in the family, and the ritual is easy to repeat quarterly. The audit below is designed for the common Indian reality: shared family accounts, one or two phones doing everything, and users from eight to eighty.\n\n## Round One: The Delete Pass (fifteen minutes per phone)\n\nScroll every screen and ask of each app: have you opened it in the last month? If not, off it goes — app stores always have it for re-install, and the cloud remembers your account. Special cases: that second food app from the festival offer, the notes app you abandoned mid-migration, the game your child installed and forgot. Then the twin hunt: two gallery apps, three file managers, four browsers — merge to one favourite each. Deleting is instant therapy; the phone''s storage bar visibly exhales.\n\n## Round Two: The Renewal and Re-login Check (ten minutes)\n\nOpen each surviving app once. Does the login still work, does the notification you depend on still arrive, does the app still serve the purpose? This catches the quiet failures — the bank app whose update broke alerts, the utility app that stopped sending bills. While inside, fix the profile: current phone number, correct address, recovery email that someone in the family can actually access. An hour now prevents the panicked customer-care call later.\n\n## Round Three: Storage Forensics (fifteen minutes)\n\nWhatsApp media is the usual landlord of Indian phone storage. Open the storage settings, see what is actually occupying space, and act: turn off auto-save for forwarded videos, clear stale chat media you no longer need, move irreplaceable photos to one agreed backup place — a cloud album or one family hard drive, chosen deliberately, not drifted into. For the family camera roll, delete the daily fifty-shot burst habit at the source: shoot fewer, keep keepers.\n\n## Round Four: The Notification Amnesty (ten minutes)\n\nThis is the mental-health round. For each app that buzzes: is this a human, money, or an emergency? Everything else gets silenced — not deleted, silenced; the content still exists for when you choose to look. Do this once per app, in the app''s own settings, not with the master do-not-disturb sledgehammer, and every phone in the house suddenly gets quieter without losing anything that mattered.\n\n## Close With the Family Contract\n\nWrite three lines together and stick them on the fridge, literally or digitally: one app per job; new apps get the permission check before they settle; quarterly audit on the first Sunday. Phones are the family''s most-used office, bank, album and classroom — an hour a season keeping that office tidy is the cheapest upgrade your family will ever make.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
 'draft', NULL, NULL,
 5,
 'The Weekend App Audit: Declutter Your Family''s Phones in an Hour | Bharat Tech Pulse',
 'A one-hour, four-round audit to delete, renew, clean storage and silence notifications on every family phone — a repeatable quarterly ritual.',
 'https://bharattechpulse.in/article/weekend-app-audit-indian-families',
 'The Weekend App Audit: Declutter Your Family''s Phones in an Hour',
 'A one-hour, four-round audit to delete, renew, clean storage and silence notifications on every family phone — a repeatable quarterly ritual.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
 false, false, false, 0, '',
 '["Delete anything unopened for a month; the store and cloud keep the option alive.","Re-login to every survivor and fix stale contact and recovery details.","Attack WhatsApp media first in storage cleanups; agree on one deliberate backup place.","Silence everything that is not a human, money or emergency — keep the app, kill the buzz."]'::jsonb,
 '[{"question":"Will deleting apps lose my purchased content or data?","answer":"Accounts live with the provider, not on the handset; re-install and re-login restores almost everything. What lives only on the device — some chats, downloaded offline maps and local files — is worth exporting or checking before deletion."},{"question":"How do I get reluctant family members to join the audit?","answer":"Do theirs first as a service, on the couch, showing the freed storage and silenced noise as instant wins. Participation follows results; lectures do not."},{"question":"Should kids run the same audit?","answer":"Same ritual, shorter: one screen of apps, parent confirms the delete list, and the child chooses which notifications to keep. The habit is the lesson; your supervision is the safety net."}]'::jsonb,
 '[{"id":"round-one-the-delete-pass-fifteen-minutes-per-phone","title":"Round One: The Delete Pass"},{"id":"round-two-the-renewal-and-re-login-check-ten-minutes","title":"Round Two: The Renewal and Re-login Check"},{"id":"round-three-storage-forensics-fifteen-minutes","title":"Round Three: Storage Forensics"},{"id":"round-four-the-notification-amnesty-ten-minutes","title":"Round Four: The Notification Amnesty"},{"id":"close-with-the-family-contract","title":"Close With the Family Contract"}]'::jsonb,
 '2026-10-19 10:00:00+00', '2026-10-23 14:00:00+00'),

-- ── 409 | Apps | archived ──────────────────────────────────────────────────
('00000000-0000-4000-8000-000000000409', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000103',
 'Why Offline-First Apps Earn a Place on Your Phone',
 'offline-first-apps-worth-installing',
 'Patchy network, roaming charges, a dead zone on the ghats: apps that keep working when the internet does not are the quiet heroes of Indian travel and daily life.',
 E'## What Offline-First Actually Means\n\nAn offline-first app treats no-connection as its normal state and connectivity as a bonus: your data lives on the device, the interface never spins waiting for a server, and syncing happens in the background when a network appears. This differs from apps that merely cache a little — the design philosophy decides whether a dead zone breaks you or barely registers. For a country with variable coverage, this is not a niche preference; it is the difference between a tool and a decoration.\n\n## The Indian Cases Where It Earns Its Space\n\nTrains are the classic: tickets, seat plans and meal booking handled before the network vanishes between stations. Hill treks and remote stays where mobile data is a rumour. Roaming when international rates make every bar expensive — maps, translations and boarding passes pre-downloaded turn a data plan from necessity into luxury. Daily-life cases too: the metro turnstile queue where the network is congested precisely because everyone is there, and the ticket that worked offline. And the storm case: when towers flood during disasters, local notes, first-aid guides and cached maps are the apps you are glad stayed resident.\n\n## The Offline-First Toolkit Worth Carrying\n\nMaps with regions pre-downloaded are the anchor: search, routes and turn-by-turn work without a bar of signal. Notes and to-dos that store locally and sync opportunistically keep your brain offline-safe. Language basics for foreign trips, downloaded in advance. A personal document vault — copies of ID, insurance, prescriptions, bookings — stored encrypted on the device itself, since an upload to a cloud you cannot reach proves nothing at a checkpost. Small utilities too: unit converters, torch-plus-SOS combinations, and offline PDF readers for manuals and forms.\n\n## The Habits That Make It Actually Work\n\nOffline-first is a discipline of preparation, not a feature. Download the map region before the trip, not when the signal dies. Keep the document vault current — stale insurance copies are dangerous. Choose apps where export is easy: local-first data you can back up on Wi-Fi tonight, not locked in a proprietary cloud. And remember the trade-off: local data on an unsecured phone is only as private as your lock screen, so pair the vault with a strong passcode and encrypted backup.\n\n## Why the Store Under-sells This\n\nApp stores rank on engagement, and engagement wants the network; nobody demos well offline. So the offline-first category is a place to browse deliberately once — put the five candidates in the folder, test each once at airplane-mode dinner at home — and keep what works. The payoff day will be unglamorous and sudden: a queue, a dead zone, a roaming bill avoided. The phone that shrugs is the one whose apps were chosen for the real India, not the demo.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
 'archived', '2026-08-28 10:00:00+00', NULL,
 5,
 'Why Offline-First Apps Earn a Place on Your Phone | Bharat Tech Pulse',
 'Maps, document vaults, notes and tickets that keep working when the network does not — a practical case for offline-first apps in India.',
 'https://bharattechpulse.in/article/offline-first-apps-worth-installing',
 'Why Offline-First Apps Earn a Place on Your Phone',
 'Maps, document vaults, notes and tickets that keep working when the network does not — a practical case for offline-first apps in India.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
 false, false, false, 940, 'Productivity',
 '["Offline-first means the app treats no-signal as normal, sync as a bonus.","Pre-download maps and documents before the trip, not when the signal dies.","Keep an encrypted on-device document vault alongside cloud backups.","Local data demands a strong lock screen — prepare for both."]'::jsonb,
 '[{"question":"Do offline-first apps stay updated if I rarely go online?","answer":"Content like map tiles and prices age; connect on Wi-Fi weekly and let the sync run. The app working offline is not an excuse for the data on it drifting stale."},{"question":"Is cloud backup enough instead of on-device storage?","answer":"For tickets and documents you need at a dead zone, no — a cloud you cannot reach proves nothing. Keep an on-device copy and use the cloud as the disaster-redundancy layer, not the daily-access layer."}]'::jsonb,
 '[{"id":"what-offline-first-actually-means","title":"What Offline-First Actually Means"},{"id":"the-indian-cases-where-it-earns-its-space","title":"The Indian Cases Where It Earns Its Space"},{"id":"the-offline-first-toolkit-worth-carrying","title":"The Offline-First Toolkit Worth Carrying"},{"id":"the-habits-that-make-it-actually-work","title":"The Habits That Make It Actually Work"}]'::jsonb,
 '2026-08-24 09:00:00+00', '2026-10-04 12:00:00+00'),

-- ── 410 | How-To | published ───────────────────────────────────────────────
('00000000-0000-4000-8000-000000000410', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000104',
 'Organise Government Documents on Your Phone the Right Way',
 'organise-government-documents-on-your-phone',
 'PAN, passport, insurance, marksheets, property papers: a simple, safe system to keep every essential document reachable on your phone — and legible when the counter demands it.',
 E'## The Shelf You Actually Need\n\nA folder called "docs" with two hundred files is not organisation; it is a landfill with a label. The working system mirrors how documents are demanded at real counters — a police stop, a bank form, a hospital admission, a rental agreement. Create one parent folder, then four sub-folders: Identity (Aadhaar, PAN, passport, voter ID), Money (insurance policies, loan papers, salary slips, tax filings), Health (prescriptions, reports, vaccination records), and Life Events (marksheets, degree certificates, property papers, marriage documents). Every file goes in exactly one shelf, and the shelf that the counter would ask for first wins.\n\n## Name Files Like a Librarian, Not a Hoarder\n\nScreenshots arrive as Screenshot20261012_143245.png. Rename once, in a fixed pattern: documenttype_person_yyyy — pan_father_2026, insurance_mother_policy_2026, marksheet_sister_class12. The pattern makes files searchable in any app, sortable in any file manager, and instantly identifiable in a screenshot you text to a bank clerk. Do it at the moment of saving, never as a weekend project — the weekend project never comes.\n\n## Capture Quality Is a Real Requirement\n\nA blurry photo of a PAN card fails at counters and fails in your own memory of what it says. Three rules: fill the frame, shoot on a plain dark background under steady light, and check the digits before you delete the take. For multi-page documents, PDF-scan them into one file per document using any scanner app rather than a heap of loose images — one file that opens as one document is the format clerks expect and the format that survives forwarding.\n\n## The Two-Copy Safety Net\n\nYour phone is not a backup; it is one copy that can be stolen, drowned or factory-reset by your own toddler. Rule of two: an encrypted cloud backup for the whole folder, plus a periodic export to a physical drive at home. For the handful of documents that would end the week if lost — property deeds, base insurance, degree certificates — add a third: a printed set in a flat file, because no format invented so far has survived every technology change intact.\n\n## Lock It Like the Vault It Is\n\nDo not park document folders in the gallery. Keep them in the file app behind an app-lock or the phone''s secure folder, keep the lock screen itself strong, and turn off gallery auto-save for WhatsApp so random files never mingle with your shelf. When your phone is handed across a counter, it should open the requested PDF, not offer your whole life. And name your cloud backup account''s recovery details to a trusted person — document systems die with forgotten passwords.\n\n## The Family Version of This\n\nRun this setup once for your parents on their phone, then teach the naming pattern and the capture rules — thirty minutes that ends the annual "beta bhejo na" scramble for a document photo. When documents are organised, families stop losing hours; when they are organised and backed up, families stop losing documents entirely.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
 'published', '2026-10-05 16:00:00+00', NULL,
 5,
 'Organise Government Documents on Your Phone the Right Way | Bharat Tech Pulse',
 'A simple folder system, naming pattern and two-copy backup plan that keeps every essential Indian document reachable and counter-ready.',
 'https://bharattechpulse.in/article/organise-government-documents-on-your-phone',
 'Organise Government Documents on Your Phone the Right Way',
 'A simple folder system, naming pattern and two-copy backup plan that keeps every essential Indian document reachable and counter-ready.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
 false, false, false, 3980, 'Govt Services',
 '["Four shelves beat one messy folder: Identity, Money, Health, Life Events.","Rename files the moment you save them: doctype_person_year.","One clean PDF per document always beats twenty scattered screenshots.","Keep two digital copies plus printed originals for the irreplaceable few."]'::jsonb,
 '[{"question":"Should I store Aadhaar and PAN photos in the same folder as everything else?","answer":"Yes for reachability, with the folder itself behind a lock. The risk with ID documents is device loss, not organisation — a lost unlocked phone is dangerous however the files are named, so the app-lock and strong screen passcode are the real protection."},{"question":"My cloud backup app already saves everything — do I still need the drive copy?","answer":"A home drive protects against the account trouble cloud backups have: forgotten recovery details, provider changes, or a sync that quietly stopped. The two-copy rule is about independent failure, not duplicate comfort."},{"question":"Is a photo of a document accepted at counters?","answer":"Legally it varies and officials differ; a clear PDF on screen is treated as presentable in most daily situations, and digital-locked copies can be refused, so keep originals handy for serious transactions and treat the phone copy as the convenience layer."}]'::jsonb,
 '[{"id":"the-shelf-you-actually-need","title":"The Shelf You Actually Need"},{"id":"name-files-like-a-librarian-not-a-hoarder","title":"Name Files Like a Librarian, Not a Hoarder"},{"id":"capture-quality-is-a-real-requirement","title":"Capture Quality Is a Real Requirement"},{"id":"the-two-copy-safety-net","title":"The Two-Copy Safety Net"},{"id":"lock-it-like-the-vault-it-is","title":"Lock It Like the Vault It Is"}]'::jsonb,
 '2026-09-29 10:00:00+00', '2026-10-06 09:30:00+00'),

-- ── 411 | How-To | published ───────────────────────────────────────────────
('00000000-0000-4000-8000-000000000411', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000104',
 'Slow Wi-Fi? A Step-by-Step Troubleshooting Routine for Indian Homes',
 'home-wifi-troubleshooting-routine',
 'Before you anger the customer-care executive, run this fifteen-minute routine. Most Indian home Wi-Fi complaints are placement, congestion or settings — all fixable without a technician.',
 E'## First: Diagnose Before You Fix\n\nRun one honest test while sitting next to the router: if a speedtest is fine at the router and awful in the bedroom, you have a coverage problem — physics, not the ISP. If it is slow everywhere including next to the router, you have a line, plan or congestion problem. This fork saves most families an unnecessary support call. Also check the boring universal: is the slowdown on one device or all? One device means that device, not the network.\n\n## The Placement Fix That Beats Every Gadget\n\nWi-Fi is light in radio''s clothing: it hates distance, walls — especially bathrooms and kitchens with metal and moisture — and it despises being hidden. The single highest-impact change in Indian homes: move the router out of the TV-cabinet cupboard where it was buried, place it high, central and visible, away from microwaves and metal almirahs. If the router lives at one end of a long flat and life happens at the other, no configuration trick fixes geometry; consider a mesh node or powerline extender for the far rooms instead of chasing settings.\n\n## The Two Bands Are Different Tools\n\nModern routers broadcast 2.4 GHz and 5 GHz. The five-band is faster but dies quickly through walls; the 2.4-band is slower but reaches. Connect latency-sensitive devices — laptop calls, gaming — to 5 GHz when in the same room; give distant rooms and smart plugs the 2.4 GHz reach. Naming the bands differently in settings makes this choice visible and stops devices grabbing the wrong one. It is also worth checking a device is on Wi-Fi at all: many "slow internet" complaints are phones quietly sitting on mobile data.\n\n## Congestion Is Neighbourhood, Not Household\n\nFlats pack dozens of networks into one radio spectrum; the channel your router chose on its own at midnight may be a traffic jam by evening. Log in to the router admin page and switch the channel — auto-selection is usually lazy; a manual pick from the quieter end of the list can lift evening speeds noticeably. And count what is actually online: the four-month-old firmware update downloading on the kid''s tablet, the cloud photo backup running at nine in the morning, the smart TV streaming in the other room. Router admin pages show the talkers; some are worth scheduling for night.\n\n## The Router Reboot Is Not Folklore\n\nRouters are computers that accumulate memory crumbs and stuck sessions; a weekly reboot is free maintenance. Unplug for thirty seconds — the full pause matters — and restart while you are at the placement step anyway. If the box is several years old and never replaced, check its age honestly: ISP-provided entry boxes handle today''s plans and today''s device counts worse every year, and a better personal router usually fixes what support calls cannot.\n\n## When to Finally Call the ISP\n\nAfter the routine: slow next to the router on every device, rebooted, re-placed, re-channels and still bad — that is a line problem, and now you can tell the executive exactly what you ruled out, which changes the conversation from scripts to tickets. Note the pattern — evening-only slowness is often congestion on your plan or the area''s tower, and the fix may be a plan tier or a fair-usage conversation, not hardware. The routine will not fix a cut cable, but it fixes — permanently — most of what families were paying technicians for.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
 'published', '2026-10-02 12:00:00+00', NULL,
 6,
 'Slow Wi-Fi? A Step-by-Step Troubleshooting Routine for Indian Homes | Bharat Tech Pulse',
 'A fifteen-minute, technician-free routine to fix Indian home Wi-Fi: diagnose coverage, move the router, pick the right band, dodge channel congestion.',
 'https://bharattechpulse.in/article/home-wifi-troubleshooting-routine',
 'Slow Wi-Fi? A Step-by-Step Troubleshooting Routine for Indian Homes',
 'A fifteen-minute, technician-free routine to fix Indian home Wi-Fi: diagnose coverage, move the router, pick the right band, dodge channel congestion.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
 false, false, false, 2760, '',
 '["Test next to the router first: coverage problems and line problems need different fixes.","Move the router high, central and visible — the cupboard is where signals go to die.","Use 5 GHz for nearby fast devices, 2.4 GHz for distant rooms.","A thirty-second unplug-and-reboot weekly is free maintenance, not superstition."]'::jsonb,
 '[{"question":"Do Wi-Fi booster apps actually work?","answer":"No app changes your radio physics or your landlord''s router. The real boosters are placement, band choice and channel selection — all free and done in the router''s own admin page."},{"question":"Is a mesh system worth it for a three-bedroom flat?","answer":"If one honest test shows signal fine at the router and dead two rooms away, and the walls are thick, mesh is the geometry fix that settings cannot fake. For smaller homes, one well-placed router or a single powerline extender usually suffices."},{"question":"My evening speed is always worse than morning. Fix?","answer":"That is congestion — your building''s shared line or the neighbourhood spectrum, not your phone. Check for family devices scheduling evening updates, and if it persists, raise the pattern specifically with the ISP: time-shaped slowdown is a plan or capacity conversation."}]'::jsonb,
 '[{"id":"first-diagnose-before-you-fix","title":"First: Diagnose Before You Fix"},{"id":"the-placement-fix-that-beats-every-gadget","title":"The Placement Fix That Beats Every Gadget"},{"id":"congestion-is-neighbourhood-not-household","title":"Congestion Is Neighbourhood, Not Household"},{"id":"when-to-finally-call-the-isp","title":"When to Finally Call the ISP"}]'::jsonb,
 '2026-09-26 09:00:00+00', '2026-10-02 15:20:00+00'),

-- ── 412 | How-To | draft ───────────────────────────────────────────────────
('00000000-0000-4000-8000-000000000412', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000104',
 'The New Phone First-Week Checklist: Setup That Pays Off for Years',
 'new-phone-first-week-checklist',
 'Migration excitement makes everyone skip the boring settings that decide a phone''s next three years. This first-week checklist locks in backup, security and sanity before the habits set.',
 E'## Day One: Backup Before You Admire\n\nThe one regret every phone owner shares is the migration gap — the days when the old phone held the photos and the new one held the hope. Before play, confirm the old device''s photos, chats and documents actually completed their upload, then restore onto the new phone in one sitting: accounts first, photos second, chats third, documents last. Only after the last family photo is verified on the new screen should the old phone be factory-reset. The five-star review can wait one honest afternoon; the backup cannot.\n\n## Day Two: The Security Bones\n\nThree settings decide how boring a theft becomes: a strong lock — biometrics backed by a passcode you have actually written down somewhere safe, because fingerprints wear off and faces fail at police stations; find-my-device switched on and verified working by a test ring right now, not discovered broken during the panic; and two-factor enabled on the mail account that owns everything else, with recovery codes saved offline. While here, review notification access on the lock screen: bank OTPs arriving visible to a stranger glancing at your buzzes is a design choice, not fate.\n\n## Day Three: The Permission Cleanse\n\nA new phone is the one moment apps are re-installed one by one — so give each the permission audit as it lands: deny first, allow in context later. It takes a minute per app now and saves the monthly recheck forever. Resist pre-loading everything; install what you use weekly this month and let the rest come back when needed. The new phone''s emptiness is a feature — most clutter is just migration without a filter.\n\n## Day Four: Health for the Handset and the Human\n\nGive the battery a working rule that matches your life rather than forum folklore — overnight charging on a modern phone is managed, heat and deep discharges are the habits worth avoiding. Then the human settings: screen-time boundaries for the household, night mode scheduled before your actual sleep hour, and the home-screen purge — the apps you want your thumb reaching for first, not the ones the setup wizard installed for you. A phone configured by its owner in week one stays configured; a default phone reverts to factory chaos by week four.\n\n## Day Five to Seven: The Verification Round\n\nSetups fail quietly in the details, so test, do not trust: restore from backup onto settings and confirm the cloud actually saved; back up the chat that matters; try the lock-screen camera shortcut in a rush; confirm bank alerts arrive with the phone silent; check what the kids can install without asking. Seven checks, fifteen minutes, and the phone is a configured instrument rather than a decorated box.\n\n## The One-Line Rule\n\nA new phone earns its upgrade in the first week: the habits set now — where photos live, what can buzz at dinner, who can add money with a fingerprint — run for the next three years whether you planned them or not. Set them deliberately, once, now.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
 'draft', NULL, NULL,
 5,
 'The New Phone First-Week Checklist: Setup That Pays Off | Bharat Tech Pulse',
 'Backup, security bones, permission cleanse and verification rounds: the first-week checklist that decides your phone''s next three years.',
 'https://bharattechpulse.in/article/new-phone-first-week-checklist',
 'The New Phone First-Week Checklist: Setup That Pays Off for Years',
 'Backup, security bones, permission cleanse and verification rounds: the first-week checklist that decides your phone''s next three years.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
 false, false, false, 0, 'Android Tweaks',
 '["Verify the old phone''s upload completed before resetting it — the migration gap is where memories die.","Turn on find-my-device and test it the same day you enable it.","Re-install with a permission audit per app; do not clone your old clutter.","Run a fifteen-minute verification round before week two begins."]'::jsonb,
 '[{"question":"Should I factory-reset the old phone immediately?","answer":"Only after the new phone visibly holds everything — photos opened, chats restored, documents downloaded — and the old phone has had its own second backup. Resetting on faith is how one-tap regrets happen."},{"question":"Do I need a screen protector and case before first use?","answer":"For Indian family reality — outdoor use, monsoon, small children — yes, this is the rare accessories case that pays for itself. Resale value is just the bonus; the repair bill avoided is the main return."},{"question":"How much of this matters for a secondary phone?","answer":"Day one, day two and the verification round matter on any phone that holds accounts; the permission cleanse and health settings scale down with use, not price."}]'::jsonb,
 '[{"id":"day-one-backup-before-you-admire","title":"Day One: Backup Before You Admire"},{"id":"day-two-the-security-bones","title":"Day Two: The Security Bones"},{"id":"day-three-the-permission-cleanse","title":"Day Three: The Permission Cleanse"},{"id":"day-five-to-seven-the-verification-round","title":"Day Five to Seven: The Verification Round"},{"id":"the-one-line-rule","title":"The One-Line Rule"}]'::jsonb,
 '2026-10-21 11:00:00+00', '2026-10-25 09:45:00+00'),

-- ── 413 | Tech Updates | published ─────────────────────────────────────────
('00000000-0000-4000-8000-000000000413', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000105',
 'Digital Public Infrastructure, Explained Simply: What It Means for Your Family',
 'digital-public-infrastructure-explained-simply',
 'UPI, DigiLocker, ONDC, CoWIN-style health stacks: India runs on a set of shared digital rails most of us use daily without meeting by name. Here is the plain-language map.',
 E'## The Plumbing Behind the Daily Ten Minutes\n\nDigital public infrastructure — DPI — is the unglamorous name for the shared digital rails the country built so that services do not each invent their own: a way to pay instantly (UPI), a way to prove who you are and hold your documents (Aadhaar authentication and DigiLocker), a way for goods markets to interoperate (ONDC), and the data stacks behind health and education services. You have personally used several of these before breakfast, and their design goal was exactly that: infrastructure you never have to think about, the way you never think about the water mains.\n\n## Why ''Public'' Is the Point\n\nPrivate apps compete; public infrastructure cooperates. The rails are open enough that banks, wallets and shops can all plug in, which is why the same QR at a kirana counter works from half a dozen apps. For families this creates two practical protections worth internalising: you are rarely locked to one app — if your favourite wallet annoys you, the rail still works from any other — and the government-facing services do not disappear if a startup shuts down. When you hear "platform", think landlord; when you hear "infrastructure", think road.\n\n## The Consumer''s Map: Four Rails, Four Habits\n\nPayments: treat instant UPI as cash and scheduled bills as cards — keep the small-day spending on the rail with limits, and keep the big-ticket purchases wherever disputes are easiest to open. Documents: DigiLocker and its equivalents are for convenience copies; the physical originals remain the legal heavyweight — the phone copy speeds the queue, not the court. Commerce: ONDC-style open networks price differently because commissions differ, so comparing one restaurant across apps is a legitimate, useful habit. Civic: state portals and central services increasingly expect a verified phone number and a DigiLocker-backed login — keep that stack tidy with the same care you keep keys.\n\n## Where DPI Meets the Scam Economy\n\nOpen rails invite clever abuse: QR-code dropping, fake "received payment" screenshots, and calls invoking the very infrastructure you trust. The counter-habits are boring and effective: verify money actually entered your account before handing over goods — the SMS is not the ledger; never share OTPs against "received" payments you did not initiate; and remember that no legitimate agency demands a transfer to "verify" anything. Infrastructure is neutral; the fraud industry is simply the toll on the road, and the toll booth is your own two-step check.\n\n## The Data Question Families Should Keep Asking\n\nDPI concentrates digital life: more documents, payments and history flowing through fewer, bigger systems. That is efficient and it is a risk in the same sentence. The reasonable household posture: use the rails, minimise what you hand over — share document copies only with the mask or partial-number options where available, keep consent notices readable rather than skimmable, and hold institutions accountable through complaints channels and consumer forums when data is misused. Rights under India''s data-protection law are real, but they activate when someone exercises them.\n\n## Living Comfortably on the Rails\n\nThe families best adapted to Indian DPI are not the earliest adopters; they are the most deliberately redundant: two payment routes, one calm document system, one habit of verification, one shared understanding of what the phone may never be asked to do. The rails will keep upgrading quietly in the background. Your job is smaller than it looks: keep the habits sharp enough that convenience never outruns caution.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
 'published', '2026-09-30 10:00:00+00', NULL,
 6,
 'Digital Public Infrastructure, Explained Simply for Indian Families | Bharat Tech Pulse',
 'UPI, DigiLocker, ONDC and the rails beneath them: a plain-language map of India''s digital public infrastructure and the family habits that fit it.',
 'https://bharattechpulse.in/article/digital-public-infrastructure-explained-simply',
 'Digital Public Infrastructure, Explained Simply: What It Means for Your Family',
 'UPI, DigiLocker, ONDC and the rails beneath them: a plain-language map of India''s digital public infrastructure and the family habits that fit it.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
 false, false, false, 3400, 'Policy & DPDP',
 '["DPI is shared rails — payments, identity, documents, commerce — designed to be invisible.","Open rails mean no app lock-in: the same QR works from many apps.","Verify money in your account, not in an SMS screenshot, before goods move.","Use the rails, minimise data handed over, and exercise your data rights deliberately."]'::jsonb,
 '[{"question":"Is DPI the same as government apps?","answer":"No — the rails are the shared systems; many private apps are built on top of them. You experience DPI every time two different apps can talk to the same QR, and the distinction is why no single app owns your digital life."},{"question":"What happens if a rail changes or shuts down?","answer":"Core rails are built with redundancy and rule-sets precisely because the whole economy sits on them; the realistic family risk is smaller — an app you personally lean on disappearing. Keep the habit of one alternative route per critical task."},{"question":"Should elderly family members use UPI at all?","answer":"With limits, a linked trusted person for big approvals where the app offers delegation features, and the verify-before-handover rule taught once, the rails are as safe for them as the cash habits they replace — the risks are scam patterns, which are teachable."}]'::jsonb,
 '[{"id":"the-plumbing-behind-the-daily-ten-minutes","title":"The Plumbing Behind the Daily Ten Minutes"},{"id":"why-public-is-the-point","title":"Why ''Public'' Is the Point"},{"id":"the-consumers-map-four-rails-four-habits","title":"The Consumer''s Map: Four Rails, Four Habits"},{"id":"where-dpi-meets-the-scam-economy","title":"Where DPI Meets the Scam Economy"},{"id":"the-data-question-families-should-keep-asking","title":"The Data Question Families Should Keep Asking"}]'::jsonb,
 '2026-09-24 09:00:00+00', '2026-09-30 14:10:00+00'),

-- ── 414 | Tech Updates | published | trending ──────────────────────────────
('00000000-0000-4000-8000-000000000414', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000105',
 'Why App Permissions and Data Consent Are Changing in India: A Consumer Reading Guide',
 'app-permission-consent-changes-india-reading-guide',
 'Consent screens are getting longer, permission prompts more polite, and deletion buttons suddenly real. A reading guide to what India''s evolving privacy rules actually change for you.',
 E'## The Longest-Read Document in Your Life\n\nNobody has ever read a privacy policy, and companies knew it — consent by burying was the default business model for a decade. That is bending. India''s data-protection framework is pushing consent toward what it always claimed to be: specific, informed, and revocable. For consumers the practical change is a set of small UI shifts worth learning to read: permission asks that explain themselves, consent managers that list every company holding your data, and delete and grievance buttons that exist because a rule now says they must.\n\n## What ''Valid Consent'' Looks Like Now\n\nRead any new app''s first minute through three filters. Specific: is each purpose named separately, or is one blanket "I agree" bundling payments, marketing and profiling? Informed: does the ask tell you what you give up, in words, not just links? Freely given: does the app actually work when you decline the non-core ones — or does refusing "optional" marketing grant you a refusal of service? That last test is the loudest signal of a company''s honest posture, and it is one you can perform yourself, no lawyer required.\n\n## The Consent Manager Habit\n\nThe genuinely new power for Indian users is inventory: a single place to see which entities hold your consent, and to withdraw it with a few taps instead of emails and legal notice. Make it a yearly habit like a health check-up: open the manager, list the companies, withdraw everything you no longer use — the fintech you tried once, the shopping app you replaced. Data you reclaimed this way is quiet leverage against exactly the breach headlines you read about.\n\n## Permissions Are Now a Negotiation, Not a Surrender\n\nThe old flow: app asks for the contacts and gallery, you tap allow to get your bill paid. The newer flow, pushed by both the operating systems and the rules: ask only for what the feature needs, ask at the moment of need, and accept no. Use the friction as information. When an app suddenly insists on the entire address book for its core service, that insistence is a policy statement about its business model, and you now have both the legal backdrop and the settings screen to say no and mean it.\n\n## Grievance Officers and the Complaint Path\n\nEvery app that processes Indian data now names a grievance contact as a matter of course. Most users will never need it; the ones who do discover it changes everything — an unanswered "delete my account and data" request escalated through the named officer, and then the appellate path, moves in weeks where ignoring used to be permanent. Save the officer''s email at install, not at crisis; the entire complaint genre begins with a timestamped written request.\n\n## Reading the Change Without Hype\n\nNone of this makes privacy effortless — enforcement is still young, and the strongest lever remains the oldest: choosing apps that need less of you. But the direction is real: consent that can be withdrawn, permissions that can be refused, and a paper trail that companies must answer. The modern Indian consumer''s job is smaller than fighting giants and bigger than tapping agree: read the three filters yearly, use the manager, and keep the receipts.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
 'published', '2026-09-28 09:00:00+00', NULL,
 6,
 'App Permissions and Data Consent in India: A Consumer Reading Guide | Bharat Tech Pulse',
 'What India''s evolving privacy rules actually change for daily app use: valid consent, consent managers, permission refusal and the grievance path.',
 'https://bharattechpulse.in/article/app-permission-consent-changes-india-reading-guide',
 'Why App Permissions and Data Consent Are Changing in India: A Consumer Reading Guide',
 'What India''s evolving privacy rules actually change for daily app use: valid consent, consent managers, permission refusal and the grievance path.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
 false, true, false, 2200, 'Policy & DPDP',
 '["Valid consent is specific, informed and freely given — test all three on install day.","Use the consent manager yearly to see and withdraw old data permissions.","An app''s reaction to ''no'' on optional permissions reveals its real business model.","Save the grievance officer''s contact at install; escalate delete requests in writing."]'::jsonb,
 '[{"question":"Does withdrawing consent delete everything companies took earlier?","answer":"Withdrawal stops future processing under the consent framework; data already collected can be requested for erasure through the same channels. Keep the written request and the response timeline — the paper trail is the mechanism."},{"question":"Should I stop using apps before they show a consent screen?","answer":"No — the screens are the leverage. Install, apply the three filters, decline the optional bundles, and let the app''s behaviour under refusal tell you what kind of company you are dealing with."},{"question":"Do these rules cover foreign apps used from India?","answer":"The rules follow the user and the data, not the company''s headquarters, which is why Indian-facing services increasingly ship Indian consent flows and named grievance officers. If a service refuses to show either, that absence is itself an answer about its posture."}]'::jsonb,
 '[{"id":"the-longest-read-document-in-your-life","title":"The Longest-Read Document in Your Life"},{"id":"what-valid-consent-looks-like-now","title":"What ''Valid Consent'' Looks Like Now"},{"id":"the-consent-manager-habit","title":"The Consent Manager Habit"},{"id":"grievance-officers-and-the-complaint-path","title":"Grievance Officers and the Complaint Path"},{"id":"reading-the-change-without-hype","title":"Reading the Change Without Hype"}]'::jsonb,
 '2026-09-21 10:00:00+00', '2026-09-28 12:30:00+00'),

-- ── 415 | Tech Updates | scheduled 2026-10-20 ──────────────────────────────
('00000000-0000-4000-8000-000000000415', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000105',
 'Why Chip News Matters Even When It''s Boring: Semiconductors in Daily Life',
 'why-chip-news-matters-semiconductors-daily-life',
 'Fabrication plants, packaging units, mature nodes: the vocabulary of semiconductor news sounds far from home. It is actually the supply chain of your phone, your bill and your next job.',
 E'## The Invisible Substrate of Visible Life\n\nEvery story this site covers — the phone review, the UPI outage, the smart-TV deal — sits on a physical base nobody photographs: chips. Semiconductors run the traffic signals, the bank servers, the tractor sensors and the meter you argue with. When chip news is boring, that boredom is usually the system working quietly; when it suddenly is not boring — shortages, export controls, a factory fire somewhere — the effects surface in Indian shops months later as price, availability, or a launch delayed. Reading a little chip news is not tech cosplay; it is reading the weather of the physical economy.\n\n## Mature Nodes: Why the Unexciting Chips Are the Nation-Building Ones\n\nHeadline semiconductors chase the smallest, most exotic process nodes; the everyday economy runs on mature nodes — the workhorse chips in appliances, vehicles, payment terminals and power systems. A country that can design and package these reliably does not need to win the frontier race to secure its supply chains; it needs factories, engineers and logistics for the unglamorous silicon majority. This is why India''s semiconductor push centres on these chips, and why the honest measure of success will be quiet things: components in an electric two-wheeler, a meter, a hospital device — not smartphone bragging specs.\n\n## The Jobs Story Behind the Fab Story\n\nChip headlines usually count dollars; families should notice degrees. Fabrication and packaging plants create dense ecosystems: technicians, tool handlers, design and verification engineers, test and validation roles — and the VLSI and microelectronics programmes expanding in Indian universities exist precisely to staff them. For students deciding streams, the honest signal is not a fab''s inauguration date but the growing middle of the industry: design services, assembly-test-packaging, and the component ecosystem that arrives a factory does not.\n\n## What Consumers Actually Feel\n\nWhen you do feel chip news, it arrives disguised: your phone''s launch slips because a controller chip was shorted; the "sale price" on a television is the first price in months because panel supply loosened; a laptop tier disappears because a chipset generation ended. None of these appear in the gadget page under their real cause. The practical habit: understand that gadget pricing and availability are downstream of a supply chain — so waiting a quarter or accepting last year''s model is often a supply-chain decision wearing the costume of a bargain.\n\n## Reading the Policy Layer Without the Hype\n\nSemiconductor policy is genuinely consequential and genuinely slow: incentives announced are not chips shipped, and the honest timeline is measured in years of construction, calibration and yield learning. The useful reader''s filter: watch for factory milestones that are verifiable and unglamorous — equipment moving in, wafers moving out — rather than signing-ceremony milestones. The industry, like the site''s audience, rewards patience and punishes theatre.\n\n## The Dinner-Table Frame\n\nThe families who benefit from "boring" chip news are the ones who borrow the frame: devices are physical, supplies are finite, and the gap between "launched" and "available in Nagpur in quantity" is where the real world lives. Keep reading the small print of the big industry; your phone, your bills and your child''s engineering choices all live on the substrate.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
 'scheduled', NULL, '2026-10-20 10:00:00+00',
 6,
 'Why Chip News Matters Even When It''s Boring: Semiconductors in Daily Life | Bharat Tech Pulse',
 'Mature nodes, fabs and the supply chain beneath your phone, your bills and India''s engineering jobs — a consumer''s guide to semiconductor news.',
 'https://bharattechpulse.in/article/why-chip-news-matters-semiconductors-daily-life',
 'Why Chip News Matters Even When It''s Boring: Semiconductors in Daily Life',
 'Mature nodes, fabs and the supply chain beneath your phone, your bills and India''s engineering jobs — a consumer''s guide to semiconductor news.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
 false, false, false, 0, 'Semiconductors',
 '["Chip news is boring when the system works; it surfaces at your shop months later when it does not.","Mature-node chips — not frontier ones — run appliances, vehicles and meters.","Verify fab progress by equipment-in and wafers-out milestones, not signing ceremonies.","Launch delays and price drops are often supply-chain weather wearing a bargain costume."]'::jsonb,
 '[{"question":"I am a student — should I choose electronics or software for the chip wave?","answer":"Both ends hire: chip design leans on strong fundamentals and tooling skills, manufacturing leans on electronics and process engineering. The safer signal is curiosity about how things are made, because the industry''s growth is broad — design services and packaging employ far more people than the headline fabs alone."},{"question":"Will Indian fabs actually lower my phone''s price?","answer":"Modestly and slowly: phones are globally priced, and mature-node gains land first in appliances, meters and vehicle components before your gadget bill reads them. Expect patience, then quiet benefit."},{"question":"Is this topic only for tech people?","answer":"It is mostly for buyers: availability, pricing cycles and repair ecosystems are chip-news consequences. Reading the frame turns a \"sold out\" or a delayed launch from frustration into forecast."}]'::jsonb,
 '[{"id":"the-invisible-substrate-of-visible-life","title":"The Invisible Substrate of Visible Life"},{"id":"mature-nodes-why-the-unexciting-chips-are-the-nation-building-ones","title":"Mature Nodes: Why the Unexciting Chips Matter"},{"id":"the-jobs-story-behind-the-fab-story","title":"The Jobs Story Behind the Fab Story"},{"id":"what-consumers-actually-feel","title":"What Consumers Actually Feel"},{"id":"reading-the-policy-layer-without-the-hype","title":"Reading the Policy Layer Without the Hype"}]'::jsonb,
 '2026-10-14 09:00:00+00', '2026-10-16 11:30:00+00'),

-- ── 416 | Comparisons | published | popular ────────────────────────────────
('00000000-0000-4000-8000-000000000416', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000106',
 'Android or iPhone for Your Parents? A Decision Framework for the Family',
 'android-or-iphone-for-your-parents',
 'Forget the brand war. Choosing your parents'' next phone is a family-support question, not a specs question — here is the framework that decides it correctly.',
 E'## Reframe: You Are Buying a Support Relationship\n\nWhen you choose your parents'' phone, you are also choosing which device you can remotely troubleshoot at ten at night, which emergency features their hands can reach, and which ecosystem their dearest contacts — you, the grandchildren, the old friends — already live in. The brand debate people wage online is irrelevant here; the support geometry of your actual family decides everything. Write the real requirements first: who will help when it breaks, what must work in one tap, and which existing family tools the phone must speak to.\n\n## The One Question That Sorts Most Families\n\nWhose phone does the household already understand? If you and the grandchildren are on iPhone and the WhatsApp video-call panic button is you, an iPhone for your parents means someone at the other end of the call who has the same screen. If the family is Android-all-the-way, the same logic points the other direction. Shared platforms turn "beta kar bhejo na" into an actual solvable instruction. This one consideration outweighs almost every spec difference in the segment.\n\n## Android''s Honest Strengths for Older Users\n\nChoice and fit: Android ships phones in every size, price and weight, so a parent with stiff fingers or poor near-vision can find a large, light, big-button device rather than settling. Sideloading and file access matter in Indian households where APKs arrive through family groups — with the obvious caution that the same openness is why the permission audit and Play-only install habits must be taught once, carefully. Simple mode and launcher customisation on many brands go genuinely far for elderly eyes and thumbs.\n\n## iPhone''s Honest Strengths for Older Users\n\nConsistency and longevity: the interface stays the same across years and devices, updates arrive for many years so the "this button moved" complaint fades, and the ecosystem''s guardrails — curated installs, stricter app vetting — close some of the scam doorways that Indian elders are specifically targeted through. Emergency features and health-oriented tools are cohesive when the family is already Apple-native. The trade-ins are real too: fewer size choices, higher entry cost, and one fewer family member who can fix it remotely if your household runs Android.\n\n## The Wallet Is Part of the Argument\n\nDecide ownership years honestly, then let budget follow the frame rather than the reverse. The per-year maths for a phone your parents will hand you to fix is the same maths from any longevity conversation; it matters more here because their next upgrade may depend on your mood and month. Whichever platform fits, resist the reflex discount: the phone that dies in year two strands them with a cracked old device and a data migration you will do at midnight.\n\n## Run the Thirty-Minute Trial at Home\n\nBefore deciding, stage the actual life: install their apps, size the text, put your contact as the speed-dial, test the loudness in their kitchen, ask them to answer a video call and a bank OTP unassisted. The phone that passes a Tuesday-dinner rehearsal — without you touching it — is the right platform, whatever its logo. The framework ends where all good family tech advice ends: not which phone wins the internet''s argument, but which phone your family can support, tonight, without a manual.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
 'published', '2026-09-25 13:30:00+00', NULL,
 6,
 'Android or iPhone for Your Parents? A Family Decision Framework | Bharat Tech Pulse',
 'Choosing a phone for elderly parents is a support question, not a specs debate. A practical framework every Indian family can run in thirty minutes.',
 'https://bharattechpulse.in/article/android-or-iphone-for-your-parents',
 'Android or iPhone for Your Parents? A Decision Framework for the Family',
 'Choosing a phone for elderly parents is a support question, not a specs debate. A practical framework every Indian family can run in thirty minutes.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
 false, false, true, 3050, 'Phone Battles',
 '["You are choosing a support relationship, not a brand.","Whose platform the household can troubleshoot outweighs most specs.","Android offers fit and customisation; iPhone offers consistency and guardrails.","Rehearse real life — their apps, their kitchen, your speed-dial — before you decide."]'::jsonb,
 '[{"question":"Is the switch cost worth it if my father has used Android for ten years?","answer":"Usually not for interface reasons alone — muscle memory is a genuine accessibility feature. Reconsider only if a serious family-support argument points the other way, and then budget a month of patient hand-holding as part of the price."},{"question":"Do elderly-mode apps fix the difference either way?","answer":"They narrow gaps substantially on both platforms, but they do not change the support geometry: whoever remotely fixes the phone still needs to see the same screen. Simplification apps are helpers, not tie-breakers."},{"question":"What about shared family photos and accounts?","answer":"Decide the photo habit before the phone: one shared cloud album works within either ecosystem, but mixing platforms without an agreed route is why grandparents'' albums end up stranded. Make the photo pipeline the first setup task."}]'::jsonb,
 '[{"id":"reframe-you-are-buying-a-support-relationship","title":"Reframe: You Are Buying a Support Relationship"},{"id":"androids-honest-strengths-for-older-users","title":"Android''s Honest Strengths for Older Users"},{"id":"iphones-honest-strengths-for-older-users","title":"iPhone''s Honest Strengths for Older Users"},{"id":"the-wallet-is-part-of-the-argument","title":"The Wallet Is Part of the Argument"},{"id":"run-the-thirty-minute-trial-at-home","title":"Run the Thirty-Minute Trial at Home"}]'::jsonb,
 '2026-09-19 10:00:00+00', '2026-09-25 17:00:00+00'),

-- ── 417 | Comparisons | published ──────────────────────────────────────────
('00000000-0000-4000-8000-000000000417', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000106',
 'Laptop, Desktop or Mini PC: Choosing the Right Shape for a Home Study Corner',
 'laptop-vs-desktop-vs-mini-pc-home-study',
 'Same budget buys three very different lives depending on the shape you choose. A criteria-first comparison for Indian households setting up a study or work corner at home.',
 E'## The Real Axis: Movement, Not Money\n\nThe first honest question is not performance — modern machines in every shape handle school, office and creative work fine — it is where the computing happens. A laptop serves children who move between rooms, parents who work from the sofa on calls, and households whose study "corner" is the dining table at exam time. A desktop or mini PC serves a fixed desk in a fixed room, and pays you back in screen size, comfort and upgrade freedom at the same rupees. A family that moves needs one; a family with a dedicated corner can thrive on the other. Buying the wrong shape is the most common and least reversible mistake in this whole comparison.\n\n## Total Cost Tells a Different Story Than Price\n\nA desktop budget stretches further: separate monitor, keyboard and mouse cost less together than a laptop screen alone, and the machine is cheaper per unit of performance. A mini PC sits in between — cheap box, monitor extra. A laptop folds it all into one price and one hinge. Run the three-column maths on your own list: the machine, the monitor or screen you actually want, the chairs and desk it implies, and the repair pattern for your city. The shape with the lower sticker often ends up the pricier household project.\n\n## Repair, Upgrade and the Indian Service Map\n\nHere the shapes separate sharply. Desktops are modular by law of physics: parts fail, parts get replaced, and any neighbourhood shop can service them; a five-year-old desktop stays alive cheaply. Mini PCs are simpler still but tighter inside. Laptops concentrate their life into one fragile integration — the battery swells, the hinge cracks, the keyboard dies, and each event is a service-centre bill or a grave. For a family that plans to hand the machine down siblings over years, desktop or mini-PC longevity is a genuine financial feature. For a student who needs the machine at the library, no durability argument survives irrelevance: get the laptop.\n\n## The Human Factors Everyone Forgets\n\nPosture is a feature: a laptop at table height bends a thirteen-year-old spine; a desktop with a proper monitor and chair holds it straight — or a laptop on a stand with an external keyboard fixes it cheaply. Shared-family friction is another: a fixed machine teaches turn-taking and keeps use visible to parents; a personal laptop teaches privacy and hides everything. There is no universally better answer, but a family should choose its value deliberately instead of discovering the trade-off during a report-card argument. The cable-and-power reality of Indian homes matters too: a desktop needs a stabiliser-worthy socket; a laptop shrugs outages on its battery — during load-shedding seasons that is a genuine productivity feature.\n\n## The Hybrid That Wins Most Households\n\nFor one-machine families, the strongest pattern is the pair: a fixed desktop or mini PC as the household workhorse at the study desk, plus the cheapest adequate phone-and-tablet reality for away-hours. For a college-bound student, the laptop is the right single machine — bought with a case, a pad and an extended warranty, precisely because its fragility is now the price of its usefulness. Decide which life the machine lives, then buy the shape that serves that life, not the spec sheet that flatters it.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
 'published', '2026-09-22 15:00:00+00', NULL,
 6,
 'Laptop vs Desktop vs Mini PC for a Home Study Corner | Bharat Tech Pulse',
 'A criteria-first comparison — movement, total cost, repairability and posture — to choose the right computer shape for an Indian home.',
 'https://bharattechpulse.in/article/laptop-vs-desktop-vs-mini-pc-home-study',
 'Laptop, Desktop or Mini PC: Choosing the Right Shape for a Home Study Corner',
 'A criteria-first comparison — movement, total cost, repairability and posture — to choose the right computer shape for an Indian home.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
 false, false, false, 1600, '',
 '["Choose by where computing happens in your home, not by specs.","Total cost includes monitor, furniture and the city''s repair pattern.","Desktops and mini PCs win upgrade and longevity; laptops win necessity.","Posture and supervision are family values to decide deliberately."]'::jsonb,
 '[{"question":"Can a mini PC genuinely do what a desktop does for the kids'' projects?","answer":"For school, office and typical creative work, yes — the practical difference is integration: fewer ports, one shared component set, slightly higher upgrade ceilings reached sooner. The shape saves rupees and space, not capability."},{"question":"Is a used office desktop a legitimate option?","answer":"One of the best-value moves in Indian home computing — corporate-fleet machines with a new SSD and a monitor often outperform same-price new laptops. Buy knowing the model, demand the warranty in writing, and budget the first year''s power protection honestly."},{"question":"My child needs a laptop for college but we cannot afford a good one — is a cheap laptop a mistake?","answer":"A very cheap laptop that dies yearly costs more than a mid-range one that survives the degree; if the budget is genuinely fixed, the honest options are a refurbished business laptop or the desktop-plus-library-hours combination, not a new bottom-shelf machine."}]'::jsonb,
 '[{"id":"the-real-axis-movement-not-money","title":"The Real Axis: Movement, Not Money"},{"id":"total-cost-tells-a-different-story-than-price","title":"Total Cost Tells a Different Story Than Price"},{"id":"repair-upgrade-and-the-indian-service-map","title":"Repair, Upgrade and the Indian Service Map"},{"id":"the-hybrid-that-wins-most-households","title":"The Hybrid That Wins Most Households"}]'::jsonb,
 '2026-09-15 10:00:00+00', '2026-09-22 18:05:00+00'),

-- ── 418 | Comparisons | scheduled 2026-10-28 ───────────────────────────────
('00000000-0000-4000-8000-000000000418', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000106',
 'Prepaid or Postpaid: How to Choose Based on Your Actual Usage Pattern',
 'prepaid-vs-postpaid-how-to-choose',
 'The plan you overpay for is invisible because it bills quietly. A usage-first method — not a rate-card argument — to settle the prepaid-versus-postpaid question for every phone in your house.',
 E'## Start With Evidence, Not Opinions\n\nEvery telecom conversation in India begins with someone''s cousin''s plan. Begin instead with your own month: open the carrier app and read the usage statement — data consumed, call minutes, recharge history, what actually expired unused. This five-minute evidence pass does two jobs: it shows your real pattern, and it shows the shape of what you are wasting. The prepaid-versus-postpaid question never has one answer; it has an answer per person per pattern, which is exactly why the family audit is worth doing once a year together.\n\n## What Each Billing Shape Actually Is\n\nPrepaid is a budget with a deadline: you buy a pack, its rules — validity, data caps, fair-usage limits — govern the period, and the discipline is built in because when it runs out, it runs out. Postpaid is a meter: services flow, one bill arrives, overage is possible, and predictability is the product you are buying. The classic confusion is treating them as price competitions — they are different instruments. A careful prepaider who matches packs to real use often pays less; a postpayer buys the no-thinking premium. Know which of the two you are actually paying for.\n\n## The Pattern Test: Four Questions\n\nAsk, honestly: Does your data use spike irregularly — a travel month, a project — or sit steady? Spiky suits prepaid''s buy-what-you-need flexibility; steady suits postpaid''s flat predictability. Do you hate recharge days? That is not laziness, it is a real cost — the mental overhead of expiry-tracking is exactly what postpaid sells relief from. Does anyone in the family run slightly over the edge every month — the 2 GB extra, the fifteen minutes of calls? Those near-misses are what postpaid smooths and prepaid punishes. And finally: would a shared family plan pool the waste? Postpaid family structures exist precisely because five people five plans is five times the dead data.\n\n## The Two-Number Rule for Indian Households\n\nWrite down two numbers per person: typical monthly data and typical monthly voice. Everything else in telecom advertising is decoration. With those two numbers, rate-card maths is mechanical: whichever shape covers the numbers with the least surplus wins — surplus being the data and validity that expire unused, the truest hidden tax in Indian telecom. Families that audit this jointly once a quarter discover the same two findings every time: the eldest sibling is over-provisioned, and the grandparent''s plan has quietly expired into pay-as-you-dial.\n\n## Where the Old Fears Are Now Obsolete\n\nBoth shapes work on the same networks; coverage arguments between prepaid and postpaid are folklore from a different era. Roaming behaves similarly on modern packs and plans; what still differs is flexibility — prepaid lets a casual user recharge only in months they actually travel or need data, which beats postpaying for a dormant connection. The one genuinely postpaid advantage worth keeping: a consistent billing trail, which doubles as documentation for everything from visa financials to expense records.\n\n## Decide per Phone, Revisit per Season\n\nThe correct answer in most Indian families is a mix: steady heavy users on a sensible postpaid or long-validity structure, irregular light users on prepaid packs, and everyone''s numbers re-audited when life changes — the new job, the hostel year, the festival binge. The plan that fits December is not the plan that fits the internship month. Settle the prepaid-postpaid war the way you would settle anything in a house budget: by evidence, per person, revisited quarterly.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
 'scheduled', NULL, '2026-10-28 23:00:00+00',
 5,
 'Prepaid or Postpaid: How to Choose by Your Real Usage Pattern | Bharat Tech Pulse',
 'A usage-evidence method — not a rate-card argument — to settle the prepaid-versus-postpaid question phone by phone in your family.',
 'https://bharattechpulse.in/article/prepaid-vs-postpaid-how-to-choose',
 'Prepaid or Postpaid: How to Choose Based on Your Actual Usage Pattern',
 'A usage-evidence method — not a rate-card argument — to settle the prepaid-versus-postpaid question phone by phone in your family.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
 false, false, false, 0, 'Subscription Plans',
 '["Read your own usage statement before reading any rate card.","Prepaid is a budget with deadlines; postpaid is a meter you pay for calm.","Track the hidden tax: data and validity that expire unused.","Decide per phone, revisit when life changes — quarterly works."]'::jsonb,
 '[{"question":"I work from home and cannot risk a failed payment cutting my internet-like phone backup — does postpaid suit me?","answer":"If a mid-month expiry with no grace is genuinely dangerous for your work, predictability is worth its premium — but fix the real fragility properly: auto-pay mandates, a small buffer pack, and knowing your carrier''s grace rules apply to both shapes."},{"question":"Do long-validity prepaid packs beat postpaid for light users?","answer":"Usually yes for genuinely light months — validity-length prepaid packs are designed exactly for the user who needs connectivity not volume. The trap is buying the biggest pack for safety; buy for the evidence."},{"question":"How do I stop my teenager from silently exhausting the plan?","answer":"Carrier apps show per-connection usage and offer limits and alerts on many plans; the quarterly family audit does double duty as the conversation. Visible numbers end invisible overruns."}]'::jsonb,
 '[{"id":"start-with-evidence-not-opinions","title":"Start With Evidence, Not Opinions"},{"id":"what-each-billing-shape-actually-is","title":"What Each Billing Shape Actually Is"},{"id":"the-pattern-test-four-questions","title":"The Pattern Test: Four Questions"},{"id":"the-two-number-rule-for-indian-households","title":"The Two-Number Rule for Indian Households"},{"id":"decide-per-phone-revisit-per-season","title":"Decide per Phone, Revisit per Season"}]'::jsonb,
 '2026-10-17 09:00:00+00', '2026-10-19 13:30:00+00'),

-- ── 419 | Cyber Safety | published | featured ──────────────────────────────
('00000000-0000-4000-8000-000000000419', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000107',
 'The 30-Minute Family Cyber Safety Conversation: An Agenda You Can Steal',
 'family-cyber-safety-conversation-30-minutes',
 'One calm conversation does more than a hundred warnings. A ready-made 30-minute agenda — five items, no lectures — to make your Indian household measurably safer online.',
 E'## Why One Conversation Beats a Hundred Warnings\n\nFamily cyber safety fails as a nagging genre: "don''t click that" repeated until it becomes noise. It works as a single scheduled conversation — thirty focused minutes where everyone says what they actually do online, and the household leaves with three or four agreed rules. The agenda below is designed for the typical Indian family: a teenager with a private world, parents with payment apps and forwarding groups, and at least one grandparent with a suspiciously generous network offer. Run it after dinner, with phones physically on the table — this is the one meeting where the devices are the subject, not the distraction.\n\n## Item One (eight minutes): The Honest Map\n\nEach person names, without judgement, what they actually use: the teen lists platforms and games, the parents list payment and utility apps and the groups that matter, the elder lists what arrived on WhatsApp this week. The point of the map is not surveillance — it is knowing which door needs locking. You will discover each generation underestimates the others'' exposure, and that discovery is where the useful part of the conversation starts.\n\n## Item Two (seven minutes): One Story Each\n\nEveryone shares one real scam or creep story they have personally seen — the fake delivery fee message, the cloned relative profile, the loan app that demanded contacts, the "free" game that swallowed a month of pocket money. Stories from your own family beat any news alert because they carry the local texture: the language the message came in, who forwarded it, what happened next. This is the thirty minutes'' emotional core — safety explained as family memory, not as fear.\n\n## Item Three (seven minutes): Agree Three Rules Only\n\nResist a constitution. Pick three household rules together, specific and checkable. The strongest starter set for Indian families: money never moves on a message alone — any request for money, even from mum, gets a voice call to a known number first; no stranger gets OTP, screen-share or remote-access help, ever, whatever they claim; and anything that feels urgent and wrong gets told to an adult or a family member the same day, without punishment attached. Write the three rules where everyone sees them — the fridge, the family group pinned message.\n\n## Item Four (five minutes): One Device, One Fix\n\nPick the weakest-seeming device in the house and fix one thing live, together: turn on the lock screen the elder never set, enable chat backups the teen mocked, switch off unknown-installers, or prune the notification list that is quietly harvesting attention. One visible fix teaches more than the whole agenda: safety as a habit you perform, not a poster on the wall.\n\n## Item Five (three minutes): The Escape Hatch\n\nClose with the rule that makes all other rules work: nobody loses their phone for being fooled. Scam losses multiply in silence — the borrowed money, the fake-loan shame, the grooming threat — and the one intervention every police helpline says helps most is speed, which only honesty buys. Say it plainly: if something bad happened on a device, tell us the same hour, and the first sentence out of every mouth here will be "okay, let''s fix it", followed by 1930 or cybercrime.gov.in where money moved.\n\n## Rebook It for the Next Festival\n\nThirty minutes a season keeps the agenda current as the scams cycle — the new forwarding lure, the new game trend, the new payment trick. Families that schedule the conversation stop being victims-in-waiting and become the household where everyone, from twelve to seventy-two, knows the three rules and the escape hatch. That is the entire industry-facing defence an Indian family actually needs.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
 'published', '2026-09-20 09:00:00+00', NULL,
 5,
 'The 30-Minute Family Cyber Safety Conversation: A Stealable Agenda | Bharat Tech Pulse',
 'A ready-made five-item, thirty-minute agenda — honest map, one story each, three rules, one live fix, and the no-blame escape hatch — for Indian families.',
 'https://bharattechpulse.in/article/family-cyber-safety-conversation-30-minutes',
 'The 30-Minute Family Cyber Safety Conversation: An Agenda You Can Steal',
 'A ready-made five-item, thirty-minute agenda — honest map, one story each, three rules, one live fix, and the no-blame escape hatch — for Indian families.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
 true, false, false, 3720, 'Family Cyber Safety',
 '["Schedule one calm 30-minute conversation per season instead of daily nagging.","Agree exactly three checkable rules — money, OTP/screen-share, tell-us-same-day.","Fix one thing live on the weakest device so safety becomes a performed habit.","Keep the no-blame escape hatch loud; speed of disclosure saves the most money."]'::jsonb,
 '[{"question":"My teenager will treat this as a lecture and close down — does the agenda still work?","answer":"It works better with them present if the first item is genuinely non-judgemental and you admit your own weak spots — the parents'' forwarding habits and password reuse belong on the map too. Mutual honesty is the price of teenage participation."},{"question":"Should the rules be written down formally?","answer":"Yes — three lines, phrased in the family''s own words, posted where devices live. Formality is the point: a rule everyone paraphrases differently is a rule that fails at the moment of panic."},{"question":"What if someone has already lost money and hidden it?","answer":"The escape hatch exists precisely for this. Once disclosed, act fast and bureaucratic: bank dispute, 1930, the cybercrime portal — and keep the lesson inside the conversation, never as future ammunition."}]'::jsonb,
 '[{"id":"why-one-conversation-beats-a-hundred-warnings","title":"Why One Conversation Beats a Hundred Warnings"},{"id":"item-two-one-story-each","title":"Item Two: One Story Each"},{"id":"item-three-agree-three-rules-only","title":"Item Three: Agree Three Rules Only"},{"id":"item-five-the-escape-hatch","title":"Item Five: The Escape Hatch"},{"id":"rebook-it-for-the-next-festival","title":"Rebook It for the Next Festival"}]'::jsonb,
 '2026-09-14 10:00:00+00', '2026-09-20 15:40:00+00'),

-- ── 420 | Cyber Safety | published ─────────────────────────────────────────
('00000000-0000-4000-8000-000000000420', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000107',
 'Spot the Lure: A Pattern-Recognition Guide to Payment Fraud Attempts',
 'spot-payment-fraud-lures-pattern-guide',
 'Fraud operators recycle the same handful of psychological moves. Learn the five patterns and you stop needing to recognise the specific scam of the month.',
 E'## Train Patterns, Not Memory\n\nThe scam of the month changes names — delivery fee, KYC update, prize draw, digital arrest, loan approval — while the machinery underneath is old and few. Victims and advisers both focus on the newest story; the durable defence is recognising the five or six psychological moves that every story is assembled from. Once you can name the moves, the individual scam loses its novelty and, with it, its grip. This is the same skill as reading a con artist in a bazaar; it just now applies to your lock screen.\n\n## Pattern One: Manufactured Urgency\n\nTime pressure is the fraud industry''s first tool, because urgency bypasses the part of you that asks a second question. "The account will be frozen in two hours", "the subsidy expires tonight", "the warrant is issued, pay now". Real institutions dealing with real money almost never operate on villain deadlines — banks, courts, tax offices and employers have paperwork-shaped timelines, not countdown timers. Treat urgency itself as the tell: the tighter the clock, the more slowly you should move. A legitimate party survives being told "I will call back in an hour"; a fraud cannot.\n\n## Pattern Two: Authority Costume\n\nThe costume arrives complete: CID badge background, bank-branded email footer, officer voice with a case number, a screenshot that looks official. Costume is cheap; verification is not. The counter-move is mechanical and rude in the best way: hang up or exit the chat, then re-initiate yourself through the official number or app you already had — never through the link, QR or callback they provide. An identity that refuses to be verified on your own channel is not an identity, it is a costume.\n\n## Pattern Three: The "Small" Test Transfer\n\nBefore the big ask, frauds build trust with something tiny and harmless-looking: a Rupees ten fee, a QR "just to check payment works", a one-time OTP "for verification, nothing happens". Each is a real theft — of a credential, a permission, or your future good judgement, because after complying with the small thing the big thing feels consistent. The clean rule: money and credentials flow in one direction only, from you to parties you initiated contact with. Anything else is the pattern.\n\n## Pattern Four: The Too-Good Reason\n\nYour uncle never calls about money; a lottery you never entered has your name; the refund is double what you paid; the loan is instant, unsecured, for students. Greed and fear are the two doors, and both arrive with implausible reasons attached. Name the emotion the message is targeting — that naming alone slows the reflex — then apply the plain test: if this offer were real, why would it find me, today, through a stranger? No good answer means pattern four.\n\n## Pattern Five: Isolation and Silence\n\nThe professional tell: "do not tell family or the lawyers", "stay on this call until it is done", "delete this chat". Legitimate processes are transparent — institutions want your family to know, want paper trails, expect you to consult. Secrecy demanded from you about your own money and your own safety is the fraud signature every Indian helpline warns about. Break the isolation deliberately: put the phone on speaker, call a family member, tell the person nearest you what is happening in the sentence the scammer fears most: "someone is asking me to pay and not tell anyone."\n\n## The Two-Minute Verdict\n\nWith the patterns named, the daily habit is small: any payment-adjacent request gets two minutes before any action — verify on your own initiated channel, name the emotion being played, and ask one person the question the scam depends on you not asking. The fraud industry votes for panic because most people never vote. Learning the patterns is how your family stops being an opinion poll and starts being a hard target.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
 'published', '2026-09-17 11:30:00+00', NULL,
 6,
 'Spot the Lure: A Pattern-Recognition Guide to Payment Fraud Attempts | Bharat Tech Pulse',
 'Urgency, costume, the small test transfer, the too-good reason and isolation — the five recycled moves of payment fraud and the two-minute verdict that beats them.',
 'https://bharattechpulse.in/article/spot-payment-fraud-lures-pattern-guide',
 'Spot the Lure: A Pattern-Recognition Guide to Payment Fraud Attempts',
 'Urgency, costume, the small test transfer, the too-good reason and isolation — the five recycled moves of payment fraud and the two-minute verdict that beats them.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
 false, false, false, 1980, 'Scam Alerts',
 '["Scams change names; the five psychological moves underneath are recycled.","Urgency itself is the tell — real institutions use paperwork timelines, not countdowns.","Never verify through their link, QR or callback; re-initiate on your own channel.","Secrecy demanded about your own money is the fraud signature; break the isolation."]'::jsonb,
 '[{"question":"What do I actually do the minute I recognise a pattern?","answer":"Stop, do not engage further, and preserve evidence: screenshot the number or handle. If money moved, call the national cyber helpline 1930 immediately — the first hour is when banks can still freeze beneficiary accounts — then report on cybercrime.gov.in. If nothing moved, report anyway through your carrier''s spam route so the number gets burned."},{"question":"Are WhatsApp payment requests from known numbers ever really a fraud?","answer":"Yes — cloned profiles and hacked accounts mean the number you trust is the costume. Any money request in a chat, even from mum, gets the voice-call callback to a number you dial yourself. That single habit is pattern-proof against impersonation."},{"question":"My parents fall for forwarding scams even after this talk. What now?","answer":"Reduce the surface rather than repeat the lecture: turn off unknown-installers, keep money apps off their most-used device where feasible, and make the two-minute verdict a phrase your family says together. Habit engineering works where warning fatigue fails."}]'::jsonb,
 '[{"id":"train-patterns-not-memory","title":"Train Patterns, Not Memory"},{"id":"pattern-one-manufactured-urgency","title":"Pattern One: Manufactured Urgency"},{"id":"pattern-three-the-small-test-transfer","title":"Pattern Three: The \"Small\" Test Transfer"},{"id":"pattern-five-isolation-and-silence","title":"Pattern Five: Isolation and Silence"},{"id":"the-two-minute-verdict","title":"The Two-Minute Verdict"}]'::jsonb,
 '2026-09-10 09:00:00+00', '2026-09-17 13:00:00+00'),

-- ── 421 | Cyber Safety | draft ─────────────────────────────────────────────
('00000000-0000-4000-8000-000000000421', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000107',
 'From Passwords to Passkeys: A Gentle Transition Guide for Your Parents',
 'passwords-passkeys-parents-transition-guide',
 'Passkeys promise a world without typed passwords — and a world your parents have probably never heard of explained in one sitting. A patient, device-by-device transition plan.',
 E'## What a Passkey Is, in One Kitchen Table Sentence\n\nA passkey replaces the thing your parents type with the thing your parents are: instead of a password, the device unlocks the account with a fingerprint, face or PIN they already use on the phone itself. The account and the phone hold a shared secret; logging in means proving identity to the phone, and the phone vouches for the person. No word to remember, no field to paste into a fake site, no reuse trap — which is why, of all the security jargon families ever had to learn, this is the first one that actually makes the older generation safer rather than more careful.\n\n## Why This Transition Is Easier Than the Last One\n\nPassword hygiene lectures failed with parents because they demanded new habits: unique strings, managers, copies. Passkeys ask for the habit they already have — the thumbprint that opens the phone sixty times a day — and quietly remove the surface area frauds exploit: there is no password to phish, OTP-like tricks lose their prize, and written-down notes under the remote stop mattering. For a generation worn down by "reset your password" loops, the promise is not elegance; it is the end of a recurring indignity.\n\n## The Sitting: One Account, One Finger, Ten Minutes\n\nDo not announce a security programme. Sit with one account the parent genuinely uses — the bank app, the email, the DigiLocker-linked service — and do exactly this: open the sign-in settings, find the passkey or biometric login option, and enrol while explaining in the one-sentence form above. Then test the future: lock the app, reopen it with the thumb, and narrate the before-and-after once. One account per sitting, spaced across a month, lands the concept better than a weekend seminar. The second account enrolment is theirs to drive; you supervise.\n\n## What to Keep, What to Retire\n\nPasskeys are per-account, not magic, so the household inventory still needs one honest pass: written passwords on paper stay valid wherever they live until every important account moves, so do not burn the sheet mid-transition — retire it account by account. Anything they cannot move yet — the old utility portal, the relative-run website — gets one rule instead: a phone-only login habit and a phone-call to you before any password change arrives by message. Password reset requests, like money requests, never travel through strangers.\n\n## The Failure Modes to Warn Them About\n\nTwo honest caveats keep the trust durable. First, the passkey lives on the device — losing the phone means recovery through a trusted email or number, so those recovery details get checked and, if stale, fixed on the same sitting as enrolment. Second, a passkey authenticates the person at the phone, so the lock-screen PIN itself stays private: no handing the unlocked phone to "the bank officer" who asks on a call — that scam needs no password because it borrows the finger. The device is the key; the thumb is the thumb; the two stay together and at home.\n\n## Where the Family Ends Up\n\nWithin a few sittings, the achievable goal is real: bank, email and the two services that matter to each parent all open with a thumb, the written sheet shrinks by half, and the fraud surface that password attacks relied on disappears. It is the rare technology moment where the safety upgrade, the convenience upgrade and the dignity upgrade are the same upgrade — and the only cost to your parents was ten minutes and a child who sat down and did it with them instead of at them.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
 'draft', NULL, NULL,
 5,
 'From Passwords to Passkeys: A Gentle Transition Guide for Your Parents | Bharat Tech Pulse',
 'A patient, account-by-account plan to move your parents off typed passwords to passkeys — with the failure modes and recovery details handled first.',
 'https://bharattechpulse.in/article/passwords-passkeys-parents-transition-guide',
 'From Passwords to Passkeys: A Gentle Transition Guide for Your Parents',
 'A patient, account-by-account plan to move your parents off typed passwords to passkeys — with the failure modes and recovery details handled first.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
 false, false, false, 0, 'Privacy Settings',
 '["A passkey = the phone''s own unlock (thumb/face/PIN) logging you in — nothing to type.","Enrol one familiar account per sitting; test reopen the same minute.","Check recovery email and number first; the passkey lives on the device.","The lock-screen PIN stays private: no handing an unlocked phone to callers."]'::jsonb,
 '[{"question":"What if the website or app my parent uses does not support passkeys yet?","answer":"Keep it on the list, and apply the interim rule: use it only from the family phone, and treat any password-change message with the callback-to-you habit. Most major banking, email and government-linked services move toward passkey support over time; the transition is per account, never all-or-nothing."},{"question":"Two parents share one phone — does that break passkeys?","answer":"It muddies them: a passkey authenticates whoever''s biometrics are enrolled on that device. The cleaner setup is one phone or one profile each where feasible; failing that, per-person PINs and the understanding that the thumb that logs in is the account that opens."},{"question":"Is the written password sheet dangerous to keep?","answer":"Less dangerous than a forgotten password and a fraud-assisted reset. Keep it locked away at home during transition, retire each entry as its account moves, and treat it like a key — not something that photographs travel."}]'::jsonb,
 '[{"id":"what-a-passkey-is-in-one-kitchen-table-sentence","title":"What a Passkey Is, in One Kitchen Table Sentence"},{"id":"why-this-transition-is-easier-than-the-last-one","title":"Why This Transition Is Easier Than the Last One"},{"id":"the-sitting-one-account-one-finger-ten-minutes","title":"The Sitting: One Account, One Finger, Ten Minutes"},{"id":"the-failure-modes-to-warn-them-about","title":"The Failure Modes to Warn Them About"},{"id":"where-the-family-ends-up","title":"Where the Family Ends Up"}]'::jsonb,
 '2026-10-18 11:00:00+00', '2026-10-22 16:30:00+00'),

-- ── 422 | Buying Guides | published | popular ──────────────────────────────
('00000000-0000-4000-8000-000000000422', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000108',
 'The First College Laptop: What to Prioritise and What to Ignore',
 'first-college-laptop-what-to-prioritise',
 'Four years, one machine, one budget most families cannot stretch twice. A parent-and-student guide to the handful of laptop choices that actually decide the degree''s daily experience.',
 E'## The Four-Year Frame Comes First\n\nA college laptop is not a gadget purchase; it is a duration contract. Before any spec argument, settle three questions with your student: what will the course demand in years two and three — the engineering lab software, the design tools, the data-science elective that appears suddenly — and can this machine meet them then, not just at orientation? And how will it be carried: daily in a crowded local train, or parked in a hostel room with library machines doing the heavy work? The answers dictate the tier far more honestly than any review. A machine with headroom and durability beats a faster one that dies, gets stolen or cannot run the third-year syllabus.\n\n## Prioritise the Boring Trifecta: Keyboard, Battery, Weight\n\nDaily experience lives in the unadvertised parts. The keyboard is where eight hours a day actually happen — test-serve it with a full paragraph typed in the shop, because a laptop you tolerate on the counter is a laptop you will hate at one in the night before a submission. Battery is a timetable freedom: a machine that survives a full day of lectures plus hostel power uncertainty stops needing the wall, the extension board and the bench-squeeze. Weight decides whether it actually travels to class or rots in the room. These three items, over any spec-sheet tie-break, are where parent money buys daily quality.\n\n## The Durability and Service Questions Nobody Asks Aloud\n\nHostels are harshest to machines: spills, voltage quirks, the bag that falls off the rack. So ask the shop two grown-up questions. What is this model''s service reality in your city — is there an authorised centre, and how do local independents rate its parts? And what is the warranty actually covering: accidental damage protection earns its extra price for exactly this demographic, and an extended plan usually pays for itself against the one event every hostel has. The brand with the great specs and the thin Indian service map is a risk your student will personally discover in week twenty.\n\n## Ignore the Sales-Season Halo\n\nFestival pricing makes everything look like a bargain; the trap is buying the discount rather than the machine. Concretely: last year''s model at the same price is usually the better engineering, storage you cannot expand later deserves buying larger today, and the gaming-aesthetic tier trades battery and weight for glow your course will not use. And the single biggest ignore-list item: the spec everyone argues about — processor generation — is already adequate across every mainstream option for a college workload; the differences you are being sold mostly appear in benchmarks, not in your student''s Tuesday.\n\n## The Hand-Me-Down maths Families Miss\n\nBefore buying new, honestly price the two alternatives: a certified-refurbished business laptop — built for four years of corporate abuse, often the best rupee-per-year machine in India — and the family desktop already sitting unused. A second machine for the hostel plus a shared home workstation beats one anxious laptop that must do everything. Families that treat the purchase as a system rather than a single object routinely land a tier above what the same budget bought alone.\n\n## The One-Page List to Bring to the Shop\n\nPrint or screenshot: course demands years two and three; keyboard and battery and weight tested in person; service centre and parts reality in your city; accidental-damage cover priced; storage and RAM upgrade paths checked; the model year honestly named. Seven lines, no marketing. The laptop that passes all seven is your student''s four-year companion; the one chosen off a discount poster is the one you will meet again in second year, at the counter, for the replacement.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
 'published', '2026-09-12 14:00:00+00', NULL,
 6,
 'The First College Laptop: What to Prioritise and What to Ignore | Bharat Tech Pulse',
 'A duration-contract framework for Indian families: keyboard, battery, service reality and the four-year syllabus — over festival discounts and spec theatre.',
 'https://bharattechpulse.in/article/first-college-laptop-what-to-prioritise',
 'The First College Laptop: What to Prioritise and What to Ignore',
 'A duration-contract framework for Indian families: keyboard, battery, service reality and the four-year syllabus — over festival discounts and spec theatre.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
 false, false, true, 2600, 'Student Laptops',
 '["Buy for year three of the course, not for orientation day.","Keyboard, battery and weight decide daily life; benchmarks mostly do not.","Service-centre reality and accidental-damage cover are parent-tier questions.","Refurbished business laptops and a home-desktop split often beat one anxious machine."]'::jsonb,
 '[{"question":"How much should we actually spend on a college laptop?","answer":"The honest answer is the four-year cost divided by four: a mid-tier machine kept comfortably through the degree almost always beats a bottom-tier machine replaced after two years of friction. Fix the ceiling, then buy durability at the top of the range rather than speed at the bottom."},{"question":"Is a Chromebook an option for arts and commerce students?","answer":"For browser-and-documents coursework with reliable internet, they are cheap, light and durable — but Indian course reality (form-filling portals, a lab module, offline hostel stretches) usually rewards a normal laptop. Check the specific syllabus before trusting the stereotype of a light degree."},{"question":"MacBook for a management student — worth it?","answer":"If the budget genuinely exists and the student will keep it four years, yes — build quality and longevity are the argument, not status. If the same money stretched means a worse Windows machine, the platform does not rescue a bad purchase."}]'::jsonb,
 '[{"id":"the-four-year-frame-comes-first","title":"The Four-Year Frame Comes First"},{"id":"prioritise-the-boring-trifecta-keyboard-battery-weight","title":"Prioritise the Boring Trifecta"},{"id":"the-durability-and-service-questions-nobody-asks-aloud","title":"The Durability and Service Questions"},{"id":"ignore-the-sales-season-halo","title":"Ignore the Sales-Season Halo"},{"id":"the-one-page-list-to-bring-to-the-shop","title":"The One-Page List to Bring to the Shop"}]'::jsonb,
 '2026-09-05 10:00:00+00', '2026-09-12 16:00:00+00'),

-- ── 423 | Buying Guides | published ────────────────────────────────────────
('00000000-0000-4000-8000-000000000423', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000108',
 'Choosing a Phone for an Elderly Parent: A Needs-First Checklist That Beats Any Spec Sheet',
 'choosing-phone-for-elderly-parent-checklist',
 'Vision, hearing, hands, habits and emergency access: the five real requirements an elderly parent''s phone must meet — and the setup that follows the purchase.',
 E'## Write the Needs List Before the Budget Argument\n\nBuying a phone for an ageing parent fails in the same way everywhere: the shopper compares specs for a person who will never read one. Start from their body and their day instead. Can they read small text at arm length? Do their fingers have the grip and touch precision for a glass slab, or do taps land half-missing? Is hearing aid-compatible loudness needed for video calls? Do they take medication by reminder and walk alone to the bank? Five honest answers become your spec, and the spec then picks the phone — not the shop. This inversion is the entire method of this checklist.\n\n## Vision and Display: Size Is a Safety Feature\n\nBig, bright, high-contrast text beats every cosmetic screen feature for this user. Prefer larger screens at close seating distance, set the system font to its biggest on day one, and check the maximum brightness under the tube-light, because that is where the phone actually lives. Dark-mode glare and washed-out sunlight screens are not aesthetics; they are reasons the medication reminder gets missed. If the parent has been prescribed new glasses, budget for them as part of the phone purchase — screen and eyes are one system.\n\n## Hands and Controls: The Physical Interface\n\nStiff joints and trembling thumbs make thin, slippery, flat-everything designs actively hostile. Prioritise: a flat-ish screen — curved edges mis-tap cruelly; a case with a real grip and a raised lip; physical button placement the parent can find blind — the power button is the emergency anchor; and weight distribution that does not tire a wrist, since this phone will be held during long calls and read in bed. If their old phone had a keypad they loved, respect the evidence: some seniors genuinely do better with big-button devices plus your video-call tablet at the other end, and that is a legitimate system, not a defeat.\n\n## Hearing, Voice and the Communication Stack\n\nTest the stack that matters: speaker loudness for video calls, the vibration strength in a cardigan pocket, and whether their hearing-aid or bluetooth setup works before the festival-season purchase. Enable the emergency shortcuts on both platforms — power-button sequences that call a preset contact and share location — and rehearse the sequence until it is muscle memory. Voice assistants are legitimately useful here for one-tap calls and reminders; set them up with the family''s actual names and accents, then verify the assistant can really dial your sibling, because a confused assistant teaches distrust quickly.\n\n## The Software Set-Up Is the Real Purchase\n\nWhatever phone you choose, the value is added in the first hour, by you, in person. One home screen, four giant icons: phone, WhatsApp, photos, emergency. Every other app in a folder named "rest" — discovery through swiping is how seniors get lost and how scam forwards get installed. Text and icon size maxed, simple launcher mode if the brand offers it, auto-answer and large-clock widgets configured, medication reminders set up together and tested twice. A phone for an elderly parent is a designed environment, and the designer must visit.\n\n## The Maintenance Contract You Sign With It\n\nDecide, out loud, what you own forever: the monthly glance at storage and battery health, the quarterly permission check when you visit, the "who called me" conversation that keeps spam at bay, and the rule that any password, OTP or "bank" call question comes to you before it comes to a stranger. Then name the next-upgrade owner — likely you, likely yours to schedule. The needs-first checklist buys the right hardware once; this contract is what makes it work for the four years after the box goes back.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
 'published', '2026-09-08 10:00:00+00', NULL,
 5,
 'Choosing a Phone for an Elderly Parent: A Needs-First Checklist | Bharat Tech Pulse',
 'Vision, hands, hearing, the software set-up and the maintenance contract: the checklist that beats any spec sheet when buying a parent''s phone.',
 'https://bharattechpulse.in/article/choosing-phone-for-elderly-parent-checklist',
 'Choosing a Phone for an Elderly Parent: A Needs-First Checklist That Beats Any Spec Sheet',
 'Vision, hands, hearing, the software set-up and the maintenance contract: the checklist that beats any spec sheet when buying a parent''s phone.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
 false, false, false, 1420, 'Phones Under ₹20,000',
 '["Their body and their day are the spec; write five honest answers first.","Big bright text, flat screen, grippy case and a findable power button.","Emergency shortcuts rehearsed until they are muscle memory.","The first hour of software setup by you is the real purchase."]'::jsonb,
 '[{"question":"Should we get a basic phone instead of a smartphone for safety?","answer":"Judge by the parent, not the generation gap. A keypad-plus-your-video-call tablet is a legitimate system for a phone used for calls and SOS only. The failure mode is either extreme: a smartphone abandoned in confusion, or a basic phone that misses telehealth and reminders the family actually depends on."},{"question":"Is buying the cheapest phone sensible because they ''will barely use it''?","answer":"Barely-used is exactly why reliability matters more — the phone that dies at an emergency is the one you remember. Mid-range with a good speaker, big text support and a real service network is the honest target; fancy is waste, cheap is risk."},{"question":"How often should the setup be revisited?","answer":"Quarterly, ideally in person: text size drifts with eyesight, apps update interfaces, and the forwarding-habits conversation needs fresh examples. Fold it into a family routine — the same Sunday as the audit article suggests, and the two visits become one."}]'::jsonb,
 '[{"id":"write-the-needs-list-before-the-budget-argument","title":"Write the Needs List Before the Budget Argument"},{"id":"vision-and-display-size-is-a-safety-feature","title":"Vision and Display: Size Is a Safety Feature"},{"id":"the-software-setup-is-the-real-purchase","title":"The Software Set-Up Is the Real Purchase"},{"id":"the-maintenance-contract-you-sign-with-it","title":"The Maintenance Contract You Sign With It"}]'::jsonb,
 '2026-09-01 09:00:00+00', '2026-09-08 12:20:00+00'),

-- ── 424 | Buying Guides | archived ─────────────────────────────────────────
('00000000-0000-4000-8000-000000000424', '00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000108',
 'Festival Sale Instincts: Five Old Shopping Habits That Lead to Buyer''s Remorse',
 'festival-gadget-shopping-old-habits',
 'The sale is not new; the habits it exploits are. Five reflexive shopping behaviours that predict buyer''s remorse in Indian gadget purchases — and the replacement move for each.',
 E'## Why the Season Wins Every Year\n\nFestival sales work because they are engineered against instinct: countdown timers, "limited stock" badges, exchange bonuses and the social proof of the family group chat all firing at the same prefrontal cortex. The deals are sometimes real; the remorse comes from the habits the season rewards — buying speed over fit, price over cost, novelty over need. Nothing below says skip the sale; the point is to arrive with the reflexes rewired, so the season sells you what you wanted anyway, at a price that was genuinely better.\n\n## Habit One: Shopping by Discount, Not by Need\n\n"The savings" is the season''s sleight of hand: a fifty-percent-off gadget you did not need saved zero rupees. Replace the reflex with the one-question gate — would I buy this, at full price, this month, for the job it does in my life? If no, no percentage moves it into yes. Write the list of real needs before opening the app, and let only list items pass the gate; the cart fills itself with items you will discover you already owned three varieties of.\n\n## Habit Two: Upgrading a Decision with Research Backwards\n\nThe timer makes everyone pick a product first, then hunt for reviews to justify it — the opposite of how research works. The fix is boring and effective: shortlist before the season, when nothing is ticking. By the time the sale opens, you should already know two or three acceptable models and their honest normal prices. The sale then becomes what it claims to be: a chance to buy the pre-decided thing cheaper, not a scavenger hunt for meaning.\n\n## Habit Three: Buying the Exchange, Not the Price\n\nExchange bonuses are a pricing trick with a sentimental wrapper: your old phone gets an optimistic valuation, the new one a padded headline, and the family learns the real number at the doorstep when the rider arrives. Run the maths once, calmly: what does your old device actually fetch from a used buyer or a store quote, versus the exchange credit? When the gap costs you the bonus, the bonus is the discount you paid for. And if the old device is a hand-me-down that still works, the exchange is just an expensive habit.\n\n## Habit Four: The Bundle That Bundles You\n\nFree earbuds with a laptop, a "cover plus" with a phone, the extended everything-pack at checkout: bundles are priced so the marginal item feels free and the total feels fair. Test each item separately at its own normal price and ask whether you would buy it that way, today. Most "free" accessories are the tier you would return, and the extended service plan deserves a real decision about your city and your habits, not a checkout reflex.\n\n## Habit Five: Treating the Delivery as the Decision Point\n\nThe purchase feels done at payment; the decision actually ends at the unboxing week — when the return window closes and the regret becomes property. Keep the receipt-era discipline: verify the sealed box, check the model year honestly against what you ordered, use the warranty-registration step as a second look at what you own, and let the return window run its full useful life before you gift-wrap the device into permanence. A three-day no-return-feeling is the cheapest insurance in shopping.\n\n## The Season, Rewired\n\nFive replacements — need-gate, pre-shortlist, exchange maths, item-tested bundles, return-window patience — and the festival season turns from an annual regret ritual into what the best Indian shopping always was: a planned purchase made at a good price, discussed at dinner with satisfaction rather than silence. The timers will keep counting. The habits are the only thing that ever changed.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
 'archived', '2026-09-01 10:00:00+00', NULL,
 5,
 'Festival Sale Instincts: Five Shopping Habits That Cause Buyer''s Remorse | Bharat Tech Pulse',
 'Discount-shopping, backwards research, exchange maths, bundle traps and return-window patience: rewiring five reflexes before the next sale season.',
 'https://bharattechpulse.in/article/festival-gadget-shopping-old-habits',
 'Festival Sale Instincts: Five Old Shopping Habits That Lead to Buyer''s Remorse',
 'Discount-shopping, backwards research, exchange maths, bundle traps and return-window patience: rewiring five reflexes before the next sale season.',
 'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
 false, false, false, 1150, '',
 '["Would I buy this at full price this month? If no, no discount moves it.","Shortlist and learn normal prices before the season, not during it.","Run exchange maths against what the old device truly fetches.","Let the return window run its full life before the purchase becomes permanent."]'::jsonb,
 '[{"question":"Is waiting for the next festival always better than buying today?","answer":"No — the honest test is the need''s cost of waiting. A broken work phone today loses you wages and peace; a six-month patience on a comfort purchase usually wins. The habit to break is sale-reactive timing, not timing itself."},{"question":"Are festival deals actually better than normal prices?","answer":"Sometimes genuinely, often cosmetically — which is exactly why the pre-season price research matters. Track two or three candidate models for a few weeks before the season and the answer becomes local and personal instead of folklore."},{"question":"Why was this article archived?","answer":"It is a demonstration of the archived lifecycle: the piece stays addressable for redirects and history, and drops out of public feeds once the editorial team retires a seasonal title from the active shelf."}]'::jsonb,
 '[{"id":"why-the-season-wins-every-year","title":"Why the Season Wins Every Year"},{"id":"habit-one-shopping-by-discount-not-by-need","title":"Habit One: Shopping by Discount, Not by Need"},{"id":"habit-three-buying-the-exchange-not-the-price","title":"Habit Three: Buying the Exchange, Not the Price"},{"id":"habit-five-treating-the-delivery-as-the-decision-point","title":"Habit Five: Delivery Is Not the Decision Point"},{"id":"the-season-rewired","title":"The Season, Rewired"}]'::jsonb,
 '2026-08-27 09:00:00+00', '2026-10-10 10:00:00+00')
ON CONFLICT (site_id, slug) DO UPDATE
SET title           = EXCLUDED.title,
    excerpt         = EXCLUDED.excerpt,
    content         = EXCLUDED.content,
    author_id       = EXCLUDED.author_id,
    category_id     = EXCLUDED.category_id,
    featured_image  = EXCLUDED.featured_image,
    thumbnail_image = EXCLUDED.thumbnail_image,
    status          = EXCLUDED.status,
    published_at    = EXCLUDED.published_at,
    scheduled_for   = EXCLUDED.scheduled_for,
    reading_time    = EXCLUDED.reading_time,
    seo_title       = EXCLUDED.seo_title,
    seo_description = EXCLUDED.seo_description,
    canonical_url   = EXCLUDED.canonical_url,
    og_title        = EXCLUDED.og_title,
    og_description  = EXCLUDED.og_description,
    og_image        = EXCLUDED.og_image,
    is_featured     = EXCLUDED.is_featured,
    is_trending     = EXCLUDED.is_trending,
    is_popular      = EXCLUDED.is_popular,
    view_count      = EXCLUDED.view_count,
    subcategory     = EXCLUDED.subcategory,
    key_takeaways   = EXCLUDED.key_takeaways,
    faqs            = EXCLUDED.faqs,
    toc             = EXCLUDED.toc,
    created_at      = EXCLUDED.created_at
WHERE public.posts.id = EXCLUDED.id;

-- ----------------------------------------------------------------------------
-- 7. post_tags (77 rows) — 2-4 tags per post, every reference resolves to a
--    demo tag and demo post above; junction conflicts are ignored.
-- ----------------------------------------------------------------------------
INSERT INTO public.post_tags (post_id, tag_id) VALUES
    ('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000301'),
    ('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000305'),
    ('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000312'),
    ('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000318'),
    ('00000000-0000-4000-8000-000000000402', '00000000-0000-4000-8000-000000000301'),
    ('00000000-0000-4000-8000-000000000402', '00000000-0000-4000-8000-000000000313'),
    ('00000000-0000-4000-8000-000000000402', '00000000-0000-4000-8000-000000000318'),
    ('00000000-0000-4000-8000-000000000403', '00000000-0000-4000-8000-000000000301'),
    ('00000000-0000-4000-8000-000000000403', '00000000-0000-4000-8000-000000000318'),
    ('00000000-0000-4000-8000-000000000403', '00000000-0000-4000-8000-000000000324'),
    ('00000000-0000-4000-8000-000000000404', '00000000-0000-4000-8000-000000000309'),
    ('00000000-0000-4000-8000-000000000404', '00000000-0000-4000-8000-000000000315'),
    ('00000000-0000-4000-8000-000000000404', '00000000-0000-4000-8000-000000000319'),
    ('00000000-0000-4000-8000-000000000405', '00000000-0000-4000-8000-000000000309'),
    ('00000000-0000-4000-8000-000000000405', '00000000-0000-4000-8000-000000000310'),
    ('00000000-0000-4000-8000-000000000405', '00000000-0000-4000-8000-000000000315'),
    ('00000000-0000-4000-8000-000000000406', '00000000-0000-4000-8000-000000000309'),
    ('00000000-0000-4000-8000-000000000406', '00000000-0000-4000-8000-000000000310'),
    ('00000000-0000-4000-8000-000000000406', '00000000-0000-4000-8000-000000000319'),
    ('00000000-0000-4000-8000-000000000407', '00000000-0000-4000-8000-000000000306'),
    ('00000000-0000-4000-8000-000000000407', '00000000-0000-4000-8000-000000000307'),
    ('00000000-0000-4000-8000-000000000407', '00000000-0000-4000-8000-000000000308'),
    ('00000000-0000-4000-8000-000000000407', '00000000-0000-4000-8000-000000000317'),
    ('00000000-0000-4000-8000-000000000408', '00000000-0000-4000-8000-000000000308'),
    ('00000000-0000-4000-8000-000000000408', '00000000-0000-4000-8000-000000000316'),
    ('00000000-0000-4000-8000-000000000408', '00000000-0000-4000-8000-000000000318'),
    ('00000000-0000-4000-8000-000000000409', '00000000-0000-4000-8000-000000000308'),
    ('00000000-0000-4000-8000-000000000409', '00000000-0000-4000-8000-000000000316'),
    ('00000000-0000-4000-8000-000000000409', '00000000-0000-4000-8000-000000000320'),
    ('00000000-0000-4000-8000-000000000410', '00000000-0000-4000-8000-000000000311'),
    ('00000000-0000-4000-8000-000000000410', '00000000-0000-4000-8000-000000000318'),
    ('00000000-0000-4000-8000-000000000410', '00000000-0000-4000-8000-000000000321'),
    ('00000000-0000-4000-8000-000000000411', '00000000-0000-4000-8000-000000000311'),
    ('00000000-0000-4000-8000-000000000411', '00000000-0000-4000-8000-000000000315'),
    ('00000000-0000-4000-8000-000000000411', '00000000-0000-4000-8000-000000000319'),
    ('00000000-0000-4000-8000-000000000412', '00000000-0000-4000-8000-000000000302'),
    ('00000000-0000-4000-8000-000000000412', '00000000-0000-4000-8000-000000000309'),
    ('00000000-0000-4000-8000-000000000412', '00000000-0000-4000-8000-000000000311'),
    ('00000000-0000-4000-8000-000000000412', '00000000-0000-4000-8000-000000000315'),
    ('00000000-0000-4000-8000-000000000413', '00000000-0000-4000-8000-000000000315'),
    ('00000000-0000-4000-8000-000000000413', '00000000-0000-4000-8000-000000000321'),
    ('00000000-0000-4000-8000-000000000413', '00000000-0000-4000-8000-000000000322'),
    ('00000000-0000-4000-8000-000000000414', '00000000-0000-4000-8000-000000000307'),
    ('00000000-0000-4000-8000-000000000414', '00000000-0000-4000-8000-000000000308'),
    ('00000000-0000-4000-8000-000000000414', '00000000-0000-4000-8000-000000000320'),
    ('00000000-0000-4000-8000-000000000415', '00000000-0000-4000-8000-000000000315'),
    ('00000000-0000-4000-8000-000000000415', '00000000-0000-4000-8000-000000000319'),
    ('00000000-0000-4000-8000-000000000415', '00000000-0000-4000-8000-000000000320'),
    ('00000000-0000-4000-8000-000000000416', '00000000-0000-4000-8000-000000000302'),
    ('00000000-0000-4000-8000-000000000416', '00000000-0000-4000-8000-000000000303'),
    ('00000000-0000-4000-8000-000000000416', '00000000-0000-4000-8000-000000000309'),
    ('00000000-0000-4000-8000-000000000416', '00000000-0000-4000-8000-000000000310'),
    ('00000000-0000-4000-8000-000000000417', '00000000-0000-4000-8000-000000000304'),
    ('00000000-0000-4000-8000-000000000417', '00000000-0000-4000-8000-000000000319'),
    ('00000000-0000-4000-8000-000000000417', '00000000-0000-4000-8000-000000000320'),
    ('00000000-0000-4000-8000-000000000418', '00000000-0000-4000-8000-000000000310'),
    ('00000000-0000-4000-8000-000000000418', '00000000-0000-4000-8000-000000000315'),
    ('00000000-0000-4000-8000-000000000418', '00000000-0000-4000-8000-000000000323'),
    ('00000000-0000-4000-8000-000000000419', '00000000-0000-4000-8000-000000000306'),
    ('00000000-0000-4000-8000-000000000419', '00000000-0000-4000-8000-000000000314'),
    ('00000000-0000-4000-8000-000000000419', '00000000-0000-4000-8000-000000000317'),
    ('00000000-0000-4000-8000-000000000420', '00000000-0000-4000-8000-000000000306'),
    ('00000000-0000-4000-8000-000000000420', '00000000-0000-4000-8000-000000000317'),
    ('00000000-0000-4000-8000-000000000420', '00000000-0000-4000-8000-000000000322'),
    ('00000000-0000-4000-8000-000000000421', '00000000-0000-4000-8000-000000000306'),
    ('00000000-0000-4000-8000-000000000421', '00000000-0000-4000-8000-000000000307'),
    ('00000000-0000-4000-8000-000000000421', '00000000-0000-4000-8000-000000000320'),
    ('00000000-0000-4000-8000-000000000422', '00000000-0000-4000-8000-000000000310'),
    ('00000000-0000-4000-8000-000000000422', '00000000-0000-4000-8000-000000000319'),
    ('00000000-0000-4000-8000-000000000422', '00000000-0000-4000-8000-000000000320'),
    ('00000000-0000-4000-8000-000000000422', '00000000-0000-4000-8000-000000000324'),
    ('00000000-0000-4000-8000-000000000423', '00000000-0000-4000-8000-000000000309'),
    ('00000000-0000-4000-8000-000000000423', '00000000-0000-4000-8000-000000000310'),
    ('00000000-0000-4000-8000-000000000423', '00000000-0000-4000-8000-000000000317'),
    ('00000000-0000-4000-8000-000000000424', '00000000-0000-4000-8000-000000000310'),
    ('00000000-0000-4000-8000-000000000424', '00000000-0000-4000-8000-000000000315'),
    ('00000000-0000-4000-8000-000000000424', '00000000-0000-4000-8000-000000000319')
ON CONFLICT (post_id, tag_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 8. media (17 rows) — registry entries for the demo assets that live in the
--    public 'media' Storage bucket under the site folder prefix india_tech/.
--    The binaries are uploaded; file_size/width/height below are the real
--    byte counts and pixel dimensions of those files.
--    uploaded_by is NULL (no auth user exists at seed time; the FK allows it).
-- ----------------------------------------------------------------------------
INSERT INTO public.media
    (id, site_id, uploaded_by, file_name, storage_path, public_url,
     mime_type, file_size, width, height, alt_text)
VALUES
    ('00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000001', NULL,
     '2026-10-ai-tool-framework-hero.jpg',
     'india_tech/articles/2026-10-ai-tool-framework-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/2026-10-ai-tool-framework-hero.jpg',
     'image/jpeg', 43478, 1600, 900,
     'Hero illustration for the AI tool selection framework article (demo asset)'),
    ('00000000-0000-4000-8000-000000000502', '00000000-0000-4000-8000-000000000001', NULL,
     '2026-09-dpi-explained-hero.jpg',
     'india_tech/articles/2026-09-dpi-explained-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/2026-09-dpi-explained-hero.jpg',
     'image/jpeg', 47794, 1600, 900,
     'Hero illustration explaining India''s digital public infrastructure rails (demo asset)'),
    ('00000000-0000-4000-8000-000000000503', '00000000-0000-4000-8000-000000000001', NULL,
     '2026-10-spec-sheet-decoded-hero.jpg',
     'india_tech/articles/2026-10-spec-sheet-decoded-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/2026-10-spec-sheet-decoded-hero.jpg',
     'image/jpeg', 47535, 1600, 900,
     'Hero image for the smartphone spec sheet decoded article (demo asset)'),
    ('00000000-0000-4000-8000-000000000504', '00000000-0000-4000-8000-000000000001', NULL,
     '2026-09-family-cyber-safety-hero.jpg',
     'india_tech/articles/2026-09-family-cyber-safety-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/2026-09-family-cyber-safety-hero.jpg',
     'image/jpeg', 46814, 1600, 900,
     'Hero image for the 30-minute family cyber safety conversation article (demo asset)'),
    ('00000000-0000-4000-8000-000000000505', '00000000-0000-4000-8000-000000000001', NULL,
     'aravind-sharma-avatar.jpg',
     'india_tech/authors/aravind-sharma-avatar.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/aravind-sharma-avatar.jpg',
     'image/jpeg', 7693, 300, 300,
     'Avatar for byline Aravind Sharma (demo asset)'),
    ('00000000-0000-4000-8000-000000000506', '00000000-0000-4000-8000-000000000001', NULL,
     'bharat-tech-pulse-og-default.jpg',
     'india_tech/brand/bharat-tech-pulse-og-default.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/brand/bharat-tech-pulse-og-default.jpg',
     'image/jpeg', 29496, 1200, 630,
     'Default Open Graph share image for Bharat Tech Pulse (demo asset)'),
    ('00000000-0000-4000-8000-000000000507', '00000000-0000-4000-8000-000000000001', NULL,
     'ai-hero.jpg',
     'india_tech/articles/category/ai-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/ai-hero.jpg',
     'image/jpeg', 39874, 1600, 900,
     'hero illustration for Artificial Intelligence articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000508', '00000000-0000-4000-8000-000000000001', NULL,
     'smartphones-hero.jpg',
     'india_tech/articles/category/smartphones-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/smartphones-hero.jpg',
     'image/jpeg', 48121, 1600, 900,
     'hero illustration for Smartphone Reviews articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000509', '00000000-0000-4000-8000-000000000001', NULL,
     'apps-hero.jpg',
     'india_tech/articles/category/apps-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/apps-hero.jpg',
     'image/jpeg', 43118, 1600, 900,
     'hero illustration for App & Software News articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000510', '00000000-0000-4000-8000-000000000001', NULL,
     'how-to-hero.jpg',
     'india_tech/articles/category/how-to-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/how-to-hero.jpg',
     'image/jpeg', 45842, 1600, 900,
     'hero illustration for How-To & Guides articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000511', '00000000-0000-4000-8000-000000000001', NULL,
     'tech-news-hero.jpg',
     'india_tech/articles/category/tech-news-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/tech-news-hero.jpg',
     'image/jpeg', 43373, 1600, 900,
     'hero illustration for Latest Tech News 2026 articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000512', '00000000-0000-4000-8000-000000000001', NULL,
     'comparisons-hero.jpg',
     'india_tech/articles/category/comparisons-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/comparisons-hero.jpg',
     'image/jpeg', 41033, 1600, 900,
     'hero illustration for Product Comparisons articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000513', '00000000-0000-4000-8000-000000000001', NULL,
     'cyber-safety-hero.jpg',
     'india_tech/articles/category/cyber-safety-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/cyber-safety-hero.jpg',
     'image/jpeg', 46125, 1600, 900,
     'hero illustration for Cyber Safety & Security articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000514', '00000000-0000-4000-8000-000000000001', NULL,
     'buying-guides-hero.jpg',
     'india_tech/articles/category/buying-guides-hero.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/articles/category/buying-guides-hero.jpg',
     'image/jpeg', 44287, 1600, 900,
     'hero illustration for Buying Guides 2026 articles (demo asset)'),
    ('00000000-0000-4000-8000-000000000515', '00000000-0000-4000-8000-000000000001', NULL,
     'priya-nambiar-avatar.jpg',
     'india_tech/authors/priya-nambiar-avatar.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/priya-nambiar-avatar.jpg',
     'image/jpeg', 8043, 300, 300,
     'Avatar for byline Priya Nambiar (demo asset)'),
    ('00000000-0000-4000-8000-000000000516', '00000000-0000-4000-8000-000000000001', NULL,
     'rohit-deshmukh-avatar.jpg',
     'india_tech/authors/rohit-deshmukh-avatar.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/rohit-deshmukh-avatar.jpg',
     'image/jpeg', 8220, 300, 300,
     'Avatar for byline Rohit Deshmukh (demo asset)'),
    ('00000000-0000-4000-8000-000000000517', '00000000-0000-4000-8000-000000000001', NULL,
     'sneha-kulkarni-avatar.jpg',
     'india_tech/authors/sneha-kulkarni-avatar.jpg',
     'https://ylzwuwfhlqomjqcdrpxk.supabase.co/storage/v1/object/public/media/india_tech/authors/sneha-kulkarni-avatar.jpg',
     'image/jpeg', 7344, 300, 300,
     'Avatar for byline Sneha Kulkarni (demo asset)')
ON CONFLICT (id) DO UPDATE
SET file_name    = EXCLUDED.file_name,
    storage_path = EXCLUDED.storage_path,
    public_url   = EXCLUDED.public_url,
    mime_type    = EXCLUDED.mime_type,
    file_size    = EXCLUDED.file_size,
    width        = EXCLUDED.width,
    height       = EXCLUDED.height,
    alt_text     = EXCLUDED.alt_text;

-- ----------------------------------------------------------------------------
-- 9. post_revisions (5 rows) — editor history demo.
--    Numbering follows the same max+1 rule the Flutter editor uses (see 005):
--    post 401 has revisions 1 and 2; posts 404/413/419 have revision 1.
--    edited_by is NULL: the FK to auth.users allows NULL by design and no
--    auth user exists at seed time.
--    NOTE: content snapshots are truncated demo excerpts of the earlier draft,
--    not byte-exact historical copies.
-- ----------------------------------------------------------------------------
INSERT INTO public.post_revisions (id, post_id, edited_by, title, content, excerpt, revision_number)
VALUES
    ('00000000-0000-4000-8000-000000000601', '00000000-0000-4000-8000-000000000401', NULL,
     'How to Pick an AI Tool: A Simple Framework',
     '## Start With the Job, Not the Tool\n\nThe most common mistake is choosing an AI tool because a friend showed you something it did once. Write down the two or three recurring tasks that actually eat your week, then evaluate every candidate tool against those concrete jobs. [Earlier draft snapshot — demo revision]',
     'A simple framework for picking AI tools based on your actual work.',
     1),
    ('00000000-0000-4000-8000-000000000602', '00000000-0000-4000-8000-000000000401', NULL,
     'Choose the Right AI Tool for Your Daily Work: A Framework',
     '## Start With the Job, Not the Tool\n\n... [second draft before publication: added the data-consent section and the two-week trial rule; near-final text — demo revision]',
     'AI tool marketing is loud. This framework helps Indian professionals pick tools for their real work instead of the hype.',
     2),
    ('00000000-0000-4000-8000-000000000603', '00000000-0000-4000-8000-000000000404', NULL,
     'Reading a Smartphone Spec Sheet: What Matters',
     '## RAM: Number vs Reality\n\nMarketing treats RAM like engine displacement — bigger must be better. Reality is subtler. [First draft before the display and camera sections were added — demo revision]',
     'Spec sheets are a wall of numbers designed to impress. Here is how to read them.',
     1),
    ('00000000-0000-4000-8000-000000000604', '00000000-0000-4000-8000-000000000413', NULL,
     'What Is Digital Public Infrastructure? A Plain-Language Map',
     '## The Plumbing Behind the Daily Ten Minutes\n\nDigital public infrastructure is the shared digital rails the country built so services do not each invent their own. [Early draft with the scam-economy section still a TODO — demo revision]',
     'UPI, DigiLocker, ONDC: the plain-language map of the rails India runs on.',
     1),
    ('00000000-0000-4000-8000-000000000605', '00000000-0000-4000-8000-000000000419', NULL,
     'A 30-Minute Family Cyber Safety Meeting: The Agenda',
     '## Why One Conversation Beats a Hundred Warnings\n\nFamily cyber safety fails as a nagging genre. It works as a single scheduled conversation. [Draft where item four was a checklist instead of a live fix — demo revision]',
     'A ready-made 30-minute agenda to make your household measurably safer online.',
     1)
ON CONFLICT (post_id, revision_number) DO UPDATE
SET title   = EXCLUDED.title,
    content = EXCLUDED.content,
    excerpt = EXCLUDED.excerpt,
    edited_by = EXCLUDED.edited_by
WHERE public.post_revisions.id = EXCLUDED.id;

-- ----------------------------------------------------------------------------
-- 10. redirects (3 rows) — 301s for demo posts whose slugs changed during
--     editorial revisions; new_path values match existing demo post slugs.
-- ----------------------------------------------------------------------------
INSERT INTO public.redirects (id, site_id, old_path, new_path, status_code)
VALUES
    ('00000000-0000-4000-8000-000000000701', '00000000-0000-4000-8000-000000000001',
     '/article/ai-tool-choice-framework',
     '/article/choose-right-ai-tool-honest-framework', 301),
    ('00000000-0000-4000-8000-000000000702', '00000000-0000-4000-8000-000000000001',
     '/article/smartphone-spec-sheet-guide',
     '/article/smartphone-spec-sheet-decoded-india', 301),
    ('00000000-0000-4000-8000-000000000703', '00000000-0000-4000-8000-000000000001',
     '/article/family-app-audit',
     '/article/weekend-app-audit-indian-families', 301)
ON CONFLICT (site_id, old_path) DO UPDATE
SET new_path    = EXCLUDED.new_path,
    status_code = EXCLUDED.status_code
WHERE public.redirects.id = EXCLUDED.id;

-- ----------------------------------------------------------------------------
-- 11. subscribers (6 rows) — ALL addresses are fictitious example.com /
--     example.in addresses (RFC-reserved domains); no real person is listed.
-- ----------------------------------------------------------------------------
INSERT INTO public.subscribers
    (id, site_id, email, name, is_verified, is_active, subscribed_at, unsubscribed_at)
VALUES
    ('00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000001',
     'demo.reader@example.com',        'Demo Reader',       true,  true,
     '2026-06-11 09:15:00+00', NULL),
    ('00000000-0000-4000-8000-000000000802', '00000000-0000-4000-8000-000000000001',
     'family.pulse@example.in',        'Family Subscriber', true,  true,
     '2026-07-02 18:40:00+00', NULL),
    ('00000000-0000-4000-8000-000000000803', '00000000-0000-4000-8000-000000000001',
     'student.demo@example.com',       'Student Demo',      false, true,
     '2026-09-19 12:05:00+00', NULL),  -- pending email verification
    ('00000000-0000-4000-8000-000000000804', '00000000-0000-4000-8000-000000000001',
     'former.fan@example.in',          'Former Fan',        true,  false,
     '2026-05-28 07:50:00+00',                                                -- demo row with an
     '2026-10-06 14:22:00+00'),                                               -- unsubscribed_at set
    ('00000000-0000-4000-8000-000000000805', '00000000-0000-4000-8000-000000000001',
     'tech.enthusiast@example.com',    'Tech Enthusiast',   true,  true,
     '2026-08-14 20:10:00+00', NULL),
    ('00000000-0000-4000-8000-000000000806', '00000000-0000-4000-8000-000000000001',
     'office.inbox@example.in',        'Office Inbox',      false, true,
     '2026-10-01 10:00:00+00', NULL)
ON CONFLICT (site_id, email) DO UPDATE
SET name            = EXCLUDED.name,
    is_verified     = EXCLUDED.is_verified,
    is_active       = EXCLUDED.is_active,
    subscribed_at   = EXCLUDED.subscribed_at,
    unsubscribed_at = EXCLUDED.unsubscribed_at
WHERE public.subscribers.id = EXCLUDED.id;

-- ----------------------------------------------------------------------------
-- 12. analytics_events (40 rows) — synthetic recent traffic for the dashboard.
--     Every post_id / path below references a demo row above. Dates spread
--     2026-10-10 .. 2026-10-27 (UTC). Ids are fixed so re-runs never duplicate;
--     events are append-only history so conflicts are ignored entirely.
-- ----------------------------------------------------------------------------
INSERT INTO public.analytics_events
    (id, site_id, post_id, event_type, session_id, path, referrer, created_at)
VALUES
    ('00000000-0000-4000-8000-000000000901', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a01', '/',                                                        'https://www.google.com/',          '2026-10-10 08:12:00+00'),
    ('00000000-0000-4000-8000-000000000902', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000401', 'article_view', 'sess-demo-a01', '/article/choose-right-ai-tool-honest-framework',      'https://www.google.com/',          '2026-10-10 08:15:00+00'),
    ('00000000-0000-4000-8000-000000000903', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000404', 'article_view', 'sess-demo-a02', '/article/smartphone-spec-sheet-decoded-india',          'https://t.me/bharattechpulse',     '2026-10-10 13:40:00+00'),
    ('00000000-0000-4000-8000-000000000904', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a03', '/category/cyber-safety',                                       'https://www.google.co.in/',        '2026-10-11 06:05:00+00'),
    ('00000000-0000-4000-8000-000000000905', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000419', 'article_view', 'sess-demo-a03', '/article/family-cyber-safety-conversation-30-minutes', 'https://www.google.co.in/',        '2026-10-11 06:09:00+00'),
    ('00000000-0000-4000-8000-000000000906', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000413', 'article_view', 'sess-demo-a04', '/article/digital-public-infrastructure-explained-simply', NULL,                           '2026-10-11 17:22:00+00'),
    ('00000000-0000-4000-8000-000000000907', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a05', '/',                                                        'https://www.bing.com/',            '2026-10-12 09:00:00+00'),
    ('00000000-0000-4000-8000-000000000908', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000410', 'article_view', 'sess-demo-a05', '/article/organise-government-documents-on-your-phone',  'https://www.bing.com/',            '2026-10-12 09:04:00+00'),
    ('00000000-0000-4000-8000-000000000909', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000411', 'article_view', 'sess-demo-a06', '/article/home-wifi-troubleshooting-routine',            'https://duckduckgo.com/',          '2026-10-12 20:35:00+00'),
    ('00000000-0000-4000-8000-000000000910', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a07', '/category/ai',                                               NULL,                           '2026-10-13 07:48:00+00'),
    ('00000000-0000-4000-8000-000000000911', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000402', 'article_view', 'sess-demo-a07', '/article/responsible-ai-writing-checklist-indian-students', '/category/ai',                  '2026-10-13 07:52:00+00'),
    ('00000000-0000-4000-8000-000000000912', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000416', 'article_view', 'sess-demo-a08', '/article/android-or-iphone-for-your-parents',            'https://www.google.com/',          '2026-10-13 15:10:00+00'),
    ('00000000-0000-4000-8000-000000000913', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000420', 'article_view', 'sess-demo-a09', '/article/spot-payment-fraud-lures-pattern-guide',         'https://t.me/bharattechpulse',     '2026-10-14 08:26:00+00'),
    ('00000000-0000-4000-8000-000000000914', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a10', '/',                                                        'https://www.google.co.in/',        '2026-10-14 12:02:00+00'),
    ('00000000-0000-4000-8000-000000000915', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000405', 'article_view', 'sess-demo-a10', '/article/how-long-should-your-next-phone-last',            'https://www.google.co.in/',        '2026-10-14 12:07:00+00'),
    ('00000000-0000-4000-8000-000000000916', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000422', 'article_view', 'sess-demo-a11', '/article/first-college-laptop-what-to-prioritise',         'https://duckduckgo.com/',          '2026-10-15 10:18:00+00'),
    ('00000000-0000-4000-8000-000000000917', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000417', 'article_view', 'sess-demo-a11', '/article/laptop-vs-desktop-vs-mini-pc-home-study',         '/article/first-college-laptop-what-to-prioritise', '2026-10-15 10:26:00+00'),
    ('00000000-0000-4000-8000-000000000918', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a12', '/category/how-to',                                             NULL,                           '2026-10-15 19:44:00+00'),
    ('00000000-0000-4000-8000-000000000919', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000414', 'article_view', 'sess-demo-a13', '/article/app-permission-consent-changes-india-reading-guide', 'https://www.google.com/',     '2026-10-16 06:31:00+00'),
    ('00000000-0000-4000-8000-000000000920', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000407', 'article_view', 'sess-demo-a13', '/article/app-permission-check-after-install',              '/article/app-permission-consent-changes-india-reading-guide', '2026-10-16 06:39:00+00'),
    ('00000000-0000-4000-8000-000000000921', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000401', 'article_view', 'sess-demo-a14', '/article/choose-right-ai-tool-honest-framework',           'https://www.linkedin.com/',        '2026-10-16 14:20:00+00'),
    ('00000000-0000-4000-8000-000000000922', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a15', '/',                                                        'https://t.me/bharattechpulse',     '2026-10-17 08:05:00+00'),
    ('00000000-0000-4000-8000-000000000923', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000419', 'article_view', 'sess-demo-a15', '/article/family-cyber-safety-conversation-30-minutes',    'https://t.me/bharattechpulse',     '2026-10-17 08:11:00+00'),
    ('00000000-0000-4000-8000-000000000924', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000423', 'article_view', 'sess-demo-a16', '/article/choosing-phone-for-elderly-parent-checklist',     'https://www.google.co.in/',        '2026-10-17 16:52:00+00'),
    ('00000000-0000-4000-8000-000000000925', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000413', 'article_view', 'sess-demo-a17', '/article/digital-public-infrastructure-explained-simply',  'https://www.google.com/',          '2026-10-18 09:26:00+00'),
    ('00000000-0000-4000-8000-000000000926', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000414', 'article_view', 'sess-demo-a17', '/article/app-permission-consent-changes-india-reading-guide', '/article/digital-public-infrastructure-explained-simply', '2026-10-18 09:33:00+00'),
    ('00000000-0000-4000-8000-000000000927', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a18', '/category/smartphones',                                        NULL,                           '2026-10-18 21:14:00+00'),
    ('00000000-0000-4000-8000-000000000928', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000404', 'article_view', 'sess-demo-a18', '/article/smartphone-spec-sheet-decoded-india',             '/category/smartphones',          '2026-10-18 21:17:00+00'),
    ('00000000-0000-4000-8000-000000000929', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000405', 'article_view', 'sess-demo-a18', '/article/how-long-should-your-next-phone-last',            '/article/smartphone-spec-sheet-decoded-india', '2026-10-18 21:25:00+00'),
    ('00000000-0000-4000-8000-000000000930', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000411', 'article_view', 'sess-demo-a19', '/article/home-wifi-troubleshooting-routine',               'https://duckduckgo.com/',        '2026-10-19 11:03:00+00'),
    ('00000000-0000-4000-8000-000000000931', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a20', '/',                                                        'https://www.google.com/',          '2026-10-20 07:40:00+00'),
    ('00000000-0000-4000-8000-000000000932', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000420', 'article_view', 'sess-demo-a20', '/article/spot-payment-fraud-lures-pattern-guide',          'https://www.google.com/',        '2026-10-20 07:46:00+00'),
    ('00000000-0000-4000-8000-000000000933', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000402', 'article_view', 'sess-demo-a21', '/article/responsible-ai-writing-checklist-indian-students', 'https://t.me/bharattechpulse',   '2026-10-21 13:58:00+00'),
    ('00000000-0000-4000-8000-000000000934', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a22', '/category/comparisons',                                        NULL,                           '2026-10-22 10:21:00+00'),
    ('00000000-0000-4000-8000-000000000935', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000416', 'article_view', 'sess-demo-a22', '/article/android-or-iphone-for-your-parents',              '/category/comparisons',        '2026-10-22 10:25:00+00'),
    ('00000000-0000-4000-8000-000000000936', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000410', 'article_view', 'sess-demo-a23', '/article/organise-government-documents-on-your-phone',     'https://www.google.co.in/',      '2026-10-23 18:34:00+00'),
    ('00000000-0000-4000-8000-000000000937', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000401', 'article_view', 'sess-demo-a24', '/article/choose-right-ai-tool-honest-framework',            'https://duckduckgo.com/',        '2026-10-24 08:47:00+00'),
    ('00000000-0000-4000-8000-000000000938', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000422', 'article_view', 'sess-demo-a25', '/article/first-college-laptop-what-to-prioritise',           'https://www.google.com/',        '2026-10-25 15:12:00+00'),
    ('00000000-0000-4000-8000-000000000939', '00000000-0000-4000-8000-000000000001', NULL, 'page_view',   'sess-demo-a26', '/article/smartphone-spec-sheet-decoded-india',                 'https://t.me/bharattechpulse',     '2026-10-26 19:03:00+00'),
    ('00000000-0000-4000-8000-000000000940', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000419', 'article_view', 'sess-demo-a26', '/article/family-cyber-safety-conversation-30-minutes',     '/article/smartphone-spec-sheet-decoded-india', '2026-10-27 06:55:00+00')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
COMMIT;
-- End of 006_seed_data.sql
