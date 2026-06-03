#!/usr/bin/env node
/**
 * Quick connectivity test for the Stitch MCP bridge.
 * Run: node src/test.js
 */

import { StitchClient } from "./stitch-client.js";

const API_KEY =
  process.env.STITCH_API_KEY ||
  "YOUR_STITCH_API_KEY";

async function main() {
  console.log("🔌 Testing connection to Google Stitch MCP...\n");

  const client = new StitchClient(API_KEY);

  // 1. Introspect available tools
  try {
    console.log("📋 Fetching tool list from Stitch MCP...");
    const tools = await client.listTools();
    if (tools.length === 0) {
      console.log("   ⚠️  No tools returned (API may use a different method)");
    } else {
      console.log(`   ✅ Found ${tools.length} tools:`);
      tools.forEach((t) => console.log(`      • ${t.name}: ${t.description ?? ""}`));
    }
  } catch (err) {
    console.error("   ❌ Tool list error:", err.message);
  }

  console.log("");

  // 2. List projects
  try {
    console.log("📁 Listing Stitch projects...");
    const projects = await client.call("list_projects", {});
    console.log("   ✅ Response:", JSON.stringify(projects, null, 2));
  } catch (err) {
    console.error("   ❌ list_projects error:", err.message);
  }

  console.log("\n✅ Test complete.");
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
