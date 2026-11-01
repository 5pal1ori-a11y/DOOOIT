import SwiftUI

struct CropItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// 사진에서 인쇄된 문제 부분만 네모로 골라 글자를 읽게 하는 화면
struct ProblemCropView: View {
    let image: UIImage
    var onDone: (UIImage) -> Void
    var onCancel: () -> Void

    @State private var rect = CGRect(x: 0.04, y: 0.04, width: 0.92, height: 0.5)
    @State private var startRect: CGRect?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("인쇄된 문제 부분만 네모 안에 넣어주세요.\n손글씨 풀이를 빼면 훨씬 정확하게 읽어요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                GeometryReader { geo in
                    let fit = fittedSize(image.size, in: geo.size)
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: fit.width, height: fit.height)

                        // 선택 영역 밖은 어둡게
                        Path { path in
                            path.addRect(CGRect(origin: .zero, size: fit))
                            path.addRect(CGRect(x: rect.minX * fit.width, y: rect.minY * fit.height,
                                                width: rect.width * fit.width, height: rect.height * fit.height))
                        }
                        .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
                        .allowsHitTesting(false)

                        // 영역 이동
                        Rectangle()
                            .stroke(Theme.accent, lineWidth: 2.5)
                            .background(Color.white.opacity(0.001))
                            .frame(width: rect.width * fit.width, height: rect.height * fit.height)
                            .position(x: rect.midX * fit.width, y: rect.midY * fit.height)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let start = startRect ?? rect
                                        if startRect == nil { startRect = rect }
                                        var moved = start.offsetBy(dx: value.translation.width / fit.width,
                                                                   dy: value.translation.height / fit.height)
                                        moved.origin.x = min(max(0, moved.origin.x), 1 - moved.width)
                                        moved.origin.y = min(max(0, moved.origin.y), 1 - moved.height)
                                        rect = moved
                                    }
                                    .onEnded { _ in startRect = nil }
                            )

                        // 모서리로 크기 조절
                        ForEach(0..<4, id: \.self) { corner in
                            handle(corner, fit: fit)
                        }
                    }
                    .frame(width: fit.width, height: fit.height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }

                Button {
                    onDone(Self.crop(image, to: CGRect(x: 0, y: 0, width: 1, height: 1)))
                } label: {
                    Text("사진 전체 읽기").font(.subheadline.weight(.semibold))
                }
            }
            .padding(16)
            .navigationTitle("문제 영역 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("이 영역 읽기") { onDone(Self.crop(image, to: rect)) }
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func handle(_ corner: Int, fit: CGSize) -> some View {
        let isLeft = corner % 2 == 0
        let isTop = corner < 2
        let x = (isLeft ? rect.minX : rect.maxX) * fit.width
        let y = (isTop ? rect.minY : rect.maxY) * fit.height
        return Circle()
            .fill(Color.white)
            .frame(width: 24, height: 24)
            .overlay { Circle().stroke(Theme.accent, lineWidth: 3) }
            .shadow(radius: 2)
            .position(x: x, y: y)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = startRect ?? rect
                        if startRect == nil { startRect = rect }
                        let dx = value.translation.width / fit.width
                        let dy = value.translation.height / fit.height
                        var minX = start.minX, maxX = start.maxX, minY = start.minY, maxY = start.maxY
                        if isLeft { minX = min(max(0, start.minX + dx), maxX - 0.1) } else { maxX = max(min(1, start.maxX + dx), minX + 0.1) }
                        if isTop { minY = min(max(0, start.minY + dy), maxY - 0.1) } else { maxY = max(min(1, start.maxY + dy), minY + 0.1) }
                        rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                    }
                    .onEnded { _ in startRect = nil }
            )
    }

    private func fittedSize(_ size: CGSize, in box: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0, box.width > 0, box.height > 0 else { return box }
        let scale = min(box.width / size.width, box.height / size.height)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    /// rect는 0~1 비율 좌표
    static func crop(_ image: UIImage, to rect: CGRect) -> UIImage {
        let base = image.resized(maxDimension: 3000) // 방향을 바로잡은 이미지
        guard let cg = base.cgImage else { return image }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let area = CGRect(x: rect.minX * w, y: rect.minY * h, width: rect.width * w, height: rect.height * h).integral
        guard let cropped = cg.cropping(to: area) else { return base }
        return UIImage(cgImage: cropped)
    }
}
