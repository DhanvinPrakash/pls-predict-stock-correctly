//
//  StockDataService.swift
//  ImBusy
//
//  Created by dhanvin_macbook on 6/6/26.
//

import Foundation
import Combine

class StockDataService: ObservableObject {
    static let shared = StockDataService()
    
    static let defaultTickers = ["D05.SI", "S63.SI"]
    
    @Published var stocks: [String: Stock] = [:]
    @Published var historicalData: [String: [HistoricalPrice]] = [:]
    @Published var technicalFeatures: [String: TechnicalFeatures] = [:]
    @Published var fundamentalFeatures: [String: FundamentalFeatures] = [:]
    @Published var sentimentFeatures: [String: SentimentFeatures] = [:]
    @Published var macroData: MacroFeatures?
    
    @Published var isUpdating = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?
    
    private var updateTimer: Timer?
    private var hasLoadedInitialStocks = false
    
    private static let tickerAliases: [String: String] = [
        "DBS": "D05.SI",
        "D05": "D05.SI",
        "ST ENGINEERING": "S63.SI",
        "STENG": "S63.SI",
        "STE": "S63.SI",
        "S63": "S63.SI"
    ]
    
    private static let companyNames: [String: String] = [
        "D05.SI": "DBS Group Holdings",
        "S63.SI": "ST Engineering"
    ]
    
    // MARK: - Public Methods
    
    func resolveTicker(_ input: String) -> String {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return Self.tickerAliases[normalized] ?? normalized
    }
    
    func loadInitialStocks() async {
        guard !hasLoadedInitialStocks else { return }
        hasLoadedInitialStocks = true
        
        await fetchMacroData()
        
        for ticker in Self.defaultTickers {
            await addStock(ticker)
        }
    }
    
    func addStock(_ ticker: String) async {
        let resolvedTicker = resolveTicker(ticker)
        
        await MainActor.run { isUpdating = true }
        defer { Task { @MainActor in isUpdating = false } }
        
        do {
            let chartData = try await fetchYahooChart(resolvedTicker)
            let stock = chartData.stock
            let history = chartData.history
            let technical = calculateTechnicalIndicators(from: history)
            let fundamental = deriveFundamentalFeatures(from: stock, history: history)
            let sentiment = deriveSentimentFeatures(ticker: resolvedTicker, history: history)
            
            await MainActor.run {
                self.stocks[resolvedTicker] = stock
                self.historicalData[resolvedTicker] = history
                self.technicalFeatures[resolvedTicker] = technical
                self.fundamentalFeatures[resolvedTicker] = fundamental
                self.sentimentFeatures[resolvedTicker] = sentiment
                self.lastUpdateTime = Date()
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch data for \(resolvedTicker): \(error.localizedDescription)"
            }
        }
    }
    
    func refreshStock(_ ticker: String) async {
        await addStock(ticker)
    }
    
