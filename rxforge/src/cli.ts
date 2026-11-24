import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { DEFAULT_IOS_PACK_DB, StagingDatabase } from "./db.js";
import { ingestTopDrugsFromOpenFda } from "./ingest/openfda.js";
import { generateDeterministicMathQuestions } from "./math/generator.js";
import { generateQuestionsWithPiAgents } from "./agents/piQuestionFactory.js";
import { startReviewServer } from "./review/server.js";
import { exportApprovedPackToIos } from "./exporter/buildPack.js";
import type { DomainCode, ExamCode } from "./types.js";

function loadDotEnvIfPresent(): void {
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const envPath = path.resolve(__dirname, "../.env");
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, "utf-8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const val = trimmed.slice(eq + 1).trim();
    if (val && !process.env[key]) {
      process.env[key] = val;
    }
  }
}

async function main(): Promise<void> {
  loadDotEnvIfPresent();
  const cmd = process.argv[2] ?? "help";
  const db = new StagingDatabase();

  try {
    switch (cmd) {
      case "ingest-fda": {
        console.log("[RxForge] Fetching live openFDA SPL labels & building flashcards...");
        const count = await ingestTopDrugsFromOpenFda(db);
        console.log(`[RxForge] Ingested ${count} Top Drugs from openFDA.`, db.getStats());
        break;
      }

      case "gen-math": {
        console.log("[RxForge] Generating deterministic pharmacy math items...");
        const count = generateDeterministicMathQuestions(db);
        console.log(`[RxForge] Generated ${count} deterministic math items.`, db.getStats());
        break;
      }

      case "gen-ai": {
        const examCode = ((process.argv[3] as ExamCode | undefined) ?? "PTCE");
        const domainCode = ((process.argv[4] as DomainCode | undefined) ?? "PATIENT_SAFETY");
        const drugId = process.argv[5];
        const count = await generateQuestionsWithPiAgents(db, {
          examCode,
          domainCode,
          drugId,
          count: 3
        });
        console.log(`[RxForge] Staged ${count} Blind-Critic-verified items for review.`);
        break;
      }

      case "review": {
        startReviewServer(db, 4321);
        return; // Keep server alive
      }

      case "export-pack": {
        const res = exportApprovedPackToIos(db, DEFAULT_IOS_PACK_DB);
        console.log(
          `[RxForge] Exported iOS SQLite pack -> ${DEFAULT_IOS_PACK_DB} (${(res.bytes / 1024).toFixed(1)} KB)`,
          res
        );
        break;
      }

      case "seed-all": {
        console.log("[1/3] Fetching live openFDA SPL drug labels & flashcards...");
        await ingestTopDrugsFromOpenFda(db);
        console.log("[2/3] Generating deterministic pharmacy math questions...");
        generateDeterministicMathQuestions(db);
        console.log("[3/3] Exporting read-only SQLite bundle into ios/VeriRx/Resources/...");
        const res = exportApprovedPackToIos(db, DEFAULT_IOS_PACK_DB);
        console.log(
          `✓ Ready! Exported ${res.drugs} drugs, ${res.flashcards} flashcards, ${res.questions} approved questions (${(res.bytes / 1024).toFixed(1)} KB).`
        );
        break;
      }

      default:
        console.log(
          "Usage: npm run <ingest:fda | gen:math | gen:ai | review | export:pack | seed:all>"
        );
    }
  } finally {
    if (cmd !== "review") {
      db.close();
    }
  }
}

main().catch((err) => {
  console.error("[RxForge Error]", err);
  process.exit(1);
});
