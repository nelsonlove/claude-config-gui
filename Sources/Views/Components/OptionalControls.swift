import SwiftUI

// MARK: - Inline description modifier

/// Adds a small description line below any control.
/// More reliable and discoverable than `.help()` hover tooltips on macOS.
struct DescribedModifier: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            content
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    func described(_ text: String) -> some View {
        modifier(DescribedModifier(text: text))
    }
}

// MARK: - OptionalToggle

/// A toggle that supports optional Bool bindings.
/// Shows a tri-state: unset (dimmed), on, off.
struct OptionalToggle: View {
    let label: String
    @Binding var isOn: Bool?

    init(_ label: String, isOn: Binding<Bool?>) {
        self.label = label
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            Toggle(label, isOn: Binding(
                get: { isOn ?? false },
                set: { newValue in
                    // Checking sets true; unchecking clears to nil (unset/default).
                    // Use the raw JSON editor to set an explicit false if needed.
                    isOn = newValue ? true : nil
                }
            ))
            .toggleStyle(.checkbox)

            if isOn != nil {
                resetButton { isOn = nil }
            }
        }
        .opacity(isOn == nil ? 0.6 : 1)
    }
}

// MARK: - OptionalPicker

/// A picker that wraps an optional binding, showing a "Default" option for nil.
struct OptionalPicker<Value: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: Value?
    @ViewBuilder let content: () -> Content

    init(_ label: String, selection: Binding<Value?>, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self._selection = selection
        self.content = content
    }

    var body: some View {
        HStack {
            Picker(label, selection: $selection) {
                Text("Default").tag(nil as Value?)
                content()
            }

            if selection != nil {
                resetButton { selection = nil }
            }
        }
    }
}

// MARK: - OptionalStepper

/// A stepper for optional Int bindings, with inline text field and unit label.
struct OptionalStepper: View {
    let label: String
    @Binding var value: Int?
    let range: ClosedRange<Int>
    let unit: String

    init(_ label: String, value: Binding<Int?>, range: ClosedRange<Int>, unit: String = "") {
        self.label = label
        self._value = value
        self.range = range
        self.unit = unit
    }

    var body: some View {
        HStack {
            Text(label)

            Spacer()

            Stepper(value: Binding(
                get: { value ?? range.lowerBound },
                set: { value = $0 }
            ), in: range) {
                HStack(spacing: 4) {
                    TextField("", value: Binding(
                        get: { value ?? range.lowerBound },
                        set: { value = $0 }
                    ), format: .number)
                    .frame(width: 48)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)

                    if !unit.isEmpty {
                        Text(unit)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if value != nil {
                resetButton { value = nil }
            }
        }
        .opacity(value == nil ? 0.6 : 1)
    }
}

// MARK: - Shared reset button

private func resetButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
            .font(.caption)
    }
    .buttonStyle(.plain)
    .help("Reset to default")
}
