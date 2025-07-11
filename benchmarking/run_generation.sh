#!/bin/bash

BASE_DIR="."
DATA_DIR="${BASE_DIR}/test_datasets"
LIB_DIR="${BASE_DIR}/libraries"
JINJA_GENERATOR="generator_jinja.py"
SCIFR_GENERATOR="generator_scifr.py"

#library paths
JQUERY="${LIB_DIR}/jquery-3.7.1.min.js"
CHARTJS="${LIB_DIR}/chartjs-4.4.1.min.js"
DATATABLES_JS="${LIB_DIR}/datatables-2.3.1.min.js"
DATATABLES_CSS="${LIB_DIR}/datatables-2.3.1.min.css"
TAILWIND="${LIB_DIR}/tailwind-4.1.8.min.js"

#template files
TEMPLATE_FILE="${BASE_DIR}/template_scifr.html"
MUTATOR_SCRIPT="$SCIFR_GENERATOR"
QUARTO_TEMPLATE="${BASE_DIR}/template_quarto.qmd"

#iterations
ITERATION=(1 2 3 4 5)
#ITERATION=(1)

#tools
TOOLS=('quartoR' 'jinja2' 'scifr')
#TOOLS=('scifr')

#data sizes
DATA_SIZES=(100 500 1K 2K 4K 8K 16K 32K 64K 128K 256K 485K)
#DATA_SIZES=(1K)

#delay between tools, 10 seconds for cold-start
DELAY=10

#function to extract timing
extract_timing() {
    local time_file="$1"
    if [[ -f "$time_file" ]]; then
        local real_time=$(awk '/^real/ {printf "%.5f", $2}' "$time_file")
        local user_time=$(awk '/^user/ {printf "%.5f", $2}' "$time_file")
        local sys_time=$(awk '/^sys/ {printf "%.5f", $2}' "$time_file")
        echo "$real_time $user_time $sys_time"
    else
        echo "0.00000 0.00000 0.00000"
    fi
}

#function to write CSV
write_csv_row() {
    local iteration="$1"
    local size="$2"
    local timing="$3"
    local status="$4"
    local file_size="$5"
    local method="$6"
    local csv_file="$7"
    
    echo "$iteration,$size,$timing,$status,$file_size,$method" >> "$csv_file"
}

#function to execute jinja2 tool
execute_jinja2() {
    local iteration="$1"
    local size="$2"
    local input_file="$3"
    local output_file="$4"
    local log_file="$5"
    local csv_file="$6"
    local time_file="$7"
    
    if /usr/bin/time -p -o "$time_file" python "$JINJA_GENERATOR" "$input_file" \
        --jquery "$JQUERY" \
        --chartjs "$CHARTJS" \
        --datatables-js "$DATATABLES_JS" \
        --datatables-css "$DATATABLES_CSS" \
        --tailwind "$TAILWIND" 2>>"$log_file"; then
        
        local timing=$(extract_timing "$time_file")
        
        if [[ -f "jinja_report.html" ]]; then
            mv "jinja_report.html" "$output_file"
            local file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
            echo "SUCCESS: $output_file (${file_size}B, real:$(echo $timing | cut -d' ' -f1)s)" | tee -a "$log_file"
            write_csv_row "$iteration" "$size" "$timing" "SUCCESS" "$file_size" "jinja2" "$csv_file"
        else
            echo "ERROR: Output file not generated for $size" | tee -a "$log_file"
            write_csv_row "$iteration" "$size" "$timing" "FAILED_NO_OUTPUT" "0" "jinja2" "$csv_file"
        fi
    else
        local timing=$(extract_timing "$time_file")
        echo "ERROR: Failed to generate report for $size dataset" | tee -a "$log_file"
        write_csv_row "$iteration" "$size" "$timing" "FAILED_EXECUTION" "0" "jinja2" "$csv_file"
    fi
}

