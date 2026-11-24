import { DatabaseSync } from "node:sqlite";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { DrugRecord, FlashcardRecord, QuestionRecord } from "./types.js";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = path.resolve(__dirname, "../..");
export const SCHEMA_PATH = path.join(REPO_ROOT, "schema/schema.sql");
export const DEFAULT_STAGING_DB = path.join(REPO_ROOT, "rxforge/data/staging.sqlite");
export const DEFAULT_IOS_PACK_DB = path.join(
  REPO_ROOT,
  "ios/VeriRx/Resources/verirx_pack.sqlite"
);

export class StagingDatabase {
  public readonly db: DatabaseSync;

  constructor(dbPath: string = DEFAULT_STAGING_DB) {
    fs.mkdirSync(path.dirname(dbPath), { recursive: true });
    this.db = new DatabaseSync(dbPath);
    const schemaSql = fs.readFileSync(SCHEMA_PATH, "utf-8");
    this.db.exec(schemaSql);
    this.seedExamTracks();
  }

  private seedExamTracks(): void {
    const stmt = this.db.prepare(`
      INSERT INTO exams (exam_code, display_name, subtitle, domains_json, trademark_disclaimer, is_active)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(exam_code) DO UPDATE SET
        display_name = excluded.display_name,
        subtitle = excluded.subtitle,
        domains_json = excluded.domains_json,
        trademark_disclaimer = excluded.trademark_disclaimer,
        is_active = excluded.is_active
    `);

    stmt.run(
      "PTCE",
      "PTCE® Pharmacy Tech",
      "Top 200 Drugs, Patient Safety, Pharmacy Math & Federal Law",
      JSON.stringify([
        { code: "MEDICATIONS", name: "Medications", weight_pct: 40.0 },
        { code: "PATIENT_SAFETY", name: "Patient Safety & Quality Assurance", weight_pct: 26.25 },
        { code: "ORDER_ENTRY_MATH", name: "Order Entry, Processing & Math", weight_pct: 21.25 },
        { code: "FEDERAL_REQUIREMENTS", name: "Federal Requirements", weight_pct: 12.5 }
      ]),
      "PTCB®, PTCE®, and Pharmacy Technician Certification Exam® are registered trademarks of the Pharmacy Technician Certification Board® (PTCB®). VeriRx is an independent educational tool and is neither endorsed nor approved by PTCB®.",
      1
    );

    stmt.run(
      "NCLEX_PHARM",
      "NCLEX® Pharmacology",
      "High-Alert Nursing Medications, Safety Checks & Dosage Calculations",
      JSON.stringify([
        { code: "MEDICATIONS", name: "Pharmacological Therapies", weight_pct: 45.0 },
        { code: "PATIENT_SAFETY", name: "Adverse Effects & Nursing Monitoring", weight_pct: 35.0 },
        { code: "ORDER_ENTRY_MATH", name: "Parenteral & Dosage Calculations", weight_pct: 20.0 }
      ]),
      "NCLEX®, NCLEX-RN®, and NCLEX-PN® are registered trademarks of the National Council of State Boards of Nursing, Inc. (NCSBN®), which neither sponsors nor endorses this product.",
      0
    );

    stmt.run(
      "NAPLEX",
      "NAPLEX® Clinical Core",
      "Pharmacotherapy, Mechanisms, CYP450 Interactions & PK Calculations",
      JSON.stringify([
        { code: "MEDICATIONS", name: "Pharmacotherapy & Mechanisms", weight_pct: 50.0 },
        { code: "PATIENT_SAFETY", name: "Drug Interactions & Contraindications", weight_pct: 25.0 },
        { code: "ORDER_ENTRY_MATH", name: "Compounding & Pharmacokinetics", weight_pct: 25.0 }
      ]),
      "NAPLEX® is a registered trademark of the National Association of Boards of Pharmacy® (NABP®), which neither sponsors nor endorses this product.",
      0
    );
  }

  upsertDrug(drug: DrugRecord): void {
    const stmt = this.db.prepare(`
      INSERT INTO drugs (
        id, generic_name, brand_names_json, tall_man_name, drug_class,
        dea_schedule, rems_program, indications_summary, mechanism_summary,
        boxed_warning, key_adverse_effects, key_interactions, storage_handling,
        high_alert_flag, fda_spl_set_id, fda_application_number, dailymed_url,
        raw_label_excerpt, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        generic_name = excluded.generic_name,
        brand_names_json = excluded.brand_names_json,
        tall_man_name = excluded.tall_man_name,
        drug_class = excluded.drug_class,
        dea_schedule = excluded.dea_schedule,
        rems_program = excluded.rems_program,
        indications_summary = excluded.indications_summary,
        mechanism_summary = excluded.mechanism_summary,
        boxed_warning = excluded.boxed_warning,
        key_adverse_effects = excluded.key_adverse_effects,
        key_interactions = excluded.key_interactions,
        storage_handling = excluded.storage_handling,
        high_alert_flag = excluded.high_alert_flag,
        fda_spl_set_id = excluded.fda_spl_set_id,
        fda_application_number = excluded.fda_application_number,
        dailymed_url = excluded.dailymed_url,
        raw_label_excerpt = excluded.raw_label_excerpt,
        updated_at = excluded.updated_at
    `);

    stmt.run(
      drug.id,
      drug.generic_name,
      JSON.stringify(drug.brand_names),
      drug.tall_man_name,
      drug.drug_class,
      drug.dea_schedule,
      drug.rems_program,
      drug.indications_summary,
      drug.mechanism_summary,
      drug.boxed_warning,
      drug.key_adverse_effects,
      drug.key_interactions,
      drug.storage_handling,
      drug.high_alert_flag,
      drug.fda_spl_set_id,
      drug.fda_application_number,
      drug.dailymed_url,
      drug.raw_label_excerpt,
      drug.updated_at
    );
  }

