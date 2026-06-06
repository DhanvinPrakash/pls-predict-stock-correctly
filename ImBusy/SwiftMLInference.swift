//
//  SwiftMLInference.swift
//  ImBusy
//

import Foundation

enum SwiftMLInference {
    
    // MARK: - Activations
    
    static func relu(_ values: [Double]) -> [Double] {
        values.map { max(0, $0) }
    }
    
    static func sigmoid(_ x: Double) -> Double {
        1.0 / (1.0 + exp(-x))
    }
    
    static func sigmoid(_ values: [Double]) -> [Double] {
        values.map(sigmoid)
    }
    
    static func tanh(_ values: [Double]) -> [Double] {
        values.map { Foundation.tanh($0) }
    }
    
    // MARK: - Dense Layer
    
    static func dense(_ input: [Double], weights: [[Double]], bias: [Double], activation: String) -> [Double] {
        let outputSize = weights[0].count
        var output = Array(repeating: 0.0, count: outputSize)
        
        for i in 0..<input.count {
            for j in 0..<outputSize {
                output[j] += input[i] * weights[i][j]
            }
        }
        
        for j in 0..<outputSize {
            output[j] += bias[j]
        }
        
        switch activation {
        case "relu": return relu(output)
        case "sigmoid": return sigmoid(output)
        case "tanh": return tanh(output)
        default: return output
        }
    }
    
    // MARK: - LSTM
    
    static func lstmSequence(
        _ sequence: [[Double]],
        kernel: [[Double]],
        recurrentKernel: [[Double]],
        bias: [Double],
        units: Int,
        returnSequences: Bool
    ) -> [[Double]] {
        var hidden = Array(repeating: 0.0, count: units)
        var cell = Array(repeating: 0.0, count: units)
        var outputs: [[Double]] = []
        
        for timestep in sequence {
            let (newHidden, newCell) = lstmStep(
                timestep,
                hidden: hidden,
                cell: cell,
                kernel: kernel,
                recurrentKernel: recurrentKernel,
                bias: bias,
                units: units
            )
            hidden = newHidden
            cell = newCell
            outputs.append(hidden)
        }
        
        return returnSequences ? outputs : [hidden]
    }
    
    private static func lstmStep(
        _ input: [Double],
        hidden: [Double],
        cell: [Double],
        kernel: [[Double]],
        recurrentKernel: [[Double]],
        bias: [Double],
        units: Int
    ) -> ([Double], [Double]) {
        var gates = Array(repeating: 0.0, count: units * 4)
        
        for i in 0..<input.count {
            for j in 0..<gates.count {
                gates[j] += input[i] * kernel[i][j]
            }
        }
        
        for i in 0..<hidden.count {
            for j in 0..<gates.count {
                gates[j] += hidden[i] * recurrentKernel[i][j]
            }
        }
        
        for j in 0..<gates.count {
            gates[j] += bias[j]
        }
        
        var inputGate = Array(gates[0..<units])
        var forgetGate = Array(gates[units..<units * 2])
        var cellGate = Array(gates[units * 2..<units * 3])
        var outputGate = Array(gates[units * 3..<units * 4])
        
        inputGate = sigmoid(inputGate)
        forgetGate = sigmoid(forgetGate)
        cellGate = tanh(cellGate)
        outputGate = sigmoid(outputGate)
        
        var newCell = Array(repeating: 0.0, count: units)
        var newHidden = Array(repeating: 0.0, count: units)
        
        for i in 0..<units {
            newCell[i] = forgetGate[i] * cell[i] + inputGate[i] * cellGate[i]
            newHidden[i] = outputGate[i] * Foundation.tanh(newCell[i])
        }
        
        return (newHidden, newCell)
    }
    
    // MARK: - Tree Models
    
    static func predictRandomForest(_ trees: [TreeModel], features: [Double]) -> Double {
        guard !trees.isEmpty else { return 0.5 }
        let probs = trees.map { predictTree($0, features: features).probUp }
        return probs.reduce(0, +) / Double(probs.count)
    }
    
    static func predictXGBoost(_ trees: [TreeModel], features: [Double]) -> Double {
        guard !trees.isEmpty else { return 0.5 }
        let margin = trees.map { predictTree($0, features: features).score }.reduce(0, +)
        return sigmoid(margin)
    }
    
    private static func predictTree(_ tree: TreeModel, features: [Double]) -> (probUp: Double, score: Double) {
        var index = 0
        while tree[index].type == "split" {
            let node = tree[index]
            guard let feature = node.feature, let threshold = node.threshold,
                  let left = node.left, let right = node.right else { break }
            index = features[feature] <= threshold ? left : right
        }
        
        let leaf = tree[index]
        return (leaf.probUp ?? 0.5, leaf.score ?? 0)
    }
    
    // MARK: - Keras JSON Models
    
    static func predictNeuralNetwork(_ model: KerasModelExport, features: [Double]) -> Double {
        var activation = features
        
        for layer in model.layers {
            switch layer.className {
            case "Dense":
                guard layer.weights.count == 2,
                      let act = layer.activation else { continue }
                let kernel = layer.weights[0].matrix
                let bias = layer.weights[1].vector
                activation = dense(activation, weights: kernel, bias: bias, activation: act)
                if activation.count == 1 { return activation[0] }
            default:
                continue
            }
        }
        
        return activation.first ?? 0.5
    }
    
    static func predictLSTM(_ model: KerasModelExport, features: [Double]) -> Double {
        let timesteps = model.inputShape[0]
        let featureCount = model.inputShape.count > 1 ? model.inputShape[1] : 1
        
        var sequence: [[Double]] = []
        for step in 0..<timesteps {
            let start = step * featureCount
            let end = min(start + featureCount, features.count)
            var values = Array(features[start..<end])
            while values.count < featureCount { values.append(0) }
            sequence.append(values)
        }
        
        var activation: [[Double]] = sequence
        var lstmLayerIndex = 0
        
        for layer in model.layers {
            switch layer.className {
            case "LSTM":
                guard layer.weights.count == 3,
                      let units = layer.units else { continue }
                let returnSequences = lstmLayerIndex == 0
                activation = lstmSequence(
                    activation,
                    kernel: layer.weights[0].matrix,
                    recurrentKernel: layer.weights[1].matrix,
                    bias: layer.weights[2].vector,
                    units: units,
                    returnSequences: returnSequences
                )
                lstmLayerIndex += 1
            case "Dense":
                guard layer.weights.count == 2,
                      let act = layer.activation else { continue }
                let flat = activation.last ?? []
                let kernel = layer.weights[0].matrix
                let bias = layer.weights[1].vector
                let output = dense(flat, weights: kernel, bias: bias, activation: act)
                if output.count == 1 { return output[0] }
                activation = [output]
            default:
                continue
            }
        }
        
        return activation.first?.first ?? 0.5
    }
}
