# chatWithLLM 🤖 - A universal LLM CLI Interface

A powerful, minimal bash script for interacting with multiple Large Language Model providers through a unified command-line interface. No external dependencies beyond standard Unix tools - just bash, curl, sed, and grep.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Bash-4.0%2B-green.svg)](https://www.gnu.org/software/bash/)
[![Dependencies](https://img.shields.io/badge/Dependencies-curl%20%7C%20sed%20%7C%20grep-blue.svg)](#dependencies)

## 🚀 Features

- **Multi-Provider Support**: OpenAI, Anthropic (Claude), Google (Gemini), Mistral, DeepSeek, Meta (Llama)
- **Minimal Dependencies**: Only requires `curl`, `sed`, and `grep` - no Python, Node.js, or heavy frameworks
- **Flexible Input**: Accept prompts from command line, files, or stdin
- **Multiple Output Formats**: Plain text, Markdown, JSON, HTML
- **File Processing**: Analyze text files with your prompts
- **Configuration Management**: Persistent API key storage and default model settings
- **Token Usage Tracking**: Monitor your API consumption
- **Cross-Platform**: Works on Linux, macOS, and Windows (WSL)

## 📦 Installation

### Quick Start
```bash
# Download the script
curl -O https://raw.githubusercontent.com/nkenan/chatWithLLM/main/chatWithLLM.sh

# Make it executable
chmod +x chatWithLLM.sh

# Initialize configuration
./chatWithLLM.sh --init

# Edit config file to add your API keys
nano .chatWithLLM
```

### Global Installation (optional)
```bash
# Move to a directory in your PATH
sudo cp chatWithLLM.sh /usr/local/bin/chatWithLLM
sudo chmod +x /usr/local/bin/chatWithLLM

# Now you can use it from anywhere
chatWithLLM --help
```

## ⚙️ Configuration

Run the initialization command to create your config file:

```bash
./chatWithLLM.sh --init
```

This creates a `.chatWithLLM` file in your current directory. Edit it to add your API keys:

```bash
# chatWithLLM Configuration File
# Default model (provider:model format)
DEFAULT_MODEL=anthropic:claude-3-opus-20240229

# API Keys - Add your keys below
# OpenAI
OPENAI_API_KEY=sk-your-openai-key-here

# Anthropic (Claude)
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key-here

# Google (Gemini)
GOOGLE_API_KEY=your-google-api-key-here

# Mistral
MISTRAL_API_KEY=your-mistral-key-here

# DeepSeek
DEEPSEEK_API_KEY=your-deepseek-key-here

# Meta (Llama) - if using cloud API
META_API_KEY=your-meta-key-here
```

## 🎯 Basic Usage

### Simple Queries

```bash
# Use your default model (from config)
./chatWithLLM.sh "Explain quantum computing in simple terms"

# Specify a model explicitly
./chatWithLLM.sh -m "openai:gpt-4" "Write a haiku about coding"

# Use Claude for creative writing
./chatWithLLM.sh -m "anthropic:claude-3-opus" "Write a short story about a time-traveling programmer"

# Use Gemini for analysis
./chatWithLLM.sh -m "google:gemini-pro" "What are the pros and cons of renewable energy?"
```

### Model Format

Always use the `provider:model` format:

- **OpenAI**: `openai:gpt-4`, `openai:gpt-3.5-turbo`
- **Anthropic**: `anthropic:claude-3-opus-20240229`, `anthropic:claude-3-sonnet-20240229`
- **Google**: `google:gemini-pro`, `google:gemini-pro-vision`
- **Mistral**: `mistral:mistral-large-latest`, `mistral:mistral-medium`
- **DeepSeek**: `deepseek:deepseek-chat`, `deepseek:deepseek-coder`

## 📁 Working with Files

### Analyze Text Files

```bash
# Analyze a single file
./chatWithLLM.sh -f "document.txt" "Summarize this document"

# Analyze multiple files
./chatWithLLM.sh -f "readme.md,changelog.txt,todo.md" "What are the main themes across these files?"

# Code review
./chatWithLLM.sh -f "main.py,utils.py" "Review this Python code for bugs and improvements"

# Document analysis
./chatWithLLM.sh -f "report.txt" -m "anthropic:claude-3-opus" "Extract key insights and create an executive summary"
```

### Reading Prompts from Files

```bash
# Read prompt from a file
echo "Explain machine learning algorithms" > prompt.txt
./chatWithLLM.sh --file prompt.txt -m "openai:gpt-4"

# Combine file prompt with file analysis
./chatWithLLM.sh --file analysis_prompt.txt -f "data.csv,report.txt"
```

## 🔄 Input Methods

### Command Line
```bash
./chatWithLLM.sh "Direct prompt here"
```

### From File
```bash
./chatWithLLM.sh --file prompt.txt
```

### From Stdin (Pipe)
```bash
echo "Translate to French: Hello, world!" | ./chatWithLLM.sh -m "google:gemini-pro"

# From clipboard (macOS)
pbpaste | ./chatWithLLM.sh "Improve this text:"

# From command output
git log --oneline -10 | ./chatWithLLM.sh "Summarize these git commits"

# From curl
curl -s https://api.github.com/users/octocat | ./chatWithLLM.sh "Explain this JSON data"
```

## 📄 Output Formats

### Markdown (Default)
```bash
./chatWithLLM.sh -F markdown "Create a project roadmap"
```

### Plain Text
```bash
./chatWithLLM.sh -F plain "Just give me the facts about photosynthesis"
```

### JSON
```bash
./chatWithLLM.sh -F json "List 5 programming languages" > response.json
```

### HTML
```bash
./chatWithLLM.sh -F html --save "Create a technical explanation of REST APIs"
```

## 💾 Saving Output

### Auto-generated Filenames
```bash
# Saves to llm_response_YYYYMMDD_HHMMSS.md
./chatWithLLM.sh --save "Write documentation for a REST API"

# Saves to llm_response_YYYYMMDD_HHMMSS.html
./chatWithLLM.sh -F html --save "Create a marketing page concept"
```

### Custom Filenames
```bash
# Save to specific file
./chatWithLLM.sh -o "api_docs.md" "Document our user authentication API"

# Save as HTML report
./chatWithLLM.sh -F html -o "analysis_report.html" -f "data.txt" "Analyze this dataset"
```

## 🎛️ Advanced Options

### Temperature and Token Control

```bash
# High creativity (temperature 1.2)
./chatWithLLM.sh -t 1.2 "Write a creative story about AI"

# Focused/deterministic (temperature 0.1)
./chatWithLLM.sh -t 0.1 "Calculate compound interest formula"

# Limit response length
./chatWithLLM.sh -T 100 "Briefly explain blockchain"

# Long-form content
./chatWithLLM.sh -T 8192 "Write a comprehensive guide to Docker"
```

### Debugging and Verbose Output

```bash
# See token usage
./chatWithLLM.sh -v "Explain neural networks"

# Debug API responses
./chatWithLLM.sh --debug "Test API connection"
```

## 🔧 Real-World Use Cases

### Code Review and Development

```bash
# Code review
./chatWithLLM.sh -f "src/main.js" -m "anthropic:claude-3-opus" "Review this JavaScript code for security issues and best practices"

# Generate documentation
./chatWithLLM.sh -f "api.py" "Generate comprehensive API documentation for this Python file"

# Debug help
git diff | ./chatWithLLM.sh "Explain what this git diff does and if there are any potential issues"

# Generate tests
./chatWithLLM.sh -f "calculator.py" "Generate unit tests for this Python class"
```

### Content Creation

```bash
# Blog post generation
./chatWithLLM.sh -F markdown --save "Write a technical blog post about microservices architecture"

# Social media content
./chatWithLLM.sh -T 280 "Create a Twitter thread about sustainable web development (5 tweets max)"

# Email templates
./chatWithLLM.sh -o "email_template.html" -F html "Create a professional email template for customer onboarding"
```

### Data Analysis and Research

```bash
# Analyze log files
./chatWithLLM.sh -f "server.log" "Identify potential security issues in this log file"

# Research assistance
./chatWithLLM.sh "Compare the pros and cons of GraphQL vs REST APIs for mobile applications"

# Report generation
./chatWithLLM.sh -f "survey_data.txt" -F html -o "survey_report.html" "Create an executive summary report from this survey data"
```

### DevOps and System Administration

```bash
# Dockerfile optimization
./chatWithLLM.sh -f "Dockerfile" "Optimize this Dockerfile for production use"

# Configuration analysis
./chatWithLLM.sh -f "nginx.conf" "Review this Nginx configuration for security and performance"

# Script generation
./chatWithLLM.sh "Generate a bash script to backup MySQL databases with rotation"
```

### Learning and Education

```bash
# Concept explanation
./chatWithLLM.sh -m "anthropic:claude-3-opus" "Explain dependency injection in software development with practical examples"

# Code explanation
./chatWithLLM.sh -f "complex_algorithm.py" "Explain this algorithm step by step for a beginner programmer"

# Interactive learning
echo "What is functional programming?" | ./chatWithLLM.sh -m "openai:gpt-4" --save
```

## 🔧 Integration Examples

### Git Hooks

Create a commit message generator:

```bash
#!/bin/bash
# .git/hooks/prepare-commit-msg
git diff --cached | ./chatWithLLM.sh -T 50 "Generate a concise git commit message for these changes" > $1
```

### CI/CD Pipeline

```bash
# In your GitHub Actions or GitLab CI
- name: AI Code Review
  run: |
    git diff HEAD~1 | ./chatWithLLM.sh -m "anthropic:claude-3-opus" "Review this code diff for potential issues" > review.md
```

### Alfred Workflow (macOS)

```bash
# Alfred script filter
echo "$1" | ./chatWithLLM.sh -m "openai:gpt-4" -F plain
```

### Slack Bot Integration

```bash
#!/bin/bash
# slack-ai-bot.sh
MESSAGE="$1"
RESPONSE=$(echo "$MESSAGE" | ./chatWithLLM.sh -F plain)
curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"$RESPONSE\"}" \
    "$SLACK_WEBHOOK_URL"
```

## 🛠️ Troubleshooting

### Common Issues

**API Key Not Found**
```bash
Error: No API key found for provider: openai
```
Solution: Add your API key to the `.chatWithLLM` config file.

**Model Format Error**
```bash
Error: Model must be specified in provider:model format
```
Solution: Use the correct format, e.g., `openai:gpt-4` instead of just `gpt-4`.

**File Not Found**
```bash
Error: File not found: document.txt
```
Solution: Check file path and permissions.

### Debug Mode

Use debug mode to see raw API responses:

```bash
./chatWithLLM.sh --debug "test prompt"
```

### Verbose Mode

See token usage and timing information:

```bash
./chatWithLLM.sh -v "test prompt"
```

## 📋 Dependencies

The script requires only standard Unix utilities:

- **bash** (4.0+)
- **curl** - for HTTP requests
- **sed** - for text processing
- **grep** - for pattern matching

These are available on virtually all Unix-like systems (Linux, macOS, WSL).

## 🔐 Security Notes

- API keys are stored in plain text in the config file - ensure appropriate file permissions
- Use `chmod 600 .chatWithLLM` to restrict config file access
- Never commit your config file to version control
- Consider using environment variables for API keys in production environments

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

```bash
git clone https://github.com/nkenan/chatWithLLM.git
cd chatWithLLM
./chatWithLLM.sh --init
# Add your API keys to .chatWithLLM
./chatWithLLM.sh "Test message"
```

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Thanks to all the LLM providers for their APIs
- Inspired by the need for a simple, universal CLI interface for AI models
- Built with love for the command line interface community

---

**Happy AI chatting! 🚀**

For more examples and updates, visit the [GitHub repository](https://github.com/nkenan/chatWithLLM).
