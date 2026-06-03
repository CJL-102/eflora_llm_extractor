# ============================================================================= 
# 03_混淆矩阵 
# =============================================================================

# 1. 加载必要的包
library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(stringr)
library(readr)

# =============================================================================
# 2. 路径配置
# =============================================================================
# WORK_DIR <- "D:/2025work/AI_New/zqljs_C"
WORK_DIR <- "D:/BaiduNetdiskWorkspace/陈佳乐"
DATA_FILE <- file.path(WORK_DIR, "data", "metrics_base.csv")
OUT_DIR <- file.path(WORK_DIR, "results")

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# =============================================================================
# 2. 读取数据
# =============================================================================
cleaned_data <- read_csv(DATA_FILE)
str(cleaned_data)

n_repeats <- n_distinct(cleaned_data$repeat_num)
cat("重复次数:", n_repeats, "\n")

# =============================================================================
# 4. 汇总数据与标签格式化（修正版：先按重复计算比例，再取平均）
# =============================================================================
# 计算每次重复中的混淆矩阵比例
cm_by_repeat <- cleaned_data %>%
  group_by(task, model, temperature, prompt, repeat_num, truth) %>%
  count(prediction) %>%
  ungroup()

# 对重复取平均，得到最终的混淆矩阵值
cm_summary <- cm_by_repeat %>%
  group_by(task, model, temperature, prompt, truth, prediction) %>%
  summarise(
    Freq = round(mean(n), 0),
    .groups = "drop"
  ) %>%
  mutate(
    model_label = ifelse(model == "8b", "8B", "V3"),
    prompt_label = ifelse(prompt == "promptdetailed", "提示词 (Prompted)", "无提示词 (Unprompted)"),
    temp_label = ifelse(temperature == "temp0.1", "温度(Temp.): 0.1", "温度(Temp.): 0.6")
  )

# =============================================================================
# 5. 核心：极简分面绘图函数（使用平均值）
# =============================================================================
plot_simple_confusion <- function(data, task_name) {

  # 设置类别因子的顺序，确保坐标轴按固定顺序排列，且 Y 轴翻转(对角线从左上到右下)
  if(task_name == "growth_form"){
    
    lvls <- c("木本", "草本")
    
    # =============================================================================
    # 添加：横轴和纵轴均换行
    # =============================================================================
    x_axis_labels <- c(
      "木本" = "木本\n(Woody)",
      "草本" = "草本\n(Herbaceous)"
    )
    
    y_axis_labels <- c(
      "木本" = "木本\n(Woody)",
      "草本" = "草本\n(Herbaceous)"
    )
    
  } else {
    
    lvls <- c("一年生", "多年生")
    
    # =============================================================================
    # 添加：横轴和纵轴均换行
    # =============================================================================
    x_axis_labels <- c(
      "一年生" = "一年生\n(Annual)",
      "多年生" = "多年生\n(Perennial)"
    )
    
    y_axis_labels <- c(
      "一年生" = "一年生\n(Annual)",
      "多年生" = "多年生\n(Perennial)"
    )
  }

  df_plot <- data %>%
    filter(task == task_name) %>%
    mutate(
      truth = factor(truth, levels = lvls),
      prediction = factor(prediction, levels = rev(lvls)),
      row_facet = paste0(prompt_label, "\n", temp_label)
    ) %>%
    complete(truth, prediction, model_label, row_facet, fill = list(Freq = 0)) %>%
    mutate(
      Freq_label = round(Freq, 0)
    )

  p <- ggplot(df_plot, aes(x = truth, y = prediction, fill = Freq)) +
    geom_tile(color = "black", linewidth = 1) +
    geom_text(aes(label = Freq_label), size = 14, color = "black") +
    scale_fill_gradient(
      low = "white",
      high = "grey45",
      name = "平均次数"
    ) +
    
    # =============================================================================
    # 添加：坐标轴标签换行
    # =============================================================================
    scale_x_discrete(labels = x_axis_labels) +
    scale_y_discrete(labels = y_axis_labels) +
    
    coord_fixed() +
    facet_grid(row_facet ~ model_label) +
    labs(
      x = "实际值 (Actual)",
      y = "预测值 (Predicted)"
    ) +
    theme_bw(base_size = 18) +
    theme(
      legend.position = "none",
      panel.grid = element_blank(),
      strip.background = element_rect(fill = "grey90", color = "black", linewidth = 1),
      strip.text = element_text(color = "black", size = 18),
      
      # =============================================================================
      # 添加：横轴标签换行后居中对齐
      # =============================================================================
      axis.text.x = element_text(
        color = "black",
        size = 18,
        angle = 0,
        hjust = 0.5,
        vjust = 0.5,
        lineheight = 0.85
      ),
      
      # =============================================================================
      # 添加：纵轴标签换行，并整体旋转90度，中英文居中对齐
      # =============================================================================
      axis.text.y = element_text(
        color = "black",
        size = 18,
        angle = 90,
        hjust = 0.5,
        vjust = 0.5,
        lineheight = 0.85
      ),
      
      axis.title = element_text(color = "black", size = 18),
      panel.border = element_rect(color = "black", linewidth = 1)
    )

  return(p)
}

# =============================================================================
# 6. 生成并保存图表
# =============================================================================
cat("[1/2] 生成 growth_form...\n")
p_growth <- plot_simple_confusion(cm_summary, "growth_form")

ggsave(
  filename = file.path(OUT_DIR, "growth_form_confusion_direct.png"),
  plot = p_growth,
  width = 12,
  height = 18,
  dpi = 300,
  bg = "white"
)

cat("[2/2] 生成 life_span...\n")
p_life <- plot_simple_confusion(cm_summary, "life_span")

ggsave(
  filename = file.path(OUT_DIR, "life_span_confusion_direct.png"),
  plot = p_life,
  width = 12,
  height = 18,
  dpi = 300,
  bg = "white"
)