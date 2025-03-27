//
//  UpbitWebSocketService.swift
//  TestChart
//
//  Created by ilim on 2025-03-27.
//

import Foundation
import OSLog
import Starscream
import RxSwift

class UpbitWebSocketService {
    private var socket: WebSocket?
    private let disposeBag = DisposeBag()
    private let logger = Logger(subsystem: "UpbitWebSocket", category: "Connection")
    
    enum WebSocketError: Error {
        case urlCreationFailed
        case connectionFailed
        case messageSendingFailed
        case decodingError
    }
    // 데이터 스트림
    let tickerSubject = PublishSubject<UpbitTicker>()
    let tradeSubject = PublishSubject<UpbitTrade>()
    let orderbookSubject = PublishSubject<UpbitOrderbook>()
    
    // 일반 메시지 스트림 (REST API 대체용)
    let messageSubject = PublishSubject<String>()
    
    // 연결 상태 스트림
    let connectionStatusSubject = PublishSubject<Bool>()
    
    init() {
        setupSocket()
    }
    
    func setupSocket() {
        guard let url = URL(string: "wss://api.upbit.com/websocket/v1") else {
            logger.error("❌ WebSocket URL 생성 실패: 유효하지 않은 URL")
            // Error Report 메커니즘 추가 가능
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        socket = WebSocket(request: request)
        socket?.delegate = self
        
        logger.debug("🔌 WebSocket 초기화: \(url)")
    }
    
    private func sendMessage(type: String, codes: [String]) {
        do {
            let ticket = UUID().uuidString
            let request: [[String: Any]] = [
                ["ticket": ticket],
                ["type": type, "codes": codes]
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: request)
            
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                logger.error("❌ WebSocket 메시지 인코딩 실패")
                return
            }
            
            socket?.write(string: jsonString)
            logger.debug("📤 WebSocket 메시지 전송: \(jsonString)")
            
        } catch {
            logger.error("❌ WebSocket 메시지 직렬화 오류: \(error.localizedDescription)")
        }
    }
}

extension UpbitWebSocketService: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            logger.info("✅ WebSocket 연결 성공: \(headers)")
            connectionStatusSubject.onNext(true)
            
        case .disconnected(let reason, let code):
            logger.warning("🔴 WebSocket 연결 해제: 원인 = \(reason), 코드 = \(code)")
            connectionStatusSubject.onNext(false)
            
        case .text(let string):
            logger.debug("📥 수신 메시지: \(string)")
            handleTextMessage(string)
            
        case .binary(let data):
            logger.debug("📦 수신 바이너리 데이터: \(data.count) 바이트")
            handleBinaryMessage(data)
            
        case .ping:
            logger.debug("💓 PING 수신")
            
        case .pong:
            logger.debug("💓 PONG 수신")
            
        case .error(let error):
            logger.error("❌ WebSocket 오류 발생: \(error?.localizedDescription ?? "알 수 없는 오류")")
            connectionStatusSubject.onNext(false)

        default:
            break
        }
    }
    
    func connect() {
        socket?.connect()
    }
    
    func disconnect() {
        socket?.disconnect()
    }
    
    func subscribeTicker(codes: [String]) {
        sendMessage(type: "ticker", codes: codes)
    }
    
    func subscribeTrade(codes: [String]) {
        sendMessage(type: "trade", codes: codes)
    }
    
    func subscribeOrderbook(codes: [String]) {
        sendMessage(type: "orderbook", codes: codes)
    }
        
    // 일반 메시지 전송 (REST API 대체용)
    func sendMessage(_ message: String) {
        socket?.write(string: message)
    }
    
    // PING 메시지 전송 (연결 유지)
    func sendPing() {
        socket?.write(ping: Data())
    }
    
    // 주기적으로 PING 전송 설정
    func startPingTimer() -> Disposable {
        return Observable<Int>
            .interval(.seconds(30), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.sendPing()
            })
    }

    
    private func handleTextMessage(_ text: String) {
        // 일반 메시지는 messageSubject로 전달
        messageSubject.onNext(text)
        
        // 기존 처리 로직도 유지
        guard let data = text.data(using: .utf8) else { return }
        handleBinaryMessage(data)
    }
    
    private func handleBinaryMessage(_ data: Data) {
        let decoder = JSONDecoder()
        
        // 메시지 타입 확인
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {
            
            switch type {
            case "ticker":
                if let ticker = try? decoder.decode(UpbitTicker.self, from: data) {
                    tickerSubject.onNext(ticker)
                }
                
            case "trade":
                if let trade = try? decoder.decode(UpbitTrade.self, from: data) {
                    tradeSubject.onNext(trade)
                }
                
            case "orderbook":
                if let orderbook = try? decoder.decode(UpbitOrderbook.self, from: data) {
                    orderbookSubject.onNext(orderbook)
                }
                
            default:
                break
            }
        }
    }
}
