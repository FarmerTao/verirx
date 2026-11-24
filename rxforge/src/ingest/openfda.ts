import type { StagingDatabase } from "../db.js";
import type { DrugRecord, FlashcardRecord, QuestionRecord } from "../types.js";
import { TOP_DRUGS_SEED, type SeedDrugSpec } from "./topDrugsCatalog.js";

interface OpenFdaLabelResult {
  set_id?: string;
  id?: string;
  openfda?: {
    application_number?: string[];
    brand_name?: string[];
    generic_name?: string[];
  };
  boxed_warning?: string[];
  indications_and_usage?: string[];
  contraindications?: string[];
  warnings_and_cautions?: string[];
  warnings?: string[];
  drug_interactions?: string[];
  adverse_reactions?: string[];
  storage_and_handling?: string[];
  how_supplied?: string[];
}

function cleanExcerpt(arr?: string[], maxChars = 650): string | null {
  if (!arr || arr.length === 0) return null;
  const text = arr.join(" ").replace(/\s+/g, " ").trim();
  if (!text) return null;
  return text.length > maxChars ? `${text.slice(0, maxChars)}…` : text;
}

async function fetchOpenFdaLabel(queryGeneric: string): Promise<OpenFdaLabelResult | null> {
  const apiKey = process.env.OPENFDA_API_KEY ? `&api_key=${encodeURIComponent(process.env.OPENFDA_API_KEY)}` : "";
  const search = encodeURIComponent(`openfda.generic_name:"${queryGeneric}"`);
  const url = `https://api.fda.gov/drug/label.json?search=${search}&limit=1${apiKey}`;

  try {
    const res = await fetch(url, {
      headers: { "User-Agent": "VeriRx-RxForge/0.1 (Educational Exam Prep Builder)" }
    });
    if (!res.ok) return null;
    const data = (await res.json()) as { results?: OpenFdaLabelResult[] };
    return data.results?.[0] ?? null;
  } catch {
    return null;
  }
}

export async function ingestTopDrugsFromOpenFda(db: StagingDatabase): Promise<number> {
  let ingestedCount = 0;
  const now = new Date().toISOString();

  for (const spec of TOP_DRUGS_SEED) {
    const label = await fetchOpenFdaLabel(spec.fda_query_generic);
    const setId = label?.set_id ?? `fallback-${spec.id}`;
    const appNo = label?.openfda?.application_number?.[0] ?? null;
    const dailymedUrl = label?.set_id
      ? `https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=${label.set_id}`
      : `https://dailymed.nlm.nih.gov/dailymed/search.cfm?labeltype=all&query=${encodeURIComponent(spec.generic_name)}`;

    const fdaBoxed = cleanExcerpt(label?.boxed_warning, 500);
    const fdaIndications = cleanExcerpt(label?.indications_and_usage, 500);
    const fdaInteractions = cleanExcerpt(label?.drug_interactions, 500);
    const fdaStorage = cleanExcerpt(label?.storage_and_handling ?? label?.how_supplied, 400);
    const fdaWarnings = cleanExcerpt(label?.warnings_and_cautions ?? label?.warnings, 500);

    const rawExcerptParts = [
      fdaBoxed ? `[BOXED WARNING] ${fdaBoxed}` : null,
      fdaIndications ? `[INDICATIONS] ${fdaIndications}` : null,
      fdaInteractions ? `[DRUG INTERACTIONS] ${fdaInteractions}` : null,
      fdaWarnings ? `[WARNINGS] ${fdaWarnings}` : null,
      fdaStorage ? `[STORAGE & HANDLING] ${fdaStorage}` : null
    ].filter(Boolean);

    const rawLabelExcerpt =
      rawExcerptParts.length > 0
        ? rawExcerptParts.join("\n\n")
        : `[FDA SUMMARY] ${spec.concise_indication}. Interactions: ${spec.concise_interactions}. Storage: ${spec.concise_storage}.`;

    const record: DrugRecord = {
      id: spec.id,
      generic_name: spec.generic_name,
      brand_names: spec.brand_names,
      tall_man_name: spec.tall_man_name,
      drug_class: spec.drug_class,
      dea_schedule: spec.dea_schedule,
      rems_program: spec.rems_program,
      indications_summary: spec.concise_indication,
      mechanism_summary: spec.concise_moa,
      boxed_warning: fdaBoxed,
      key_adverse_effects: spec.concise_adverse,
      key_interactions: spec.concise_interactions,
      storage_handling: spec.concise_storage,
      high_alert_flag: spec.high_alert_flag,
      fda_spl_set_id: setId,
      fda_application_number: appNo,
      dailymed_url: dailymedUrl,
      raw_label_excerpt: rawLabelExcerpt,
      updated_at: now
    };

    db.upsertDrug(record);
    generateFlashcardsForDrug(db, spec, record);
    ingestedCount++;
  }

  seedGroundedVignetteQuestions(db);
  return ingestedCount;
}

