import type { StagingDatabase } from "../db.js";

export interface DrugStemSeed {
  id: string;
  stem: string;
  position: "suffix" | "prefix" | "infix";
  drug_class: string;
  clinical_pearl: string;
  example_drugs: string[];
  trap_note: string;
}

export interface SigDrillSeed {
  id: string;
  rx_shorthand: string;
  correct_tokens: string[];
  distractor_tokens: string[];
  clinical_tip: string;
}

export interface SkillUnitSeed {
  id: string;
  exam_code: "PTCE";
  unit_order: number;
  title: string;
  subtitle: string;
  theme_color: string;
  icon_name: string;
  focus_type: string;
  drug_ids: string[];
}

export const DRUG_STEMS_SEED: DrugStemSeed[] = [
  {
    id: "stem-statin",
    stem: "-statin",
    position: "suffix",
    drug_class: "HMG-CoA Reductase Inhibitor",
    clinical_pearl: "Lowers LDL cholesterol; monitor for unexplained muscle pain (myopathy/rhabdomyolysis) and liver enzymes.",
    example_drugs: ["Atorvastatin", "Rosuvastatin", "Simvastatin"],
    trap_note: "Do not confuse with Nystatin (polyene antifungal, NOT a cholesterol statin!)."
  },
  {
    id: "stem-pril",
    stem: "-pril",
    position: "suffix",
    drug_class: "ACE Inhibitor",
    clinical_pearl: "Treats HTN & heart failure; classic dry cough, hyperkalemia, angioedema, and fetal toxicity.",
    example_drugs: ["Lisinopril", "Enalapril", "Ramipril"],
    trap_note: "Requires 36-hour washout before/after sacubitril/valsartan (Entresto)."
  },
  {
    id: "stem-sartan",
    stem: "-sartan",
    position: "suffix",
    drug_class: "Angiotensin II Receptor Blocker (ARB)",
    clinical_pearl: "Alternative to ACE inhibitors with much lower incidence of dry cough; still causes hyperkalemia & fetal harm.",
    example_drugs: ["Losartan", "Valsartan", "Irbesartan"],
    trap_note: "Never combine an ARB (-sartan) with an ACE inhibitor (-pril)."
  },
  {
    id: "stem-olol",
    stem: "-olol",
    position: "suffix",
    drug_class: "Beta-Adrenergic Blocker",
    clinical_pearl: "Slows heart rate and lowers BP; can mask tachycardia signs of hypoglycemia in diabetics.",
    example_drugs: ["Metoprolol", "Atenolol", "Propranolol"],
    trap_note: "Cardioselective beta-1 blockers: A-M (Atenolol, Metoprolol); non-selective N-Z (Propranolol) can trigger bronchospasm."
  },
  {
    id: "stem-dipine",
    stem: "-dipine",
    position: "suffix",
    drug_class: "Dihydropyridine Calcium Channel Blocker",
    clinical_pearl: "Potent arterial vasodilator for HTN/angina; hallmark side effect is peripheral ankle edema.",
    example_drugs: ["Amlodipine", "Nifedipine", "Felodipine"],
    trap_note: "Non-dihydropyridines (verapamil, diltiazem) lack '-dipine' and slow AV node heart rate."
  },
  {
    id: "stem-prazole",
    stem: "-prazole",
    position: "suffix",
    drug_class: "Proton Pump Inhibitor (PPI)",
    clinical_pearl: "Irreversibly blocks gastric H+/K+ ATPase; take 30–60 minutes BEFORE breakfast.",
    example_drugs: ["Omeprazole", "Pantoprazole", "Esomeprazole"],
    trap_note: "TRAP: Aripiprazole & Brexpiprazole end in '-piprazole' and are atypical antipsychotics, NOT PPIs!"
  },
  {
    id: "stem-zolam-zepam",
    stem: "-zolam / -zepam",
    position: "suffix",
    drug_class: "Benzodiazepine (DEA Schedule IV)",
    clinical_pearl: "Enhances GABA-A inhibition for anxiety/seizures; FDA Boxed Warning with opioids for fatal respiratory depression.",
    example_drugs: ["Alprazolam", "Lorazepam", "Clonazepam"],
    trap_note: "Clozapine & Olanzapine look vaguely similar but are antipsychotics, not Schedule IV benzodiazepines."
  },
  {
    id: "stem-aban",
    stem: "-aban",
    position: "suffix",
    drug_class: "Direct Factor Xa Inhibitor (DOAC)",
    clinical_pearl: "Oral anticoagulant (X-a-ban = inhibits Factor Xa); no routine INR monitoring required.",
    example_drugs: ["Apixaban", "Rivaroxaban", "Edoxaban"],
    trap_note: "Dabigatran (-gatran) is a direct thrombin (IIa) inhibitor, whereas -aban targets Factor Xa."
  },
  {
    id: "stem-oxacin",
    stem: "-oxacin",
    position: "suffix",
    drug_class: "Fluoroquinolone Antibiotic",
    clinical_pearl: "Inhibits bacterial DNA gyrase; FDA Boxed Warning for tendonitis/tendon rupture and peripheral neuropathy.",
    example_drugs: ["Ciprofloxacin", "Levofloxacin", "Moxifloxacin"],
    trap_note: "Chelated by calcium, iron, antacids, and dairy—separate oral doses!"
  },
  {
    id: "stem-gliflozin",
    stem: "-gliflozin",
    position: "suffix",
    drug_class: "SGLT2 Inhibitor",
    clinical_pearl: "Blocks renal glucose reabsorption in T2DM, heart failure & CKD; increases genital mycotic infections and euglycemic DKA risk.",
    example_drugs: ["Empagliflozin", "Dapagliflozin", "Canagliflozin"],
    trap_note: "Distinct from '-gliptin' (DPP-4 inhibitors like sitagliptin)."
  }
];

