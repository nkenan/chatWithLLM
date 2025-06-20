#!/bin/bash
# chatWithLLM.sh - Universal LLM CLI Interface
# Supports: OpenAI, Google (Gemini), Meta (Llama), Mistral, DeepSeek, Anthropic
# Dependencies: curl, sed, grep (no jq, awk, or bc)

set -euo pipefail

# ============================================================================
# GLOBAL VARIABLES AND CONSTANTS
# ============================================================================

# Default configuration
DEFAULT_PROVIDER=""
DEFAULT_MODEL=""
DEFAULT_OUTPUT_FORMAT="markdown"
DEFAULT_MAX_TOKENS=4096
DEFAULT_TEMPERATURE=0.7
CONFIG_FILE=".chatWithLLM"

# Provider endpoints
declare -A PROVIDER_ENDPOINTS=(
    ["openai"]="https://api.openai.com/v1/chat/completions"
    ["anthropic"]="https://api.anthropic.com/v1/messages"
    ["google"]="https://generativelanguage.googleapis.com/v1beta/models"
    ["mistral"]="https://api.mistral.ai/v1/chat/completions"
    ["deepseek"]="https://api.deepseek.com/v1/chat/completions"
    ["meta"]="https://api.meta.com/v1/chat/completions"
)

# Global return variables for functions
RESPONSE_CONTENT=""
RESPONSE_ERROR=""
RESPONSE_SUCCESS=""
RESPONSE_USAGE=""
RESPONSE_RAW=""
RESPONSE_FILE=""

# Function: init_config - Updated
# Description: Initialize configuration file with default model and API keys
# Parameters: None
# Returns: 0 on success, 1 on failure
# Side effects: Creates .chatWithLLM file if not exists
init_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "Configuration file already exists: $CONFIG_FILE"
        return 0
    fi

    local config_template="# chatWithLLM Configuration File
# Default model (provider:model format)
DEFAULT_MODEL=anthropic:claude-3-opus-20240229

# API Keys - Add your keys below
# OpenAI
OPENAI_API_KEY=

# Anthropic (Claude)
ANTHROPIC_API_KEY=

# Google (Gemini)
GOOGLE_API_KEY=

# Mistral
MISTRAL_API_KEY=

# DeepSeek
DEEPSEEK_API_KEY=

# Meta (Llama) - if using cloud API
META_API_KEY=
"
    
    echo "$config_template" > "$CONFIG_FILE"
    echo "Configuration file created: $CONFIG_FILE"
    echo "Please edit the file and add your API keys and set your preferred DEFAULT_MODEL."
    return 0
}

# Function: load_config - Updated
# Description: Load API keys and default model from configuration file
# Parameters: None
# Returns: 0 on success, 1 on failure
# Side effects: Sets environment variables for API keys and DEFAULT_MODEL
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$CONFIG_FILE: Configuration file not found. Run with --init to create a configuration file."
        return 1
    fi

    # Source the config file to load API keys and default model
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
            continue
        fi
        
        # Export valid key=value pairs
        if [[ "$line" =~ ^[A-Z_]+=[^[:space:]]*$ ]]; then
            export "$line"
        fi
    done < "$CONFIG_FILE"

    # Set the default model from config
    if [[ -n "${DEFAULT_MODEL:-}" ]]; then
        # Validate format
        if [[ "$DEFAULT_MODEL" == *":"* ]]; then
            echo "Using default model from config: $DEFAULT_MODEL" >&2
        else
            echo "Warning: DEFAULT_MODEL in config should be in provider:model format" >&2
        fi
    fi

    return 0
}

# Function: get_api_key
# Description: Get API key for specified provider
# Parameters: 
#   $1 - provider name (openai, anthropic, google, etc.)
# Returns: API key via echo, empty string if not found
get_api_key() {
    local provider="$1"
    
    case "$provider" in
        "openai")
            echo "${OPENAI_API_KEY:-}"
            ;;
        "anthropic")
            echo "${ANTHROPIC_API_KEY:-}"
            ;;
        "google")
            echo "${GOOGLE_API_KEY:-}"
            ;;
        "mistral")
            echo "${MISTRAL_API_KEY:-}"
            ;;
        "deepseek")
            echo "${DEEPSEEK_API_KEY:-}"
            ;;
        "meta")
            echo "${META_API_KEY:-}"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ============================================================================
# PROVIDER DETECTION AND VALIDATION
# ============================================================================

# Function: parse_model_string - Simplified
# Description: Parse model string in format "provider:model"
# Parameters:
#   $1 - model string (e.g., "openai:gpt-4", "anthropic:claude-3-opus")
# Returns: Sets PROVIDER and MODEL variables
parse_model_string() {
    local model_string="$1"
    
    if [[ "$model_string" == *":"* ]]; then
        PROVIDER="${model_string%%:*}"
        MODEL="${model_string#*:}"
    else
        echo "Error: Model must be specified in provider:model format (e.g., openai:gpt-4)" >&2
        return 1
    fi
}

# Function: validate_provider
# Description: Check if provider is supported
# Parameters:
#   $1 - provider name
# Returns: 0 if valid, 1 if invalid
validate_provider() {
    local provider="$1"
    
    case "$provider" in
        openai|anthropic|google|mistral|deepseek|meta)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ============================================================================
# INPUT PROCESSING
# ============================================================================

