import SwiftUI

/// 이용약관 · 개인정보 처리방침 보기
struct LegalDocumentView: View {
    let kind: LegalText.Kind

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("시행일 \(LegalText.effectiveDate)")
                    .font(.pt(.caption))
                    .foregroundStyle(.secondary)
                ForEach(kind.sections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.pt(.subheadline).weight(.bold))
                            .foregroundStyle(Palette.ink)
                        Text(section.body)
                            .font(.pt(.subheadline))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background { AppBackground() }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 가입할 때 동의: [필수] 이용약관 · 개인정보 처리방침 (눌러서 읽기)
struct LegalConsentRow: View {
    @Binding var agreed: Bool
    @State private var reading: LegalText.Kind?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                agreed.toggle()
                Haptics.tap()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: agreed ? "checkmark.circle.fill" : "circle")
                        .font(.pt(.title3))
                        .foregroundStyle(agreed ? Theme.accent : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                    Text("[필수] 이용약관과 개인정보 처리방침에 동의해요")
                        .font(.pt(.subheadline).weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(agreed ? .isSelected : [])

            HStack(spacing: 14) {
                link(.terms)
                link(.privacy)
                Spacer(minLength: 0)
            }
            .padding(.leading, 34)

            Text("만 14세 미만은 보호자 동의 후 이용해 주세요")
                .font(.pt(.caption2))
                .foregroundStyle(.tertiary)
                .padding(.leading, 34)
        }
        .sheet(item: $reading) { kind in
            NavigationStack {
                LegalDocumentView(kind: kind)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) { Button("확인") { reading = nil } }
                    }
            }
        }
    }

    private func link(_ kind: LegalText.Kind) -> some View {
        Button {
            reading = kind
        } label: {
            Text("\(kind.title) 보기")
                .font(.pt(.caption).weight(.semibold))
                .underline()
                .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
    }
}