#function to execute scifr tool
execute_scifr() {
    local iteration="$1"
    local size="$2"
    local input_file="$3"
    local output_file="$4"
    local log_file="$5"
    local csv_file="$6"
    local time_file="$7"
    
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        echo "ERROR: Template file not found: $TEMPLATE_FILE" | tee -a "$log_file"
        write_csv_row "$iteration" "$size" "0.00000,0.00000,0.00000" "FAILED_MISSING_TEMPLATE" "0" "scifr" "$csv_file"
        return
    fi
    
    if /usr/bin/time -p -o "$time_file" python "$MUTATOR_SCRIPT" \
        --data_json "$input_file" \
        --template "$TEMPLATE_FILE" \
        --startIdx "EXAMPLE@@@START&&&INDEX" \
        --endIdx "EXAMPLE@@@END&&&INDEX" 2>>"$log_file"; then
        
        local timing=$(extract_timing "$time_file")
        
        if [[ -f "scifr_report.html" ]]; then
            mv "scifr_report.html" "$output_file"
            local file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
            echo "SUCCESS: $output_file (${file_size}B, real:$(echo $timing | cut -d' ' -f1)s)" | tee -a "$log_file"
            write_csv_row "$iteration" "$size" "$timing" "SUCCESS" "$file_size" "scifr" "$csv_file"
        else
            echo "ERROR: Output file not generated for $size" | tee -a "$log_file"
            write_csv_row "$iteration" "$size" "$timing" "FAILED_NO_OUTPUT" "0" "scifr" "$csv_file"
        fi
    else
        local timing=$(extract_timing "$time_file")
        echo "ERROR: Failed to generate report for $size dataset" | tee -a "$log_file"
        write_csv_row "$iteration" "$size" "$timing" "FAILED_EXECUTION" "0" "scifr" "$csv_file"
    fi
}

#function to execute quartoR tool
execute_quarto_r() {
    local iteration="$1"
    local size="$2"
    local input_file="$3"
    local output_file="$4"
    local log_file="$5"
    local csv_file="$6"
    local time_file="$7"
    
    if [[ ! -f "$QUARTO_TEMPLATE" ]]; then
        echo "ERROR: Quarto template file not found: $QUARTO_TEMPLATE" | tee -a "$log_file"
        write_csv_row "$iteration" "$size" "0.00000,0.00000,0.00000" "FAILED_MISSING_TEMPLATE" "0" "quartoR" "$csv_file"
        return
    fi

    if /usr/bin/time -p -o "$time_file" quarto render "$QUARTO_TEMPLATE" \
        -P dataset:"${size}" \
        -o "temp_quartoR_iter_$iteration.html" 2>>"$log_file"; then
        
        local timing=$(extract_timing "$time_file")

        mv temp_quartoR_iter_$iteration.html "$output_file"
        if [[ -f "$output_file" ]]; then
            local file_size=$(stat -f%z "$output_file" 2>/dev/null || stat -c%s "$output_file" 2>/dev/null)
            echo "SUCCESS: $output_file (${file_size}B, real:$(echo $timing | cut -d' ' -f1)s)" | tee -a "$log_file"
            write_csv_row "$iteration" "$size" "$timing" "SUCCESS" "$file_size" "quartoR" "$csv_file"
        else
            echo "ERROR: Output file not generated for $size" | tee -a "$log_file"
            write_csv_row "$iteration" "$size" "$timing" "FAILED_NO_OUTPUT" "0" "quartoR" "$csv_file"
        fi
    else
        local timing=$(extract_timing "$time_file")
        echo "ERROR: Failed to render report for $size dataset" | tee -a "$log_file"
        write_csv_row "$iteration" "$size" "$timing" "FAILED_EXECUTION" "0" "quartoR" "$csv_file"
    fi
}

echo "=== Benchmarking Started at $(date) ==="
echo "Processing ${#ITERATION[@]} iterations, ${#TOOLS[@]} tools, ${#DATA_SIZES[@]} data sizes"
echo

#create results directories
for tool in "${TOOLS[@]}"; do
    RESULTS_DIR="_results_${tool}"
    mkdir -p "$RESULTS_DIR"
    echo "Created results directory: $RESULTS_DIR"
done
echo

