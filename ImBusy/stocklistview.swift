import SwiftUI

struct StockRow: Identifiable {
    let id: String
    let ticker: String
    let stock: Stock
}

struct StockListView: View {
    @EnvironmentObject var stockService: StockDataService
    @EnvironmentObject var predictionService: PredictionService
    @State private var searchText = ""
    @State private var showAddStock = false
    @State private var selectedStock: String?
    
    var filteredStocks: [StockRow] {
        let rows = stockService.stocks.map { StockRow(id: $0.key, ticker: $0.key, stock: $0.value) }
        if searchText.isEmpty {
            return rows.sorted { $0.ticker < $1.ticker }
        }
        return rows
            .filter { $0.ticker.localizedCaseInsensitiveContains(searchText) ||
                      $0.stock.companyName.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.ticker < $1.ticker }
    }
    
    var body: some View {
        VStack {
            HStack {
                TextField("Search stocks...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: { showAddStock = true }) {
                    Label("Add Stock", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            if filteredStocks.isEmpty {
                VStack {
                    Image(systemName: "chart.line.xaxis")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No stocks added")
                        .font(.headline)
                    Text("Add a stock to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlBackgroundColor))
            } else {
                Table(filteredStocks, selection: $selectedStock) {
                    TableColumn("Ticker") { row in
                        Text(row.ticker)
                            .fontWeight(.semibold)
                    }
                    
                    TableColumn("Company") { row in
                        Text(row.stock.companyName)
                            .lineLimit(1)
                    }
                    
                    TableColumn("Price") { row in
                        Text(formatPrice(row.stock.currentPrice, ticker: row.ticker))
                            .monospacedDigit()
                    }
                    
                    TableColumn("Change") { row in
                        HStack(spacing: 4) {
                            Image(systemName: row.stock.priceChange >= 0 ? "arrow.up" : "arrow.down")
                                .foregroundColor(row.stock.priceChange >= 0 ? .green : .red)
                            
                            Text(String(format: "%.2f%% (\(row.stock.priceChange >= 0 ? "+" : "")%@%.2f)",
                                       row.stock.percentChange,
                                       row.ticker.hasSuffix(".SI") ? "S$" : "$",
                                       row.stock.priceChange))
                                .monospacedDigit()
                                .foregroundColor(row.stock.priceChange >= 0 ? .green : .red)
                        }
                    }
                    
                    TableColumn("P/E") { row in
                        Text(String(format: "%.1f", row.stock.peRatio))
                            .monospacedDigit()
                    }
                    
                    TableColumn("Market Cap") { row in
                        Text(formatMarketCap(row.stock.marketCap))
                    }
                    
                    TableColumn("Prediction") { row in
                        if let prediction = predictionService.predictions[row.ticker] {
                            HStack {
                                Label(prediction.predictedDirection.rawValue,
                                      systemImage: prediction.predictedDirection == .up ? "arrow.up" : "arrow.down")
                                    .foregroundColor(prediction.predictedDirection == .up ? .green : .red)
                                
                                Text("\(String(format: "%.0f%%", prediction.probability * 100))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("—")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddStock) {
            AddStockView(isPresented: $showAddStock)
                .environmentObject(stockService)
                .environmentObject(predictionService)
        }
    }
    
    private func formatPrice(_ value: Double, ticker: String) -> String {
        let symbol = ticker.hasSuffix(".SI") ? "S$" : "$"
        return String(format: "\(symbol)%.2f", value)
    }
    
    private func formatMarketCap(_ value: Double) -> String {
        if value >= 1e12 {
            return String(format: "$%.1fT", value / 1e12)
        } else if value >= 1e9 {
            return String(format: "$%.1fB", value / 1e9)
        } else if value >= 1e6 {
            return String(format: "$%.1fM", value / 1e6)
        }
        return String(format: "$%.0f", value)
    }
}

// MARK: - Add Stock View

struct AddStockView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var stockService: StockDataService
    @EnvironmentObject var predictionService: PredictionService
    @State private var ticker = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Stock")
                    .font(.headline)
                
                Text("Enter the stock ticker symbol")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            TextField("Ticker (e.g., DBS, D05.SI)", text: $ticker)
                .textFieldStyle(.roundedBorder)
                .textCase(.uppercase)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Add") {
                    addStock()
                }
                .buttonStyle(.borderedProminent)
                .disabled(ticker.isEmpty || isLoading)
            }
            
            if isLoading {
                ProgressView()
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400)
    }
    
    private func addStock() {
        isLoading = true
        let resolvedTicker = stockService.resolveTicker(ticker)
        Task {
            await stockService.addStock(resolvedTicker)
            await predictionService.predictStock(resolvedTicker)
            DispatchQueue.main.async {
                isLoading = false
                isPresented = false
            }
        }
    }
}

#Preview {
    StockListView()
        .environmentObject(StockDataService.shared)
        .environmentObject(PredictionService.shared)
}
