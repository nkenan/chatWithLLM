#!/bin/bash
# chatWithLLM.sh - Universal LLM CLI Interface (Minimal Version)
# Supports: OpenAI, Google (Gemini), Meta (Llama), Mistral, DeepSeek, Anthropic
# Dependencies: curl, sed, grep only

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

# Function: init_config
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

# Function: load_config
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

# Function: parse_model_string
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
# Description: Process multiple text files only (improved implementation)
# Parameters:
#   $1 - comma-separated list of file paths
# Returns: Processed content via RESPONSE_CONTENT, error via RESPONSE_ERROR
# Supports: text files only
process_input_files() {
    local files="$1"
    local processed_content=""
    local total_size=0
    local max_single_file=20971520
    local max_total_size=41943040
    
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
        
        # Check if file is readable
        if [[ ! -r "$file" ]]; then
            RESPONSE_ERROR="File not readable: $file"
            return 1
        fi
        
        # Check file size
        local file_size
        file_size=$(wc -c < "$file" 2>/dev/null || echo "0")
        
        # Skip very large files
        if [[ $file_size -gt $max_single_file ]]; then
            local size_mb=$((file_size / 1048576))
            echo "Warning: File too large, skipping: $file (~${size_mb}MB)" >&2
            continue
        fi
        
        total_size=$((total_size + file_size))
        
        # Check total size limit
        if [[ $total_size -gt $max_total_size ]]; then
            echo "Warning: Total file size limit exceeded, stopping at: $file" >&2
            break
        fi
        
        processed_content+="\n\n--- Content from $file ---\n"
        
        # Read file content with better error handling
        local file_content
        if ! file_content=$(cat "$file" 2>/dev/null); then
            echo "Warning: Could not read file: $file" >&2
            continue
        fi
        
        # More aggressive cleaning for problematic characters
        # Remove null bytes, control characters, and non-ASCII characters
        file_content=$(printf '%s' "$file_content" | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177-\377')
        
        # Additional cleanup: normalize line endings
        file_content=$(printf '%s' "$file_content" | tr '\r' '\n' | sed '/^$/N;/^\n$/d')
        
        processed_content+="$file_content"
    done
    
    RESPONSE_CONTENT="$processed_content"
    return 0
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
    
    # Create temporary files
    local temp_response temp_request
    temp_response=$(mktemp)
    temp_request=$(mktemp)
    
    # Write request body to temp file
    printf '%s' "$request_body" > "$temp_request"
    
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
    curl_args+=("--data-binary" "@$temp_request")
    curl_args+=("$url")
    curl_args+=("-o" "$temp_response")
    
    local http_code
    http_code=$(curl "${curl_args[@]}")
    
    RESPONSE_RAW=$(cat "$temp_response")
    
    # Cleanup
    rm -f "$temp_response" "$temp_request"
    
    # Check if http_code is a valid number
    if [[ "$http_code" =~ ^[0-9]+$ ]] && [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        RESPONSE_SUCCESS="true"
    else
        RESPONSE_SUCCESS="false"
        RESPONSE_ERROR="HTTP $http_code: $RESPONSE_RAW"
    fi
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
    
    # Sanitize content for safe output
    local safe_content
    safe_content=$(sanitize_content_for_output "$content")
    
    cat << EOF
# LLM Response

**Provider:** $provider  
**Model:** $model  
**Usage:** $usage  
**Generated:** $(date)

## Prompt

$prompt

## Response

$safe_content
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

# Function: sanitize_content_for_output
# Description: Sanitize content for safe shell output
# Parameters:
#   $1 - content to sanitize
# Returns: Sanitized content via echo
sanitize_content_for_output() {
    local content="$1"
    
    # Escape problematic characters for shell output
    printf '%s' "$content" | sed '
        s/\$/\\$/g
    '
}

# Function: escape_json
# Description: Escape string for JSON inclusion (improved implementation)
# Parameters:
#   $1 - string to escape
# Returns: Escaped string via echo
escape_json() {
    local input="$1"
    
    # More thorough cleaning - remove problematic control characters
    # Keep only printable ASCII, space, tab, newline, carriage return
    local cleaned_input
    cleaned_input=$(printf '%s' "$input" | LC_ALL=C sed 's/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\xFF]//g')
    
    # Escape for JSON using more robust sed patterns
    printf '%s' "$cleaned_input" | sed '
        s/\\/\\\\/g
        s/"/\\"/g
        s/	/\\t/g
        s//\\r/g
        s/$/\\n/g
    ' | tr -d '\n' | sed 's/\\n$//'
}

# Function: extract_json_value
# Description: Extract value from JSON by key (improved implementation - no new dependencies)
# Parameters:
#   $1 - JSON string
#   $2 - key to extract (dot notation supported)
# Returns: Value via echo
extract_json_value() {
    local json="$1"
    local key="$2"
    
    # Simple JSON extraction using sed/grep with improved patterns
    case "$key" in
        "error.message")
            # Handle both nested error objects and direct error messages
            local error_msg
            error_msg=$(echo "$json" | sed -n 's/.*"error"[[:space:]]*:[[:space:]]*{[^}]*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
            if [[ -z "$error_msg" ]]; then
                # Try simpler pattern for direct message
                error_msg=$(echo "$json" | sed -n 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
            fi
            echo "$error_msg"
            ;;
        "choices.0.message.content")
            # Extract OpenAI-style content, handling multiline content
            local content
            # Use a more robust approach - extract everything between "content":" and the next ",
            content=$(echo "$json" | sed -n 's/.*"choices":\[[^]]*"content":"\([^"]*\)".*/\1/p' | head -1)
            
            # If that fails, try a broader pattern
            if [[ -z "$content" ]]; then
                content=$(echo "$json" | grep -o '"content":"[^"]*"' | head -1 | sed 's/"content":"\(.*\)"/\1/')
            fi
            
            # Unescape JSON
            if [[ -n "$content" ]]; then
                # Use printf for better escape sequence handling
                printf '%b' "$content" | sed 's/\\"/"/g; s/\\\\/\\/g'
            fi
            ;;
        "content.0.text")
            # Extract Anthropic-style content - using only sed/grep
            local content
            # Step 1: Extract the content array section
            local content_section
            content_section=$(echo "$json" | grep -o '"content":\[[^]]*\]' | head -1)
            # Step 2: Extract just the text value
            if [[ -n "$content_section" ]]; then
                content=$(echo "$content_section" | sed 's/.*"text":"//')
                content=$(echo "$content" | sed 's/"}]$//')
            fi
            # Step 3: Properly unescape the content
            if [[ -n "$content" ]]; then
                # Handle all escape sequences in the correct order
                # First convert double-escaped quotes
                content=$(echo "$content" | sed 's/\\\\\"/\\"/g')
                # Then convert escaped newlines
                content=$(echo "$content" | sed 's/\\n/\
/g')
                # Convert escaped tabs
                content=$(echo "$content" | sed 's/\\t/	/g')
                # Convert escaped quotes
                content=$(echo "$content" | sed 's/\\"/"/g')
                # Finally handle escaped backslashes
                content=$(echo "$content" | sed 's/\\\\/\\/g')
                echo "$content"
            fi
            ;;
        "candidates.0.content.parts.0.text")
            # Extract Google Gemini content
            local content
            # Similar approach to Anthropic
            content=$(echo "$json" | sed -n 's/.*"candidates":\[[^]]*"text":"\([^"]*\)".*/\1/p' | head -1)
            
            if [[ -z "$content" ]]; then
                content=$(echo "$json" | grep -o '"text":"[^"]*"' | head -1 | sed 's/"text":"\(.*\)"/\1/')
            fi
            
            # Unescape
            if [[ -n "$content" ]]; then
                printf '%b' "$content" | sed 's/\\"/"/g; s/\\\\/\\/g'
            fi
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
    
    # Check for required commands
    for cmd in curl sed grep; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install the missing commands and try again."
        return 1
    fi
    
    return 0
}

# Function: show_usage
# Description: Display usage information
# Parameters: None
# Returns: Nothing (outputs to stdout)
show_usage() {
    cat << 'EOF'
chatWithLLM.sh - Universal LLM CLI Interface (Minimal Version)

USAGE:
    ./chatWithLLM.sh [OPTIONS] "prompt"
    ./chatWithLLM.sh [OPTIONS] --file input.txt
    echo "prompt" | ./chatWithLLM.sh [OPTIONS]

OPTIONS:
    -m, --model MODEL       Model in provider:model format
                           Examples: openai:gpt-4, anthropic:claude-3-opus, google:gemini-pro
    -f, --files FILES       Input text files (comma-separated)
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
    
    # Use input files (text files only)
    ./chatWithLLM.sh -f "document.txt,readme.md" "Analyze these files"
    
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

DEPENDENCIES:
    - bash, curl, sed, grep (minimal requirements)
    - No support for images, PDFs, or advanced text encoding
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
    # Default values
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
    else
        # Model was specified on command line
        if [[ "$verbose" == true ]]; then
            echo "Using specified model: $model_string" >&2
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
