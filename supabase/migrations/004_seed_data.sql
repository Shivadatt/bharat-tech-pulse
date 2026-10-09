-- ============================================================================
-- 004_seed_data.sql
-- Bharat Tech Pulse (site slug: india_tech) — deterministic seed data.
-- Owned by SUB-AGENT 1 (database architecture + migrations).
--
-- Seeds the site row, its 8 editorial categories, and the 4 editorial bylines.
-- Does NOT seed posts or tags.
-- The authors are required for the CMS write path: the article editor refuses
-- to save while the site has no authors (it must attach a byline), so without
-- this the first post could never be created. They are seeded UNLINKED
-- (user_id NULL) — linking one to an auth account is an admin action.
-- Safe to re-run: site insert uses ON CONFLICT DO NOTHING; categories and
-- authors upsert.
-- Must run AFTER 001_initial_schema.sql.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Site row. Fixed UUID keeps local, staging, and production references
-- stable across environments.
-- Values mirror lib/app/config/site_config.dart.
-- ----------------------------------------------------------------------------
INSERT INTO public.sites (id, name, slug, domain, description)
VALUES (
    '00000000-0000-4000-8000-000000000001',
    'Bharat Tech Pulse',
    'india_tech',
    'https://bharattechpulse.in',
    'Bharat Tech Pulse delivers actionable AI tools tutorials, unbiased smartphone comparisons, practical how-to guides, and cyber safety awareness curated specifically for Indian tech enthusiasts and families.'
)
ON CONFLICT (slug) DO NOTHING;

-- ----------------------------------------------------------------------------
-- Editorial categories (sort_order 1..8). Category UUIDs are deterministic
-- (derived from the site UUID block) so cross-environment references stay
-- stable; name/description/sort_order are refreshed on re-run.
-- ----------------------------------------------------------------------------
INSERT INTO public.categories (id, site_id, name, slug, description, sort_order, icon_code, subcategories) VALUES
    ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000001', 'AI & AI Tools',        'ai',           'AI tool tutorials, prompts, and practical machine-learning guides for Indian users.', 1, 'psychology',      ARRAY['Indic LLMs','Productivity AI','Coding Copilots','Image & Video Gen']),
    ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000001', 'Smartphones',          'smartphones',  'Smartphone reviews, comparisons, and buying advice for the Indian market.',           2, 'phone_android',   ARRAY['Budget (Under Rs 15K)','Mid-range (Rs 15K-30K)','Flagship Killers','Premium']),
    ('00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000001', 'Apps',                 'apps',         'App reviews, recommendations, and practical how-tos.',                                3, 'apps',            ARRAY['Fintech & UPI','Govt & Citizen Utility','Productivity','Entertainment']),
    ('00000000-0000-4000-8000-000000000104', '00000000-0000-4000-8000-000000000001', 'How-To Guides',        'how-to',       'Step-by-step how-to guides for everyday technology.',                                 4, 'menu_book',       ARRAY['Govt Services','Android Tweaks','iOS Tips','Windows & Web']),
    ('00000000-0000-4000-8000-000000000105', '00000000-0000-4000-8000-000000000001', 'Tech Updates',         'tech-news',    'Latest technology news and updates from India and beyond.',                           5, 'newspaper',       ARRAY['Telecom & 5G','Startups & Funding','Semiconductors','Policy & DPDP']),
    ('00000000-0000-4000-8000-000000000106', '00000000-0000-4000-8000-000000000001', 'Comparisons',          'comparisons',  'Head-to-head comparisons to help you choose the right tech.',                         6, 'compare_arrows',  ARRAY['App Showdowns','Phone Battles','Network Tests','Subscription Plans']),
    ('00000000-0000-4000-8000-000000000107', '00000000-0000-4000-8000-000000000001', 'Cyber Safety',         'cyber-safety', 'Cyber safety, privacy, and online security awareness for Indian families.',           7, 'security',        ARRAY['Scam Alerts','Privacy Settings','Reporting Portals','Family Cyber Safety']),
    ('00000000-0000-4000-8000-000000000108', '00000000-0000-4000-8000-000000000001', 'Buying Guides',        'buying-guides','Curated buying guides and best-of recommendations.',                                  8, 'shopping_bag',    ARRAY['Phones Under Rs 20,000','Student Laptops','Smart TVs','TWS Earbuds'])
ON CONFLICT (site_id, slug) DO UPDATE
SET name          = EXCLUDED.name,
    description   = EXCLUDED.description,
    sort_order    = EXCLUDED.sort_order,
    icon_code     = EXCLUDED.icon_code,
    subcategories = EXCLUDED.subcategories;

-- ----------------------------------------------------------------------------
-- Editorial bylines (user_id left NULL = unlinked). Applied by superuser, so
-- the admin-only RLS write policy on authors does not apply here.
-- ----------------------------------------------------------------------------
INSERT INTO public.authors (id, site_id, name, slug, bio, avatar_url, designation, social_links) VALUES
    ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000001', 'Aravind Sharma', 'aravind-sharma',
     'Aravind has spent 12 years covering Indian consumer electronics, emerging AI agents, and semiconductor supply chains across Bengaluru and Hyderabad.',
     'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
     'Senior Tech Editor & AI Lead',
     '{"twitter":"@aravind_tech","linkedin":"in/aravindsharma-tech","email":"aravind@bharattechpulse.in"}'::jsonb),
    ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000001', 'Priya Nambiar', 'priya-nambiar',
     'Priya investigates digital arrest rackets, payment gateway vulnerabilities, and consumer privacy rights under the DPDP Act 2023.',
     'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=300&q=80',
     'Cybersecurity & Fintech Specialist',
     '{"twitter":"@priya_cyberin","linkedin":"in/priyanambiar-cyber","email":"priya@bharattechpulse.in"}'::jsonb),
    ('00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000001', 'Rohit Deshmukh', 'rohit-deshmukh',
     'Specialist in Indian smartphone value segments (under Rs 15k to Rs 40k), benchmark testing, camera shootouts, and battery longevity.',
     'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
     'Smartphone & Gadget Reviewer',
     '{"twitter":"@rohit_gadgets","linkedin":"in/rohitdeshmukh-tech","email":"rohit@bharattechpulse.in"}'::jsonb),
    ('00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000001', 'Sneha Kulkarni', 'sneha-kulkarni',
     'Sneha breaks down complex digital public infrastructure like DigiLocker, ONDC, UPI Lite, and state portal workflows into step-by-step guides.',
     'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=300&q=80',
     'How-To & App Ecosystem Lead',
     '{"twitter":"@sneha_guides","linkedin":"in/snehakulkarni-in","email":"sneha@bharattechpulse.in"}'::jsonb)
ON CONFLICT (site_id, slug) DO UPDATE
SET name         = EXCLUDED.name,
    bio          = EXCLUDED.bio,
    avatar_url   = EXCLUDED.avatar_url,
    designation  = EXCLUDED.designation,
    social_links = EXCLUDED.social_links;

-- End of 004_seed_data.sql