export const SIG_DRILLS_SEED: SigDrillSeed[] = [
  {
    id: "sig-ou-bid",
    rx_shorthand: "ii gtts OU BID",
    correct_tokens: ["Instill", "2 drops", "in both eyes", "twice daily"],
    distractor_tokens: ["in both ears", "1 drop", "right eye", "at bedtime"],
    clinical_tip: "O = Ocular (eyes): OD = right eye, OS = left eye, OU = both eyes. Never confuse with AD/AS/AU (ears)!"
  },
  {
    id: "sig-ad-tid",
    rx_shorthand: "iii gtts AD TID x 7d",
    correct_tokens: ["Instill", "3 drops", "in the right ear", "three times daily", "for 7 days"],
    distractor_tokens: ["in the right eye", "left ear", "twice daily", "by mouth"],
    clinical_tip: "A = Auris (ear): AD = right ear, AS = left ear, AU = both ears. Ear drops must NEVER be placed in the eyes."
  },
  {
    id: "sig-po-bid-pc",
    rx_shorthand: "ii tabs PO BID pc",
    correct_tokens: ["Take", "2 tablets", "by mouth", "twice daily", "after meals"],
    distractor_tokens: ["before meals", "at bedtime", "1 tablet", "under the tongue"],
    clinical_tip: "'ac' (ante cibum) = before meals; 'pc' (post cibum) = after meals (helpful for GI-irritating drugs like metformin)."
  },
  {
    id: "sig-qhs-prn",
    rx_shorthand: "i cap PO QHS PRN insomnia",
    correct_tokens: ["Take", "1 capsule", "by mouth", "every night at bedtime", "as needed for", "insomnia"],
    distractor_tokens: ["every hour", "every morning", "2 capsules", "with meals"],
    clinical_tip: "QHS = quaque hora somni (every night at bedtime); PRN = pro re nata (as needed)."
  },
  {
    id: "sig-q6h-ac",
    rx_shorthand: "15 mL PO q6h ac",
    correct_tokens: ["Take", "1 tablespoonful (15 mL)", "by mouth", "every 6 hours", "before meals"],
    distractor_tokens: ["1 teaspoonful (5 mL)", "after meals", "4 times a year", "every 4 hours"],
    clinical_tip: "5 mL = 1 tsp; 15 mL = 1 tbsp. Always dispense oral liquids with metric mL dosing syringes/cups."
  },
  {
    id: "sig-inh-sob",
    rx_shorthand: "ii puffs INH q4-6h PRN SOB",
    correct_tokens: ["Inhale", "2 puffs", "by mouth", "every 4 to 6 hours", "as needed for", "shortness of breath"],
    distractor_tokens: ["swallow", "twice daily", "every 4 days", "chest pain"],
    clinical_tip: "Standard rescue bronchodilator (albuterol HFA) Sig; SOB = shortness of breath."
  },
  {
    id: "sig-sl-nitro",
    rx_shorthand: "i tab SL q5min x 3 PRN chest pain",
    correct_tokens: ["Place", "1 tablet", "under the tongue", "every 5 minutes", "up to 3 doses", "as needed for chest pain"],
    distractor_tokens: ["swallow whole", "every 5 hours", "after meals", "chew"],
    clinical_tip: "Classic nitroglycerin (Nitrostat) sublingual instruction; call 911 if pain persists 5 minutes after the first dose."
  },
  {
    id: "sig-ss-qd",
    rx_shorthand: "ss tab PO QD am",
    correct_tokens: ["Take", "one-half tablet", "by mouth", "once daily", "in the morning"],
    distractor_tokens: ["2 tablets", "every other day", "at bedtime", "under the tongue"],
    clinical_tip: "Apothecary 'ss' (semis) means one-half (1/2)—an ISMP error-prone abbreviation tested on PTCE!"
  }
];