# Function: process_input_files
# Description: Process multiple input files, including images for vision models
# Parameters:
#   $1 - comma-separated list of file paths
# Returns: Processed content via RESPONSE_CONTENT, error via RESPONSE_ERROR
# Supports: text files, images (for vision models), PDFs (basic text extraction)
process_input_files() {
    local files="$1"
    local processed_content=""
    
    RESPONSE_ERROR=""
    
    # Split files by comma
    IFS=',' read -ra FILE_ARRAY <<< "$files"
    
    for file in "${FILE_ARRAY[@]}"; do
        # Trim whitespace
        file=$(echo "$file" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [[ ! -f "$file" ]]; then
            RESPONSE_ERROR="File not found: $file"
            return 1
        fi
        
        local file_type
        file_type=$(detect_file_type "$file")
        
        case "$file_type" in
            "text")
                processed_content+="\n\n--- Content from $file ---\n"
                processed_content+=$(cat "$file")
                ;;
            "image")
                # For images, we'll return the file path for the API call to handle
                processed_content+="\n\n--- Image file: $file ---\n"
                processed_content+="[IMAGE:$file]"
                ;;
            "pdf")
                # Basic PDF text extraction (requires pdftotext if available)
                if command -v pdftotext >/dev/null 2>&1; then
                    processed_content+="\n\n--- Content from $file ---\n"
                    processed_content+=$(pdftotext "$file" - 2>/dev/null || echo "Could not extract text from PDF")
                else
                    RESPONSE_ERROR="PDF support requires pdftotext (poppler-utils package)"
                    return 1
                fi
                ;;
            *)
                RESPONSE_ERROR="Unsupported file type: $file"
                return 1
                ;;
        esac
    done
    
    RESPONSE_CONTENT="$processed_content"
    return 0
}

