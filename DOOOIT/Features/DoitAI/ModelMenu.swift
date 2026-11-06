import SwiftUI

/// 모티 AI 화면 위쪽의 모델 고르기 (ChatGPT·Gemini처럼): 모티 ZERO(모델 없이) / 모티 1 / 모티 2
/// (사진 인식 설정은 오답노트에서)
struct ModelMenu: View {
    @State private var brain = DoitBrain.shared
    @State private var confirmDownload: DoitBrain.Model?

    var body: some View {
        Menu {
            Section("모델") {
                // 모티 ZERO: 모델 없이 규칙형 엔진만 (간단한 명령)
                Button {
                    brain.select(nil)
                } label: {
                    row(title: L("모티 ZERO"), detail: L("간단한 명령이 필요할 때"), selected: brain.selected == nil)
                }
                ForEach(DoitBrain.Model.allCases) { model in
                    Button {
                        if brain.isInstalled(model) { brain.select(model); Task { await brain.prepare() } }
                        else { confirmDownload = model }
                    } label: {
                        if !model.fitsDevice {
                            row(title: model.title.loc, detail: L("이 기기에서는 못 써요"), selected: false)
                        } else if brain.isInstalled(model) {
                            row(title: model.title.loc, detail: model.detail.loc, selected: brain.selected == model)
                        } else {
                            row(title: model.title.loc, detail: model.detail.loc + L(" · 다운로드"), selected: false, symbol: "arrow.down.circle")
                        }
                    }
                    .disabled(!DoitBrain.isSupported || !model.fitsDevice || (brain.downloading != nil && brain.downloading != model && !brain.isInstalled(model)))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(title).font(.pt(.headline)).foregroundStyle(Palette.ink)
                if case .downloading(let fraction) = brain.phase {
                    Text("\(Int(fraction * 100))%").font(.pt(.caption).weight(.semibold)).foregroundStyle(Theme.accent).monospacedDigit()
                } else if brain.phase == .loading {
                    ProgressView().controlSize(.mini)
                }
                Image(systemName: "chevron.down").font(.pt(.caption).weight(.bold)).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("모델 고르기, 지금 \(title)")
        .alert(confirmDownload.map { L("\($0.title.loc) 다운로드") } ?? "", isPresented: Binding(get: { confirmDownload != nil }, set: { if !$0 { confirmDownload = nil } })) {
            Button("다운로드") {
                if let model = confirmDownload { Task { await brain.download(model) } }
                confirmDownload = nil
            }
            Button("취소", role: .cancel) { confirmDownload = nil }
        } message: {
            Text("한 번 받으면 인터넷 없이도 써요. 와이파이에서 받아 주세요.")
        }
    }

    /// 메뉴 한 줄: 이름 + 아래 작은 설명 (고른 것은 체크)
    @ViewBuilder
    private func row(title: String, detail: String, selected: Bool, symbol: String? = nil) -> some View {
        if selected {
            Label { Text(title); Text(detail) } icon: { Image(systemName: "checkmark") }
        } else if let symbol {
            Label { Text(title); Text(detail) } icon: { Image(systemName: symbol) }
        } else {
            Text(title)
            Text(detail)
        }
    }

    private var title: String {
        if let downloading = brain.downloading { return downloading.title }
        return brain.selected?.title.loc ?? L("모티 ZERO")
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
                    Image(systemName: "sparkles").font(.pt(.headline)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline(model)).font(.pt(.subheadline).weight(.bold)).foregroundStyle(Palette.ink)
                        Text(detail(model)).font(.pt(.caption)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if case .downloading(let fraction) = brain.phase {
                    ProgressView(value: fraction).tint(Theme.accent)
                } else if brain.downloading == nil {
                    Button {
                        Haptics.tap()
                        Task { await brain.download(model) }
                    } label: {
                        Label("\(model.title.loc) 다운로드", systemImage: "arrow.down.circle.fill")
                            .font(.pt(.subheadline).weight(.bold))
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
        if case .downloading = brain.phase { return L("\(model.title.loc) 다운로드 중") }
        if brain.phase == .loading { return L("\(model.title.loc) 준비 중…") }
        if case .failed(let message) = brain.phase { return message }
        return L("\(model.title.loc) 모델 사용하기")
    }

    private func detail(_ model: DoitBrain.Model) -> String {
        if case .downloading(let fraction) = brain.phase { return L("\(Int(fraction * 100))% · 앱을 켜 둔 채로 기다려 주세요") }
        return L("한 번 다운로드하면 더 자연스럽게 대화하고, 인터넷에서 찾아 정리하고, 스스로 배워요. 위쪽 메뉴에서 다른 모델도 고를 수 있어요.")
    }
}

/// 모티 AI가 배운 내용 (보기·지우기)
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
                            .font(.pt(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(icon(note.kind) + " " + note.topic).font(.pt(.subheadline).weight(.semibold))
                                Spacer()
                                if note.score > 0 { Text("👍 \(note.score)").font(.pt(.caption)) }
                            }
                            Text(note.summary).font(.pt(.caption)).foregroundStyle(.secondary).lineLimit(3)
                            if !note.sources.isEmpty {
                                Text("출처: " + note.sources.joined(separator: ", ")).font(.pt(.caption2)).foregroundStyle(.tertiary).lineLimit(1)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { DoitMemory.shared.forget(notes[index].id) }
                        reload()
                    }
                } footer: {
                    Text("이 기기에만 저장돼요 · 모티 1·2는 Apache-2.0 오픈소스 모델 기반")
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
