import SwiftUI

/// Compact numeric minutes control laid out as `−  XX min  +`. The number is
/// directly editable (digits only) and the −/+ buttons step by 1, clamped to
/// `MinutesInput.range`. Backed by `MinutesInput` so empty/garbage can never
/// collapse to a stray value.
struct MinutesField: View {
    @Binding var value: Int
    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 14) {
            stepButton("minus.circle.fill") { value = MinutesInput.clamped(value - 1) }
            HStack(spacing: 4) {
                TextField("", text: $text)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .onChange(of: text) { _, newValue in
                        let clean = MinutesInput.sanitize(newValue)
                        if clean != newValue { text = clean; return }
                        value = MinutesInput.minutes(from: clean)
                    }
                Text("min").foregroundStyle(.secondary)
            }
            .font(.body.monospacedDigit())
            stepButton("plus.circle.fill") { value = MinutesInput.clamped(value + 1) }
        }
        .onAppear { text = String(value) }
        // Reflect external/stepper changes, but don't clobber an in-progress
        // edit (e.g. a momentarily-empty field resolving to the fallback).
        .onChange(of: value) { _, newValue in
            if let synced = MinutesInput.reconcile(text: text, value: newValue) { text = synced }
        }
    }

    private func stepButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
    }
}
