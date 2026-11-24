import SwiftUI

struct RootTabView: View {
    @Bindable var studyStore: StudyStore
    var storeKit: StoreKitManager
    @State private var showPaywall = false

    var body: some View {
        TabView {
            NavigationStack {
                TodayDashboardView(
                    studyStore: studyStore,
                    onOpenPaywall: { showPaywall = true }
                )
            }
            .tabItem {
                Label("Today", systemImage: "bolt.heart.fill")
            }

            NavigationStack {
                PracticeHubView(
                    studyStore: studyStore,
                    onOpenPaywall: { showPaywall = true }
                )
            }
            .tabItem {
                Label("Practice", systemImage: "checklist.checked")
            }

            NavigationStack {
                DrugEncyclopediaView(studyStore: studyStore)
            }
            .tabItem {
                Label("Top Drugs", systemImage: "pills.fill")
            }

            NavigationStack {
                ReadinessProfileView(
                    studyStore: studyStore,
                    storeKit: storeKit,
                    onOpenPaywall: { showPaywall = true }
                )
            }
            .tabItem {
                Label("Readiness", systemImage: "chart.bar.xaxis")
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
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.teal)

            Text("Welcome to VeriRx")
                .font(.largeTitle.bold())

            Text("Zero-Hallucination Pharmacology & Pharmacy Math Prep.\nEvery card and rationale is anchored to official FDA SPL labels.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Label("Educational Use Only: VeriRx is designed strictly for licensure exam preparation and must never be used for clinical patient care or dosing decisions.", systemImage: "graduationcap.fill")
                Label("100% Offline & Private: No account sign-up required. Your FSRS memory schedule stays on your iPhone.", systemImage: "lock.iphone")
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
                Text("I Understand — Start Studying")
                    .font(.headline)
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
