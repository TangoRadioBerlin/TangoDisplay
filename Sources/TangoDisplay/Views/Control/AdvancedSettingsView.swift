import SwiftUI
import TangoDisplayCore

struct AdvancedSettingsView: View {
    @EnvironmentObject var settings: AppSettings

    @State private var selectedField: TrackInfoField? = nil
    @State private var showingResetAllConfirmation = false
    @State private var resetGeneration = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                fieldTable
                if let field = selectedField {
                    Divider()
                    FieldEditorPanel(field: field, settings: settings)
                        .id("\(field.rawValue)-\(resetGeneration)")
                }
                Spacer(minLength: 20)
                footerRow
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            "Reset all track info transformations?",
            isPresented: $showingResetAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset All", role: .destructive) {
                for field in TrackInfoField.allCases {
                    settings.trackTransforms[field.rawValue] = TransformRule()
                }
                resetGeneration += 1
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will disable and clear regex rules for all fields. This cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Track Info Transformations")
                .font(.headline)
                .foregroundColor(ControlTheme.accent)
            Text("Use regular expressions to change how track information appears on the display. This does not modify your music files or tags.")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Field table

    private var fieldTable: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Text("Field")
                    .frame(width: 120, alignment: .leading)
                Text("Transform")
                    .frame(width: 120, alignment: .leading)
                Text("Preview (example)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                // chevron spacer
                Spacer().frame(width: 20)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            ForEach(TrackInfoField.allCases) { field in
                FieldRow(
                    field: field,
                    rule: settings.trackTransforms[field.rawValue] ?? TransformRule(),
                    isSelected: selectedField == field,
                    onTap: {
                        selectedField = (selectedField == field) ? nil : field
                    }
                )
                if field != TrackInfoField.allCases.last {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "questionmark.circle")
                .foregroundColor(.secondary)
            Text("If a pattern matches, the match is the result. On no match, the field is kept or cleared — per the toggle on each field.")
                .foregroundColor(.secondary)
            Spacer()
            Button("Reset All") {
                showingResetAllConfirmation = true
            }
        }
    }
}

// MARK: - Field row

private struct FieldRow: View {
    let field: TrackInfoField
    let rule: TransformRule
    let isSelected: Bool
    let onTap: () -> Void

