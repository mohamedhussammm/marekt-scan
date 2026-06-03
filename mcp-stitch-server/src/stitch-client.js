/**
 * StitchClient
 * ─────────────
 * Handles communication with the Google Stitch remote MCP HTTP endpoint.
 *
 * The Stitch MCP server uses JSON-RPC 2.0 over HTTP POST.
 * Reference: https://stitch.googleapis.com/mcp
 */

const STITCH_MCP_URL = "https://stitch.googleapis.com/mcp";

export class StitchClient {
  /**
   * @param {string} apiKey  – X-Goog-Api-Key value
   */
  constructor(apiKey) {
    this.apiKey = apiKey;
    this._requestId = 1;
  }

  /**
   * Call a Stitch MCP tool by name with given arguments.
   *
   * @param {string} toolName
   * @param {object} args
   * @returns {Promise<any>}
   */
  async call(toolName, args = {}) {
    const body = {
      jsonrpc: "2.0",
      id: this._requestId++,
      method: "tools/call",
      params: {
        name: toolName,
        arguments: args,
      },
    };

    let response;
    try {
      response = await fetch(STITCH_MCP_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": this.apiKey,
        },
        body: JSON.stringify(body),
      });
    } catch (err) {
      throw new Error(`[StitchClient] Network error calling ${toolName}: ${err.message}`);
    }

    if (!response.ok) {
      const text = await response.text().catch(() => "(no body)");
      throw new Error(
        `[StitchClient] HTTP ${response.status} from Stitch MCP for tool "${toolName}": ${text}`
      );
    }

    const json = await response.json();

    // Handle JSON-RPC error
    if (json.error) {
      throw new Error(
        `[StitchClient] JSON-RPC error for tool "${toolName}": ${JSON.stringify(json.error)}`
      );
    }

    // Extract content from MCP tool result
    const result = json.result;

    if (!result) return null;

    // MCP tool responses wrap content in a `content` array of typed blocks
    if (Array.isArray(result.content)) {
      // If there is a single text block, return the parsed value if JSON
      if (result.content.length === 1 && result.content[0].type === "text") {
        const text = result.content[0].text;
        try {
          return JSON.parse(text);
        } catch {
          return text;
        }
      }
      return result.content;
    }

    return result;
  }

  /**
   * List all tools that the Stitch MCP exposes (introspection).
   *
   * @returns {Promise<object[]>}
   */
  async listTools() {
    const body = {
      jsonrpc: "2.0",
      id: this._requestId++,
      method: "tools/list",
      params: {},
    };

    const response = await fetch(STITCH_MCP_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": this.apiKey,
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      throw new Error(`[StitchClient] HTTP ${response.status} on tools/list`);
    }

    const json = await response.json();
    return json?.result?.tools ?? [];
  }
}
