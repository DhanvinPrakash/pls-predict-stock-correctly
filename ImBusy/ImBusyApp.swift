import SwiftUI

@main
struct StockPredictorApp: App {
    @StateObject private var stockService = StockDataService.shared
    @StateObject private var predictionService = PredictionService.shared
    @StateObject private var portfolioManager = PortfolioManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(stockService)
                .environmentObject(predictionService)
                .environmentObject(portfolioManager)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        
        Settings {
            SettingsView()
                .environmentObject(stockService)
        }
    }
    
    init() {
        setupBackgroundTasks()
    }
    
    private func setupBackgroundTasks() {
        Task {
            await stockService.loadInitialStocks()
            
            for ticker in StockDataService.defaultTickers {
                await predictionService.predictStock(ticker)
            }
            
            await stockService.startBackgroundUpdates()
        }
    }
}
