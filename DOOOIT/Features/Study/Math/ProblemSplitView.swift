import SwiftUI

/// 문제 번호로 자동으로 나눈 한 쪽(페이지)
struct SplitItem: Identifiable {
    let id = UUID()
    let image: UIImage
    let regions: [ProblemSplitter.Region]
    /// regions와 같은 순서로 잘라 둔 문제 사진
    let crops: [UIImage]
}

/// 한 사진에서 찾은 문제들을 확인하는 화면: 눌러서 빼기/넣기 · 직접 자르기 · n개 문제로 만들기
struct ProblemSplitView: View {
    let item: SplitItem
    var onDone: ([UIImage]) -> Void
    var onManual: () -> Void
    var onCancel: () -> Void

    /// 뺀 문제 번호
    @State private var excluded: Set<Int> = []

    private struct Pair: Identifiable {
        let region: ProblemSplitter.Region
        let crop: UIImage
        var id: Int { region.number }
    }

    private var pairs: [Pair] {
        zip(item.regions, item.crops).map { Pair(region: $0, crop: $1) }
    }

    private var selectedCrops: [UIImage] {
        pairs.filter { !excluded.contains($0.region.number) }.map(\.crop)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("문제 번호로 \(pairs.count)개를 찾았어요.\n빼고 싶은 문제는 눌러서 끌 수 있어요.")
                        .font(.pt(.subheadline))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    pagePreview

                    SectionTitle(title: L("나눈 문제")) {
                        Text("\(selectedCrops.count)/\(pairs.count)개")
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(pairs) { pair in
                            thumbnail(pair.region, crop: pair.crop)
                        }
                    }

                    Button(action: onManual) {
                        Label("직접 자르기", systemImage: "crop")
                            .font(.pt(.subheadline).weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
                .animation(Motion.spring, value: excluded)
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onDone(selectedCrops)
                } label: {
                    Text(selectedCrops.isEmpty ? L("만들 문제를 골라주세요") : L("\(selectedCrops.count)개 문제로 만들기"))
                }
                .buttonStyle(.primaryFill)
                .disabled(selectedCrops.isEmpty)
                .opacity(selectedCrops.isEmpty ? 0.5 : 1)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .navigationTitle("문제 나누기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
            }
        }
    }

    /// 페이지 전체 + 찾은 문제마다 번호 붙은 네모 (눌러서 빼기/넣기)
    private var pagePreview: some View {
        // 세로로 긴 페이지는 높이를 정해 두고 그 안에 맞춤 (네모 위치는 맞춘 사진 크기 기준)
        let isPortrait = item.image.size.height >= item.image.size.width
        return Image(uiImage: item.image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geo in
                    ForEach(pairs) { pair in
                        let rect = pair.region.topLeftRect
                        let isOn = !excluded.contains(pair.region.number)
                        let frame = CGRect(x: rect.minX * geo.size.width, y: rect.minY * geo.size.height,
                                           width: rect.width * geo.size.width, height: rect.height * geo.size.height)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isOn ? Theme.accent.opacity(0.10) : Color.black.opacity(0.35))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(isOn ? Theme.accent : Color.secondary,
                                                  style: StrokeStyle(lineWidth: 2, dash: isOn ? [] : [5, 4]))
                            }
                            .overlay(alignment: .topLeading) {
                                numberBadge(pair.region.number, isOn: isOn).padding(4)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { toggle(pair.region.number) }
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08)))
            .frame(height: isPortrait ? 460 : nil)
            .frame(maxWidth: .infinity)
    }

    /// 잘라 낸 문제 한 칸 (켜짐: 강조 테두리 + 체크)
    private func thumbnail(_ region: ProblemSplitter.Region, crop: UIImage) -> some View {
        let isOn = !excluded.contains(region.number)
        return Button {
            toggle(region.number)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(uiImage: crop)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(.rect(cornerRadius: 10))
                    .opacity(isOn ? 1 : 0.35)
                HStack(spacing: 6) {
                    Text("\(region.number)번")
                        .font(.pt(.subheadline).weight(.bold))
                        .foregroundStyle(isOn ? Palette.ink : Color.secondary)
                    Spacer(minLength: 4)
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.pt(.title3))
                        .foregroundStyle(isOn ? Theme.accent : Color.secondary)
                }
            }
            .padding(10)
            .softCardBackground(cornerRadius: 16)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isOn ? Theme.accent : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("\(region.number)번 문제")
        .accessibilityValue(isOn ? L("포함") : L("제외"))
    }

    private func numberBadge(_ number: Int, isOn: Bool) -> some View {
        Text("\(number)")
            .font(.pt(.caption).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 7)
            .frame(minWidth: 22, minHeight: 22)
            .background(isOn ? Theme.accent : Color.gray, in: .capsule)
    }

    private func toggle(_ number: Int) {
        if excluded.contains(number) { excluded.remove(number) } else { excluded.insert(number) }
        Haptics.tap()
    }
}
