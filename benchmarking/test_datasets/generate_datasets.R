library(tidyverse)
library(jsonlite)

# load covid data
# covid_cases_deaths_data <- read_csv("https://catalog.ourworldindata.org/garden/covid/latest/cases_deaths/cases_deaths.csv")
# write_csv(covid_cases_deaths_data, "benchmarking/0_test_dataset/covid_cases_deaths_data.csv", col_names = TRUE)
covid_cases_deaths_data <- read_csv("/Users/uqbperma/SynologyDrive/Fordelab_works_NAS/00_SCIFR/benchmarking/run_automated_benchmark/test_datasets/covid_cases_deaths_data.csv")
colnames(covid_cases_deaths_data)
nrow(covid_cases_deaths_data)
unique(covid_cases_deaths_data$country)

# simple data:
covid_cases_deaths_data_simple <- covid_cases_deaths_data %>%
    filter(date >= as.Date("2020-01-09")) %>%
    arrange(date, total_cases) %>%
    select(country, date, new_cases_per_million_7_day_avg_right, new_deaths_per_million_7_day_avg_right) %>%
    mutate(
        new_cases_per_million_7_day_avg_right = replace_na(new_cases_per_million_7_day_avg_right, 0),
        new_deaths_per_million_7_day_avg_right = replace_na(new_deaths_per_million_7_day_avg_right, 0)
    )


nrow(covid_cases_deaths_data_simple) # 486K rows

# data points: 100, 500, 1K, 2K, 4K, 8K, 16K, 32K, 64K, 128K, 256K, All(486K)
data_size <- c(100, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000, 128000, 256000, nrow(covid_cases_deaths_data_simple))

# write out datasets for different sizes
for (i in data_size) {
    print(paste0("Processing data size: ", i))
    sampled_data <- covid_cases_deaths_data_simple[1:i, ]
    suffix <- ifelse(i >= 1000, paste0(floor(i / 1000), "K"), as.character(i))
    # for general csv
    # write_csv(sampled_data, paste0("benchmarking/0_test_dataset/covid_country_", suffix, ".csv"), col_names = TRUE)

    csv_string <- paste(
        paste(colnames(sampled_data), collapse = ";t"),
        paste(apply(sampled_data, 1, function(x) {
            paste(trimws(as.character(x)), collapse = ";t")
        }), collapse = ";n"),
        sep = ";n"
    )

    flat_json <- list(
        data = csv_string
    )
    write_json(flat_json, paste0("benchmarking/run_automated_benchmark/test_datasets/covid_country_", suffix, ".flat.json"), pretty = TRUE, auto_unbox = TRUE)

    # for scifr json
    scifr_json <- list(
        startIdx = "EXAMPLE@@@START&&&INDEX",
        data = csv_string,
        endIdx = "EXAMPLE@@@END&&&INDEX"
    )
    write_json(scifr_json, paste0("benchmarking/run_automated_benchmark/test_datasets/covid_country_", suffix, ".scifr.json"), pretty = TRUE, auto_unbox = TRUE)
}
