import SwiftUI
import WatchKit

/// Watch version of the iPhone's Quick-Pick Treatments sheet. The suggestions are computed on the
/// iPhone and sent along with the watch state. Like the iPhone's slide-to-confirm, picked amounts are
/// confirmed right here by dialing the crown (same crown confirmation as `BolusConfirmationView`).
struct QuickPickTreatmentsView: View {
    @Binding var navigationPath: NavigationPath
    let state: WatchState

    @State private var selectedBolusAmount: Decimal?
    @State private var selectedCarbAmount: Decimal?
    @State private var confirmationProgress: Double = 0

    @FocusState private var isCrownFocused: Bool

    var trioBackgroundColor = LinearGradient(
        gradient: Gradient(colors: [Color.bgDarkBlue, Color.bgDarkerDarkBlue]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        Group {
            if displayedBolusSuggestions.isEmpty, displayedCarbSuggestions.isEmpty {
                ScrollView {
                    Text(String(
                        localized: "Quick-Pick Treatments learns from your manual boluses and carb entries over time. Once you've logged a few, it will suggest amounts based on what you typically enter at this time of day.",
                        comment: "Alert body explaining that quick-pick treatments history is empty"
                    ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            } else {
                pickerWithCrownConfirmation
            }
        }
        .background(trioBackgroundColor)
        .navigationTitle("Quick Pick")
    }

    private var pickerWithCrownConfirmation: some View {
        VStack(spacing: 10) {
            Spacer()

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

            ProgressView(value: confirmationProgress, total: 1.0)
                .tint(confirmationProgress >= 1.0 ? .loopGreen : .gray)

            Text("To confirm, dial crown.").font(.footnote)
                .foregroundStyle(hasSelection ? .primary : .secondary)

            Spacer()
        }
        .padding(.horizontal)
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $confirmationProgress,
            from: 0.0,
            through: 1.0,
            by: state.confirmBolusFaster ? 0.5 : 0.05,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear {
            isCrownFocused = true
        }
        // Changing the pick restarts the confirmation, so a half-dialed crown never confirms a different amount
        .onChange(of: selectedBolusAmount) { restartConfirmation() }
        .onChange(of: selectedCarbAmount) { restartConfirmation() }
        .onChange(of: confirmationProgress) { _, newValue in
            guard hasSelection else {
                confirmationProgress = 0
                return
            }
            if newValue >= 1.0 {
                WKInterfaceDevice.current().play(.success)
                confirm()
            } else if newValue > 0 {
                WKInterfaceDevice.current().play(.click)
            }
        }
    }

    // Same selection as the iPhone sheet: the top 3 suggestions, shown smallest first.
    private var displayedBolusSuggestions: [Decimal] { state.quickPickBolusSuggestions.prefix(3).sorted() }
    private var displayedCarbSuggestions: [Decimal] { state.quickPickCarbSuggestions.prefix(3).sorted() }

    private var hasSelection: Bool { selectedBolusAmount != nil || selectedCarbAmount != nil }

    private func restartConfirmation() {
        confirmationProgress = 0
        isCrownFocused = true // tapping a pill must not leave the crown without focus
    }

    /// Sends the picked carbs and/or bolus the same way `BolusConfirmationView` does.
    private func confirm() {
        // Suggestions are already capped on the iPhone; re-cap in case a limit changed since.
        let carbsAmount = NSDecimalNumber(decimal: min(selectedCarbAmount ?? 0, state.maxCarbs)).intValue
        let bolusAmount = min(selectedBolusAmount ?? 0, state.maxBolus)

        if carbsAmount > 0 {
            state.sendCarbsRequest(carbsAmount, Date())
        }
        if bolusAmount > 0 {
            state.sendBolusRequest(bolusAmount)
        }
        selectedCarbAmount = nil
        selectedBolusAmount = nil
        navigationPath.append(NavigationDestinations.acknowledgmentPending)
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
