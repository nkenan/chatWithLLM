# chatWithLLM.sh - Universal LLM CLI Interface

A powerful, dependency-light bash script for interacting with multiple Large Language Model providers from the command line. No need for Python, Node.js, or heavy dependencies - just bash and standard Unix tools.

## 🚀 Features

- **Multi-Provider Support**: OpenAI, Anthropic (Claude), Google (Gemini), Mistral, DeepSeek, and Meta (Llama)
- **Zero Dependencies**: Only requires `curl`, `sed`, `grep`, and `od` (standard on most Unix systems)
- **File Processing**: Support for text files, images, and PDFs
- **Multiple Input Methods**: Direct prompts, file input, or stdin
- **Flexible Output**: Plain text, Markdown, JSON, or HTML formats
- **Configuration Management**: Centralized API key and model management
- **Pure Shell Implementation**: Even includes a pure bash base64 encoder for image processing

## 📋 Requirements

- Bash 4.0+
- `curl` (for HTTP requests)
- `sed` and `grep` (for text processing)
- `od` (for binary file handling)
- Optional: `base64` (fallback included), `pdftotext` (for PDF support)

## 🛠️ Installation

1. Download the script:
```bash
wget https://raw.githubusercontent.com/nkenan/chatWithLLM/main/chatWithLLM.sh
# or
curl -O https://raw.githubusercontent.com/nkenan/chatWithLLM/main/chatWithLLM.sh
```

2. Make it executable:
```bash
chmod +x chatWithLLM.sh
```

3. Initialize configuration:
```bash
./chatWithLLM.sh --init
```

4. Edit the configuration file and add your API keys:
```bash
nano .chatWithLLM
```

## ⚙️ Configuration

The `--init` command creates a `.chatWithLLM` configuration file in your current directory:

```bash
# chatWithLLM Configuration File
# Default model (provider:model format)
DEFAULT_MODEL=anthropic:claude-3-opus-20240229

# API Keys - Add your keys below
OPENAI_API_KEY=your_openai_key_here
ANTHROPIC_API_KEY=your_anthropic_key_here
GOOGLE_API_KEY=your_google_key_here
MISTRAL_API_KEY=your_mistral_key_here
DEEPSEEK_API_KEY=your_deepseek_key_here
META_API_KEY=your_meta_key_here
```

## 🎯 Usage

### Basic Usage

```bash
# Use default model from config
./chatWithLLM.sh "Explain quantum computing"

# Specify model explicitly
./chatWithLLM.sh -m "openai:gpt-4" "Write a Python function to sort a list"
./chatWithLLM.sh -m "anthropic:claude-3-opus" "Analyze this business strategy"
./chatWithLLM.sh -m "google:gemini-pro" "Translate: Hello, how are you?"
```

### File Input

```bash
# Process text files
./chatWithLLM.sh -f "document.txt" "Summarize this document"

# Process multiple files
./chatWithLLM.sh -f "code.py,readme.md" "Review this code and documentation"

# Process images (vision models)
./chatWithLLM.sh -m "openai:gpt-4-vision-preview" -f "chart.png" "Analyze this chart"

# Process PDFs (requires pdftotext)
./chatWithLLM.sh -f "report.pdf" "Extract key insights from this report"
```

### Different Input Methods

```bash
# Read prompt from file
./chatWithLLM.sh --file prompt.txt -m "anthropic:claude-3-opus"

# Read from stdin
echo "What is the capital of France?" | ./chatWithLLM.sh

# Interactive mode (if no prompt provided and stdin available)
./chatWithLLM.sh -m "openai:gpt-4"
# Type your prompt and press Ctrl+D
```

### Output Formats

```bash
# Markdown output (default)
./chatWithLLM.sh "Create a project plan" -F markdown

# Plain text
./chatWithLLM.sh "Simple answer please" -F plain

# JSON output
./chatWithLLM.sh "Analyze sentiment" -F json

# HTML output
./chatWithLLM.sh "Create a report" -F html
```

### Save Output

```bash
# Auto-generate filename
./chatWithLLM.sh --save "Write a technical document" -F html

# Specify output file
./chatWithLLM.sh -o "analysis.md" "Analyze market trends"
```

### Advanced Options

```bash
# Adjust creativity/randomness
./chatWithLLM.sh -t 0.9 "Write a creative story"  # Higher temperature = more creative
./chatWithLLM.sh -t 0.1 "Solve this math problem"  # Lower temperature = more focused

# Limit response length
./chatWithLLM.sh -T 500 "Brief summary please"  # Maximum 500 tokens

# Verbose mode (show token usage)
./chatWithLLM.sh -v "Explain machine learning"

# Debug mode (show raw API response)
./chatWithLLM.sh --debug "Test response"
```

## 🌐 Supported Providers and Models

### OpenAI
```bash
-m "openai:gpt-4"
-m "openai:gpt-4-turbo"
-m "openai:gpt-3.5-turbo"
-m "openai:gpt-4-vision-preview"  # For image analysis
```

### Anthropic (Claude)
```bash
-m "anthropic:claude-3-opus-20240229"
-m "anthropic:claude-3-sonnet-20240229"
-m "anthropic:claude-3-haiku-20240307"
```

