# Woqu - Intelligent Command Assistant

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A command correction tool inspired by [`thefuck`](https://github.com/nvbn/thefuck), focusing on providing AI-powered suggestions through shell integration. Currently experimental and optimized for macOS environments.

[![asciinema CLI
demo](https://asciinema.org/a/zAYgjn7F99Rl13WvMMzBYgrDr.svg)](https://asciinema.org/a/zAYgjn7F99Rl13WvMMzBYgrDr?autoplay=1)


## Features

- 🍎 **macOS First**: Primary support for macOS 12+
- 🤖 **AI Integration**: DeepSeek and other OpenAI compatible providers
- ⚡ **Swift Performance**: Built with Swift 6.0
- ⚠️ **Experimental**: Core functionality stable but under active development

## Installation

```bash
# Clone & Build
git clone https://github.com/ddrccw/woqu.git
cd woqu
swift build -c release

# Install to PATH
install .build/release/woqu /usr/local/bin/
```

## Shell Integration

For bash users, add this to your `~/.bashrc` or `~/.bash_profile`:

```bash
eval "$(command woqu alias)"
```

Then either:
```bash
source ~/.bashrc  # or source ~/.bash_profile
```
or restart your terminal session.

## Configuration

Create `~/.config/woqu/settings.yml`:

```yaml
# Required API credentials
defaultProvider: deepseek
providers:
  deepseek:
    apiKey: "redacted"
    apiUrl: "https://api.deepseek.com/chat/completions"
    model: "deepseek-chat"
    temperature: 0.7
  siliconflow:
    apiKey: "redacted"
    apiUrl: "https://api.siliconflow.cn/v1/chat/completions"
    model: "deepseek-ai/DeepSeek-V3"
    temperature: 0.7
```

## TODO

- [x] bash support ✔️
- [x] fish support ✔️
- [ ] tcsh support
- [ ] Cross-platform support (Linux/Windows WSL)
- [ ] `woqu config` interactive configuration command
- [ ] Additional AI providers (Anthropic, Gemini, Azure OpenAI, etc.)
- [ ] Homebrew/Linuxbrew packaging

## License

This code repository is licensed under [ the MIT License ](https://opensource.org/licenses/MIT).
