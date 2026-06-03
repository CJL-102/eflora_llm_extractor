# =============================================================================
# 01_提取table.R
# 作用：
# 提取模型评估指标并进行统计分析
# 支持：
# - 多模型
# - 多temperature
# - 多prompt
# - 多repeat
# - 缺失率/幻觉率
# - ANOVA/Tukey
# =============================================================================
# 1. 环境配置
# =============================================================================
library(readxl)
library(writexl)
library(dplyr)
library(tidyr)
library(caret)
library(pROC)
library(stringr)
library(tidyverse)
library(broom)

# WORK_DIR <- "D:/2025work/AI_New/zqljs_C"
WORK_DIR <- "D:/BaiduNetdiskWorkspace/陈佳乐"

DATA_FILE <- file.path(WORK_DIR, "data", "final_merged.xlsx")
OUT_DIR <- file.path(WORK_DIR, "results")

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# 2. 读取数据
# =============================================================================
raw_data <- read_excel(DATA_FILE) %>%
  filter(!is.na(plant_traits)) %>%
  mutate(row_id = row_number())

baseline_n <- nrow(raw_data)
cat("基准数据量:", baseline_n, "条\n")

# =============================================================================
# 3. 宽表 -> 长表
# =============================================================================
# 1. 选择需要的列
long_data <- raw_data %>%
  select(
    row_id,
    growth_form,
    life_span,
    matches("(_growth_form|_life_span)$")
  )

str(long_data)

# 2. 宽表转长表
long_data <- long_data %>%
  pivot_longer(
    cols = -c(row_id, growth_form, life_span),
    names_to = c(
      "model",
      "temperature",
      "prompt",
      "repeat_num",
      "tmp",
      "task"
    ),
    names_pattern =
      "^(8b|V3)_(temp[0-9.]+)_(prompt[a-zA-Z]+)_(rep[0-9]+)_(result)_(growth_form|life_span)$",
    values_to = "prediction"
  )

# 3. 添加真实标签列
long_data <- long_data %>%
  mutate(
    truth = if_else(
      task == "growth_form",
      growth_form,
      life_span
    )
  )

# 5. 保存长格式数据
write_csv(long_data, file.path(WORK_DIR, "data", "long_data.csv"))

# =============================================================================
# 4. 缺失率统计
# =============================================================================
quality_missing <- long_data %>%
  group_by(
    model,
    temperature,
    prompt,
    repeat_num,
    task
  ) %>%
  summarise(
    total_expected = n(),
    missing_count = sum(is.na(prediction) | is.na(truth)),
    missing_rate = missing_count / total_expected,
    .groups = "drop"
  )

# =============================================================================
# 5. 清洗数据
# =============================================================================
valid_data <- long_data %>%
  filter(
    !is.na(prediction),
    !is.na(truth)
  )

cleaned_data <- valid_data %>%
  mutate(
    prediction = case_when(
      # life_span
      task == "life_span" & prediction == "一年生" ~ "一年生",
      task == "life_span" & prediction == "多年生" ~ "多年生",
      # growth_form
      task == "growth_form" & prediction == "草本" ~ "草本",
      task == "growth_form" & prediction == "木本" ~ "木本",
      TRUE ~ "幻觉_未识别"
    )
  )

# =============================================================================
# 6. 幻觉检测
# =============================================================================
valid_levels_df <- cleaned_data %>%
  distinct(task, truth) %>%
  rename(valid_class = truth)

mismatch_check <- cleaned_data %>%
  left_join(
    valid_levels_df %>% mutate(is_valid_class = TRUE),
    by = c(
      "task",
      "prediction" = "valid_class"
    )
  ) %>%
  mutate(
    is_valid_class = replace_na(is_valid_class, FALSE),
    is_mismatch = !is_valid_class
  )

# =============================================================================
# 7. 幻觉率统计
# =============================================================================
quality_mismatch <- mismatch_check %>%
  group_by(
    model,
    temperature,
    prompt,
    repeat_num,
    task
  ) %>%
  summarise(
    valid_predictions = n(),
    mismatch_count = sum(is_mismatch),
    mismatch_rate = mismatch_count / valid_predictions,
    .groups = "drop"
  )

# =============================================================================
# 8. 合并质量指标
# =============================================================================
quality_long <- quality_missing %>%
  left_join(
    quality_mismatch,
    by = c(
      "model",
      "temperature",
      "prompt",
      "repeat_num",
      "task"
    )
  ) %>%
  mutate(
    mismatch_count = replace_na(mismatch_count, 0),
    mismatch_rate = replace_na(mismatch_rate, 0)
  )

# 清理幻觉数据
metrics_base <- mismatch_check %>%
  filter(!is_mismatch)

# 5. 保存长格式数据
write_csv(metrics_base, file.path(WORK_DIR, "data", "metrics_base.csv"))

