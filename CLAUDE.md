# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an OpenAI-compatible API gateway for Claude Code CLI. It wraps the Claude Code CLI and exposes its functionality through a FastAPI server with OpenAI-compatible endpoints, enabling integration with tools like Cursor, Cline, Roo Code, and Open WebUI.

## Core Architecture

### Request Flow
1. Client sends OpenAI-compatible request to `/v1/chat/completions`
2. FastAPI endpoint validates and parses the request
3. `ClaudeManager` spawns a Claude Code CLI process with the prompt
4. Claude Code CLI runs to completion and outputs stream-json format
5. Output is parsed and converted to OpenAI-compatible format
6. Response is returned as streaming SSE or non-streaming JSON

### Key Components

**ClaudeProcess (claude_manager.py:18-228)**
- Manages a single Claude Code CLI process
- Spawns process with `--output-format stream-json --dangerously-skip-permissions`
- Runs from `src/` directory to use existing Claude Code authentication
- Process runs to completion (not interactive) and all output is captured at once
- Output is parsed line-by-line as JSON messages and queued

**ClaudeManager (claude_manager.py:230-343)**
- Creates and manages multiple Claude Code processes
- Enforces concurrent session limits
- Does NOT store completed processes to avoid "max sessions" errors
- Each request creates a fresh process

**Chat Endpoint (api/chat.py:30-302)**
- Handles `/v1/chat/completions` requests
- Extracts user prompt from last user message
- Creates session and project directory
- Spawns Claude process and handles streaming/non-streaming responses
- Updates session manager with token usage

**Streaming (utils/streaming.py)**
- `OpenAIStreamConverter` converts Claude's stream-json output to OpenAI SSE format
- Looks for `{"type":"assistant","message":{"content":[{"type":"text","text":"..."}]}}` messages
- Extracts text content and emits as SSE chunks
- Sends `data: [DONE]` to complete stream

**Response Creation (utils/streaming.py:331-431)**
- For non-streaming: collects all Claude messages and extracts assistant content
- Handles both array format `[{"type":"text","text":"..."}]` and string format
- Always ensures content is non-empty with fallback messages
- Returns OpenAI-compatible response with basic usage stats

### Critical Implementation Details

1. **Claude CLI Invocation**: Always use exact flags `--output-format stream-json --verbose --dangerously-skip-permissions` and run from the `src/` directory where Claude Code is authenticated

2. **Process Lifecycle**: Claude Code CLI completes immediately and is not interactive. All output is captured at once via `communicate()`. Don't store processes after completion.

3. **Session IDs**: Claude Code generates its own session ID in the first message. Extract and use this ID instead of the generated one.

4. **Output Parsing**: Parse each line as JSON. Look for `type` field to identify message types (assistant, result, error, etc.)

5. **Content Extraction**: Assistant messages have nested structure: `message.content[]` where each item has `type:"text"` and `text` field

6. **Authentication**: Uses existing Claude Code authentication in working directory. No API key configuration in code.

## Common Commands

### Development
```bash
make install          # Install dependencies
make start            # Start dev server with reload
make start-prod       # Start production server
make test             # Run pytest tests
make test-real        # Run end-to-end curl tests
make clean            # Clean Python cache
```

### Testing Individual Components
```bash
# Test Claude Code CLI directly
claude -p "hello" --output-format stream-json --dangerously-skip-permissions

# Test API endpoint
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3-5-haiku-20241022","messages":[{"role":"user","content":"hello"}]}'

# Test with streaming
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-3-5-haiku-20241022","messages":[{"role":"user","content":"hello"}],"stream":true}'
```

### Port Management
```bash
make kill PORT=8000   # Kill process on specific port
```

## Supported Claude Models

- `claude-opus-4-20250514` - Claude Opus 4 (Most powerful)
- `claude-sonnet-4-20250514` - Claude Sonnet 4 (Latest Sonnet)
- `claude-3-7-sonnet-20250219` - Claude Sonnet 3.7 (Advanced)
- `claude-3-5-haiku-20241022` - Claude Haiku 3.5 (Fast, default)

Models are mapped in `models/claude.py` and validated before use.

## Configuration

Key settings in `core/config.py`:
- `claude_binary_path`: Auto-detected from PATH or npm global install
- `project_root`: `/tmp/claude_projects` - workspace for Claude processes
- `default_model`: `claude-3-5-haiku-20241022`
- `max_concurrent_sessions`: 10
- `streaming_timeout_seconds`: 300

## Limitations

- Claude Code has ~25k token input limit (less than normal API)
- Context auto-compacts beyond 100k
- Runs in bypass mode to avoid tool permission prompts
- Linux/Mac only (use WSL on Windows)
- Claude Code must be authenticated in the current directory before starting API

## Docker Deployment

Uses Ubuntu 22.04 base with Node.js 18+ for Claude Code CLI. Runs as non-root `claudeuser`. Two authentication modes:

1. **API Key**: Set `ANTHROPIC_API_KEY` env var
2. **Claude Max**: Set `USE_CLAUDE_MAX=true` and authenticate interactively via `docker exec -it claude-code-api claude`

## OpenAI Compatibility

Implements subset of OpenAI Chat Completions API:
- POST `/v1/chat/completions` - Create completion (streaming and non-streaming)
- GET `/v1/models` - List available models
- GET `/health` - Health check

Extension fields:
- `project_id`: Claude Code project context
- `session_id`: Continue existing conversation

## Debugging Tips

- Check logs for "DEBUG: Claude stderr" and "DEBUG: Claude stdout" messages
- Use `/v1/chat/completions/debug` endpoint to test request validation
- Verify Claude Code works: `claude --version` and `claude -p "test" --output-format stream-json`
- Ensure Claude Code is authenticated: run `claude` in the project directory first
- Check that `src/` directory exists and is accessible
