# ==========================================================================
# 文件名: 20250919_中国植物志特征识别_deepseek.R
# 作者:
# 创建日期: 2025-09-19
# 描述: 使用 DeepSeek 大模型从植物志描述数据中提取生长型与生活型特征
# ==========================================================================

# 清理环境
cat("\014")
rm(list=ls())
gc()

# 加载必要的库
library(jsonlite)
library(readxl)
library(tidyverse)
library(ellmer)

# ==========================================================================
# 0. 全局参数设置 (重要：每次重复实验只需修改这里的 REP_NUM)
# ==========================================================================
REP_NUM <- 1                  # 当前实验重复批次 (做第2次重复时改为2，以此类推)
CURRENT_SEED <- 1234 + REP_NUM # 自动为每次重复生成不同的随机种子，保证结果多样性

# ==========================================================================
# 1. 环境设置与数据加载
# ==========================================================================
# 设置路径
path <- "D:/我的坚果云/学生档案/陈佳乐/zqljs"
path.output <- paste0(path, "/deepseek_rep", REP_NUM) # 自动应用新的输出文件夹

# 创建文件夹
if (!dir.exists(path.output)) {
  dir.create(path.output, recursive = TRUE)
  print(paste("文件夹", path.output, "创建成功！"))
} else {
  print(paste("文件夹", path.output, "已经存在。"))
}

# 设置工作目录
setwd(path)
getwd()

# 读取数据
data00 <- read_excel("./data/汇总数据.xlsx", sheet = 1)

# 数据预处理
data <- data00 %>%
  filter(!is.na(plant_traits)) %>%
  select(
    taxon_id,
    Name,
    Chinese_name,
    plant_traits
  ) %>%
  mutate(data.id = paste0("foc_x", row_number())) %>%
  mutate(taxon_id = as.numeric(taxon_id))

n.info <- nrow(data)
print(paste("数据集准备完成，共有", n.info, "条数据记录待处理"))

# ==========================================================================
# 2. API 配置与数据分批
# ==========================================================================
# 从配置文件加载API密钥
config <- fromJSON("./config.json")
ARK_API_KEY <- config$api_key.deepseek$apiKey

if (is.null(ARK_API_KEY) || ARK_API_KEY == "") {
  stop("未能从config.json中获取API Key，请检查配置文件。")
}

# 设置模型ID
model_id <- "deepseek-chat"

# 数据分批逻辑
batch_size <- 50

# 为每一行添加一个批次ID，并将数据分割成列表
data <- data %>%
  mutate(batch_id = floor((row_number() - 1) / batch_size) + 1)

batches <- data %>%
  group_by(batch_id) %>%
  nest() %>%
  pull(data)

num_batches <- unique(data$batch_id)

print(paste("数据已分为", length(num_batches), "个批次进行处理。"))

# --- 修改：更新系统Prompt以适应批处理 ---
prompt_system <- '
**背景 (Context):**
你是一个植物分类学专家，需要从植物志描述数据中提取关键特征信息。

**核心任务 (Core Task):**
逐行分析植物特征描述，准确识别并提取每个物种的生长型（growth form）和生命周期（life span）信息。

**数据结构 (Data Schema):**
- `taxon_id`: 物种唯一标识符
- `plant_traits`: 植物形态特征的文字描述

**分类标准 (Classification Criteria):**

**生长型 (growth_form):**
- `草本`: 茎部柔软，不形成木质化组织（如草、花卉等）
- `木本`: 茎部木质化，形成坚硬的木质组织（如树木、灌木等）

**生命周期 (life_span):**
- `一年生`: 完成整个生命周期在一年内（发芽→开花→结果→死亡）
- `多年生`: 生命周期超过一年，可连续多年生长

**关键识别词汇:**
- 草本指示词：草、草本、柔软茎、绿色茎等
- 木本指示词：木、木本、树、灌木、木质茎、bark等
- 一年生指示词：一年生、annual、当年完成等
- 多年生指示词：多年生、perennial、宿根、多年等

**输出要求 (Output Format):**
严格按照以下csv表格格式输出，务必提供标题(taxon_id,growth_form,life_span,evidence)，结果应该用```csv与```包裹，如下：

```csv
taxon_id,growth_form,life_span,evidence
ID,草本/木本,一年生/多年生,关键证据文字
```

**字段说明:**
- `taxon_id`: 保持原始ID不变
- `growth_form`: 仅填写"草本"或"木本"
- `life_span`: 仅填写"一年生"或"多年生" 、
- `evidence`: 引用原文中支持判断的具体词汇或短语，用逗号分隔

