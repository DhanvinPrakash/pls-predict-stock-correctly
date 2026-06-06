import SwiftUI
import Charts

struct ContentView: View {
    @State private var selectedTab: TabItem = .dashboard
    @EnvironmentObject var stockService: StockDataService
    @EnvironmentObject var predictionService: PredictionService
    @EnvironmentObject var portfolioManager: PortfolioManager
    
    enum TabItem {
        case dashboard
        case stocks
        case portfolio
        case alerts
    }
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stock Predictor")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let lastUpdate = stockService.lastUpdateTime {
                        Text("Last update: \(lastUpdate.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                
                Divider()
                
                List(selection: $selectedTab) {
                    NavigationLink(value: TabItem.dashboard) {
                        Label("Dashboard", systemImage: "chart.xyaxis.circle")
                    }
                    
                    NavigationLink(value: TabItem.stocks) {
                        Label("Stocks", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    
                    NavigationLink(value: TabItem.portfolio) {
                        Label("Portfolio", systemImage: "briefcase")
                    }
                    
                    NavigationLink(value: TabItem.alerts) {
                        Label("Alerts", systemImage: "bell")
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                VStack(spacing: 12) {
                    Button(action: { Task { await refreshData() } }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    if stockService.isUpdating || predictionService.isCalculating {
                        ProgressView()
                            .scaleEffect(0.8, anchor: .center)
                    }
                }
                .padding()
            }
            .frame(minWidth: 200, maxWidth: 250)
        } detail: {
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .stocks:
                    StockListView()
                case .portfolio:
                    PortfolioView()
                case .alerts:
                    AlertsView()
                }
            }
            .environmentObject(stockService)
            .environmentObject(predictionService)
            .environmentObject(portfolioManager)
        }
        .onAppear {
            Task {
                await stockService.loadInitialStocks()
                
                for ticker in StockDataService.defaultTickers {
                    await predictionService.predictStock(ticker)
                }
            }
        }
    }
    
    private func refreshData() async {
        let tickers = Array(stockService.stocks.keys)
        for ticker in tickers {
            await stockService.refreshStock(ticker)
            await predictionService.predictStock(ticker)
        }
        portfolioManager.updateAllPrices()
        portfolioManager.checkAlerts()
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var portfolioManager: PortfolioManager
    @EnvironmentObject var stockService: StockDataService
    @EnvironmentObject var predictionService: PredictionService
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Portfolio Summary
                if !portfolioManager.portfolio.holdings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Portfolio Summary")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            StatCard(
                                label: "Total Value",
                                value: portfolioManager.portfolio.totalValue,
                                isCurrency: true
                            )
                            
                            StatCard(
                                label: "Total Cost",
                                value: portfolioManager.portfolio.totalCost,
                                isCurrency: true
                            )
                            
                            StatCard(
                                label: "Gain/Loss",
                                value: portfolioManager.portfolio.totalGainLossPercent,
                                isCurrency: false,
                                isPercentage: true,
                                isPositive: portfolioManager.portfolio.totalGainLoss >= 0
                            )
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                Text(predictionService.modelStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Recent Predictions
                if !predictionService.predictions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Predictions")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            ForEach(predictionService.predictions.values.sorted {
                                $0.predictionDate > $1.predictionDate
                            }.prefix(5)) { prediction in
                                HStack {
                                    Text(prediction.ticker)
                                        .fontWeight(.semibold)
                                    
                                    Spacer()
                                    
                                    Label(
                                        prediction.predictedDirection.rawValue,
                                        systemImage: prediction.predictedDirection == .up ? "arrow.up" : "arrow.down"
                                    )
                                    .foregroundColor(prediction.predictedDirection == .up ? .green : .red)
                                    
                                    Text("\(String(format: "%.0f%%", prediction.probability * 100))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                                
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Market Overview
                if let macro = stockService.macroData {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Market Overview")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            StatCard(label: "VIX", value: macro.vixIndex, isCurrency: false)
                            StatCard(label: "Fed Rate", value: macro.federalRate * 100, isCurrency: false, isPercentage: true)
                            StatCard(label: "Inflation", value: macro.inflation * 100, isCurrency: false, isPercentage: true)
                        }
                    }
                    .padding()
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Stat Card Component

struct StatCard: View {
    let label: String
    let value: Double
    let isCurrency: Bool
    var isPercentage: Bool = false
    var isPositive: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(formatValue())
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(isPercentage ? (isPositive ? .green : .red) : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.blue))
        .cornerRadius(6)
    }
    
    private func formatValue() -> String {
        if isCurrency {
            return String(format: "$%.2f", value)
        } else if isPercentage {
            return String(format: "%.2f%%", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(StockDataService.shared)
        .environmentObject(PredictionService.shared)
        .environmentObject(PortfolioManager.shared)
}
