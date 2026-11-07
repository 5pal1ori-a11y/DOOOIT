import SwiftUI

/// 구조화된 공부 답: 한 줄 답 → 핵심 · 풀이 · 주의 · 예시 (+ 비교 표) → 다음 연습
/// 칸의 글은 모두 엔진 답이나 앱 안 자료의 글이에요 (DoitStructured).
struct StructuredAnswerView: View {
    let answer: DoitStructuredAnswer
    var onPractice: (VariantTopic) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(answer.title)
                    .font(.pt(.footnote))
                    .foregroundStyle(.secondary)
                headline
            }
            if let table = answer.table { tableView(table) }
            ForEach(Array(answer.sections.enumerated()), id: \.offset) { _, section in
                Hairline()
                sectionView(section)
            }
            if let topic = answer.practice {
                Hairline()
                practiceRow(topic)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private var headline: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let label = answer.headlineLabel {
                Text(label.loc)
                    .font(.pt(.footnote).weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(MathSymbolBar.pretty(answer.headline))
                    .font(.pt(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.ink)
            } else {
                Text(MathSymbolBar.pretty(answer.headline))
                    .font(.pt(.body).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(3)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionView(_ section: DoitStructuredAnswer.Section) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.label.loc)
                .font(.pt(.footnote).weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(Array(section.lines.enumerated()), id: \.offset) { index, line in
                if section.label == "풀이" {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "\(index + 1)")
                            .font(.pt(.footnote).weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 14, alignment: .trailing)
                        Text(MathSymbolBar.pretty(line)).font(.pt(.subheadline)).foregroundStyle(Palette.ink)
                    }
                } else {
                    Text(MathSymbolBar.pretty(line)).font(.pt(.subheadline)).foregroundStyle(Palette.ink)
                }
            }
        }
        .lineSpacing(3)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 비교 표: 첫 칸은 줄 이름, 나머지는 비교하는 것들 (얇은 선)
    private func tableView(_ table: DoitStructuredAnswer.Table) -> some View {
        let columns = table.header.count
        return Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(Array(table.header.enumerated()), id: \.offset) { _, title in
                    Text(title.loc)
                        .font(.pt(.footnote).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            }
            .background(Palette.cardInset)
            ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                Rectangle().fill(Palette.line).frame(height: 0.5).gridCellColumns(columns)
                GridRow(alignment: .firstTextBaseline) {
                    ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                        Text(MathSymbolBar.pretty(column == 0 ? cell.loc : cell))
                            .font(.pt(.footnote).weight(column == 0 ? .semibold : .regular))
                            .foregroundStyle(column == 0 ? Color.secondary : Palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .clipShape(.rect(cornerRadius: Radius.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Palette.line, lineWidth: 0.5))
    }

    private func practiceRow(_ topic: VariantTopic) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(DoitStructured.practiceLabel.loc)
                .font(.pt(.footnote).weight(.semibold))
                .foregroundStyle(.secondary)
            Button { onPractice(topic) } label: {
                HStack(spacing: 8) {
                    Text(L("변형 문제 \(DoitVariants.setSize)개"))
                        .font(.pt(.subheadline))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.pt(.footnote).weight(.semibold)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Palette.cardInset, in: .rect(cornerRadius: Radius.field, style: .continuous))
            }
            .buttonStyle(.pressable)
        }
    }
}
