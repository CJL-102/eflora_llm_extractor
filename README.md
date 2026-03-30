# eflora_llm_extractor

Evaluating LLM extractors for plant trait data (growth form & life span classification).

## Overview

This project evaluates three LLM APIs (DeepSeek, Doubao, Kimi) on their ability to extract botanical traits from text descriptions:

- **Growth form**: 草本 (herbaceous) / 木本 (woody)
- **Life span**: 一年生 (annual) / 多年生 (perennial)

## Project Structure

```
├── code/                      # R scripts for analysis
│   ├── 01_提取table.R         # Extract metrics & statistical analysis
│   ├── 02_指标图.R            # Generate metric plots
│   └── 03_混淆矩阵.R          # Generate confusion matrices
├── results/                   # Output figures and tables
│   ├── fig_confusion/         # Confusion matrix plots
│   ├── fig_metrics/           # Metric comparison plots
│   └── tables/                # Evaluation tables
├── data/                      # Input data (excluded from git)
└── config.json                # API keys (excluded from git)
```

## Workflow

1. **Data Input**: Raw plant trait descriptions in `data/汇总数据.xlsx`
2. **Model Prediction**: Three LLMs predict growth form & life span
3. **Evaluation**: Calculate accuracy, precision, recall, F1, AUC, missing rate, hallucination rate
4. **Statistics**: ANOVA + Tukey HSD for model comparison
5. **Visualization**: Confusion matrices and metric plots

## Models Evaluated

| Model | Provider |
|-------|----------|
| DeepSeek | DeepSeek API |
| Doubao | Volcano Engine |
| Kimi | Moonshot AI |

## Key Metrics

- **Performance**: Accuracy, Precision, Recall, Specificity, F1, AUC
- **Quality**: Missing rate, Mismatch (hallucination) rate
- **Stability**: Coefficient of Variation (CV) across repeated runs

## Usage

```r
# Run evaluation pipeline
source("code/01_提取table.R")  # Extract & analyze
source("code/02_指标图.R")    # Generate plots
source("code/03_混淆矩阵.R")  # Confusion matrices
```

## Requirements

- R ≥ 4.0
- Packages: readxl, writexl, dplyr, tidyr, caret, pROC, multcompView
