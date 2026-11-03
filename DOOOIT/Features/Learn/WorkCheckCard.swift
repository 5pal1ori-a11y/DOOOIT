import PencilKit
import PhotosUI
import SwiftData
import SwiftUI

/// 오답노트: 내 풀이 과정 채점 (손글씨 풀이 → 줄마다 맞았는지, 어디서 처음 틀렸는지)
struct WorkCheckCard: View {
    @Bindable var note: MathNote
    @Environment(\.modelContext) private var context

    @State private var reading = false
    @State private var checking = false
    @State private var showScanner = false
    @State private var showPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isEditing = false
    @State private var explanation: String?
    @State private var message: String?
    /// 처음에는 접어 둠 (풀이를 이미 넣었거나 채점했으면 펼침)
    @State private var expanded = false

    private var report: DoitWorkChecker.Report? {
        note.workCheckData.flatMap { try? JSONDecoder().decode(DoitWorkChecker.Report.self, from: $0) }
    }

    private var workLines: [String] {
        note.workText.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(Motion.spring) { expanded.toggle() }
            } label: {
                HStack {
                    header
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen { content }
        }
        .padding(18)
        .background(Palette.card, in: .rect(cornerRadius: 26))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .animation(Motion.spring, value: note.workCheckData)
        .animation(Motion.spring, value: reading)
        .imageInput(showScanner: $showScanner, showPhotoPicker: $showPhotoPicker, photoItems: $photoItems, maxPhotos: 1) { images in
            guard let image = images.first else { return }
            Task { await read(image) }
        }
    }

    private var isOpen: Bool { expanded || report != nil || !note.workText.isEmpty || isEditing || reading }

    @ViewBuilder private var content: some View {
            sourceButtons

            if reading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("풀이 글씨를 읽고 있어요").font(.subheadline.weight(.semibold))
                }
                .transition(.opacity)
            }

            if !note.workText.isEmpty || isEditing {
                workEditor
            }

            if let message {
                Label(message, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let report {
                ReportView(report: report, explanation: explanation)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Palette.success.gradient, in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text("풀이 과정 채점").font(.headline).foregroundStyle(Palette.ink)
                Text("내 풀이에서 틀린 줄을 찾아요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var sourceButtons: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                sourceButton("풀이 사진 찍기", symbol: "camera.fill") {
                    showScanner = DocumentScanner.isSupported
                    showPhotoPicker = !DocumentScanner.isSupported
                }
                sourceButton("앨범", symbol: "photo.on.rectangle") { showPhotoPicker = true }
                if note.drawingData != nil {
                    sourceButton("내 필기 읽기", symbol: "pencil.and.scribble") {
                        Task { await readDrawing() }
                    }
                }
                sourceButton("직접 쓰기", symbol: "keyboard") {
                    withAnimation(Motion.spring) { isEditing = true }
                }
            }
        }
        .scrollIndicators(.hidden)
        .disabled(reading || checking)
    }

    private func sourceButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.accent.opacity(0.1), in: .capsule)
        }
        .buttonStyle(.pressable)
    }

    private var workEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("내 풀이").font(.subheadline.weight(.bold)).foregroundStyle(Palette.ink)
                Text("한 줄에 한 단계씩").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            TextEditor(text: $note.workText)
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Color.black.opacity(0.04), in: .rect(cornerRadius: 14))
            Text("잘못 읽힌 글자는 고친 뒤 채점하세요. 예: 2x = 11 − 3 ⏎ 2x = 8 ⏎ x = 4")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button {
                Task { await check() }
            } label: {
                HStack {
                    if checking { ProgressView().tint(.white) }
                    Label("채점하기", systemImage: "checkmark.circle")
                }
                .font(.body.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(.glassProminent)
            .disabled(workLines.isEmpty || checking || note.recognizedText.isEmpty)
            if note.recognizedText.isEmpty {
                Text("먼저 '문제' 탭에서 문제 글이 있어야 채점할 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(Palette.danger)
            }
        }
    }

    // MARK: Actions

    private func read(_ image: UIImage) async {
        reading = true
        defer { reading = false }
        let lines = await OCRService.readHandwriting(image)
        apply(lines)
    }

    /// 오답노트에 펜으로 쓴 필기를 흰 바탕 그림으로 만들어서 읽음
    private func readDrawing() async {
        guard let data = note.drawingData, let drawing = try? PKDrawing(data: data), !drawing.bounds.isEmpty else {
            message = "필기가 없어요. '필기' 탭에서 풀이를 써주세요."
            return
        }
        reading = true
        defer { reading = false }
        let bounds = drawing.bounds.insetBy(dx: -24, dy: -24)
        let ink = drawing.image(from: bounds, scale: 2)
        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: bounds.size))
            ink.draw(in: CGRect(origin: .zero, size: bounds.size))
        }
        let lines = await OCRService.readHandwriting(image)
        apply(lines)
    }

    private func apply(_ lines: [String]) {
        guard !lines.isEmpty else {
            message = "글씨를 찾지 못했어요. 밝은 곳에서 풀이가 잘 보이게 다시 찍어주세요."
            return
        }
        note.workText = lines.joined(separator: "\n")
        note.workCheckData = nil
        explanation = nil
        message = "읽은 풀이를 확인하고 틀린 글자가 있으면 고친 뒤 채점하세요."
        withAnimation(Motion.spring) { isEditing = true }
        try? context.save()
    }

    private func check() async {
        checking = true
        defer { checking = false }
        explanation = nil
        message = nil
        let result = DoitWorkChecker.check(problem: note.recognizedText, work: workLines)
        note.workCheckData = try? JSONEncoder().encode(result)
        try? context.save()
        if result.allGood { Haptics.success() } else { Haptics.error() }
    }
}

