import SwiftUI

@main
struct VeriRxApp: App {
    @State private var studyStore = StudyStore()
    @State private var storeKit = StoreKitManager()

    var body: some Scene {
        WindowGroup {
            RootTabView(studyStore: studyStore, storeKit: storeKit)
                .fontDesign(.rounded)
                .task {
                    await storeKit.start(studyStore: studyStore)
                }
        }
    }
}
