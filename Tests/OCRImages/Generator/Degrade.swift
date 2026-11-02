import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

// 휴대폰 사진처럼 망가뜨리기: 기울기, 원근, 흐림, 잡음, 고르지 않은 조명, 낮은 해상도, JPEG 압축

/// 같은 씨앗이면 늘 같은 결과 (테스트 사진이 매번 똑같이 나오게)
struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(_ seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> CGFloat { CGFloat(Double(next() >> 11) / Double(1 << 53)) }
    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * unit() }
    mutating func sign() -> CGFloat { next() & 1 == 0 ? -1 : 1 }
}

struct Degrade {
    var name: String
    var rotation: CGFloat = 0          // 도
    var perspective: CGFloat = 0       // 모서리 흔들림 (사진 크기 비율)
    var blur: CGFloat = 0              // 픽셀
    var noise: CGFloat = 0             // 0~255
    var lighting: CGFloat = 0          // 가장 어두운 곳 밝기 감소 (0~1)
    var scale: CGFloat = 1
    var jpeg: CGFloat = 0.9
    /// 책상 위 종이 사진 (종이 바깥 배경 + 원근)
    var desk = false
    /// 누런 종이
    var paperTint = false

    static let clean = Degrade(name: "clean", jpeg: 0.92)
    static let mild = Degrade(name: "mild", rotation: 1.2, blur: 0.6, noise: 6, lighting: 0.08, scale: 0.85, jpeg: 0.7)
    static let photo = Degrade(name: "photo", rotation: 2.5, perspective: 0.02, blur: 1.1, noise: 12, lighting: 0.22, scale: 0.8, jpeg: 0.6, paperTint: true)
    static let lowres = Degrade(name: "lowres", rotation: 0.8, blur: 0.5, noise: 5, lighting: 0.1, scale: 0.48, jpeg: 0.6)
    static let tilted = Degrade(name: "tilted", rotation: 4, blur: 0.7, noise: 8, lighting: 0.12, scale: 0.9, jpeg: 0.65)
    static let desk = Degrade(name: "desk", rotation: 2, perspective: 0.05, blur: 0.9, noise: 10, lighting: 0.2, scale: 0.9, jpeg: 0.6, desk: true, paperTint: true)
}

private let ciContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

