# Use Ubuntu as base for better Claude Code support
FROM ubuntu:22.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies including Node.js
RUN apt-get update && apt-get install -y \
    curl \
    git \
    python3.10 \
    python3-pip \
    ca-certificates \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18+ (required for Claude Code)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    node --version && npm --version

# Install Claude Code CLI via npm (more Docker-friendly than native installer)
RUN npm install -g @anthropic-ai/claude-code && \
    claude --version

# Set up working directory
WORKDIR /app

# Clone and install claude-code-api
RUN git clone https://github.com/codingworkflow/claude-code-api.git . && \
    pip3 install -e .

# Expose API port
EXPOSE 8000

# Environment variables (set these at runtime)
ENV ANTHROPIC_API_KEY=""
ENV HOST=0.0.0.0
ENV PORT=8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start the API server
CMD ["python3", "-m", "claude_code_api.main"]