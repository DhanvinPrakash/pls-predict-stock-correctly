//
//  SettingsView.swift
//  ImBusy
//
//  Created by dhanvin_macbook on 6/6/26.
//


import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var stockService: StockDataService
    @State private var alphaVantageKey = ""
    @State private var newsAPIKey = ""
    @State private var fredAPIKey = ""
    @State private var updateInterval = 15.0
    @State private var showNotifications = true
    @State private var darkMode = false
    
    var body: some View {
        TabView {
            VStack(spacing: 20) {
                Form {
                    Section("API Configuration") {
                        SecureField("Alpha Vantage API Key", text: $alphaVantageKey)
                        SecureField("News API Key", text: $newsAPIKey)
                        SecureField("FRED API Key", text: $fredAPIKey)
                        
                        Button(action: { saveAPIKeys() }) {
                            Label("Save API Keys", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Section("Update Settings") {
                        Slider(value: $updateInterval, in: 5...60, step: 5) {
                            Text("Update Interval (minutes)")
                        }
                        
                        Text("\(Int(updateInterval)) minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .tabItem {
                Label("API Keys", systemImage: "key.fill")
            }
            
            VStack(spacing: 20) {
                Form {
                    Section("Notifications") {
                        Toggle("Enable Notifications", isOn: $showNotifications)
                        Toggle("Enable Sound Alerts", isOn: $showNotifications)
                    }
                    
                    Section("Appearance") {
                        Toggle("Dark Mode", isOn: $darkMode)
                    }
                    
                    Section("Data") {
                        Button(role: .destructive) {
                            clearCache()
                        } label: {
                            Label("Clear Cache", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .tabItem {
                Label("Preferences", systemImage: "gear")
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("About Stock Predictor")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Version 1.0.0")
                        .font(.caption)
                    
                    Text("A comprehensive macOS app for stock prediction using ensemble machine learning models.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                Text("Technology Stack")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Frontend", value: "SwiftUI")
                    InfoRow(label: "ML Framework", value: "Core ML")
                    InfoRow(label: "Models", value: "LSTM, XGBoost, Random Forest, Neural Network")
                    InfoRow(label: "Data Sources", value: "Alpha Vantage, NewsAPI, FRED")
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func saveAPIKeys() {
        UserDefaults.standard.set(alphaVantageKey, forKey: "alphaVantageKey")
        UserDefaults.standard.set(newsAPIKey, forKey: "newsAPIKey")
        UserDefaults.standard.set(fredAPIKey, forKey: "fredAPIKey")
    }
    
    private func clearCache() {
        // Clear any cached data
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(StockDataService.shared)
}