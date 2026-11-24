# VeriRx + RxForge

**Zero-Hallucination Pharmacology & Pharmacy Math Exam Prep**  
- **Backend (`rxforge/`)**: Offline Multi-Agent Question Factory built on `@mariozechner/pi-ai`, `@mariozechner/pi-agent-core`, and Node 22 `node:sqlite`. Anchors every drug card and clinical vignette to US Public Domain **openFDA / DailyMed SPL** labels and passes drafts through an independent **Blind Critic** model before human sign-off.
- **Frontend (`ios/`)**: 100% offline-first native **SwiftUI** iOS app (`VeriRx`) featuring **FSRS v5** spaced repetition with Exam-Date Cram Pacing, **CAT / IRT Adaptive Readiness Simulator**, **StoreKit 2** monetization, and zero runtime LLM API cost.

---

## Quick Start

### 1. Build / Update Offline Content Pack (`rxforge/`)

```bash
cd rxforge
npm install

# Pull live openFDA SPL drug labels + generate deterministic pharmacy math + export SQLite pack
npm run seed:all
```

### 2. Generate New AI Vignette Questions with Pi Multi-Agent Pipeline

Copy `.env.example` to `.env` and add your API key (`OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, or `GEMINI_API_KEY`):

```bash
cp .env.example .env
# Generate & Blind-Critic-verify PTCE questions
npm run gen:ai PTCE PATIENT_SAFETY

# Launch 10-second Founder Final Review Console at http://localhost:4321
npm run review

# Export approved items into ios/VeriRx/Resources/verirx_pack.sqlite
npm run export:pack
```

### 3. Open Native SwiftUI App in Xcode (macOS)

```bash
./scripts/open_on_mac.sh
```
Select an iPhone Simulator in Xcode (the `VeriRx` scheme automatically attaches `VeriRx.storekit` for testing StoreKit 2 subscriptions and lifetime unlock locally) and press `Cmd + R`.
