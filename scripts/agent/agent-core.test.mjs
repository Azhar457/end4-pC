#!/usr/bin/env node

import { executeTool, BUILTIN_TOOLS, buildAgentSystemPrompt } from "./agent-core.mjs";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

async function runTests() {
	console.log("🧪 Testing Built-in Agent Tools...");

	// 1. Test Tools Schema
	assert.ok(BUILTIN_TOOLS.length >= 6, "Must have at least 6 tools");
	assert.ok(BUILTIN_TOOLS.some(t => t.name === "bash"));
	assert.ok(BUILTIN_TOOLS.some(t => t.name === "file_read"));
	assert.ok(BUILTIN_TOOLS.some(t => t.name === "file_write"));
	assert.ok(BUILTIN_TOOLS.some(t => t.name === "hyprland_control"));
	assert.ok(BUILTIN_TOOLS.some(t => t.name === "web_search"));
	assert.ok(BUILTIN_TOOLS.some(t => t.name === "web_fetch"));
	console.log("  ✓ Tool schemas valid");

	// 2. Test Bash Tool
	const bashRes = await executeTool("bash", { command: "echo 'Agent Test OK 123'" });
	assert.match(bashRes, /Agent Test OK 123/);
	console.log("  ✓ Bash tool execution passed");

	// 3. Test File Write & Read Tool
	const testFilePath = path.join(os.tmpdir(), "agent_test_file.txt");
	const writeRes = await executeTool("file_write", { filePath: testFilePath, content: "Hello from Agent File Tool!" });
	assert.match(writeRes, /Successfully wrote/);

	const readRes = await executeTool("file_read", { filePath: testFilePath });
	assert.equal(readRes, "Hello from Agent File Tool!");
	await fs.unlink(testFilePath).catch(() => {});
	console.log("  ✓ File write and read tools passed");

	// 4. Test Hyprland Control Tool (query monitors or clients)
	const hyprRes = await executeTool("hyprland_control", { action: "query_monitors" });
	assert.ok(typeof hyprRes === "string");
	console.log("  ✓ Hyprland control tool query passed");

	// 5. Test Web Fetch Tool
	const webRes = await executeTool("web_fetch", { url: "https://example.com" });
	assert.match(webRes, /Example Domain/);
	console.log("  ✓ Web fetch tool passed");

	// 6. Test System Prompt Generator
	const prompt = buildAgentSystemPrompt();
	assert.match(prompt, /Hyprland/);
	assert.match(prompt, /<tool_call>/);
	console.log("  ✓ System prompt generator passed");

	console.log("\n🎉 ALL AGENT CORE TESTS PASSED (6/6)!\n");
}

runTests().catch((err) => {
	console.error("❌ Test failed:", err);
	process.exit(1);
});
