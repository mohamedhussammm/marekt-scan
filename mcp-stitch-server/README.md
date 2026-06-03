# Google Stitch MCP Bridge Server

A local stdio MCP server that bridges **Google Stitch** — Google's AI-powered UI design tool — into any MCP-compatible AI client (Claude Desktop, Cursor, Gemini CLI, etc.).

---

## How It Works

```
Your AI Client (Claude / Cursor / etc.)
         │  stdio (MCP protocol)
         ▼
  mcp-stitch-server  (this project)
         │  HTTPS + X-Goog-Api-Key
         ▼
  https://stitch.googleapis.com/mcp
```

The local server receives MCP tool calls over **stdio**, forwards them to the Google Stitch remote MCP over **HTTPS**, and returns the results.

---

## Setup

### 1. Install dependencies

```bash
cd mcp-stitch-server
npm install
```

### 2. Test the connection

```bash
npm test
```

You should see your Stitch projects listed if the API key is valid.

### 3. Run the server

```bash
npm start
```

---

## Connecting to Your AI Client

### Claude Desktop

Add to `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "stitch": {
      "command": "node",
      "args": ["e:/Market Scan/mcp-stitch-server/src/index.js"],
      "env": {
        "STITCH_API_KEY": "YOUR_STITCH_API_KEY"
      }
    }
  }
}
```

### Cursor IDE

Add to `.cursor/mcp.json` in your project:

```json
{
  "mcpServers": {
    "stitch": {
      "command": "node",
      "args": ["e:/Market Scan/mcp-stitch-server/src/index.js"],
      "env": {
        "STITCH_API_KEY": "YOUR_STITCH_API_KEY"
      }
    }
  }
}
```

### Antigravity (this editor)

Add to your MCP config:

```json
{
  "mcpServers": {
    "stitch": {
      "command": "node",
      "args": ["e:/Market Scan/mcp-stitch-server/src/index.js"]
    }
  }
}
```

---

## Available Tools

| Tool | Description |
|------|-------------|
| `list_projects` | List all your Stitch projects |
| `get_project` | Get details for a specific project |
| `create_project` | Create a new project / workspace |
| `list_screens` | List all screens in a project |
| `get_screen` | Get metadata for a specific screen |
| `fetch_screen_code` | Download HTML / CSS / React code for a screen |
| `fetch_screen_image` | Get a high-res screenshot of a screen |
| `generate_screen_from_text` | Generate a new UI screen from a text prompt |
| `extract_design_context` | Extract Design DNA (colors, fonts, layout) |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `STITCH_API_KEY` | (hardcoded fallback) | Your Google Stitch API key |

> **Tip:** Use an `.env` file or set `STITCH_API_KEY` in your shell for production use instead of the hardcoded key.
