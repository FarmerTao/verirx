-- Canonical Schema for VeriRx Content Packs & RxForge Staging DB
-- Compatible with Node 22 (node:sqlite) and iOS Native SQLite3

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS pack_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS exams (
    exam_code TEXT PRIMARY KEY,          -- 'PTCE', 'NCLEX_PHARM', 'NAPLEX'
    display_name TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    domains_json TEXT NOT NULL,          -- JSON array of {code, name, weight_pct}
    trademark_disclaimer TEXT NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS drugs (
    id TEXT PRIMARY KEY,                 -- slug e.g. 'atorvastatin'
    generic_name TEXT NOT NULL,
    brand_names_json TEXT NOT NULL,      -- JSON string array e.g. '["Lipitor"]'
    tall_man_name TEXT,                  -- e.g. 'hydrALAZINE' or NULL
    drug_class TEXT NOT NULL,
    dea_schedule TEXT NOT NULL DEFAULT 'Rx', -- 'Rx', 'OTC', 'C-II', 'C-III', 'C-IV', 'C-V'
    rems_program TEXT,                   -- e.g. 'iPLEDGE' or NULL
    indications_summary TEXT NOT NULL,
    mechanism_summary TEXT NOT NULL,
    boxed_warning TEXT,                  -- Verbatim or condensed FDA Boxed Warning if present
    key_adverse_effects TEXT NOT NULL,
    key_interactions TEXT NOT NULL,
    storage_handling TEXT NOT NULL,
    high_alert_flag INTEGER NOT NULL DEFAULT 0, -- 1 if ISMP/FDA High-Alert medication
    fda_spl_set_id TEXT NOT NULL,
    fda_application_number TEXT,
    dailymed_url TEXT NOT NULL,
    raw_label_excerpt TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS flashcards (
    id TEXT PRIMARY KEY,
    drug_id TEXT REFERENCES drugs(id) ON DELETE CASCADE,
    exam_code TEXT NOT NULL REFERENCES exams(exam_code),
    domain_code TEXT NOT NULL,           -- 'MEDICATIONS', 'PATIENT_SAFETY', 'FEDERAL_REQUIREMENTS'
    card_type TEXT NOT NULL,             -- 'brand_generic', 'class_moa', 'safety_warning', 'law_schedule'
    front_prompt TEXT NOT NULL,
    back_answer TEXT NOT NULL,
    back_detail TEXT NOT NULL,
    citation_label TEXT NOT NULL,
    citation_url TEXT NOT NULL,
    is_free_tier INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS questions (
    id TEXT PRIMARY KEY,
    drug_id TEXT REFERENCES drugs(id) ON DELETE SET NULL,
    exam_code TEXT NOT NULL REFERENCES exams(exam_code),
    domain_code TEXT NOT NULL,           -- 'MEDICATIONS', 'PATIENT_SAFETY', 'ORDER_ENTRY_MATH', 'FEDERAL_REQUIREMENTS'
    question_type TEXT NOT NULL,         -- 'vignette_mcq', 'math_mcq'
    difficulty INTEGER NOT NULL CHECK (difficulty BETWEEN 1 AND 5),
    stem TEXT NOT NULL,
    choices_json TEXT NOT NULL,          -- JSON array of {id: 'A'|'B'|'C'|'D', text: string, rationale: string}
    correct_choice_id TEXT NOT NULL,
    explanation TEXT NOT NULL,
    fda_spl_set_id TEXT,
    citation_quote TEXT NOT NULL,        -- Exact FDA SPL excerpt or deterministic math formula
    citation_url TEXT NOT NULL,
    generator_source TEXT NOT NULL,      -- 'deterministic_math' | 'rxforge_pi_agent' | 'curated_fda_seed'
    blind_critic_json TEXT,              -- JSON audit log from Blind Critic Agent
    review_status TEXT NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending', 'approved', 'rejected')),
    is_free_tier INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_flashcards_exam_domain ON flashcards(exam_code, domain_code);
CREATE INDEX IF NOT EXISTS idx_questions_exam_domain ON questions(exam_code, domain_code, review_status);
CREATE INDEX IF NOT EXISTS idx_questions_difficulty ON questions(exam_code, difficulty);
