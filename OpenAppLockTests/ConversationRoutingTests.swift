import Foundation
import FamilyControls
import ManagedSettings
import Testing
@testable import OpenAppLock

@MainActor struct ConversationRoutingTests {
    private func rule(_ name: String, _ byte: UInt8) throws -> RuleSnapshotDTO {
        let token = try JSONDecoder().decode(ApplicationToken.self,
            from: JSONSerialization.data(withJSONObject: ["data": Data([byte]).base64EncodedString()]))
        var selection = FamilyActivitySelection(); selection.applicationTokens = [token]
        return .init(id: UUID(), name: name, kindRaw: "conversation", isEnabled: true,
            hardMode: false, selectionModeRaw: "block", selectionData: AppSelectionCodec.encode(selection),
            dayNumbers: [], startMinutes: 0, endMinutes: 0, dailyLimitMinutes: 45, maxOpens: 5)
    }
    @Test func savedNamesBoundariesAndAmbiguity() throws {
        let maps = try rule("Google Maps", 1), sound = try rule("SoundCloud", 2)
        let token = try #require(AppSelectionCodec.decode(sound.selectionData).applicationTokens.first)
        #expect(ConversationAppResolver.resolve("Please unlock SOUND CLOUD!", in: [maps, sound]) == .selected(token))
        #expect(ConversationAppResolver.resolve("SoundCloud or Google Maps", in: [maps, sound]) == .ambiguous)
        #expect(ConversationAppResolver.resolve("SoundCloudish", in: [sound]) == .none)
        var disabled = sound; disabled.isEnabled = false
        #expect(ConversationAppResolver.resolve("SoundCloud", in: [disabled]) == .none)
        let duplicate = try rule("SoundCloud", 3)
        #expect(ConversationAppResolver.resolve("SoundCloud", in: [sound, duplicate]) == .ambiguous)
        let short = try rule("Maps", 4)
        #expect(ConversationAppResolver.resolve("Google Maps or Maps", in: [maps, short]) == .ambiguous)
        let mapsToken = try #require(AppSelectionCodec.decode(maps.selectionData).applicationTokens.first)
        #expect(ConversationAppResolver.resolve("Use Google Maps", in: [maps, short]) == .selected(mapsToken))
    }
}
