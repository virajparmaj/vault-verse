import Testing
import Foundation
@testable import VaultVerseCore

@Suite("Model sanity")
struct ModelSanityTests {
    @Test("Track generates an id and keeps its title")
    func trackGeneratesIdAndKeepsTitle() {
        let track = Track(
            title: "Blinding Lights",
            normalizedTitle: "blinding lights",
            primaryArtist: "The Weeknd",
            artists: ["The Weeknd"],
            normalizedArtist: "the weeknd"
        )
        #expect(!track.id.isEmpty)
        #expect(track.title == "Blinding Lights")
    }

    @Test("Confident mapping threshold is 80")
    func confidentThresholdIsEighty() {
        #expect(TrackPlatformMapping.confidentThreshold == 80)
    }

    @Test("No-material-change detection")
    func noMaterialChangeDetection() {
        #expect(SnapshotChangeSummary().isNoMaterialChange)
        #expect(!SnapshotChangeSummary(added: 1).isNoMaterialChange)
    }
}
