export interface SeedDrugSpec {
  id: string;
  generic_name: string;
  fda_query_generic: string;
  brand_names: string[];
  tall_man_name: string | null;
  drug_class: string;
  dea_schedule: "Rx" | "OTC" | "C-II" | "C-III" | "C-IV" | "C-V";
  rems_program: string | null;
  high_alert_flag: 0 | 1;
  concise_indication: string;
  concise_moa: string;
  concise_adverse: string;
  concise_interactions: string;
  concise_storage: string;
  is_free_tier: 0 | 1;
}

/**
 * Starter High-Yield PTCB Top Drugs seed catalog.
 * Expandable to all Top 200 Drugs; live openFDA SPL set_id and label text
 * are fetched automatically by `openfda.ts` and merged at ingest time.
 */
export const TOP_DRUGS_SEED: SeedDrugSpec[] = [
  {
    id: "atorvastatin",
    generic_name: "Atorvastatin",
    fda_query_generic: "atorvastatin calcium",
    brand_names: ["Lipitor"],
    tall_man_name: null,
    drug_class: "HMG-CoA Reductase Inhibitor (Statin)",
    dea_schedule: "Rx",
    rems_program: null,
    high_alert_flag: 0,
    concise_indication: "Hyperlipidemia and primary/secondary ASCVD risk reduction",
    concise_moa: "Competitively inhibits HMG-CoA reductase, the rate-limiting enzyme in hepatic cholesterol synthesis",
    concise_adverse: "Myalgia, elevated hepatic transaminases, rare rhabdomyolysis",
    concise_interactions: "Strong CYP3A4 inhibitors (clarithromycin, itraconazole), cyclosporine, gemfibrozil, large quantities of grapefruit juice",
    concise_storage: "Store at controlled room temperature 20°C–25°C (68°F–77°F)",
    is_free_tier: 1
  },
  {
    id: "lisinopril",
    generic_name: "Lisinopril",
    fda_query_generic: "lisinopril",
    brand_names: ["Prinivil", "Zestril"],
    tall_man_name: null,
    drug_class: "ACE Inhibitor",
    dea_schedule: "Rx",
    rems_program: null,
    high_alert_flag: 0,
    concise_indication: "Hypertension, heart failure with reduced ejection fraction, post-acute MI",
    concise_moa: "Inhibits angiotensin-converting enzyme, blocking conversion of angiotensin I to angiotensin II and decreasing bradykinin breakdown",
    concise_adverse: "Dry persistent cough, hyperkalemia, hypotension, life-threatening angioedema; fetal toxicity in pregnancy",
    concise_interactions: "Sacubitril/valsartan (36-hour washout required), potassium-sparing diuretics, NSAIDs, lithium",
    concise_storage: "Store at 20°C–25°C; protect from moisture",
    is_free_tier: 1
  },
  {
    id: "warfarin",
    generic_name: "Warfarin",
    fda_query_generic: "warfarin sodium",
    brand_names: ["Coumadin", "Jantoven"],
    tall_man_name: null,
    drug_class: "Vitamin K Antagonist (Oral Anticoagulant)",
    dea_schedule: "Rx",
    rems_program: null,
    high_alert_flag: 1,
    concise_indication: "Prophylaxis and treatment of venous thrombosis, pulmonary embolism, and thromboembolism in atrial fibrillation/mechanical heart valves",
    concise_moa: "Inhibits vitamin K epoxide reductase (VKORC1), depleting reduced vitamin K needed for clotting factors II, VII, IX, X and proteins C/S",
    concise_adverse: "Major or fatal hemorrhage, skin necrosis, purple toe syndrome; teratogenic",
    concise_interactions: "CYP2C9 inhibitors (TMP-SMX, metronidazole, amiodarone, fluconazole markedly raise INR); consistent dietary vitamin K intake required",
    concise_storage: "Store at 20°C–25°C; protect from light; note standardized tablet strength color coding",
    is_free_tier: 1
  },
  {
    id: "metformin",
    generic_name: "Metformin",
    fda_query_generic: "metformin hydrochloride",
    brand_names: ["Glucophage", "Glumetza"],
    tall_man_name: "metFORMIN",
    drug_class: "Biguanide Antidiabetic",
    dea_schedule: "Rx",
    rems_program: null,
    high_alert_flag: 1,
    concise_indication: "First-line glycemic management in type 2 diabetes mellitus",
    concise_moa: "Decreases hepatic gluconeogenesis, reduces intestinal glucose absorption, and improves peripheral insulin sensitivity via AMPK activation",
    concise_adverse: "GI upset (diarrhea, nausea), vitamin B12 deficiency, rare metformin-associated lactic acidosis (MALA)",
    concise_interactions: "Iodinated contrast media (hold prior/at procedure when eGFR 30–60 mL/min/1.73m² or liver/heart failure), carbonic anhydrase inhibitors, excess alcohol",
    concise_storage: "Store at 20°C–25°C in tight, light-resistant containers",
    is_free_tier: 1
  },
  {
    id: "levothyroxine",
    generic_name: "Levothyroxine",
    fda_query_generic: "levothyroxine sodium",
    brand_names: ["Synthroid", "Levoxyl", "Unithroid"],
    tall_man_name: null,
    drug_class: "Thyroid Hormone Replacement (T4)",
    dea_schedule: "Rx",
    rems_program: null,
    high_alert_flag: 0,
    concise_indication: "Hypothyroidism and pituitary TSH suppression in thyroid cancer",
    concise_moa: "Synthetic L-thyroxine (T4) converted peripherally to active T3, binding nuclear thyroid receptors to regulate metabolic rate",
    concise_adverse: "Hyperthyroid symptoms if overdosed (tachycardia, arrhythmias, tremor, bone mineral loss); not for obesity/weight loss",
    concise_interactions: "Calcium carbonate, ferrous sulfate, antacids, sucralfate, bile acid sequestrants (separate administration by at least 4 hours)",
    concise_storage: "Store at 20°C–25°C; protect from light and moisture; Narrow Therapeutic Index (NTI) drug",
    is_free_tier: 1
  },
  {
    id: "oxycodone",
    generic_name: "Oxycodone",
    fda_query_generic: "oxycodone hydrochloride",
    brand_names: ["Roxicodone", "OxyContin"],
    tall_man_name: "oxyCODONE",
    drug_class: "Opioid Analgesic",
    dea_schedule: "C-II",
    rems_program: "Opioid Analgesic REMS",
    high_alert_flag: 1,
    concise_indication: "Management of pain severe enough to require an opioid analgesic when alternative treatments are inadequate",
    concise_moa: "Full mu-opioid receptor agonist in the CNS inhibiting ascending pain pathways",
    concise_adverse: "Addiction, abuse, fatal respiratory depression, severe constipation, sedation",
    concise_interactions: "Benzodiazepines and other CNS depressants (profound sedation/coma/death), CYP3A4 inhibitors (ketoconazole, macrolides)",
    concise_storage: "Locked C-II controlled substance storage; no refills permitted under federal law (21 CFR 1306.12)",
    is_free_tier: 0
  },
  {
    id: "alprazolam",
    generic_name: "Alprazolam",
    fda_query_generic: "alprazolam",
    brand_names: ["Xanax"],
    tall_man_name: "ALPRAZolam",
    drug_class: "Benzodiazepine",
    dea_schedule: "C-IV",
    rems_program: null,
    high_alert_flag: 0,
    concise_indication: "Generalized anxiety disorder (GAD) and panic disorder",
    concise_moa: "Positive allosteric modulator of GABA-A receptors increasing chloride channel opening frequency",
    concise_adverse: "CNS depression, physical dependence, life-threatening withdrawal seizures upon abrupt discontinuation",
    concise_interactions: "Opioids (boxed warning for fatal respiratory depression), strong CYP3A inhibitors (itraconazole, ketoconazole — contraindicated)",
    concise_storage: "C-IV controlled substance: maximum 5 refills within 6 months of issue date",
    is_free_tier: 0
  },
  {
    id: "isotretinoin",
    generic_name: "Isotretinoin",
    fda_query_generic: "isotretinoin",
    brand_names: ["Absorica", "Accutane", "Claravis"],
    tall_man_name: null,
    drug_class: "Systemic Retinoid",
    dea_schedule: "Rx",
    rems_program: "iPLEDGE REMS",
    high_alert_flag: 1,
    concise_indication: "Severe recalcitrant nodular acne unresponsive to conventional therapy including systemic antibiotics",
    concise_moa: "13-cis-retinoic acid isomer that shrinks sebaceous glands and inhibits sebum production and keratinization",
    concise_adverse: "Extreme teratogenicity (fetal malformations), hypertriglyceridemia, mucocutaneous dryness, hepatotoxicity, pseudotumor cerebri",
    concise_interactions: "Vitamin A supplements (additive toxicity), tetracyclines (doxycycline/minocycline — risk of pseudotumor cerebri/intracranial hypertension)",
    concise_storage: "Dispense only with active iPLEDGE REMS authorization, max 30-day supply, no automatic refills; protect from light",
    is_free_tier: 0
  },
  {
    id: "hydralazine",
    generic_name: "Hydralazine",
    fda_query_generic: "hydralazine hydrochloride",
    brand_names: ["Apresoline"],
    tall_man_name: "hydrALAZINE",
    drug_class: "Direct Arterial Vasodilator",
    dea_schedule: "Rx",
    rems_program: null,
    high_alert_flag: 0,
    concise_indication: "Essential hypertension and heart failure (often combined with isosorbide dinitrate)",
    concise_moa: "Directly relaxes arteriolar smooth muscle, lowering systemic vascular resistance",
    concise_adverse: "Reflex tachycardia, fluid retention, drug-induced lupus-like syndrome",
    concise_interactions: "Frequently confused Look-Alike/Sound-Alike (LASA) pair with hydrOXYzine (antihistamine/anxiolytic); additive hypotension with antihypertensives",
    concise_storage: "Store at 20°C–25°C; verify LASA Tall Man Lettering (hydrALAZINE vs hydrOXYzine) during order entry and filling",
    is_free_tier: 0
  },
  {
    id: "apixaban",
    generic_name: "Apixaban",
    fda_query_generic: "apixaban",
    brand_names: ["Eliquis"],
    tall_man_name: null,
    drug_class: "Direct Factor Xa Inhibitor (DOAC)",
    dea_schedule: "Rx",
    rems_program: null,
    high_alert_flag: 1,
    concise_indication: "Stroke/systemic embolism reduction in nonvalvular atrial fibrillation, DVT/PE treatment and prophylaxis",
    concise_moa: "Selectively and reversibly inhibits free and clot-bound Factor Xa without requiring antithrombin III",
    concise_adverse: "Serious bleeding; premature discontinuation increases thrombotic stroke risk; spinal/epidural hematoma with neuraxial anesthesia",
    concise_interactions: "Combined strong dual CYP3A4 and P-gp inhibitors (ketoconazole, ritonavir) or inducers (rifampin, carbamazepine, phenytoin, St. John's wort)",
    concise_storage: "Store at 20°C–25°C; dispense with FDA Medication Guide",
    is_free_tier: 0
  },
  {
    id: "amoxicillin",
    generic_name: "Amoxicillin",
    fda_query_generic: "amoxicillin",
    brand_names: ["Amoxil"],
    tall_man_name: null,
    drug_class: "Aminopenicillin Beta-Lactam Antibiotic",
    dea_schedule: "Rx",
    rems_program: null,
    high_alert_flag: 0,
    concise_indication: "Bacterial ear/nose/throat, lower respiratory, skin, urinary tract, and H. pylori infections",
    concise_moa: "Binds penicillin-binding proteins (PBPs) to inhibit bacterial peptidoglycan cell wall synthesis",
    concise_adverse: "Hypersensitivity/anaphylaxis (cross-reactivity consideration with beta-lactams), diarrhea, Clostridioides difficile colitis, ampicillin/amoxicillin rash in mononucleosis",
    concise_interactions: "Allopurinol (increased rash incidence), probenecid (prolongs amoxicillin levels), oral anticoagulants",
    concise_storage: "Reconstituted oral suspension: shake well, store in refrigerator preferred (though room temp stable per label), discard unused portion after 14 days",
    is_free_tier: 0
  },
  {
    id: "insulin_glargine",
    generic_name: "Insulin Glargine",
    fda_query_generic: "insulin glargine",
    brand_names: ["Lantus", "Basaglar", "Toujeo"],
    tall_man_name: "insulin glargine",
    drug_class: "Long-Acting Basal Insulin",
    dea_schedule: "Rx",
    rems_program: null,
    high_alert_flag: 1,
    concise_indication: "Glycemic control in adults and pediatric patients with type 1 and type 2 diabetes mellitus",
    concise_moa: "Forms microprecipitates in subcutaneous tissue releasing steady peakless basal insulin over ~24 hours",
    concise_adverse: "Hypoglycemia (life-threatening), hypokalemia, lipodystrophy at injection site, weight gain",
    concise_interactions: "Never dilute or mix with any other insulin or solution in the same syringe; beta-blockers may mask tachycardia symptoms of hypoglycemia",
    concise_storage: "Unopened vials/pens: refrigerate 2°C–8°C (36°F–46°F), do not freeze; in-use Lantus SoloStar pens: room temperature <30°C up to 28 days",
    is_free_tier: 0
  }
];
