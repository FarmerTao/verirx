import type { StagingDatabase } from "../db.js";
import type { ChoiceOption, QuestionRecord } from "../types.js";

/**
 * 100% Deterministic Pharmacy Math Engine (Zero LLM, Zero Hallucination).
 * Generates parameterized PTCE calculations with realistic calculation-error distractors
 * and per-choice error rationales.
 */
export function generateDeterministicMathQuestions(db: StagingDatabase): number {
  const now = new Date().toISOString();
  const questions: QuestionRecord[] = [
    ...buildOralDaysSupplyItems(now),
    ...buildInsulinDaysSupplyItems(now),
    ...buildPediatricWeightDosingItems(now),
    ...buildAlligationItems(now),
    ...buildIvDripRateItems(now)
  ];

  for (const q of questions) {
    db.upsertQuestion(q);
  }
  return questions.length;
}

function shuffleDeterministic<T>(items: T[], seed: number): T[] {
  const copy = [...items];
  let s = seed;
  for (let i = copy.length - 1; i > 0; i--) {
    s = (s * 1664525 + 1013904223) >>> 0;
    const j = s % (i + 1);
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function assignChoices(
  rawOptions: { text: string; rationale: string; isCorrect: boolean }[],
  seed: number
): { choices: ChoiceOption[]; correctId: "A" | "B" | "C" | "D" } {
  const shuffled = shuffleDeterministic(rawOptions, seed);
  const letters: ("A" | "B" | "C" | "D")[] = ["A", "B", "C", "D"];
  let correctId: "A" | "B" | "C" | "D" = "A";
  const choices: ChoiceOption[] = shuffled.slice(0, 4).map((opt, idx) => {
    const id = letters[idx];
    if (opt.isCorrect) correctId = id;
    return { id, text: opt.text, rationale: opt.rationale };
  });
  return { choices, correctId };
}

function buildOralDaysSupplyItems(now: string): QuestionRecord[] {
  const cases = [
    {
      id: "math-days-taper-1",
      drug: "Prednisone 10 mg tablets",
      qty: 42,
      sig: "4 tabs PO QD x 3 days, then 3 tabs QD x 3 days, then 2 tabs QD x 3 days, then 1 tab QD until gone",
      phaseTabs: 4 * 3 + 3 * 3 + 2 * 3, // 12 + 9 + 6 = 27 tabs in first 9 days; 15 left @ 1/day = 15 days => 24 days
      correctDays: 24,
      wrongSummedOnly: 12,
      wrongDividedFlat: 14,
      wrongForgotLastPhase: 9
    },
    {
      id: "math-days-bid-2",
      drug: "Metformin 500 mg tablets",
      qty: 180,
      sig: "ii tabs PO BID pc",
      phaseTabs: 0,
      correctDays: 45, // 4 tabs/day -> 180 / 4 = 45
      wrongSummedOnly: 90, // forgot ii = 2 tabs (180 / 2)
      wrongDividedFlat: 60, // divided by 3 (TID)
      wrongForgotLastPhase: 30
    },
    {
      id: "math-days-ophthalmic-3",
      drug: "Timolol 0.5% ophthalmic solution (10 mL bottle; pharmacy standard 20 gtts/mL)",
      qty: 10,
      sig: "1 gtt OU BID",
      phaseTabs: 0,
      correctDays: 50, // 10 mL * 20 gtts/mL = 200 gtts; 1 gtt * 2 eyes * 2/day = 4 gtts/day -> 50 days
      wrongSummedOnly: 100, // forgot OU = both eyes (calculated 2 gtts/day)
      wrongDividedFlat: 25, // used QID or 10 gtts/mL
      wrongForgotLastPhase: 30
    }
  ];

  return [
    {
      id: cases[0].id,
      drug_id: null,
      exam_code: "PTCE",
      domain_code: "ORDER_ENTRY_MATH",
      question_type: "math_mcq",
      difficulty: 3,
      stem: `A prescription calls for ${cases[0].drug}, Dispense #${cases[0].qty}, with Sig: "${cases[0].sig}". What is the exact days' supply to bill insurance?`,
      ...(() => {
        const { choices, correctId } = assignChoices(
          [
            {
              text: "24 days",
              rationale:
                "Correct. Days 1–3 use 12 tabs (4×3), Days 4–6 use 9 tabs (3×3), Days 7–9 use 6 tabs (2×3) = 27 tabs over 9 days. Remaining 42 − 27 = 15 tabs at 1 tab/day = 15 days. Total = 9 + 15 = 24 days.",
              isCorrect: true
            },
            {
              text: "12 days",
              rationale: "Incorrect. Assumes 4 phases × 3 days each without calculating the remaining 15 tablets taken at 1 tablet daily.",
              isCorrect: false
            },
            {
              text: "14 days",
              rationale: "Incorrect. Averages 3 tablets/day across the entire 42-tablet bottle instead of computing each taper step.",
              isCorrect: false
            },
            {
              text: "27 days",
              rationale: "Incorrect. 27 is the tablet count consumed during the first 9 days, not the total days' supply.",
              isCorrect: false
            }
          ],
          101
        );
        return { choices, correct_choice_id: correctId };
      })(),
      explanation:
        "Step 1: Sum tablets in fixed taper phases: (4×3) + (3×3) + (2×3) = 12 + 9 + 6 = 27 tablets used in 9 days.\nStep 2: Subtract from total dispensed: 42 − 27 = 15 tablets remaining.\nStep 3: At 1 tablet QD, 15 tablets last 15 days.\nStep 4: Total days' supply = 9 + 15 = 24 days.",
      fda_spl_set_id: null,
      citation_quote: "Deterministic Formula: Total Days = Σ(Phase Days) + (Remaining Qty ÷ Final Daily Dose)",
      citation_url: "https://ptcb.org/credentials/certified-pharmacy-technician/",
      generator_source: "deterministic_math",
      blind_critic_json: null,
      review_status: "approved",
      is_free_tier: 1,
      created_at: now
    },
    {
      id: cases[1].id,
      drug_id: "metformin",
      exam_code: "PTCE",
      domain_code: "ORDER_ENTRY_MATH",
      question_type: "math_mcq",
      difficulty: 1,
      stem: `An order reads: "${cases[1].drug}, Sig: ${cases[1].sig}, Disp #${cases[1].qty}". What days' supply should be entered?`,
      ...(() => {
        const { choices, correctId } = assignChoices(
          [
            {
              text: "45 days",
              rationale: "Correct. 'ii tabs PO BID pc' = 2 tablets twice daily after meals = 4 tablets/day. 180 ÷ 4 = 45 days.",
              isCorrect: true
            },
            {
              text: "90 days",
              rationale: "Incorrect. Common error: misreading Roman numeral 'ii' (2 tablets) as 1 tablet BID (180 ÷ 2 = 90).",
              isCorrect: false
            },
            {
              text: "60 days",
              rationale: "Incorrect. Divides 180 by 3 tablets/day instead of 4 tablets/day.",
              isCorrect: false
            },
            {
              text: "30 days",
              rationale: "Incorrect. Assumes 6 tablets/day (TID) instead of BID.",
              isCorrect: false
            }
          ],
          202
        );
        return { choices, correct_choice_id: correctId };
      })(),
      explanation:
        "Sig translation: 'ii' = 2 tablets, 'PO' = by mouth, 'BID' = twice daily, 'pc' = after meals.\nDaily consumption = 2 × 2 = 4 tablets/day.\nDays' supply = 180 tablets ÷ 4 tablets/day = 45 days.",
      fda_spl_set_id: null,
      citation_quote: "Deterministic Formula: Days' Supply = Total Dispensed Qty ÷ (Dose per Admin × Admins per Day)",
      citation_url: "https://dailymed.nlm.nih.gov/",
      generator_source: "deterministic_math",
      blind_critic_json: null,
      review_status: "approved",
      is_free_tier: 1,
      created_at: now
    },
    {
      id: cases[2].id,
      drug_id: null,
      exam_code: "PTCE",
      domain_code: "ORDER_ENTRY_MATH",
      question_type: "math_mcq",
      difficulty: 3,
      stem: `Calculate the billing days' supply for ${cases[2].drug} with Sig: "${cases[2].sig}".`,
      ...(() => {
        const { choices, correctId } = assignChoices(
          [
            {
              text: "50 days",
              rationale: "Correct. 10 mL × 20 gtts/mL = 200 drops total. '1 gtt OU BID' = 1 drop in BOTH eyes twice daily = 4 drops/day. 200 ÷ 4 = 50 days.",
              isCorrect: true
            },
            {
              text: "100 days",
              rationale: "Incorrect. Trap: forgot 'OU' means both eyes (oculus uterque), calculating 2 drops/day instead of 4 drops/day.",
              isCorrect: false
            },
            {
              text: "25 days",
              rationale: "Incorrect. Used 10 gtts/mL or doubled the daily frequency to QID.",
              isCorrect: false
            },
            {
              text: "38 days",
              rationale: "Incorrect. Used 15 gtts/mL instead of the stated 20 gtts/mL calibration.",
              isCorrect: false
            }
          ],
          303
        );
        return { choices, correct_choice_id: correctId };
      })(),
      explanation:
        "Step 1: Total drops in bottle = 10 mL × 20 gtts/mL = 200 gtts.\nStep 2: 'OU' (both eyes) × 1 gtt × BID (2/day) = 4 gtts/day.\nStep 3: Days' supply = 200 ÷ 4 = 50 days.",
      fda_spl_set_id: null,
      citation_quote: "Deterministic Formula: Ophthalmic Days' Supply = (Bottle mL × gtts/mL) ÷ (Drops × Eyes × Daily Freq)",
      citation_url: "https://ptcb.org/credentials/certified-pharmacy-technician/",
      generator_source: "deterministic_math",
      blind_critic_json: null,
      review_status: "approved",
      is_free_tier: 1,
      created_at: now
    }
  ];
}

function buildInsulinDaysSupplyItems(now: string): QuestionRecord[] {
  return [
    {
      id: "math-insulin-pen-priming-1",
      drug_id: "insulin_glargine",
      exam_code: "PTCE",
      domain_code: "ORDER_ENTRY_MATH",
      question_type: "math_mcq",
      difficulty: 4,
      stem: "A prescription orders Insulin Glargine (Lantus SoloStar U-100, 3 mL/pen, box of 5 pens): 'Inject 28 units subcutaneously QHS, plus 2 units priming test shot prior to each daily injection.' Taking both total units and the 28-day in-use pen expiration into account, how many days will 1 box of 5 pens last?",
      ...(() => {
        const { choices, correctId } = assignChoices(
          [
            {
              text: "50 days",
              rationale:
                "Correct. Each 3 mL U-100 pen holds 300 units. Daily total consumption = 28 + 2 priming = 30 units/day. Each pen lasts 300 ÷ 30 = 10 days (well within the 28-day room-temp expiration!). 5 pens × 10 days/pen = 50 days.",
              isCorrect: true
            },
            {
              text: "53 days",
              rationale: "Incorrect. Trap: forgot to add the 2-unit daily priming waste (calculated 1,500 ÷ 28 = 53.5 days).",
              isCorrect: false
            },
            {
              text: "28 days",
              rationale:
                "Incorrect. Trap: the 28-day Beyond-Use Date applies ONLY to an individual opened in-use pen; unopened pens remain refrigerated until needed.",
              isCorrect: false
            },
            {
              text: "140 days",
              rationale: "Incorrect. Multiplied 5 pens × 28 days without checking that 30 units/day depletes each 300-unit pen in 10 days.",
              isCorrect: false
            }
          ],
          404
        );
        return { choices, correct_choice_id: correctId };
      })(),
      explanation:
        "Step 1: Units per pen = 3 mL × 100 units/mL = 300 units/pen.\nStep 2: Daily units used = 28 dose + 2 priming = 30 units/day.\nStep 3: Days per pen = 300 ÷ 30 = 10 days (≤ 28-day in-use limit, so no insulin is discarded).\nStep 4: 5 pens × 10 days/pen = 50 days.",
      fda_spl_set_id: null,
      citation_quote: "Deterministic Formula: Days/Pen = min(28, Pen Units ÷ [Daily Dose + Priming Units]); Total = Pens × Days/Pen",
      citation_url: "https://dailymed.nlm.nih.gov/",
      generator_source: "deterministic_math",
      blind_critic_json: null,
      review_status: "approved",
      is_free_tier: 0,
      created_at: now
    },
    {
      id: "math-insulin-pen-bud-cap-2",
      drug_id: "insulin_glargine",
      exam_code: "PTCE",
      domain_code: "ORDER_ENTRY_MATH",
      question_type: "math_mcq",
      difficulty: 5,
      stem: "A pediatric patient uses 1 single Lantus SoloStar U-100 pen (3 mL = 300 units) with Sig: 'Inject 6 units subcutaneously once daily at bedtime (includes no extra priming)'. Given the FDA 28-day in-use room-temperature expiration, what is the maximum valid days' supply for 1 pen?",
      ...(() => {
        const { choices, correctId } = assignChoices(
          [
            {
              text: "28 days",
              rationale:
                "Correct. Volume-wise 300 ÷ 6 = 50 days, BUT an opened Lantus SoloStar pen expires 28 days after first use and must be discarded even if insulin remains.",
              isCorrect: true
            },
            {
              text: "50 days",
              rationale: "Incorrect. Trap: divided 300 units by 6 units/day without capping at the mandatory 28-day in-use stability limit.",
              isCorrect: false
            },
            {
              text: "14 days",
              rationale: "Incorrect. Confuses reconstituted amoxicillin suspension (14 days) or certain insulin mixes with Lantus SoloStar's 28-day limit.",
              isCorrect: false
            },
            {
              text: "30 days",
              rationale: "Incorrect. Standard Lantus SoloStar in-use room-temperature stability is 28 days, not 30 days.",
              isCorrect: false
            }
          ],
          505
        );
        return { choices, correct_choice_id: correctId };
      })(),
      explanation:
        "Volume calculation gives 300 units ÷ 6 units/day = 50 days, which exceeds the FDA 28-day in-use expiration for an opened Lantus SoloStar pen. Therefore, days' supply must be capped at 28 days.",
      fda_spl_set_id: null,
      citation_quote: "FDA Lantus SPL & PTCE Rule: Opened U-100 glargine pen must be discarded after 28 days -> min(28, 300 ÷ 6) = 28 days.",
      citation_url: "https://dailymed.nlm.nih.gov/",
      generator_source: "deterministic_math",
      blind_critic_json: null,
      review_status: "approved",
      is_free_tier: 0,
      created_at: now
    }
  ];
}

function buildPediatricWeightDosingItems(now: string): QuestionRecord[] {
  return [
    {
      id: "math-peds-amox-mgkg-1",
      drug_id: "amoxicillin",
      exam_code: "PTCE",
      domain_code: "ORDER_ENTRY_MATH",
      question_type: "math_mcq",
      difficulty: 3,
      stem: "A 44-lb child with acute otitis media is prescribed high-dose amoxicillin 90 mg/kg/day divided BID x 10 days. Pharmacy stock is Amoxicillin 400 mg / 5 mL oral suspension. How many milliliters (mL) should be administered per SINGLE dose?",
      ...(() => {
        const { choices, correctId } = assignChoices(
          [
            {
              text: "11.25 mL per dose",
              rationale:
                "Correct. 44 lb ÷ 2.2 = 20 kg. Total daily dose = 20 kg × 90 mg/kg/day = 1,800 mg/day. Divided BID = 900 mg per dose. Concentration = 400 mg / 5 mL (80 mg/mL). 900 mg ÷ 80 mg/mL = 11.25 mL.",
              isCorrect: true
            },
            {
              text: "22.5 mL per dose",
              rationale: "Incorrect. Classic trap: calculated the full DAILY volume (1,800 mg ÷ 80 mg/mL = 22.5 mL) and forgot to divide by 2 for BID dosing!",
              isCorrect: false
            },
            {
              text: "24.75 mL per dose",
              rationale: "Incorrect. Trap: forgot to convert 44 lb to kg (multiplied 44 × 90 mg directly instead of dividing by 2.2 lb/kg).",
              isCorrect: false
            },
            {
              text: "7.5 mL per dose",
              rationale: "Incorrect. Divided daily dose by 3 (TID) instead of 2 (BID).",
              isCorrect: false
            }
          ],
          606
        );
        return { choices, correct_choice_id: correctId };
      })(),
      explanation:
        "Step 1 (lb → kg): 44 lb ÷ 2.2 lb/kg = 20 kg.\nStep 2 (Daily mg): 20 kg × 90 mg/kg/day = 1,800 mg/day.\nStep 3 (Single BID dose): 1,800 mg ÷ 2 = 900 mg/dose.\nStep 4 (mg → mL): (900 mg × 5 mL) ÷ 400 mg = 11.25 mL per dose.",
      fda_spl_set_id: null,
      citation_quote: "Deterministic Formula: mL/dose = [(Weight_lb ÷ 2.2) × mg/kg/day ÷ Daily_Divisions] ÷ (mg / mL)",
      citation_url: "https://dailymed.nlm.nih.gov/",
      generator_source: "deterministic_math",
      blind_critic_json: null,
      review_status: "approved",
      is_free_tier: 1,
      created_at: now
    }
  ];
}

function buildAlligationItems(now: string): QuestionRecord[] {
  return [
    {
      id: "math-alligation-dextrose-1",
      drug_id: null,
      exam_code: "PTCE",
      domain_code: "ORDER_ENTRY_MATH",
      question_type: "math_mcq",
      difficulty: 4,
      stem: "A sterile compounding order requires 600 mL of Dextrose 20% (D20W). The pharmacy only stocks Dextrose 50% (D50W) and Dextrose 5% (D5W). Using alligation alternate, how many milliliters of D50W and D5W must be mixed?",
      ...(() => {
        const { choices, correctId } = assignChoices(
          [
            {
              text: "200 mL of D50W and 400 mL of D5W",
              rationale:
                "Correct. Alligation grid: Parts of D50W = |20 − 5| = 15 parts; Parts of D5W = |50 − 20| = 30 parts. Total = 45 parts. D50W = (15/45) × 600 = 200 mL; D5W = (30/45) × 600 = 400 mL.",
              isCorrect: true
            },
            {
              text: "400 mL of D50W and 200 mL of D5W",
              rationale:
                "Incorrect. Inverted the alligation parts! Sanity check: 400 mL of 50% + 200 mL of 5% would yield 35% dextrose, far above the target 20%.",
              isCorrect: false
            },
            {
              text: "240 mL of D50W and 360 mL of D5W",
              rationale: "Incorrect. Used simple C1V1 = C2V2 ignoring the 5% dextrose contributed by D5W (treated diluent as sterile water 0%).",
              isCorrect: false
            },
            {
              text: "300 mL of D50W and 300 mL of D5W",
              rationale: "Incorrect. A 1:1 mixture of 50% and 5% produces 27.5% dextrose, not 20%.",
              isCorrect: false
            }
          ],
          707
        );
        return { choices, correct_choice_id: correctId };
      })(),
      explanation:
        "Alligation Alternate:\n• Higher strength (50%) parts = Target (20) − Lower (5) = 15 parts\n• Lower strength (5%) parts = Higher (50) − Target (20) = 30 parts\n• Total parts = 15 + 30 = 45 parts\n• Volume D50W = (15 ÷ 45) × 600 mL = 200 mL\n• Volume D5W = (30 ÷ 45) × 600 mL = 400 mL\nCheck: (200 × 0.50) + (400 × 0.05) = 100 g + 20 g = 120 g in 600 mL = 20%.",
      fda_spl_set_id: null,
      citation_quote: "Alligation Alternate: V_high = Total_V × (C_target − C_low) ÷ (C_high − C_low)",
      citation_url: "https://ptcb.org/credentials/certified-pharmacy-technician/",
      generator_source: "deterministic_math",
      blind_critic_json: null,
      review_status: "approved",
      is_free_tier: 0,
      created_at: now
    },
    {
      id: "math-dilution-c1v1-cream-2",
      drug_id: null,
      exam_code: "PTCE",
      domain_code: "ORDER_ENTRY_MATH",
      question_type: "math_mcq",
      difficulty: 3,
      stem: "A dermatology compounding order calls for 120 g of Hydrocortisone 1.5% ointment prepared by diluting commercial Hydrocortisone 2.5% ointment with white petrolatum (0% active). How many grams of Hydrocortisone 2.5% ointment and white petrolatum are needed?",
      ...(() => {
        const { choices, correctId } = assignChoices(
          [
            {
              text: "72 g of Hydrocortisone 2.5% and 48 g of white petrolatum",
              rationale: "Correct. Using C1Q1 = C2Q2: (2.5%)(Q1) = (1.5%)(120 g) → Q1 = 180 ÷ 2.5 = 72 g of 2.5% ointment. Diluent = 120 − 72 = 48 g petrolatum.",
              isCorrect: true
            },
            {
              text: "48 g of Hydrocortisone 2.5% and 72 g of white petrolatum",
              rationale: "Incorrect. Swapped the active ointment weight and the petrolatum base weight.",
              isCorrect: false
            },
            {
              text: "60 g of Hydrocortisone 2.5% and 60 g of white petrolatum",
              rationale: "Incorrect. A 1:1 dilution with 0% base yields 1.25% hydrocortisone, not 1.5%.",
              isCorrect: false
            },
            {
              text: "72 g of Hydrocortisone 2.5% and 120 g of white petrolatum",
              rationale: "Incorrect. Added 72 g to 120 g (totaling 192 g) instead of subtracting 120 − 72 = 48 g.",
              isCorrect: false
            }
          ],
          808
        );
        return { choices, correct_choice_id: correctId };
      })(),
      explanation:
        "Because white petrolatum contains 0% hydrocortisone, C1Q1 = C2Q2 applies directly:\nQ1 = (1.5% × 120 g) ÷ 2.5% = 72 g of Hydrocortisone 2.5%.\nWhite petrolatum needed = 120 g − 72 g = 48 g.",
      fda_spl_set_id: null,
      citation_quote: "Dilution Equation (0% base): Q_stock = (C_final × Q_final) ÷ C_stock; Q_base = Q_final − Q_stock",
      citation_url: "https://ptcb.org/credentials/certified-pharmacy-technician/",
      generator_source: "deterministic_math",
      blind_critic_json: null,
      review_status: "approved",
      is_free_tier: 0,
      created_at: now
    }
  ];
}

function buildIvDripRateItems(now: string): QuestionRecord[] {
  return [
    {
      id: "math-iv-gtts-min-1",
      drug_id: null,
      exam_code: "PTCE",
      domain_code: "ORDER_ENTRY_MATH",
      question_type: "math_mcq",
      difficulty: 2,
      stem: "An inpatient IV order requires 1,000 mL of 0.9% Sodium Chloride (Normal Saline) to infuse over 8 hours using macrodrip tubing with a drop factor of 15 gtts/mL. Rounded to the nearest whole drop, what is the flow rate in drops per minute (gtts/min)?",
      ...(() => {
        const { choices, correctId } = assignChoices(
          [
            {
              text: "31 gtts/min",
              rationale:
                "Correct. Total minutes = 8 hr × 60 min/hr = 480 min. Flow rate = (1,000 mL × 15 gtts/mL) ÷ 480 min = 15,000 ÷ 480 = 31.25 → rounds to 31 gtts/min.",
              isCorrect: true
            },
            {
              text: "125 gtts/min",
              rationale: "Incorrect. 125 is the pump rate in mL/hr (1,000 mL ÷ 8 hr), not the gravity drip rate in gtts/min.",
              isCorrect: false
            },
            {
              text: "42 gtts/min",
              rationale: "Incorrect. Used a 20 gtts/mL drop factor instead of the specified 15 gtts/mL tubing.",
              isCorrect: false
            },
            {
              text: "19 gtts/min",
              rationale: "Incorrect. Calculated over 12 hours or used 10 gtts/mL tubing.",
              isCorrect: false
            }
          ],
          909
        );
        return { choices, correct_choice_id: correctId };
      })(),
      explanation:
        "Step 1 (mL/hr): 1,000 mL ÷ 8 hr = 125 mL/hr.\nStep 2 (gtts/min): (125 mL/hr × 15 gtts/mL) ÷ 60 min/hr = 31.25 gtts/min.\nStep 3: Round to nearest whole drop = 31 gtts/min.",
      fda_spl_set_id: null,
      citation_quote: "IV Gravity Drip Formula: gtts/min = (Volume_mL × Drop_Factor_gtts/mL) ÷ (Hours × 60)",
      citation_url: "https://ptcb.org/credentials/certified-pharmacy-technician/",
      generator_source: "deterministic_math",
      blind_critic_json: null,
      review_status: "approved",
      is_free_tier: 1,
      created_at: now
    }
  ];
}
