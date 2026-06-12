import SwiftUI
import TangoDisplayCore

struct AppearanceVisibilityTab: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var working: AppearanceProfile
    @Binding var danceDragItem: DisplayTextItem?
    @Binding var cortinaTrackDragItem: DisplayTextItem?
    @Binding var cortinaUpDragItem: DisplayTextItem?

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Dance")
                        .frame(width: 70, alignment: .center)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Text("Next Up")
                        .frame(width: 70, alignment: .center)
                        .foregroundColor(working.showNextTrackDuringCortina ? .secondary : .secondary.opacity(0.4))
                        .font(.subheadline)
                }
                visibilityRow("Genre",   dance: $working.showGenreDance,   cortina: $working.showGenreCortina)
                visibilityRow("Artist",  dance: $working.showArtistDance,  cortina: $working.showArtistCortina)
                visibilityRow("Year",    dance: $working.showYearDance,    cortina: $working.showYearCortina)
                visibilityRow("Title",   dance: $working.showTitleDance,   cortina: $working.showTitleCortina)
                visibilityRow("Singer",  dance: $working.showSingerDance,  cortina: $working.showSingerCortina)
                visibilityRow("Artwork", dance: $working.showArtworkDance, cortina: $working.showArtworkCortina)
                HStack {
                    Text("Last Played").frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("", isOn: $working.showLastPlayedDance).labelsHidden().frame(width: 70, alignment: .center)
                    Toggle("", isOn: $working.showLastPlayedCortina).labelsHidden().frame(width: 70, alignment: .center)
                }
                if working.showLastPlayedDance || working.showLastPlayedCortina {
                    HStack {
                        Text("Last Played prefix").foregroundColor(.secondary)
                        TextField("prev. Song: ", text: $settings.lastPlayedPrefix)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                Divider()
                Toggle("Show next track during cortina", isOn: $working.showNextTrackDuringCortina)
            } header: {
                Text("Field Visibility")
                    .foregroundColor(ControlTheme.accent)
            } footer: {
                Label {
                    Text("The Next Up column applies when 'Show next track during cortina' is enabled.")
                } icon: {
                    Image(systemName: "info.circle")
                }
            }

            Section {
                orderRows(items: $working.danceItemOrder, dragItem: $danceDragItem,
                          filter: { $0 != .trackCounter || settings.trackCounterPosition == .centre })
            } header: {
                orderHeader("Dance Tracks")
            }

            Section {
                orderRows(items: $working.cortinaTrackItemOrder, dragItem: $cortinaTrackDragItem)
            } header: {
                orderHeader("Cortinas — Cortina Track")
            }

            Section {
                orderRows(items: $working.cortinaItemOrder, dragItem: $cortinaUpDragItem)
            } header: {
                orderHeader("Cortinas — Coming Up")
            } footer: {
                Label {
                    Text("Sets the display order only. Use Field Visibility to show or hide individual fields.")
                } icon: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private func orderHeader(_ subtitle: String) -> some View {
        Text("Text Order for \(subtitle)")
            .foregroundColor(ControlTheme.accent)
    }

    private func visibilityRow(_ label: String, dance: Binding<Bool>, cortina: Binding<Bool>) -> some View {
        HStack {
            Text(label).frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: dance).labelsHidden().frame(width: 70, alignment: .center)
            Toggle("", isOn: cortina).labelsHidden().frame(width: 70, alignment: .center)
                .disabled(!working.showNextTrackDuringCortina)
        }
    }

    @ViewBuilder
    private func orderRows(items: Binding<[DisplayTextItem]>, dragItem: Binding<DisplayTextItem?>,
                           filter: ((DisplayTextItem) -> Bool)? = nil) -> some View {
        let visibleIndices = items.wrappedValue.indices.filter { filter?(items.wrappedValue[$0]) ?? true }
        VStack(spacing: 0) {
            ForEach(visibleIndices, id: \.self) { index in
                let isFirstVisible = index == visibleIndices.first
                let isLastVisible  = index == visibleIndices.last
                if !isFirstVisible { Divider() }
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    Text(items.wrappedValue[index].displayName)
                    Spacer()
                    Button {
                        items.wrappedValue.swapAt(index, index - 1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isFirstVisible)
                    Button {
                        items.wrappedValue.swapAt(index, index + 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(isLastVisible)
                }
                .padding(.vertical, 8)
                .onDrag {
                    dragItem.wrappedValue = items.wrappedValue[index]
                    return NSItemProvider(object: items.wrappedValue[index].rawValue as NSString)
                }
                .onDrop(of: [.plainText], delegate: OrderDropDelegate(
                    target: items.wrappedValue[index],
                    items: items,
                    dragging: dragItem
                ))
            }
        }
    }
}

// MARK: - Drop delegate (shared with visibility tab)

struct OrderDropDelegate: DropDelegate {
    let target: DisplayTextItem
    var items: Binding<[DisplayTextItem]>
    var dragging: Binding<DisplayTextItem?>

    func dropUpdated(info: DropInfo) -> DropProposal? {
        .init(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging.wrappedValue = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let src = dragging.wrappedValue,
              src != target,
              let from = items.wrappedValue.firstIndex(of: src),
              let to = items.wrappedValue.firstIndex(of: target) else { return }
        withAnimation {
            items.wrappedValue.move(fromOffsets: .init(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }
}
