//
//  ChartDataModels.swift
//  TestChart
//
//  Created by ilim on 2025-03-27.
//

import Foundation

// MARK: - TradingView 차트 데이터 변환 모델
struct CandleData {
    let time: Double
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
}

// MARK: - Market Info Model
struct MarketInfo: Codable {
    let market: String
    let koreanName: String
    let englishName: String
    
    enum CodingKeys: String, CodingKey {
        case market
        case koreanName = "korean_name"
        case englishName = "english_name"
    }
}
