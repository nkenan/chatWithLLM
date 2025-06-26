# 🤖 Universal LLM CLI Interface

A powerful, minimal bash script for interacting with multiple Large Language Model providers through a unified command-line interface. No external dependencies beyond standard Unix tools - just bash, curl, sed, and grep.

## ✨ Features

- 🔌 **Multiple Provider Support**: OpenAI, Anthropic (Claude), Google (Gemini), Mistral, DeepSeek, and Meta (Llama)
- 📝 **Flexible Input Methods**: Direct prompts, file input, stdin, or multiple text files
- 🎨 **Multiple Output Formats**: Markdown, plain text, JSON, and HTML
- ⚙️ **Configurable**: Simple configuration file for API keys and default models
- 🔧 **Minimal Dependencies**: Only requires bash, curl, sed, and grep
- 💾 **File Processing**: Support for text files with automatic content processing
- 📊 **Usage Tracking**: Token usage information from API responses
- 🎯 **Provider-Specific**: Optimized request handling for each LLM provider

## 🚀 Quick Start

### 1. Download and Setup

```bash
# Download the script
curl -O https://example.com/chatWithLLM.sh
chmod +x chatWithLLM.sh

# Initialize configuration
./chatWithLLM.sh --init
```

### 2. Configure API Keys

Edit the generated `.chatWithLLM` configuration file:

```bash
# chatWithLLM Configuration File
DEFAULT_MODEL=anthropic:claude-3-opus-20240229

# API Keys
OPENAI_API_KEY=sk-your-openai-key-here
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key-here
GOOGLE_API_KEY=your-google-api-key-here
MISTRAL_API_KEY=your-mistral-api-key-here
DEEPSEEK_API_KEY=your-deepseek-api-key-here
META_API_KEY=your-meta-api-key-here
```

### 3. Start Chatting

```bash
# Use your default model
./chatWithLLM.sh "Explain quantum computing in simple terms"

# Specify a different model
./chatWithLLM.sh -m "openai:gpt-4" "Write a Python function to sort a list"
```

## 📖 Usage

### Basic Syntax

```bash
./chatWithLLM.sh [OPTIONS] "prompt"
./chatWithLLM.sh [OPTIONS] --file input.txt
echo "prompt" | ./chatWithLLM.sh [OPTIONS]
```

### Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `-m, --model MODEL` | Model in provider:model format | `-m "anthropic:claude-3-opus"` |
| `-f, --files FILES` | Input text files (comma-separated) | `-f "doc1.txt,doc2.md"` |
| `-o, --output FILE` | Output file | `-o "response.html"` |
| `-F, --format FORMAT` | Output format (markdown, plain, json, html) | `-F json` |
| `-t, --temperature NUM` | Temperature (0.0-2.0) | `-t 0.8` |
| `-T, --max-tokens NUM` | Maximum tokens | `-T 2048` |
| `--file FILE` | Read prompt from file | `--file prompt.txt` |
| `--stdin` | Read prompt from stdin | `--stdin` |
| `--save` | Save output to auto-generated file | `--save` |
| `--init` | Initialize configuration file | `--init` |
| `-v, --verbose` | Verbose output with usage stats | `-v` |
| `--debug` | Debug mode (show raw API response) | `--debug` |
| `-h, --help` | Show help message | `-h` |

## 🌟 Examples

### Basic Usage

```bash
# Simple question with default model
./chatWithLLM.sh "What is the capital of France?"

# Creative writing with specific model
./chatWithLLM.sh -m "openai:gpt-4" "Write a short poem about autumn"

# Technical explanation with higher temperature
./chatWithLLM.sh -m "google:gemini-pro" -t 0.9 "Explain machine learning algorithms"
```

### File Input Examples

```bash
# Analyze a single document
./chatWithLLM.sh -f "report.txt" "Summarize the key points in this document"

# Process multiple files
./chatWithLLM.sh -f "code.py,readme.md,docs.txt" "Review this project and suggest improvements"

# Read prompt from file
./chatWithLLM.sh --file my_prompt.txt -m "anthropic:claude-3-opus"
```

### Output Formatting