# Function: shell_base64_encode - Improved Version
# Description: Pure shell implementation of base64 encoding (no external dependencies)
# Parameters:
#   $1 - file path to encode
# Returns: base64 string via echo
shell_base64_encode() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo ""
        return 1
    fi
    
    # Base64 alphabet
    local b64_chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    
    # Read file as binary using od (octal dump)
    local bytes
    bytes=$(od -An -tx1 -v "$file_path" 2>/dev/null | tr -d ' \n' | tr '[:lower:]' '[:upper:]')
    
    if [[ -z "$bytes" ]]; then
        echo ""
        return 1
    fi
    
    local result=""
    local i=0
    local len=${#bytes}
    
    # Process in groups of 6 hex characters (3 bytes = 24 bits)
    while [[ $i -lt $len ]]; do
        local hex_group=""
        local byte_count=0
        
        # Collect up to 3 bytes (6 hex chars)
        for ((j=0; j<6 && i+j<len; j+=2)); do
            hex_group+="${bytes:$((i+j)):2}"
            ((byte_count++))
        done
        
        # Pad with zeros if needed
        while [[ ${#hex_group} -lt 6 ]]; do
            hex_group+="00"
        done
        
        # Convert hex to decimal
        local byte1=$((0x${hex_group:0:2}))
        local byte2=$((0x${hex_group:2:2}))
        local byte3=$((0x${hex_group:4:2}))
        
        # Combine into 24-bit number
        local combined=$((byte1 * 65536 + byte2 * 256 + byte3))
        
        # Extract 4 groups of 6 bits each
        local b64_1=$(((combined >> 18) & 63))
        local b64_2=$(((combined >> 12) & 63))
        local b64_3=$(((combined >> 6) & 63))
        local b64_4=$((combined & 63))
        
        # Convert to base64 characters
        result+="${b64_chars:$b64_1:1}${b64_chars:$b64_2:1}"
        
        if [[ $byte_count -gt 1 ]]; then
            result+="${b64_chars:$b64_3:1}"
        else
            result+="="
        fi
        
        if [[ $byte_count -gt 2 ]]; then
            result+="${b64_chars:$b64_4:1}"
        else
            result+="="
        fi
        
        i=$((i + byte_count * 2))
    done
    
    echo "$result"
}

# Alternative: Even simpler base64 implementation using printf
# This version is more portable and easier to understand
shell_base64_encode_simple() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        echo ""
        return 1
    fi
    
    # Base64 alphabet
    local b64="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local result=""
    local padding=""
    
    # Read file byte by byte using od
    local bytes
    bytes=$(od -An -td1 -v "$file_path" 2>/dev/null | tr -d ' \n')
    
    if [[ -z "$bytes" ]]; then
        echo ""
        return 1
    fi
    
    # Convert space-separated decimal bytes to array
    local byte_array=()
    local temp_byte=""
    
    for ((i=0; i<${#bytes}; i++)); do
        local char="${bytes:$i:1}"
        if [[ "$char" =~ [0-9] ]]; then
            temp_byte+="$char"
        else
            if [[ -n "$temp_byte" ]]; then
                byte_array+=("$temp_byte")
                temp_byte=""
            fi
        fi
    done
    
    # Add last byte if exists
    if [[ -n "$temp_byte" ]]; then
        byte_array+=("$temp_byte")
    fi
    
    # Process bytes in groups of 3
    for ((i=0; i<${#byte_array[@]}; i+=3)); do
        local b1=${byte_array[$i]:-0}
        local b2=${byte_array[$((i+1))]:-0}
        local b3=${byte_array[$((i+2))]:-0}
        
        # Check how many actual bytes we have
        local actual_bytes=1
        if [[ $((i+1)) -lt ${#byte_array[@]} ]]; then
            actual_bytes=2
        fi
        if [[ $((i+2)) -lt ${#byte_array[@]} ]]; then
            actual_bytes=3
        fi
        
        # Combine 3 bytes into 24-bit number
        local combined=$((b1 * 65536 + b2 * 256 + b3))
        
        # Extract 4 base64 indices
        local idx1=$(((combined >> 18) & 63))
        local idx2=$(((combined >> 12) & 63))
        local idx3=$(((combined >> 6) & 63))
        local idx4=$((combined & 63))
        
        # Add base64 characters
        result+="${b64:$idx1:1}${b64:$idx2:1}"
        
        if [[ $actual_bytes -gt 1 ]]; then
            result+="${b64:$idx3:1}"
        else
            result+="="
        fi
        
        if [[ $actual_bytes -gt 2 ]]; then
            result+="${b64:$idx4:1}"
        else
            result+="="
        fi
    done
    
    echo "$result"
}

# Function: encode_image_base64 - Updated
# Description: Encode image file to base64 for vision API calls
# Parameters:
#   $1 - image file path
# Returns: base64 string via echo
encode_image_base64() {
    local image_path="$1"
    
    if [[ ! -f "$image_path" ]]; then
        echo ""
        return 1
    fi
    
    # Try native base64 first, then fallback to shell implementation
    if command -v base64 >/dev/null 2>&1; then
        base64 -w 0 "$image_path" 2>/dev/null
    else
        # Use the simpler shell implementation
        shell_base64_encode_simple "$image_path"
    fi
}


# Function: detect_file_type
# Description: Detect file type (text, image, etc.)
# Parameters:
#   $1 - file path
# Returns: file type string via echo (text, image, pdf, unknown)
detect_file_type() {
    local file_path="$1"
    
    # Get file extension
    local ext="${file_path##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    case "$ext" in
        txt|md|markdown|rst|org|tex|py|js|html|css|json|xml|yaml|yml|sh|bash|zsh|fish|c|cpp|h|hpp|java|go|rs|php|rb|pl|swift|kt|scala|clj)
            echo "text"
            ;;
        jpg|jpeg|png|gif|bmp|webp|svg)
            echo "image"
            ;;
        pdf)
            echo "pdf"
            ;;
        *)
            # Try to detect by file content
            if file "$file_path" 2>/dev/null | grep -q "text"; then
                echo "text"
            else
                echo "unknown"
            fi
            ;;
    esac
}

# ============================================================================
# REQUEST BUILDING
# ============================================================================

# Function: build_request_body
# Description: Build JSON request body for specified provider
# Parameters:
#   $1 - provider name
#   $2 - model name
#   $3 - user content/prompt
#   $4 - max_tokens
#   $5 - temperature
#   $6 - additional parameters (provider-specific)
# Returns: JSON string via echo
build_request_body() {
    local provider="$1"
    local model="$2"
    local content="$3"
    local max_tokens="$4"
    local temperature="$5"
    local extra_params="$6"
    
    case "$provider" in
        "openai")
            build_openai_request "$model" "$content" "$max_tokens" "$temperature" "$extra_params"
            ;;
        "anthropic")
            build_anthropic_request "$model" "$content" "$max_tokens" "$temperature" "$extra_params"
            ;;
        "google")
            build_google_request "$model" "$content" "$max_tokens" "$temperature" "$extra_params"
            ;;
        "mistral")
            build_mistral_request "$model" "$content" "$max_tokens" "$temperature" "$extra_params"
            ;;
        "deepseek")
            build_deepseek_request "$model" "$content" "$max_tokens" "$temperature" "$extra_params"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function: build_openai_request
# Description: Build OpenAI-specific request body
# Parameters: Same as build_request_body
# Returns: JSON string via echo
build_openai_request() {
    local model="$1"
    local content="$2"
    local max_tokens="$3"
    local temperature="$4"
    local extra_params="$5"
    
    local escaped_content
    escaped_content=$(escape_json "$content")
    
    cat << EOF
{
  "model": "$model",
  "messages": [
    {
      "role": "user",
      "content": "$escaped_content"
    }
  ],
  "max_tokens": $max_tokens,
  "temperature": $temperature
}
EOF
}

# Function: build_anthropic_request
# Description: Build Anthropic-specific request body
# Parameters: Same as build_request_body
# Returns: JSON string via echo
build_anthropic_request() {
    local model="$1"
    local content="$2"
    local max_tokens="$3"
    local temperature="$4"
    local extra_params="$5"
    
    local escaped_content
    escaped_content=$(escape_json "$content")
    
    cat << EOF
{
  "model": "$model",
  "max_tokens": $max_tokens,
  "temperature": $temperature,
  "messages": [
    {
      "role": "user",
      "content": "$escaped_content"
    }
  ]
}
EOF
}

# Function: build_google_request
# Description: Build Google Gemini-specific request body
# Parameters: Same as build_request_body
# Returns: JSON string via echo
build_google_request() {
    local model="$1"
    local content="$2"
    local max_tokens="$3"
    local temperature="$4"
    local extra_params="$5"
    
    local escaped_content
    escaped_content=$(escape_json "$content")
    
    cat << EOF
{
  "contents": [{
    "parts": [{
      "text": "$escaped_content"
    }]
  }],
  "generationConfig": {
    "temperature": $temperature,
    "maxOutputTokens": $max_tokens
  }
}
EOF
}

# Function: build_mistral_request
# Description: Build Mistral-specific request body
# Parameters: Same as build_request_body
# Returns: JSON string via echo
build_mistral_request() {
    local model="$1"
    local content="$2"
    local max_tokens="$3"
    local temperature="$4"
    local extra_params="$5"
    
    local escaped_content
    escaped_content=$(escape_json "$content")
    
    cat << EOF
{
  "model": "$model",
  "messages": [
    {
      "role": "user",
      "content": "$escaped_content"
    }
  ],
  "max_tokens": $max_tokens,
  "temperature": $temperature
}
EOF
}

# Function: build_deepseek_request
# Description: Build DeepSeek-specific request body
# Parameters: Same as build_request_body
# Returns: JSON string via echo
build_deepseek_request() {
    local model="$1"
    local content="$2"
    local max_tokens="$3"
    local temperature="$4"
    local extra_params="$5"
    
    local escaped_content
    escaped_content=$(escape_json "$content")
    
    cat << EOF
{
  "model": "$model",
  "messages": [
    {
      "role": "user",
      "content": "$escaped_content"
    }
  ],
  "max_tokens": $max_tokens,
  "temperature": $temperature
}
EOF
}

# ============================================================================
# API COMMUNICATION
# ============================================================================

# Function: make_api_call
# Description: Make HTTP request to LLM provider
# Parameters:
#   $1 - provider name
#   $2 - request body (JSON)
#   $3 - API key
#   $4 - model name
# Returns: Sets RESPONSE_RAW with full response, RESPONSE_SUCCESS=true/false
make_api_call() {
    local provider="$1"
    local request_body="$2"
    local api_key="$3"
    local model="$4"
    
    local url
    url=$(get_provider_url "$provider" "$model")
    
    # Make the API call
    local temp_file
    temp_file=$(mktemp)
    
    local curl_args=()
    curl_args+=("-s" "-w" "%{http_code}" "-X" "POST")
    
    # Add provider-specific headers
    case "$provider" in
        "openai"|"deepseek"|"mistral")
            curl_args+=("-H" "Authorization: Bearer $api_key")
            ;;
        "anthropic")
            curl_args+=("-H" "x-api-key: $api_key" "-H" "anthropic-version: 2023-06-01")
            ;;
        "google")
            # Google uses API key in URL, no auth header needed
            ;;
        "meta")
            curl_args+=("-H" "Authorization: Bearer $api_key")
            ;;
    esac
    
    curl_args+=("-H" "Content-Type: application/json")
    curl_args+=("-d" "$request_body")
    curl_args+=("$url")
    curl_args+=("-o" "$temp_file")
    
    local http_code
    http_code=$(curl "${curl_args[@]}")
    
    RESPONSE_RAW=$(cat "$temp_file")
    rm -f "$temp_file"
    
    # Check if http_code is a valid number
    if [[ "$http_code" =~ ^[0-9]+$ ]] && [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        RESPONSE_SUCCESS="true"
    else
        RESPONSE_SUCCESS="false"
        RESPONSE_ERROR="HTTP $http_code: $RESPONSE_RAW"
    fi
}

# Function: get_provider_headers
# Description: Get provider-specific HTTP headers
# Parameters:
#   $1 - provider name
#   $2 - API key
# Returns: curl header arguments via echo
get_provider_headers() {
    local provider="$1"
    local api_key="$2"
    
    # This function is now deprecated in favor of direct header handling in make_api_call
    # Keeping for compatibility but not used
    echo ""
}

# Function: get_provider_url
# Description: Get full API URL for provider
# Parameters:
#   $1 - provider name
#   $2 - model name (some providers need model in URL)
# Returns: URL string via echo
get_provider_url() {
    local provider="$1"
    local model="$2"
    
    case "$provider" in
        "google")
            local api_key
            api_key=$(get_api_key "$provider")
            echo "${PROVIDER_ENDPOINTS[$provider]}/$model:generateContent?key=$api_key"
            ;;
        *)
            echo "${PROVIDER_ENDPOINTS[$provider]}"
            ;;
    esac
}

# ============================================================================
# RESPONSE PARSING
# ============================================================================

# Function: parse_response
# Description: Parse provider-specific response format
# Parameters:
#   $1 - provider name
#   $2 - raw JSON response
# Returns: Sets RESPONSE_CONTENT, RESPONSE_ERROR, RESPONSE_USAGE
parse_response() {
    local provider="$1"
    local raw_response="$2"
    
    case "$provider" in
        "openai")
            parse_openai_response "$raw_response"
            ;;
        "anthropic")
            parse_anthropic_response "$raw_response"
            ;;
        "google")
            parse_google_response "$raw_response"
            ;;
        "mistral")
            parse_mistral_response "$raw_response"
            ;;
        "deepseek")
            parse_deepseek_response "$raw_response"
            ;;
        *)
            RESPONSE_CONTENT=""
            RESPONSE_ERROR="Unknown provider: $provider"
            RESPONSE_USAGE=""
            ;;
    esac
}

