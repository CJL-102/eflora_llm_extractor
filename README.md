# eflora_llm_extractor

植物性状LLM提取器评估 / LLM Extractor Evaluation for Plant Traits

---

## 项目概述 | Project Overview

本项目评估三个大语言模型API（DeepSeek、Doubao、Kimi）在植物性状文本描述中提取性状的能力。

This project evaluates three LLM APIs (DeepSeek, Doubao, Kimi) on their ability to extract botanical traits from text descriptions.

**评估性状 | Evaluated Traits:**

- 生长形态 Growth form: 草本 (herbaceous) / 木本 (woody)
- 生命周期 Life span: 一年生 (annual) / 多年生 (perennial)

---

## 项目结构 | Project Structure

```
eflora_llm_extractor/
├── code/                      # R 分析脚本 / R analysis scripts
│   ├── 01_提取table.R         # 提取指标并统计分析 / Extract metrics & statistical analysis
│   ├── 02_指标图.R            # 生成指标图表 / Generate metric plots
│   └── 03_混淆矩阵.R          # 生成混淆矩阵 / Generate confusion matrices
│
├── results/                   # 输出结果 / Output results
│   ├── fig_confusion/         # 混淆矩阵图 / Confusion matrix plots
│   ├── fig_metrics/           # 指标对比图 / Metric comparison plots
│   └── tables/                # 评估表格 / Evaluation tables
│
├── data/                      # 输入数据 (已排除 / excluded)
└── config.json                # API密钥 (已排除 / excluded)
```

---

## 工作流程 | Workflow

```
数据输入 (Input)
    ↓
LLM预测 (Model Prediction)
    ↓
指标计算 (Evaluation Metrics)
    ↓
统计检验 (Statistical Tests: ANOVA + Tukey)
    ↓
可视化 (Visualization)
```

1. **数据输入** | **Data Input**: 原始植物性状描述位于 `data/汇总数据.xlsx` | Raw plant trait descriptions in `data/汇总数据.xlsx`
2. **模型预测** | **Model Prediction**: 三个LLM分别预测生长形态和生命周期 | Three LLMs predict growth form & life span
3. **指标评估** | **Evaluation**: 计算准确率、精确率、召回率、F1、AUC、缺失率、幻觉率 | Calculate accuracy, precision, recall, F1, AUC, missing rate, hallucination rate
4. **统计检验** | **Statistics**: ANOVA + Tukey HSD 进行模型间差异比较 | ANOVA + Tukey HSD for model comparison
5. **可视化** | **Visualization**: 混淆矩阵和指标图表 | Confusion matrices and metric plots

---

## 评估模型 | Models Evaluated

| 模型 | 提供方 | Model | Provider |
|------|--------|-------|----------|
| DeepSeek | DeepSeek API | DeepSeek | DeepSeek API |
| Doubao | 火山引擎 | Doubao | Volcano Engine |
| Kimi | 月之暗面 | Kimi | Moonshot AI |

---

## 核心指标 | Key Metrics

### 性能指标 | Performance Metrics

| 指标 | 英文 | 说明 |
|------|------|------|
| Accuracy | 准确率 | 正确预测比例 |
| Precision | 精确率 | 阳性预测准确度 |
| Recall | 召回率 | 真实阳性检出率 |
| Specificity | 特异度 | 真实阴性正确率 |
| F1 | F1分数 | 精确率与召回率的调和均值 |
| AUC | AUC值 | ROC曲线下面积 |

### 质量指标 | Quality Metrics

| 指标 | 英文 | 说明 |
|------|------|------|
| Missing rate | 缺失率 | 未能提取的比例 |
| Mismatch rate | 幻觉率 | 预测结果不符合标准类别的比例 |

### 稳定性指标 | Stability Metrics

| 指标 | 英文 | 说明 |
|------|------|------|
| CV | 变异系数 | 多次重复结果的标准差/均值，衡量模型稳定性 |

---

## 使用方法 | Usage

```r
# 运行完整评估流程 / Run full evaluation pipeline
source("code/01_提取table.R")  # 提取与分析 / Extract & analyze
source("code/02_指标图.R")      # 生成图表 / Generate plots
source("code/03_混淆矩阵.R")    # 混淆矩阵 / Confusion matrices
```

---

## 环境依赖 | Requirements

- R ≥ 4.0
- R 包 | R packages: `readxl`, `writexl`, `dplyr`, `tidyr`, `caret`, `pROC`, `multcompView`

```r
install.packages(c("readxl", "writexl", "dplyr", "tidyr", "caret", "pROC", "multcompView"))
```

---

## 输出示例 | Output Example

### 指标汇总表 | Metrics Summary Table

| Task | Model | Metric | Mean ± SE | Letter |
|------|-------|--------|-----------|--------|
| growth_form | deepseek | accuracy | 0.852 ± 0.012 | a |
| growth_form | doubao | accuracy | 0.823 ± 0.015 | ab |
| growth_form | kimi | accuracy | 0.789 ± 0.018 | b |

> 显著性字母来自 Tukey HSD 检验 (p < 0.05)
> Significance letters from Tukey HSD test (p < 0.05)
