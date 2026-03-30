# =============================================================================
# 03_混淆矩阵.R (基于 v2 提取逻辑的纯净扁平化版本)
# =============================================================================

library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(ggpubr)
library(forcats)
library(patchwork) # 确保加载 patchwork

# 1. 环境配置 -----------------------------------------------------------------
WORK_DIR <- "D:/我的坚果云/学生档案/陈佳乐/zqljs/"
DATA_FILE <- file.path(WORK_DIR, "data", "汇总数据.xlsx")

# 图像输出目录
OUT_DIR_FIG <- file.path(WORK_DIR, "results", "fig_confusion")
OUT_SUB <- file.path(OUT_DIR_FIG, "confusion_matrix")
dir.create(OUT_SUB, recursive = TRUE, showWarnings = FALSE)

MODELS <- c("deepseek", "doubao", "kimi")
MODEL_LABELS <- c("deepseek" = "DeepSeek", "doubao" = "Doubao", "kimi" = "Kimi")
TASKS <- c("growth_form", "life_span")

# 2. 读取与预处理 -------------------------------------------------------------
raw_data <- read_excel(DATA_FILE) %>%
  filter(!is.na(plant_traits)) %>%
  mutate(row_id = row_number())

baseline_n <- nrow(raw_data)
cat("基准数据量 (非空 plant_traits):", baseline_n, "条\n")

# 3. 数据重构与质控筛查 -------------------------------------------------------
long_data <- raw_data %>%
  select(row_id, growth_form, life_span, matches("^(deepseek|doubao|kimi)_.*")) %>%
  pivot_longer(
    cols = -c(row_id, growth_form, life_span),
    names_to = c("model", "repeat_num", "task"),
    names_pattern = "(.*)_(.*)_(growth_form|life_span)",
    values_to = "prediction"
  ) %>%
  mutate(truth = if_else(task == "growth_form", growth_form, life_span))

# 3.1 规则清洗与幻觉筛查
cleaned_data <- long_data %>%
  filter(!is.na(prediction) & !is.na(truth)) %>%
  mutate(
    prediction = case_when(
      task == "life_span" & prediction == "一年生" ~ "一年生",
      task == "life_span" & prediction == "多年生" ~ "多年生",
      task == "growth_form" & prediction == "草本" ~ "草本",
      task == "growth_form" & prediction == "木本" ~ "木本",
      TRUE ~ "幻觉_未识别"
    )
  )

# 4. 生成混淆矩阵作图数据 (计算平均混淆矩阵取整) ------------------------------
# 过滤出有效匹配数据，保留所有重复数据
cm_base_data <- cleaned_data %>%
  filter(prediction != "幻觉_未识别")

# 动态计算重复次数（通常为 5）
n_repeats <- n_distinct(cm_base_data$repeat_num)
cat("当前动态重复次数计算为:", n_repeats, "次\n")

# 5. 循环生成单图与组装拼图列表 (14号字体，无小数) --------------------------
plot_list_for_combined <- list()
panel_idx <- 1

for (tsk in TASKS) {
  valid_lvls <- if (tsk == "growth_form") c("木本", "草本") else c("一年生", "多年生")
  x_lab <- paste0("实测值：", if_else(tsk == "growth_form", "生长型", "生活型"), " (Actual)")
  y_lab <- paste0("预测值：", if_else(tsk == "growth_form", "生长型", "生活型"), " (Predicted)")

  for (mdl in MODELS) {
    # 修复: 计算平均频数并四舍五入为整数，代表模型平均水平且无小数
    cm_df <- cm_base_data %>%
      filter(model == mdl, task == tsk) %>%
      mutate(truth = factor(truth, levels = valid_lvls),
             prediction = factor(prediction, levels = rev(valid_lvls))) %>%
      group_by(truth, prediction) %>%
      summarise(Freq = round(n() / n_repeats), .groups = "drop") %>%
      complete(truth, prediction, fill = list(Freq = 0))

    # --- 提取公共绘图层 (基础映射) ---
    p_base <- ggplot(cm_df, aes(x = truth, y = prediction, fill = Freq)) +
      geom_tile(color = "black", linewidth = 1) +
      geom_text(aes(label = Freq), size = 14 / .pt, family = "serif", color = "black") +
      scale_fill_gradient(low = "white", high = "grey40", name = "Count")

    # --- 5.1 绘制单图 (独立导出用) ---
    # --- 5.2 绘制拼图版子图 (极致排版控制) ---
    # 修复: theme_minimal() 必须放在自定义 theme() 前面
    p_comb_item <- p_base +
      theme_minimal() +
      labs(title = MODEL_LABELS[[mdl]], x = "实际值 (Actual)", y = "预测值 (Predicted)") +
      theme(
        text = element_text(family = "serif", color = "black", size = 14),
        plot.title = element_text(hjust = 0.5, size = 14),
        axis.text = element_text(family = "serif", color = "black", size = 14),
        axis.title = element_text(family = "serif", color = "black", size = 14),
        legend.position = "none",
        panel.grid = element_blank()
      )

# 修改 2：拦截第二行（第4、5、6个图），去除模型名称标题
    if (panel_idx > 3) {
      p_comb_item <- p_comb_item + theme(plot.title = element_blank())
    }

# 动态拦截 2：去除第一行的 X 轴标题 "实际值 (Actual)" (索引 <= 3 即 1, 2, 3)
    if (panel_idx <= 3) {
      p_comb_item <- p_comb_item + theme(axis.title.x = element_blank())
    }

# 动态拦截 3：去除第 2、3 列的 Y 轴标题 "预测值 (Predicted)" (非 1、4 的索引即 2, 3, 5, 6)
    if (!(panel_idx %in% c(1, 4))) {
      p_comb_item <- p_comb_item + theme(axis.title.y = element_blank())
    }

    plot_list_for_combined[[panel_idx]] <- p_comb_item
    panel_idx <- panel_idx + 1
  }
}

# 6. 组装全局拼图 (使用 patchwork 完美拼接) -----------------------------------
# wrap_plots 组装网格，plot_annotation 自动打上 A-F TAG
combined_patchwork <- wrap_plots(plot_list_for_combined, ncol = 3, nrow = 2) +
  plot_annotation(tag_levels = 'A') &
  theme(plot.tag = element_text(size = 14, family = "serif", face = "bold"))

# 导出最终拼图
ggexport(
  combined_patchwork,
  filename = file.path(OUT_DIR_FIG, "Combined_Confusion.png"),
  width = 3300, height = 2200,
  pointsize = 14, res = 300
)