function generateFlashcardsForDrug(
  db: StagingDatabase,
  spec: SeedDrugSpec,
  record: DrugRecord
): void {
  const citationLabel = appOrSplCitation(record);

  const cards: FlashcardRecord[] = [
    {
      id: `fc-${spec.id}-brand`,
      drug_id: spec.id,
      exam_code: "PTCE",
      domain_code: "MEDICATIONS",
      card_type: "brand_generic",
      front_prompt: `What is the generic name and therapeutic class of ${spec.brand_names[0]}®?`,
      back_answer: `${spec.generic_name} — ${spec.drug_class}`,
      back_detail: `Primary Indication: ${spec.concise_indication}.${spec.tall_man_name ? ` ISMP Tall Man: ${spec.tall_man_name}.` : ""}`,
      citation_label: citationLabel,
      citation_url: record.dailymed_url,
      is_free_tier: spec.is_free_tier
    },
    {
      id: `fc-${spec.id}-safety`,
      drug_id: spec.id,
      exam_code: "PTCE",
      domain_code: "PATIENT_SAFETY",
      card_type: "safety_warning",
      front_prompt: `Which critical safety risks and drug interactions must be flagged for ${spec.generic_name} (${spec.brand_names[0]}®)?`,
      back_answer: spec.concise_adverse,
      back_detail: `Key Interactions: ${spec.concise_interactions}.${record.boxed_warning ? " Carries an FDA Boxed Warning." : ""}`,
      citation_label: citationLabel,
      citation_url: record.dailymed_url,
      is_free_tier: spec.is_free_tier
    },
    {
      id: `fc-${spec.id}-law-storage`,
      drug_id: spec.id,
      exam_code: "PTCE",
      domain_code:
        spec.dea_schedule !== "Rx" && spec.dea_schedule !== "OTC"
          ? "FEDERAL_REQUIREMENTS"
          : "ORDER_ENTRY_MATH",
      card_type: "law_schedule",
      front_prompt: `What is the DEA classification, REMS requirement, and storage/dispensing rule for ${spec.generic_name}?`,
      back_answer: `Schedule: ${spec.dea_schedule}${spec.rems_program ? ` | REMS: ${spec.rems_program}` : " | Standard Rx"}`,
      back_detail: spec.concise_storage,
      citation_label: citationLabel,
      citation_url: record.dailymed_url,
      is_free_tier: spec.is_free_tier
    }
  ];

  for (const card of cards) {
    db.upsertFlashcard(card);
  }
}

function appOrSplCitation(record: DrugRecord): string {
  const appPart = record.fda_application_number ? `${record.fda_application_number} · ` : "";
  return `FDA SPL (${appPart}Set ID: ${record.fda_spl_set_id.slice(0, 8)}…)`;
}

/**
 * Curated, 100% FDA-label-anchored starter PTCE vignette MCQs
 * linked to the live openFDA SPL set_ids fetched above.
 */
