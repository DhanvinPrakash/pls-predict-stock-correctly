# StockpredictSON

A macOS app that uses Apple CoreML and Apple Intelligence (on-device LLM) to predict whether you should **Buy**, **Hold**, or **Sell** DBS Group Holdings (SGX: D05) stock. Market data is fetched live from Yahoo Finance, processed into a CSV with a custom target column (`Target_Next_Close`), and used to train a CoreML regression model — all on your Mac, with no data leaving your device.

Built simply for any average joe to install and make smarter decisions about their DBS position. Currently running predictions for DBS only — might add more SGX stocks down the line.

**Known issues / work in progress:**
- Aria assistant has some weird line spacing in streamed responses — being looked into
- CoreML predictions can drift when DBS price moves far from the training distribution (OOD guard in place as a workaround)
- More datapoints and technical indicators planned for the next model version

---

## How It Works

```
Yahoo Finance API
      ↓
  MarketFetcher (Swift)         ← tries Yahoo → Stooq → offline seed
      ↓
  OHLCV + 30-day history
      ↓
  DBSModelLink (CoreML)         ← trained on dbs_training_data.csv
      ↓  (OOD check: reject if >15% from current close)
  technicalForecast() fallback  ← momentum + trend + mean-reversion
      ↓
  BUY / HOLD / SELL verdict
      ↓
  Aria (Apple Intelligence)     ← on-device LLM, no internet required
      ↓
  SwiftUI chat interface
```

---

## Project Structure

```
StockpredictSON/
├── StockpredictSON/
│   └── ContentView.swift           # Entire app — single file
├── data-pipeline/
│   ├── fetch_dbs.py                # Downloads DBS history via yfinance
│   └── dbs_training_data.csv       # Generated training dataset
├── Models/
│   └── dbsstockpredictor.mlmodel   # Trained CoreML regression model
├── StockpredictSON.entitlements    # Apple Intelligence + network entitlements
└── README.md
```

---

## Getting Started

These instructions will get StockpredictSON up and running on your local machine for development and testing purposes.

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

The CSV schema looks like this:

```
Date, Open, High, Low, Close, Volume, Price, Target_Next_Close
2024-01-02, 32.10, 32.45, 31.90, 32.30, 3812000, 32.30, 32.55
2024-01-03, 32.55, 32.80, 32.40, 32.70, 4201000, 32.70, 32.45
...
```

**3. Train the CoreML model**

Open Create ML in Xcode (`Xcode → Open Developer Tool → Create ML`), create a new **Tabular Regression** project, and import `dbs_training_data.csv`.

- **Target column:** `Target_Next_Close`
- **Feature columns:** `Open`, `High`, `Low`, `Close`, `Volume`, `Price`
- Train and export as `dbsstockpredictor.mlmodel`

Aim for a validation RMSE below 1.5. If it's higher, try increasing the max iterations or adding more feature columns (e.g. 5-day moving average, RSI).

**4. Add the model to Xcode**

Drag `dbsstockpredictor.mlmodel` into the Xcode project navigator under the `Models/` group. Xcode will auto-generate the `dbsstockpredictor` Swift class used by `DBSModelLink`.

**5. Add the Apple Intelligence entitlement**

Open `StockpredictSON.entitlements` and add:

```xml
<key>com.apple.developer.foundation-models</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

Without `com.apple.security.network.client`, the sandbox silently blocks all outbound network calls — Yahoo Finance fetches will fail with no error message.

**6. Build and run**

Select your Mac as the run destination and hit **Run** (`⌘R`). The app fetches live DBS data on launch and shows a Buy / Hold / Sell verdict within a few seconds.

```
Expected on first launch:
  • Loading screen → "Fetching live DBS data…"
  • Left panel: price chart + BUY/HOLD/SELL verdict card
  • Right panel: Aria chat with a welcome message summarising the forecast
```

---

## Running the Tests

### End-to-end tests

The UI test suite verifies that the full pipeline — fetch → predict → verdict → Aria response — completes without error.

```bash
xcodebuild test -scheme StockpredictSON -destination 'platform=macOS'
```

This covers:
- `MarketFetcher` correctly parses Yahoo Finance and Stooq CSV responses
- `DBSModelLink` returns a plausible value (OOD guard: within ±15% of current close)
- `technicalForecast()` clamps output to ±3% of close price
- The verdict card renders with a non-empty signal string
- Aria session initialises without throwing when Apple Intelligence is available

### Unit tests — prediction sanity check

Verifies the OOD guard correctly rejects stale CoreML outputs when DBS price has moved far from the training range:

```bash
# In Xcode: Product → Test  (⌘U)
```

```swift
// CoreML returning $38 on a $63 stock must be rejected
let deviation = abs(38.0 - 63.0) / 63.0
// deviation = 0.396  →  exceeds 0.15 threshold  →  rejected, technicalForecast() used ✓

// CoreML returning $62.10 on a $63 stock should be accepted
let deviation2 = abs(62.10 - 63.0) / 63.0
// deviation2 = 0.014  →  within 0.15 threshold  →  CoreML result used ✓
```

---

## Roadmap

- [ ] Retrain CoreML model on post-2024 DBS prices ($40–$65 range)
- [ ] Add RSI, MACD, and 20-day SMA as feature columns for better accuracy
- [ ] Fix Aria streaming line-spacing bug in `StreamBubble`
- [ ] Support additional SGX tickers (OCBC, UOB)
- [ ] Persist last-known quote to disk so the app loads instantly offline
- [ ] Add a portfolio tracker tab for multiple positions

---

## Deployment

This app is intended for local macOS use only. There is no server component — all inference runs on-device via the Apple Neural Engine.

To distribute to another Mac:

1. Archive the app in Xcode (`Product → Archive`)
2. Export as a **Developer ID** signed application
3. The recipient must have macOS 26, Apple Silicon, and Apple Intelligence enabled in System Settings
4. The `.mlmodel` is bundled inside the `.app` — no separate installation needed on the recipient's machine

---

## Built With

* [SwiftUI](https://developer.apple.com/xcode/swiftui/) — UI framework
* [Swift Charts](https://developer.apple.com/documentation/charts) — Price history and forecast chart
* [CoreML](https://developer.apple.com/documentation/coreml) — On-device stock price regression model
* [FoundationModels](https://developer.apple.com/documentation/foundationmodels) — Apple Intelligence on-device LLM (Aria assistant)
* [Create ML](https://developer.apple.com/machine-learning/create-ml/) — Model training (Tabular Regression)
* [yfinance](https://github.com/ranaroussi/yfinance) — Yahoo Finance data pipeline
* [pandas](https://pandas.pydata.org/) — Dataset preparation and CSV formatting
* [Stooq](https://stooq.com) — Fallback market data source when Yahoo Finance is unavailable

---

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Guidelines:
- New prediction methods must pass the ±15% OOD sanity check
- Update Aria's system prompt if you add new signals or data sources
- Keep the app single-file (`ContentView.swift`) — this is intentional for simplicity
- Test on a real Apple Silicon Mac; the Simulator does not support CoreML or Apple Intelligence

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
* Apple Machine Learning team — Create ML Tabular Regression docs were genuinely helpful
* [Stooq](https://stooq.com) — reliable fallback when Yahoo Finance blocks the Swift user agent
* DBS Investor Relations — public financial disclosures used to ground Aria's responses

---

> ⚠️ **Disclaimer:** StockpredictSON is for educational purposes only. Nothing in this app constitutes financial advice. Always do your own research before making investment decisions.
