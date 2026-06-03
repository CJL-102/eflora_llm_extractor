# eflora_llm_extractor

> 基于大语言模型的植物性状自动提取框架构建与评价体系
> A framework and evaluation system for plant trait extraction based on large language models

---

## 研究背景 | Background

植物性状是描述植物形态、生理、生活史等特征的基本属性，其中生长型和生命周期是两类核心功能性状。《中国植物志》收录了中国三万余种维管植物的详细描述文本，但将这些非结构化信息转化为可用于定量分析的结构化数据，传统上依赖人工整理，过程劳动密集且耗时。本研究构建了一套基于大语言模型（LLMs）的植物性状自动提取方法框架，系统评估了模型类型、提示词设计及温度参数对任务性能的影响，并建立了标准化的评测体系。

Plant traits are fundamental properties describing plant morphology, physiology, and life history, with growth form and life span being two core functional traits. The Flora of China contains detailed descriptive texts for over 30,000 vascular plant species in China. However, converting this unstructured information into structured data for quantitative analysis has traditionally relied on manual curation, a labor-intensive and time-consuming process.This study establishes an automated plant trait extraction framework based on large language models (LLMs), systematically evaluates the effects of model type, prompt design, and temperature parameters on task performance, and develops a standardized evaluation system.

---

## 研究目标 | Research Objectives

| 任务 | Task | 类别 | Categories |
| --- | --- | --- | --- |
| 生长型识别 | Growth form recognition | 草本 / 木本 | Herbaceous / Woody |
| 生命周期识别 | Life span recognition | 一年生 / 多年生 | Annual / Perennial |

---

## 评估模型 | Benchmarked Models

| 模型 | 参数量 | 部署方式 |
| --- | --- | --- |
| DeepSeek-V3 | 千亿级（671B） | 云端 API 调用 |
| DeepSeek-R1-0528-Qwen3-8B | 八十亿（8B） | 本地 Ollama 部署 |

---

## 实验设计 | Experimental Design

本研究采用**三因素实验设计**（Three-way factorial design）：

| 因素 | 水平 |
| --- | --- |
| 模型类型（Model） | DeepSeek-V3 / DeepSeek-R1-0528-Qwen3-8B |
| 温度参数（Temperature） | 0.1 / 0.6 |
| 提示策略（Prompt strategy） | 无系统化提示词 / 系统化提示词 |

- 每个实验条件下对每条植物性状描述文本独立执行 **5 次提取**（实验重复）
- 数据集：**27,922 条**人工标注记录（基于《中国植物志》数字化版本）
- 有效样本中：生长型（草本 62.7%，木本 37.3%）；生命周期（多年生 92.5%，一年生 7.5%）

### 系统化提示词设计

系统化提示词遵循"逐步约束生成空间"原则，包含四个核心优化层次：

1. **背景设定**：将模型角色限定为"植物分类学专家"
2. **分类标准定义**：明确生长型和生命周期的判定依据
3. **关键识别词汇**：提供典型指示词列表（如草本指示词：草、草本、柔软茎；木本指示词：木、树、灌木、木质茎）
4. **输出格式约束**：要求严格按 CSV 格式返回 `taxon_id, growth_form, life_span, evidence` 四个字段

---
## 项目结构 | Project Structure

```
eflora_llm_extractor/
├── code/
│ ├── 20250919_中国植物志特征识别_deepseek.R # LLM API 调用与批量提取
│ ├── 01_提取table.R # 指标计算与统计分析
│ ├── 02_指标图.R # 性能指标可视化
│ └── 03_混淆矩阵.R # 混淆矩阵可视化
│
├── results/
│ ├── fig_confusion/ # 混淆矩阵图 / Confusion matrix plots
│ ├── fig_metrics/ # 指标对比图 / Metric comparison plots
│ └── tables/ # 统计汇总表 / Summary tables (.xlsx)
│
├── data/ # 原始数据（已排除 / not tracked）
└── config.json # API 密钥（已排除 / not tracked）
```

---

## 分析流程 | Analysis Pipeline

```
植物志描述文本 (Flora of China text)
│
▼
LLM API 批量调用（2 模型 × 2 温度 × 2 提示策略 × 5 重复）
│
▼
性状提取结果（growth_form, life_span, evidence）
│
▼
质控筛查（缺失率 + 幻觉率检测）
│
▼
指标计算（Accuracy / Precision / Recall / Specificity / F1 / AUC）
│
▼
统计检验（三因素 ANOVA + Tukey HSD）
│
▼
可视化输出（混淆矩阵 + 指标对比图）
```

---

## 评估指标 | Evaluation Metrics

### 质量指标 | Response Quality

| 指标  | Metric | 说明 | 计算公式 |
| ---  | --- | --- | --- |
| 缺失率 | Missing rate | 预测值或真值空缺的样本占比 | N_missing / N_total |
| 幻觉率 | Mismatch rate | 输出超出预设合法类别的样本占比（在非缺失样本中） | N_wrong / N_total(not missing) |

### 分类性能指标 | Classification Performance

| 指标 | Metric | 说明 | 计算公式 |
| --- | --- | --- | --- |
| Accuracy | 准确率 | 有效样本的整体判对占比 | (TP + TN) / (TP + TN + FP + FN) |
| Precision | 精确率 | 预测为正类中真正为正的比例 | TP / (TP + FP) |
| Recall | 召回率 | 真实正类中被正确识别的比例 | TP / (TP + FN) |
| Specificity | 特异度 | 真实负类中被正确识别的比例 | TN / (TN + FP) |
| F1-score | F1 分数 | Precision 与 Recall 的调和均值 | 2 × (P × R) / (P + R) |
| AUC | AUC 值 | ROC 曲线下面积，衡量区分能力 | Area Under the ROC Curve |

> **正负样本定义**：生长型分类中以草本为正类、木本为负类；生命周期分类中以多年生为正类、一年生为负类。

### 统计方法 | Statistical Method

- **三因素方差分析（Three-way ANOVA）**：检验模型类型、温度参数、提示策略的主效应及交互效应（模型:提示词、模型:温度、温度:提示词、模型:温度:提示词）
- **Tukey HSD**：事后多重比较，确定不同处理组合之间的显著性差异
- 显著性水平：*p* < 0.05

---

## 使用方法 | Usage

**Step 1: 配置 API 密钥**

创建 `config.json`（参考以下结构，不纳入版本控制）：

```json
{
  "api_key.deepseek": { "apiKey": "YOUR_DEEPSEEK_API_KEY" }
}
```
注：本地部署的 DeepSeek-R1-0528-Qwen3-8B 通过 Ollama 调用（ollama pull deepseek-r1:8b），无需 API 密钥。

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
