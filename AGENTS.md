# VeriRx + RxForge — Project Agent Instructions (`AGENTS.md`)

> Compatible with `@mariozechner/pi-coding-agent` (`pi`) and AI coding harnesses.

## Architecture Overview
- **`schema/schema.sql`**: Single source-of-truth SQLite schema shared between `rxforge` (offline generator) and `ios` (`VeriRx` offline-first native SwiftUI app).
- **`rxforge/`**: Offline Multi-Agent question & flashcard factory built on `@mariozechner/pi-ai`, `@mariozechner/pi-agent-core`, and Node 22 `node:sqlite`.
  - Zero runtime LLM calls ever ship inside the iOS app.
  - All pharmacology facts anchor to US Public Domain federal databases (`openFDA` SPL labels, `DailyMed`, `DEA` schedules).
  - Pharmacy math questions are generated 100% deterministically in TypeScript (`rxforge/src/math/generator.ts`).
  - Clinical/pharmacy vignette MCQs pass through **Writer Agent → Deterministic Quote Check → Blind Critic Agent** (answers with `correct_choice_id` hidden) → **Human Review UI** before export.
- **`ios/`**: Native iOS 17+ SwiftUI app (`VeriRx`) with:
  - Read-only bundled `verirx_pack.sqlite` (`SQLite3` C API, zero external third-party bloat).
  - Pure Swift **FSRS v5** spaced-repetition scheduler + Exam-Date Cram Pacer.
  - **IRT/Elo Adaptive Quiz Selector** simulating PTCE / NCLEX Computerized Adaptive Testing (CAT).
  - Native **StoreKit 2** subscription & lifetime unlock + mandatory PTCB®/NCLEX® trademark & educational disclaimers.

## Key Commands (`rxforge/`)
- `npm --prefix rxforge run ingest:fda` — Fetch live `openFDA` drug labels for Top Drugs & generate FDA-cited flashcards.
- `npm --prefix rxforge run gen:math` — Deterministically generate step-by-step pharmacy math MCQs with trap rationales.
- `npm --prefix rxforge run gen:ai` — Run `@mariozechner/pi-ai` Writer + Blind Critic multi-model pipeline to draft vignette MCQs.
- `npm --prefix rxforge run review` — Launch local browser Review Console (`http://localhost:4321`) for 10-second human sign-off.
- `npm --prefix rxforge run export:pack` — Compile approved items into `ios/VeriRx/Resources/verirx_pack.sqlite`.
- `npm --prefix rxforge run seed:all` — Run full offline seed (`ingest:fda` + `gen:math` + curated vignette seed + `export:pack`).

## Guardrails
1. Never scrape copyrighted commercial Q-banks (UWorld, RxPrep, Archer) or CC BY-NC textbooks (OpenStax, StatPearls).
2. Every drug card and vignette rationale must carry a verifiable `fda_spl_set_id` / `dailymed_url` citation.
3. Keep `VeriRx` categorized under Apple App Store **Education** (never Medical) and retain trademark + non-clinical disclaimers.
