# eflora_llm_extractor

> 基于大语言模型的植物志性状批量提取与评估框架
> A benchmark framework for automated botanical trait extraction using large language models

---

## 研究背景 | Background

植物志（Flora of China）包含海量物种形态描述文本，手动提取关键性状（如生长型、生活型）耗时费力。本研究构建了一套基于LLM API的自动化性状提取流程，并对三种主流中文大模型的提取准确性、响应质量与输出稳定性进行系统评估。

The *Flora of China* contains extensive morphological descriptions for thousands of species. Manual extraction of key traits (e.g., growth form, life span) is labor-intensive. This study establishes an automated LLM-based trait extraction pipeline and systematically benchmarks three leading Chinese LLMs on extraction accuracy, response quality, and output stability.

---

## 评估目标 | Evaluated Traits

| 性状  | Trait       | 类别        | Categories         |
| --- | ----------- | --------- | ------------------ |
| 生长型 | Growth form | 草本 / 木本   | Herbaceous / Woody |
| 生活型 | Life span   | 一年生 / 多年生 | Annual / Perennial |

---

## 评估模型 | Benchmarked Models

| 模型       | 提供方      | Model    | Provider                   |
| -------- | -------- | -------- | -------------------------- |
| DeepSeek | DeepSeek | DeepSeek | DeepSeek                   |
| Doubao   | 火山引擎     | Doubao   | Volcano Engine (ByteDance) |
| Kimi     | 月之暗面     | Kimi     | Moonshot AI                |

---

## 项目结构 | Project Structure

```
eflora_llm_extractor/
├── code/
│   ├── 20250919_中国植物志特征识别_deepseek.R   # LLM API 调用与批量提取
│   ├── 01_提取table.R                           # 指标计算与统计分析
│   ├── 02_指标图.R                              # 性能指标可视化
│   └── 03_混淆矩阵.R                            # 混淆矩阵可视化
│
├── results/
│   ├── fig_confusion/    # 混淆矩阵图 / Confusion matrix plots
│   ├── fig_metrics/      # 指标对比图 / Metric comparison plots
│   └── tables/           # 统计汇总表 / Summary tables (.xlsx)
│
├── data/                 # 原始数据（已排除 / not tracked）
└── config.json           # API 密钥（已排除 / not tracked）
```

---

## 分析流程 | Analysis Pipeline

```
植物志文本 (Flora of China text)
        │
        ▼
  LLM API 批量调用（3 模型 × 5重复）
        │
        ▼
  性状提取结果（growth_form, life_span）
        │
        ▼
  质控筛查（幻觉检测 + 缺失率统计）
        │
        ▼
  指标计算（Accuracy / Precision / Recall / F1 / AUC）
        │
        ▼
  统计检验（ANOVA + Tukey HSD）
        │
        ▼
  可视化输出（混淆矩阵 + 指标图）
```

---

## 评估指标 | Evaluation Metrics

### 性能指标 | Performance

| 指标          | Metric | 说明                       |
| ----------- | ------ | ------------------------ |
| Accuracy    | 准确率    | 所有类别的整体正确率               |
| Precision   | 精确率    | 预测为正类中真正为正的比例            |
| Recall      | 召回率    | 真实正类中被正确识别的比例            |
| Specificity | 特异度    | 真实负类中被正确识别的比例            |
| F1          | F1 分数  | Precision 与 Recall 的调和均值 |
| AUC         | AUC 值  | ROC 曲线下面积，衡量区分能力         |

### 质量指标 | Response Quality

| 指标            | Metric | 说明             |
| ------------- | ------ | -------------- |
| Missing rate  | 缺失率    | 模型未输出有效结果的比例   |
| Mismatch rate | 幻觉率    | 输出结果不符合预设类别的比例 |

### 稳定性指标 | Stability

| 指标  | Metric | 说明                |
| --- | ------ | ----------------- |
| CV  | 变异系数   | 多次重复间的变异程度（越低越稳定） |

---

## 使用方法 | Usage

**Step 1: 配置 API 密钥**

创建 `config.json`（参考以下结构，不纳入版本控制）：

```json
{
  "api_key.deepseek": { "apiKey": "YOUR_KEY" },
  "api_key.doubao":   { "apiKey": "YOUR_KEY" },
  "api_key.kimi":     { "apiKey": "YOUR_KEY" }
}
```

**Step 2: 运行提取脚本**

```r
source("code/20250919_中国植物志特征识别_deepseek.R")
```

**Step 3: 运行评估分析**

```r
source("code/01_提取table.R")   # 指标计算与统计检验
source("code/02_指标图.R")      # 生成性能对比图
source("code/03_混淆矩阵.R")    # 生成混淆矩阵
```

---

## 环境依赖 | Requirements

- R ≥ 4.0
- R packages:

```r
install.packages(c("readxl", "writexl", "dplyr", "tidyr", "tidyverse",
                   "caret", "pROC", "multcompView", "jsonlite", "ellmer"))
```
