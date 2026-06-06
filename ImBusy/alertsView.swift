import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var portfolioManager: PortfolioManager
    @EnvironmentObject var stockService: StockDataService
    @State private var showAddAlert = false
    
    var body: some View {
        VStack {
            HStack {
                Text("Price & Prediction Alerts")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showAddAlert = true }) {
                    Label("Add Alert", systemImage: "bell.badge.plus")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            
            if portfolioManager.alerts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No alerts set")
                        .font(.headline)
                    
                    Text("Create an alert to get notified about price changes or predictions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.controlBackgroundColor))
            } else {
                Table(portfolioManager.alerts) {
                    TableColumn("Ticker", value: \.ticker)
                    
                    TableColumn("Type") { alert in
                        Text(alert.conditionType.label)
                    }
                    
                    TableColumn("Threshold") { alert in
                        if alert.conditionType == .priceAbove || alert.conditionType == .priceBelow {
                            Text(String(format: "$%.2f", alert.threshold))
                                .monospacedDigit()
                        } else {
                            Text("—")
                        }
                    }
                    
                    TableColumn("Status") { alert in
                        HStack(spacing: 8) {
                            Image(systemName: alert.isActive ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(alert.isActive ? .green : .gray)
                            
                            Text(alert.isActive ? "Active" : "Inactive")
                                .font(.caption)
                        }
                    }
                    
                    TableColumn("") { alert in
                        HStack(spacing: 8) {
                            Button(action: { portfolioManager.toggleAlert(alert) }) {
                                Image(systemName: alert.isActive ? "pause.circle" : "play.circle")
                            }
                            .buttonStyle(.plain)
                            .help(alert.isActive ? "Pause alert" : "Resume alert")
                            
                            Button(action: { portfolioManager.removeAlert(alert) }) {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete alert")
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showAddAlert) {
            AddAlertView(isPresented: $showAddAlert)
                .environmentObject(portfolioManager)
                .environmentObject(stockService)
        }
    }
}

// MARK: - Add Alert View

struct AddAlertView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var portfolioManager: PortfolioManager
    @EnvironmentObject var stockService: StockDataService
    @State private var selectedTicker = ""
    @State private var selectedType: AlertCondition.AlertType = .priceAbove
    @State private var threshold = ""
    
    var availableTickers: [String] {
        Array(stockService.stocks.keys).sorted()
    }
    
    var isValid: Bool {
        !selectedTicker.isEmpty &&
        (selectedType == .priceAbove || selectedType == .priceBelow ? !threshold.isEmpty && Double(threshold) ?? 0 > 0 : true)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add Alert")
                    .font(.headline)
                
                Text("Get notified when specific conditions are met")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                Picker("Stock Ticker", selection: $selectedTicker) {
                    ForEach(availableTickers, id: \.self) { ticker in
                        Text(ticker).tag(ticker)
                    }
                }
                
                Picker("Alert Type", selection: $selectedType) {
                    ForEach(AlertCondition.AlertType.allCases, id: \.self) { type in
                        Text(type.label).tag(type)
                    }
                }
                
                if selectedType == .priceAbove || selectedType == .priceBelow {
                    TextField("Threshold Price", text: $threshold)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Add") {
                    addAlert()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 400)
    }
    
    private func addAlert() {
        let value = Double(threshold) ?? 0
        portfolioManager.addAlert(
            ticker: selectedTicker,
            conditionType: selectedType,
            threshold: value
        )
        isPresented = false
    }
}

#Preview {
    AlertsView()
        .environmentObject(PortfolioManager.shared)
        .environmentObject(StockDataService.shared)
}
