//
//  PredictionService.swift
//  ImBusy
//
//  Created by dhanvin_macbook on 6/6/26.
//

import Foundation
import Combine

class PredictionService: ObservableObject {
    static let shared = PredictionService()
    
    @Published var predictions: [String: StockPrediction] = [:]
    @Published var predictionDetails: [String: PredictionDetail] = [:]
    @Published var isCalculating = false
    @Published var modelAccuracy: Double = 0.0
    @Published var modelStatus: String = "Loading models..."
    
    private let stockService = StockDataService.shared
    private let modelBundle = ModelBundleLoader.shared
    
    init() {
        loadModels()
    }
    
    // MARK: - Public Methods
    
    func predictStock(_ ticker: String) async {
        await MainActor.run { isCalculating = true }
        defer { Task { @MainActor in isCalculating = false } }
        
        do {
            guard modelBundle.isLoaded else {
                throw NSError(domain: "PredictionService", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: modelBundle.loadError ?? "Models not loaded"])
            }
            
            guard let technicalFeatures = stockService.technicalFeatures[ticker],
                  let fundamentalFeatures = stockService.fundamentalFeatures[ticker],
                  let sentimentFeatures = stockService.sentimentFeatures[ticker],
                  let macroFeatures = stockService.macroData else {
                throw NSError(domain: "Missing features", code: -1)
            }
            
            let combinedFeatures = CombinedFeatures(
                ticker: ticker,
                technical: technicalFeatures,
                fundamental: fundamentalFeatures,
                sentiment: sentimentFeatures,
                macro: macroFeatures,
                date: Date()
            )
            
            let normalizedFeatures = normalizeFeatures(combinedFeatures)
            
            let lstmPred = runLSTMPrediction(normalizedFeatures)
            let xgbPred = runXGBPrediction(normalizedFeatures)
            let rfPred = runRandomForestPrediction(normalizedFeatures)
            let nnPred = runNeuralNetworkPrediction(normalizedFeatures)
            
            let finalPrediction = blendPredictions(
                lstm: lstmPred,
                xgb: xgbPred,
                rf: rfPred,
                nn: nnPred
            )
            
            let modelScores = [lstmPred.probability, xgbPred.probability, rfPred.probability, nnPred.probability]
            let modelAgreement = calculateModelAgreement(modelScores)
            let variance = calculateVariance(modelScores)
            let confidence = 1.0 - min(variance * 0.5, 1.0)
            
            let stockPrediction = StockPrediction(
                id: UUID(),
                ticker: ticker,
                predictedDirection: finalPrediction.0,
                probability: finalPrediction.1,
                confidence: confidence,
                lstmScore: lstmPred.probability,
                xgbScore: xgbPred.probability,
                rfScore: rfPred.probability,
                nnScore: nnPred.probability,
                predictionDate: Date(),
                targetDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
                modelAgreement: modelAgreement
            )
            
            let detail = generatePredictionDetail(
                prediction: stockPrediction,
                technical: technicalFeatures,
                fundamental: fundamentalFeatures,
                sentiment: sentimentFeatures,
                macro: macroFeatures
            )
            
            await MainActor.run {
                self.predictions[ticker] = stockPrediction
                self.predictionDetails[ticker] = detail
            }
            
        } catch {
            print("Prediction error: \(error.localizedDescription)")
            await MainActor.run {
                self.modelStatus = "Prediction failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadModels() {
        modelBundle.loadModels()
        if modelBundle.isLoaded {
            modelStatus = "Trained ensemble models loaded"
            print(modelStatus)
        } else {
            modelStatus = modelBundle.loadError ?? "Failed to load models"
            print(modelStatus)
        }
    }
    
    private func normalizeFeatures(_ features: CombinedFeatures) -> [Double] {
        var vector: [Double] = []
        
        vector.append(normalize(features.technical.rsi, min: 0, max: 100))
        vector.append(normalize(features.technical.macd, min: -50, max: 50))
        vector.append(normalize(features.technical.bollingerUpper, min: 0, max: 1000))
        vector.append(normalize(features.technical.sma20, min: 0, max: 1000))
        vector.append(normalize(features.technical.volatility20D, min: 0, max: 1))
        
        vector.append(normalize(features.fundamental.peRatio, min: 0, max: 100))
        vector.append(normalize(features.fundamental.roe, min: -1, max: 1))
        vector.append(normalize(features.fundamental.debtToEquity, min: 0, max: 3))
        vector.append(normalize(features.fundamental.revenueGrowth, min: -1, max: 1))
        vector.append(normalize(features.fundamental.dividendYield, min: 0, max: 0.1))
        
        vector.append(normalize(features.sentiment.newsScore7D, min: -1, max: 1))
        vector.append(normalize(features.sentiment.twitterSentiment, min: -1, max: 1))
        vector.append(normalize(features.sentiment.impliedVolatility, min: 0, max: 1))
        
        vector.append(normalize(features.macro.vixIndex, min: 10, max: 40))
        vector.append(normalize(features.macro.federalRate, min: 0, max: 0.1))
        vector.append(normalize(features.macro.inflation, min: -0.02, max: 0.08))
        
        return vector
    }
    
    private func normalize(_ value: Double, min: Double, max: Double) -> Double {
        guard min != max else { return 0.5 }
        return (value - min) / (max - min)
    }
    
    // MARK: - Model Predictions
    
    private func runLSTMPrediction(_ features: [Double]) -> (direction: PredictionDirection, probability: Double) {
        guard let model = modelBundle.lstmModel else { return (.neutral, 0.5) }
        let probability = SwiftMLInference.predictLSTM(model, features: features)
        return (probability > 0.5 ? .up : .down, probability)
    }
    
    private func runXGBPrediction(_ features: [Double]) -> (direction: PredictionDirection, probability: Double) {
        guard let trees = modelBundle.treeModels?.xgboost else { return (.neutral, 0.5) }
        let probability = SwiftMLInference.predictXGBoost(trees, features: features)
        return (probability > 0.5 ? .up : .down, probability)
    }
    
    private func runRandomForestPrediction(_ features: [Double]) -> (direction: PredictionDirection, probability: Double) {
        guard let trees = modelBundle.treeModels?.randomForest else { return (.neutral, 0.5) }
        let probability = SwiftMLInference.predictRandomForest(trees, features: features)
        return (probability > 0.5 ? .up : .down, probability)
    }
    
    private func runNeuralNetworkPrediction(_ features: [Double]) -> (direction: PredictionDirection, probability: Double) {
        guard let model = modelBundle.neuralNetworkModel else { return (.neutral, 0.5) }
        let probability = SwiftMLInference.predictNeuralNetwork(model, features: features)
        return (probability > 0.5 ? .up : .down, probability)
    }
    
    // MARK: - Ensemble Blending
    
    private func blendPredictions(
        lstm: (direction: PredictionDirection, probability: Double),
        xgb: (direction: PredictionDirection, probability: Double),
        rf: (direction: PredictionDirection, probability: Double),
        nn: (direction: PredictionDirection, probability: Double)
    ) -> (PredictionDirection, Double) {
        if let metaModel = modelBundle.metaLearnerModel {
            let baseScores = [lstm.probability, xgb.probability, rf.probability, nn.probability]
            let metaProbability = SwiftMLInference.predictNeuralNetwork(metaModel, features: baseScores)
            return (metaProbability > 0.5 ? .up : .down, metaProbability)
        }
        
        let avgProb = (lstm.probability * 0.25 +
                       xgb.probability * 0.35 +
                       rf.probability * 0.25 +
                       nn.probability * 0.15)
        
        return (avgProb > 0.5 ? .up : .down, avgProb)
    }
    
    private func calculateModelAgreement(_ predictions: [Double]) -> Double {
        let directions = predictions.map { $0 > 0.5 }
        let agreeing = directions.filter { $0 == directions.first }.count
        return Double(agreeing) / Double(directions.count)
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
    
    // MARK: - Explanation Generation
    
    private func generatePredictionDetail(
        prediction: StockPrediction,
        technical: TechnicalFeatures,
        fundamental: FundamentalFeatures,
        sentiment: SentimentFeatures,
        macro: MacroFeatures
    ) -> PredictionDetail {
        
        let technicalInsight: String
        if technical.rsi > 70 {
            technicalInsight = "RSI indicates overbought conditions. MACD signal: \(String(format: "%.2f", technical.macd))"
        } else if technical.rsi < 30 {
            technicalInsight = "RSI indicates oversold conditions. Potential reversal brewing."
        } else {
            technicalInsight = "RSI neutral at \(String(format: "%.1f", technical.rsi)). Price above 20-SMA."
        }
        
        let fundamentalInsight: String
        if fundamental.peRatio > 30 {
            fundamentalInsight = "P/E ratio elevated at \(String(format: "%.1f", fundamental.peRatio)). Growth story required."
        } else if fundamental.peRatio < 15 {
            fundamentalInsight = "P/E ratio low at \(String(format: "%.1f", fundamental.peRatio)). Possibly undervalued."
        } else {
            fundamentalInsight = "P/E ratio fair at \(String(format: "%.1f", fundamental.peRatio))."
        }
        
        let sentimentInsight = "News sentiment: \(String(format: "%.2f", sentiment.newsScore7D)) (7D). Social mentions: \(sentiment.socialMentions)"
        let macroInsight = "VIX at \(String(format: "%.1f", macro.vixIndex)). Fed rate: \(String(format: "%.2f%%", macro.federalRate * 100))"
        
        return PredictionDetail(
            direction: prediction.predictedDirection,
            probability: prediction.probability,
            confidence: prediction.confidence,
            rationale: "Trained ensemble (LSTM, XGBoost, Random Forest, Neural Net + Meta-Learner) predicts \(prediction.predictedDirection.rawValue) with \(String(format: "%.1f%%", prediction.probability * 100)) probability",
            technicalInsight: technicalInsight,
            fundamentalInsight: fundamentalInsight,
            sentimentInsight: sentimentInsight,
            macroInsight: macroInsight
        )
    }
}