# Function: parse_openai_response
# Description: Parse OpenAI response format
# Parameters:
#   $1 - raw JSON response
# Returns: Sets global response variables
parse_openai_response() {
    local raw_response="$1"
    
    # Check for error first
    local error_message
    error_message=$(extract_json_value "$raw_response" "error.message")
    
    if [[ -n "$error_message" ]]; then
        RESPONSE_ERROR="$error_message"
        RESPONSE_CONTENT=""
        return
    fi
    
    # Extract content
    RESPONSE_CONTENT=$(extract_json_value "$raw_response" "choices.0.message.content")
    
    # Extract usage information
    local prompt_tokens completion_tokens
    prompt_tokens=$(extract_json_value "$raw_response" "usage.prompt_tokens")
    completion_tokens=$(extract_json_value "$raw_response" "usage.completion_tokens")
    
    if [[ -n "$prompt_tokens" && -n "$completion_tokens" ]]; then
        RESPONSE_USAGE="Tokens used: $prompt_tokens prompt + $completion_tokens completion = $((prompt_tokens + completion_tokens)) total"
    fi
}

# Function: parse_anthropic_response
# Description: Parse Anthropic response format
# Parameters:
#   $1 - raw JSON response
# Returns: Sets global response variables
parse_anthropic_response() {
    local raw_response="$1"
    
    # Check for error
    local error_message
    error_message=$(extract_json_value "$raw_response" "error.message")
    
    if [[ -n "$error_message" ]]; then
        RESPONSE_ERROR="$error_message"
        RESPONSE_CONTENT=""
        return
    fi
    
    # Extract content
    RESPONSE_CONTENT=$(extract_json_value "$raw_response" "content.0.text")
    
    # Extract usage
    local input_tokens output_tokens
    input_tokens=$(extract_json_value "$raw_response" "usage.input_tokens")
    output_tokens=$(extract_json_value "$raw_response" "usage.output_tokens")
    
    if [[ -n "$input_tokens" && -n "$output_tokens" ]]; then
        RESPONSE_USAGE="Tokens used: $input_tokens input + $output_tokens output = $((input_tokens + output_tokens)) total"
    fi
}

