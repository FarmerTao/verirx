import {
  Type,
  completeSimple,
  getEnvApiKey,
  getModels,
  type KnownProvider,
  type Model
} from "@mariozechner/pi-ai";
import { Agent, type AgentTool } from "@mariozechner/pi-agent-core";
import crypto from "node:crypto";
import type { StagingDatabase } from "../db.js";
import type { ChoiceOption, DomainCode, DrugRecord, ExamCode } from "../types.js";

export interface PiFactoryOptions {
  examCode: ExamCode;
  domainCode: DomainCode;
  drugId?: string;
  count?: number;
}

interface BlindCriticVerdict {
  selected_choice_id: "A" | "B" | "C" | "D";
  ambiguity_score: number;
  clinical_accuracy_ok: boolean;
  critique: string;
}

function resolvePiModel(providerEnv: string | undefined, modelEnv: string | undefined, fallbackProvider: KnownProvider, fallbackModelSubstring: string): Model<any> {
  const provider = (providerEnv || fallbackProvider) as KnownProvider;
  const models = getModels(provider);
  if (models.length === 0) {
    throw new Error(`No registered pi-ai models found for provider "${provider}".`);
  }
  if (modelEnv) {
    const exact = models.find((m) => m.id === modelEnv);
    if (exact) return exact;
    const partial = models.find((m) => m.id.includes(modelEnv));
    if (partial) return partial;
  }
  return models.find((m) => m.id.includes(fallbackModelSubstring)) ?? models[0];
}

function autoDetectDefaultProvider(): { writer: [KnownProvider, string]; critic: [KnownProvider, string] } {
  if (getEnvApiKey("openrouter")) {
    return {
      writer: ["openrouter", "anthropic/claude-sonnet-4"],
      critic: ["openrouter", "openai/gpt-4.1"]
    };
  }
  const hasAnthropic = Boolean(getEnvApiKey("anthropic"));
  const hasOpenAI = Boolean(getEnvApiKey("openai"));
  const hasGoogle = Boolean(getEnvApiKey("google"));

  if (hasAnthropic && hasOpenAI) {
    return {
      writer: ["anthropic", "claude-sonnet-4"],
      critic: ["openai", "gpt-4.1"]
    };
  }
  if (hasOpenAI) {
    return {
      writer: ["openai", "gpt-4.1"],
      critic: ["openai", "gpt-4.1-mini"]
    };
  }
  if (hasAnthropic) {
    return {
      writer: ["anthropic", "claude-sonnet-4"],
      critic: ["anthropic", "claude-3-5-haiku"]
    };
  }
  if (hasGoogle) {
    return {
      writer: ["google", "gemini-2.5-pro"],
      critic: ["google", "gemini-2.5-flash"]
    };
  }
  throw new Error(
    "No LLM API key detected. Set OPENROUTER_API_KEY, ANTHROPIC_API_KEY, OPENAI_API_KEY, or GEMINI_API_KEY in rxforge/.env before running `gen:ai`."
  );
}

async function runBlindCritic(
  criticModel: Model<any>,
  examCode: ExamCode,
  stem: string,
  choices: { id: string; text: string }[],
  fdaReferenceText: string
): Promise<BlindCriticVerdict> {
  const optionsFormatted = choices.map((c) => `${c.id}. ${c.text}`).join("\n");
  const systemPrompt = `You are an independent Blind Pharmacy/Medical Board Psychometrician auditing a candidate ${examCode} exam item.
You are NOT told the intended answer. Solve the question strictly using the official FDA SPL facts below, check whether more than one choice could be defended, and return ONLY valid JSON:
{"selected_choice_id":"A"|"B"|"C"|"D","ambiguity_score":0-10,"clinical_accuracy_ok":true|false,"critique":"brief reason"}`;

  const userPrompt = `[OFFICIAL FDA REFERENCE]\n${fdaReferenceText}\n\n[CANDIDATE STEM]\n${stem}\n\n[CHOICES]\n${optionsFormatted}`;

  const msg = await completeSimple(
    criticModel,
    {
      systemPrompt,
      messages: [{ role: "user", content: userPrompt, timestamp: Date.now() }]
    },
    { temperature: 0.1 }
  );

  const rawText = msg.content
    .filter((b): b is { type: "text"; text: string } => b.type === "text")
    .map((b) => b.text)
    .join("\n")
    .trim();

  const jsonMatch = rawText.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error(`Blind Critic did not return JSON: ${rawText.slice(0, 200)}`);
  }
  return JSON.parse(jsonMatch[0]) as BlindCriticVerdict;
}

