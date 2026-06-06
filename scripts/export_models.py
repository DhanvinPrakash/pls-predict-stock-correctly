#!/usr/bin/env python3
"""Export Keras and sklearn models to JSON bundles for Swift inference."""

import json
import math
import os
import pickle

import tensorflow as tf
from sklearn.tree import _tree

BASE = os.path.join(os.path.dirname(__file__), "..", "ImBusy")
OUT = os.path.join(BASE, "Models")


def layer_info(layer):
    info = {"class": layer.__class__.__name__}
    if hasattr(layer, "activation"):
        act = layer.activation
        info["activation"] = act.__name__ if hasattr(act, "__name__") else str(act)
    if hasattr(layer, "units"):
        info["units"] = int(layer.units)
    if hasattr(layer, "rate"):
        info["rate"] = float(layer.rate)
    info["weights"] = [w.tolist() for w in layer.get_weights()]
    return info


def export_keras(path):
    model = tf.keras.models.load_model(path)
    return {
        "input_shape": list(model.input_shape[1:]),
        "layers": [layer_info(layer) for layer in model.layers],
    }


def export_tree(tree):
    tree_ = tree.tree_
    nodes = []
    for i in range(tree_.node_count):
        if tree_.feature[i] != _tree.TREE_UNDEFINED:
            nodes.append({
                "type": "split",
                "feature": int(tree_.feature[i]),
                "threshold": float(tree_.threshold[i]),
                "left": int(tree_.children_left[i]),
                "right": int(tree_.children_right[i]),
            })
        else:
            values = tree_.value[i][0]
            total = values.sum()
            nodes.append({
                "type": "leaf",
                "prob_up": float(values[1] / total) if total > 0 else 0.5,
            })
    return nodes


def flatten_xgb_tree(node):
    nodes = []

    def walk(n):
        if "leaf" in n:
            nodes.append({"type": "leaf", "score": float(n["leaf"])})
            return len(nodes) - 1
        split_idx = len(nodes)
        nodes.append({
            "type": "split",
            "feature": int(n["split"][1:]),
            "threshold": float(n["split_condition"]),
            "left": -1,
            "right": -1,
        })
        nodes[split_idx]["left"] = walk(n["children"][0])
        nodes[split_idx]["right"] = walk(n["children"][1])
        return split_idx

    walk(node)
    return nodes


def main():
    os.makedirs(OUT, exist_ok=True)

    for key, rel in [
        ("lstm", "Assets.xcassets/LSTM_Model.dataset/LSTM_Model.keras"),
        ("neural_network", "Assets.xcassets/NeuralNetwork_Model.dataset/NeuralNetwork_Model.keras"),
        ("meta_learner", "Assets.xcassets/MetaLearner_Model.dataset/MetaLearner_Model.keras"),
    ]:
        with open(os.path.join(OUT, f"{key}_weights.json"), "w", encoding="utf-8") as f:
            json.dump(export_keras(os.path.join(BASE, rel)), f)

    with open(os.path.join(BASE, "RandomForest_Model.pkl"), "rb") as f:
        rf = pickle.load(f)
    with open(os.path.join(BASE, "XGBoost_Model.pkl"), "rb") as f:
        xgb = pickle.load(f)

    bundle = {
        "feature_count": 15,
        "random_forest": [export_tree(est) for est in rf.estimators_],
        "xgboost": [
            flatten_xgb_tree(json.loads(dump))
            for dump in xgb.get_booster().get_dump(dump_format="json")
        ],
    }

    with open(os.path.join(OUT, "tree_models.json"), "w", encoding="utf-8") as f:
        json.dump(bundle, f)

    print(f"Exported models to {OUT}")


if __name__ == "__main__":
    main()
