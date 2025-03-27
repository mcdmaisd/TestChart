import Foundation
import RxSwift
import RxCocoa
import OSLog

class MarketSelectionViewModel {
    // 전용 로거 생성
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.default.cryptoapp",
        category: "MarketSelectionViewModel"
    )
    
    // MARK: - Properties
    
    // Output
    let availableMarkets = BehaviorRelay<[MarketInfo]>(value: [])
    let isLoading = BehaviorRelay<Bool>(value: false)
    let errorMessage = PublishRelay<String>()
    
    // 내부 상태 및 의존성 관리
    private let disposeBag = DisposeBag()
    private let webSocketService: UpbitWebSocketService
    
    // MARK: - Initialization
    init(webSocketService: UpbitWebSocketService = UpbitWebSocketService()) {
        logger.debug("MarketSelectionViewModel 초기화")
        self.webSocketService = webSocketService
        setupInitialMarkets()
    }
    
    // MARK: - Initial Market Setup
    private func setupInitialMarkets() {
        let defaultMarkets = [
            MarketInfo(market: "KRW-BTC", koreanName: "비트코인", englishName: "Bitcoin"),
            MarketInfo(market: "KRW-ETH", koreanName: "이더리움", englishName: "Ethereum"),
            MarketInfo(market: "KRW-XRP", koreanName: "리플", englishName: "Ripple"),
            MarketInfo(market: "KRW-SOL", koreanName: "솔라나", englishName: "Solana"),
            MarketInfo(market: "KRW-ADA", koreanName: "에이다", englishName: "Cardano")
        ]
        
        availableMarkets.accept(defaultMarkets)
        logger.debug("기본 마켓 \(defaultMarkets.count)개 로드")
    }
    
    // MARK: - Market Loading
    func loadMarkets() {
        logger.debug("마켓 정보 로드 시작")
        
        // 로딩 상태 업데이트
        isLoading.accept(true)
        
        // 웹소켓 서비스 인스턴스 생성
        let requestId = UUID().uuidString
        let requestMessage: [String: Any] = [
            "request_id": requestId,
            "type": "market_all",
            "is_details": true
        ]
        
        // 요청 메시지 JSON 변환
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestMessage),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            logger.error("마켓 정보 요청 메시지 생성 실패")
            errorMessage.accept("요청 메시지 생성 실패")
            isLoading.accept(false)
            return
        }
        
        // 웹소켓 연결
        webSocketService.connect()
        
        // 응답 처리를 위한 일회성 구독
        let disposable = webSocketService.messageSubject
            .filter { message in
                guard let data = message.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseId = json["request_id"] as? String,
                      responseId == requestId,
                      let type = json["type"] as? String,
                      type == "market_all" else {
                    return false
                }
                return true
            }
            .take(1)
            .subscribe(onNext: { [weak self] message in
                guard let self = self,
                      let data = message.data(using: .utf8) else {
                    self?.logger.error("마켓 데이터 수신 실패")
                    return
                }
                
                do {
                    // 마켓 데이터 추출
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let marketsData = json["data"] as? [[String: Any]] else {
                        throw NSError(domain: "ParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "마켓 데이터 추출 실패"])
                    }
                    
                    // 마켓 데이터 변환
                    var marketInfoArray: [MarketInfo] = []
                    
                    for marketJson in marketsData {
                        guard let market = marketJson["market"] as? String,
                              let koreanName = marketJson["korean_name"] as? String,
                              let englishName = marketJson["english_name"] as? String else {
                            continue
                        }
                        
                        let marketInfo = MarketInfo(
                            market: market,
                            koreanName: koreanName,
                            englishName: englishName
                        )
                        
                        marketInfoArray.append(marketInfo)
                    }
                    
                    // KRW 마켓만 필터링
                    let krwMarkets = marketInfoArray.filter { $0.market.hasPrefix("KRW-") }
                    
                    logger.debug("총 \(krwMarkets.count)개의 KRW 마켓 로드")
                    
                    DispatchQueue.main.async {
                        self.availableMarkets.accept(krwMarkets)
                        self.isLoading.accept(false)
                    }
                    
                } catch {
                    logger.error("마켓 정보 파싱 실패: \(error.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        self.errorMessage.accept("마켓 정보 파싱 실패: \(error.localizedDescription)")
                        self.isLoading.accept(false)
                    }
                }
                
                // 작업 완료 후 웹소켓 연결 종료
                self.webSocketService.disconnect()
                
            }, onError: { [weak self] error in
                self?.logger.error("마켓 정보 로드 오류: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self?.errorMessage.accept("마켓 정보 로드 오류: \(error.localizedDescription)")
                    self?.isLoading.accept(false)
                }
                
                // 오류 발생 시 웹소켓 연결 종료
                self?.webSocketService.disconnect()
            })
        
        // 타임아웃 처리
        let timeoutDisposable = Observable<Int>.timer(.seconds(10), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.logger.error("마켓 정보 로드 타임아웃")
                self?.errorMessage.accept("마켓 정보 로드 타임아웃")
                self?.isLoading.accept(false)
                self?.webSocketService.disconnect()
                disposable.dispose()
            })
        
        // 웹소켓으로 요청 전송
        webSocketService.sendMessage(jsonString)
        
        // 임시 DisposeBag 생성하여 구독 관리
        let tempDisposeBag = DisposeBag()
        disposable.disposed(by: tempDisposeBag)
        timeoutDisposable.disposed(by: tempDisposeBag)
    }
    
    // MARK: - Utility Methods
    func getMarketDisplayName(_ market: String) -> String {
        if let marketInfo = availableMarkets.value.first(where: { $0.market == market }) {
            logger.debug("마켓 \(market) 디스플레이 이름 반환")
            return "\(marketInfo.koreanName) (\(market))"
        }
        logger.debug("마켓 \(market)에 대한 디스플레이 이름 없음")
        return market
    }
}
