import GoogleMobileAds
import Observation
import UIKit

/// Google AdMob 보상형 광고 (크레딧 얻기)
/// 광고 단위 ID는 Info.plist의 DOOOITAdMobRewardedID (빌드 설정 DOOOIT_ADMOB_REWARDED_ID)
@MainActor
@Observable
final class RewardedAdManager: NSObject, FullScreenContentDelegate {
    static let shared = RewardedAdManager()

    private(set) var isLoading = false
    private(set) var isShowing = false
    private(set) var lastError: String?
    var isReady: Bool { ad != nil }

    @ObservationIgnored private var ad: RewardedAd?
    @ObservationIgnored private var started = false
    @ObservationIgnored private var earned = false
    @ObservationIgnored private var finish: CheckedContinuation<Bool, Never>?

    private static var unitID: String {
        (Bundle.main.object(forInfoDictionaryKey: "DOOOITAdMobRewardedID") as? String) ?? ""
    }

    /// Google 테스트 광고 ID로 빌드된 경우
    static var isTestAd: Bool { unitID.hasPrefix("ca-app-pub-3940256099942544") }

    func start() {
        guard !started else { return }
        started = true
        MobileAds.shared.start()
        Task { await load() }
    }

    func load() async {
        guard ad == nil, !isLoading, !Self.unitID.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await RewardedAd.load(with: Self.unitID, request: Request())
            loaded.fullScreenContentDelegate = self
            ad = loaded
            lastError = nil
        } catch {
            ad = nil
            lastError = "광고를 불러오지 못했어요. 잠시 후 다시 시도해주세요."
            print("보상형 광고 로드 실패: \(error)")
        }
    }

    /// 광고를 끝까지 보면 true
    func show() async -> Bool {
        start()
        if ad == nil { await load() }
        guard let ad, !isShowing else { return false }
        isShowing = true
        earned = false
        return await withCheckedContinuation { continuation in
            finish = continuation
            // 보상 콜백은 광고가 닫히기 전에 메인 스레드에서 불림
            ad.present(from: nil) { [weak self] in
                MainActor.assumeIsolated { self?.earned = true }
            }
        }
    }

    private func complete() {
        isShowing = false
        ad = nil
        let result = earned
        finish?.resume(returning: result)
        finish = nil
        Task { await load() }
    }

    // MARK: FullScreenContentDelegate

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.complete() }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            self.lastError = "광고를 보여주지 못했어요. 다시 시도해주세요."
            self.complete()
        }
    }
}
