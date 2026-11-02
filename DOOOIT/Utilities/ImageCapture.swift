import PhotosUI
import SwiftUI
import VisionKit

/// 문서 스캐너 (자동으로 종이 영역을 잘라주는 카메라)
struct DocumentScanner: UIViewControllerRepresentable {
    var onFinish: ([UIImage]) -> Void

    static var isSupported: Bool { VNDocumentCameraViewController.isSupported }

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void

        init(onFinish: @escaping ([UIImage]) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            onFinish(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish([])
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            onFinish([])
        }
    }
}

/// 여러 장의 사진을 묶어서 전달하기 위한 래퍼
struct ImageBatch: Identifiable {
    let id = UUID()
    let images: [UIImage]
}

enum PhotoLoader {
    static func load(_ items: [PhotosPickerItem]) async -> [UIImage] {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        return images
    }
}

/// "촬영 / 앨범" 이미지 입력을 한 곳에서 처리하는 modifier
struct ImageInputModifier: ViewModifier {
    @Binding var showScanner: Bool
    @Binding var photoItems: [PhotosPickerItem]
    @Binding var showPhotoPicker: Bool
    var maxPhotos: Int = 5
    /// 앨범 사진에서 종이 부분만 잘라 반듯하게 펴기 (단어장·문제 사진용)
    var straighten = false
    var onImages: ([UIImage]) -> Void

    @State private var scanned: [UIImage] = []

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $showScanner, onDismiss: {
                if !scanned.isEmpty {
                    let images = scanned
                    scanned = []
                    onImages(images)
                }
            }) {
                DocumentScanner { images in
                    scanned = images
                    showScanner = false
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoItems, maxSelectionCount: maxPhotos, matching: .images)
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    let loaded = await PhotoLoader.load(items)
                    var images = loaded
                    if straighten {
                        images = []
                        for image in loaded { images.append(await OCRService.straightened(image)) }
                    }
                    photoItems = []
                    if !images.isEmpty { onImages(images) }
                }
            }
    }
}

extension View {
    func imageInput(showScanner: Binding<Bool>, showPhotoPicker: Binding<Bool>, photoItems: Binding<[PhotosPickerItem]>,
                    maxPhotos: Int = 5, straighten: Bool = false, onImages: @escaping ([UIImage]) -> Void) -> some View {
        modifier(ImageInputModifier(showScanner: showScanner, photoItems: photoItems, showPhotoPicker: showPhotoPicker,
                                    maxPhotos: maxPhotos, straighten: straighten, onImages: onImages))
    }
}
