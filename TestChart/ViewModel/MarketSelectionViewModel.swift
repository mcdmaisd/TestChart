//
//  MarketSelectionViewModel.swift
//  TestChart
//
//  Created by ilim on 2025-03-27.
//

import Foundation
import RxSwift
import RxCocoa

class MarketSelectionViewModel {
    // MARK: - Properties
    
    // Output
    let availableMarkets = BehaviorRelay<[MarketInfo]>(value: [])
    let isLoading = BehaviorRelay<Bool>(value: false)
    let errorMessage = PublishRelay<String>()
    
    private let disposeBag = DisposeBag()
    
    // MARK: - Initialization
    init() {
        // 기본 마켓 정보 설정
        let defaultMarkets = [
            MarketInfo(market: "KRW-BTC", koreanName: "비트코인", englishName: "Bitcoin"),
            MarketInfo(market: "KRW-ETH", koreanName: "이더리움", englishName: "Ethereum"),
            MarketInfo(market: "KRW-XRP", koreanName: "리플", englishName: "Ripple"),
            MarketInfo(market: "KRW-SOL", koreanName: "솔라나", englishName: "Solana"),
            MarketInfo(market: "KRW-ADA", koreanName: "에이다", englishName: "Cardano")
        ]
        
        availableMarkets.accept(defaultMarkets)
    }
    
    // MARK: - Public Methods
    func loadMarkets() {
        isLoading.accept(true)
        
        // 웹소켓 서비스 인스턴스 생성
        let webSocketService = UpbitWebSocketService()
        
        // 마켓 정보 요청 메시지 구성
        let requestId = UUID().uuidString
        let requestMessage: [String: Any] = [
            "request_id": requestId,
            "type": "market_all",
            "is_details": true
        ]
        
        // 요청 메시지를 JSON 문자열로 변환
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestMessage),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            errorMessage.accept("요청 메시지 생성 실패")
            isLoading.accept(false)
            return
        }
        
        // 웹소켓 연결
        webSocketService.connect()
        
        // 응답 처리를 위한 일회성 구독 설정
        let disposable = webSocketService.messageSubject
            .filter { message in
                // 응답 메시지에서 request_id 확인
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
            .take(1) // 첫 번째 일치하는 응답만 처리
            .subscribe(onNext: { [weak self] message in
                guard let self = self,
                      let data = message.data(using: .utf8) else {
                    return
                }
                
                do {
                    // 응답 JSON에서 마켓 데이터 추출
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
                    
                    DispatchQueue.main.async {
                        self.availableMarkets.accept(krwMarkets)
                        self.isLoading.accept(false)
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage.accept("마켓 정보 파싱 실패: \(error.localizedDescription)")
                        self.isLoading.accept(false)
                    }
                }
                
                // 작업 완료 후 웹소켓 연결 종료
                webSocketService.disconnect()
                
            }, onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.errorMessage.accept("마켓 정보 로드 오류: \(error.localizedDescription)")
                    self?.isLoading.accept(false)
                }
                
                // 오류 발생 시 웹소켓 연결 종료
                webSocketService.disconnect()
            })
        
        // 요청 전송 후 일정 시간 후에 타임아웃 처리
        let timeoutDisposable = Observable<Int>.timer(.seconds(10), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.errorMessage.accept("마켓 정보 로드 타임아웃")
                self?.isLoading.accept(false)
                webSocketService.disconnect()
                disposable.dispose()
            })
        
        // 웹소켓으로 요청 전송
        webSocketService.sendMessage(jsonString)
        
        // 임시 DisposeBag 생성하여 구독 관리
        let tempDisposeBag = DisposeBag()
        disposable.disposed(by: tempDisposeBag)
        timeoutDisposable.disposed(by: tempDisposeBag)
    }
    
    func getMarketDisplayName(_ market: String) -> String {
        if let marketInfo = availableMarkets.value.first(where: { $0.market == market }) {
            return "\(marketInfo.koreanName) (\(market))"
        }
        return market
    }
}
