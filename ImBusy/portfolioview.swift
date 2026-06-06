import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var portfolioManager: PortfolioManager
    @EnvironmentObject var stockService: StockDataService
    @State private var showAddHolding = false
    
    var body: some View {
        VStack {
            if portfolioManager.portfolio.holdings.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "briefcase")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No holdings yet")
                        .font(.headline)
                    
                    Text("Add your first stock holding to track your portfolio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showAddHolding = true }) {
                        Label("Add Holding", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlBackgroundColor))
            } else {
                VStack(spacing: 16) {
                    // Summary Cards
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Value")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "$%.2f", portfolioManager.portfolio.totalValue))
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Cost")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "$%.2f", portfolioManager.portfolio.totalCost))
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gain/Loss")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: portfolioManager.portfolio.totalGainLoss >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption)
                                
                                Text(String(format: "%.2f%%", portfolioManager.portfolio.totalGainLossPercent))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(portfolioManager.portfolio.totalGainLoss >= 0 ? .green : .red)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .padding()
                    
                    // Holdings Table
                    Table(portfolioManager.portfolio.holdings) {
                        TableColumn("Ticker", value: \.ticker)
                        
                        TableColumn("Shares") { holding in
                            Text(String(format: "%.4f", holding.shares))
                                .monospacedDigit()
                        }
                        
                        TableColumn("Avg Cost") { holding in
                            Text(String(format: "$%.2f", holding.purchasePrice))
                                .monospacedDigit()
                        }
                        
                        TableColumn("Current Price") { holding in
                            Text(String(format: "$%.2f", holding.currentPrice))
                                .monospacedDigit()
                        }
                        
                        TableColumn("Total Cost") { holding in
                            Text(String(format: "$%.2f", holding.totalCost))
                                .monospacedDigit()
                        }
                        
                        TableColumn("Current Value") { holding in
                            Text(String(format: "$%.2f", holding.currentValue))
                                .monospacedDigit()
                        }
                        
                        TableColumn("Gain/Loss") { holding in
                            HStack {
                                Image(systemName: holding.isProfit ? "arrow.up" : "arrow.down")
                                    .font(.caption)
                                
                                Text(String(format: "%.2f%% ($%.2f)",
                                           holding.gainLossPercent, holding.gainLoss))
                                    .monospacedDigit()
                            }
                            .foregroundColor(holding.isProfit ? .green : .red)
                        }
                        
                        TableColumn("") { holding in
                            Button(action: { portfolioManager.removeHolding(holding) }) {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Remove holding")
                        }
                    }
                    
                    HStack {
                        Button(action: { showAddHolding = true }) {
                            Label("Add Holding", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showAddHolding) {
            AddHoldingView(isPresented: $showAddHolding)
                .environmentObject(portfolioManager)
        }
    }
}

// MARK: - Add Holding View

struct AddHoldingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var portfolioManager: PortfolioManager
    @State private var ticker = ""
    @State private var shares = ""
    @State private var purchasePrice = ""
    @State private var isLoading = false
    
    var isValid: Bool {
        !ticker.isEmpty && !shares.isEmpty && !purchasePrice.isEmpty &&
        Double(shares) ?? 0 > 0 && Double(purchasePrice) ?? 0 > 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Holding")
                    .font(.headline)
                
                Text("Add a stock position to your portfolio")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                TextField("Ticker", text: $ticker)
                    .textFieldStyle(.roundedBorder)
                    .textCase(.uppercase)
                
                TextField("Shares", text: $shares)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Purchase Price per Share", text: $purchasePrice)
                    .textFieldStyle(.roundedBorder)
            }
            
            if !ticker.isEmpty && !shares.isEmpty && !purchasePrice.isEmpty,
               let shareCount = Double(shares),
               let price = Double(purchasePrice) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Cost: $\(String(format: "%.2f", shareCount * price))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Add") {
                    addHolding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isLoading)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400)
    }
    
    private func addHolding() {
        isLoading = true
        portfolioManager.addHolding(
            ticker: ticker,
            shares: Double(shares) ?? 0,
            purchasePrice: Double(purchasePrice) ?? 0
        )
        isLoading = false
        isPresented = false
    }
}

#Preview {
    PortfolioView()
        .environmentObject(PortfolioManager.shared)
        .environmentObject(StockDataService.shared)
}
