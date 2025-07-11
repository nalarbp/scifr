#!/bin/bash

BASE_DIR="."
ITERATION=(1 2 3 4 5)
TOOLS=('quartoR' 'jinja2' 'scifr')
DATA_SIZES=(100 500 1K 2K 4K 8K 16K 32K 64K 128K 256K 485K)
BASE_URL='http://localhost:1234'
SERVE_PID=""

#cleanup function to stop web server on exit
cleanup() {
    if [[ -n "$SERVE_PID" ]]; then
        echo "Stopping web server (PID: $SERVE_PID)..."
        kill $SERVE_PID 2>/dev/null
        wait $SERVE_PID 2>/dev/null
    fi
}
trap cleanup EXIT

#create results directories
for tool in "${TOOLS[@]}"; do
    RESULTS_DIR="_results_${tool}"
    mkdir -p "$RESULTS_DIR"
    echo "Created results directory: $RESULTS_DIR"
done

#start web server in background
echo "Starting web server..."
serve ${BASE_DIR} -p 1234 &
SERVE_PID=$!

#wait for server to be ready
sleep 3

#check if server is running
if ! curl -s "${BASE_URL}" >/dev/null 2>&1; then
    echo "ERROR: Web server failed to start or is not accessible"
    exit 1
fi
echo "Web server ready at ${BASE_URL}"

#setup logging
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${BASE_DIR}/lighthouse_benchmark_${TIMESTAMP}.log"
echo "Lighthouse benchmarking started at $(date)" | tee "$LOG_FILE"

for iteration in "${ITERATION[@]}"; do
    echo "=== Starting Iteration $iteration ===" | tee -a "$LOG_FILE"
    
    for tool in "${TOOLS[@]}"; do
        echo "--- Processing tool: $tool ---" | tee -a "$LOG_FILE"
        
        for size in "${DATA_SIZES[@]}"; do
            echo "Processing ${size} dataset with ${tool}..." | tee -a "$LOG_FILE"
            
            case $tool in
                'jinja2')
                    OUTPUT_FILE="jinja_report_iter${iteration}_${size}.html"
                    RESULTS_DIR="_results_jinja2"
                    ;;
                'scifr')  
                    OUTPUT_FILE="scifr_report_iter${iteration}_${size}.html"
                    RESULTS_DIR="_results_scifr"
                    ;;
                'quartoR')
                    OUTPUT_FILE="quartoR_report_iter${iteration}_${size}.html"
                    RESULTS_DIR="_results_quartoR"
                    ;;
            esac
            
            #construct paths and URL (without .html extension for URL)
            FULL_FILE_PATH="${RESULTS_DIR}/${OUTPUT_FILE}"
            FILE_NAME_NO_EXT="${OUTPUT_FILE%.html}"
            TEST_URL="${BASE_URL}/${RESULTS_DIR}/${FILE_NAME_NO_EXT}"
            LIGHTHOUSE_OUTPUT="${BASE_DIR}/${RESULTS_DIR}/${OUTPUT_FILE}.lighthouse"
            
            #check if HTML file exists
            if [[ ! -f "$FULL_FILE_PATH" ]]; then
                echo "WARNING: HTML file not found: $FULL_FILE_PATH" | tee -a "$LOG_FILE"
                continue
            fi
            
            #test URL accessibility
            if ! curl -s --head "$TEST_URL" | head -n 1 | grep -q "200 OK"; then
                echo "WARNING: URL not accessible: $TEST_URL" | tee -a "$LOG_FILE"
                continue
            fi
            
            #run lighthouse
            echo "Running lighthouse on: $TEST_URL" | tee -a "$LOG_FILE"
            if lighthouse "$TEST_URL" \
                --output json html \
                --output-path "$LIGHTHOUSE_OUTPUT" \
                --disable-full-page-screenshot \
                --chrome-flags="--headless --no-sandbox --disable-gpu" 2>>"$LOG_FILE"; then
                echo "SUCCESS: Lighthouse report saved to $LIGHTHOUSE_OUTPUT" | tee -a "$LOG_FILE"
            else
                echo "ERROR: Lighthouse failed for $TEST_URL" | tee -a "$LOG_FILE"
            fi
            
            echo | tee -a "$LOG_FILE"
        done
    done
    
    echo "=== Iteration $iteration completed ===" | tee -a "$LOG_FILE"
    echo | tee -a "$LOG_FILE"
done

echo "=== Lighthouse evaluation done at $(date) ===" | tee -a "$LOG_FILE"

#compile lighthouse performance scores
echo "=== Now compiling Lighthouse performance scores ===" | tee -a "$LOG_FILE"
LIGHTHOUSE_CSV="compiled_lighthouse_performance.csv"

