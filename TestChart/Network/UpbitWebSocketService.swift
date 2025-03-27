//
//  UpbitWebSocketService.swift
//  TestChart
//
//  Created by ilim on 2025-03-27.
//

import Foundation
import Starscream
import RxSwift

class UpbitWebSocketService {
    private var socket: WebSocket?
    private let disposeBag = DisposeBag()
    
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
    
    private func setupSocket() {
        guard let url = URL(string: "wss://api.upbit.com/websocket/v1") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        socket = WebSocket(request: request)
        socket?.delegate = self
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
    
    private func sendMessage(type: String, codes: [String]) {
        let request = [
            ["ticket": "rx-swift-\(UUID().uuidString)"],
            ["type": type, "codes": codes]
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: request),
              let message = String(data: data, encoding: .utf8) else {
            return
        }
        
        socket?.write(string: message)
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
}

extension UpbitWebSocketService: WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected:
            connectionStatusSubject.onNext(true)
            
        case .disconnected:
            connectionStatusSubject.onNext(false)
            
        case .text(let string):
            handleTextMessage(string)
            
        case .binary(let data):
            handleBinaryMessage(data)
            
        case .error(let error):
            print("WebSocket Error: \(error?.localizedDescription ?? "Unknown error")")
            connectionStatusSubject.onNext(false)
            
        default:
            break
        }
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
