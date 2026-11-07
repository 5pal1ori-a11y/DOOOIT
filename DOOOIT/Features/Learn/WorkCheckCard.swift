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
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(Motion.spring) { expanded.toggle() }
            } label: {
                HStack {
                    header
                    Image(systemName: "chevron.down")
                        .font(.pt(.caption).weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isOpen { content }
        }
        .softCard()
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
                    Text("풀이 글씨를 읽고 있어요").font(.pt(.subheadline)).foregroundStyle(Palette.ink)
                }
                .transition(.opacity)
            }

            if !note.workText.isEmpty || isEditing {
                workEditor
            }

            if let message {
                Label(message, systemImage: "info.circle")
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
            }

            if let report {
                ReportView(report: report, explanation: explanation)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("풀이 과정 채점").font(.pt(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                Text("내 풀이에서 틀린 줄을 찾아요")
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var sourceButtons: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                sourceButton(L("풀이 사진 찍기"), symbol: "camera.fill") {
                    showScanner = DocumentScanner.isSupported
                    showPhotoPicker = !DocumentScanner.isSupported
                }
                sourceButton(L("앨범"), symbol: "photo.on.rectangle") { showPhotoPicker = true }
                if note.drawingData != nil {
                    sourceButton(L("내 필기 읽기"), symbol: "pencil") {
                        Task { await readDrawing() }
                    }
                }
                sourceButton(L("직접 쓰기"), symbol: "keyboard") {
                    withAnimation(Motion.spring) { isEditing = true }
                }
            }
        }
        .scrollIndicators(.hidden)
        .disabled(reading || checking)
    }

    private func sourceButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol.outlineSymbol)
                .environment(\.symbolVariants, .none)
                .font(.pt(.footnote).weight(.semibold))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Theme.secondaryFill, in: .rect(cornerRadius: Radius.field, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private var workEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("내 풀이").font(.pt(.subheadline).weight(.semibold)).foregroundStyle(Palette.ink)
                Text("한 줄에 한 단계씩").font(.pt(.footnote)).foregroundStyle(.secondary)
                Spacer()
            }
            TextEditor(text: $note.workText)
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(Palette.ink)
                .frame(minHeight: 110)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
            Text("잘못 읽힌 글자는 고친 뒤 채점하세요. 예: 2x = 11 − 3 ⏎ 2x = 8 ⏎ x = 4")
                .font(.pt(.caption2))
                .foregroundStyle(.secondary)
            Button {
                Task { await check() }
            } label: {
                HStack(spacing: 8) {
                    if checking { ProgressView().tint(Theme.onAccent) }
                    Text("채점하기")
                }
            }
            .buttonStyle(.flatProminent)
            .disabled(workLines.isEmpty || checking || note.recognizedText.isEmpty)
            if note.recognizedText.isEmpty {
                Text("먼저 '문제' 탭에서 문제 글이 있어야 채점할 수 있어요.")
                    .font(.pt(.footnote))
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
            message = L("필기가 없어요. '필기' 탭에서 풀이를 써주세요.")
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
            message = L("글씨를 찾지 못했어요. 밝은 곳에서 풀이가 잘 보이게 다시 찍어주세요.")
            return
        }
        note.workText = lines.joined(separator: "\n")
        note.workCheckData = nil
        explanation = nil
        message = L("읽은 풀이를 확인하고 틀린 글자가 있으면 고친 뒤 채점하세요.")
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
            // 한 줄 판정 (헤어라인 사이)
            HStack(spacing: 8) {
                Image(systemName: report.allGood ? "checkmark.circle" : "exclamationmark.triangle")
                    .environment(\.symbolVariants, .none)
                    .font(.pt(size: 18, weight: .regular))
                    .foregroundStyle(report.allGood ? Palette.success : Palette.warning)
                Text(report.verdict)
                    .font(.pt(.subheadline).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Hairline() }
            .overlay(alignment: .bottom) { Hairline() }

            // 줄마다
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(report.lines.enumerated()), id: \.element.id) { index, line in
                    row(index: index, line: line, isLast: index == report.lines.count - 1)
                        .appearAnimation(delay: Double(index) * 0.06)
                }
            }

            ForEach(report.tips, id: \.self) { tip in
                Text(tip)
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !report.correctAnswer.isEmpty && !report.allGood {
                HStack(spacing: 8) {
                    FlowLabel(L("정답"))
                    Text(MathSymbolBar.pretty(report.correctAnswer.components(separatedBy: "\n").first ?? report.correctAnswer))
                        .font(.pt(.subheadline).weight(.semibold))
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
        case .skipped: return Color.secondary
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
                    .font(.pt(.caption).weight(.bold))
                    .foregroundStyle(color(line.mark))
                    .frame(width: 22, height: 22)
                if !isLast {
                    Rectangle().fill(Palette.line).frame(width: 0.5).frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(index + 1). \(MathSymbolBar.pretty(line.text))")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(line.mark == .wrong ? Palette.danger : Palette.ink)
                if !line.note.isEmpty {
                    Text(line.note)
                        .font(.pt(.footnote))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, isLast ? 0 : 12)
            Spacer(minLength: 0)
        }
    }
}