  upsertFlashcard(card: FlashcardRecord): void {
    const stmt = this.db.prepare(`
      INSERT INTO flashcards (
        id, drug_id, exam_code, domain_code, card_type,
        front_prompt, back_answer, back_detail,
        citation_label, citation_url, is_free_tier
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        front_prompt = excluded.front_prompt,
        back_answer = excluded.back_answer,
        back_detail = excluded.back_detail,
        citation_label = excluded.citation_label,
        citation_url = excluded.citation_url,
        is_free_tier = excluded.is_free_tier
    `);

    stmt.run(
      card.id,
      card.drug_id,
      card.exam_code,
      card.domain_code,
      card.card_type,
      card.front_prompt,
      card.back_answer,
      card.back_detail,
      card.citation_label,
      card.citation_url,
      card.is_free_tier
    );
  }

  upsertQuestion(q: QuestionRecord): void {
    const stmt = this.db.prepare(`
      INSERT INTO questions (
        id, drug_id, exam_code, domain_code, question_type, difficulty,
        stem, choices_json, correct_choice_id, explanation,
        fda_spl_set_id, citation_quote, citation_url,
        generator_source, blind_critic_json, review_status, is_free_tier, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        difficulty = excluded.difficulty,
        stem = excluded.stem,
        choices_json = excluded.choices_json,
        correct_choice_id = excluded.correct_choice_id,
        explanation = excluded.explanation,
        fda_spl_set_id = excluded.fda_spl_set_id,
        citation_quote = excluded.citation_quote,
        citation_url = excluded.citation_url,
        generator_source = excluded.generator_source,
        blind_critic_json = excluded.blind_critic_json,
        review_status = excluded.review_status,
        is_free_tier = excluded.is_free_tier
    `);

    stmt.run(
      q.id,
      q.drug_id,
      q.exam_code,
      q.domain_code,
      q.question_type,
      q.difficulty,
      q.stem,
      JSON.stringify(q.choices),
      q.correct_choice_id,
      q.explanation,
      q.fda_spl_set_id,
      q.citation_quote,
      q.citation_url,
      q.generator_source,
      q.blind_critic_json,
      q.review_status,
      q.is_free_tier,
      q.created_at
    );
  }

  listDrugs(): DrugRecord[] {
    const rows = this.db.prepare("SELECT * FROM drugs ORDER BY generic_name ASC").all() as Record<string, unknown>[];
    return rows.map((r) => ({
      id: String(r.id),
      generic_name: String(r.generic_name),
      brand_names: JSON.parse(String(r.brand_names_json)) as string[],
      tall_man_name: r.tall_man_name ? String(r.tall_man_name) : null,
      drug_class: String(r.drug_class),
      dea_schedule: String(r.dea_schedule) as DrugRecord["dea_schedule"],
      rems_program: r.rems_program ? String(r.rems_program) : null,
      indications_summary: String(r.indications_summary),
      mechanism_summary: String(r.mechanism_summary),
      boxed_warning: r.boxed_warning ? String(r.boxed_warning) : null,
      key_adverse_effects: String(r.key_adverse_effects),
      key_interactions: String(r.key_interactions),
      storage_handling: String(r.storage_handling),
      high_alert_flag: Number(r.high_alert_flag),
      fda_spl_set_id: String(r.fda_spl_set_id),
      fda_application_number: r.fda_application_number ? String(r.fda_application_number) : null,
      dailymed_url: String(r.dailymed_url),
      raw_label_excerpt: String(r.raw_label_excerpt),
      updated_at: String(r.updated_at)
    }));
  }

  getStats(): { drugs: number; flashcards: number; approvedQuestions: number; pendingQuestions: number } {
    const drugs = Number((this.db.prepare("SELECT COUNT(*) AS c FROM drugs").get() as { c: number }).c);
    const flashcards = Number((this.db.prepare("SELECT COUNT(*) AS c FROM flashcards").get() as { c: number }).c);
    const approvedQuestions = Number(
      (this.db.prepare("SELECT COUNT(*) AS c FROM questions WHERE review_status = 'approved'").get() as { c: number }).c
    );
    const pendingQuestions = Number(
      (this.db.prepare("SELECT COUNT(*) AS c FROM questions WHERE review_status = 'pending'").get() as { c: number }).c
    );
    return { drugs, flashcards, approvedQuestions, pendingQuestions };
  }

  close(): void {
    this.db.close();
  }
}
