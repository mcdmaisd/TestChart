//
//  Formatters.swift
//  TestChart
//
//  Created by ilim on 2025-03-27.
//

import Foundation

struct Formatters {
    // MARK: - Price Formatters
    
    /// 가격 포맷터 (기본)
    static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    /// 가격 포맷터 (소수점 8자리까지)
    static let cryptoPriceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter
    }()
    
    /// 퍼센트 포맷터
    static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.multiplier = 1
        return formatter
    }()
    
    /// 거래량 포맷터
    static let volumeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        return formatter
    }()
    
    // MARK: - Date Formatters
    
    /// 날짜 포맷터 (yyyy-MM-dd)
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
    
    /// 시간 포맷터 (HH:mm:ss)
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
    
    /// 날짜 시간 포맷터 (yyyy-MM-dd HH:mm:ss)
    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter
    }()
    
    // MARK: - Formatting Methods
    
    /// 가격 포맷팅
    static func formatPrice(_ price: Double) -> String {
        return priceFormatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
    
    /// 암호화폐 가격 포맷팅 (소수점 8자리까지)
    static func formatCryptoPrice(_ price: Double) -> String {
        return cryptoPriceFormatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
    
    /// 퍼센트 포맷팅
    static func formatPercent(_ value: Double) -> String {
        return percentFormatter.string(from: NSNumber(value: value)) ?? "\(value * 100)%"
    }
    
    /// 거래량 포맷팅
    static func formatVolume(_ volume: Double) -> String {
        return volumeFormatter.string(from: NSNumber(value: volume)) ?? "\(volume)"
    }
    
    /// 타임스탬프를 날짜 문자열로 변환
    static func formatTimestamp(_ timestamp: Double, format: DateFormatter = dateTimeFormatter) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        return format.string(from: date)
    }
    
    /// 변화율에 따른 색상 코드 반환
    static func colorForChange(_ change: String) -> String {
        switch change {
        case "RISE":
            return "#eb5a46" // 상승 (빨강)
        case "FALL":
            return "#2a71d0" // 하락 (파랑)
        default:
            return "#000000" // 보합 (검정)
        }
    }
}
