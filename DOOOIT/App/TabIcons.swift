import SwiftUI
import UIKit

/// 탭 바 아이콘 (얇고 둥근 선): 집 · 기울어진 책 · 오늘 날짜가 적힌 달력
/// SF Symbols에 없는 모양이라 직접 그려서 탭 바가 색을 입히는 template 이미지로 씀
@MainActor
enum TabIcons {
    /// 한 번 그린 이미지는 다시 쓰기 (달력은 날짜가 바뀌면 새로)
    private static var cache: [String: UIImage] = [:]

    static func home() -> UIImage { image("home") { HomeGlyph() } }
    static func book() -> UIImage { image("book") { BookGlyph() } }
    static func calendar(day: Int = Calendar.current.component(.day, from: Date())) -> UIImage {
        image("calendar-\(day)") { CalendarGlyph(day: day) }
    }

    private static func image<Content: View>(_ key: String, @ViewBuilder _ content: () -> Content) -> UIImage {
        if let cached = cache[key] { return cached }
        let renderer = ImageRenderer(content: content().frame(width: 26, height: 26).foregroundStyle(.black))
        renderer.scale = 3
        let image = (renderer.uiImage ?? UIImage()).withRenderingMode(.alwaysTemplate)
        cache[key] = image
        return image
    }
}

private let lineWidth: CGFloat = 1.7
private var lineStyle: StrokeStyle { StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round) }

/// 둥근 집 (가운데 아치 문)
private struct HomeGlyph: View {
    var body: some View {
        Canvas { context, _ in
            var roof = Path()
            roof.move(to: CGPoint(x: 3.6, y: 12.2))
            roof.addLine(to: CGPoint(x: 13, y: 4.4))
            roof.addLine(to: CGPoint(x: 22.4, y: 12.2))
            var body = Path()
            body.move(to: CGPoint(x: 6.3, y: 10.2))
            body.addLine(to: CGPoint(x: 6.3, y: 19.2))
            body.addQuadCurve(to: CGPoint(x: 8.3, y: 21.2), control: CGPoint(x: 6.3, y: 21.2))
            body.addLine(to: CGPoint(x: 10.6, y: 21.2))
            body.addLine(to: CGPoint(x: 10.6, y: 17.3))
            body.addArc(center: CGPoint(x: 13, y: 17.3), radius: 2.4, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            body.addLine(to: CGPoint(x: 15.4, y: 21.2))
            body.addLine(to: CGPoint(x: 17.7, y: 21.2))
            body.addQuadCurve(to: CGPoint(x: 19.7, y: 19.2), control: CGPoint(x: 19.7, y: 21.2))
            body.addLine(to: CGPoint(x: 19.7, y: 10.2))
            context.stroke(roof, with: .foreground, style: lineStyle)
            context.stroke(body, with: .foreground, style: lineStyle)
        }
    }
}

/// 살짝 기울어진 덮인 책 (아래쪽에 책장 두께)
private struct BookGlyph: View {
    var body: some View {
        Canvas { context, size in
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: .degrees(-24))
            context.translateBy(x: -size.width / 2, y: -size.height / 2)
            // 표지
            let cover = Path(roundedRect: CGRect(x: 7.2, y: 3.4, width: 12.2, height: 16.6), cornerRadius: 1.8)
            // 책장 두께: 왼쪽 아래로 이어지는 선
            var pages = Path()
            pages.move(to: CGPoint(x: 7.2, y: 18.2))
            pages.addLine(to: CGPoint(x: 5.6, y: 20.4))
            pages.addQuadCurve(to: CGPoint(x: 7.0, y: 22.6), control: CGPoint(x: 5.0, y: 22.6))
            pages.addLine(to: CGPoint(x: 17.6, y: 22.6))
            pages.addLine(to: CGPoint(x: 19.4, y: 20.0))
            context.stroke(cover, with: .foreground, style: lineStyle)
            context.stroke(pages, with: .foreground, style: lineStyle)
        }
    }
}

/// 고리 두 개가 달린 달력 + 오늘 날짜
private struct CalendarGlyph: View {
    let day: Int

    var body: some View {
        ZStack {
            Canvas { context, _ in
                let frame = Path(roundedRect: CGRect(x: 3.6, y: 5.4, width: 18.8, height: 17.4), cornerRadius: 3.4)
                var rings = Path()
                rings.move(to: CGPoint(x: 8.8, y: 3.2)); rings.addLine(to: CGPoint(x: 8.8, y: 7.4))
                rings.move(to: CGPoint(x: 17.2, y: 3.2)); rings.addLine(to: CGPoint(x: 17.2, y: 7.4))
                var header = Path()
                header.move(to: CGPoint(x: 3.6, y: 10.0)); header.addLine(to: CGPoint(x: 22.4, y: 10.0))
                context.stroke(frame, with: .foreground, style: lineStyle)
                context.stroke(rings, with: .foreground, style: lineStyle)
                context.stroke(header, with: .foreground, style: lineStyle)
            }
            Text("\(day)")
                .font(.pt(size: 9.5, weight: .semibold))
                .monospacedDigit()
                .offset(y: 3.4)
        }
    }
}
