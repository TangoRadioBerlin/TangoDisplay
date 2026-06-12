import SwiftUI
import TangoDisplayCore

struct AppearanceCortinaTab: View {
    @Binding var working: AppearanceProfile

    var body: some View {
        Form {
            Section {
                Toggle("Show Cortina Label", isOn: $working.showCortinaLabel)
                Toggle("Show cortina track during cortina", isOn: $working.showCortinaTrackDuringCortina)
                Toggle("Show next track during cortina (Coming Up)", isOn: $working.showNextTrackDuringCortina)
                Toggle("Show Cortina Artist", isOn: $working.showCortinaTrackArtist)
                    .disabled(!working.showCortinaTrackDuringCortina)
                Toggle("Show Cortina Title",  isOn: $working.showCortinaTrackTitle)
                    .disabled(!working.showCortinaTrackDuringCortina)
                Toggle("Show Cortina Year",   isOn: $working.showCortinaTrackYear)
                    .disabled(!working.showCortinaTrackDuringCortina)
            } header: {
                Text("Cortina Display")
                    .foregroundColor(ControlTheme.accent)
            }
        }
        .formStyle(.grouped)
    }
}
