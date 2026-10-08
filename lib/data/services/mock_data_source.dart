import '../models/article_model.dart';
import '../models/author_model.dart';
import '../models/category_model.dart';
import '../models/tag_model.dart';

/// Comprehensive realistic mock data source for Bharat Tech Pulse.
class MockDataSource {
  // ----------------------------------------------------
  // AUTHORS
  // ----------------------------------------------------
  static final List<AuthorModel> authors = [
    const AuthorModel(
      id: 'author-1',
      slug: 'aravind-sharma',
      name: 'Aravind Sharma',
      role: 'Senior Tech Editor & AI Lead',
      bio:
          'Aravind has spent 12 years covering Indian consumer electronics, emerging AI agents, and semiconductor supply chains across Bengaluru and Hyderabad.',
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
      twitter: '@aravind_tech',
      linkedin: 'in/aravindsharma-tech',
      email: 'aravind@bharattechpulse.in',
    ),
    const AuthorModel(
      id: 'author-2',
      slug: 'priya-nambiar',
      name: 'Priya Nambiar',
      role: 'Cybersecurity & Fintech Specialist',
      bio:
          'Priya investigates digital arrest rackets, payment gateway vulnerabilities, and consumer privacy rights under the DPDP Act 2023.',
      avatarUrl:
          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=300&q=80',
      twitter: '@priya_cyberin',
      linkedin: 'in/priyanambiar-cyber',
      email: 'priya@bharattechpulse.in',
    ),
    const AuthorModel(
      id: 'author-3',
      slug: 'rohit-deshmukh',
      name: 'Rohit Deshmukh',
      role: 'Smartphone & Gadget Reviewer',
      bio:
          'Specialist in Indian smartphone value segments (under ₹15k to ₹40k), benchmark testing, camera shootouts, and battery longevity.',
      avatarUrl:
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
      twitter: '@rohit_gadgets',
      linkedin: 'in/rohitdeshmukh-tech',
      email: 'rohit@bharattechpulse.in',
    ),
    const AuthorModel(
      id: 'author-4',
      slug: 'sneha-kulkarni',
      name: 'Sneha Kulkarni',
      role: 'How-To & App Ecosystem Lead',
      bio:
          'Sneha breaks down complex digital public infrastructure like DigiLocker, ONDC, UPI Lite, and state portal workflows into step-by-step guides.',
      avatarUrl:
          'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=300&q=80',
      twitter: '@sneha_guides',
      linkedin: 'in/snehakulkarni-in',
      email: 'sneha@bharattechpulse.in',
    ),
  ];

  // ----------------------------------------------------
  // CATEGORIES
  // ----------------------------------------------------
  static final List<CategoryModel> categories = [
    const CategoryModel(
      id: 'cat-ai',
      slug: 'ai',
      name: 'AI & AI Tools',
      description:
          'Indic LLMs, conversational agents, productivity workflows, and practical artificial intelligence tools for Indian developers, students, and businesses.',
      iconCode: 'psychology',
      subcategories: ['Indic LLMs', 'Productivity AI', 'Coding Copilots', 'Image & Video Gen'],
    ),
    const CategoryModel(
      id: 'cat-smartphones',
      slug: 'smartphones',
      name: 'Smartphones',
      description:
          'In-depth reviews, 5G battery benchmarks, camera comparisons, and value analysis for smartphones sold across India.',
      iconCode: 'phone_android',
      subcategories: ['Budget (Under ₹15K)', 'Mid-range (₹15K-₹30K)', 'Flagship Killers', 'Premium'],
    ),
    const CategoryModel(
      id: 'cat-apps',
      slug: 'apps',
      name: 'Apps',
      description:
          'Curated Android & iOS apps, Digital Public Infrastructure tools, productivity software, and utility applications popular in India.',
      iconCode: 'apps',
      subcategories: ['Fintech & UPI', 'Govt & Citizen Utility', 'Productivity', 'Entertainment'],
    ),
    const CategoryModel(
      id: 'cat-how-to',
      slug: 'how-to',
      name: 'How-To Guides',
      description:
          'Practical, verified tutorials for DigiLocker, IRCTC booking, Aadhaar updates, fast Wi-Fi configuration, and smartphone maintenance.',
      iconCode: 'menu_book',
      subcategories: ['Govt Services', 'Android Tweaks', 'iOS Tips', 'Windows & Web'],
    ),
    const CategoryModel(
      id: 'cat-tech-news',
      slug: 'tech-news',
      name: 'Tech Updates',
      description:
          'Breaking news across Indian tech startups, telecom policy (TRAI/DoT), semiconductor manufacturing, and digital infrastructure.',
      iconCode: 'newspaper',
      subcategories: ['Telecom & 5G', 'Startups & Funding', 'Semiconductors', 'Policy & DPDP'],
    ),
    const CategoryModel(
      id: 'cat-comparisons',
      slug: 'comparisons',
      name: 'Comparisons',
      description:
          'Head-to-head showdowns: PhonePe vs Google Pay, Jio vs Airtel 5G, Snapdragon vs MediaTek Dimensity, and mid-range devices.',
      iconCode: 'compare_arrows',
      subcategories: ['App Showdowns', 'Phone Battles', 'Network Tests', 'Subscription Plans'],
    ),
    const CategoryModel(
      id: 'cat-cyber-safety',
      slug: 'cyber-safety',
      name: 'Cyber Safety',
      description:
          'Alerts and defensive strategies against Digital Arrest scams, OTP theft, fake APK loans, WhatsApp impersonation, and reporting on Chakshu / 1930.',
      iconCode: 'security',
      subcategories: ['Scam Alerts', 'Privacy Settings', 'Reporting Portals', 'Family Cyber Safety'],
    ),
    const CategoryModel(
      id: 'cat-buying-guides',
      slug: 'buying-guides',
      name: 'Buying Guides',
      description:
          'Curated purchase recommendations for every budget during Flipkart Big Billion Days, Amazon Great Indian Festival, and all year round.',
      iconCode: 'shopping_bag',
      subcategories: ['Phones Under ₹20,000', 'Student Laptops', 'Smart TVs', 'TWS Earbuds'],
    ),
  ];

