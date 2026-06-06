//
//  ModelBundle.swift
//  ImBusy
//

import Foundation

struct WeightTensor {
    let matrix: [[Double]]
    let vector: [Double]
}

struct KerasLayerExport: Decodable {
    let className: String
    let activation: String?
    let units: Int?
    let rate: Double?
    let weights: [WeightTensor]
    
    enum CodingKeys: String, CodingKey {
        case className = "class"
        case activation, units, rate, weights
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        className = try container.decode(String.self, forKey: .className)
        activation = try container.decodeIfPresent(String.self, forKey: .activation)
        units = try container.decodeIfPresent(Int.self, forKey: .units)
        rate = try container.decodeIfPresent(Double.self, forKey: .rate)
        
        let rawWeights = try container.decode([AnyDecodable].self, forKey: .weights)
        weights = rawWeights.map { WeightTensor.from($0.value) }
    }
}

extension WeightTensor {
    static func from(_ value: Any) -> WeightTensor {
        if let matrix = value as? [[Double]] {
            if matrix.count == 1 {
                return WeightTensor(matrix: matrix, vector: matrix[0])
            }
            return WeightTensor(matrix: matrix, vector: matrix.flatMap { $0 })
        }
        
        if let vector = value as? [Double] {
            return WeightTensor(matrix: [vector], vector: vector)
        }
        
        if let nested = value as? [Any] {
            if let matrix = nested as? [[Double]] {
                return from(matrix)
            }
            if let vector = nested as? [Double] {
                return from(vector)
            }
        }
        
        return WeightTensor(matrix: [], vector: [])
    }
}

struct KerasModelExport: Decodable {
    let inputShape: [Int]
    let layers: [KerasLayerExport]
    
    enum CodingKeys: String, CodingKey {
        case inputShape = "input_shape"
        case layers
    }
}

struct TreeNode: Decodable {
    let type: String
    let feature: Int?
    let threshold: Double?
    let left: Int?
    let right: Int?
    let probUp: Double?
    let score: Double?
    
    enum CodingKeys: String, CodingKey {
        case type, feature, threshold, left, right
        case probUp = "prob_up"
        case score
    }
}

typealias TreeModel = [TreeNode]

struct TreeModelBundle: Decodable {
    let featureCount: Int
    let randomForest: [TreeModel]
    let xgboost: [TreeModel]
    
    enum CodingKeys: String, CodingKey {
        case featureCount = "feature_count"
        case randomForest = "random_forest"
        case xgboost
    }
}

private struct AnyDecodable: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([Double].self) {
            value = array
        } else if let number = try? container.decode(Double.self) {
            value = number
        } else if let nested = try? container.decode([AnyDecodable].self) {
            value = nested.map(\.value)
        } else {
            value = 0.0
        }
    }
}

final class ModelBundleLoader {
    static let shared = ModelBundleLoader()
    
    private(set) var lstmModel: KerasModelExport?
    private(set) var neuralNetworkModel: KerasModelExport?
    private(set) var metaLearnerModel: KerasModelExport?
    private(set) var treeModels: TreeModelBundle?
    private(set) var loadError: String?
    private(set) var isLoaded = false
    
    func loadModels() {
        guard !isLoaded else { return }
        
        do {
            lstmModel = try loadJSON("lstm_weights", as: KerasModelExport.self)
            neuralNetworkModel = try loadJSON("neural_network_weights", as: KerasModelExport.self)
            metaLearnerModel = try loadJSON("meta_learner_weights", as: KerasModelExport.self)
            treeModels = try loadJSON("tree_models", as: TreeModelBundle.self)
            isLoaded = true
            print("Loaded trained models from bundle")
        } catch {
            loadError = error.localizedDescription
            print("Model bundle load error: \(error.localizedDescription)")
        }
    }
    
    private func loadJSON<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw NSError(
                domain: "ModelBundleLoader",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Missing \(name).json in app bundle"]
            )
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
