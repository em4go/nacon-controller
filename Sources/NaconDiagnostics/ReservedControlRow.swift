import NaconCore
import SwiftUI

/// The PS row, drawn once for both mapping views.
///
/// PS is not an editor row: it is the emulation switch and must stay reachable whatever the mapping
/// says, so the table and the graphical view both print it under their own content. The two copies
/// said the same thing with two different catalog keys, which is exactly how a reserved sentence ends
/// up reading two ways in one window — the row lives here and both views place it.
///
/// The sentence is already resolved by `MappingLine`, which is why it goes into `Text` as text: a
/// `LocalizedStringResource` handed to `Text` is looked up in the system language and would ignore the
/// language the user chose.
struct ReservedControlRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Text(Localization.resolve(ControlFacts.of(MappingRules.reservedControl).label))
                .font(.callout.weight(.medium))
                .frame(width: 96, alignment: .leading)
            Label(MappingLine.reserved, systemImage: "power")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
    }
}
