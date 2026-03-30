# =============================================================================
# 01_提取table.R
# 作用：提取模型评估指标并进行统计分析（全面纳入重复分析，支持质量指标ANOVA）
# =============================================================================

library(readxl)
library(writexl)
library(dplyr)
library(tidyr)
library(caret)
library(pROC)
library(multcompView)

# 1. 环境配置 -----------------------------------------------------------------
WORK_DIR <- "D:/我的坚果云/学生档案/陈佳乐/zqljs/"
DATA_FILE <- file.path(WORK_DIR, "data", "汇总数据.xlsx")
OUT_DIR  <- file.path(WORK_DIR, "results", "tables")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

MODELS <- c("deepseek", "doubao", "kimi")

# 2. 读取与预处理 -------------------------------------------------------------
raw_data <- read_excel(DATA_FILE) %>%
  filter(!is.na(plant_traits)) %>%
  mutate(row_id = row_number())

baseline_n <- nrow(raw_data)
cat("基准数据量 (非空 plant_traits):", baseline_n, "条\n")

# 3. 数据重构与质控筛查 (按 repeat_num 独立计算) ------------------------------
long_data <- raw_data %>%
  select(row_id, growth_form, life_span, matches("^(deepseek|doubao|kimi)_.*")) %>%
  pivot_longer(
    cols = -c(row_id, growth_form, life_span),
    names_to = c("model", "repeat_num", "task"),
    names_pattern = "(.*)_(.*)_(growth_form|life_span)",
    values_to = "prediction"
  ) %>%
  mutate(truth = if_else(task == "growth_form", growth_form, life_span))

# 3.1 计算每次重复的缺失率
quality_missing <- long_data %>%
  group_by(model, task, repeat_num) %>%
  summarise(
    total_expected = n(),
    missing_count  = sum(is.na(prediction) | is.na(truth)),
    missing_rate   = missing_count / total_expected, # 保持0-1小数，与Accuracy同量级
    .groups = "drop"
  )

valid_data <- long_data %>% filter(!is.na(prediction) & !is.na(truth))

# 3.2 规则清洗与幻觉筛查
cleaned_data <- valid_data %>%
  mutate(
    prediction = case_when(
      task == "life_span" & prediction == "一年生" ~ "一年生",
      task == "life_span" & prediction == "多年生" ~ "多年生",
      task == "life_span" ~ "幻觉_未识别",

      task == "growth_form" & prediction == "草本" ~ "草本",
      task == "growth_form" & prediction == "木本" ~ "木本",
      task == "growth_form" ~ "幻觉_未识别",

      TRUE ~ "幻觉_未识别"
    )
  )

valid_levels_df <- cleaned_data %>%
filter(!is.na(truth)) %>%
distinct(task, truth) %>%
rename(valid_class = truth)

mismatch_check <- cleaned_data %>%
  left_join(valid_levels_df %>% mutate(is_valid_class = TRUE),
            by = c("task" = "task", "prediction" = "valid_class")) %>%
  mutate(
    is_valid_class = replace_na(is_valid_class, FALSE),
    is_mismatch = !is_valid_class
  )

# 3.3 计算每次重复的幻觉/不匹配率
quality_mismatch <- mismatch_check %>%
  group_by(model, task, repeat_num) %>%
  summarise(
    valid_predictions = n(),
    mismatch_count    = sum(is_mismatch),
    mismatch_rate     = mismatch_count / valid_predictions,
    .groups = "drop"
  )

# 将质量指标整合为宽表，备用
quality_long <- quality_missing %>%
  left_join(quality_mismatch, by = c("model", "task", "repeat_num")) %>%
  mutate(
    mismatch_count = replace_na(mismatch_count, 0),
    mismatch_rate  = replace_na(mismatch_rate, 0)
  )

# 4. 计算模型评估指标 ---------------------------------------------------------
metrics_base <- mismatch_check %>% filter(!is_mismatch)

metrics_performance <- metrics_base %>%
  group_by(model, repeat_num, task) %>%
  summarise(
    n_for_eval = n(),
    cm_obj = list(suppressWarnings(caret::confusionMatrix(
      factor(prediction, levels = levels(factor(truth))),
      factor(truth)
    ))),
    by_class_mean = list(colMeans(rbind(cm_obj[[1]]$byClass), na.rm = TRUE)),
    accuracy      = as.numeric(cm_obj[[1]]$overall["Accuracy"]),
    precision     = as.numeric(by_class_mean[[1]]["Precision"]),
    recall        = as.numeric(by_class_mean[[1]]["Recall"]),
    specificity   = as.numeric(by_class_mean[[1]]["Specificity"]),
    f1            = as.numeric(by_class_mean[[1]]["F1"]),
    auc = if(length(levels(factor(truth))) == 2) {
      pos_class <- levels(factor(truth))[2]
      suppressWarnings(as.numeric(pROC::roc(response = as.numeric(truth == pos_class), predictor = as.numeric(prediction == pos_class), quiet = TRUE)$auc))
    } else { NA_real_ },
    .groups = "drop"
  ) %>%
  select(-cm_obj, -by_class_mean)

# 核心：将“缺失率”和“幻觉率”直接作为正式指标并入 metrics_long！
metrics_long <- metrics_performance %>%
  left_join(select(quality_long, model, task, repeat_num, missing_rate, mismatch_rate),
            by = c("model", "task", "repeat_num"))

# 提前进行一次透视，避免后续重复操作，提升代码运行效率
metrics_tall <- metrics_long %>%
  pivot_longer(
    cols = c(accuracy, precision, recall, specificity, f1, auc, missing_rate, mismatch_rate),
    names_to = "Metric",
    values_to = "Value"
  ) %>%
  filter(!is.na(Value))

