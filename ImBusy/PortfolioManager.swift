//
//  PortfolioManager.swift
//  ImBusy
//
//  Created by dhanvin_macbook on 6/6/26.
//


import Foundation
import Combine

class PortfolioManager: ObservableObject {
    static let shared = PortfolioManager()
    
    @Published var portfolio: Portfolio = Portfolio()
    @Published var alerts: [AlertCondition] = []
    
    private let userDefaults = UserDefaults.standard
    private let portfolioKey = "com.stockpredictor.portfolio"
    private let alertsKey = "com.stockpredictor.alerts"
    
    private let stockService = StockDataService.shared
    private let predictionService = PredictionService.shared
    
    init() {
        loadPortfolio()
        loadAlerts()
    }
    
    // MARK: - Portfolio Management
    
    func addHolding(ticker: String, shares: Double, purchasePrice: Double) {
        let holding = PortfolioHolding(
            id: UUID(),
            ticker: ticker,
            shares: shares,
            purchasePrice: purchasePrice,
            currentPrice: purchasePrice,
            purchaseDate: Date()
        )
        
        portfolio.holdings.append(holding)
        savePortfolio()
    }
    
    func removeHolding(_ holding: PortfolioHolding) {
        portfolio.holdings.removeAll { $0.id == holding.id }
        savePortfolio()
    }
    
    func updateHoldingPrice(holdingId: UUID, newPrice: Double) {
        if let index = portfolio.holdings.firstIndex(where: { $0.id == holdingId }) {
            var holding = portfolio.holdings[index]
            holding.currentPrice = newPrice
            portfolio.holdings[index] = holding
            savePortfolio()
        }
    }
    
    func updateAllPrices() {
        for ticker in portfolio.holdings.map({ $0.ticker }).uniqued {
            if let stock = stockService.stocks[ticker] {
                let holdings = portfolio.holdings.filter { $0.ticker == ticker }
                for holding in holdings {
                    updateHoldingPrice(holdingId: holding.id, newPrice: stock.currentPrice)
                }
            }
        }
    }
    
    // MARK: - Portfolio Analysis
    
    func getHoldingsForTicker(_ ticker: String) -> [PortfolioHolding] {
        portfolio.holdings.filter { $0.ticker == ticker }
    }
    
    func getTotalSharesForTicker(_ ticker: String) -> Double {
        portfolio.holdings
            .filter { $0.ticker == ticker }
            .map { $0.shares }
            .reduce(0, +)
    }
    
    func getAverageCostForTicker(_ ticker: String) -> Double {
        let holdings = getHoldingsForTicker(ticker)
        let totalCost = holdings.map { $0.totalCost }.reduce(0, +)
        let totalShares = holdings.map { $0.shares }.reduce(0, +)
        return totalShares > 0 ? totalCost / totalShares : 0
    }
    
    // MARK: - Alert Management
    
    func addAlert(ticker: String, conditionType: AlertCondition.AlertType, threshold: Double) {
        let alert = AlertCondition(
            id: UUID(),
            ticker: ticker,
            conditionType: conditionType,
            threshold: threshold,
            isActive: true
        )
        
        alerts.append(alert)
        saveAlerts()
    }
    
    func toggleAlert(_ alert: AlertCondition) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index].isActive.toggle()
            saveAlerts()
        }
    }
    
    func removeAlert(_ alert: AlertCondition) {
        alerts.removeAll { $0.id == alert.id }
        saveAlerts()
    }
    
    func checkAlerts() {
        for alert in alerts where alert.isActive {
            switch alert.conditionType {
            case .priceAbove:
                if let stock = stockService.stocks[alert.ticker],
                   stock.currentPrice > alert.threshold {
                    triggerAlert(alert, message: "\(alert.ticker) is now above \(String(format: "$%.2f", alert.threshold))")
                }
                
            case .priceBelow:
                if let stock = stockService.stocks[alert.ticker],
                   stock.currentPrice < alert.threshold {
                    triggerAlert(alert, message: "\(alert.ticker) is now below \(String(format: "$%.2f", alert.threshold))")
                }
                
            case .predictedUP:
                if let prediction = predictionService.predictions[alert.ticker],
                   prediction.predictedDirection == .up {
                    triggerAlert(alert, message: "\(alert.ticker) prediction: UP (\(String(format: "%.0f%%", prediction.probability * 100)))")
                }
                
            case .predictedDOWN:
                if let prediction = predictionService.predictions[alert.ticker],
                   prediction.predictedDirection == .down {
                    triggerAlert(alert, message: "\(alert.ticker) prediction: DOWN (\(String(format: "%.0f%%", prediction.probability * 100)))")
                }
                
            case .highVolume:
                if let stock = stockService.stocks[alert.ticker] {
                    // Check against 20-day average volume
                    if let prices = stockService.historicalData[alert.ticker] {
                        let avgVolume = prices.map { Double($0.volume) }.reduce(0, +) / Double(prices.count)
                        if let lastPrice = prices.last,
                           Double(lastPrice.volume) > avgVolume * 1.5 {
                            triggerAlert(alert, message: "\(alert.ticker) has high volume")
                        }
                    }
                }
            }
        }
    }
    
    private func triggerAlert(_ alert: AlertCondition, message: String) {
        #if os(macOS)
        let notification = NSUserNotification()
        notification.title = "Stock Alert"
        notification.subtitle = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
        #endif
    }
    
    // MARK: - Persistence
    
    private func savePortfolio() {
        if let encoded = try? JSONEncoder().encode(portfolio) {
            userDefaults.set(encoded, forKey: portfolioKey)
        }
    }
    
    private func loadPortfolio() {
        if let data = userDefaults.data(forKey: portfolioKey),
           let decoded = try? JSONDecoder().decode(Portfolio.self, from: data) {
            portfolio = decoded
        }
    }
    
    private func saveAlerts() {
        if let encoded = try? JSONEncoder().encode(alerts) {
            userDefaults.set(encoded, forKey: alertsKey)
        }
    }
    
    private func loadAlerts() {
        if let data = userDefaults.data(forKey: alertsKey),
           let decoded = try? JSONDecoder().decode([AlertCondition].self, from: data) {
            alerts = decoded
        }
    }
}

// MARK: - Array Extension

extension Array where Element: Hashable {
    var uniqued: [Element] {
        Array(Set(self))
    }
}