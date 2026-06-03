#!/usr/bin/env node

/**
 * Google Stitch MCP Bridge Server
 * ─────────────────────────────────
 * A local stdio MCP server that forwards all tool calls to the
 * Google Stitch remote MCP endpoint (https://stitch.googleapis.com/mcp).
 *
 * Tools exposed:
 *   • list_projects           – list all Stitch projects
 *   • get_project             – get a project by ID
 *   • create_project          – create a new project
 *   • list_screens            – list screens inside a project
 *   • get_screen              – get a screen by ID
 *   • fetch_screen_code       – download HTML/CSS/React code for a screen
 *   • fetch_screen_image      – download a high-res screenshot of a screen
 *   • generate_screen_from_text – generate a new UI screen from a prompt
 *   • extract_design_context  – extract design DNA (fonts, colors, layout)
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { StitchClient } from "./stitch-client.js";

// ─── Bootstrap ───────────────────────────────────────────────────────────────

const API_KEY =
  process.env.STITCH_API_KEY ||
  "YOUR_STITCH_API_KEY";

const client = new StitchClient(API_KEY);

const server = new McpServer({
  name: "google-stitch-bridge",
  version: "1.0.0",
  description:
    "Bridge server that exposes Google Stitch design tools via MCP stdio transport",
});

// ─── Tool: list_projects ─────────────────────────────────────────────────────

server.tool(
  "list_projects",
  "List all available Google Stitch projects in your account",
  {},
  async () => {
    const result = await client.call("list_projects", {});
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);

// ─── Tool: get_project ───────────────────────────────────────────────────────

server.tool(
  "get_project",
  "Get details and metadata for a specific Stitch project",
  {
    project_id: z.string().describe("The unique ID of the Stitch project"),
  },
  async ({ project_id }) => {
    const result = await client.call("get_project", { project_id });
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);

// ─── Tool: create_project ────────────────────────────────────────────────────

server.tool(
  "create_project",
  "Create a new Stitch project / workspace",
  {
    name: z.string().describe("Display name for the new project"),
    description: z
      .string()
      .optional()
      .describe("Optional description of the project"),
  },
  async ({ name, description }) => {
    const result = await client.call("create_project", { name, description });
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);

// ─── Tool: list_screens ──────────────────────────────────────────────────────

server.tool(
  "list_screens",
  "List all screens / pages inside a Stitch project",
  {
    project_id: z.string().describe("The project whose screens to list"),
  },
  async ({ project_id }) => {
    const result = await client.call("list_screens", { project_id });
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);

// ─── Tool: get_screen ────────────────────────────────────────────────────────

server.tool(
  "get_screen",
  "Get metadata and details for a specific screen in a Stitch project",
  {
    project_id: z.string().describe("Project that contains the screen"),
    screen_id: z.string().describe("The unique ID of the screen"),
  },
  async ({ project_id, screen_id }) => {
    const result = await client.call("get_screen", { project_id, screen_id });
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);

// ─── Tool: fetch_screen_code ─────────────────────────────────────────────────

server.tool(
  "fetch_screen_code",
  "Download the frontend code (HTML, CSS, or React) for a Stitch screen",
  {
    project_id: z.string().describe("Project that contains the screen"),
    screen_id: z.string().describe("Screen whose code to fetch"),
    format: z
      .enum(["html", "react", "css"])
      .optional()
      .default("html")
      .describe("Output format: html (default), react, or css"),
  },
  async ({ project_id, screen_id, format }) => {
    const result = await client.call("fetch_screen_code", {
      project_id,
      screen_id,
      format,
    });
    return {
      content: [
        {
          type: "text",
          text:
            typeof result === "string" ? result : JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);

// ─── Tool: fetch_screen_image ────────────────────────────────────────────────

server.tool(
  "fetch_screen_image",
  "Download a high-resolution screenshot of a Stitch screen",
  {
    project_id: z.string().describe("Project that contains the screen"),
    screen_id: z.string().describe("Screen to capture"),
  },
  async ({ project_id, screen_id }) => {
    const result = await client.call("fetch_screen_image", {
      project_id,
      screen_id,
    });
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);

// ─── Tool: generate_screen_from_text ─────────────────────────────────────────

server.tool(
  "generate_screen_from_text",
  "Generate a brand-new UI screen in a Stitch project from a text prompt",
  {
    project_id: z.string().describe("Project to add the new screen to"),
    prompt: z
      .string()
      .describe(
        "Detailed description of the UI screen you want to generate (e.g. 'A modern login page with a gradient background')"
      ),
    screen_name: z
      .string()
      .optional()
      .describe("Optional name for the new screen"),
  },
  async ({ project_id, prompt, screen_name }) => {
    const result = await client.call("generate_screen_from_text", {
      project_id,
      prompt,
      screen_name,
    });
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);

// ─── Tool: extract_design_context ────────────────────────────────────────────

server.tool(
  "extract_design_context",
  "Extract the Design DNA from a screen: color palette, typography, spacing, and layout patterns",
  {
    project_id: z.string().describe("Project that contains the screen"),
    screen_id: z.string().describe("Screen to analyse for design context"),
  },
  async ({ project_id, screen_id }) => {
    const result = await client.call("extract_design_context", {
      project_id,
      screen_id,
    });
    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);

// ─── Start ────────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();

await server.connect(transport);

console.error("[Stitch MCP] Server running via stdio transport ✓");
