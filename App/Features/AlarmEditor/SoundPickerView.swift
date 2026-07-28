import SwiftUI
import UniformTypeIdentifiers

/// Pro: pick the alarm sound — Default, or one of the user's imported sounds.
/// Drives both the heads-up notification and the alarm ring (device-validated
/// this round). Import pulls audio from Files/Voice Memos and converts it
/// (see SoundManager).
struct SoundPickerView: View {
    @Binding var soundName: String?
    @Environment(SoundManager.self) private var sounds
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var working = false
    @State private var importFailed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(title: "Default", file: nil, icon: "bell")
                }
                Section {
                    if sounds.sounds.isEmpty {
                        Text("No imported sounds yet").foregroundStyle(.secondary)
                    } else {
                        ForEach(sounds.sounds, id: \.self) { file in
                            row(title: sounds.displayName(file), file: file, icon: "music.note")
                        }
                        .onDelete { offsets in
                            for file in offsets.map({ sounds.sounds[$0] }) {
                                if soundName == file { soundName = nil }
                                sounds.delete(file)
                            }
                        }
                    }
                    Button {
                        importing = true
                    } label: {
                        Label(working ? "Importing…" : "Import from Files…", systemImage: "square.and.arrow.down")
                    }
                    .disabled(working)
                } header: {
                    Text("Your sounds")
                } footer: {
                    Text("Import your own audio - the first ~30 seconds are used (trimmed & converted automatically). Apple Music tracks are protected and can't be imported.")
                }
            }
            .navigationTitle("Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { sounds.stopPreview(); dismiss() } }
            }
            .alert("Couldn't import that sound", isPresented: $importFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Try a different audio file. Apple Music tracks are protected and can't be used.")
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
                guard case .success(let url) = result else { return }
                Task {
                    working = true
                    if let name = await sounds.importSound(from: url) { soundName = name }
                    else { importFailed = true }
                    working = false
                }
            }
        }
    }

    private func row(title: String, file: String?, icon: String) -> some View {
        Button {
            soundName = file
            if let file { sounds.preview(file) } else { sounds.stopPreview() }
        } label: {
            HStack {
                Image(systemName: icon).foregroundStyle(.secondary).frame(width: 22)
                Text(title)
                Spacer()
                if soundName == file {
                    Image(systemName: "checkmark").foregroundStyle(Theme.accent).fontWeight(.semibold)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
