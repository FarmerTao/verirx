-- Canonical Schema for VeriRx Content Packs & RxForge Staging DB
-- Supports Duolingo-style Skill Path (Drug Stems, Sig Word-Bank, Match Pairs & Boss MCQs)
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

CREATE TABLE IF NOT EXISTS skill_units (
    id TEXT PRIMARY KEY,                 -- e.g. 'unit-1-stems'
    exam_code TEXT NOT NULL REFERENCES exams(exam_code),
    unit_order INTEGER NOT NULL,
    title TEXT NOT NULL,
    subtitle TEXT NOT NULL,
    theme_color TEXT NOT NULL,           -- 'teal', 'indigo', 'orange', 'rose', 'purple', 'emerald'
    icon_name TEXT NOT NULL,             -- SF Symbol name for iOS SwiftUI
    focus_type TEXT NOT NULL,            -- 'stems' | 'sig_codes' | 'drugs_cardio' | 'high_alert' | 'law_rems' | 'math'
    drug_ids_json TEXT NOT NULL          -- JSON array of drug slugs emphasized in this unit
);

CREATE TABLE IF NOT EXISTS drug_stems (
    id TEXT PRIMARY KEY,                 -- e.g. 'stem-statin'
    stem TEXT NOT NULL,                  -- e.g. '-statin'
    position TEXT NOT NULL,              -- 'suffix' | 'prefix' | 'infix'
    drug_class TEXT NOT NULL,
    clinical_pearl TEXT NOT NULL,
    example_drugs_json TEXT NOT NULL,    -- JSON array e.g. '["Atorvastatin","Rosuvastatin"]'
    trap_note TEXT NOT NULL              -- Common look-alike stem trap
);

CREATE TABLE IF NOT EXISTS sig_drills (
    id TEXT PRIMARY KEY,                 -- e.g. 'sig-ou-bid'
    rx_shorthand TEXT NOT NULL,          -- e.g. 'ii gtts OU BID'
    correct_tokens_json TEXT NOT NULL,   -- Ordered JSON array of phrase chips
    distractor_tokens_json TEXT NOT NULL,-- Extra trap chips for Duolingo word bank
    clinical_tip TEXT NOT NULL
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
    high_alert_flag INTEGER NOT NULL DEFAULT 0,
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
    domain_code TEXT NOT NULL,
    card_type TEXT NOT NULL,
    front_prompt TEXT NOT NULL,
    back_answer TEXT NOT NULL,
    back_detail TEXT NOT NULL,
    citation_label TEXT NOT NULL,
    citation_url TEXT NOT NULL,
    is_free_tier INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS questions (
    id TEXT PRIMARY KEY,
    drug_id TEXT REFERENCES drugs(id) ON DELETE SET NULL,
    exam_code TEXT NOT NULL REFERENCES exams(exam_code),
    domain_code TEXT NOT NULL,
    question_type TEXT NOT NULL,         -- 'vignette_mcq', 'math_mcq'
    difficulty INTEGER NOT NULL CHECK (difficulty BETWEEN 1 AND 5),
    stem TEXT NOT NULL,
    choices_json TEXT NOT NULL,
    correct_choice_id TEXT NOT NULL,
    explanation TEXT NOT NULL,
    fda_spl_set_id TEXT,
    citation_quote TEXT NOT NULL,
    citation_url TEXT NOT NULL,
    generator_source TEXT NOT NULL,
    blind_critic_json TEXT,
    review_status TEXT NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending', 'approved', 'rejected')),
    is_free_tier INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_skill_units_exam ON skill_units(exam_code, unit_order);
CREATE INDEX IF NOT EXISTS idx_flashcards_exam_domain ON flashcards(exam_code, domain_code);
CREATE INDEX IF NOT EXISTS idx_questions_exam_domain ON questions(exam_code, domain_code, review_status);