    var previewText: String {
        let input = rule.testInput.isEmpty ? field.sampleValue : rule.testInput
        guard rule.enabled, !rule.pattern.isEmpty,
              let regex = try? NSRegularExpression(pattern: rule.pattern) else {
            return input
        }
        let range = NSRange(input.startIndex..., in: input)
        let result = regex.stringByReplacingMatches(in: input, range: range, withTemplate: rule.replacement)
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? input : trimmed
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Text(field.displayName)
                    .frame(width: 120, alignment: .leading)
                Text(rule.enabled ? "On (regex)" : "Off")
                    .frame(width: 120, alignment: .leading)
                    .foregroundColor(rule.enabled ? .primary : .secondary)
                Text(previewText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(rule.enabled ? .green : .primary)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Field editor panel

private struct FieldEditorPanel: View {
    let field: TrackInfoField
    @ObservedObject var settings: AppSettings

    @State private var patternText: String = ""
    @State private var replacementText: String = ""
    @State private var testInput: String = ""

    private var currentRule: TransformRule {
        settings.trackTransforms[field.rawValue] ?? TransformRule()
    }

    private enum RegexStatus { case matched, noMatch, invalid }

    private var regexStatus: RegexStatus {
        guard !patternText.isEmpty else { return .noMatch }
        guard let regex = try? NSRegularExpression(pattern: patternText) else { return .invalid }
        let r = NSRange(testInput.startIndex..., in: testInput)
        return regex.numberOfMatches(in: testInput, range: r) > 0 ? .matched : .noMatch
    }

    private var resultString: String {
        // Mirror the runtime exactly, including the per-field "clear when no match" behaviour.
        applyRegexTransform(testInput, pattern: patternText, replacement: replacementText,
                            clearWhenNoMatch: currentRule.clearWhenNoMatch)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Panel header
            HStack {
                Text("Edit: \(field.displayName)")
                    .font(.headline)
                    .foregroundColor(ControlTheme.accent)
                Spacer()
                Toggle("Enable transformation", isOn: Binding(
                    get: { currentRule.enabled },
                    set: { newVal in
                        var rule = currentRule
                        rule.enabled = newVal
                        settings.trackTransforms[field.rawValue] = rule
                    }
                ))
                .toggleStyle(.switch)
            }

            Text("Use a regular expression to transform how the \(field.displayName) field is shown on the display.")
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Copy from field")
                        .frame(width: 120, alignment: .leading)
                    Picker("", selection: Binding<TrackInfoField?>(
                        get: { currentRule.sourceField },
                        set: { newVal in
                            var rule = currentRule
                            rule.sourceField = newVal
                            settings.trackTransforms[field.rawValue] = rule
                            testInput = (newVal ?? field).sampleValue
                        }
                    )) {
                        Text("None (use \(field.displayName))").tag(TrackInfoField?.none)
                        ForEach(TrackInfoField.allCases.filter { $0 != field }) { f in
                            Text(f.displayName).tag(TrackInfoField?.some(f))
                        }
                    }
                    .labelsHidden()
                    Spacer()
                }
                Text("Optionally fill this field from another field's value before the regex runs — e.g. show the Artist in the Album Artist line.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .top, spacing: 20) {
                // Left: inputs
                VStack(alignment: .leading, spacing: 12) {
                    patternField
                    replacementField
                    Toggle("Clear field when the pattern doesn't match", isOn: Binding(
                        get: { currentRule.clearWhenNoMatch },
                        set: { newVal in
                            var rule = currentRule
                            rule.clearWhenNoMatch = newVal
                            settings.trackTransforms[field.rawValue] = rule
                        }
                    ))
                    .help("On: a non-matching pattern empties the field. Off: the original value is kept.")
                    Button("Reset to default") {
                        settings.trackTransforms[field.rawValue] = TransformRule()
                        patternText = ""
                        replacementText = ""
                        testInput = field.sampleValue
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)

                // Right: live preview
                previewPanel
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .onAppear { loadFromSettings() }
    }

    // MARK: Pattern input

    private var patternField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Pattern (regex)")
                    .font(.subheadline)
                Button {
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("A regular expression pattern. Capture groups can be referenced in the replacement with $1, $2, etc.")
            }
            TextField("", text: $patternText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: patternText) { newVal in
                    guard !newVal.isEmpty else {
                        var rule = currentRule
                        rule.pattern = ""
                        settings.trackTransforms[field.rawValue] = rule
                        return
                    }
                    guard (try? NSRegularExpression(pattern: newVal)) != nil else { return }
                    var rule = currentRule
                    rule.pattern = newVal
                    settings.trackTransforms[field.rawValue] = rule
                }
            Text("The regular expression to match.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: Replacement input

    private var replacementField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Replace with")
                    .font(.subheadline)
                Button {
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("The replacement text. Use $1, $2, etc. for capture groups. Use \\n for a line break.")
            }
            TextField("", text: $replacementText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onChange(of: replacementText) { newVal in
                    var rule = currentRule
                    rule.replacement = newVal
                    settings.trackTransforms[field.rawValue] = rule
                }
            Text("Use $1, $2 for capture groups. Use \\n for a line break.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: Preview panel

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(ControlTheme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Test input")
                    .font(.subheadline)
                TextField("", text: $testInput)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: testInput) { newVal in
                        var rule = currentRule
                        rule.testInput = newVal
                        settings.trackTransforms[field.rawValue] = rule
                    }
                Text("Enter a sample value to see the result.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !patternText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Result")
                        .font(.subheadline)
                    Text(resultString)
                        .font(.body)
                        .foregroundColor(regexStatus == .matched ? .green : .primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(6)
                }

                statusIndicator
            }
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            switch regexStatus {
            case .matched:
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Pattern matched.").foregroundColor(.green)
            case .noMatch:
                Image(systemName: "exclamationmark.triangle").foregroundColor(.secondary)
                Text(currentRule.clearWhenNoMatch
                     ? "No match — the field will be empty."
                     : "No match — the original value is kept.").foregroundColor(.secondary)
            case .invalid:
                Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                Text("Invalid regex.").foregroundColor(.red)
            }
        }
        .font(.caption)
    }

    // MARK: - Helpers

    private func loadFromSettings() {
        let rule = currentRule
        patternText = rule.pattern
        replacementText = rule.replacement
        testInput = rule.testInput.isEmpty ? (rule.sourceField ?? field).sampleValue : rule.testInput
    }
}