**注意事项:**
1. 如描述不明确，基于植物学常识进行合理推断
2. evidence字段必须是原文的直接引用
3. 保持表格格式的一致性和完整性
4. 每行数据必须填写完整，不得留空
'

# ==========================================================================
# 3. 批处理循环与API调用
# ==========================================================================
for (i in num_batches) {

  print(paste("[Replicate]:", REP_NUM, "[Batch Id]:", i, "| Start time:", Sys.time()))

  current_batch_df <- batches[[i]]
  current_batch_df$taxon_id <- as.numeric(current_batch_df$taxon_id)

  user_content_lines <- apply(current_batch_df, 1, function(row) {
    paste0(
      "- **taxon_id:** ", row["taxon_id"], "\n",
      "- **plant_traits:** ", row["plant_traits"]
    )
  })

  user_content <- paste(user_content_lines, collapse = "\n\n---\n\n")

  try({
    # 调用 ellmer 获取大模型回复
    chat = chat_deepseek(
      model = model_id,
      api_key = ARK_API_KEY,
      seed = CURRENT_SEED, # 自动应用随 REP_NUM 变化的随机种子
      api_args = list(temperature = 0.6, timeout = 1800, stop = NULL)
    )

    message_content <- chat$chat(paste(prompt_system, user_content))

    # 使用 stringr 和 readr 解析大模型返回的 CSV 数据
    parsed_df <- message_content %>%
      str_extract_all("```csv[\\s\\S]*?```") %>%
      str_remove_all("```csv|```|\\[1\\] \"|\"$") %>%
      str_trim() %>%
      read_csv()

    # 只有解析成功且有数据才输出 CSV
    if (!is.null(parsed_df) && nrow(parsed_df) > 0) {
      # 与原始批次数据合并
      batch_result <- current_batch_df %>%
        left_join(parsed_df, by = "taxon_id")

      # 生成带时间戳的文件名并保存
      timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
      success_file <- file.path(path.output, paste0("batch_", i, "_", timestamp, ".csv"))
      write_csv(batch_result, success_file)
    }
  }, silent = TRUE)

  Sys.sleep(5)
}

# ==========================================================================
# 4. 结果汇总
# ==========================================================================
# 获取当前重复批次文件夹下的所有 CSV 文件路径
csv_files <- list.files(path.output, pattern = "\\.csv$", full.names = TRUE)

# 简化的安全读取函数
safe_read_csv <- function(file_path) {
  tryCatch({
    # 首先尝试UTF-8编码读取
    data <- read_csv(file_path, show_col_types = FALSE, locale = locale(encoding = "UTF-8"))

    # 基本处理：去重、添加来源文件列、清理 data.id
    result <- data %>%
      distinct_all() %>%
      mutate(source_file = basename(file_path),
             data.id = str_replace_all(as.character(data.id), "foc_x", ""))

    return(result)

  }, error = function(e) {
    # UTF-8 编码失败时尝试 GB2312 编码
    tryCatch({
      data <- read_csv(file_path, show_col_types = FALSE, locale = locale(encoding = "GB2312"))

      result <- data %>%
        distinct_all() %>%
        mutate(source_file = basename(file_path),
               data.id = str_replace_all(as.character(data.id), "foc_x", ""))

      return(result)

    }, error = function(e2) {
      # 两次读取均失败则跳过该文件
      warning(paste("跳过文件 (读取失败):", basename(file_path)))
      return(NULL)
    })
  })
}

# 批量读取并合并数据
if (length(csv_files) > 0) {
  # 映射函数读取所有文件
  all_data_list <- map(csv_files, safe_read_csv)

  # 剔除读取失败(NULL)的文件后，纵向合并所有数据框
  all_data <- bind_rows(compact(all_data_list))

  if (nrow(all_data) > 0) {
    # 自动应用带 REP_NUM 后缀的动态文件名保存合并结果
    merged_path <- file.path(path, paste0("merged_deepseek_rep", REP_NUM, ".csv"))
    write_csv(all_data, merged_path)

    print(paste("合并完成！成功读取文件数:", length(compact(all_data_list)), "/", length(csv_files)))
    print(paste("总记录行数:", nrow(all_data)))
    print(paste("合并结果已保存至:", merged_path))
  } else {
    print("警告：没有有效数据可以合并。")
  }
} else {
  print(paste("警告：未在输出文件夹", path.output, "中找到任何 CSV 文件。"))
}