# 5. 统计汇总 (均值 ± SE & CV) ------------------------------------------------
summary_tbl <- metrics_tall %>%
  group_by(task, model, Metric) %>%
  summarise(
    n = n(),
    Mean = mean(Value),
    SE   = sd(Value) / sqrt(n),
    CV_percent = (sd(Value) / Mean) * 100,
    .groups = "drop"
  )

# 6. 差异性检验 (ANOVA & Tukey) -----------------------------------------------
# 6.1 ANOVA 检验 (同样覆盖所有表现指标和质量指标)
anova_results <- metrics_tall %>%
  group_by(task, Metric) %>%
  summarise(
    F_value = summary(aov(Value ~ model))[[1]][["F value"]][1],
    P_value = summary(aov(Value ~ model))[[1]][["Pr(>F)"]][1],
    .groups = "drop"
  ) %>%
  mutate(
    Significant = case_when(
      P_value < 0.001 ~ "***",
      P_value < 0.01  ~ "**",
      P_value < 0.05  ~ "*",
      TRUE            ~ "ns"
    )
  )

# 6.2 提取原始 Tukey 检验结果 (保留具体 P 值供核查)
tukey_results <- metrics_tall %>%
  group_by(task, Metric) %>%
  filter(summary(aov(Value ~ model))[[1]][["Pr(>F)"]][1] < 0.05) %>%
  reframe(
    as_tibble(TukeyHSD(aov(Value ~ model))$model, rownames = "Comparison")
  )

# 6.3 【新增核心】计算并生成完美的 a/b/ab 显著性字母
letters_tbl <- metrics_tall %>%
  group_by(task, Metric) %>%
  reframe({
    # 为当前 task 和 Metric 构建方差分析模型
    aov_model <- aov(Value ~ model, data = cur_data())

    # 提取 Tukey 结果
    tukey_res <- TukeyHSD(aov_model)

    # 【大招】传入模型和Tukey结果，自动按均值排序并分配字母（完美处理 ab 交叉）
    letters_list <- multcompLetters4(aov_model, tukey_res)

    # 提取生成的字母并转为 tibble
    tibble(
      model = names(letters_list$model$Letters),
      Letter = letters_list$model$Letters
    )
  })

# 6.4 将生成的字母合并回汇总表，并生成“出版级”文本列
summary_final <- summary_tbl %>%
  left_join(letters_tbl, by = c("task", "Metric", "model")) %>%
  # 按 task, Metric 分组，并按均值降序排列，让表看起来更直观
  group_by(task, Metric) %>%
  arrange(desc(Mean), .by_group = TRUE) %>%
  ungroup() %>%
  # 拼接一列出版用的格式，例如: "0.852 ± 0.012 a"
  mutate(
    Publish_Format = sprintf("%.3f ± %.3f %s", Mean, SE, Letter)
  )


# 6.5 新增：CV (变异系数) 的整体稳定性分析 (以6个指标作为重复)
# 1. 过滤出6个性能指标的 CV 数据，准备进行 ANOVA
cv_data <- summary_tbl %>%
  filter(!Metric %in% c("missing_rate", "mismatch_rate")) %>%
  select(task, model, Metric, CV_percent) %>%
  filter(!is.na(CV_percent))

# 2. 对 CV 进行 ANOVA 检验与字母分配
cv_stats_tbl <- cv_data %>%
  group_by(task) %>%
  reframe({
    # 以6个指标的CV作为重复，检验模型间的稳定性差异
    aov_model <- aov(CV_percent ~ model, data = cur_data())
    tukey_res <- TukeyHSD(aov_model)

    # 提取 ANOVA 的 F 值和 P 值
    f_val <- summary(aov_model)[[1]][["F value"]][1]
    p_val <- summary(aov_model)[[1]][["Pr(>F)"]][1]

    # 自动生成 a/b/ab 显著性字母 (注意：CV越大代表越不稳定，这里默认把最大的CV标为a)
    letters_list <- multcompLetters4(aov_model, tukey_res)

    tibble(
      model = names(letters_list$model$Letters),
      CV_Letter = letters_list$model$Letters,
      CV_ANOVA_F = f_val,
      CV_ANOVA_P = p_val
    )
  }) %>%
  mutate(
    CV_Significant = case_when(
      CV_ANOVA_P < 0.001 ~ "***",
      CV_ANOVA_P < 0.01  ~ "**",
      CV_ANOVA_P < 0.05  ~ "*",
      TRUE               ~ "ns"
    )
  )

# 3. 汇总模型的平均 CV 并拼合显著性字母 (用于最终展示)
cv_summary_final <- cv_data %>%
  group_by(task, model) %>%
  summarise(
    Mean_CV = mean(CV_percent),
    SE_CV   = sd(CV_percent) / sqrt(n()),
    .groups = "drop"
  ) %>%
  left_join(cv_stats_tbl, by = c("task", "model")) %>%
  group_by(task) %>%
  arrange(Mean_CV, .by_group = TRUE) %>% # 按CV从小到大排序 (越小越稳定)
  ungroup() %>%
  mutate(
    Publish_CV_Format = sprintf("%.2f%% ± %.2f%% %s", Mean_CV, SE_CV, CV_Letter)
  )

# 7. 导出结果 -----------------------------------------------------------------
output_list <- list(
  metrics_detail = metrics_long,
  summary_stats  = summary_final,  # 之前指标的汇总
  anova_test     = anova_results,
  tukey_test     = tukey_results,
  # ---------- 新增的 CV 结果 ----------
  cv_summary     = cv_summary_final # 包含各模型平均CV、字母、方差P值 (最推荐看这个)
)

write_xlsx(output_list, file.path(OUT_DIR, "model_evaluation_results.xlsx"))

cat("<- 完成！结果已保存至：", OUT_DIR, " ->\n")