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
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18+ (required for Claude Code)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    node --version && npm --version

# Install Claude Code CLI globally as root (before switching to non-root user)
RUN npm install -g @anthropic-ai/claude-code && \
    claude --version

# Create non-root user for running Claude Code
RUN useradd -m -s /bin/bash claudeuser && \
    echo "claudeuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to non-root user
USER claudeuser
WORKDIR /home/claudeuser

# Set up working directory
WORKDIR /home/claudeuser/app

# Clone and install claude-code-api
RUN git clone https://github.com/codingworkflow/claude-code-api.git . && \
    pip3 install --user -e .

# Add user's local bin to PATH
ENV PATH="/home/claudeuser/.local/bin:${PATH}"

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