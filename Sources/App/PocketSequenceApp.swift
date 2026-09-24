import SwiftUI

@main
struct PocketSequenceApp: App {
    var body: some Scene {
        WindowGroup { SequencerView().preferredColorScheme(.dark) }
    }
}