# Function: parse_google_response
# Description: Parse Google Gemini response format
# Parameters:
#   $1 - raw JSON response
# Returns: Sets global response variables
parse_google_response() {
    local raw_response="$1"
    
    # Check for error
    local error_message
    error_message=$(extract_json_value "$raw_response" "error.message")
    
    if [[ -n "$error_message" ]]; then
        RESPONSE_ERROR="$error_message"
        RESPONSE_CONTENT=""
        return
    fi
    
    # Extract content
    RESPONSE_CONTENT=$(extract_json_value "$raw_response" "candidates.0.content.parts.0.text")
    
    # Extract usage (if available)
    local prompt_tokens completion_tokens
    prompt_tokens=$(extract_json_value "$raw_response" "usageMetadata.promptTokenCount")
    completion_tokens=$(extract_json_value "$raw_response" "usageMetadata.candidatesTokenCount")
    
    if [[ -n "$prompt_tokens" && -n "$completion_tokens" ]]; then
        RESPONSE_USAGE="Tokens used: $prompt_tokens prompt + $completion_tokens completion = $((prompt_tokens + completion_tokens)) total"
    fi
}

# Function: parse_mistral_response
# Description: Parse Mistral response format
# Parameters:
#   $1 - raw JSON response
# Returns: Sets global response variables
parse_mistral_response() {
    local raw_response="$1"
    
    # Similar to OpenAI format
    local error_message
    error_message=$(extract_json_value "$raw_response" "error.message")
    
    if [[ -n "$error_message" ]]; then
        RESPONSE_ERROR="$error_message"
        RESPONSE_CONTENT=""
        return
    fi
    
    RESPONSE_CONTENT=$(extract_json_value "$raw_response" "choices.0.message.content")
    
    local prompt_tokens completion_tokens
    prompt_tokens=$(extract_json_value "$raw_response" "usage.prompt_tokens")
    completion_tokens=$(extract_json_value "$raw_response" "usage.completion_tokens")
    
    if [[ -n "$prompt_tokens" && -n "$completion_tokens" ]]; then
        RESPONSE_USAGE="Tokens used: $prompt_tokens prompt + $completion_tokens completion = $((prompt_tokens + completion_tokens)) total"
    fi
}

# Function: parse_deepseek_response
# Description: Parse DeepSeek response format
# Parameters:
#   $1 - raw JSON response
# Returns: Sets global response variables
parse_deepseek_response() {
    local raw_response="$1"
    
    # Similar to OpenAI format
    local error_message
    error_message=$(extract_json_value "$raw_response" "error.message")
    
    if [[ -n "$error_message" ]]; then
        RESPONSE_ERROR="$error_message"
        RESPONSE_CONTENT=""
        return
    fi
    
    RESPONSE_CONTENT=$(extract_json_value "$raw_response" "choices.0.message.content")
    
    local prompt_tokens completion_tokens
    prompt_tokens=$(extract_json_value "$raw_response" "usage.prompt_tokens")
    completion_tokens=$(extract_json_value "$raw_response" "usage.completion_tokens")
    
    if [[ -n "$prompt_tokens" && -n "$completion_tokens" ]]; then
        RESPONSE_USAGE="Tokens used: $prompt_tokens prompt + $completion_tokens completion = $((prompt_tokens + completion_tokens)) total"
    fi
}

# ============================================================================
# OUTPUT FORMATTING
# ============================================================================

# Function: format_output
# Description: Format response content according to specified format
# Parameters:
#   $1 - format type (markdown, plain, json, html)
#   $2 - response content
#   $3 - original prompt
#   $4 - provider name
#   $5 - model name
#   $6 - usage information
# Returns: Formatted string via echo
format_output() {
    local format="$1"
    local content="$2"
    local prompt="$3"
    local provider="$4"
    local model="$5"
    local usage="$6"
    
    case "$format" in
        "markdown")
            format_markdown "$content" "$prompt" "$provider" "$model" "$usage"
            ;;
        "plain")
            echo "$content"
            ;;
        "json")
            cat << EOF
{
  "provider": "$provider",
  "model": "$model",
  "prompt": "$(escape_json "$prompt")",
  "response": "$(escape_json "$content")",
  "usage": "$(escape_json "$usage")",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
            ;;
        "html")
            cat << EOF
