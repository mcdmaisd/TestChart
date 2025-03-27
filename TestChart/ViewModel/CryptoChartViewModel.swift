//
//  CryptoChartViewModel.swift
//  TestChart
//
//  Created by ilim on 2025-03-27.
//

import Foundation
import RxSwift
import RxCocoa
import OSLog

class CryptoChartViewModel {
    // MARK: - Properties
    private let webSocketService: UpbitWebSocketService
    private let disposeBag = DisposeBag()
    
    // Input
    let marketCode = BehaviorRelay<String>(value: "KRW-BTC")
    let selectedTimeframe = BehaviorRelay<String>(value: "1")
    
    // Output
    let candleData = BehaviorRelay<[CandleData]>(value: [])
    let currentPrice = BehaviorRelay<Double>(value: 0.0)
    let connectionStatus = BehaviorRelay<Bool>(value: false)
    let isLoading = BehaviorRelay<Bool>(value: false)
    let errorMessage = PublishRelay<String>()
    
    // MARK: - Initialization
    init(webSocketService: UpbitWebSocketService = UpbitWebSocketService()) {
        self.webSocketService = webSocketService
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // 마켓 코드 변경 시 웹소켓 재연결
        marketCode
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] market in
                guard let self = self else { return }
                
                // 기존 연결 해제
                self.webSocketService.disconnect()
                
                // 데이터 초기화
                self.candleData.accept([])
                
                // 새 마켓으로 연결 및 구독
                self.webSocketService.connect()
                self.webSocketService.subscribeTicker(codes: [market])
                
                // 과거 데이터 로드
                self.loadHistoricalData(market: market, timeframe: self.selectedTimeframe.value)
            })
            .disposed(by: disposeBag)
        
        // 타임프레임 변경 시 데이터 다시 로드
        selectedTimeframe
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] timeframe in
                guard let self = self else { return }
                
                // 데이터 초기화
                self.candleData.accept([])
                
                // 새 타임프레임으로 데이터 로드
                self.loadHistoricalData(market: self.marketCode.value, timeframe: timeframe)
            })
            .disposed(by: disposeBag)
        
        // 웹소켓 티커 데이터 구독
        webSocketService.tickerSubject
            .subscribe(onNext: { [weak self] ticker in
                guard let self = self,
                      ticker.code == self.marketCode.value else { return }
                
                // 현재가 업데이트
                self.currentPrice.accept(ticker.tradePrice)
                
                // 최신 캔들 데이터 업데이트
                self.updateLatestCandle(ticker)
            })
            .disposed(by: disposeBag)
        
        // 연결 상태 구독
        webSocketService.connectionStatusSubject
            .subscribe(onNext: { [weak self] isConnected in
                self?.connectionStatus.accept(isConnected)
            })
            .disposed(by: disposeBag)
        
        // 연결 유지를 위한 PING 타이머 시작
        webSocketService.startPingTimer()
            .disposed(by: disposeBag)
    }
    
    // MARK: - Data Loading
    func loadHistoricalData(market: String, timeframe: String) {
        isLoading.accept(true)
        
        // 웹소켓으로 과거 데이터 요청 메시지 구성
        let requestId = UUID().uuidString
        let requestMessage: [String: Any] = [
            "request_id": requestId,
            "type": "candles",
            "market": market,
            "timeframe": timeframe,
            "count": 200
        ]
        
        // 요청 메시지를 JSON 문자열로 변환
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestMessage),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            errorMessage.accept("요청 메시지 생성 실패")
            isLoading.accept(false)
            return
        }
        
        // 응답 처리를 위한 일회성 구독 설정
        let disposable = webSocketService.messageSubject
            .filter { message in
                // 응답 메시지에서 request_id 확인
                guard let data = message.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let responseId = json["request_id"] as? String,
                      responseId == requestId,
                      let type = json["type"] as? String,
                      type == "candles" else {
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
                    // 응답 JSON에서 캔들 데이터 추출
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let candlesData = json["data"] as? [[String: Any]] else {
                        throw NSError(domain: "ParsingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "캔들 데이터 추출 실패"])
                    }
                    
                    // 캔들 데이터 변환
                    var candleDataArray: [CandleData] = []
                    
                    for candleJson in candlesData {
                        guard let timestamp = candleJson["timestamp"] as? Double,
                              let open = candleJson["opening_price"] as? Double,
                              let high = candleJson["high_price"] as? Double,
                              let low = candleJson["low_price"] as? Double,
                              let close = candleJson["trade_price"] as? Double,
                              let volume = candleJson["candle_acc_trade_volume"] as? Double else {
                            continue
                        }
                        
                        let candle = CandleData(
                            time: timestamp / 1000,
                            open: open,
                            high: high,
                            low: low,
                            close: close,
                            volume: volume
                        )
                        
                        candleDataArray.append(candle)
                    }
                    
                    // 시간순 정렬 (오래된 데이터부터)
                    let sortedData = candleDataArray.sorted { $0.time < $1.time }
                    
                    DispatchQueue.main.async {
                        self.candleData.accept(sortedData)
                        
                        // 현재가 업데이트
                        if let lastCandle = sortedData.last {
                            self.currentPrice.accept(lastCandle.close)
                        }
                        
                        self.isLoading.accept(false)
                    }
                    
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage.accept("데이터 파싱 실패: \(error.localizedDescription)")
                        self.isLoading.accept(false)
                    }
                }
            }, onError: { [weak self] error in
                DispatchQueue.main.async {
                    self?.errorMessage.accept("데이터 로드 오류: \(error.localizedDescription)")
                    self?.isLoading.accept(false)
                }
            })
        
        // DisposeBag에 추가
        disposable.disposed(by: disposeBag)
        
        // 웹소켓으로 요청 전송
        webSocketService.sendMessage(jsonString)
    }
    
    // MARK: - Data Update
    private func updateLatestCandle(_ ticker: UpbitTicker) {
        let timestamp = Double(ticker.timestamp) / 1000
        var updatedCandleData = candleData.value
        
        // 이미 있는 데이터인지 확인
        if let lastIndex = updatedCandleData.lastIndex(where: { $0.time == timestamp }) {
            // 기존 데이터 업데이트
            let updatedCandle = CandleData(
                time: timestamp,
                open: updatedCandleData[lastIndex].open,
                high: max(updatedCandleData[lastIndex].high, ticker.tradePrice),
                low: min(updatedCandleData[lastIndex].low, ticker.tradePrice),
                close: ticker.tradePrice,
                volume: ticker.accTradeVolume
            )
            
            updatedCandleData[lastIndex] = updatedCandle
        } else {
            // 새 캔들 추가
            let newCandle = CandleData(
                time: timestamp,
                open: ticker.tradePrice,
                high: ticker.tradePrice,
                low: ticker.tradePrice,
                close: ticker.tradePrice,
                volume: ticker.accTradeVolume
            )
            
            updatedCandleData.append(newCandle)
            
            // 정렬 유지
            updatedCandleData.sort { $0.time < $1.time }
        }
        
        candleData.accept(updatedCandleData)
    }
    
    // MARK: - Public Methods
    func connect() {
        webSocketService.connect()
    }
    
    func disconnect() {
        webSocketService.disconnect()
    }
    
    func changeMarket(_ market: String) {
        marketCode.accept(market)
    }
    
    func changeTimeframe(_ timeframe: String) {
        selectedTimeframe.accept(timeframe)
    }
}
