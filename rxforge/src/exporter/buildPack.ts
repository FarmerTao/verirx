import { DatabaseSync } from "node:sqlite";
import fs from "node:fs";
import path from "node:path";
import { DEFAULT_IOS_PACK_DB, SCHEMA_PATH, type StagingDatabase } from "../db.js";

/**
 * Compiles a clean, compact, read-only SQLite content bundle for the iOS app.
 * Strips unapproved/rejected drafts and Blind Critic internal logs.
 */
export function exportApprovedPackToIos(
  staging: StagingDatabase,
  outputPath: string = DEFAULT_IOS_PACK_DB
): { drugs: number; flashcards: number; questions: number; bytes: number } {
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  if (fs.existsSync(outputPath)) {
    fs.unlinkSync(outputPath);
  }

  const outDb = new DatabaseSync(outputPath);
  const schemaSql = fs.readFileSync(SCHEMA_PATH, "utf-8");
  outDb.exec(schemaSql);

  const metaInsert = outDb.prepare("INSERT INTO pack_meta (key, value) VALUES (?, ?)");
  metaInsert.run("pack_version", "2026.11.1");
  metaInsert.run("built_at", new Date().toISOString());
  metaInsert.run("generator", "RxForge Offline Factory");

  const exams = staging.db.prepare("SELECT * FROM exams").all() as Record<string, unknown>[];
  const examStmt = outDb.prepare(`
    INSERT INTO exams (exam_code, display_name, subtitle, domains_json, trademark_disclaimer, is_active)
    VALUES (?, ?, ?, ?, ?, ?)
  `);
  for (const e of exams) {
    examStmt.run(
      String(e.exam_code),
      String(e.display_name),
      String(e.subtitle),
      String(e.domains_json),
      String(e.trademark_disclaimer),
      Number(e.is_active)
    );
  }

  const drugs = staging.db.prepare("SELECT * FROM drugs").all() as Record<string, unknown>[];
  const drugStmt = outDb.prepare(`
    INSERT INTO drugs (
      id, generic_name, brand_names_json, tall_man_name, drug_class,
      dea_schedule, rems_program, indications_summary, mechanism_summary,
      boxed_warning, key_adverse_effects, key_interactions, storage_handling,
      high_alert_flag, fda_spl_set_id, fda_application_number, dailymed_url,
      raw_label_excerpt, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  for (const d of drugs) {
    drugStmt.run(
      String(d.id),
      String(d.generic_name),
      String(d.brand_names_json),
      d.tall_man_name ? String(d.tall_man_name) : null,
      String(d.drug_class),
      String(d.dea_schedule),
      d.rems_program ? String(d.rems_program) : null,
      String(d.indications_summary),
      String(d.mechanism_summary),
      d.boxed_warning ? String(d.boxed_warning) : null,
      String(d.key_adverse_effects),
      String(d.key_interactions),
      String(d.storage_handling),
      Number(d.high_alert_flag),
      String(d.fda_spl_set_id),
      d.fda_application_number ? String(d.fda_application_number) : null,
      String(d.dailymed_url),
      String(d.raw_label_excerpt),
      String(d.updated_at)
    );
  }

  const flashcards = staging.db.prepare("SELECT * FROM flashcards").all() as Record<string, unknown>[];
  const fcStmt = outDb.prepare(`
    INSERT INTO flashcards (
      id, drug_id, exam_code, domain_code, card_type,
      front_prompt, back_answer, back_detail,
      citation_label, citation_url, is_free_tier
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `);
  for (const fc of flashcards) {
    fcStmt.run(
      String(fc.id),
      fc.drug_id ? String(fc.drug_id) : null,
      String(fc.exam_code),
      String(fc.domain_code),
      String(fc.card_type),
      String(fc.front_prompt),
      String(fc.back_answer),
      String(fc.back_detail),
      String(fc.citation_label),
      String(fc.citation_url),
      Number(fc.is_free_tier)
    );
  }

  const questions = staging.db
    .prepare("SELECT * FROM questions WHERE review_status = 'approved'")
    .all() as Record<string, unknown>[];
  const qStmt = outDb.prepare(`
    INSERT INTO questions (
      id, drug_id, exam_code, domain_code, question_type, difficulty,
      stem, choices_json, correct_choice_id, explanation,
      fda_spl_set_id, citation_quote, citation_url,
      generator_source, blind_critic_json, review_status, is_free_tier, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 'approved', ?, ?)
  `);
  for (const q of questions) {
    qStmt.run(
      String(q.id),
      q.drug_id ? String(q.drug_id) : null,
      String(q.exam_code),
      String(q.domain_code),
      String(q.question_type),
      Number(q.difficulty),
      String(q.stem),
      String(q.choices_json),
      String(q.correct_choice_id),
      String(q.explanation),
      q.fda_spl_set_id ? String(q.fda_spl_set_id) : null,
      String(q.citation_quote),
      String(q.citation_url),
      String(q.generator_source),
      Number(q.is_free_tier),
      String(q.created_at)
    );
  }

  outDb.exec("VACUUM;");
  outDb.close();

  const bytes = fs.statSync(outputPath).size;
  return {
    drugs: drugs.length,
    flashcards: flashcards.length,
    questions: questions.length,
    bytes
  };
}
