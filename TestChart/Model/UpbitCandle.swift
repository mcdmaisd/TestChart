//
//  UpbitCandle.swift
//  TestChart
//
//  Created by ilim on 2025-03-27.
//

import Foundation

// MARK: - 업비트 캔들 응답 모델
struct UpbitCandle: Decodable {
    let market: String
    let timestamp: Double
    let openingPrice: Double
    let highPrice: Double
    let lowPrice: Double
    let tradePrice: Double
    let candleAccTradeVolume: Double
    
    enum CodingKeys: String, CodingKey {
        case market
        case timestamp = "timestamp"
        case openingPrice = "opening_price"
        case highPrice = "high_price"
        case lowPrice = "low_price"
        case tradePrice = "trade_price"
        case candleAccTradeVolume = "candle_acc_trade_volume"
    }
}
