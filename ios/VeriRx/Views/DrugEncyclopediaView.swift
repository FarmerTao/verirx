import SwiftUI
import StoreKit

struct DrugEncyclopediaView: View {
    var studyStore: StudyStore
    @State private var mode: Int = 0
    @State private var query: String = ""

    private var filteredDrugs: [DrugItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return studyStore.drugs
        }
        let q = query.lowercased()
        return studyStore.drugs.filter {
            $0.genericName.lowercased().contains(q)
                || $0.brandNames.joined(separator: " ").lowercased().contains(q)
                || $0.drugClass.lowercased().contains(q)
                || $0.deaSchedule.lowercased().contains(q)
        }
    }

    private var filteredStems: [DrugStemItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return studyStore.drugStems
        }
        let q = query.lowercased()
        return studyStore.drugStems.filter {
            $0.stem.lowercased().contains(q)
                || $0.drugClass.lowercased().contains(q)
                || $0.exampleDrugs.joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Reference Mode", selection: $mode) {
                Text("Drug Stems (-pril, -statin)").tag(0)
                Text("Top Drugs (FDA SPL)").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if mode == 0 {
                List(filteredStems) { stem in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(stem.stem)
                                .font(.title3.bold().monospaced())
                                .foregroundStyle(.teal)
                            Spacer()
                            Text(stem.drugClass)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.teal.opacity(0.14), in: Capsule())
                        }
                        Text("Examples: \(stem.exampleDrugs.joined(separator: ", "))")
                            .font(.subheadline.weight(.medium))
                        Text(stem.clinicalPearl)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("⚠️ \(stem.trapNote)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                List(filteredDrugs) { drug in
                    NavigationLink {
                        DrugDetailView(drug: drug)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(drug.tallManName ?? drug.genericName)
                                    .font(.headline)
                                if drug.isHighAlert {
                                    badge("HIGH-ALERT", color: .red)
                                }
                                if drug.deaSchedule != "Rx" && drug.deaSchedule != "OTC" {
                                    badge(drug.deaSchedule, color: .purple)
                                }
                                if let rems = drug.remsProgram {
                                    badge(rems, color: .orange)
                                }
                            }
                            Text("\(drug.brandNames.joined(separator: ", ")) · \(drug.drugClass)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search stems (-statin), brands, or C-II…")
        .navigationTitle("Pharm Codex")
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}

struct DrugDetailView: View {
    let drug: DrugItem

    var body: some View {
        List {
            Section("Classification & Regulatory") {
                LabeledContent("Brand Name(s)", value: drug.brandNames.joined(separator: ", "))
                LabeledContent("Therapeutic Class", value: drug.drugClass)
                LabeledContent("DEA Schedule", value: drug.deaSchedule)
                if let tallMan = drug.tallManName {
                    LabeledContent("ISMP Tall Man", value: tallMan)
                }
                if let rems = drug.remsProgram {
                    LabeledContent("FDA REMS Program", value: rems)
                }
            }

            if let boxed = drug.boxedWarning {
                Section("FDA Boxed Warning") {
                    Text(boxed)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Clinical & Exam High-Yields") {
                row("Indications", drug.indicationsSummary)
                row("Mechanism of Action", drug.mechanismSummary)
                row("Key Adverse Effects", drug.keyAdverseEffects)
                row("Critical Interactions", drug.keyInteractions)
                row("Storage & Handling", drug.storageHandling)
            }

            Section("Official FDA Verification") {
                LabeledContent("FDA SPL Set ID", value: String(drug.fdaSplSetId.prefix(13)) + "…")
                if let url = URL(string: drug.dailymedUrl) {
                    Link("Open Full FDA Package Insert on DailyMed ↗", destination: url)
                }
            }
        }
        .navigationTitle(drug.genericName)
    }

    private func row(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            Text(detail).font(.subheadline)
        }
        .padding(.vertical, 2)
    }
}

struct ReadinessProfileView: View {
    @Bindable var studyStore: StudyStore
    var storeKit: StoreKitManager
    var onOpenPaywall: () -> Void

    var body: some View {
        List {
            Section("Streak & Exam Readiness") {
                LabeledContent("Current Streak", value: "\(studyStore.streakDays) Days 🔥")
                LabeledContent("Total XP", value: "\(studyStore.totalXP) XP ⚡")
                LabeledContent("Estimated PTCE Score", value: "\(studyStore.readinessScore) / 1600")
                DatePicker("Target Exam Date", selection: $studyStore.examDate, in: Date()..., displayedComponents: .date)
            }

            Section("Domain Mastery (CAT Theta)") {
                ForEach(studyStore.currentExam?.domains ?? []) { domain in
                    let theta = studyStore.adaptiveEngine.domainTheta(
                        domainCode: domain.code,
                        attempts: studyStore.attempts
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(domain.name).font(.subheadline.weight(.medium))
                            Spacer()
                            Text(String(format: "%.1f / 5.0", theta))
                                .font(.caption.bold())
                                .foregroundStyle(.teal)
                        }
                        ProgressView(value: theta, total: 5.0)
                            .tint(theta >= 3.5 ? .green : .teal)
                    }
                    .padding(.vertical, 4)
                }
            }

            // Ethical Free-App Monetization Slot: PTCB-Recognized Course & CPhT Hiring Partners
            Section("Next Steps to Get Certified & Hired") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Need Your PTCB-Recognized Training Certificate?")
                        .font(.subheadline.bold())
                    Text("Compare accredited online CPhT prerequisite programs to unlock exam eligibility.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hospital & Retail Pharmacy Hiring Board")
                        .font(.subheadline.bold())
                    Text("Readiness 1400+ unlocks direct CPhT job matches with sign-on bonuses.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }

            Section("Optional Exam Cram Pass") {
                Button("Support VeriRx / Unlock Mock Exam Pack", action: onOpenPaywall)
                Button("Restore Purchases") {
                    Task { await storeKit.restorePurchases(studyStore: studyStore) }
                }
            }

            Section("Legal & Trademark Disclaimers") {
                Text("Educational Use Only: VeriRx does not provide medical advice, clinical decision support, or patient dosing recommendations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let tm = studyStore.currentExam?.trademarkDisclaimer {
                    Text(tm)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Career & Readiness")
    }
}

struct PaywallSheetView: View {
    var studyStore: StudyStore
    var storeKit: StoreKitManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.yellow)
                        .padding(.top, 12)

                    Text("VeriRx Super (Optional)")
                        .font(.title2.bold())

                    Text("All daily path lessons are 100% free! Upgrade only if you want unlimited Streak Freezes, ad-free mode, and full 90-question timed mock exams.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    ForEach(storeKit.products, id: \.id) { product in
                        Button {
                            Task {
                                await storeKit.purchase(product, studyStore: studyStore)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.displayName).font(.headline)
                                    Text(product.description).font(.caption).opacity(0.85)
                                }
                                Spacer()
                                Text(product.displayPrice).font(.headline.bold())
                            }
                            .padding()
                            .background(.teal, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                        }
                    }

                    Button("Restore Purchases") {
                        Task { await storeKit.restorePurchases(studyStore: studyStore) }
                    }
                    .font(.footnote.weight(.medium))

                    if let tm = studyStore.currentExam?.trademarkDisclaimer {
                        Text(tm)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("VeriRx Super")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
