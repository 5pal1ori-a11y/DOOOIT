import SwiftUI

/// 두잇 AI 화면 위쪽의 모델 고르기 (ChatGPT·Gemini처럼): 두잇 1 / 두잇 2 다운로드·전환·삭제
/// (사진 인식 설정은 오답노트에서)
struct ModelMenu: View {
    @State private var brain = DoitBrain.shared
    @State private var confirmDownload: DoitBrain.Model?
    @State private var confirmDelete: DoitBrain.Model?

    var body: some View {
        Menu {
            Section("모델") {
                ForEach(DoitBrain.Model.allCases) { model in
                    Button {
                        if brain.isInstalled(model) { brain.select(model); Task { await brain.prepare() } }
                        else { confirmDownload = model }
                    } label: {
                        if brain.selected == model {
                            Label("\(model.title) · \(model.detail)", systemImage: "checkmark")
                        } else if brain.isInstalled(model) {
                            Text("\(model.title) · \(model.detail)")
                        } else {
                            Label("\(model.title) 다운로드", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(!DoitBrain.isSupported || (brain.downloading != nil && brain.downloading != model && !brain.isInstalled(model)))
                }
                Button {
                    brain.select(nil)
                } label: {
                    if brain.selected == nil { Label("기본 (모델 없이)", systemImage: "checkmark") } else { Text("기본 (모델 없이)") }
                }
            }
            if !brain.installed.isEmpty {
                Section("다운로드한 모델 삭제") {
                    ForEach(DoitBrain.Model.allCases.filter { brain.isInstalled($0) }) { model in
                        Button(role: .destructive) { confirmDelete = model } label: {
                            Label("\(model.title) 삭제", systemImage: "trash")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                if case .downloading(let fraction) = brain.phase {
                    Text("\(Int(fraction * 100))%").font(.caption.weight(.semibold)).foregroundStyle(Theme.accent).monospacedDigit()
                } else if brain.phase == .loading {
                    ProgressView().controlSize(.mini)
                }
                Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("모델 고르기, 지금 \(title)")
        .alert(confirmDownload.map { "\($0.title) 다운로드" } ?? "", isPresented: Binding(get: { confirmDownload != nil }, set: { if !$0 { confirmDownload = nil } })) {
            Button("다운로드") {
                if let model = confirmDownload { Task { await brain.download(model) } }
                confirmDownload = nil
            }
            Button("취소", role: .cancel) { confirmDownload = nil }
        } message: {
            Text("한 번 받으면 인터넷 없이도 써요. 와이파이에서 받아 주세요.")
        }
        .alert(confirmDelete.map { "\($0.title)을(를) 삭제할까요?" } ?? "", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("삭제", role: .destructive) {
                if let model = confirmDelete { brain.delete(model) }
                confirmDelete = nil
            }
            Button("취소", role: .cancel) { confirmDelete = nil }
        } message: {
            Text("다시 쓰려면 새로 다운로드해야 해요. 배운 내용은 남아 있어요.")
        }
    }

    private var title: String {
        if let downloading = brain.downloading { return downloading.title }
        return brain.selected?.title ?? "DOOOIT"
    }
}

/// 모델을 아직 받지 않았을 때 첫 화면에 보이는 다운로드 안내
struct ModelDownloadCard: View {
    @State private var brain = DoitBrain.shared

    var body: some View {
        if DoitBrain.isSupported, brain.installed.isEmpty || brain.downloading != nil || isFailed {
            let model = brain.downloading ?? DoitBrain.Model.recommended
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").font(.headline).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline(model)).font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                        Text(detail(model)).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if case .downloading(let fraction) = brain.phase {
                    ProgressView(value: fraction).tint(Theme.accent)
                } else if brain.downloading == nil {
                    Button {
                        Haptics.tap()
                        Task { await brain.download(model) }
                    } label: {
                        Label("\(model.title) 다운로드", systemImage: "arrow.down.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .glassCard(cornerRadius: 20, padding: 14)
        }
    }

    private var isFailed: Bool {
        if case .failed = brain.phase { return true }
        return false
    }

    private func headline(_ model: DoitBrain.Model) -> String {
        if case .downloading = brain.phase { return "\(model.title) 다운로드 중" }
        if brain.phase == .loading { return "\(model.title) 준비 중…" }
        if case .failed(let message) = brain.phase { return message }
        return "\(model.title) 모델 사용하기"
    }

    private func detail(_ model: DoitBrain.Model) -> String {
        if case .downloading(let fraction) = brain.phase { return "\(Int(fraction * 100))% · 앱을 켜 둔 채로 기다려 주세요" }
        return "한 번 다운로드하면 더 자연스럽게 대화하고, 인터넷에서 찾아 정리하고, 스스로 배워요. 위쪽 메뉴에서 다른 모델도 고를 수 있어요."
    }
}

/// 두잇 AI가 배운 내용 (보기·지우기)
struct LearnedNotesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notes: [DoitMemory.Note] = []
    @State private var confirmForget = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if notes.isEmpty {
                        Text("아직 배운 내용이 없어요. 인터넷에서 찾아 정리한 내용, 👍를 받은 설명, \"기억해줘: …\"로 알려준 내용이 여기에 쌓여요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(icon(note.kind) + " " + note.topic).font(.subheadline.weight(.semibold))
                                Spacer()
                                if note.score > 0 { Text("👍 \(note.score)").font(.caption) }
                            }
                            Text(note.summary).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                            if !note.sources.isEmpty {
                                Text("출처: " + note.sources.joined(separator: ", ")).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { DoitMemory.shared.forget(notes[index].id) }
                        reload()
                    }
                } footer: {
                    Text("이 기기에만 저장돼요 · 두잇 1·2는 Apache-2.0 오픈소스 모델 기반")
                }
            }
            .navigationTitle("배운 내용")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
                if !notes.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("모두 지우기", role: .destructive) { confirmForget = true }
                    }
                }
            }
            .confirmationDialog("배운 내용을 모두 지울까요?", isPresented: $confirmForget, titleVisibility: .visible) {
                Button("모두 지우기", role: .destructive) { DoitMemory.shared.forgetAll(); reload() }
            }
            .onAppear(perform: reload)
        }
        .presentationDetents([.medium, .large])
    }

    private func icon(_ kind: DoitMemory.Note.Kind) -> String {
        switch kind {
        case .learned: return "📘"
        case .userFact: return "📝"
        case .correction: return "✏️"
        }
    }

    private func reload() {
        notes = DoitMemory.shared.notes.sorted { $0.updatedAt > $1.updatedAt }
    }
}