# =============================================================================
# 9. 模型评估
# =============================================================================
metrics_performance <- metrics_base %>%
  group_by(
    model,
    temperature,
    prompt,
    repeat_num,
    task
  ) %>%
  summarise(
    n_for_eval = n(),
    cm_obj = list(
      suppressWarnings(
        confusionMatrix(
          factor(prediction),
          factor(truth)
        )
      )
    ),
    by_class_mean = list(
      colMeans(
        rbind(cm_obj[[1]]$byClass),
        na.rm = TRUE
      )
    ),
    accuracy =
      as.numeric(
        cm_obj[[1]]$overall["Accuracy"]
      ),
    precision =
      as.numeric(
        by_class_mean[[1]]["Precision"]
      ),
    recall =
      as.numeric(
        by_class_mean[[1]]["Recall"]
      ),
    specificity =
      as.numeric(
        by_class_mean[[1]]["Specificity"]
      ),
    f1 =
      as.numeric(
        by_class_mean[[1]]["F1"]
      ),
    auc = if(length(unique(truth)) == 2){
      pos_class <- levels(factor(truth))[2]
      suppressWarnings(
        as.numeric(
          roc(
            response = as.numeric(truth == pos_class),
            predictor = as.numeric(prediction == pos_class),
            quiet = TRUE
          )$auc
        )
      )
    } else {
      NA_real_
    },
    .groups = "drop"
  ) %>%
  select(-cm_obj, -by_class_mean)

# =============================================================================
# 10. 合并全部指标
# =============================================================================
metrics_long <- metrics_performance %>%
  left_join(
    quality_long %>%
      select(
      model,
      temperature,
      prompt,
      repeat_num,
      task,
      missing_rate,
      mismatch_rate
    ),
    by = c(
      "model",
      "temperature",
      "prompt",
      "repeat_num",
      "task"
    )
  )

# =============================================================================
# 11. 汇总统计
# =============================================================================
summary_tbl <- metrics_long %>%
  pivot_longer(
    cols = c(
      accuracy,
      precision,
      recall,
      specificity,
      f1,
      auc,
      missing_rate,
      mismatch_rate
    ),
    names_to = "Metric",
    values_to = "Value"
  ) %>%
  filter(!is.na(Value)) %>%
  group_by(
    task,
    model,
    temperature,
    prompt,
    Metric
  ) %>%
  summarise(
    n = n(),
    Mean = mean(Value),
    SD = sd(Value),
    SE = sd(Value) / sqrt(n),
    CV_percent =
      (sd(Value) / mean(Value)) * 100,
    .groups = "drop"
  )

# =============================================================================
# 12. ANOVA（三因素）
# =============================================================================
anova_results <- metrics_long %>%
  pivot_longer(
    cols = c(
      accuracy, precision, recall, specificity,
      f1, auc, missing_rate, mismatch_rate
    ),
    names_to = "Metric",
    values_to = "Value"
  ) %>%
  filter(!is.na(Value)) %>%
  nest_by(task, Metric) %>%
  mutate(
    aov_fit = list(aov(Value ~ model * temperature * prompt, data = data)),
    tidy_results = list(tidy(aov_fit))
  ) %>%
  reframe(tidy_results) %>%
  mutate(
    Significant = case_when(
      p.value < 0.001 ~ "***",
      p.value < 0.01  ~ "**",
      p.value < 0.05  ~ "*",
      TRUE ~ "ns"
    )
  ) %>%
  select(task, Metric, term, df, statistic, p.value, Significant)

# =============================================================================
# 13. Tukey HSD（基于三因素完整模型）
# =============================================================================
tukey_results <- metrics_long %>%
  pivot_longer(
    cols = c(
      accuracy, precision, recall, specificity,
      f1, auc, missing_rate, mismatch_rate
    ),
    names_to = "Metric",
    values_to = "Value"
  ) %>%
  filter(!is.na(Value)) %>%
  nest_by(task, Metric) %>%
  mutate(
    aov_fit = list(aov(Value ~ model * temperature * prompt, data = data)),
    # 先对所有因子做 Tukey 检验
    all_tukey = list({
      fit <- aov_fit
      # 获取所有交互项和主效应项
      all_terms <- tidy(fit) %>%
        filter(!term %in% c("Residuals")) %>%
        pull(term)

      if (length(all_terms) > 0) {
        purrr::map_dfr(all_terms, function(trm) {
          TukeyHSD(fit, which = trm)[[trm]] %>%
            as.data.frame() %>%
            rownames_to_column("Comparison") %>%
            mutate(Term = trm)
        })
      } else {
        tibble()
      }
    }),
    # 再找出有显著性的因子
    sig_terms = list({
      tidy(aov_fit) %>%
        filter(!term %in% c("Residuals"), p.value < 0.05) %>%
        pull(term)
    })
  ) %>%
  # 筛选出显著性因子对应的事后检验结果
  mutate(
    tukey_list = list({
      if (length(sig_terms) > 0) {
        all_tukey %>% filter(Term %in% sig_terms)
      } else {
        tibble()
      }
    })
  ) %>%
  filter(nrow(tukey_list) > 0) %>%
  reframe(tukey_list) %>%
  mutate(
    Significant = case_when(
      `p adj` < 0.001 ~ "***",
      `p adj` < 0.01  ~ "**",
      `p adj` < 0.05  ~ "*",
      TRUE ~ "ns"
    )
  ) %>%
  select(task, Metric, Term, Comparison, diff, lwr, upr, `p adj`, Significant)

# =============================================================================
# 14. 导出
# =============================================================================
output_list <- list(
  metrics_detail = metrics_long,
  summary_stats = summary_tbl,
  anova_test = anova_results,
  tukey_test = tukey_results
)

write_xlsx(
  output_list,
  file.path(
    OUT_DIR,
    "model_evaluation_results.xlsx"
  )
)

cat("\n=================================================\n")
cat("完成！结果已保存：\n")
cat(OUT_DIR)
cat("\n=================================================\n")
