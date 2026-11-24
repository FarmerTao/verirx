import SwiftUI
import StoreKit

struct DrugEncyclopediaView: View {
    var studyStore: StudyStore
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

    var body: some View {
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
        .searchable(text: $query, prompt: "Search generic, brand, class, or C-II…")
        .navigationTitle("Top Drugs (FDA SPL)")
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
            Section("Exam Track & Schedule") {
                Picker("Exam Track", selection: $studyStore.selectedExamCode) {
                    ForEach(studyStore.exams.filter(\.isActive)) { exam in
                        Text(exam.displayName).tag(exam.examCode)
                    }
                }
                DatePicker("Target Exam Date", selection: $studyStore.examDate, in: Date()..., displayedComponents: .date)
                LabeledContent("Estimated Scaled Score", value: "\(studyStore.readinessScore) / 1600")
                LabeledContent("Questions Answered", value: "\(studyStore.attempts.count)")
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

            Section("Membership") {
                if studyStore.isProUnlocked {
                    Label("VeriRx Pro Unlocked", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Upgrade to VeriRx Pro", action: onOpenPaywall)
                }
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
        .navigationTitle("Readiness")
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
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.teal)
                        .padding(.top, 12)

                    Text("Pass Your Exam Without Paying $400+")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 10) {
                        Label("All Top 200 Drug FSRS Flashcards with FDA SPL Links", systemImage: "checkmark.circle.fill")
                        Label("Unlimited Pharmacy Math & Alligation Drills", systemImage: "checkmark.circle.fill")
                        Label("Full Computerized Adaptive (CAT) Readiness Simulator", systemImage: "checkmark.circle.fill")
                        Label("100% Offline Access — Study Anywhere", systemImage: "checkmark.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    ForEach(storeKit.products, id: \.id) { product in
                        Button {
                            Task {
                                await storeKit.purchase(product, studyStore: studyStore)
                                if studyStore.isProUnlocked { dismiss() }
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

                    if let err = storeKit.errorMessage {
                        Text(err).font(.caption).foregroundStyle(.red)
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
            .navigationTitle("VeriRx Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
