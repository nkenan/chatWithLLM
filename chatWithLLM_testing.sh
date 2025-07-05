#!/bin/bash
# chatWithLLM_testing.sh - Simple test script for chatWithLLM.sh
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

# Models to test - add/remove as needed
MODELS_TO_TEST=(
    "openai:gpt-4o-mini-2024-07-18"
    "anthropic:claude-opus-4-20250514"
    "anthropic:claude-sonnet-4-20250514"
    "anthropic:claude-3-7-sonnet-20250219"
    "anthropic:claude-3-5-haiku-20241022"
    "anthropic:claude-3-5-sonnet-20241022"
    "anthropic:claude-3-5-sonnet-20240620"
    "anthropic:claude-3-opus-20240229"
    "anthropic:claude-3-haiku-20240307"
)

# Function: test_model
# Description: Test a specific model
test_model() {
    local model="$1"
    local provider="${model%%:*}"
    
    echo "Testing model: $model"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Run the LLM CLI with timeout
    local response
    local exit_code
    
    # Use timeout to prevent hanging (30 seconds max)
    if command -v timeout >/dev/null 2>&1; then
        response=$(timeout 30s "$LLM_CLI_SCRIPT" -m "$model" -F plain "$TEST_PROMPT" 2>&1)
        exit_code=$?
    else
        response=$("$LLM_CLI_SCRIPT" -m "$model" -F plain "$TEST_PROMPT" 2>&1)
        exit_code=$?
    fi
    
    # Check if the command executed successfully
    if [[ $exit_code -ne 0 ]]; then
        echo "❌ FAIL: Model $model - CLI execution failed (exit code: $exit_code)"
        if [[ "$response" == *"No API key found"* ]]; then
            echo "   Reason: Missing API key for provider: $provider"
        elif [[ "$response" == *"HTTP 401"* ]] || [[ "$response" == *"Unauthorized"* ]]; then
            echo "   Reason: Invalid API key for provider: $provider"
        elif [[ "$response" == *"HTTP 404"* ]] || [[ "$response" == *"not found"* ]]; then
            echo "   Reason: Model not found or unavailable"
        else
            echo "   Error: $response"
        fi
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
    
    # Check if response contains the expected answer
    if echo "$response" | grep -q "$EXPECTED_ANSWER"; then
        echo "✅ PASS: Model $model - Response contains expected answer '$EXPECTED_ANSWER'"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        
        # Show a preview of the response
        local clean_response
        clean_response=$(echo "$response" | head -1 | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')
        echo "   Response preview: ${clean_response:0:100}..."
        return 0
    else
        echo "❌ FAIL: Model $model - Response does not contain expected answer '$EXPECTED_ANSWER'"
        echo "   Actual response: $response"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Function: run_tests
# Description: Run tests for all configured models
run_tests() {
    echo "Starting LLM CLI tests..."
    echo "Test prompt: '$TEST_PROMPT'"
    echo "Expected answer: '$EXPECTED_ANSWER'"
    echo "Number of models to test: ${#MODELS_TO_TEST[@]}"
    echo ""
    
    for model in "${MODELS_TO_TEST[@]}"; do
        test_model "$model"
        echo ""
        sleep 1  # Small delay between tests
    done
}

# Function: show_summary
# Description: Display test results summary
show_summary() {
    echo "======================================"
    echo "           TEST SUMMARY"
    echo "======================================"
    echo "Total tests run:    $TOTAL_TESTS"
    echo "Tests passed:       $PASSED_TESTS"
    echo "Tests failed:       $FAILED_TESTS"
    
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo "Success rate:       ${success_rate}%"
    fi
    
    echo "======================================"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo "✅ All tests completed successfully!"
        return 0
    else
        echo "❌ Some tests failed. Check the output above for details."
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    if [[ ! -f "$LLM_CLI_SCRIPT" ]]; then
        echo "❌ LLM CLI script not found: $LLM_CLI_SCRIPT"
        return 1
    fi
    
    if [[ ! -x "$LLM_CLI_SCRIPT" ]]; then
        echo "Making LLM CLI script executable..."
        chmod +x "$LLM_CLI_SCRIPT"
    fi
    
    if [[ ! -f ".chatWithLLM" ]]; then
        echo "⚠️  Configuration file not found. Make sure to run '$LLM_CLI_SCRIPT --init' and add your API keys."
    fi
    
    echo "✅ Prerequisites check completed."
    return 0
}

# Main execution
main() {
    echo "LLM CLI Test Script"
    echo "==================="
    
    # Check if help was requested
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        cat << 'EOF'
chatWithLLM_testing.sh - Simple test script for chatWithLLM.sh

USAGE:
    ./chatWithLLM_testing.sh

DESCRIPTION:
    Tests LLM model availability by asking "What is 1+1?" and checking 
    if the response contains "2".
    
    Before running:
    1. Make sure chatWithLLM.sh is in the same directory
    2. Run 'chatWithLLM.sh --init' to create config
    3. Add your API keys to .chatWithLLM config file

EXAMPLES:
    ./chatWithLLM_testing.sh           # Test all configured models
EOF
        return 0
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
