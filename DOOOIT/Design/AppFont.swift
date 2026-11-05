import CoreText
import SwiftUI
import UIKit

/// 앱 글꼴: Pretendard (SIL 오픈 폰트 라이선스, Resources/Fonts/Pretendard-LICENSE.txt)
/// - 글자 크기는 시스템 글자 크기 설정(다이내믹 타입)을 그대로 따름
/// - 없는 글자는 iOS가 시스템 글꼴로 대신 보여 줌
enum AppFont {
    static let family = "Pretendard"

    /// 앱을 켤 때 한 번: 번들의 Pretendard 글꼴을 등록하고, 내비게이션 제목도 같은 글꼴로
    static func register() {
        for url in Bundle.main.urls(forResourcesWithExtension: "otf", subdirectory: nil) ?? []
        where url.lastPathComponent.hasPrefix("Pretendard") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        let nav = UINavigationBar.appearance()
        if let title = UIFont(name: "Pretendard-SemiBold", size: 17) {
            nav.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: title)]
        }
        if let large = UIFont(name: "Pretendard-Bold", size: 34) {
            nav.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        }
    }

    /// 글자 스타일별 기본 크기 (시스템과 같음)
    static func size(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .subheadline: 15
        case .body: 17
        case .callout: 16
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }
}

extension Font {
    /// Pretendard로 된 글자 스타일 (.headline은 시스템처럼 조금 굵게)
    static func pt(_ style: Font.TextStyle) -> Font {
        let font = Font.custom(AppFont.family, size: AppFont.size(style), relativeTo: style)
        return style == .headline ? font.weight(.semibold) : font
    }

    /// Pretendard로 된 정한 크기 글자 (design은 무시: 모양을 하나로 맞춤)
    static func pt(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design? = nil) -> Font {
        Font.custom(AppFont.family, size: size).weight(weight)
    }
}