  // ----------------------------------------------------
  // TAGS
  // ----------------------------------------------------
  static final List<TagModel> tags = [
    const TagModel(id: 't-upi', slug: 'upi', name: 'UPI 2.0', count: 12),
    const TagModel(id: 't-5g', slug: '5g-india', name: '5G India', count: 9),
    const TagModel(id: 't-sarvam', slug: 'sarvam-ai', name: 'Sarvam AI', count: 6),
    const TagModel(id: 't-scams', slug: 'cyber-safety', name: 'Scam Alert', count: 14),
    const TagModel(id: 't-digilocker', slug: 'digilocker', name: 'DigiLocker', count: 8),
    const TagModel(id: 't-under20k', slug: 'under-20k', name: 'Under ₹20,000', count: 11),
    const TagModel(id: 't-deepseek', slug: 'deepseek', name: 'DeepSeek LLM', count: 7),
    const TagModel(id: 't-jio-airtel', slug: 'jio-vs-airtel', name: 'Jio vs Airtel', count: 5),
    const TagModel(id: 't-chakshu', slug: 'chakshu', name: 'Chakshu Portal', count: 4),
    const TagModel(id: 't-irctc', slug: 'irctc', name: 'IRCTC Hacks', count: 5),
  ];

  // ----------------------------------------------------
  // 20+ REALISTIC INDIAN ARTICLES
  // ----------------------------------------------------
  static final List<ArticleModel> articles = [
    // 1: AI Hero
    ArticleModel(
      id: 'art-1',
      slug: 'sarvam-ai-open-source-indic-llm-breakthrough',
      title: 'Sarvam AI Unveils Open Indic LLMs: Why It Matters for 22 Indian Languages',
      excerpt:
          'Bengaluru-based Sarvam AI has released powerful open-source models supporting regional speech-to-text and reasoning across Hindi, Tamil, Telugu, and Bengali. Here is what makes them special.',
      content: '''
India’s multilingual reality poses distinct computational challenges that Western frontier models often fail to grasp effectively. Sarvam AI, based out of Bengaluru, has announced breakthrough open-source models designed natively for token efficiency across 22 Scheduled Indian languages.

### The Tokenizer Disadvantage in Indic Computing
Historically, models trained primarily on English text tokenized Devanagari and Dravidian scripts inefficiently. A Hindi sentence could take up to 4x to 6x more tokens than its English equivalent, driving API costs astronomically higher for Indian startups.

Sarvam's custom tokenizer directly solves this inequality:
- Compresses Indic text representation by over 60%.
- Native support for Hinglish code-switching in real-time conversational flows.
- Sub-second latency optimized for edge servers deployed on Indian cloud infrastructure.

### Voice-First Architecture for Bharat
For millions of users outside Tier-1 metros, speech is the preferred digital interface. The new Sarvam speech models provide state-of-the-art Automatic Speech Recognition (ASR) capable of parsing heavy regional accents, background noise from Indian streets, and rapid language switching.
      ''',
      categorySlug: 'ai',
      categoryName: 'AI & AI Tools',
      subcategory: 'Indic LLMs',
      tags: ['sarvam-ai', 'ai-india', 'open-source'],
      author: authors[0],
      publishedAt: DateTime(2026, 9, 28, 10, 30),
      updatedAt: DateTime(2026, 9, 29, 14, 15),
      featuredImage:
          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 6,
      isFeatured: true,
      isTrending: true,
      isPopular: true,
      viewCount: 24500,
      keyTakeaways: [
        'Custom Indic tokenizer slashes token overhead by 60% compared to standard Llama/GPT tokenizers.',
        'Supports 22 official languages with seamless Hinglish and Tamil-English code-switching.',
        'Fully open-weights available on Hugging Face for Indian developers and enterprises.',
      ],
      faqs: [
        const ArticleFaq(
          question: 'Can I run Sarvam AI models locally on my laptop?',
          answer:
              'Yes, 2B and 7B quantized GGUF weights run comfortably on laptops with 16GB RAM using Ollama or LM Studio.',
        ),
        const ArticleFaq(
          question: 'Is Sarvam AI free for commercial deployment?',
          answer:
              'The open-source weights are released under Apache 2.0 license, permitting commercial SaaS integration without royalty.',
        ),
      ],
      toc: [
        const ArticleTocItem(id: 'tokenizer', title: 'The Tokenizer Disadvantage in Indic Computing'),
        const ArticleTocItem(id: 'voice-first', title: 'Voice-First Architecture for Bharat'),
      ],
    ),

    // 2: Cyber Safety Trending
    ArticleModel(
      id: 'art-2',
      slug: 'digital-arrest-scam-how-to-protect-yourself-and-report-1930',
      title: 'Digital Arrest Scams: How Fake CBI & Police Video Calls Work and How to Stay Safe',
      excerpt:
          'Indian citizens have lost over ₹120 Crore to fraudsters claiming to be Mumbai Cyber Crime or ED officials via Skype. Learn the warning signs and instant reporting protocols.',
      content: '''
Cybercriminals have industrialized a terrifying extortion tactic known as "Digital Arrest". Victims receive an urgent call claiming their Aadhaar was used to ship narcotics or illicit SIM cards, followed by a coerced Skype call with fake police backdrops.

### Anatomy of the Fake CBI Interrogation
The scam relies entirely on psychological panic and isolation:
1. **The Fear Induction**: The victim is told an arrest warrant has been issued in their name.
2. **The Isolation Directive**: The scammers demand continuous video surveillance, forbidding calls to relatives or lawyers under threat of immediate physical raid.
3. **The "Verification" Escrow**: Victims are instructed to liquidate fixed deposits and wire money to a "Govt Reserve Escrow account" for verification, with promises of a refund within 24 hours.

### Official Rule: There Is No Such Thing as Digital Arrest
The Ministry of Home Affairs (MHA) and Indian Cyber Crime Coordination Centre (I4C) have repeatedly clarified that no law enforcement agency conducts arrests, interrogations, or financial auditing over Skype or WhatsApp.
      ''',
      categorySlug: 'cyber-safety',
      categoryName: 'Cyber Safety',
      subcategory: 'Scam Alerts',
      tags: ['cyber-safety', 'chakshu', '1930'],
      author: authors[1],
      publishedAt: DateTime(2026, 9, 27, 9, 0),
      updatedAt: DateTime(2026, 9, 27, 9, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1563986768609-322da13575f3?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 5,
      isFeatured: false,
      isTrending: true,
      isPopular: true,
      viewCount: 38200,
      keyTakeaways: [
        'No Indian police department, CBI, or ED conducts video interrogations or "digital arrests".',
        'Never transfer funds to any third-party account under legal threats.',
        'Immediately dial the national cyber helpline 1930 and report via cybercrime.gov.in or Chakshu portal within the golden hour.',
      ],
      faqs: [
        const ArticleFaq(
          question: 'What is the Golden Hour in cyber fraud?',
          answer:
              'The first 2 hours after a fraudulent transfer. Calling 1930 during this window allows banks to freeze the recipient account before money is withdrawn at an ATM.',
        ),
      ],
      toc: [
        const ArticleTocItem(id: 'anatomy', title: 'Anatomy of the Fake CBI Interrogation'),
        const ArticleTocItem(id: 'official-rule', title: 'Official Rule: There Is No Digital Arrest'),
      ],
    ),

    // 3: Smartphones Buying Guide
    ArticleModel(
      id: 'art-3',
      slug: 'best-smartphones-under-20000-india-2026',
      title: 'Best Smartphones Under ₹20,000 in India (Q4 2026 Edition): Real Benchmarks Tested',
      excerpt:
          'From OnePlus Nord CE 4 Lite to Redmi Note 14 and Vivo T3x, we tested battery stamina, heat dissipation in Indian summers, and real-world camera samples.',
      content: '''
The sub-₹20,000 segment remains the undisputed battleground for Indian smartphone buyers. In 2026, features that were once flagship-exclusive—such as 120Hz curved AMOLED displays, Sony LYT camera sensors, and 67W fast charging—have comfortably trickled down.

### Top Contenders Ranked
1. **Redmi Note 14 5G**: Best all-rounder display with Corning Gorilla Glass Victus 2 and clean haptics.
2. **OnePlus Nord CE 4**: Outstanding battery optimization with Snapdragon 7 Gen 3 and zero bloatware ads.
3. **iQOO Z9s 5G**: Unrivaled gaming benchmark performance in BGMI at smooth 60fps with minimal throttling.
4. **Realme 13+ 5G**: Exceptional thermal dissipation chamber suited for humid Indian climates.
      ''',
      categorySlug: 'smartphones',
      categoryName: 'Smartphones',
      subcategory: 'Budget (Under ₹15K)',
      tags: ['under-20k', 'smartphones', 'reviews'],
      author: authors[2],
      publishedAt: DateTime(2026, 9, 25, 14, 0),
      updatedAt: DateTime(2026, 9, 26, 11, 20),
      featuredImage:
          'https://images.unsplash.com/photo-1598327105666-5b89351aff97?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 7,
      isFeatured: false,
      isTrending: true,
      isPopular: true,
      viewCount: 42100,
      keyTakeaways: [
        'Look for minimum 6GB LPDDR4X RAM and 128GB UFS 2.2 storage.',
        'Prioritize Sony IMX882 or LYT-600 sensors with Optical Image Stabilization (OIS).',
        'Check for at least 3 years of Android security patch commitments.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'contenders', title: 'Top Contenders Ranked'),
      ],
    ),

    // 4: How-To DigiLocker
    ArticleModel(
      id: 'art-4',
      slug: 'how-to-link-digilocker-with-whatsapp-and-download-documents',
      title: 'How to Download Aadhaar, PAN & Driving License Directly on WhatsApp via DigiLocker',
      excerpt:
          'Skip app downloads. The official MyGov Helpdesk on WhatsApp allows you to fetch verified government IDs in under 60 seconds with simple OTP verification.',
      content: '''
Most citizens are unaware that DigiLocker maintains an official, encrypted integration directly inside WhatsApp through the Government of India MyGov chatbot.

### Step-by-Step WhatsApp Setup
1. Save the official MyGov WhatsApp Helpdesk number: **+91 9013151515**.
2. Send a greeting such as "Hi" or "Namaste".
3. Select "DigiLocker Services" from the automated menu.
4. Enter your 12-digit Aadhaar number to verify your linked phone number.
5. Provide the one-time OTP received via SMS.
6. Choose the document you need: PAN Card, Driving License, Class 10/12 Marksheets, or Vehicle RC.
7. Receive the digitally signed, court-admissible PDF instantly in your chat.
      ''',
      categorySlug: 'how-to',
      categoryName: 'How-To Guides',
      subcategory: 'Govt Services',
      tags: ['digilocker', 'whatsapp', 'how-to'],
      author: authors[3],
      publishedAt: DateTime(2026, 9, 24, 8, 30),
      updatedAt: DateTime(2026, 9, 24, 8, 30),
      featuredImage:
          'https://images.unsplash.com/photo-1616469829941-c7200edec809?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 4,
      isFeatured: false,
      isTrending: false,
      isPopular: true,
      viewCount: 19800,
      keyTakeaways: [
        'Official MyGov Helpdesk number is +91 9013151515 with green verified tick.',
        'PDFs downloaded through WhatsApp are legally recognized under IT Act 2000 Rule 9A.',
        'Works seamlessly on 2G/3G connections without installing heavy apps.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'setup', title: 'Step-by-Step WhatsApp Setup'),
      ],
    ),

    // 5: Comparisons UPI
    ArticleModel(
      id: 'art-5',
      slug: 'phonepe-vs-google-pay-vs-bhim-2026-comparison',
      title: 'PhonePe vs Google Pay vs BHIM: Which UPI App Is Safest and Has Least Failed Transactions?',
      excerpt:
          'With NPCI market share caps and UPI Lite auto-top-up rolling out, we tested server response times, refund speeds, and privacy permissions across the big three.',
      content: '''
UPI processes over 15 billion transactions monthly in India. But when a payment hangs at a bustling Kirana store counter, which app resolves pending debits fastest?

### 1. Transaction Success Rate (TSR)
According to NPCI monthly logs, BHIM leads raw core success rates because it connects directly via NPCI gateways without intermediary tracking layers. PhonePe ranks second with heavy server caching, while Google Pay occasionally stalls on complex multi-SIM dual VoLTE switching.

### 2. Offline Micro-Payments: UPI Lite
All three now support UPI Lite with on-device biometric auth up to ₹500 without requiring your 6-digit bank PIN. This eliminates failed transactions caused by weekend bank server maintenance.
      ''',
      categorySlug: 'comparisons',
      categoryName: 'Comparisons',
      subcategory: 'App Showdowns',
      tags: ['upi', 'fintech', 'comparisons'],
      author: authors[1],
      publishedAt: DateTime(2026, 9, 22, 11, 0),
      updatedAt: DateTime(2026, 9, 22, 11, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1556742049-0a67c5574f73?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 6,
      isFeatured: false,
      isTrending: true,
      isPopular: true,
      viewCount: 31200,
      keyTakeaways: [
        'BHIM offers zero advertisement clutter and fastest direct gateway pings.',
        'PhonePe provides the best payment history search and merchant cashback tracking.',
        'Activate UPI Lite on any app to bypass bank server downtime for small chai/grocery payments.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'tsr', title: 'Transaction Success Rate'),
        const ArticleTocItem(id: 'upi-lite', title: 'Offline Micro-Payments: UPI Lite'),
      ],
    ),

    // 6: Apps ONDC
    ArticleModel(
      id: 'art-6',
      slug: 'top-ondc-buyer-apps-ordering-food-and-groceries-cheaper',
      title: 'Top ONDC Buyer Apps: How to Order Food & Groceries Cheaper Than Swiggy and Zomato',
      excerpt:
          'Open Network for Digital Commerce (ONDC) allows direct restaurant ordering with zero commissions. Here are the 5 best buyer apps currently saving customers 15-25%.',
      content: '''
The Indian government's open commerce protocol ONDC is fundamentally altering how urban Indians order food, groceries, and cab rides. Because restaurants don’t pay 25-30% aggregator commissions, menu prices are frequently listed significantly lower.

### Best ONDC Buyer Apps Tested
1. **Magicpin**: The most reliable food delivery tracking and restaurant coverage across Delhi NCR, Mumbai, and Bengaluru.
2. **Paytm ONDC**: Embedded inside Paytm search with instant bank discounts and cashback coupons.
3. **Pincode by PhonePe**: Clean hyper-local UI focused on fresh produce and neighboring Kirana stores.
4. **Mystore**: Superb interface for artisan handicrafts and direct-to-consumer organic snacks.
      ''',
      categorySlug: 'apps',
      categoryName: 'Apps',
      subcategory: 'Fintech & UPI',
      tags: ['ondc', 'apps', 'food-delivery'],
      author: authors[3],
      publishedAt: DateTime(2026, 9, 20, 16, 15),
      updatedAt: DateTime(2026, 9, 20, 16, 15),
      featuredImage:
          'https://images.unsplash.com/photo-1526367790999-0150786686a2?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 5,
      isFeatured: false,
      isTrending: false,
      isPopular: false,
      viewCount: 15400,
      keyTakeaways: [
        'ONDC food prices are typically 15-20% lower on identical restaurant menus.',
        'Delivery times may vary slightly since third-party logistics (Shadowfax/Dunzo) handle fulfillment.',
        'Magicpin and Paytm offer the smoothest refunds for canceled orders.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'best-apps', title: 'Best ONDC Buyer Apps Tested'),
      ],
    ),

    // 7: Tech Updates 5G SA
    ArticleModel(
      id: 'art-7',
      slug: 'jio-vs-airtel-5g-standalone-true-speeds-and-battery-drain',
      title: 'Jio True 5G vs Airtel 5G Plus: Speed Tests, Coverage & Smartphone Battery Drain Tested',
      excerpt:
          'We traveled 4,000 km across tier-1 and tier-3 Indian cities comparing Standalone (SA) vs Non-Standalone (NSA) 5G architecture. Here is the unvarnished truth.',
      content: '''
India’s two telecom behemoths took radically diverging engineering paths when rolling out 5G: Reliance Jio opted for greenfield Standalone (SA) 5G on dedicated sub-GHz 700MHz spectrum, while Bharti Airtel deployed Non-Standalone (NSA) utilizing existing 4G LTE core anchors.

### Real World Speed & Latency Comparison
- **Jio 5G SA**: Superior indoor penetration thanks to Band n28 (700 MHz). Consistent upload speeds inside basements and elevators. Latency hovers around 18-24ms.
- **Airtel 5G NSA**: Higher peak burst speeds in open outdoor plazas (often topping 850 Mbps), but slightly higher smartphone battery consumption due to simultaneous 4G+5G radio handshakes.
      ''',
      categorySlug: 'tech-news',
      categoryName: 'Tech Updates',
      subcategory: 'Telecom & 5G',
      tags: ['5g-india', 'jio-vs-airtel', 'telecom'],
      author: authors[0],
      publishedAt: DateTime(2026, 9, 18, 12, 0),
      updatedAt: DateTime(2026, 9, 18, 12, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 7,
      isFeatured: false,
      isTrending: true,
      isPopular: true,
      viewCount: 29800,
      keyTakeaways: [
        'Jio SA provides better indoor coverage via 700MHz spectrum.',
        'Airtel NSA achieves slightly higher peak download bursts in unobstructed outdoor tests.',
        'Switch to "Auto 5G" mode on smartphones to prevent unnecessary battery drain while idling.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'speed-latency', title: 'Real World Speed & Latency Comparison'),
      ],
    ),

    // 8: Buying Guides Earbuds
    ArticleModel(
      id: 'art-8',
      slug: 'best-anc-earbuds-under-3000-for-indian-commuters',
      title: 'Best ANC TWS Earbuds Under ₹3,000 for Metro & Local Train Commuters in India',
      excerpt:
          'We tested active noise cancellation against the screeching sounds of Delhi Metro and Mumbai locals. These 4 models actually silence ambient transit noise.',
      content: '''
Commuting on Indian public transit is one of the toughest stress tests for active noise canceling (ANC) headphones. The combination of screeching rail tracks, PA announcements, and crowd chatter easily overpowers budget ANC algorithms.

### Tested Winners
1. **Realme Buds Air 6**: 50dB hybrid ANC with LHDC high-res codec and exceptional mic isolation.
2. **OnePlus Nord Buds 3 Pro**: Punchy BassWave tuning with 49dB ANC and intuitive dual-device pairing.
3. **Oppo Enco Air 3 Pro**: Bamboo fiber diaphragm with natural vocal reproduction and IP55 water resistance for monsoon commutes.
      ''',
      categorySlug: 'buying-guides',
      categoryName: 'Buying Guides',
      subcategory: 'TWS Earbuds',
      tags: ['audio', 'under-3000', 'buying-guide'],
      author: authors[2],
      publishedAt: DateTime(2026, 9, 16, 15, 45),
      updatedAt: DateTime(2026, 9, 16, 15, 45),
      featuredImage:
          'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 5,
      isFeatured: false,
      isTrending: false,
      isPopular: false,
      viewCount: 16900,
      keyTakeaways: [
        'Ensure hybrid dual-mic ANC rather than single feedforward noise cancellation.',
        'Look for IP55 splash resistance rating to survive sudden Indian monsoon showers.',
        'Dual connection allows seamless switching between your laptop and phone.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'winners', title: 'Tested Winners'),
      ],
    ),

    // 9: AI DeepSeek
    ArticleModel(
      id: 'art-9',
      slug: 'deepseek-coder-v2-complete-setup-guide-for-indian-developers',
      title: 'DeepSeek-V2 for Indian Developers: Free High-Performance Coding AI Setup',
      excerpt:
          'DeepSeek offers near-Claude 3.5 Sonnet coding performance at 1/10th the token pricing. Here is how to configure it in VS Code and Cursor using Indian credit cards without Forex markup.',
      content: '''
For Indian software developers and freelancers, API bills in US Dollars with 20% TCS/GST deductions can eat into margins rapidly. DeepSeek has emerged as the go-to alternative, offering exceptional reasoning on Python, Dart, and TypeScript codebases.

### Connecting in VS Code via Continue.dev
1. Install the open-source **Continue** extension in VS Code.
2. Generate your DeepSeek API key from platform.deepseek.com.
3. Add the custom endpoint in `config.json`.
4. Test full-codebase refactoring and automatic test generation.
      ''',
      categorySlug: 'ai',
      categoryName: 'AI & AI Tools',
      subcategory: 'Coding Copilots',
      tags: ['deepseek', 'coding', 'developer-tools'],
      author: authors[0],
      publishedAt: DateTime(2026, 9, 15, 10, 0),
      updatedAt: DateTime(2026, 9, 15, 10, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1555066931-4365d14bab8c?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 6,
      isFeatured: false,
      isTrending: true,
      isPopular: false,
      viewCount: 22100,
      keyTakeaways: [
        'DeepSeek costs approximately ₹12 per million tokens compared to ₹250+ for US closed models.',
        'Supports standard OpenAI compatible API specifications.',
        'Compatible with Continue, Roo Code, and Cline VS Code extensions.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'setup-vscode', title: 'Connecting in VS Code via Continue.dev'),
      ],
    ),

    // 10: Cyber Safety Chakshu
    ArticleModel(
      id: 'art-10',
      slug: 'chakshu-portal-how-to-report-spam-calls-and-block-fraudsters',
      title: 'How to Use Chakshu Portal to Report WhatsApp Spam, Loan Scams & Phishing Calls',
      excerpt:
          'The Department of Telecommunications (DoT) Sanchar Saathi Chakshu platform has already disconnected 1.8 crore fraudulent mobile numbers. Here is how to report scam numbers.',
      content: '''
Unsolicited calls offering fake work-from-home YouTube liking jobs, pre-approved instant loans, and courier customs fees are a daily menace for Indian mobile subscribers. Chakshu allows citizens to report suspected fraud communications before becoming victims.

### Steps to Submit Evidence on Chakshu
1. Visit `sancharsaathi.gov.in` and tap **Chakshu**.
2. Select medium of fraud: SMS, WhatsApp call, regular voice call, or RCS message.
3. Attach screenshots showing the sender number and timestamp.
4. Verify with your mobile number via OTP.
5. DoT AI bots cross-correlate reports to initiate automatic telecom blacklisting.
      ''',
      categorySlug: 'cyber-safety',
      categoryName: 'Cyber Safety',
      subcategory: 'Reporting Portals',
      tags: ['chakshu', 'cyber-safety', 'telecom'],
      author: authors[1],
      publishedAt: DateTime(2026, 9, 12, 11, 20),
      updatedAt: DateTime(2026, 9, 12, 11, 20),
      featuredImage:
          'https://images.unsplash.com/photo-1510511459019-5dda7724fd87?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 4,
      isFeatured: false,
      isTrending: false,
      isPopular: true,
      viewCount: 18400,
      keyTakeaways: [
        'You can report suspicious communications even if you did not lose money.',
        'DoT initiates immediate device-level IMEI barring for verified spam rings.',
        'Takes less than 3 minutes to submit via Sanchar Saathi.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'chakshu-steps', title: 'Steps to Submit Evidence on Chakshu'),
      ],
    ),

    // 11: How-To IRCTC Tatkal
    ArticleModel(
      id: 'art-11',
      slug: 'irctc-tatkal-booking-hacks-confirmed-tickets-festival-season',
      title: 'Confirmed IRCTC Tatkal Ticket Booking Hacks for Diwali & Chhath Puja Travel',
      excerpt:
          'Tatkal slots disappear in 30 seconds. Learn how Master Passenger Lists, IRCTC iPay payment gateways, and autofill scripts dramatically boost your confirmation odds.',
      content: '''
Booking Tatkal train tickets on IRCTC during peak festive migration is notoriously competitive. With millions hitting IRCTC servers at 10:00 AM (AC) and 11:00 AM (Sleeper), saving 10 seconds makes the difference between a confirmed berth and Waitlist 120.

### The 4 Crucial Preparations
1. **Master Passenger List**: Pre-save passenger names, ages, and berth preferences in your IRCTC profile 24 hours prior. This eliminates manual typing.
2. **IRCTC iPay or UPI Auto-Debit**: Never choose net banking or external debit cards. IRCTC iPay holds dedicated server priority.
3. **Synchronized Time**: Ensure your device clock matches the official NTP standard time down to the exact millisecond.
4. **App vs Web**: The official IRCTC Rail Connect mobile app on 5G is typically faster than the web browser CAPTCHA reload.
      ''',
      categorySlug: 'how-to',
      categoryName: 'How-To Guides',
      subcategory: 'Govt Services',
      tags: ['irctc', 'travel-tech', 'how-to'],
      author: authors[3],
      publishedAt: DateTime(2026, 9, 10, 9, 15),
      updatedAt: DateTime(2026, 9, 10, 9, 15),
      featuredImage:
          'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 5,
      isFeatured: false,
      isTrending: true,
      isPopular: true,
      viewCount: 45200,
      keyTakeaways: [
        'Pre-configure the Master Passenger list to auto-populate passengers in 1 click.',
        'Use IRCTC iPay gateway with pre-authorized UPI for zero OTP latency.',
        'Log in precisely at 09:58 AM for AC and 10:58 AM for Sleeper classes.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'preparations', title: 'The 4 Crucial Preparations'),
      ],
    ),

    // 12: Smartphones Camera
    ArticleModel(
      id: 'art-12',
      slug: 'smartphone-cameras-in-diwali-lighting-best-low-light-performers',
      title: 'Smartphone Cameras Tested in Diwali Night Lighting: Best Low-Light Performers Under ₹35,000',
      excerpt:
          'From earthen diyas to sparkling fireworks, we tested highlight flare control and skin-tone preservation across Vivo V40, Pixel 8a, and Honor 200.',
      content: '''
Diwali lighting creates extreme dynamic range challenges: intense, point-source diya flames juxtaposed against deep shadow backgrounds. Budget sensors frequently blow out golden hues or smear skin details under aggressive noise reduction algorithms.

### Camera Shootout Summary
- **Vivo V40 with Zeiss Optics**: Outstanding natural skin tones and dedicated Aura Light ring for family portraits.
- **Google Pixel 8a**: Incomparable computational HDR tone mapping and Night Sight balance.
- **Honor 200 Studio Portraits**: Studio lighting simulation powered by Studio Harcourt AI presets.
      ''',
      categorySlug: 'smartphones',
      categoryName: 'Smartphones',
      subcategory: 'Mid-range (₹15K-₹30K)',
      tags: ['camera-test', 'smartphones', 'diwali'],
      author: authors[2],
      publishedAt: DateTime(2026, 9, 8, 14, 0),
      updatedAt: DateTime(2026, 9, 8, 14, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 6,
      isFeatured: false,
      isTrending: false,
      isPopular: false,
      viewCount: 14800,
      keyTakeaways: [
        'Optical Image Stabilization (OIS) is essential for shutter speeds slower than 1/15s.',
        'Zeiss T* coating significantly cuts down glare streaks from street lamps and fairy lights.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'shootout', title: 'Camera Shootout Summary'),
      ],
    ),

    // 13: Apps UPI Circle
    ArticleModel(
      id: 'art-13',
      slug: 'upi-circle-delegated-payments-how-to-set-up-for-parents-and-children',
      title: 'UPI Circle Delegated Payments: How to Set Up Secondary Wallet Limits for Parents and Kids',
      excerpt:
          'NPCI’s new UPI Circle feature lets you delegate payment authorization to family members without sharing your bank account or debit card details. Step-by-step setup.',
      content: '''
UPI Circle is one of the most practical financial innovations for Indian households. Elderly parents or college-going children who may not have independent bank accounts or who hesitate to handle digital payments can now make merchant transactions backed by a primary family member’s account.

### Delegation Models Available
1. **Full Delegation**: The secondary user can initiate and complete payments up to a monthly cap (e.g. ₹5,000 or ₹15,000) with their own phone’s biometric lock.
2. **Partial Delegation**: The secondary user initiates the purchase at a shop counter, but the primary account holder approves the transaction on their own phone with 1-tap notification.
      ''',
      categorySlug: 'apps',
      categoryName: 'Apps',
      subcategory: 'Fintech & UPI',
      tags: ['upi', 'family-finance', 'apps'],
      author: authors[1],
      publishedAt: DateTime(2026, 9, 5, 11, 30),
      updatedAt: DateTime(2026, 9, 5, 11, 30),
      featuredImage:
          'https://images.unsplash.com/photo-1563013544-824ae1b704d3?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 5,
      isFeatured: false,
      isTrending: true,
      isPopular: false,
      viewCount: 21300,
      keyTakeaways: [
        'Set custom monthly and per-transaction spending limits for secondary users.',
        'Secondary user never needs to know the primary user UPI PIN.',
        'Instant revoke capability through Google Pay, PhonePe, or BHIM.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'models', title: 'Delegation Models Available'),
      ],
    ),

    // 14: Tech Updates Semiconductor
    ArticleModel(
      id: 'art-14',
      slug: 'india-semiconductor-mission-dholera-and-sanand-fab-status-report',
      title: 'India Semiconductor Mission: Ground Reality at Tata & Micron Fabs in Dholera and Sanand',
      excerpt:
          'With over \$15 Billion invested under the India Semiconductor Mission (ISM), we examine construction progress, cleanroom installations, and when first Made-in-India chips hit market.',
      content: '''
The India Semiconductor Mission (ISM) is transitioning from government MOUs to physical fabrication cleanrooms. In Gujarat’s Dholera SIR and Sanand, as well as Assam’s Morigaon, heavy construction machinery operates around the clock.

### Project Breakdown
- **Tata-PSMC Dholera Fab**: Targeting 28nm, 40nm, and 91nm mature node wafers for automotive, power management, and IoT chips.
- **Micron Sanand ATMP Facility**: Advanced packaging of DRAM and NAND flash memory chips for global export.
- **Tata Morigaon OSAT**: Semiconductor packaging focused on consumer electronics and electric vehicle power modules.
      ''',
      categorySlug: 'tech-news',
      categoryName: 'Tech Updates',
      subcategory: 'Semiconductors',
      tags: ['semiconductors', 'make-in-india', 'tech-policy'],
      author: authors[0],
      publishedAt: DateTime(2026, 9, 3, 16, 0),
      updatedAt: DateTime(2026, 9, 3, 16, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 7,
      isFeatured: false,
      isTrending: false,
      isPopular: false,
      viewCount: 17200,
      keyTakeaways: [
        'First commercial packaged chip modules from Sanand anticipated in early 2027.',
        'Focus on mature nodes (28nm-91nm) matches 70% of Indian industrial demand.',
        'Over 20 universities now offer specialized VLSI design and microelectronics degrees.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'breakdown', title: 'Project Breakdown'),
      ],
    ),

    // 15: Comparisons Laptops
    ArticleModel(
      id: 'art-15',
      slug: 'snapdragon-x-elite-vs-intel-core-ultra-india-battery-test',
      title: 'Snapdragon X Elite vs Intel Core Ultra: Which Windows Copilot+ Laptop Survives Indian Power Cuts?',
      excerpt:
          'ARM-powered Windows laptops have arrived in India. We tested real battery endurance under Indian conditions without AC charging for an entire workday.',
      content: '''
With frequent power cuts in several Indian residential zones and long university lecture days, battery life is paramount. Qualcomm’s ARM-based Snapdragon X Elite has disrupted the long-standing Intel/AMD x86 monopoly.

### The 10-Hour Unplugged Test
In our standardized workload comprising 20 Chrome tabs, Slack, YouTube 1080p stream, and Google Docs:
- **Snapdragon X Elite (Asus Vivobook S 15)**: Lasted an astonishing 14 hours and 22 minutes with cool lap temperatures.
- **Intel Core Ultra 7 (Lenovo Yoga Slim 7i)**: Lasted 9 hours and 40 minutes, with noticeable fan spin-up during video calls.
      ''',
      categorySlug: 'comparisons',
      categoryName: 'Comparisons',
      subcategory: 'Phone Battles',
      tags: ['laptops', 'qualcomm', 'intel', 'comparisons'],
      author: authors[2],
      publishedAt: DateTime(2026, 9, 1, 10, 0),
      updatedAt: DateTime(2026, 9, 1, 10, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 6,
      isFeatured: false,
      isTrending: false,
      isPopular: true,
      viewCount: 23900,
      keyTakeaways: [
        'Qualcomm ARM laptops deliver genuine all-day battery life on Windows 11.',
        'Check app compatibility: most Indian banking tokens and niche emulators still run smoother on Intel x86.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'test', title: 'The 10-Hour Unplugged Test'),
      ],
    ),

    // 16: Buying Guides Smart TVs
    ArticleModel(
      id: 'art-16',
      slug: 'best-55-inch-4k-smart-tvs-under-40000-in-india',
      title: 'Best 55-inch 4K Smart TVs Under ₹40,000 in India: QLED, Dolby Vision & IPL Viewing Tested',
      excerpt:
          'Want stadium-like immersion for cricket matches without breaking the bank? We tested Xiaomi, TCL, Hisense, and Acer for color accuracy and peak brightness.',
      content: '''
Watching live sports in brightly lit Indian living rooms requires high peak brightness and wide viewing angles. At the ₹35,000 to ₹40,000 price point, Quantum Dot (QLED) panels have become accessible.

### Recommended Models
1. **TCL 55C655 QLED**: 450 nits peak brightness, Google TV UI, and dedicated ONKYO 2.1 subwoofers.
2. **Hisense 55E7K Pro**: Native 144Hz refresh rate with AMD FreeSync Premium for console gaming.
3. **Xiaomi X Pro 55**: Superb PatchWall interface with IPL cricket score tickers and Dolby Atmos sound.
      ''',
      categorySlug: 'buying-guides',
      categoryName: 'Buying Guides',
      subcategory: 'Smart TVs',
      tags: ['smart-tvs', 'buying-guide', 'home-entertainment'],
      author: authors[2],
      publishedAt: DateTime(2026, 8, 29, 13, 0),
      updatedAt: DateTime(2026, 8, 29, 13, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1593784991095-a205069470b6?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 5,
      isFeatured: false,
      isTrending: false,
      isPopular: false,
      viewCount: 13100,
      keyTakeaways: [
        'Opt for QLED panels with minimum 400 nits brightness for daylight viewing.',
        'Verify MEMC motion estimation to avoid ball jitter during fast-paced cricket overs.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'recommended', title: 'Recommended Models'),
      ],
    ),

    // 17: How-To Aadhaar Lock
    ArticleModel(
      id: 'art-17',
      slug: 'how-to-lock-aadhaar-biometrics-on-m-aadhaar-app-prevent-aeps-fraud',
      title: 'How to Lock Aadhaar Biometrics on mAadhaar to Prevent AePS Bank Account Drainage',
      excerpt:
          'Scammers use cloned fingerprints from registry documents to drain bank accounts via Aadhaar Enabled Payment System (AePS). Lock your biometrics in 2 minutes.',
      content: '''
AePS allows rural and urban banking customers to withdraw cash simply using their Aadhaar number and fingerprint scan at point-of-sale micro-ATMs. However, leaking land deed or registry fingerprints has led to unauthorized AePS withdrawals.

### Step-by-Step Biometric Lock via mAadhaar
1. Download the official **mAadhaar** app from Google Play or Apple App Store.
2. Register with the phone number linked to your Aadhaar and input the OTP.
3. Create a 4-digit profile security PIN.
4. On your Aadhaar dashboard, tap **Biometrics Lock**.
5. Confirm the lock. Your fingerprints and iris scans are immediately disabled from authentication.
6. Whenever you visit a bank or SIM shop, unlock temporarily with 1 tap (it auto-relocks after 10 minutes).
      ''',
      categorySlug: 'how-to',
      categoryName: 'How-To Guides',
      subcategory: 'Govt Services',
      tags: ['aadhaar', 'cyber-safety', 'how-to'],
      author: authors[1],
      publishedAt: DateTime(2026, 8, 26, 17, 0),
      updatedAt: DateTime(2026, 8, 26, 17, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1563986768494-4dee2763ff3f?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 4,
      isFeatured: false,
      isTrending: true,
      isPopular: true,
      viewCount: 36700,
      keyTakeaways: [
        'Biometric lock completely prevents unauthorized AePS fingerprint withdrawals.',
        'OTP-based Aadhaar authentications continue to work normally.',
        'Temporary unlocking lasts 10 minutes and automatically re-secures itself.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'biometric-lock', title: 'Step-by-Step Biometric Lock via mAadhaar'),
      ],
    ),

    // 18: Apps WhatsApp Companion
    ArticleModel(
      id: 'art-18',
      slug: 'whatsapp-companion-mode-run-one-account-on-multiple-phones',
      title: 'WhatsApp Companion Mode: How to Use the Same Number on Two Phones Without Disconnecting',
      excerpt:
          'No more WhatsApp Web workarounds. WhatsApp officially supports linking up to four secondary mobile phones while keeping full end-to-end encryption.',
      content: '''
Many Indian professionals carry two mobile phones: one for office calls and another for personal use. In the past, keeping your primary WhatsApp number active on both required third-party clone apps that risked permanent bans.

### Linking Secondary Android or iPhone
1. On your secondary phone, install fresh WhatsApp.
2. At the phone number entry screen, tap the three dots in the top right corner.
3. Select **Link as companion device**. A QR code will display.
4. On your primary phone, open WhatsApp > Settings > **Linked Devices** > **Link a Device**.
5. Scan the QR code. All chat histories and media sync securely.
      ''',
      categorySlug: 'apps',
      categoryName: 'Apps',
      subcategory: 'Govt & Citizen Utility',
      tags: ['whatsapp', 'apps', 'productivity'],
      author: authors[3],
      publishedAt: DateTime(2026, 8, 23, 10, 0),
      updatedAt: DateTime(2026, 8, 23, 10, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1577563908411-5077b6dc7624?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 4,
      isFeatured: false,
      isTrending: false,
      isPopular: false,
      viewCount: 18900,
      keyTakeaways: [
        'Works across Android-to-iPhone and iPhone-to-Android cross-platforms.',
        'Primary phone does not need to stay connected to the internet for secondary to function.',
        'Inactive companion sessions automatically expire after 14 days of non-use.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'linking', title: 'Linking Secondary Android or iPhone'),
      ],
    ),

    // 19: AI Indian Startups
    ArticleModel(
      id: 'art-19',
      slug: 'krutrim-vs-sarvam-vs-hanooman-indic-ai-showdown',
      title: 'Krutrim vs Sarvam vs Hanooman: Which Indian Generative AI Model Wins the Battle for Bharat?',
      excerpt:
          'We tested Sanskrit grammar, Hindi poetry, and vernacular medical translation across India’s leading domestic AI models. Here is our comprehensive evaluation.',
      content: '''
India’s sovereign AI ambitions have gathered tremendous momentum, with Ola’s Krutrim, Sarvam AI, and the SML BharatGPT initiative (Hanooman) releasing native foundational models trained on cultural nuances and regional linguistics.

### Benchmark Evaluation Highlights
- **Sarvam AI**: Decisive leader in speech synthesis, voice recognition, and real-time dialect comprehension.
- **Krutrim**: Strong integration into consumer cloud and local maps navigation context.
- **Hanooman**: Best in formal classical languages like Sanskrit, Marathi, and Tamil with deep cultural contextual awareness.
      ''',
      categorySlug: 'ai',
      categoryName: 'AI & AI Tools',
      subcategory: 'Indic LLMs',
      tags: ['sarvam-ai', 'krutrim', 'indic-llm'],
      author: authors[0],
      publishedAt: DateTime(2026, 8, 20, 15, 30),
      updatedAt: DateTime(2026, 8, 20, 15, 30),
      featuredImage:
          'https://images.unsplash.com/photo-1620712943543-bcc4688e7485?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 6,
      isFeatured: false,
      isTrending: true,
      isPopular: true,
      viewCount: 27400,
      keyTakeaways: [
        'Sarvam takes the gold medal for low-latency Indic voice bots.',
        'Sovereign data hosting safeguards sensitive citizen records within Indian borders.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'benchmarks', title: 'Benchmark Evaluation Highlights'),
      ],
    ),

    // 20: Cyber Safety WhatsApp Impersonation
    ArticleModel(
      id: 'art-20',
      slug: 'whatsapp-family-impersonation-scam-emergency-cash-frauds',
      title: 'WhatsApp "Hi Dad, I Need Money" Scams Surge in India: Prevention Rules for Families',
      excerpt:
          'Fraudsters clone profile pictures and pretend to be children studying in Delhi, Pune, or abroad claiming their phone broke. Share these 3 verification rules with your family.',
      content: '''
One of the most emotionally distressing scams targeting Indian parents involves WhatsApp messages originating from unknown international or VoIP numbers (+92, +84, +44, etc.). Scammers set the child’s WhatsApp display photo and send frantic messages claiming their phone fell in water and they desperately need ₹20,000 to clear hostel or medical fees.

### The 3 Golden Family Rules
1. **Never send money to an unfamiliar UPI VPA** without speaking directly to the child on voice call.
2. **Establish a Secret Family Safe Word**: A private keyword known only to parents and siblings that an impostor could never guess.
3. **Call Roommates or College Warden**: If your child’s primary phone is unreachable, contact trusted friends or hostel authorities before panicking.
      ''',
      categorySlug: 'cyber-safety',
      categoryName: 'Cyber Safety',
      subcategory: 'Family Cyber Safety',
      tags: ['cyber-safety', 'scam-alert', 'family'],
      author: authors[1],
      publishedAt: DateTime(2026, 8, 18, 12, 10),
      updatedAt: DateTime(2026, 8, 18, 12, 10),
      featuredImage:
          'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 5,
      isFeatured: false,
      isTrending: false,
      isPopular: true,
      viewCount: 31900,
      keyTakeaways: [
        'Scammers scrape profile photos from public Facebook/Instagram accounts.',
        'Always confirm via normal phone call before approving emergency UPI transfers.',
        'Immediately report the WhatsApp account inside the app and through Chakshu.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'rules', title: 'The 3 Golden Family Rules'),
      ],
    ),

    // 21: Tech Updates DPDP
    ArticleModel(
      id: 'art-21',
      slug: 'digital-personal-data-protection-act-rules-what-changes-for-users',
      title: 'DPDP Act Rules: What Changes for Your Phone Apps, Cookies, and Personal Privacy',
      excerpt:
          'India’s landmark Data Protection rules impose penalties up to ₹250 Crore for data leaks. Here is what you should expect from app permissions and consent managers.',
      content: '''
The Digital Personal Data Protection (DPDP) Act represents India’s strongest legal safeguard against reckless data harvesting. With final implementation rules coming into enforcement, Indian tech platforms and multinational apps must fundamentally revamp privacy consents.

### Key Rights Empowering Citizens
- **Right to Erasure**: You can request complete deletion of past profiles from shopping and ride-hailing platforms with a single click.
- **Strict Parental Consent for Minors**: Apps catering to users under 18 cannot conduct behavioral targeted advertising.
- **Mandatory Breach Notifications**: Platforms must notify both the Data Protection Board and affected users within hours of any credential breach.
      ''',
      categorySlug: 'tech-news',
      categoryName: 'Tech Updates',
      subcategory: 'Policy & DPDP',
      tags: ['dpdp', 'privacy', 'tech-policy'],
      author: authors[1],
      publishedAt: DateTime(2026, 8, 15, 14, 0),
      updatedAt: DateTime(2026, 8, 15, 14, 0),
      featuredImage:
          'https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&w=1200&q=80',
      readingTimeMinutes: 6,
      isFeatured: false,
      isTrending: false,
      isPopular: false,
      viewCount: 12400,
      keyTakeaways: [
        'Apps can no longer force blanket contacts and gallery permissions for non-essential features.',
        'Violations carry fines up to ₹250 Crore per incident.',
      ],
      faqs: [],
      toc: [
        const ArticleTocItem(id: 'rights', title: 'Key Rights Empowering Citizens'),
      ],
    ),
  ];
}
