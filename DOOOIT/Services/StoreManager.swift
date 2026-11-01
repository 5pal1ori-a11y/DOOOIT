import Observation
import StoreKit

/// 크레딧 상점 (App Store 인앱 결제, StoreKit 2)
/// 상품은 App Store Connect > 앱 > 수익화 > 인앱 구입 / 구독에 같은 ID로 등록해야 보여요
@MainActor
@Observable
final class StoreManager {
    static let shared = StoreManager()

    enum ID {
        static let firstPack = "com.bravekoon.dooit.credits.first1000"
        static let pack500 = "com.bravekoon.dooit.credits.500"
        static let pack1000 = "com.bravekoon.dooit.credits.1000"
        static let pack3000 = "com.bravekoon.dooit.credits.3000"
        static let unlimited = "com.bravekoon.dooit.plan.unlimited"
        static let daily = "com.bravekoon.dooit.plan.daily"

        static let packs = [pack500, pack1000, pack3000]
        static let plans = [unlimited, daily]
        static let all = [firstPack] + packs + plans
    }

    /// 상품별 지급 크레딧
    static let credits: [String: Int] = [
        ID.firstPack: 1000,
        ID.pack500: 500,
        ID.pack1000: 1000,
        ID.pack3000: 3000
    ]

    /// App Store에서 가격을 못 불러왔을 때 보여줄 기본 가격
    static let fallbackPrice: [String: String] = [
        ID.firstPack: "₩1,250",
        ID.pack500: "₩1,250",
        ID.pack1000: "₩2,500",
        ID.pack3000: "₩7,500",
        ID.unlimited: "₩20,000",
        ID.daily: "₩4,900"
    ]

    private(set) var products: [String: Product] = [:]
    private(set) var isLoading = false
    private(set) var purchasingID: String?
    private(set) var activePlanID: String?
    var message: String?

    @ObservationIgnored private var listener: Task<Void, Never>?

    func start() {
        guard listener == nil else { return }
        // 앱 밖에서 끝난 결제(승인 대기, 갱신, 환불)도 받아서 처리
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await load()
            await refreshEntitlements()
        }
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: ID.all)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            print("상품 불러오기 실패: \(error)")
        }
    }

    func price(_ id: String) -> String {
        products[id]?.displayPrice ?? Self.fallbackPrice[id] ?? ""
    }

    func purchase(_ id: String) async {
        if products.isEmpty { await load() }
        guard let product = products[id] else {
            message = "아직 App Store에 상품이 준비되지 않았어요. 잠시 후 다시 시도해주세요."
            return
        }
        purchasingID = id
        defer { purchasingID = nil }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
            case .pending:
                message = "결제 승인을 기다리고 있어요. 승인되면 자동으로 지급돼요."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "결제를 완료하지 못했어요. 다시 시도해주세요."
            print("결제 실패: \(error)")
        }
    }

    /// 구매 복원 (구독)
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = activePlanID == nil ? "복원할 구독이 없어요." : "구독을 복원했어요."
        } catch {
            message = "구매 내역을 불러오지 못했어요."
        }
    }

    /// 지금 이용 중인 플랜 확인 (무제한이 우선)
    func refreshEntitlements() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  ID.plans.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            if let expires = transaction.expirationDate, expires < Date() { continue }
            active.insert(transaction.productID)
        }
        activePlanID = active.contains(ID.unlimited) ? ID.unlimited : (active.contains(ID.daily) ? ID.daily : nil)
        let plan: CreditStore.Plan? = activePlanID == ID.unlimited ? .unlimited : (activePlanID == ID.daily ? .daily : nil)
        CreditStore.shared.setPlan(plan)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            message = "결제를 확인하지 못했어요. 문제가 계속되면 구매 복원을 눌러주세요."
            return
        }
        if let amount = Self.credits[transaction.productID] {
            if transaction.revocationDate == nil {
                let title = transaction.productID == ID.firstPack ? "첫 구매 특가 충전" : "크레딧 충전"
                if CreditStore.shared.addPurchase(amount, title: title, transactionID: String(transaction.id)) {
                    message = "+\(amount) 크레딧이 충전됐어요!"
                }
            }
        } else if ID.plans.contains(transaction.productID) {
            await refreshEntitlements()
        }
        await transaction.finish()
    }
}