#create CSV header with all performance metrics
echo "iteration,tool,data_size,performance_score,first_contentful_paint,largest_contentful_paint,total_blocking_time,cumulative_layout_shift,speed_index" > "$LIGHTHOUSE_CSV"

#process all lighthouse JSON files
for iteration in "${ITERATION[@]}"; do
    for tool in "${TOOLS[@]}"; do
        #determine correct results directory name
        case $tool in
            'jinja2') RESULTS_DIR="_results_jinja2" ;;
            'scifr') RESULTS_DIR="_results_scifr" ;;
            'quartoR') RESULTS_DIR="_results_quartoR" ;;
        esac
        
        for size in "${DATA_SIZES[@]}"; do
            case $tool in
                'jinja2') OUTPUT_FILE="jinja_report_iter${iteration}_${size}.html" ;;
                'scifr') OUTPUT_FILE="scifr_report_iter${iteration}_${size}.html" ;;
                'quartoR') OUTPUT_FILE="quartoR_report_iter${iteration}_${size}.html" ;;
            esac
            
            JSON_FILE="${RESULTS_DIR}/${OUTPUT_FILE}.lighthouse.report.json"
            
            if [[ -f "$JSON_FILE" ]]; then
                echo "Processing: $JSON_FILE" | tee -a "$LOG_FILE"
                
                #extract performance scores using jq
                PERF_SCORE=$(jq -r '.categories.performance.score // "null"' "$JSON_FILE")
                FCP=$(jq -r '.audits["first-contentful-paint"].numericValue // "null"' "$JSON_FILE")
                LCP=$(jq -r '.audits["largest-contentful-paint"].numericValue // "null"' "$JSON_FILE")
                TBT=$(jq -r '.audits["total-blocking-time"].numericValue // "null"' "$JSON_FILE")
                CLS=$(jq -r '.audits["cumulative-layout-shift"].numericValue // "null"' "$JSON_FILE")
                SI=$(jq -r '.audits["speed-index"].numericValue // "null"' "$JSON_FILE")
                
                #convert performance score from 0-1 to 0-100 scale
                if [[ "$PERF_SCORE" != "null" ]]; then
                    PERF_SCORE=$(echo "$PERF_SCORE * 100" | bc -l | xargs printf "%.1f")
                fi
                
                #write CSV row
                echo "$iteration,$tool,$size,$PERF_SCORE,$FCP,$LCP,$TBT,$CLS,$SI" >> "$LIGHTHOUSE_CSV"
                echo "  Added: iter$iteration, $tool, $size (score: $PERF_SCORE)" | tee -a "$LOG_FILE"
            else
                echo "WARNING: Lighthouse JSON not found: $JSON_FILE" | tee -a "$LOG_FILE"
                #write row with null values for missing data
                echo "$iteration,$tool,$size,null,null,null,null,null,null" >> "$LIGHTHOUSE_CSV"
            fi
        done
    done
done

#validate compilation
TOTAL_DATA_ROWS=$(tail -n +2 "$LIGHTHOUSE_CSV" | wc -l)
EXPECTED_ROWS=$((${#ITERATION[@]} * ${#TOOLS[@]} * ${#DATA_SIZES[@]}))

echo "Lighthouse compilation summary:" | tee -a "$LOG_FILE"
echo "  CSV file: $LIGHTHOUSE_CSV" | tee -a "$LOG_FILE"
echo "  Total rows: $TOTAL_DATA_ROWS" | tee -a "$LOG_FILE"
echo "  Expected rows: $EXPECTED_ROWS" | tee -a "$LOG_FILE"

#count successful vs failed lighthouse runs
SUCCESS_COUNT=$(tail -n +2 "$LIGHTHOUSE_CSV" | grep -v ",null," | wc -l)
FAILED_COUNT=$(tail -n +2 "$LIGHTHOUSE_CSV" | grep ",null," | wc -l)

echo "  Successful audits: $SUCCESS_COUNT" | tee -a "$LOG_FILE"
echo "  Failed audits: $FAILED_COUNT" | tee -a "$LOG_FILE"

if [[ $SUCCESS_COUNT -gt 0 ]]; then
    echo "  Status: SUCCESS - Performance data compiled" | tee -a "$LOG_FILE"
    echo "Sample performance data:" | tee -a "$LOG_FILE"
    head -n 4 "$LIGHTHOUSE_CSV" | tee -a "$LOG_FILE"
else
    echo "  Status: ERROR - No valid performance data found" | tee -a "$LOG_FILE"
fi