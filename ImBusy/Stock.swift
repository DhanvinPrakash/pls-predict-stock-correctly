//
//  Stock.swift
//  ImBusy
//
//  Created by dhanvin_macbook on 6/6/26.
//


import Foundation

// MARK: - Stock Data Models

struct Stock: Identifiable, Codable {
    let id: String
    let ticker: String
    let companyName: String
    let currentPrice: Double
    let previousClose: Double
    let priceChange: Double
    var percentChange: Double { (priceChange / previousClose) * 100 }
    
    let high52Week: Double
    let low52Week: Double
    let marketCap: Double
    let peRatio: Double
    let dividendYield: Double
    
    let lastUpdate: Date
}

struct HistoricalPrice: Identifiable, Codable {
    let id: UUID
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}

// MARK: - Feature Data Models

struct TechnicalFeatures: Codable {
    let rsi: Double
    let macd: Double
    let signal: Double
    let bollingerUpper: Double
    let bollingerLower: Double
    let bollingerMiddle: Double
    let sma20: Double
    let sma50: Double
    let sma200: Double
    let atr: Double
    let adx: Double
    let stochasticK: Double
    let stochasticD: Double
    let obv: Double
    let volumeSMA: Double
    let priceChange1D: Double
    let priceChange5D: Double
    let priceChange20D: Double
    let volatility20D: Double
}

struct FundamentalFeatures: Codable {
    let peRatio: Double
    let pegRatio: Double
    let priceToBook: Double
    let debtToEquity: Double
    let currentRatio: Double
    let quickRatio: Double
    let roe: Double
    let roa: Double
    let profitMargin: Double
    let operatingMargin: Double
    let revenueGrowth: Double
    let epsGrowth: Double
    let freeCashFlow: Double
    let operatingCashFlow: Double
    let dividendYield: Double
    let payoutRatio: Double
    let insiderBuys: Double
}

struct SentimentFeatures: Codable {
    let newsScore7D: Double
    let newsScore30D: Double
    let newsMentions: Int
    let socialMentions: Int
    let twitterSentiment: Double
    let redditMentiment: Double
    let analystSentiment: Double
    let earningsCallSentiment: Double
    let impliedVolatility: Double
}

struct MacroFeatures: Codable {
    let federalRate: Double
    let tenYearYield: Double
    let vixIndex: Double
    let inflation: Double
    let unemployment: Double
    let gdpGrowth: Double
    let advanceDeclineRatio: Double
    let sectorMomentum: Double
}

struct CombinedFeatures: Codable {
    let ticker: String
    let technical: TechnicalFeatures
    let fundamental: FundamentalFeatures
    let sentiment: SentimentFeatures
    let macro: MacroFeatures
    let date: Date
}

// MARK: - Prediction Models

struct StockPrediction: Identifiable, Codable {
    let id: UUID
    let ticker: String
    let predictedDirection: PredictionDirection // Up or Down
    let probability: Double // 0-1
    let confidence: Double // 0-1, based on model agreement
    
    let lstmScore: Double
    let xgbScore: Double
    let rfScore: Double
    let nnScore: Double
    
    let predictionDate: Date
    let targetDate: Date // 5 days out
    let modelAgreement: Double // % of models agreeing
    
    var confidenceLevel: ConfidenceLevel {
        if confidence > 0.8 { return .high }
        else if confidence > 0.6 { return .medium }
        else { return .low }
    }
}

enum PredictionDirection: String, Codable {
    case up = "UP"
    case down = "DOWN"
    case neutral = "NEUTRAL"
}

enum ConfidenceLevel: String {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

struct PredictionDetail: Codable {
    let direction: PredictionDirection
    let probability: Double
    let confidence: Double
    let rationale: String
    let technicalInsight: String
    let fundamentalInsight: String
    let sentimentInsight: String
    let macroInsight: String
}

// MARK: - Portfolio Models

struct PortfolioHolding: Identifiable, Codable {
    let id: UUID
    let ticker: String
    let shares: Double
    let purchasePrice: Double
    var currentPrice: Double
    let purchaseDate: Date
    
    var totalCost: Double { shares * purchasePrice }
    var currentValue: Double { shares * currentPrice }
    var gainLoss: Double { currentValue - totalCost }
    var gainLossPercent: Double { (gainLoss / totalCost) * 100 }
    var isProfit: Bool { gainLoss >= 0 }
}

struct Portfolio: Codable {
    var holdings: [PortfolioHolding] = []
    
    var totalCost: Double {
        holdings.reduce(0) { $0 + $1.totalCost }
    }
    
    var totalValue: Double {
        holdings.reduce(0) { $0 + $1.currentValue }
    }
    
    var totalGainLoss: Double {
        totalValue - totalCost
    }
    
    var totalGainLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (totalGainLoss / totalCost) * 100
    }
}

// MARK: - Alert Models

struct AlertCondition: Identifiable, Codable {
    let id: UUID
    let ticker: String
    let conditionType: AlertType
    let threshold: Double
    var isActive: Bool
    
    enum AlertType: String, Codable, CaseIterable {
        case priceAbove
        case priceBelow
        case predictedUP
        case predictedDOWN
        case highVolume
        
        var label: String {
            switch self {
            case .priceAbove: return "Price Above"
            case .priceBelow: return "Price Below"
            case .predictedUP: return "Predicted UP"
            case .predictedDOWN: return "Predicted DOWN"
            case .highVolume: return "High Volume"
            }
        }
    }
}