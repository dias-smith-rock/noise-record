import XCTest
@testable import NoiseRecord

@MainActor
final class AppAccentPreferenceTests: XCTestCase {
    private let defaults = UserDefaults(suiteName: "AppAccentPreferenceTests")!

    override func setUp() {
        super.setUp()
        defaults.removePersistentDomain(forName: "AppAccentPreferenceTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "AppAccentPreferenceTests")
        super.tearDown()
    }

    func testAutomaticUsesBuiltinAccent() {
        let preference = ModeAccentPreference(
            choice: .automatic,
            preset: .purple,
            customRGB: AppAccentPreset.purple.storedRGB
        )
        let builtin = StoredRGB(color: ModeVisualTheme.builtinAccent(for: .standard))
        let resolved = preference.resolvedRGB(builtin: builtin)
        XCTAssertTrue(resolved.isApproximatelyEqual(to: builtin))
    }

    func testPresetUsesSelectedColor() {
        let preference = ModeAccentPreference(
            choice: .preset,
            preset: .purple,
            customRGB: AppAccentPreset.teal.storedRGB
        )
        let resolved = preference.resolvedRGB(builtin: AppAccentPreset.teal.storedRGB)
        XCTAssertTrue(resolved.isApproximatelyEqual(to: AppAccentPreset.purple.storedRGB))
    }

    func testCustomUsesStoredRGB() {
        let custom = StoredRGB(red: 0.42, green: 0.18, blue: 0.73)
        let preference = ModeAccentPreference(
            choice: .custom,
            preset: .teal,
            customRGB: custom
        )
        let resolved = preference.resolvedRGB(builtin: AppAccentPreset.teal.storedRGB)
        XCTAssertTrue(resolved.isApproximatelyEqual(to: custom))
    }

    func testPersistenceRoundTripPerMode() {
        let standard = ModeAccentPreference(
            choice: .preset,
            preset: .blue,
            customRGB: StoredRGB(red: 0.1, green: 0.2, blue: 0.3)
        )
        let highSensitivity = ModeAccentPreference(
            choice: .custom,
            preset: .orange,
            customRGB: StoredRGB(red: 0.8, green: 0.1, blue: 0.2)
        )

        ModeAccentPersistence.save(standard, for: .standard, defaults: defaults)
        ModeAccentPersistence.save(highSensitivity, for: .highSensitivity, defaults: defaults)

        let loadedStandard = ModeAccentPersistence.load(for: .standard, defaults: defaults)
        let loadedHighSensitivity = ModeAccentPersistence.load(for: .highSensitivity, defaults: defaults)

        XCTAssertEqual(loadedStandard, standard)
        XCTAssertEqual(loadedHighSensitivity, highSensitivity)
    }

    func testModesDoNotAffectEachOther() {
        ModeAccentPersistence.save(
            ModeAccentPreference(choice: .preset, preset: .green, customRGB: AppAccentPreset.green.storedRGB),
            for: .standard,
            defaults: defaults
        )
        ModeAccentPersistence.save(
            ModeAccentPreference(choice: .automatic, preset: .orange, customRGB: AppAccentPreset.orange.storedRGB),
            for: .highSensitivity,
            defaults: defaults
        )

        let standard = ModeAccentPersistence.load(for: .standard, defaults: defaults)
        let highSensitivity = ModeAccentPersistence.load(for: .highSensitivity, defaults: defaults)

        XCTAssertEqual(standard.choice, .preset)
        XCTAssertEqual(standard.preset, .green)
        XCTAssertEqual(highSensitivity.choice, .automatic)
        XCTAssertEqual(highSensitivity.preset, .orange)
    }
}
