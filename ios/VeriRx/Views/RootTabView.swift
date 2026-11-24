import SwiftUI

struct RootTabView: View {
    @Bindable var studyStore: StudyStore
    var storeKit: StoreKitManager
    @State private var showPaywall = false

    var body: some View {
        TabView {
            NavigationStack {
                SkillPathView(studyStore: studyStore)
            }
            .tabItem {
                Label("Path", systemImage: "map.fill")
            }

            NavigationStack {
                PracticeHubView(
                    studyStore: studyStore,
                    onOpenPaywall: { showPaywall = true }
                )
            }
            .tabItem {
                Label("Drills", systemImage: "dumbbell.fill")
            }

            NavigationStack {
                DrugEncyclopediaView(studyStore: studyStore)
            }
            .tabItem {
                Label("Codex", systemImage: "character.book.closed.fill")
            }

            NavigationStack {
                ReadinessProfileView(
                    studyStore: studyStore,
                    storeKit: storeKit,
                    onOpenPaywall: { showPaywall = true }
                )
            }
            .tabItem {
                Label("Career", systemImage: "flame.fill")
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheetView(studyStore: studyStore, storeKit: storeKit)
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { !studyStore.hasAcceptedDisclaimer },
                set: { if !$0 { studyStore.hasAcceptedDisclaimer = true } }
            )
        ) {
            OnboardingDisclaimerView(studyStore: studyStore)
        }
    }
}

struct OnboardingDisclaimerView: View {
    @Bindable var studyStore: StudyStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "flame.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.teal)

            Text("Welcome to VeriRx")
                .font(.largeTitle.bold())

            Text("Learn Pharmacology Like a Language.\nDecode drug stems, build Rx Sigs, and crush exam math in 5 minutes a day — 100% Free.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Label("FDA-Verified & Zero Hallucination: Every drug card and Boss rationale links directly to official FDA SPL labels.", systemImage: "checkmark.shield.fill")
                Label("Educational Use Only: Strictly for exam preparation; never use for clinical patient care or dosing decisions.", systemImage: "graduationcap.fill")
                if let disclaimer = studyStore.currentExam?.trademarkDisclaimer {
                    Text(disclaimer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .font(.subheadline)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            DatePicker(
                "Target Exam Date",
                selection: $studyStore.examDate,
                in: Date()...,
                displayedComponents: .date
            )
            .padding(.horizontal, 28)

            Spacer()

            Button {
                studyStore.hasAcceptedDisclaimer = true
            } label: {
                Text("Start My 5-Min Streak")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.teal, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}