// MARK: - 채점 결과

private struct ReportView: View {
    let report: DoitWorkChecker.Report
    let explanation: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 한 줄 판정
            HStack(spacing: 10) {
                Image(systemName: report.allGood ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(report.allGood ? Palette.success : Palette.warning)
                    .symbolEffect(.bounce, value: report.verdict)
                Text(report.verdict)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((report.allGood ? Palette.success : Palette.warning).opacity(0.12), in: .rect(cornerRadius: 14))

            // 줄마다
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(report.lines.enumerated()), id: \.element.id) { index, line in
                    row(index: index, line: line, isLast: index == report.lines.count - 1)
                        .appearAnimation(delay: Double(index) * 0.06)
                }
            }

            ForEach(report.tips, id: \.self) { tip in
                Label(tip, systemImage: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !report.correctAnswer.isEmpty && !report.allGood {
                HStack(spacing: 6) {
                    Text("정답").font(.caption.weight(.bold)).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Palette.success, in: .capsule)
                    Text(MathSymbolBar.pretty(report.correctAnswer.components(separatedBy: "\n").first ?? report.correctAnswer))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                }
            }
        }
    }

    private func color(_ mark: DoitWorkChecker.Mark) -> Color {
        switch mark {
        case .ok: return Palette.success
        case .wrong: return Palette.danger
        case .carried: return Palette.warning
        case .skipped: return Color.secondary.opacity(0.5)
        }
    }

    private func symbol(_ mark: DoitWorkChecker.Mark) -> String {
        switch mark {
        case .ok: return "checkmark"
        case .wrong: return "xmark"
        case .carried: return "arrow.turn.down.right"
        case .skipped: return "minus"
        }
    }

    private func row(index: Int, line: DoitWorkChecker.Line, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: symbol(line.mark))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(color(line.mark), in: .circle)
                if !isLast {
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(index + 1). \(MathSymbolBar.pretty(line.text))")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(line.mark == .wrong ? Palette.danger : Palette.ink)
                if !line.note.isEmpty {
                    Text(line.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, isLast ? 0 : 14)
            Spacer(minLength: 0)
        }
    }
}
