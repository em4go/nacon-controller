import NaconCore
import SwiftUI

/// The language of the interface: the system's, or one chosen here.
///
/// Changing it rebuilds the window, because every string was resolved while it was drawn and SwiftUI
/// cannot know that a value outside its state changed underneath it. The choice is stored, so the next
/// launch starts where this one was left.
struct LanguageSection: View {
    @AppStorage(LanguagePreference.defaultsKey) private var stored = AppLanguage.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(AppText.resolve("Language"))
            Picker("", selection: $stored) {
                Text(AppText.resolve("System language")).tag(AppLanguage.system.rawValue)
                // A language names itself in its own language, so these two are verbatim.
                Text(verbatim: AppLanguage.english.name).tag(AppLanguage.english.rawValue)
                Text(verbatim: AppLanguage.spanish.name).tag(AppLanguage.spanish.rawValue)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Text(
                AppText.resolve(
                    "The whole window follows this choice. Profile names and the model of the controller stay as they are: they are your data, not interface text."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
