# StockpredictSON

A macOS app that uses Apple CoreML and Apple Intelligence (on-device LLM) to predict whether you should **Buy**, **Hold**, or **Sell** DBS Group Holdings (SGX: D05) stock. Market data is fetched live from Yahoo Finance, processed into a CSV with a custom target column (`Target_Next_Close`), and used to train a CoreML regression model — all on your Mac, with no data leaving your device.

## Getting Started

These instructions will get ImBusy up and running on your local machine for development and testing purposes.

### Prerequisites

What you need to install before running the project:

**Xcode 26 Beta**
Required for SwiftUI, Swift Charts, and the FoundationModels framework (Apple Intelligence API).
Download from [developer.apple.com](https://developer.apple.com/xcode/)

**macOS 26 + Apple Silicon (M1 or newer)**
Required for CoreML inference and on-device Apple Intelligence.
Apple Intelligence must be enabled under System Settings → Apple Intelligence & Siri.

**Python 3.x**
Required only for the data collection and dataset preparation pipeline.

```bash
python3 --version
```

**yfinance and pandas**
Used to download DBS historical data from Yahoo Finance and format it for CoreML training.

```bash
pip install yfinance pandas
```

---

### Installing

A step-by-step guide to getting a development environment running.

**1. Clone the repository**

```bash
git clone https://github.com/your-username/StockpredictSON.git
cd StockpredictSON
```

**2. Download and prepare the dataset**

Run the data pipeline script to fetch DBS historical OHLCV data from Yahoo Finance and generate a training-ready CSV with the `Target_Next_Close` column as the prediction target.

```bash
cd data-pipeline
python3 fetch_dbs.py
```

This creates `dbs_training_data.csv` in the project root. The script fetches the last 5 years of daily DBS (D05.SI) data and appends a `Target_Next_Close` column — the next day's closing price — which CoreML trains to predict.

**3. Train the CoreML model**

Open Create ML in Xcode (`Xcode → Open Developer Tool → Create ML`), create a new **Tabular Regression** project, and import `dbs_training_data.csv`.

- **Target column:** `Target_Next_Close`
- **Feature columns:** `Open`, `High`, `Low`, `Close`, `Volume`, `Price`
- Train and export as `dbsstockpredictor.mlmodel`

```
Tip: aim for an RMSE below 1.5 on the validation split.
```

**4. Add the model to Xcode**

Drag `dbsstockpredictor.mlmodel` into the Xcode project navigator. Xcode will auto-generate the `dbsstockpredictor` Swift class used by `DBSModelLink`.

**5. Add the Apple Intelligence entitlement**

Open `StockpredictSON.entitlements` and add:

```xml
<key>com.apple.developer.foundation-models</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

**6. Build and run**

Select your Mac as the target and hit **Run** (`⌘R`). The app will fetch live DBS data on launch and display a Buy / Hold / Sell verdict immediately.

---

## Running the Tests

### End-to-end tests

The UI test suite verifies that the full pipeline — fetch → predict → verdict → Aria response — completes without error.

```bash
xcodebuild test -scheme StockpredictSON -destination 'platform=macOS'
```

This tests:
- `MarketFetcher` correctly parses Yahoo Finance and Stooq responses
- `DBSModelLink` returns a plausible value within ±15% of the current close
- `technicalForecast()` clamps output to ±3% of close
- The verdict card renders with a non-empty signal string

### Unit tests — prediction sanity

Verifies the OOD (out-of-distribution) guard rejects stale CoreML outputs:

```bash
# In Xcode: Product → Test (⌘U)
```

```swift
// Example: CoreML returning $38 on a $63 stock should be rejected
let deviation = abs(38.0 - 63.0) / 63.0   // 0.396 → > 0.15 threshold → rejected ✓
```

---

## Deployment

This app is intended for local macOS use only. There is no server component — all inference runs on-device via Apple Neural Engine.

To distribute to another Mac:

1. Archive the app in Xcode (`Product → Archive`)
2. Export as a **Developer ID** signed application
3. The recipient must have macOS 26, Apple Silicon, and Apple Intelligence enabled
4. The `.mlmodel` is bundled inside the `.app` — no separate installation needed

---

## Built With

* [SwiftUI](https://developer.apple.com/xcode/swiftui/) — UI framework
* [Swift Charts](https://developer.apple.com/documentation/charts) — Price history and forecast chart
* [CoreML](https://developer.apple.com/documentation/coreml) — On-device stock price regression model
* [FoundationModels](https://developer.apple.com/documentation/foundationmodels) — Apple Intelligence on-device LLM (Aria assistant)
* [Create ML](https://developer.apple.com/machine-learning/create-ml/) — Model training (Tabular Regression)
* [yfinance](https://github.com/ranaroussi/yfinance) — Yahoo Finance data pipeline
* [pandas](https://pandas.pydata.org/) — Dataset preparation and CSV formatting
* [Stooq](https://stooq.com) — Fallback market data source

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please ensure any new prediction methods pass the ±15% OOD sanity check and that Aria's system prompt is updated to reflect any new signals or data sources.

---

## Versioning

We use [SemVer](http://semver.org/) for versioning. For available versions, see the [tags on this repository](https://github.com/your-username/StockpredictSON/tags).

---

## Authors

* **Dhanvin** — Initial build, CoreML pipeline, Apple Intelligence integration

---

## License

This project is licensed under the MIT License — see the [LICENSE.md](LICENSE.md) file for details.

---

## Acknowledgments

* [ranaroussi/yfinance](https://github.com/ranaroussi/yfinance) — made the data pipeline trivial
* Apple Machine Learning team — Create ML Tabular Regression docs
* [Stooq](https://stooq.com) — reliable fallback when Yahoo Finance blocks the request
* DBS Investor Relations — public financial data used for model context