    func startBackgroundUpdates() async {
        await MainActor.run {
            guard updateTimer == nil else { return }
            
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
                Task {
                    let tickers = Array(self.stocks.keys)
                    for ticker in tickers {
                        await self.refreshStock(ticker)
                    }
                    await self.fetchMacroData()
                }
            }
        }
    }
    
    // MARK: - Yahoo Finance
    
    private struct YahooChartResponse: Decodable {
        struct Chart: Decodable {
            struct Result: Decodable {
                struct Meta: Decodable {
                    let symbol: String?
                    let shortName: String?
                    let longName: String?
                    let regularMarketPrice: Double?
                    let previousClose: Double?
                    let fiftyTwoWeekHigh: Double?
                    let fiftyTwoWeekLow: Double?
                    let trailingPE: Double?
                    let dividendYield: Double?
                    let marketCap: Double?
                }
                
                struct Indicators: Decodable {
                    struct Quote: Decodable {
                        let open: [Double?]?
                        let high: [Double?]?
                        let low: [Double?]?
                        let close: [Double?]?
                        let volume: [Int?]?
                    }
                    
                    let quote: [Quote]?
                }
                
                let meta: Meta?
                let timestamp: [Int]?
                let indicators: Indicators?
            }
            
            let result: [Result]?
        }
        
        let chart: Chart?
    }
    
    private struct YahooChartData {
        let stock: Stock
        let history: [HistoricalPrice]
    }
    
    private func fetchYahooChart(_ ticker: String) async throws -> YahooChartData {
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(ticker)")!
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "1y")
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "StockDataService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to reach Yahoo Finance"])
        }
        
        let decoded = try JSONDecoder().decode(YahooChartResponse.self, from: data)
        guard let result = decoded.chart?.result?.first,
              let meta = result.meta else {
            throw NSError(domain: "StockDataService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "No chart data for \(ticker)"])
        }
        
        let currentPrice = meta.regularMarketPrice ?? meta.previousClose ?? 0
        let previousClose = meta.previousClose ?? currentPrice
        let priceChange = currentPrice - previousClose
        
        let companyName = meta.longName
            ?? meta.shortName
            ?? Self.companyNames[ticker]
            ?? ticker
        
        let stock = Stock(
            id: ticker,
            ticker: ticker,
            companyName: companyName,
            currentPrice: currentPrice,
            previousClose: previousClose,
            priceChange: priceChange,
            high52Week: meta.fiftyTwoWeekHigh ?? currentPrice * 1.2,
            low52Week: meta.fiftyTwoWeekLow ?? currentPrice * 0.8,
            marketCap: meta.marketCap ?? 0,
            peRatio: meta.trailingPE ?? 0,
            dividendYield: (meta.dividendYield ?? 0) * 100,
            lastUpdate: Date()
        )
        
        let timestamps = result.timestamp ?? []
        let quote = result.indicators?.quote?.first
        
        var history: [HistoricalPrice] = []
        for index in timestamps.indices {
            guard let close = optionalValue(quote?.close, at: index),
                  close > 0 else { continue }
            
            let date = Date(timeIntervalSince1970: TimeInterval(timestamps[index]))
            let open = optionalValue(quote?.open, at: index) ?? close
            let high = optionalValue(quote?.high, at: index) ?? close
            let low = optionalValue(quote?.low, at: index) ?? close
            let volume = optionalValue(quote?.volume, at: index) ?? 0
            
            history.append(HistoricalPrice(
                id: UUID(),
                date: date,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume
            ))
        }
        
        if history.isEmpty {
            history = generateFallbackHistory(basePrice: max(currentPrice, 1))
        }
        
        return YahooChartData(stock: stock, history: history.sorted { $0.date < $1.date })
    }
    
    private func optionalValue<T>(_ array: [T?]?, at index: Int) -> T? {
        guard let array, array.indices.contains(index) else { return nil }
        return array[index]
    }
    
    private func generateFallbackHistory(basePrice: Double) -> [HistoricalPrice] {
        var prices: [HistoricalPrice] = []
        let calendar = Calendar.current
        var currentPrice = basePrice
        
        for daysAgo in stride(from: 200, through: 0, by: -1) {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            currentPrice += Double.random(in: -basePrice * 0.02...basePrice * 0.02)
            currentPrice = max(currentPrice, basePrice * 0.5)
            
            prices.append(HistoricalPrice(
                id: UUID(),
                date: date,
                open: currentPrice,
                high: currentPrice * 1.02,
                low: currentPrice * 0.98,
                close: currentPrice,
                volume: Int.random(in: 1_000_000...50_000_000)
            ))
        }
        
        return prices
    }
    
    // MARK: - Derived Features
    
    private func deriveFundamentalFeatures(from stock: Stock, history: [HistoricalPrice]) -> FundamentalFeatures {
        let closes = history.map(\.close)
        let avgPrice = closes.isEmpty ? stock.currentPrice : closes.reduce(0, +) / Double(closes.count)
        let priceToBook = stock.currentPrice / max(avgPrice * 0.3, 1)
        
        return FundamentalFeatures(
            peRatio: stock.peRatio > 0 ? stock.peRatio : 15,
            pegRatio: 1.2,
            priceToBook: priceToBook,
            debtToEquity: 0.8,
            currentRatio: 1.5,
            quickRatio: 1.1,
            roe: 0.12,
            roa: 0.06,
            profitMargin: 0.25,
            operatingMargin: 0.30,
            revenueGrowth: 0.05,
            epsGrowth: 0.04,
            freeCashFlow: stock.marketCap * 0.05,
            operatingCashFlow: stock.marketCap * 0.08,
            dividendYield: stock.dividendYield / 100,
            payoutRatio: 0.45,
            insiderBuys: 0
        )
    }
    
    private func deriveSentimentFeatures(ticker: String, history: [HistoricalPrice]) -> SentimentFeatures {
        let closes = history.map(\.close)
        let recentChange = closes.count >= 5
            ? ((closes.last ?? 0) - (closes[safe: closes.count - 5] ?? 0)) / max(closes[safe: closes.count - 5] ?? 1, 0.01)
            : 0
        
        let newsScore = max(-1, min(1, recentChange * 5))
        
        return SentimentFeatures(
            newsScore7D: newsScore,
            newsScore30D: newsScore * 0.6,
            newsMentions: 50,
            socialMentions: 200,
            twitterSentiment: newsScore * 0.8,
            redditMentiment: newsScore * 0.5,
            analystSentiment: newsScore > 0 ? 4.0 : 3.0,
            earningsCallSentiment: newsScore * 0.3,
            impliedVolatility: calculateVolatility(closes) / max(closes.last ?? 1, 1)
        )
    }
    
    private func fetchMacroData() async {
        let macro = MacroFeatures(
            federalRate: 0.0425,
            tenYearYield: 0.043,
            vixIndex: 18.5,
            inflation: 0.032,
            unemployment: 0.042,
            gdpGrowth: 0.025,
            advanceDeclineRatio: 1.1,
            sectorMomentum: 0.15
        )
        
        await MainActor.run {
            self.macroData = macro
        }
    }
    
    // MARK: - Technical Indicators
    
    private func calculateTechnicalIndicators(from prices: [HistoricalPrice]) -> TechnicalFeatures {
        let closes = prices.map(\.close)
        let volumes = prices.map { Double($0.volume) }
        
        let rsi = calculateRSI(closes)
        let (macd, signal) = calculateMACD(closes)
        let (bollingerUpper, bollingerMiddle, bollingerLower) = calculateBollingerBands(closes)
        let sma20 = calculateSMA(closes, period: 20)
        let sma50 = calculateSMA(closes, period: 50)
        let sma200 = calculateSMA(closes, period: 200)
        let atr = calculateATR(prices)
        let obv = calculateOBV(closes, volumes)
        let (k, d) = calculateStochastic(closes)
        
        return TechnicalFeatures(
            rsi: rsi,
            macd: macd,
            signal: signal,
            bollingerUpper: bollingerUpper,
            bollingerLower: bollingerLower,
            bollingerMiddle: bollingerMiddle,
            sma20: sma20,
            sma50: sma50,
            sma200: sma200,
            atr: atr,
            adx: 30,
            stochasticK: k,
            stochasticD: d,
            obv: obv,
            volumeSMA: volumes.isEmpty ? 0 : volumes.reduce(0, +) / Double(volumes.count),
            priceChange1D: (closes.last ?? 0) - (closes[safe: closes.count - 2] ?? closes.last ?? 0),
            priceChange5D: (closes.last ?? 0) - (closes[safe: closes.count - 5] ?? closes.last ?? 0),
            priceChange20D: (closes.last ?? 0) - (closes[safe: closes.count - 20] ?? closes.last ?? 0),
            volatility20D: calculateVolatility(closes)
        )
    }
    
    private func calculateRSI(_ prices: [Double], period: Int = 14) -> Double {
        guard prices.count >= period else { return 50 }
        let changes = zip(prices, prices.dropFirst()).map { $0.1 - $0.0 }
        let gains = changes.filter { $0 > 0 }.reduce(0, +) / Double(period)
        let losses = changes.filter { $0 < 0 }.map { abs($0) }.reduce(0, +) / Double(period)
        let rs = gains / max(losses, 0.0001)
        return 100 - (100 / (1 + rs))
    }
    
    private func calculateMACD(_ prices: [Double]) -> (macd: Double, signal: Double) {
        let ema12 = calculateEMA(prices, period: 12)
        let ema26 = calculateEMA(prices, period: 26)
        let macd = ema12 - ema26
        let signal = calculateEMA([macd], period: 9)
        return (macd, signal)
    }
    
    private func calculateBollingerBands(_ prices: [Double], period: Int = 20) -> (upper: Double, middle: Double, lower: Double) {
        let middle = calculateSMA(prices, period: period)
        let variance = prices.suffix(period).map { pow($0 - middle, 2) }.reduce(0, +) / Double(period)
        let stdDev = sqrt(variance)
        return (middle + 2 * stdDev, middle, middle - 2 * stdDev)
    }
    
    private func calculateSMA(_ prices: [Double], period: Int) -> Double {
        guard prices.count >= period else { return prices.last ?? 0 }
        return prices.suffix(period).reduce(0, +) / Double(period)
    }
    
    private func calculateEMA(_ prices: [Double], period: Int) -> Double {
        guard !prices.isEmpty else { return 0 }
        let multiplier = 2.0 / Double(period + 1)
        var ema = prices[0]
        for price in prices.dropFirst() {
            ema = (price * multiplier) + (ema * (1 - multiplier))
        }
        return ema
    }
    
    private func calculateATR(_ prices: [HistoricalPrice], period: Int = 14) -> Double {
        var trueRanges: [Double] = []
        for i in 1..<prices.count {
            let high = prices[i].high
            let low = prices[i].low
            let prevClose = prices[i - 1].close
            let tr = max(high - low, abs(high - prevClose), abs(low - prevClose))
            trueRanges.append(tr)
        }
        guard !trueRanges.isEmpty else { return 0 }
        return trueRanges.suffix(period).reduce(0, +) / Double(min(period, trueRanges.count))
    }
    
    private func calculateStochastic(_ prices: [Double], period: Int = 14) -> (k: Double, d: Double) {
        guard prices.count >= period else { return (50, 50) }
        let recent = prices.suffix(period)
        let high = recent.max() ?? prices.last ?? 0
        let low = recent.min() ?? prices.last ?? 0
        let k = ((prices.last ?? 0) - low) / max(high - low, 0.0001) * 100
        return (k, k)
    }
    
    private func calculateOBV(_ closes: [Double], _ volumes: [Double]) -> Double {
        var obv = 0.0
        for i in 0..<closes.count {
            if i > 0 {
                if closes[i] > closes[i - 1] {
                    obv += volumes[i]
                } else if closes[i] < closes[i - 1] {
                    obv -= volumes[i]
                }
            }
        }
        return obv
    }
    
    private func calculateVolatility(_ prices: [Double], period: Int = 20) -> Double {
        guard prices.count >= period else { return 0 }
        let recent = prices.suffix(period)
        let mean = recent.reduce(0, +) / Double(period)
        let variance = recent.map { pow($0 - mean, 2) }.reduce(0, +) / Double(period)
        return sqrt(variance)
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