export const SKILL_UNITS_SEED: SkillUnitSeed[] = [
  {
    id: "unit-1-stems",
    exam_code: "PTCE",
    unit_order: 1,
    title: "Unit 1 · Drug Stem Decoder",
    subtitle: "Crack 100+ generic names instantly with -statin, -pril, -olol & -aban roots",
    theme_color: "teal",
    icon_name: "puzzlepiece.extension.fill",
    focus_type: "stems",
    drug_ids: ["atorvastatin", "lisinopril", "apixaban", "alprazolam"]
  },
  {
    id: "unit-2-sig",
    exam_code: "PTCE",
    unit_order: 2,
    title: "Unit 2 · Prescription Sig Translator",
    subtitle: "Build English directions from pharmacy shorthand (OU vs AU, ac vs pc, q6h, ss)",
    theme_color: "indigo",
    icon_name: "text.word.spacing",
    focus_type: "sig_codes",
    drug_ids: ["amoxicillin", "metformin", "levothyroxine"]
  },
  {
    id: "unit-3-chronic",
    exam_code: "PTCE",
    unit_order: 3,
    title: "Unit 3 · Cardio & Metabolic Core",
    subtitle: "Brand ↔ Generic speed match & chelation/CYP interactions",
    theme_color: "emerald",
    icon_name: "heart.text.square.fill",
    focus_type: "drugs_cardio",
    drug_ids: ["atorvastatin", "lisinopril", "metformin", "levothyroxine", "hydralazine"]
  },
  {
    id: "unit-4-high-alert",
    exam_code: "PTCE",
    unit_order: 4,
    title: "Unit 4 · High-Alert & LASA Safety",
    subtitle: "ISMP Tall Man Lettering, Warfarin INR alerts & Basal Insulin storage",
    theme_color: "rose",
    icon_name: "exclamationmark.shield.fill",
    focus_type: "high_alert",
    drug_ids: ["warfarin", "apixaban", "insulin_glargine", "hydralazine"]
  },
  {
    id: "unit-5-law",
    exam_code: "PTCE",
    unit_order: 5,
    title: "Unit 5 · DEA Schedules & REMS Vault",
    subtitle: "C-II zero-refill rules, C-IV limits & iPLEDGE 30-day lockout",
    theme_color: "purple",
    icon_name: "lock.doc.fill",
    focus_type: "law_rems",
    drug_ids: ["oxycodone", "alprazolam", "isotretinoin"]
  },
  {
    id: "unit-6-math",
    exam_code: "PTCE",
    unit_order: 6,
    title: "Unit 6 · Pharmacy Math Arena",
    subtitle: "Taper days' supply, insulin priming, mg/kg dosing, alligation & IV gtts/min",
    theme_color: "orange",
    icon_name: "function",
    focus_type: "math",
    drug_ids: ["amoxicillin", "insulin_glargine", "metformin"]
  }
];

export function seedDuolingoCurriculum(staging: StagingDatabase): {
  stems: number;
  sigDrills: number;
  units: number;
} {
  const stemStmt = staging.db.prepare(`
    INSERT INTO drug_stems (id, stem, position, drug_class, clinical_pearl, example_drugs_json, trap_note)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      stem = excluded.stem,
      drug_class = excluded.drug_class,
      clinical_pearl = excluded.clinical_pearl,
      example_drugs_json = excluded.example_drugs_json,
      trap_note = excluded.trap_note
  `);

  for (const s of DRUG_STEMS_SEED) {
    stemStmt.run(
      s.id,
      s.stem,
      s.position,
      s.drug_class,
      s.clinical_pearl,
      JSON.stringify(s.example_drugs),
      s.trap_note
    );
  }

  const sigStmt = staging.db.prepare(`
    INSERT INTO sig_drills (id, rx_shorthand, correct_tokens_json, distractor_tokens_json, clinical_tip)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      rx_shorthand = excluded.rx_shorthand,
      correct_tokens_json = excluded.correct_tokens_json,
      distractor_tokens_json = excluded.distractor_tokens_json,
      clinical_tip = excluded.clinical_tip
  `);

  for (const d of SIG_DRILLS_SEED) {
    sigStmt.run(
      d.id,
      d.rx_shorthand,
      JSON.stringify(d.correct_tokens),
      JSON.stringify(d.distractor_tokens),
      d.clinical_tip
    );
  }

  const unitStmt = staging.db.prepare(`
    INSERT INTO skill_units (id, exam_code, unit_order, title, subtitle, theme_color, icon_name, focus_type, drug_ids_json)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      unit_order = excluded.unit_order,
      title = excluded.title,
      subtitle = excluded.subtitle,
      theme_color = excluded.theme_color,
      icon_name = excluded.icon_name,
      focus_type = excluded.focus_type,
      drug_ids_json = excluded.drug_ids_json
  `);

  for (const u of SKILL_UNITS_SEED) {
    unitStmt.run(
      u.id,
      u.exam_code,
      u.unit_order,
      u.title,
      u.subtitle,
      u.theme_color,
      u.icon_name,
      u.focus_type,
      JSON.stringify(u.drug_ids)
    );
  }

  // Unlock all items for Free-to-Learn Duolingo progression
  staging.db.exec("UPDATE flashcards SET is_free_tier = 1;");
  staging.db.exec("UPDATE questions SET is_free_tier = 1;");

  return {
    stems: DRUG_STEMS_SEED.length,
    sigDrills: SIG_DRILLS_SEED.length,
    units: SKILL_UNITS_SEED.length
  };
}
