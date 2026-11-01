import SwiftUI

/// 두잇 AI 두뇌 설정: 기기 안 언어 모델 내려받기·켜고 끄기·지우기, 배운 내용 관리
struct BrainSettingsView: View {
    @State private var brain = DoitBrain.shared
    @State private var notes: [DoitMemory.Note] = []
    @State private var choice: DoitBrain.Size = DoitBrain.shared.size
    @State private var confirmRemove = false
    @State private var confirmForget = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(Theme.accent.gradient, in: .rect(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("두잇 AI 두뇌").font(.headline)
                            Text(statusText).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if case .downloading(let fraction) = brain.phase {
                        ProgressView(value: fraction)
                            .tint(Theme.accent)
                        Text("\(Int(fraction * 100))% · 앱을 켜 둔 채로 기다려 주세요").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                Text("휴대폰 안에서 돌아가는 오픈소스 언어 모델(Qwen3, Apache-2.0)이에요. 처음 한 번만 내려받으면 인터넷 없이도 설명하고 대화해요. 질문 내용은 기기 밖으로 나가지 않아요. 인터넷 자료는 위키백과에서 찾아 읽고 자기 말로 정리해요.")
            }

            if !DoitBrain.isSupported {
                Section {
                    Label("시뮬레이터에서는 두뇌를 쓸 수 없어요. 실제 iPhone에서 사용해 주세요.", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                }
            } else if brain.isInstalled {
                Section {
                    Toggle(isOn: Binding(get: { brain.isEnabled }, set: { brain.isEnabled = $0 })) {
                        Label("두뇌 사용", systemImage: "sparkles")
                    }
                    LabeledContent {
                        Text(brain.size.title)
                    } label: {
                        Label("설치된 두뇌", systemImage: "internaldrive")
                    }
                    if case .failed = brain.phase {
                        Button { Task { await brain.prepare() } } label: {
                            Label("다시 불러오기", systemImage: "arrow.clockwise")
                        }
                    }
                    Button(role: .destructive) { confirmRemove = true } label: {
                        Label("두뇌 지우기", systemImage: "trash")
                    }
                } footer: {
                    Text("끄면 직접 만든 규칙형 엔진만으로 답해요. 앱 기능 실행, 수학 풀이, 계산은 언제나 규칙형 엔진이 정확하게 처리해요.")
                }
            } else {
                Section {
                    Picker("크기", selection: $choice) {
                        ForEach(DoitBrain.Size.allCases) { size in
                            VStack(alignment: .leading) {
                                Text(size.title + (size == DoitBrain.Size.recommended ? " (이 기기 추천)" : ""))
                                Text(size.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            .tag(size)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Button {
                        Haptics.tap()
                        Task { await brain.install(choice) }
                    } label: {
                        Label(isDownloading ? "내려받는 중…" : "내려받기", systemImage: "arrow.down.circle.fill")
                            .font(.headline)
                    }
                    .disabled(isDownloading)
                } header: {
                    Text("내려받기")
                } footer: {
                    Text("와이파이에서 내려받는 걸 추천해요. 저장 공간이 \(choice == .standard ? "1.2" : "0.6")GB 정도 필요해요.")
                }
            }

            Section {
                if notes.isEmpty {
                    Text("아직 배운 내용이 없어요. 두뇌가 인터넷에서 찾아 정리한 내용, 👍를 받은 설명, \"기억해줘: …\"로 알려준 내용이 여기에 쌓여요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
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
                    Button(role: .destructive) { confirmForget = true } label: {
                        Label("배운 내용 모두 지우기", systemImage: "eraser")
                    }
                }
            } header: {
                Text("두잇 AI가 배운 내용 (\(notes.count))")
            } footer: {
                Text("배운 내용은 계정마다 따로, 이 기기에만 저장돼요. 다음에 비슷한 질문을 받으면 이 내용을 근거로 답해요.")
            }
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .navigationTitle("두잇 AI 두뇌")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: reload)
        .confirmationDialog("두뇌를 지울까요?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("지우기", role: .destructive) { brain.remove() }
        } message: {
            Text("다시 쓰려면 새로 내려받아야 해요. 배운 내용은 남아 있어요.")
        }
        .confirmationDialog("배운 내용을 모두 지울까요?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("모두 지우기", role: .destructive) { DoitMemory.shared.forgetAll(); reload() }
        }
    }

    private var isDownloading: Bool {
        switch brain.phase {
        case .downloading, .loading: return true
        default: return false
        }
    }

    private var statusText: String {
        guard DoitBrain.isSupported else { return "이 기기에서는 쓸 수 없어요" }
        switch brain.phase {
        case .notInstalled: return "아직 내려받지 않았어요"
        case .downloading: return "내려받는 중…"
        case .loading: return "불러오는 중…"
        case .ready: return brain.isEnabled ? "켜져 있어요 · 바로 답할 수 있어요" : "꺼져 있어요"
        case .sleeping: return brain.isEnabled ? "켜져 있어요 · 질문하면 깨어나요" : "꺼져 있어요"
        case .failed(let message): return message
        }
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

/// 두잇 AI 탭 첫 화면의 두뇌 안내 (내려받기 전, 내려받는 중)
struct BrainBanner: View {
    @State private var brain = DoitBrain.shared

    var body: some View {
        if DoitBrain.isSupported, !(brain.isInstalled && brain.isEnabled) || isWorking {
            NavigationLink {
                BrainSettingsView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                        Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
                .glassCard(cornerRadius: 20, padding: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private var isWorking: Bool {
        switch brain.phase {
        case .downloading, .loading: return true
        default: return false
        }
    }

    private var title: String {
        if case .downloading(let fraction) = brain.phase { return "두뇌 내려받는 중 \(Int(fraction * 100))%" }
        if brain.phase == .loading { return "두뇌를 깨우는 중…" }
        return brain.isInstalled ? "두잇 AI 두뇌가 꺼져 있어요" : "두잇 AI 두뇌 켜기"
    }

    private var detail: String {
        brain.isInstalled ? "켜면 인터넷에서 찾아 읽고 자기 말로 설명해요"
            : "폰 안에서 도는 AI를 내려받으면 더 자연스럽게 대화하고, 인터넷에서 찾아 정리하고, 스스로 배워요"
    }
}