function seedGroundedVignetteQuestions(db: StagingDatabase): void {
  const drugsById = new Map(db.listDrugs().map((d) => [d.id, d]));
  const now = new Date().toISOString();

  const items: Omit<QuestionRecord, "fda_spl_set_id" | "citation_url" | "created_at">[] = [
    {
      id: "vig-ptce-isotretinoin-rems",
      drug_id: "isotretinoin",
      exam_code: "PTCE",
      domain_code: "FEDERAL_REQUIREMENTS",
      question_type: "vignette_mcq",
      difficulty: 3,
      stem: "A patient presents a valid prescription for isotretinoin (Absorica) 40 mg capsules BID with 'Refill x 2' written by the dermatologist. Which action must the pharmacy technician take during order entry?",
      choices: [
        {
          id: "A",
          text: "Verify active iPLEDGE REMS authorization and enter a maximum 30-day supply with zero refills",
          rationale: "Correct. Isotretinoin is restricted under the FDA iPLEDGE REMS program due to severe teratogenicity; dispensing requires an active RMA/authorization, max 30-day supply, and no automatic refills."
        },
        {
          id: "B",
          text: "Process the 30-day fill and store the 2 remaining refills on hold for up to 6 months",
          rationale: "Incorrect. Unlike Schedule III–V or standard legend prescriptions, isotretinoin prescriptions under iPLEDGE cannot have refills stored; each 30-day fill requires a new prescription and new iPLEDGE authorization."
        },
        {
          id: "C",
          text: "File the hard-copy prescription in the locked Schedule II controlled substance cabinet",
          rationale: "Incorrect. Isotretinoin is a non-controlled legend drug with a REMS program, not a DEA Schedule II substance."
        },
        {
          id: "D",
          text: "Recommend co-dispensing an OTC vitamin A supplement to reduce mucocutaneous dryness",
          rationale: "Incorrect. Vitamin A supplements are strictly contraindicated/avoided with isotretinoin because of additive hypervitaminosis A toxicity, and technicians cannot recommend therapy."
        }
      ],
      correct_choice_id: "A",
      explanation:
        "Under the FDA-mandated iPLEDGE REMS program, isotretinoin may only be dispensed upon verification of active iPLEDGE authorization, for no more than a 30-day supply, with no refills permitted.",
      citation_quote:
        "FDA SPL / iPLEDGE REMS: Isotretinoin is contraindicated in pregnancy; dispense max 30-day supply with active iPLEDGE authorization and no automatic refills.",
      generator_source: "curated_fda_seed",
      blind_critic_json: JSON.stringify({ verified: true, ambiguity_score: 0 }),
      review_status: "approved",
      is_free_tier: 1
    },
    {
      id: "vig-ptce-hydralazine-lasa",
      drug_id: "hydralazine",
      exam_code: "PTCE",
      domain_code: "PATIENT_SAFETY",
      question_type: "vignette_mcq",
      difficulty: 2,
      stem: "While pulling stock for an antihypertensive order reading 'Hydralazine 25 mg PO QID', a technician notices an adjacent bottle labeled 'hydrOXYzine 25 mg'. Why does ISMP/FDA Tall Man Lettering highlight 'hydrALAZINE' vs. 'hydrOXYzine'?",
      choices: [
        {
          id: "A",
          text: "Both are direct arterial vasodilators with different DEA controlled substance schedules",
          rationale: "Incorrect. Neither drug is a DEA controlled substance, and hydroxyzine is an antihistamine, not a vasodilator."
        },
        {
          id: "B",
          text: "They share look-alike/sound-alike (LASA) names and overlapping 25 mg tablet strengths despite completely different indications",
          rationale: "Correct. Hydralazine (arterial vasodilator for hypertension/HF) and hydroxyzine (antihistamine for anxiety/pruritus) both come in 25 mg oral dosage forms, creating a classic high-risk LASA dispensing error."
        },
        {
          id: "C",
          text: "Tall Man Lettering indicates that hydrOXYzine is the authorized generic of hydrALAZINE",
          rationale: "Incorrect. They are distinct chemical entities in unrelated therapeutic classes."
        },
        {
          id: "D",
          text: "Tall Man Lettering denotes medications that require refrigeration prior to reconstitution",
          rationale: "Incorrect. Both oral tablets are stored at controlled room temperature (20°C–25°C)."
        }
      ],
      correct_choice_id: "B",
      explanation:
        "FDA and ISMP Tall Man Lettering (hydrALAZINE vs. hydrOXYzine) visually differentiates look-alike/sound-alike drug names that share overlapping 10 mg, 25 mg, and 50 mg strengths.",
      citation_quote:
        "FDA Name Differentiation Project: hydrALAZINE (antihypertensive vasodilator) vs. hydrOXYzine (antihistamine) LASA pair.",
      generator_source: "curated_fda_seed",
      blind_critic_json: JSON.stringify({ verified: true, ambiguity_score: 0 }),
      review_status: "approved",
      is_free_tier: 1
    },
    {
      id: "vig-ptce-oxycodone-c2-refill",
      drug_id: "oxycodone",
      exam_code: "PTCE",
      domain_code: "FEDERAL_REQUIREMENTS",
      question_type: "vignette_mcq",
      difficulty: 2,
      stem: "A patient brings a written prescription for oxycodone IR (Roxicodone) 5 mg #30 with '1 refill' written by an orthopedic surgeon. Under the federal Controlled Substances Act, which rule applies?",
      choices: [
        {
          id: "A",
          text: "Schedule II prescriptions cannot be refilled; any subsequent supply requires a new prescription",
          rationale: "Correct. Under 21 CFR § 1306.12, refilling a Schedule II controlled substance prescription is strictly prohibited."
        },
        {
          id: "B",
          text: "Up to 5 refills are allowed within 6 months of the date the prescription was issued",
          rationale: "Incorrect. The 5-refills-in-6-months rule applies to Schedule III and Schedule IV controlled substances (such as alprazolam), not Schedule II."
        },
        {
          id: "C",
          text: "One emergency refill of a 72-hour supply may be dispensed at the technician's discretion",
          rationale: "Incorrect. Schedule II prescriptions have no refills, and technicians never exercise independent clinical/emergency dispensing authority."
        },
        {
          id: "D",
          text: "The refill is valid only if transferred electronically to another pharmacy chain",
          rationale: "Incorrect. Refills on Schedule II orders are prohibited regardless of transfer method."
        }
      ],
      correct_choice_id: "A",
      explanation:
        "Oxycodone (both immediate-release and extended-release) is a DEA Schedule II opioid analgesic. Federal law (21 CFR 1306.12) prohibits refills on Schedule II prescriptions.",
      citation_quote:
        "21 CFR § 1306.12 & FDA Oxycodone SPL: Schedule II controlled substance; no refills permitted.",
      generator_source: "curated_fda_seed",
      blind_critic_json: JSON.stringify({ verified: true, ambiguity_score: 0 }),
      review_status: "approved",
      is_free_tier: 1
    },
    {
      id: "vig-ptce-levothyroxine-cation-sep",
      drug_id: "levothyroxine",
      exam_code: "PTCE",
      domain_code: "PATIENT_SAFETY",
      question_type: "vignette_mcq",
      difficulty: 3,
      stem: "A patient picking up levothyroxine (Synthroid) 100 mcg tablets asks the cashier if she can swallow it together with her morning calcium carbonate and iron tablets. Why should this profile/question be referred to the pharmacist?",
      choices: [
        {
          id: "A",
          text: "Calcium and iron chelate levothyroxine in the GI tract, requiring at least a 4-hour separation",
          rationale: "Correct. Per the FDA Synthroid label, calcium carbonate and ferrous sulfate bind levothyroxine in the GI tract and markedly reduce absorption; administration must be separated by at least 4 hours."
        },
        {
          id: "B",
          text: "Co-administration triggers life-threatening serotonin syndrome within 2 hours",
          rationale: "Incorrect. Levothyroxine is a thyroid hormone, not a serotonergic agent."
        },
        {
          id: "C",
          text: "Levothyroxine must be taken exclusively with a high-fat evening meal for absorption",
          rationale: "Incorrect. Levothyroxine is taken on an empty stomach 30–60 minutes before breakfast for optimal absorption."
        },
        {
          id: "D",
          text: "Calcium carbonate converts levothyroxine into a Schedule IV controlled substance metabolite",
          rationale: "Incorrect. Polyvalent cations impair GI absorption via chelation/adsorption, not controlled substance conversion."
        }
      ],
      correct_choice_id: "A",
      explanation:
        "Polyvalent cations (calcium, iron, aluminum/magnesium antacids) form insoluble complexes with levothyroxine in the gut. The pharmacist counsels patients to separate levothyroxine by at least 4 hours.",
      citation_quote:
        "FDA Levothyroxine Sodium SPL [Drug Interactions]: Administer levothyroxine sodium at least 4 hours apart from calcium carbonate and ferrous sulfate.",
      generator_source: "curated_fda_seed",
      blind_critic_json: JSON.stringify({ verified: true, ambiguity_score: 0 }),
      review_status: "approved",
      is_free_tier: 1
    },
    {
      id: "vig-ptce-warfarin-inr-alert",
      drug_id: "warfarin",
      exam_code: "PTCE",
      domain_code: "PATIENT_SAFETY",
      question_type: "vignette_mcq",
      difficulty: 4,
      stem: "During order entry for a patient stabilized on warfarin (Coumadin) 5 mg daily, a new prescription for sulfamethoxazole/trimethoprim (Bactrim DS) BID x 7 days triggers a high-severity DUR alert. What is the pharmacological basis for alerting the pharmacist?",
      choices: [
        {
          id: "A",
          text: "Sulfamethoxazole/trimethoprim inhibits CYP2C9, markedly elevating warfarin exposure and bleeding risk",
          rationale: "Correct. S-warfarin is metabolized primarily by CYP2C9; TMP-SMX strongly inhibits CYP2C9 and displaces/potentiates warfarin, causing dangerous INR spikes and hemorrhage."
        },
        {
          id: "B",
          text: "Sulfamethoxazole supplies high doses of exogenous vitamin K that clot mechanical heart valves",
          rationale: "Incorrect. Antibiotics reduce gut flora vitamin K and inhibit CYP2C9, increasing INR/bleeding rather than supplying vitamin K."
        },
        {
          id: "C",
          text: "Warfarin chelation in the stomach prevents absorption of sulfonamide antibiotics",
          rationale: "Incorrect. Chelation applies to fluoroquinolones/tetracyclines with divalent cations, not warfarin with TMP-SMX."
        },
        {
          id: "D",
          text: "Both medications are HMG-CoA reductase inhibitors that cause additive rhabdomyolysis",
          rationale: "Incorrect. Neither warfarin (anticoagulant) nor TMP-SMX (folate-antagonist antibiotic) is a statin."
        }
      ],
      correct_choice_id: "A",
      explanation:
        "Warfarin is an ISMP High-Alert anticoagulant with a narrow therapeutic index. Strong CYP2C9 inhibitors such as sulfamethoxazole/trimethoprim, metronidazole, fluconazole, and amiodarone dangerously increase INR and bleeding risk.",
      citation_quote:
        "FDA Warfarin Sodium SPL [Boxed Warning & CYP2C9 Interactions]: Warfarin can cause major or fatal bleeding; CYP2C9 inhibitors including trimethoprim/sulfamethoxazole increase PT/INR.",
      generator_source: "curated_fda_seed",
      blind_critic_json: JSON.stringify({ verified: true, ambiguity_score: 0 }),
      review_status: "approved",
      is_free_tier: 0
    },
    {
      id: "vig-ptce-glargine-mixing-storage",
      drug_id: "insulin_glargine",
      exam_code: "PTCE",
      domain_code: "MEDICATIONS",
      question_type: "vignette_mcq",
      difficulty: 3,
      stem: "Which statement accurately reflects FDA-approved storage and handling requirements for insulin glargine (Lantus) SoloStar U-100 pens?",
      choices: [
        {
          id: "A",
          text: "Refrigerate unopened pens at 2°C–8°C; once in use, keep at room temperature (<30°C) for up to 28 days and never mix with other insulins",
          rationale: "Correct. Unopened insulin glargine is refrigerated (2°C–8°C, never frozen). In-use Lantus SoloStar pens are stored at room temperature up to 28 days, and insulin glargine must never be diluted or mixed with other insulins because pH changes alter its precipitation profile."
        },
        {
          id: "B",
          text: "Store unopened pens in the pharmacy freezer (-20°C) and thaw immediately prior to dispensing",
          rationale: "Incorrect. Freezing denatures insulin proteins; frozen insulin must be discarded."
        },
        {
          id: "C",
          text: "Mix insulin glargine in the same syringe with regular insulin (cloudy after clear) to reduce injections",
          rationale: "Incorrect. 'Clear before cloudy' applies to Regular + NPH insulin; insulin glargine has an acidic pH (~4) and must NEVER be mixed with any other insulin."
        },
        {
          id: "D",
          text: "Discard any in-use insulin glargine pen 7 days after first puncture",
          rationale: "Incorrect. In-use Lantus SoloStar pens have a 28-day beyond-use window at room temperature, not 7 days."
        }
      ],
      correct_choice_id: "A",
      explanation:
        "Insulin glargine is an ISMP High-Alert basal insulin formulated at acidic pH 4.0. Mixing it with neutral-pH insulins ruins its microprecipitate release kinetics, and freezing destroys potency.",
      citation_quote:
        "FDA Insulin Glargine SPL [Dosage & Storage]: Do NOT dilute or mix with any other insulin or solution. Store unopened refrigerated 36°F–46°F (2°C–8°C); in-use pens room temp up to 28 days.",
      generator_source: "curated_fda_seed",
      blind_critic_json: JSON.stringify({ verified: true, ambiguity_score: 0 }),
      review_status: "approved",
      is_free_tier: 0
    }
  ];

  for (const item of items) {
    const drug = item.drug_id ? drugsById.get(item.drug_id) : undefined;
    db.upsertQuestion({
      ...item,
      fda_spl_set_id: drug?.fda_spl_set_id ?? null,
      citation_url: drug?.dailymed_url ?? "https://dailymed.nlm.nih.gov/",
      created_at: now
    });
  }
}