```bash
# Save as HTML report
./chatWithLLM.sh -F html --save "Create a technical analysis of blockchain technology"

# Generate JSON output
./chatWithLLM.sh -F json -o "response.json" "Explain the water cycle"

# Markdown format with custom filename
./chatWithLLM.sh -F markdown -o "analysis.md" "Compare Python vs JavaScript"
```

### Pipeline Usage

```bash
# Use with pipes
echo "Translate to French: Hello, how are you?" | ./chatWithLLM.sh -m "google:gemini-pro"

# Process command output
ls -la | ./chatWithLLM.sh "Explain what these files and directories are for"

# Chain with other commands
cat error.log | ./chatWithLLM.sh "Analyze this error log and suggest fixes" | tee solution.txt
```

### Advanced Examples

```bash
# Code review with multiple files and detailed output
./chatWithLLM.sh -f "main.py,utils.py,config.json" \
    -m "anthropic:claude-3-opus" \
    -F html \
    --save \
    -v \
    "Perform a comprehensive code review and suggest optimizations"

# Creative writing with specific parameters
./chatWithLLM.sh \
    -m "openai:gpt-4" \
    -t 1.2 \
    -T 2048 \
    -F markdown \
    -o "story.md" \
    "Write a science fiction short story about time travel"

# Technical documentation generation
./chatWithLLM.sh \
    -f "api_spec.yaml,examples.json" \
    -m "google:gemini-pro" \
    -F html \
    --save \
    "Generate comprehensive API documentation with examples"
```

## 🔧 Configuration

### Configuration File (.chatWithLLM)

The configuration file supports:

- **DEFAULT_MODEL**: Your preferred model in `provider:model` format
- **API Keys**: Store all your provider API keys securely
- **Comments**: Use `#` for comments

Example configuration:

```bash
# Default model for all requests
DEFAULT_MODEL=anthropic:claude-3-opus-20240229

# OpenAI Configuration
OPENAI_API_KEY=sk-proj-abcd1234...

# Anthropic Configuration  
ANTHROPIC_API_KEY=sk-ant-api03-xyz789...

# Google Configuration
GOOGLE_API_KEY=AIzaSyABC123...

# Mistral Configuration
MISTRAL_API_KEY=mi-abc123...

# DeepSeek Configuration
DEEPSEEK_API_KEY=sk-def456...

# Meta Configuration (if using cloud API)
META_API_KEY=meta-abc123...
```

## 🤖 Supported Providers

The script is **model-agnostic** - it doesn't validate specific model names but passes whatever model you specify to the provider's API. This means it automatically supports new models as providers release them.

### OpenAI
- **Provider**: `openai`
- **Format**: `openai:model-name`
- **Examples**: `openai:gpt-4`, `openai:gpt-4-turbo`, `openai:gpt-3.5-turbo`, `openai:gpt-4o`

### Anthropic (Claude)
- **Provider**: `anthropic`
- **Format**: `anthropic:model-name`
- **Examples**: `anthropic:claude-3-opus-20240229`, `anthropic:claude-3-sonnet-20240229`, `anthropic:claude-3-haiku-20240307`

### Google (Gemini)
- **Provider**: `google`
- **Format**: `google:model-name`
- **Examples**: `google:gemini-pro`, `google:gemini-pro-vision`, `google:gemini-1.5-pro`

### Mistral
- **Provider**: `mistral`
- **Format**: `mistral:model-name`
- **Examples**: `mistral:mistral-large-latest`, `mistral:mistral-medium-latest`, `mistral:open-mixtral-8x7b`

### DeepSeek
- **Provider**: `deepseek`
- **Format**: `deepseek:model-name`
- **Examples**: `deepseek:deepseek-chat`, `deepseek:deepseek-coder`

### Meta (Llama)
- **Provider**: `meta`
- **Format**: `meta:model-name`
- **Examples**: `meta:llama-2-70b-chat` (if using cloud API)

> **Note**: The script simply forwards your specified model name to the provider's API. Check each provider's documentation for their current available models and exact naming conventions.

## 📤 Output Formats

### Markdown (default)
```bash
./chatWithLLM.sh -F markdown "Explain photosynthesis"
```

