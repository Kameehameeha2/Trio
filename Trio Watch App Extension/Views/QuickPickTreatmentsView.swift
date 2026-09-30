import SwiftUI
import WatchKit

/// Watch version of the iPhone's Quick-Pick Treatments sheet. The suggestions are computed on the
/// iPhone and sent along with the watch state. A picked bolus goes through the regular crown
/// confirmation; picked carbs alone are logged right away, like the "Log Carbs" button.
struct QuickPickTreatmentsView: View {
    @Binding var navigationPath: NavigationPath
    let state: WatchState

    @State private var selectedBolusAmount: Decimal?
    @State private var selectedCarbAmount: Decimal?

    var trioBackgroundColor = LinearGradient(
        gradient: Gradient(colors: [Color.bgDarkBlue, Color.bgDarkerDarkBlue]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if displayedBolusSuggestions.isEmpty, displayedCarbSuggestions.isEmpty {
                    Text(String(
                        localized: "Quick-Pick Treatments learns from your manual boluses and carb entries over time. Once you've logged a few, it will suggest amounts based on what you typically enter at this time of day.",
                        comment: "Alert body explaining that quick-pick treatments history is empty"
                    ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    if !displayedCarbSuggestions.isEmpty {
                        pillRow(
                            amounts: displayedCarbSuggestions,
                            selected: selectedCarbAmount,
                            accentColor: Color.orange,
                            unit: "g",
                            select: { selectedCarbAmount = selectedCarbAmount == $0 ? nil : $0 }
                        )
                    }

                    if !displayedBolusSuggestions.isEmpty {
                        pillRow(
                            amounts: displayedBolusSuggestions,
                            selected: selectedBolusAmount,
                            accentColor: Color.insulin,
                            unit: String(localized: "U", comment: "Insulin unit"),
                            select: { selectedBolusAmount = selectedBolusAmount == $0 ? nil : $0 }
                        )
                    }

                    Button(selectedBolusAmount != nil ? String(localized: "Enact Bolus") : String(
                        localized: "Log Carbs",
                        comment: "Button Label to Log Carbs on Watch"
                    )) {
                        confirm()
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedBolusAmount != nil ? Color.insulin : Color.orange)
                    .disabled(selectedBolusAmount == nil && selectedCarbAmount == nil)
                }
            }
            .padding(.horizontal)
        }
        .background(trioBackgroundColor)
        .navigationTitle("Quick Pick")
    }

    // Same selection as the iPhone sheet: the top 3 suggestions, shown smallest first.
    private var displayedBolusSuggestions: [Decimal] { state.quickPickBolusSuggestions.prefix(3).sorted() }
    private var displayedCarbSuggestions: [Decimal] { state.quickPickCarbSuggestions.prefix(3).sorted() }

    private func confirm() {
        // Suggestions are already capped on the iPhone; re-cap in case a limit changed since.
        let carbsAmount = NSDecimalNumber(decimal: min(selectedCarbAmount ?? 0, state.maxCarbs)).intValue

        if let bolusAmount = selectedBolusAmount {
            // Hand over to the existing crown confirmation, which also sends the carbs (if any).
            state.carbsAmount = carbsAmount
            state.bolusAmount = NSDecimalNumber(decimal: min(bolusAmount, state.maxBolus)).doubleValue
            navigationPath.append(NavigationDestinations.bolusConfirm)
        } else if carbsAmount > 0 {
            state.sendCarbsRequest(carbsAmount)
            navigationPath.append(NavigationDestinations.acknowledgmentPending)
        }
    }

    private func pillRow(
        amounts: [Decimal],
        selected: Decimal?,
        accentColor: Color,
        unit: String,
        select: @escaping (Decimal) -> Void
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(amounts, id: \.self) { amount in
                let isSelected = selected == amount
                Button {
                    select(amount)
                } label: {
                    Text(amount.formatted() + " " + unit)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(isSelected ? accentColor : Color.gray.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
