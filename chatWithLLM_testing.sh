#!/bin/bash
# test_llm_cli.sh - Test script for chatWithLLM.sh
# Tests model availability by asking "What is 1+1?" and checking for "2" in response

set -euo pipefail

# Configuration
LLM_CLI_SCRIPT="./chatWithLLM.sh"
TEST_PROMPT="What is 1+1? Please answer with just the number."
EXPECTED_ANSWER="2"

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Models to test - add/remove as needed
MODELS_TO_TEST=(
    "openai:gpt-4"
    "openai:gpt-3.5-turbo"
    "anthropic:claude-3-opus-20240229"
    "anthropic:claude-3-sonnet-20240229"
    "anthropic:claude-3-haiku-20240307"
    "google:gemini-pro"
    "google:gemini-1.5-pro"
    "mistral:mistral-large-latest"
    "mistral:mistral-medium-latest"
    "deepseek:deepseek-chat"
    "deepseek:deepseek-coder"
)

# Function: log_message
# Description: Print colored log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} ${timestamp} - $message"
            ;;
        "PASS")
            echo -e "${GREEN}[PASS]${NC} ${timestamp} - $message"
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} ${timestamp} - $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} ${timestamp} - $message"
            ;;
        *)
            echo "${timestamp} - $message"
            ;;
    esac
}

# Function: check_prerequisites
# Description: Check if the LLM CLI script exists and is executable
check_prerequisites() {
    log_message "INFO" "Checking prerequisites..."
    
    if [[ ! -f "$LLM_CLI_SCRIPT" ]]; then
        log_message "FAIL" "LLM CLI script not found: $LLM_CLI_SCRIPT"
        return 1
    fi
    
    if [[ ! -x "$LLM_CLI_SCRIPT" ]]; then
        log_message "WARN" "Making LLM CLI script executable: $LLM_CLI_SCRIPT"
        chmod +x "$LLM_CLI_SCRIPT"
    fi
    
    if [[ ! -f ".chatWithLLM" ]]; then
        log_message "WARN" "Configuration file not found. Make sure to run '$LLM_CLI_SCRIPT --init' and add your API keys."
    fi
    
    log_message "INFO" "Prerequisites check completed."
    return 0
}

# Function: test_model
# Description: Test a specific model
# Parameters:
#   $1 - model string (provider:model format)
# Returns: 0 on success, 1 on failure
test_model() {
    local model="$1"
    local provider="${model%%:*}"
    local model_name="${model#*:}"
    
    log_message "INFO" "Testing model: $model"
    
    # Increment total test counter
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Run the LLM CLI with timeout
    local response
    local exit_code
    
    # Use timeout to prevent hanging (30 seconds max)
    if command -v timeout >/dev/null 2>&1; then
        response=$(timeout 30s "$LLM_CLI_SCRIPT" -m "$model" -F plain "$TEST_PROMPT" 2>&1)
        exit_code=$?
    else
        # Fallback if timeout command is not available
        response=$("$LLM_CLI_SCRIPT" -m "$model" -F plain "$TEST_PROMPT" 2>&1)
        exit_code=$?
    fi
    
    # Check if the command executed successfully
    if [[ $exit_code -ne 0 ]]; then
        log_message "FAIL" "Model $model - CLI execution failed (exit code: $exit_code)"
        if [[ "$response" == *"No API key found"* ]]; then
            log_message "WARN" "Model $model - Missing API key for provider: $provider"
        elif [[ "$response" == *"HTTP 401"* ]] || [[ "$response" == *"Unauthorized"* ]]; then
            log_message "WARN" "Model $model - Invalid API key for provider: $provider"
        elif [[ "$response" == *"HTTP 404"* ]] || [[ "$response" == *"not found"* ]]; then
            log_message "WARN" "Model $model - Model not found or unavailable"
        else
            log_message "FAIL" "Model $model - Error: $response"
        fi
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
    
    # Check if response contains the expected answer
    if echo "$response" | grep -q "$EXPECTED_ANSWER"; then
        log_message "PASS" "Model $model - Response contains expected answer '$EXPECTED_ANSWER'"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        
        # Show the actual response for verification
        local clean_response
        clean_response=$(echo "$response" | head -3 | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')
        log_message "INFO" "Model $model - Response preview: ${clean_response:0:100}..."
        
        return 0
    else
        log_message "FAIL" "Model $model - Response does not contain expected answer '$EXPECTED_ANSWER'"
        log_message "INFO" "Model $model - Actual response: $response"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Function: run_tests
# Description: Run tests for all configured models
run_tests() {
    log_message "INFO" "Starting LLM CLI tests..."
    log_message "INFO" "Test prompt: '$TEST_PROMPT'"
    log_message "INFO" "Expected answer: '$EXPECTED_ANSWER'"
    log_message "INFO" "Number of models to test: ${#MODELS_TO_TEST[@]}"
    
    echo ""
    
    for model in "${MODELS_TO_TEST[@]}"; do
        test_model "$model"
        echo "" # Add spacing between tests
        
        # Optional: Add a small delay between tests to be nice to APIs
        sleep 1
    done
}

# Function: show_summary
# Description: Display test results summary
show_summary() {
    echo ""
    echo "======================================"
    echo "           TEST SUMMARY"
    echo "======================================"
    echo "Total tests run:    $TOTAL_TESTS"
    echo -e "Tests passed:       ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Tests failed:       ${RED}$FAILED_TESTS${NC}"
    
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo "Success rate:       ${success_rate}%"
    fi
    
    echo "======================================"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_message "PASS" "All tests completed successfully!"
        return 0
    else
        log_message "FAIL" "Some tests failed. Check the output above for details."
        return 1
    fi
}

# Function: show_usage
# Description: Display usage information
show_usage() {
    cat << 'EOF'
test_llm_cli.sh - Test script for chatWithLLM.sh

USAGE:
    ./test_llm_cli.sh [OPTIONS]

OPTIONS:
    -h, --help      Show this help message
    -q, --quick     Test only a subset of models (faster testing)
    -v, --verbose   Show more detailed output

DESCRIPTION:
    This script tests the availability of different LLM models by asking
    "What is 1+1?" and checking if the response contains "2".
    
    Before running, make sure:
    1. chatWithLLM.sh is in the same directory
    2. You have run 'chatWithLLM.sh --init' to create config
    3. You have added your API keys to .chatWithLLM config file

EXAMPLES:
    ./test_llm_cli.sh           # Test all configured models
    ./test_llm_cli.sh --quick   # Test only a few models
    ./test_llm_cli.sh --verbose # Show detailed output
EOF
}

# Main execution
main() {
    local quick_mode=false
    local verbose_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -q|--quick)
                quick_mode=true
                shift
                ;;
            -v|--verbose)
                verbose_mode=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Adjust models for quick mode
    if [[ "$quick_mode" == true ]]; then
        log_message "INFO" "Quick mode enabled - testing subset of models"
        MODELS_TO_TEST=(
            "openai:gpt-3.5-turbo"
            "anthropic:claude-3-haiku-20240307"
            "google:gemini-pro"
        )
    fi
    
    # Set verbose mode (could be used to show more details)
    if [[ "$verbose_mode" == true ]]; then
        log_message "INFO" "Verbose mode enabled"
    fi
    
    # Run the test suite
    if ! check_prerequisites; then
        exit 1
    fi
    
    run_tests
    
    if show_summary; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
