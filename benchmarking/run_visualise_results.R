library(tidyverse)
library(ggbreak)
library(patchwork)
library(gridExtra)
library(colorBlindness)


# remove the 100 cold start exclusion
data_sizes <- c("500", "1K", "2K", "4K", "8K", "16K", "32K", "64K", "128K", "256K", "485K")
tools <- c("scifr", "jinja2", "quartoR")
tools_color <- c("#6db6ff", "#ffb6db", "#009292")

# runtime and filesize data
runtime_filesize <- read_csv("benchmarking/run_automated_benchmark/compiled_runtime_results.csv") %>%
    filter(data_size %in% data_sizes) %>%
    mutate(data_size = factor(data_size, levels = data_sizes)) %>%
    mutate(method = factor(method, levels = tools)) %>%
    mutate(real_time_sec = as.numeric(real_time_sec))
head(runtime_filesize)

# ====filesize=======
filesize_mean <- runtime_filesize %>%
    group_by(method, data_size) %>%
    summarise(
        mean_file_size_bytes = mean(file_size_bytes),
        sd_file_size_bytes = sd(file_size_bytes),
        .groups = "drop"
    ) %>%
    mutate(data_size = factor(data_size, levels = data_sizes))
filesize_mean

filesize_plot <- ggplot(filesize_mean) +
    geom_bar(aes(x = data_size, y = mean_file_size_bytes, fill = method), stat = "identity", position = "dodge") +
    scale_y_continuous(labels = function(x) paste0(x / 1000000, " MB")) +
    labs(x = "Data points", y = "Average file size") +
    scale_fill_manual(values = tools_color) +
    theme_minimal() +
    theme(axis.text = element_text(size = 7)) +
    theme(axis.title = element_text(size = 8)) +
    theme(legend.position = "top", legend.text = element_text(size = 7), legend.key.size = unit(0.3, "cm"))
filesize_plot

# ====runtime====
runtime_mean <- runtime_filesize %>%
    group_by(method, data_size) %>%
    summarise(mean_real_time_sec = mean(real_time_sec), sd_real_time_sec = sd(real_time_sec), .groups = "drop") %>%
    mutate(data_size = factor(data_size, levels = data_sizes))

runtime_plot <- ggplot(runtime_mean, aes(x = data_size, y = mean_real_time_sec, fill = method)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.9)) +
    geom_errorbar(aes(ymin = mean_real_time_sec - sd_real_time_sec, ymax = mean_real_time_sec + sd_real_time_sec, group = method),
        position = position_dodge(width = 0.9), width = 0.4, color = "black"
    ) +
    scale_y_break(c(0.3, 4), scales = 1) +
    labs(x = "Data points", y = "Average generation time (seconds)") +
    scale_fill_manual(values = tools_color) +
    theme_minimal() +
    theme(axis.text = element_text(size = 7)) +
    theme(axis.title = element_text(size = 8)) +
    theme(legend.position = "none", legend.text = element_text(size = 7), legend.key.size = unit(0.3, "cm"))

runtime_plot

# get the idea, on average, how SCIFR is faster than Quarto-R?
runtime_mean_wide <- runtime_mean %>%
    select(method, data_size, mean_real_time_sec) %>%
    pivot_wider(names_from = method, values_from = mean_real_time_sec)
head(runtime_mean_wide)

scifr_runtime_speed_comparison <- runtime_mean_wide %>%
    rowwise() %>%
    mutate(quartoR_scifr = quartoR / scifr, jinja2_to_scifr = jinja2 / scifr)

summary(scifr_runtime_speed_comparison$quartoR_scifr)
summary(scifr_runtime_speed_comparison$jinja2_to_scifr)
# ===overal performance===
performance <- read_csv("benchmarking/run_automated_benchmark/compiled_lighthouse_performance.csv") %>%
    filter(data_size %in% data_sizes) %>%
    mutate(data_size = factor(data_size, levels = data_sizes)) %>%
    mutate(tool = factor(tool, levels = tools)) %>%
    mutate(performance_score = as.numeric(performance_score))
head(performance)
colnames(performance)

performance_mean <- performance %>%
    group_by(tool, data_size) %>%
    mutate(score = mean(performance_score), .groups = "drop") %>%
    mutate(data_size = factor(data_size, levels = data_sizes))
performance_mean

performance_plot <- ggplot(performance_mean) +
    geom_bar(aes(x = data_size, y = score, fill = tool), stat = "identity", position = "dodge") +
    labs(x = "Data points", y = "Performance score") +
    scale_fill_manual(values = tools_color) +
    theme_minimal() +
    theme(axis.text = element_text(size = 7)) +
    theme(axis.title = element_text(size = 8)) +
    theme(legend.position = "none", legend.text = element_text(size = 7), legend.key.size = unit(0.3, "cm"))
performance_plot

# radar chart based on each performance metrics
each_performance_metric_at485K_mean <- performance %>%
    filter(data_size == "485K") %>%
    group_by(tool) %>%
    summarise(
        first_contentful_paint_mean = mean(first_contentful_paint),
        largest_contentful_paint_mean = mean(largest_contentful_paint),
        total_blocking_time_mean = mean(total_blocking_time),
        cumulative_layout_shift_mean = mean(cumulative_layout_shift),
        speed_index_mean = mean(speed_index)
    )
each_performance_metric_at485K_mean

# ===merge-plot===
filesize_plot
runtime_plot
performance_plot


grid.arrange(
    filesize_plot,
    runtime_plot,
    performance_plot,
    ncol = 2,
    heights = c(1, 1, 1)
)
