import PhotosUI
import SwiftUI
import UIKit

/// 프로필 사진 저장소: 계정마다 사진 한 장 (이 기기 안에만 저장, 서버로 보내지 않아요)
enum ProfilePhotoStore {
    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("ProfilePhotos", isDirectory: true)
    }

    private static func url(for accountID: String) -> URL {
        let safe = accountID.map { $0.isLetter || $0.isNumber ? String($0) : "_" }.joined()
        return folder.appendingPathComponent("\(safe).jpg")
    }

    static func load(for accountID: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: accountID).path)
    }

    /// 가운데를 정사각형으로 잘라 512px JPEG로 저장
    @discardableResult
    static func save(_ data: Data, for accountID: String) -> Bool {
        guard let image = UIImage(data: data) else { return false }
        let side = min(image.size.width, image.size.height) * image.scale
        guard side > 0 else { return false }
        let target = CGSize(width: 512, height: 512)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let square = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            let scale = max(target.width / image.size.width, target.height / image.size.height)
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (target.width - drawSize.width) / 2, y: (target.height - drawSize.height) / 2,
                                  width: drawSize.width, height: drawSize.height))
        }
        guard let jpeg = square.jpegData(compressionQuality: 0.85) else { return false }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (try? jpeg.write(to: url(for: accountID), options: .atomic)) != nil
    }

    static func remove(for accountID: String) {
        try? FileManager.default.removeItem(at: url(for: accountID))
    }
}

/// 둥근 프로필 사진 (사진이 없으면 이름 첫 글자)
struct ProfileAvatar: View {
    let accountID: String
    let name: String
    var size: CGFloat = 60
    /// 사진을 바꾸면 다시 그리기 위한 값
    var version: Int = 0

    var body: some View {
        Group {
            if let image = ProfilePhotoStore.load(for: accountID) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(String(name.loc.prefix(1)))
                    .font(.pt(size: size * 0.43, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.accent)
            }
        }
        .id(version)
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}
