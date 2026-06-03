#====================================================
# 02_指标图
# 功能: 生成模型评估指标柱状图（含缺失率、幻觉率、准确率等8个指标）
# 输入: model_evaluation_results.xlsx
# 输出: growth_form_metrics.png, life_span_metrics.png
# 依赖: readxl, dplyr, ggplot2, patchwork
#====================================================

cat("\014")
rm(list = ls())
gc()

# 加载packages
library(readxl)
library(dplyr)
library(ggplot2)
library(patchwork)
library(ggpubr)
library(tibble)

#====================================================
# 1. 文件路径
#====================================================
WORK_DIR <- "D:/BaiduNetdiskWorkspace/陈佳乐"

data_path <- file.path(WORK_DIR, "results", "model_evaluation_results.xlsx")
save_path <- file.path(WORK_DIR, "results")

#====================================================
# 2. 读取数据
#====================================================
df <- read_excel(data_path, sheet = "summary_stats")
str(df)

#====================================================
# 3. 指标顺序与元数据
#====================================================
# 用tibble统一管理所有指标元数据
metric_meta <- tribble(
  ~metric,         ~order, ~letter, ~label,
  "missing_rate",  1,      "A",     "缺失率(Missing Rate)",
  "mismatch_rate", 2,      "B",     "幻觉率(Mismatch Rate)",
  "accuracy",      3,      "C",     "准确率(Accuracy)",
  "precision",     4,      "D",     "精确率(Precision)",
  "recall",        5,      "E",     "召回率(Recall)",
  "specificity",   6,      "F",     "特异性(Specificity)",
  "f1",            7,      "G",     "F1-score",
  "auc",           8,      "H",     "AUC"
)

# 生成需要的命名向量
metric_order    <- metric_meta$metric[match(1:8, metric_meta$order)]
metric_letters  <- setNames(metric_meta$letter, metric_meta$metric)
metric_labels   <- setNames(metric_meta$label, metric_meta$metric)

df$Metric <- factor(df$Metric, levels = metric_order)

#====================================================
# 4. 标签统一
#====================================================
# Temperature
df$temperature <- recode(
  as.character(df$temperature),
  "temp0.1" = "0.1",
  "temp0.6" = "0.6"
)

# Prompt（中英文换行）
df$prompt <- recode(
  as.character(df$prompt),
  "promptzero" = "无提示词\n(Unprompted)",
  "promptdetailed" = "有提示词\n(Prompted)"
)

# Model
df$model <- recode(
  tolower(as.character(df$model)),
  "8b" = "8B",
  "v3" = "V3"
)

# X轴顺序
df$prompt <- factor(df$prompt, levels = c("无提示词\n(Unprompted)", "有提示词\n(Prompted)"))

#====================================================
# 5. 定义任务列表并循环绘图
#====================================================
task_names <- c("growth_form", "life_span")

# test
# task_name <- task_names[1]
# m <- metric_order[1]

for (task_name in task_names) {

  task_df <- df %>% filter(task == task_name)
  plot_list <- list()

  for(m in metric_order){

    subdf <- task_df %>% filter(Metric == m)

    # Y轴
    if(m == "missing_rate"){
      y_scale <- scale_y_continuous(
        limits = c(0, 0.6),
        expand = c(0, 0),
        breaks = seq(0, 0.5, by = 0.1)
      )
    } else if(m == "mismatch_rate"){
      y_scale <- scale_y_continuous(
        limits = c(0, 0.3),
        expand = c(0, 0),
        breaks = seq(0, 0.25, by = 0.05)
      )
    } else {
      y_scale <- scale_y_continuous(
        limits = c(0, 1.1),
        expand = c(0, 0),
        breaks = c(0, 0.2, 0.4, 0.6, 0.8, 1.0)
      )
    }

    p <- ggplot(subdf, aes(x = prompt, y = Mean, fill = temperature)) +
      geom_bar(
        stat = "identity",
        position = position_dodge(0.40),
        width = 0.40,
        color = "black",
        linewidth = 1
      ) +
      geom_errorbar(
        aes(ymin = Mean - SE, ymax = Mean + SE),
        position = position_dodge(0.40),
        width = 0.20,
        linewidth = 1
      ) +
      facet_wrap(~model, nrow = 1) +
      scale_fill_manual(
        name = "温度(Temperature)",
        values = c("0.1" = "white", "0.6" = "grey90"),
        breaks = c("0.1", "0.6"),
        labels = c("0.1", "0.6")
      ) +
      y_scale +
      labs(
        x = NULL,
        y = metric_labels[m],
        tag = metric_letters[m]
      ) +
      theme_bw(base_size = 34) +
      theme(
        strip.text = element_text(size = 34, color = "black"),
        strip.background = element_rect(fill = "grey90", color = "black", linewidth = 1),
        axis.text.x = if(m %in% c("f1", "auc")) element_text(size = 34, lineheight = 1, angle = 0, hjust = 0.5, color = "black") else element_blank(), # 同步隐藏刻度线更美观
        axis.text.y = element_text(size = 34, color = "black"),
        axis.title.y = element_text(size = 34, color = "black"),
        legend.title = element_text(size = 34, color = "black"),
        legend.text = element_text(size = 34, color = "black"),
        legend.position = "top",
        legend.key.size = unit(2.0, "cm"),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.border = element_rect(linewidth = 1, color = "black"),
        plot.tag = element_text(size = 36, color = "black"),
        plot.margin = margin(35, 20, 20, 45)
      )

    plot_list[[m]] <- p
  }

  #==================================================
  # 拼图
  #==================================================
  final_plot <- wrap_plots(
    plot_list,
    ncol = 2,
    guides = "collect"
  ) & theme(legend.position = "top")

  #==================================================
  # 保存与显示
  #==================================================
  ggsave(
    filename = file.path(save_path, paste0(task_name, "_metrics.png")),
    plot = final_plot,
    width = 30,
    height = 38,
    dpi = 300
  )

  print(final_plot)
}
