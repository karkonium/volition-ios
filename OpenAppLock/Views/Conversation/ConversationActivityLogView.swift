import SwiftUI
import UIKit

/// Private request history: time, app, message, coach response and actual local
/// outcome. Explicit exports are readable text or ISO-8601 JSON Lines; clearing
/// this content log never clears the coach's enforcement history or active waits.
struct ConversationActivityLogView: View {
    @Environment(ConversationCoordinator.self) private var conversation
    @State private var confirmingClear = false
    @State private var sharing: SharedActivityFile?
    @State private var exporting = false
    @State private var exportFailed = false
    @State private var clearFailed = false

    var body: some View {
        List {
            if conversation.history.activityLog.isEmpty {
                Text(CopyKey.activityEmpty.resource).foregroundStyle(.secondary)
                    .accessibilityIdentifier("activityLogEmpty")
            }
            ForEach(conversation.history.activityLog.reversed()) { entry in
                NavigationLink {
                    ScrollView {
                        Text(ConversationActivityExport.text([entry]))
                            .frame(maxWidth: .infinity, alignment: .leading).padding().textSelection(.enabled)
                    }.navigationTitle(entry.appName ?? CopyKey.activityNoApp.string)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(entry.appName ?? CopyKey.activityNoApp.string).font(.headline)
                            Spacer()
                            Text(entry.outcome.title).font(.caption).foregroundStyle(Color.secondary)
                                .accessibilityIdentifier("activityOutcome-\(entry.outcome.rawValue)")
                        }
                        Text(entry.date.formatted(date: .abbreviated, time: .standard))
                            .font(.caption).foregroundStyle(Color.secondary)
                        Text(entry.message).lineLimit(3).foregroundStyle(Color.primary)
                        if let reply = entry.coachResponse ?? entry.systemResponse {
                            Text(reply).font(.subheadline).lineLimit(3).foregroundStyle(Color.secondary)
                        }
                    }
                }.accessibilityIdentifier("activityEntry-\(entry.id.uuidString)")
            }
            Section { Text(CopyKey.activityPrivacy.resource).font(.footnote).foregroundStyle(.secondary) }
            if clearFailed { Text(CopyKey.conversationStorageError.resource).foregroundStyle(.red) }
            if exportFailed { Text(CopyKey.activityExportError.resource).foregroundStyle(.red) }
        }
        .navigationTitle(CopyKey.activityLogTitle.resource)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(CopyKey.activityExportText.resource) { export(.text) }
                    Button(CopyKey.activityExportJSONL.resource) { export(.jsonLines) }
                } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(conversation.history.activityLog.isEmpty || exporting)
                    .accessibilityLabel(CopyKey.activityExport.resource)
                    .accessibilityIdentifier("exportActivityLogButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(CopyKey.activityClear.resource, systemImage: "trash", role: .destructive) { confirmingClear = true }
                    .labelStyle(.iconOnly).disabled(conversation.history.activityLog.isEmpty || exporting)
                    .accessibilityIdentifier("clearActivityLogButton")
            }
        }
        .confirmationDialog(CopyKey.activityClear.resource, isPresented: $confirmingClear, titleVisibility: .visible) {
            Button(CopyKey.activityClear.resource, role: .destructive) { clearFailed = !conversation.clearActivityLog() }
        } message: { Text(CopyKey.activityClearHelp.resource) }
        .sheet(item: $sharing) { file in ActivityShareSheet(url: file.url) }
    }

    private func export(_ format: ConversationActivityExport.Format) {
        let entries = conversation.history.activityLog
        exporting = true; exportFailed = false
        Task {
            defer { exporting = false }
            do {
                let url = try await Task.detached { try ConversationActivityExport.file(entries, format: format) }.value
                sharing = SharedActivityFile(url: url)
            } catch { exportFailed = true }
        }
    }
}

private struct SharedActivityFile: Identifiable { let id = UUID(); let url: URL }
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