<!DOCTYPE html>
<html>
<head>
    <title>LLM Response</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .metadata { background: #f5f5f5; padding: 10px; border-radius: 5px; margin-bottom: 20px; }
        .content { line-height: 1.6; }
        pre { background: #f8f8f8; padding: 10px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="metadata">
        <strong>Provider:</strong> $provider<br>
        <strong>Model:</strong> $model<br>
        <strong>Usage:</strong> $usage<br>
        <strong>Generated:</strong> $(date)
    </div>
    <div class="content">
        <h3>Prompt:</h3>
        <p>$(echo "$prompt" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')</p>
        <h3>Response:</h3>
        <div>$(echo "$content" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' | sed 's/$/\<br\>/g')</div>
    </div>
</body>
</html>
EOF
            ;;
        *)
            echo "$content"
            ;;
    esac
}

# Function: format_markdown
# Description: Format output as Markdown
# Parameters: Same as format_output
# Returns: Markdown string via echo
format_markdown() {
    local content="$1"
    local prompt="$2"
    local provider="$3"
    local model="$4"
    local usage="$5"
    
    cat << EOF
# LLM Response

**Provider:** $provider  
**Model:** $model  
**Usage:** $usage  
**Generated:** $(date)

## Prompt

$prompt

## Response

$content
EOF
}

# Function: save_output
# Description: Save formatted output to file
# Parameters:
#   $1 - formatted content
#   $2 - output filename (optional, auto-generated if empty)
#   $3 - format type
# Returns: Sets RESPONSE_FILE with saved filename
save_output() {
    local content="$1"
    local filename="$2"
    local format="$3"
    
    # Generate filename if not provided
    if [[ -z "$filename" ]]; then
        local timestamp
        timestamp=$(date +"%Y%m%d_%H%M%S")
        
        case "$format" in
            "html")
                filename="llm_response_${timestamp}.html"
                ;;
            "json")
                filename="llm_response_${timestamp}.json"
                ;;
            "markdown")
                filename="llm_response_${timestamp}.md"
                ;;
            *)
                filename="llm_response_${timestamp}.txt"
                ;;
        esac
    fi
    
    echo "$content" > "$filename"
    RESPONSE_FILE="$filename"
    
    echo "Output saved to: $filename"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function: escape_json
# Description: Escape string for JSON inclusion
# Parameters:
#   $1 - string to escape
# Returns: Escaped string via echo
escape_json() {
    local input="$1"
    
    # Escape backslashes, quotes, and control characters
    echo "$input" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g; s/\r/\\r/g'
}

# Function: extract_json_value
# Description: Extract value from JSON by key (simple implementation)
# Parameters:
#   $1 - JSON string
#   $2 - key to extract (dot notation supported)
# Returns: Value via echo
extract_json_value() {
    local json="$1"
    local key="$2"
    
    # Simple JSON extraction using sed/grep
    # This is a basic implementation - for complex JSON, consider using jq
    
    # For simple cases, use basic regex patterns
    case "$key" in
        "error.message")
            # Handle both nested error objects and direct error messages
            echo "$json" | sed -n 's/.*"error"[[:space:]]*:[[:space:]]*{[^}]*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
            if [[ -z "$(echo "$json" | sed -n 's/.*"error"[[:space:]]*:[[:space:]]*{[^}]*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')" ]]; then
                # Try simpler pattern for direct message
                echo "$json" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
            fi
            ;;
        "choices.0.message.content")
            local temp_content
            temp_content=$(echo "$json" | grep -o '"content"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1)
            
            if [[ -n "$temp_content" ]]; then
                echo "$temp_content" | sed 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
            else
                echo "$json" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
            fi
            ;;
        "content.0.text")
            echo "$json" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*\[[^]]*{.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
            ;;
        "candidates.0.content.parts.0.text")
            echo "$json" | sed -n 's/.*"candidates"[[:space:]]*:[[:space:]]*\[[^]]*{.*"content"[[:space:]]*:[[:space:]]*{.*"parts"[[:space:]]*:[[:space:]]*\[[^]]*{.*"text"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
            ;;
        "usage.prompt_tokens"|"usage.input_tokens")
            local tokens
            tokens=$(echo "$json" | sed -n 's/.*"usage"[[:space:]]*:[[:space:]]*{[^}]*"\(prompt_tokens\|input_tokens\)"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\2/p' | head -1)
            if [[ "$tokens" =~ ^[0-9]+$ ]]; then
                echo "$tokens"
            fi
            ;;
        "usage.completion_tokens"|"usage.output_tokens")
            local tokens
            tokens=$(echo "$json" | sed -n 's/.*"usage"[[:space:]]*:[[:space:]]*{[^}]*"\(completion_tokens\|output_tokens\)"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\2/p' | head -1)
            if [[ "$tokens" =~ ^[0-9]+$ ]]; then
                echo "$tokens"
            fi
            ;;
        "usageMetadata.promptTokenCount")
            local tokens
            tokens=$(echo "$json" | sed -n 's/.*"usageMetadata"[[:space:]]*:[[:space:]]*{[^}]*"promptTokenCount"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
            if [[ "$tokens" =~ ^[0-9]+$ ]]; then
                echo "$tokens"
            fi
            ;;
        "usageMetadata.candidatesTokenCount")
            local tokens
            tokens=$(echo "$json" | sed -n 's/.*"usageMetadata"[[:space:]]*:[[:space:]]*{[^}]*"candidatesTokenCount"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
            if [[ "$tokens" =~ ^[0-9]+$ ]]; then
                echo "$tokens"
            fi
            ;;
        *)
            # Fallback for simple key extraction
            echo "$json" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
            ;;
    esac
}

