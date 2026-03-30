# =============================================================================
# 02_指标图.R
# 作用：独立绘制指标图（综合2x4图，包含损失率与幻觉率），纯 Tidyverse 风格 + multcompView
# =============================================================================

library(dplyr)
library(tidyr)
library(ggplot2)
library(ggpubr)
library(purrr)
library(readxl)
library(multcompView) # 用于自动生成显著性字母 a/b/c

# 1. 环境与配置 ---------------------------------------------------------------
WORK_DIR <- "D:/我的坚果云/学生档案/陈佳乐/zqljs/"
TABLE_DIR <- file.path(WORK_DIR, "results", "tables")
OUT_DIR <- file.path(WORK_DIR, "results", "fig_metrics")
dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# 新增：加入了 missing_rate 和 mismatch_rate
METRICS <- c("missing_rate", "mismatch_rate", "accuracy", "precision", "recall", "specificity", "f1", "auc")
MODEL_COLORS <- c("deepseek" = "#FFFFFF", "doubao" = "#BDBDBD", "kimi" = "#4D4D4D")

# 新增：为两个新指标配置中文 Y 轴标签
ylab_map <- c(
  accuracy = "准确率 (Accuracy)", precision = "精确率 (Precision)",
  recall = "召回率 (Recall)", specificity = "特异度 (Specificity)",
  f1 = "F1", auc = "AUC",
  missing_rate = "缺失率 (Missing rate)", mismatch_rate = "幻觉率 (Mismatch rate)"
)

# 2. 读取数据 -----------------------------------------------------------------
SOURCE_XLSX <- file.path(TABLE_DIR, "model_evaluation_results.xlsx")

summary_tbl <- read_excel(SOURCE_XLSX, sheet = "summary_stats")
anova_tbl   <- read_excel(SOURCE_XLSX, sheet = "anova_test")

TASKS <- unique(summary_tbl$task)

# 3.2 组装绘图终极数据框 (Plot Data)
plot_data <- summary_tbl %>%
  # 确保 Letter 列存在，如果因为 ANOVA 不显著导致没字母，全填充为 "a"
  mutate(Letter = replace_na(Letter, "a")) %>%
  # 拼入 ANOVA 结果，生成图表文本
  left_join(anova_tbl, by = c("task", "Metric")) %>%
  mutate(
    stat_label = case_when(
      is.na(F_value)  ~ "italic(F)==NA*','~italic(P)==NA",
      P_value < 0.001 ~ sprintf("italic(F)==%.2f*','~italic(P)<0.001", F_value),
      TRUE            ~ sprintf("italic(F)==%.2f*','~italic(P)==%.3f", F_value, P_value)
    )
  )

# 4. 绘图函数：极简版（加入 Y 轴动态缩放） -------------------------------
plot_one_metric <- function(df, metric_name, hide_x_axis = FALSE) {
  # 提取唯一的统计标签
  stat_expr <- df$stat_label[1]

  # 计算当前数据的最高点（均值 + 标准误），用于动态设限
  max_y <- max(df$Mean + df$SE, na.rm = TRUE)

  p <- ggplot(df, aes(x = model, y = Mean, fill = model)) +
    geom_col(width = 0.5, color = "black", linewidth = 0.7) +
    geom_errorbar(aes(ymin = Mean - SE, ymax = Mean + SE), width = 0.1, linewidth = 0.7) +
    # 优化：将字母放置在误差棒顶端上方，避免贴着 X 轴
    geom_text(aes(y = Mean + SE, label = Letter), vjust = -0.8, size = 6, family = "serif", color = "black") +
    annotate("text", x = -Inf, y = Inf, label = stat_expr, parse = TRUE,
             hjust = -0.05, vjust = 1, size = 6, family = "serif", color = "black") +
    scale_fill_manual(values = MODEL_COLORS) +
    labs(x = NULL, y = ylab_map[[metric_name]]) +
    theme_classic() +
    theme(
      legend.position = "none",
      text = element_text(family = "serif", color = "black"),
      axis.text = element_text(size = 16),
      axis.title.y = element_text(size = 16),
      axis.line = element_line(linewidth = 1),
      axis.ticks = element_line(linewidth = 1)
    )

  # 核心修改：动态分配 Y 轴尺度
  if (metric_name %in% c("missing_rate", "mismatch_rate")) {
    # 对于比率极小的指标：如果全为 0 则设上限为 0.1，否则取最高点的 1.5 倍留出文本空间
    upper_limit <- ifelse(max_y == 0, 0.1, max_y * 1.5)
    p <- p + scale_y_continuous(limits = c(0, upper_limit), expand = c(0, 0))
  } else {
    # 对于常规表现指标：维持 0 到 1.2
    p <- p + scale_y_continuous(limits = c(0, 1.2), breaks = seq(0, 1.0, 0.2), expand = c(0, 0))
  }

  if (hide_x_axis) {
    p <- p + theme(
      axis.text.x = element_blank(),
      axis.ticks.x = element_blank()
    )
  }

  return(p)
}

# 5. 循环拼图与导出 -----------------------------------------------------------
for (t in TASKS) {
  task_df <- plot_data %>% filter(task == t)

  # 修改：使用 purrr::imap 生成图表列表，前6个隐藏X轴 (因为现在有8个图了)
  plist <- imap(METRICS, function(metric, idx) {
    df_metric <- task_df %>% filter(Metric == metric)
    plot_one_metric(df_metric, metric, hide_x_axis = (idx <= 6))
  })

  # 修改：拼接图片，改为 4 行 (nrow = 4)
  p_all <- ggarrange(
    plotlist = plist,
    ncol = 2, nrow = 4,
    labels = "AUTO",
    font.label = list(size = 16, family = "serif", color = "black", face = "plain")
  )

  # 修改：导出高度由 3200 增加到 4200，保证每个子图不被挤压
  ggexport(
    p_all,
    filename = file.path(OUT_DIR, paste0("Combined_Metrics_", t, ".png")),
    width = 3300, height = 4400, pointsize = 14, res = 300
  )
}

cat("完成：指标图已输出到", OUT_DIR, "\n")