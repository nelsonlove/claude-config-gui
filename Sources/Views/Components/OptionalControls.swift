import SwiftUI

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
                set: { isOn = $0 }
            ))

            if isOn != nil {
                Button {
                    isOn = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }
        }
        .opacity(isOn == nil ? 0.6 : 1)
    }
}

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
                Button {
                    selection = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }
        }
    }
}

/// A stepper for optional Int bindings, with inline text field and unit label.
/// Dimmed when nil (unset), with a reset button to clear back to default.
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
                Button {
                    value = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }
        }
        .opacity(value == nil ? 0.6 : 1)
    }
}