# Function: check_dependencies
# Description: Verify required commands are available
# Parameters: None
# Returns: 0 if all dependencies met, 1 otherwise
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands (base64 removed from required list)
    for cmd in curl sed grep od; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install the missing commands and try again."
        return 1
    fi
    
    # Check if we have base64 or od for image encoding
    if ! command -v base64 >/dev/null 2>&1 && ! command -v od >/dev/null 2>&1; then
        echo "Warning: Neither base64 nor od available. Image encoding will not work."
    fi
    
    return 0
}

# Function: show_usage
# Description: Display usage information
# Parameters: None
# Returns: Nothing (outputs to stdout)
show_usage() {
    cat << 'EOF'
chatWithLLM.sh - Universal LLM CLI Interface

USAGE:
    ./chatWithLLM.sh [OPTIONS] "prompt"
    ./chatWithLLM.sh [OPTIONS] --file input.txt
    echo "prompt" | ./chatWithLLM.sh [OPTIONS]

OPTIONS:
    -m, --model MODEL       Model in provider:model format
                           Examples: openai:gpt-4, anthropic:claude-3-opus, google:gemini-pro
    -f, --files FILES       Input files (comma-separated)
    -o, --output FILE       Output file (auto-generated if not specified)
    -F, --format FORMAT     Output format (markdown, plain, json, html)
    -t, --temperature NUM   Temperature (0.0-2.0, default: 0.7)
    -T, --max-tokens NUM    Maximum tokens (default: 4096)
    --file FILE            Read prompt from file
    --stdin                Read prompt from stdin
    --save                 Save output to file
    --init                 Initialize configuration file
    -h, --help             Show this help message
    -v, --verbose          Verbose output
    --debug                Debug mode (show raw API response)

EXAMPLES:
    # Basic usage with default model from config
    ./chatWithLLM.sh "Explain quantum computing"
    
    # Specify model explicitly
    ./chatWithLLM.sh -m "anthropic:claude-3-opus" "Write a poem"
    ./chatWithLLM.sh -m "openai:gpt-4" "Analyze this code"
    
    # Use input files
    ./chatWithLLM.sh -f "document.txt,image.jpg" "Analyze these files"
    
    # Save output as HTML
    ./chatWithLLM.sh -F html --save "Create a technical report"
    
    # Read from file
    ./chatWithLLM.sh --file prompt.txt -m openai:gpt-4
    
    # Pipe input
    echo "Translate to French: Hello world" | ./chatWithLLM.sh -m google:gemini-pro

CONFIGURATION:
    Run with --init to create a configuration file (.chatWithLLM)
    Set DEFAULT_MODEL=provider:model in the config file
    Add your API keys to the configuration file before use.

MODEL FORMAT:
    Always use provider:model format (e.g., openai:gpt-4, anthropic:claude-3-opus)
    Set your preferred default in the config file as DEFAULT_MODEL

SUPPORTED PROVIDERS:
    - openai (OpenAI models)
    - anthropic (Claude models)  
    - google (Gemini models)
    - mistral (Mistral models)
    - deepseek (DeepSeek models)
    - meta (Llama models)
EOF
}

# ============================================================================
# MAIN ORCHESTRATION
# ============================================================================

