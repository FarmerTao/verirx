import Foundation
import SQLite3

/// Zero-dependency native SQLite3 read-only reader for the bundled `verirx_pack.sqlite` database.
public final class ContentPackDatabase {
    private var db: OpaquePointer?

    public init(sqliteURL: URL? = Bundle.main.url(forResource: "verirx_pack", withExtension: "sqlite")) {
        guard let url = sqliteURL else {
            print("[VeriRx] Warning: verirx_pack.sqlite not found in app bundle.")
            return
        }
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        if sqlite3_open_v2(url.path, &db, flags, nil) != SQLITE_OK {
            print("[VeriRx] Failed to open SQLite pack at \(url.path)")
            db = nil
        }
    }

    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }

    public func loadExams() -> [ExamTrack] {
        guard let db = db else { return [] }
        let sql = "SELECT exam_code, display_name, subtitle, domains_json, trademark_disclaimer, is_active FROM exams ORDER BY is_active DESC, exam_code ASC;"
        var stmt: OpaquePointer?
        var results: [ExamTrack] = []

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let code = colString(stmt, 0)
                let name = colString(stmt, 1)
                let subtitle = colString(stmt, 2)
                let domainsJson = colString(stmt, 3)
                let disclaimer = colString(stmt, 4)
                let active = sqlite3_column_int(stmt, 5) == 1

                let domains = (try? JSONDecoder().decode([ExamDomainInfo].self, from: Data(domainsJson.utf8))) ?? []
                results.append(
                    ExamTrack(
                        examCode: code,
                        displayName: name,
                        subtitle: subtitle,
                        domains: domains,
                        trademarkDisclaimer: disclaimer,
                        isActive: active
                    )
                )
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    public func loadDrugs() -> [DrugItem] {
        guard let db = db else { return [] }
        let sql = """
        SELECT id, generic_name, brand_names_json, tall_man_name, drug_class,
               dea_schedule, rems_program, indications_summary, mechanism_summary,
               boxed_warning, key_adverse_effects, key_interactions, storage_handling,
               high_alert_flag, fda_spl_set_id, dailymed_url
        FROM drugs ORDER BY generic_name ASC;
        """
        var stmt: OpaquePointer?
        var results: [DrugItem] = []

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let brandsJson = colString(stmt, 2)
                let brands = (try? JSONDecoder().decode([String].self, from: Data(brandsJson.utf8))) ?? []
                results.append(
                    DrugItem(
                        id: colString(stmt, 0),
                        genericName: colString(stmt, 1),
                        brandNames: brands,
                        tallManName: colOptionalString(stmt, 3),
                        drugClass: colString(stmt, 4),
                        deaSchedule: colString(stmt, 5),
                        remsProgram: colOptionalString(stmt, 6),
                        indicationsSummary: colString(stmt, 7),
                        mechanismSummary: colString(stmt, 8),
                        boxedWarning: colOptionalString(stmt, 9),
                        keyAdverseEffects: colString(stmt, 10),
                        keyInteractions: colString(stmt, 11),
                        storageHandling: colString(stmt, 12),
                        isHighAlert: sqlite3_column_int(stmt, 13) == 1,
                        fdaSplSetId: colString(stmt, 14),
                        dailymedUrl: colString(stmt, 15)
                    )
                )
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    public func loadFlashcards(examCode: String) -> [FlashcardItem] {
        guard let db = db else { return [] }
        let sql = """
        SELECT id, drug_id, exam_code, domain_code, card_type,
               front_prompt, back_answer, back_detail, citation_label, citation_url, is_free_tier
        FROM flashcards WHERE exam_code = ? ORDER BY id ASC;
        """
        var stmt: OpaquePointer?
        var results: [FlashcardItem] = []

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (examCode as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(
                    FlashcardItem(
                        id: colString(stmt, 0),
                        drugId: colOptionalString(stmt, 1),
                        examCode: colString(stmt, 2),
                        domainCode: colString(stmt, 3),
                        cardType: colString(stmt, 4),
                        frontPrompt: colString(stmt, 5),
                        backAnswer: colString(stmt, 6),
                        backDetail: colString(stmt, 7),
                        citationLabel: colString(stmt, 8),
                        citationUrl: colString(stmt, 9),
                        isFreeTier: sqlite3_column_int(stmt, 10) == 1
                    )
                )
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    public func loadQuestions(examCode: String) -> [QuestionItem] {
        guard let db = db else { return [] }
        let sql = """
        SELECT id, drug_id, exam_code, domain_code, question_type, difficulty,
               stem, choices_json, correct_choice_id, explanation,
               fda_spl_set_id, citation_quote, citation_url, generator_source, is_free_tier
        FROM questions WHERE exam_code = ? AND review_status = 'approved' ORDER BY difficulty ASC, id ASC;
        """
        var stmt: OpaquePointer?
        var results: [QuestionItem] = []

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (examCode as NSString).utf8String, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let choicesJson = colString(stmt, 7)
                let choices = (try? JSONDecoder().decode([ChoiceOption].self, from: Data(choicesJson.utf8))) ?? []
                results.append(
                    QuestionItem(
                        id: colString(stmt, 0),
                        drugId: colOptionalString(stmt, 1),
                        examCode: colString(stmt, 2),
                        domainCode: colString(stmt, 3),
                        questionType: colString(stmt, 4),
                        difficulty: Int(sqlite3_column_int(stmt, 5)),
                        stem: colString(stmt, 6),
                        choices: choices,
                        correctChoiceId: colString(stmt, 8),
                        explanation: colString(stmt, 9),
                        fdaSplSetId: colOptionalString(stmt, 10),
                        citationQuote: colString(stmt, 11),
                        citationUrl: colString(stmt, 12),
                        generatorSource: colString(stmt, 13),
                        isFreeTier: sqlite3_column_int(stmt, 14) == 1
                    )
                )
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    private func colString(_ stmt: OpaquePointer?, _ idx: Int32) -> String {
        guard let cStr = sqlite3_column_text(stmt, idx) else { return "" }
        return String(cString: cStr)
    }

    private func colOptionalString(_ stmt: OpaquePointer?, _ idx: Int32) -> String? {
        guard sqlite3_column_type(stmt, idx) != SQLITE_NULL,
              let cStr = sqlite3_column_text(stmt, idx) else { return nil }
        return String(cString: cStr)
    }
}