Generates a structured markdown document with metadata and formatted response.

### Plain Text
```bash
./chatWithLLM.sh -F plain "What is AI?"
```

Returns only the model's response without formatting.

### JSON
```bash
./chatWithLLM.sh -F json "Describe machine learning"
```

Returns structured JSON with provider, model, prompt, response, usage, and timestamp.

### HTML
```bash
./chatWithLLM.sh -F html "Create a technical report"
```

Generates a complete HTML document with styling and metadata.

## 📁 File Processing

### Supported File Types
- Text files (`.txt`)
- Markdown files (`.md`)
- Code files (`.py`, `.js`, `.json`, etc.)
- Configuration files (`.yaml`, `.conf`, etc.)
- Any UTF-8 text content

### File Size Limits
- **Per file**: 2MB maximum
- **Total content**: 4MB maximum
- **Content length**: Automatically truncated for API compatibility

### Examples

```bash
# Single file analysis
./chatWithLLM.sh -f "document.txt" "Summarize this document"

# Multiple file processing
./chatWithLLM.sh -f "src/main.py,src/utils.py,README.md" "Review this codebase"

# Large file handling (automatic truncation)
./chatWithLLM.sh -f "large_log.txt" "Find errors in this log file"
```

## 🔒 Security Notes

- **API Keys**: Store securely in the configuration file with appropriate file permissions
- **File Permissions**: Ensure `.chatWithLLM` is readable only by you (`chmod 600 .chatWithLLM`)
- **Sensitive Data**: Be cautious when processing files containing sensitive information
- **Network**: All API calls use HTTPS for secure communication

## 🛠️ Troubleshooting

### Common Issues

**Configuration file not found**
```bash
# Solution: Initialize configuration
./chatWithLLM.sh --init
```

**API key not found**
```bash
# Solution: Add your API key to .chatWithLLM
echo "OPENAI_API_KEY=your-key-here" >> .chatWithLLM
```

**Invalid model format**
```bash
# Wrong
./chatWithLLM.sh -m "gpt-4" "Hello"

# Correct
./chatWithLLM.sh -m "openai:gpt-4" "Hello"
```

**File too large**
```bash
# The script automatically handles large files by truncating content
# Check the warning messages for truncation notifications
./chatWithLLM.sh -v -f "large_file.txt" "Analyze this file"
```

### Debug Mode

Use `--debug` to see the raw API response:

```bash
./chatWithLLM.sh --debug -m "openai:gpt-4" "Test message"
```

### Verbose Mode

Use `-v` for detailed information including token usage:

```bash
./chatWithLLM.sh -v -m "anthropic:claude-3-opus" "Explain quantum computing"
```

## 📋 Requirements

### System Requirements
- **Operating System**: Unix-like (Linux, macOS, WSL)
- **Shell**: Bash 4.0+
- **Commands**: `curl`, `sed`, `grep` (standard on most systems)

### API Requirements
- Valid API keys for desired providers
- Internet connection for API calls
- Sufficient API credits/quota

### Installation Check
```bash
# Verify dependencies
command -v curl && echo "✓ curl found"
command -v sed && echo "✓ sed found" 
command -v grep && echo "✓ grep found"
command -v bash && echo "✓ bash found"
```

## 🤝 Contributing

This script is designed to be minimal and dependency-free. When contributing:

1. **Maintain Compatibility**: Keep the minimal dependency philosophy
2. **Test Thoroughly**: Test with multiple providers and file types
3. **Document Changes**: Update README and inline documentation
4. **Follow Style**: Maintain the existing bash coding style

## 📄 License

This script is provided as-is for educational and practical use. Ensure compliance with each LLM provider's terms of service and API usage policies.

## 🔗 Related Links

- [OpenAI API Documentation](https://platform.openai.com/docs)
- [Anthropic API Documentation](https://docs.anthropic.com)
- [Google AI API Documentation](https://ai.google.dev/docs)
- [Mistral AI API Documentation](https://docs.mistral.ai)
- [DeepSeek API Documentation](https://platform.deepseek.com/api-docs)

---

**Happy chatting with LLMs! 🎉**