# Function: process_request
# Description: Main function to process a complete LLM request
# Parameters:
#   $1 - prompt
#   $2 - model string (provider:model)
#   $3 - input files (comma-separated)
#   $4 - output format
#   $5 - max tokens
#   $6 - temperature
#   $7 - output file (optional)
#   $8 - additional options
# Returns: 0 on success, 1 on failure
process_request() {
    local prompt="$1"
    local model_string="$2"
    local input_files="$3"
    local output_format="$4"
    local max_tokens="$5"
    local temperature="$6"
    local output_file="$7"
    local extra_options="$8"
    
    # Parse model string to get provider and model
    parse_model_string "$model_string"
    
    # Validate provider
    if ! validate_provider "$PROVIDER"; then
        echo "Error: Unsupported provider: $PROVIDER" >&2
        return 1
    fi
    
    # Get API key
    local api_key
    api_key=$(get_api_key "$PROVIDER")
    
    if [[ -z "$api_key" ]]; then
        echo "Error: No API key found for provider: $PROVIDER" >&2
        echo "Please add your API key to the configuration file." >&2
        return 1
    fi
    
    # Process input files if provided
    local full_prompt="$prompt"
    if [[ -n "$input_files" ]]; then
        if ! process_input_files "$input_files"; then
            echo "Error: $RESPONSE_ERROR" >&2
            return 1
        fi
        full_prompt="$prompt$RESPONSE_CONTENT"
    fi
    
    # Build request body
    local request_body
    request_body=$(build_request_body "$PROVIDER" "$MODEL" "$full_prompt" "$max_tokens" "$temperature" "$extra_options")
    
    if [[ -z "$request_body" ]]; then
        echo "Error: Failed to build request for provider: $PROVIDER" >&2
        return 1
    fi
    
    # Make API call
    make_api_call "$PROVIDER" "$request_body" "$api_key" "$MODEL"
    
    if [[ "$RESPONSE_SUCCESS" != "true" ]]; then
        echo "Error: API call failed: $RESPONSE_ERROR" >&2
        return 1
    fi
    
    # Parse response
    parse_response "$PROVIDER" "$RESPONSE_RAW"
    
    if [[ -n "$RESPONSE_ERROR" ]]; then
        echo "Error: $RESPONSE_ERROR" >&2
        return 1
    fi
    
    # Format output
    local formatted_output
    formatted_output=$(format_output "$output_format" "$RESPONSE_CONTENT" "$prompt" "$PROVIDER" "$MODEL" "$RESPONSE_USAGE")
    
    # Output to stdout
    echo "$formatted_output"
    
    # Save to file if requested
    if [[ -n "$output_file" ]] || [[ "$extra_options" == *"save"* ]]; then
        save_output "$formatted_output" "$output_file" "$output_format"
    fi
    
    return 0
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

# Function: main
# Description: Main entry point for CLI usage
# Parameters: All command line arguments
# Returns: 0 on success, 1 on failure
main() {
    # Default values - Updated
    local model_string=""  # Will be set from config or command line
    local provider=""
    local input_files=""
    local output_file=""
    local output_format="$DEFAULT_OUTPUT_FORMAT"
    local max_tokens="$DEFAULT_MAX_TOKENS"
    local temperature="$DEFAULT_TEMPERATURE"
    local prompt=""
    local read_from_file=""
    local read_from_stdin=false
    local save_output=false
    local verbose=false
    local debug=false
    local extra_options=""
    
    # Check dependencies first
    if ! check_dependencies; then
        return 1
    fi
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--model)
                model_string="$2"
                shift 2
                ;;
            -p|--provider)
                echo "Error: -p/--provider option removed. Use -m/--model with provider:model format" >&2
                return 1
                ;;
            # ... rest of the argument parsing remains the same ...
            -f|--files)
                input_files="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -F|--format)
                output_format="$2"
                shift 2
                ;;
            -t|--temperature)
                temperature="$2"
                shift 2
                ;;
            -T|--max-tokens)
                max_tokens="$2"
                shift 2
                ;;
            --file)
                read_from_file="$2"
                shift 2
                ;;
            --stdin)
                read_from_stdin=true
                shift
                ;;
            --save)
                save_output=true
                shift
                ;;
            --init)
                init_config
                return $?
                ;;
            --models)
                echo "Error: --models option removed. Model information is no longer hardcoded." >&2
                echo "Specify models in provider:model format (e.g., openai:gpt-4, anthropic:claude-3-opus)" >&2
                return 1
                ;;
            -h|--help)
                show_usage
                return 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            --debug)
                debug=true
                shift
                ;;
            -*)
                echo "Unknown option: $1" >&2
                show_usage >&2
                return 1
                ;;
            *)
                # First non-option argument is the prompt
                if [[ -z "$prompt" ]]; then
                    prompt="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Load configuration
    if ! load_config; then
        return 1
    fi
    
    # Use default model if none specified
    if [[ -z "$model_string" ]]; then
        if [[ -n "${DEFAULT_MODEL:-}" ]]; then
            model_string="$DEFAULT_MODEL"
            if [[ "$verbose" == true ]]; then
                echo "Using default model: $model_string" >&2
            fi
        else
            echo "Error: No model specified and no DEFAULT_MODEL set in config" >&2
            echo "Either specify -m provider:model or set DEFAULT_MODEL in $CONFIG_FILE" >&2
            return 1
        fi
    fi
    
    # Handle different input methods
    if [[ -n "$read_from_file" ]]; then
        if [[ ! -f "$read_from_file" ]]; then
            echo "Error: File not found: $read_from_file" >&2
            return 1
        fi
        prompt=$(cat "$read_from_file")
    elif [[ "$read_from_stdin" == true ]] || [[ -z "$prompt" && ! -t 0 ]]; then
        # Read from stdin
        prompt=$(cat)
    fi
    
    # Validate that we have a prompt
    if [[ -z "$prompt" ]]; then
        echo "Error: No prompt provided" >&2
        echo "Use --help for usage information" >&2
        return 1
    fi
    
    # Set extra options
    if [[ "$save_output" == true ]]; then
        extra_options+=" save"
    fi
    if [[ "$verbose" == true ]]; then
        extra_options+=" verbose"
    fi
    if [[ "$debug" == true ]]; then
        extra_options+=" debug"
    fi
    
    # Process the request
    if process_request "$prompt" "$model_string" "$input_files" "$output_format" "$max_tokens" "$temperature" "$output_file" "$extra_options"; then
        # Show debug information if requested
        if [[ "$debug" == true ]]; then
            echo "" >&2
            echo "=== DEBUG INFORMATION ===" >&2
            echo "Provider: $PROVIDER" >&2
            echo "Model: $MODEL" >&2
            echo "Raw API Response:" >&2
            echo "$RESPONSE_RAW" >&2
            echo "=========================" >&2
        fi
        
        # Show verbose information if requested
        if [[ "$verbose" == true && -n "$RESPONSE_USAGE" ]]; then
            echo "" >&2
            echo "$RESPONSE_USAGE" >&2
        fi
        
        return 0
    else
        return 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