export async function generateQuestionsWithPiAgents(
  db: StagingDatabase,
  options: PiFactoryOptions
): Promise<number> {
  const defaults = autoDetectDefaultProvider();
  const writerModel = resolvePiModel(
    process.env.RXFORGE_WRITER_PROVIDER,
    process.env.RXFORGE_WRITER_MODEL,
    defaults.writer[0],
    defaults.writer[1]
  );
  const criticModel = resolvePiModel(
    process.env.RXFORGE_CRITIC_PROVIDER,
    process.env.RXFORGE_CRITIC_MODEL,
    defaults.critic[0],
    defaults.critic[1]
  );

  const allDrugs = db.listDrugs();
  const targetDrugs: DrugRecord[] = options.drugId
    ? allDrugs.filter((d) => d.id === options.drugId)
    : allDrugs.slice(0, options.count ?? 3);

  if (targetDrugs.length === 0) {
    throw new Error("No drugs in staging DB. Run `npm run ingest:fda` first.");
  }

  console.log(
    `[RxForge Pi Factory] Writer=${writerModel.provider}/${writerModel.id} | BlindCritic=${criticModel.provider}/${criticModel.id}`
  );

  const ReadFdaLabelParams = Type.Object({
    drug_id: Type.String({ description: "Drug slug ID to inspect official FDA SPL facts and peer drugs" })
  });

  const SubmitMcqParams = Type.Object({
    drug_id: Type.String(),
    difficulty: Type.Integer({ minimum: 1, maximum: 5 }),
    stem: Type.String({ minLength: 50, description: "2nd-order clinical or pharmacy workflow vignette stem" }),
    choices: Type.Array(
      Type.Object({
        id: Type.Union([Type.Literal("A"), Type.Literal("B"), Type.Literal("C"), Type.Literal("D")]),
        text: Type.String({ minLength: 3 }),
        rationale: Type.String({ minLength: 15, description: "Why this specific choice is right or why it is a plausible trap" })
      }),
      { minItems: 4, maxItems: 4 }
    ),
    correct_choice_id: Type.Union([
      Type.Literal("A"),
      Type.Literal("B"),
      Type.Literal("C"),
      Type.Literal("D")
    ]),
    explanation: Type.String({ minLength: 30 }),
    citation_quote: Type.String({
      minLength: 15,
      description: "Direct factual quote or statement grounded in the official FDA label"
    })
  });

  let acceptedCount = 0;

  for (const targetDrug of targetDrugs) {
    let attempts = 0;

    const readFdaTool: AgentTool<typeof ReadFdaLabelParams> = {
      name: "read_fda_label",
      label: "Read Official FDA SPL Label",
      description: "Fetch grounded FDA label facts and peer drugs for distractor construction.",
      parameters: ReadFdaLabelParams,
      execute: async (_toolCallId, params) => {
        const d = allDrugs.find((x) => x.id === params.drug_id) ?? targetDrug;
        const peers = allDrugs
          .filter((x) => x.id !== d.id)
          .slice(0, 6)
          .map((p) => `${p.generic_name} (${p.brand_names[0]}, ${p.drug_class}, ${p.dea_schedule})`)
          .join("; ");

        const payload = [
          `Drug: ${d.generic_name} (Brands: ${d.brand_names.join(", ")})`,
          `Class: ${d.drug_class} | DEA: ${d.dea_schedule} | REMS: ${d.rems_program ?? "None"}`,
          `Tall Man: ${d.tall_man_name ?? "N/A"} | FDA SPL Set ID: ${d.fda_spl_set_id}`,
          `Indications: ${d.indications_summary}`,
          `Mechanism: ${d.mechanism_summary}`,
          `Adverse Effects: ${d.key_adverse_effects}`,
          `Interactions: ${d.key_interactions}`,
          `Storage/Handling: ${d.storage_handling}`,
          `Official SPL Excerpt:\n${d.raw_label_excerpt}`,
          `Peer Drugs for Plausible Distractors: ${peers}`
        ].join("\n");

        return {
          content: [{ type: "text", text: payload }],
          details: { drug_id: d.id }
        };
      }
    };

    const submitMcqTool: AgentTool<typeof SubmitMcqParams> = {
      name: "submit_verified_mcq",
      label: "Submit Candidate MCQ to Blind Critic Gate",
      description:
        "Submit a candidate 4-option MCQ. Automatically runs Blind Critic verification; only terminates when Blind Critic agrees with zero ambiguity.",
      parameters: SubmitMcqParams,
      execute: async (_toolCallId, params) => {
        attempts++;
        const fdaBlob = [
          targetDrug.indications_summary,
          targetDrug.mechanism_summary,
          targetDrug.key_adverse_effects,
          targetDrug.key_interactions,
          targetDrug.storage_handling,
          targetDrug.raw_label_excerpt
        ].join("\n");

        const blindChoices = params.choices.map((c) => ({ id: c.id, text: c.text }));
        const verdict = await runBlindCritic(
          criticModel,
          options.examCode,
          params.stem,
          blindChoices,
          fdaBlob
        );

        const passed =
          verdict.selected_choice_id === params.correct_choice_id &&
          verdict.clinical_accuracy_ok &&
          verdict.ambiguity_score <= 2;

        if (!passed && attempts < 3) {
          return {
            content: [
              {
                type: "text",
                text: `REJECTED BY BLIND CRITIC (Attempt ${attempts}/3):
- Writer intended answer: ${params.correct_choice_id}
- Blind Critic picked: ${verdict.selected_choice_id}
- Ambiguity score: ${verdict.ambiguity_score}/10 (must be <= 2)
- Clinical accuracy OK: ${verdict.clinical_accuracy_ok}
- Critique: ${verdict.critique}
Revise the stem/distractors so there is exactly ONE indisputable answer grounded in the FDA label, then call submit_verified_mcq again.`
              }
            ],
            details: verdict,
            terminate: false
          };
        }

        if (!passed) {
          return {
            content: [{ type: "text", text: "Max revision attempts reached; skipping item." }],
            details: verdict,
            terminate: true
          };
        }

        const qId = `ai-${options.examCode.toLowerCase()}-${targetDrug.id}-${crypto.randomBytes(3).toString("hex")}`;
        db.upsertQuestion({
          id: qId,
          drug_id: targetDrug.id,
          exam_code: options.examCode,
          domain_code: options.domainCode,
          question_type: "vignette_mcq",
          difficulty: params.difficulty as 1 | 2 | 3 | 4 | 5,
          stem: params.stem,
          choices: params.choices as ChoiceOption[],
          correct_choice_id: params.correct_choice_id,
          explanation: params.explanation,
          fda_spl_set_id: targetDrug.fda_spl_set_id,
          citation_quote: params.citation_quote,
          citation_url: targetDrug.dailymed_url,
          generator_source: "rxforge_pi_agent",
          blind_critic_json: JSON.stringify({
            critic_model: `${criticModel.provider}/${criticModel.id}`,
            ...verdict
          }),
          review_status: "pending",
          is_free_tier: 0,
          created_at: new Date().toISOString()
        });

        acceptedCount++;
        console.log(`  ✓ Passed Blind Critic -> staged ${qId} (pending founder sign-off)`);

        return {
          content: [{ type: "text", text: `ACCEPTED & STAGED as ${qId}.` }],
          details: { questionId: qId, verdict },
          terminate: true
        };
      }
    };

    const examLens =
      options.examCode === "PTCE"
        ? "PTCE Pharmacy Technician lens: test order entry traps, brand/generic, DEA C-II–C-V rules, REMS, LASA Tall Man pairs, storage/BUD, or flagging severe DUR alerts to the pharmacist (never ask technicians to diagnose)."
        : "NCLEX Nursing Pharmacology lens: test pre-administration vital/lab checks, high-alert adverse effect recognition, antidote, or patient teaching.";

    const writerAgent = new Agent({
      initialState: {
        model: writerModel,
        systemPrompt: `You are an expert ${options.examCode} board item writer inside RxForge.
Rules:
1. First call read_fda_label to inspect the official FDA SPL facts for the target drug.
2. Write a 2nd-order scenario MCQ (never trivial 1st-order recall). ${examLens}
3. All 3 distractors must be realistic clinical/pharmacy traps with specific per-choice rationales.
4. Every claim must be strictly grounded in the FDA label facts. Call submit_verified_mcq to verify.`,
        tools: [readFdaTool, submitMcqTool]
      }
    });

    await writerAgent.prompt(
      `Draft and verify 1 high-yield ${options.examCode} question in domain ${options.domainCode} for drug_id="${targetDrug.id}".`
    );
  }

  return acceptedCount;
}
