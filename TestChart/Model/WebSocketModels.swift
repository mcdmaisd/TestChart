//
//  WebSocketModels.swift
//  TestChart
//
//  Created by ilim on 2025-03-27.
//

import Foundation

// MARK: - 공통 요청 모델
struct UpbitWebSocketRequest: Encodable {
    let ticket: String
    let type: String
    let codes: [String]
    let isOnlySnapshot: Bool?
    let isOnlyRealtime: Bool?
    let format: String?
    
    enum CodingKeys: String, CodingKey {
        case ticket, type, codes
        case isOnlySnapshot = "is_only_snapshot"
        case isOnlyRealtime = "is_only_realtime"
        case format
    }
}

// MARK: - Ticker 응답 모델
struct UpbitTicker: Decodable {
    let type: String
    let code: String
    let openingPrice: Double
    let highPrice: Double
    let lowPrice: Double
    let tradePrice: Double
    let prevClosingPrice: Double
    let accTradePrice: Double
    let change: String
    let changePrice: Double
    let signedChangePrice: Double
    let changeRate: Double
    let signedChangeRate: Double
    let tradeVolume: Double
    let accTradeVolume: Double
    let tradeDate: String
    let tradeTime: String
    let tradeTimestamp: Int64
    let timestamp: Int64
    let streamType: String?
    
    enum CodingKeys: String, CodingKey {
        case type, code, change, timestamp
        case openingPrice = "opening_price"
        case highPrice = "high_price"
        case lowPrice = "low_price"
        case tradePrice = "trade_price"
        case prevClosingPrice = "prev_closing_price"
        case accTradePrice = "acc_trade_price"
        case changePrice = "change_price"
        case signedChangePrice = "signed_change_price"
        case changeRate = "change_rate"
        case signedChangeRate = "signed_change_rate"
        case tradeVolume = "trade_volume"
        case accTradeVolume = "acc_trade_volume"
        case tradeDate = "trade_date"
        case tradeTime = "trade_time"
        case tradeTimestamp = "trade_timestamp"
        case streamType = "stream_type"
    }
}

// MARK: - Trade 응답 모델
struct UpbitTrade: Decodable {
    let type: String
    let code: String
    let tradePrice: Double
    let tradeVolume: Double
    let askBid: String
    let prevClosingPrice: Double
    let change: String
    let changePrice: Double
    let tradeDate: String
    let tradeTime: String
    let tradeTimestamp: Int64
    let timestamp: Int64
    let streamType: String?
    
    enum CodingKeys: String, CodingKey {
        case type, code, change, timestamp
        case tradePrice = "trade_price"
        case tradeVolume = "trade_volume"
        case askBid = "ask_bid"
        case prevClosingPrice = "prev_closing_price"
        case changePrice = "change_price"
        case tradeDate = "trade_date"
        case tradeTime = "trade_time"
        case tradeTimestamp = "trade_timestamp"
        case streamType = "stream_type"
    }
}

// MARK: - Orderbook 응답 모델
struct UpbitOrderbook: Decodable {
    let type: String
    let code: String
    let timestamp: Int64
    let totalAskSize: Double
    let totalBidSize: Double
    let orderbookUnits: [OrderbookUnit]
    let streamType: String?
    let level: Double?
    
    enum CodingKeys: String, CodingKey {
        case type, code, timestamp, level
        case totalAskSize = "total_ask_size"
        case totalBidSize = "total_bid_size"
        case orderbookUnits = "orderbook_units"
        case streamType = "stream_type"
    }
    
    struct OrderbookUnit: Decodable {
        let askPrice: Double
        let bidPrice: Double
        let askSize: Double
        let bidSize: Double
        
        enum CodingKeys: String, CodingKey {
            case askPrice = "ask_price"
            case bidPrice = "bid_price"
            case askSize = "ask_size"
            case bidSize = "bid_size"
        }
    }
}