### Google (Gemini)
```bash
-m "google:gemini-pro"
-m "google:gemini-pro-vision"
```

### Mistral
```bash
-m "mistral:mistral-large-latest"
-m "mistral:mistral-medium-latest"
-m "mistral:mistral-small-latest"
```

### DeepSeek
```bash
-m "deepseek:deepseek-chat"
-m "deepseek:deepseek-coder"
```

### Meta (Llama)
```bash
-m "meta:llama-2-70b-chat"
-m "meta:llama-2-13b-chat"
```

## 📝 Command Line Options

| Option | Description | Example |
|--------|-------------|---------|
| `-m, --model` | Model in provider:model format | `-m "openai:gpt-4"` |
| `-f, --files` | Input files (comma-separated) | `-f "doc.txt,img.jpg"` |
| `-o, --output` | Output file | `-o "response.md"` |
| `-F, --format` | Output format (markdown/plain/json/html) | `-F json` |
| `-t, --temperature` | Temperature (0.0-2.0, default: 0.7) | `-t 0.9` |
| `-T, --max-tokens` | Maximum tokens (default: 4096) | `-T 1000` |
| `--file` | Read prompt from file | `--file prompt.txt` |
| `--stdin` | Read prompt from stdin | `--stdin` |
| `--save` | Save output to auto-generated file | `--save` |
| `--init` | Initialize configuration file | `--init` |
| `-v, --verbose` | Show token usage information | `-v` |
| `--debug` | Show raw API responses | `--debug` |
| `-h, --help` | Show help message | `-h` |

## 🔧 Examples

### Code Analysis
```bash
./chatWithLLM.sh -m "anthropic:claude-3-opus" -f "script.py" \
  "Review this code for bugs and suggest improvements"
```

### Document Processing
```bash
./chatWithLLM.sh -m "openai:gpt-4" -f "research.pdf,data.csv" \
  "Create an executive summary of this research and data"
```

### Creative Writing
```bash
./chatWithLLM.sh -m "anthropic:claude-3-opus" -t 0.9 --save -F markdown \
  "Write a short science fiction story about AI consciousness"
```

### Data Analysis
```bash
./chatWithLLM.sh -m "openai:gpt-4" -f "sales_data.csv" -F json \
  "Analyze sales trends and provide insights"
```

### Image Analysis
```bash
./chatWithLLM.sh -m "openai:gpt-4-vision-preview" -f "screenshot.png" \
  "What does this user interface screenshot show?"
```

### Batch Processing
```bash
# Process multiple prompts from files
for prompt in prompts/*.txt; do
    ./chatWithLLM.sh --file "$prompt" -m "anthropic:claude-3-opus" \
      --save -F markdown
done
```

## 🛡️ Error Handling

The script includes comprehensive error handling:

- **Missing Dependencies**: Checks for required commands
- **Invalid API Keys**: Clear error messages for authentication issues
- **File Not Found**: Validates input files before processing
- **Network Issues**: Handles HTTP errors gracefully
- **Invalid JSON**: Robust parsing without external JSON libraries

## 🏗️ Architecture

### Pure Shell Implementation
- No external JSON parsers (jq, awk) required
- Custom base64 encoder for image processing
- Provider-agnostic request building
- Modular response parsing

### Key Components
- **Configuration Management**: API key and default model handling
- **Request Building**: Provider-specific JSON formatting
- **Response Parsing**: Extract content and usage from different API formats
- **File Processing**: Handle text, images, and PDFs
- **Output Formatting**: Multiple output formats with metadata

## 🤝 Contributing

Contributions are welcome! Here are some areas for improvement:

1. **Additional Providers**: Add support for new LLM providers
2. **Enhanced File Support**: More file types and processing options
3. **Streaming Responses**: Add support for streaming API responses
4. **Configuration Improvements**: Environment variable support
5. **Error Recovery**: Retry logic and fallback mechanisms

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Troubleshooting

### Common Issues

**"Missing required dependencies"**
```bash
# Install missing tools (Ubuntu/Debian)
sudo apt-get install curl grep sed coreutils

# macOS (should be pre-installed)
# All required tools come with macOS
```

**"No API key found for provider"**
```bash
# Edit configuration file
nano .chatWithLLM

# Add your API key
OPENAI_API_KEY=your_actual_key_here
```

**"File not found" errors**
```bash
# Check file paths are correct
ls -la yourfile.txt

# Use absolute paths if needed
./chatWithLLM.sh -f "/full/path/to/file.txt" "Your prompt"
```

**PDF processing fails**
```bash
# Install pdftotext (Ubuntu/Debian)
sudo apt-get install poppler-utils

# macOS
brew install poppler
```

### Debug Mode

Use `--debug` to see raw API responses and diagnose issues:

```bash
./chatWithLLM.sh --debug -m "openai:gpt-4" "Test message"
```

## 🔗 API Documentation Links

- [OpenAI API](https://platform.openai.com/docs/api-reference)
- [Anthropic API](https://docs.anthropic.com/claude/reference)
- [Google Gemini API](https://ai.google.dev/docs)
- [Mistral API](https://docs.mistral.ai/api/)
- [DeepSeek API](https://platform.deepseek.com/api-docs/)

---

**Made with ❤️ for the command line enthusiasts who prefer bash over bloat.**