func degrade(_ page: CGImage, _ d: Degrade, seed: UInt64) -> CGImage {
    var rng = SeededRandom(seed)
    var image = CIImage(cgImage: page)
    let w = CGFloat(page.width), h = CGFloat(page.height)
    let paper = d.paperTint ? CIColor(red: 0.97, green: 0.95, blue: 0.89) : CIColor(red: 1, green: 1, blue: 1)

    if d.paperTint {
        // 흰 바탕 → 누런 종이 (글자는 그대로 어둡게)
        let tint = CIFilter(name: "CIMultiplyCompositing")!
        tint.setValue(CIImage(color: paper).cropped(to: image.extent), forKey: kCIInputImageKey)
        tint.setValue(image, forKey: kCIInputBackgroundImageKey)
        image = tint.outputImage!.cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
    }

    let angle = d.rotation * rng.sign() * rng.range(0.7, 1.0) * .pi / 180
    if d.desk {
        // 책상(어두운 나무색) 위에 종이를 놓고 비스듬히 찍은 사진
        let pad = max(w, h) * 0.12
        let canvas = CGRect(x: 0, y: 0, width: w + pad * 2, height: h + pad * 2)
        func jitter() -> CGFloat { rng.range(-1, 1) * d.perspective * max(w, h) }
        let filter = CIFilter(name: "CIPerspectiveTransform")!
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: pad + jitter(), y: pad + h + jitter()), forKey: "inputTopLeft")
        filter.setValue(CIVector(x: pad + w + jitter(), y: pad + h + jitter()), forKey: "inputTopRight")
        filter.setValue(CIVector(x: pad + w + jitter(), y: pad + jitter()), forKey: "inputBottomRight")
        filter.setValue(CIVector(x: pad + jitter(), y: pad + jitter()), forKey: "inputBottomLeft")
        var moved = filter.outputImage!
        let center = CGPoint(x: canvas.midX, y: canvas.midY)
        moved = moved.transformed(by: CGAffineTransform(translationX: -center.x, y: -center.y)
            .concatenating(CGAffineTransform(rotationAngle: angle))
            .concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
        let deskColor = CIImage(color: CIColor(red: 0.42, green: 0.3, blue: 0.2)).cropped(to: canvas)
        image = moved.composited(over: deskColor).cropped(to: canvas)
    } else {
        var moved = image
        if d.perspective > 0 {
            func jitter() -> CGFloat { rng.range(-1, 1) * d.perspective * max(w, h) }
            let filter = CIFilter(name: "CIPerspectiveTransform")!
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(CIVector(x: jitter(), y: h + jitter()), forKey: "inputTopLeft")
            filter.setValue(CIVector(x: w + jitter(), y: h + jitter()), forKey: "inputTopRight")
            filter.setValue(CIVector(x: w + jitter(), y: jitter()), forKey: "inputBottomRight")
            filter.setValue(CIVector(x: jitter(), y: jitter()), forKey: "inputBottomLeft")
            moved = filter.outputImage!
        }
        if angle != 0 {
            moved = moved.transformed(by: CGAffineTransform(translationX: -w / 2, y: -h / 2)
                .concatenating(CGAffineTransform(rotationAngle: angle))
                .concatenating(CGAffineTransform(translationX: w / 2, y: h / 2)))
        }
        // 사진을 문제 부분만 잘라낸 것처럼: 원래 크기로 자르고 빈 모서리는 종이색
        let frame = CGRect(x: 0, y: 0, width: w, height: h)
        image = moved.composited(over: CIImage(color: paper).cropped(to: frame)).cropped(to: frame)
    }

    if d.blur > 0 {
        let extent = image.extent
        image = image.clampedToExtent().applyingGaussianBlur(sigma: Double(d.blur)).cropped(to: extent)
    }
    if d.scale != 1 {
        image = image.transformed(by: CGAffineTransform(scaleX: d.scale, y: d.scale))
    }
    let extent = image.extent.integral
    guard var cg = ciContext.createCGImage(image, from: extent) else { return page }

    if d.lighting > 0 || d.noise > 0 {
        cg = pixelEffects(cg, lighting: d.lighting, noise: d.noise, rng: &rng) ?? cg
    }
    return cg
}

/// 조명(한쪽이 어둡게) + 잡음: 픽셀을 직접 고침
private func pixelEffects(_ image: CGImage, lighting: CGFloat, noise: CGFloat, rng: inout SeededRandom) -> CGImage? {
    let width = image.width, height = image.height
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 255, count: bytesPerRow * height)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    return pixels.withUnsafeMutableBytes { buffer -> CGImage? in
        guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let p = buffer.bindMemory(to: UInt8.self)
        // 밝은 곳 (사진 안 한 점) 에서 멀수록 어둡게
        let lx = rng.range(0.1, 0.9) * CGFloat(width), ly = rng.range(0.1, 0.9) * CGFloat(height)
        let far = hypot(CGFloat(width), CGFloat(height))
        var noiseState = rng
        for y in 0..<height {
            for x in 0..<width {
                let dist = hypot(CGFloat(x) - lx, CGFloat(y) - ly) / far
                let light = 1 - lighting * min(1, dist * 1.4)
                let n = noise > 0 ? (noiseState.unit() - 0.5) * 2 * noise : 0
                let i = y * bytesPerRow + x * 4
                for c in 0..<3 {
                    let v = CGFloat(p[i + c]) * light + n
                    p[i + c] = UInt8(max(0, min(255, v)))
                }
            }
        }
        return ctx.makeImage()
    }
}

func writeJPEG(_ image: CGImage, to url: URL, quality: CGFloat) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
    return CGImageDestinationFinalize(dest)
}
