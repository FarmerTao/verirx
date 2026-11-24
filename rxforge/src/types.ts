export type ExamCode = "PTCE" | "NCLEX_PHARM" | "NAPLEX";

export type DomainCode =
  | "MEDICATIONS"
  | "PATIENT_SAFETY"
  | "ORDER_ENTRY_MATH"
  | "FEDERAL_REQUIREMENTS";

export interface ChoiceOption {
  id: "A" | "B" | "C" | "D";
  text: string;
  rationale: string;
}

export interface DrugRecord {
  id: string;
  generic_name: string;
  brand_names: string[];
  tall_man_name: string | null;
  drug_class: string;
  dea_schedule: "Rx" | "OTC" | "C-II" | "C-III" | "C-IV" | "C-V";
  rems_program: string | null;
  indications_summary: string;
  mechanism_summary: string;
  boxed_warning: string | null;
  key_adverse_effects: string;
  key_interactions: string;
  storage_handling: string;
  high_alert_flag: number;
  fda_spl_set_id: string;
  fda_application_number: string | null;
  dailymed_url: string;
  raw_label_excerpt: string;
  updated_at: string;
}

export interface FlashcardRecord {
  id: string;
  drug_id: string | null;
  exam_code: ExamCode;
  domain_code: DomainCode;
  card_type: "brand_generic" | "class_moa" | "safety_warning" | "law_schedule";
  front_prompt: string;
  back_answer: string;
  back_detail: string;
  citation_label: string;
  citation_url: string;
  is_free_tier: number;
}

export interface QuestionRecord {
  id: string;
  drug_id: string | null;
  exam_code: ExamCode;
  domain_code: DomainCode;
  question_type: "vignette_mcq" | "math_mcq";
  difficulty: 1 | 2 | 3 | 4 | 5;
  stem: string;
  choices: ChoiceOption[];
  correct_choice_id: "A" | "B" | "C" | "D";
  explanation: string;
  fda_spl_set_id: string | null;
  citation_quote: string;
  citation_url: string;
  generator_source: "deterministic_math" | "rxforge_pi_agent" | "curated_fda_seed";
  blind_critic_json: string | null;
  review_status: "pending" | "approved" | "rejected";
  is_free_tier: number;
  created_at: string;
}