#main nested loops
for iteration in "${ITERATION[@]}"; do
    echo "=== Starting Iteration $iteration ==="
    
    for tool in "${TOOLS[@]}"; do
        echo "--- Processing tool: $tool ---"
        
        #setup tool-specific results directory
        RESULTS_DIR="_results_${tool}"
        
        #setup iteration and tool specific logging
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        LOG_FILE="${RESULTS_DIR}/${tool}_runtime_iter${iteration}_${TIMESTAMP}.log"
        RUNTIME_CSV="${RESULTS_DIR}/${tool}_runtime_iter${iteration}_${TIMESTAMP}.csv"
        TIME_FILE="${RESULTS_DIR}/${tool}_time_iter${iteration}_${TIMESTAMP}.tmp"
        
        #csv header with iteration column
        echo "iteration,data_size,real_time_sec,user_time_sec,sys_time_sec,status,file_size_bytes,method" > "$RUNTIME_CSV"
        echo "$tool benchmarking iteration $iteration started at $(date)" | tee "$LOG_FILE"
        echo "Runtime data: $RUNTIME_CSV" | tee -a "$LOG_FILE"
        echo
        
        #process each dataset for current tool
        for size in "${DATA_SIZES[@]}"; do
            echo "Processing ${size} dataset with ${tool}..." | tee -a "$LOG_FILE"
            
            #determine input and output files based on tool
            case $tool in
                'jinja2')
                    INPUT_FILE="${DATA_DIR}/covid_country_${size}.flat.json"
                    OUTPUT_FILE="${RESULTS_DIR}/jinja_report_iter${iteration}_${size}.html"
                    ;;
                'scifr')
                    INPUT_FILE="${DATA_DIR}/covid_country_${size}.scifr.json"
                    OUTPUT_FILE="${RESULTS_DIR}/scifr_report_iter${iteration}_${size}.html"
                    ;;
                'quartoR')
                    INPUT_FILE="${DATA_DIR}/covid_country_${size}.flat.json"
                    OUTPUT_FILE="${RESULTS_DIR}/quartoR_report_iter${iteration}_${size}.html"
                    ;;
            esac
            
            #check if input file exists
            if [[ ! -f "$INPUT_FILE" ]]; then
                echo "ERROR: Input file not found: $INPUT_FILE" | tee -a "$LOG_FILE"
                write_csv_row "$iteration" "$size" "0.00000,0.00000,0.00000" "FAILED_MISSING_INPUT" "0" "$tool" "$RUNTIME_CSV"
                continue
            fi
            
            #tool-specific execution
            case $tool in
                'jinja2')
                    execute_jinja2 "$iteration" "$size" "$INPUT_FILE" "$OUTPUT_FILE" "$LOG_FILE" "$RUNTIME_CSV" "$TIME_FILE"
                    ;;
                'scifr')
                    execute_scifr "$iteration" "$size" "$INPUT_FILE" "$OUTPUT_FILE" "$LOG_FILE" "$RUNTIME_CSV" "$TIME_FILE"
                    ;;
                'quartoR')
                    execute_quarto_r "$iteration" "$size" "$INPUT_FILE" "$OUTPUT_FILE" "$LOG_FILE" "$RUNTIME_CSV" "$TIME_FILE"
                    ;;
            esac
            
            #cleanup temporary time file
            rm -f "$TIME_FILE"
            echo | tee -a "$LOG_FILE"
        done
        
        echo "$tool benchmarking iteration $iteration completed at $(date)" | tee -a "$LOG_FILE"
        echo "Performance data saved to: $RUNTIME_CSV" | tee -a "$LOG_FILE"
        echo
        
        #delay between tools to prevent cold-start issues
        if [[ "$tool" != "${TOOLS[-1]}" ]]; then
            echo "Waiting ${DELAY} seconds before next tool..." | tee -a "$LOG_FILE"
            sleep $DELAY
        fi
    done
    
    echo "=== Iteration $iteration completed ==="
    echo
done

echo "=== All benchmarking completed at $(date) ==="

#compile all runtime CSV files into a single master file
echo "=== Compiling all runtime results ==="
MASTER_CSV="compiled_runtime_results.csv"
TEMP_MASTER="temp_master_results.csv"

#create master CSV header
echo "iteration,data_size,real_time_sec,user_time_sec,sys_time_sec,status,file_size_bytes,method" > "$MASTER_CSV"

#compile all CSV files, skipping headers
for tool in "${TOOLS[@]}"; do
    echo "Compiling ${tool} results..."
    
    #find all runtime CSV files for this tool
    for csv_file in _results_${tool}/${tool}_runtime_iter*_*.csv; do
        if [[ -f "$csv_file" ]]; then
            #skip header line and append data
            tail -n +2 "$csv_file" >> "$MASTER_CSV"
            echo "  Added: $(basename "$csv_file")"
        fi
    done
done

#validate compilation
TOTAL_ROWS=$(tail -n +2 "$MASTER_CSV" | wc -l)
EXPECTED_ROWS=$((${#ITERATION[@]} * ${#TOOLS[@]} * ${#DATA_SIZES[@]}))

if [[ $TOTAL_ROWS -eq $EXPECTED_ROWS ]]; then
    echo "  Status: SUCCESS - All data compiled correctly"
else
    echo "  Status: WARNING - Row count mismatch, check for missing data"
fi

echo "All done!!"