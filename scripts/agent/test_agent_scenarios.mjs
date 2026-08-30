#!/usr/bin/env node

/**
 * Comprehensive Automated Test Suite for end4-pC AI Agent
 *
 * Scenarios tested:
 * 1. Taskbar Configuration (Set autohide)
 * 2. Accent Color Theming (Update custom accent color)
 * 3. Background Widgets Management (Disable and Enable widgets)
 * 4. Interactive Approval Denial (Simulating clicking [X] deny button when tool asks approval)
 */

import { runAgentLoop, executeTool, buildAgentSystemPrompt } from "./agent-core.mjs";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const CONFIG_PATH = path.join(os.homedir(), ".config/illogical-impulse/config.json");

function assert(condition, message) {
	if (!condition) {
		console.error(`❌ ASSERTION FAILED: ${message}`);
		process.exit(1);
	}
	console.log(`  ✓ ${message}`);
}

async function runScenario1_TaskbarAutohide() {
	console.log("\n🧪 [Scenario 1] Testing Taskbar Autohide Configuration...");
	
	// Read current config backup
	const raw = fs.readFileSync(CONFIG_PATH, "utf-8");
	const cfg = JSON.parse(raw);
	const originalAutoHide = cfg.bar?.autoHide?.enable ?? false;

	const events = [];
	await runAgentLoop({
		prompt: "Tolong ubah setting taskbar/bar di config.json agar bar.autoHide.enable menjadi true",
		endpoint: "https://opencode.ai/zen/v1/chat/completions",
		model: "hy3-free",
		confirmTools: false,
		sendEvent: (e) => events.push(e)
	});

	const updated = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf-8"));
	assert(updated.bar?.autoHide?.enable === true, "config.json bar.autoHide.enable updated to true");

	// Restore original state
	if (typeof cfg.bar.autoHide === "object") {
		cfg.bar.autoHide.enable = originalAutoHide;
	} else {
		cfg.bar.autoHide = { enable: originalAutoHide };
	}
	fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 4));
	console.log("  ✓ Scenario 1 Completed Successfully.");
}

async function runScenario2_AccentColor() {
	console.log("\n🧪 [Scenario 2] Testing Accent Color Theming...");

	const raw = fs.readFileSync(CONFIG_PATH, "utf-8");
	const cfg = JSON.parse(raw);
	const originalColor = cfg.appearance?.palette?.accentColor ?? "";

	const events = [];
	await runAgentLoop({
		prompt: "Tolong ganti accent color menjadi #FF5722 di config.json",
		endpoint: "https://opencode.ai/zen/v1/chat/completions",
		model: "hy3-free",
		confirmTools: false,
		sendEvent: (e) => events.push(e)
	});

	const updated = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf-8"));
	assert(updated.appearance?.palette?.accentColor === "#FF5722", "appearance.palette.accentColor updated to #FF5722");

	// Restore
	cfg.appearance.palette.accentColor = originalColor;
	fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 4));
	console.log("  ✓ Scenario 2 Completed Successfully.");
}

async function runScenario3_WidgetManagement() {
	console.log("\n🧪 [Scenario 3] Testing Background Widgets Enable / Disable...");

	const raw = fs.readFileSync(CONFIG_PATH, "utf-8");
	const cfg = JSON.parse(raw);
	const originalWidgets = JSON.parse(JSON.stringify(cfg.background?.widgets ?? {}));

	// 1. Disable widgets
	await runAgentLoop({
		prompt: "Matikan widget calendar dan todo di background widgets config.json",
		endpoint: "https://opencode.ai/zen/v1/chat/completions",
		model: "hy3-free",
		confirmTools: false,
		sendEvent: () => {}
	});

	let updated = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf-8"));
	assert(updated.background?.widgets?.calendar?.enable === false, "calendar widget disabled");
	assert(updated.background?.widgets?.todo?.enable === false, "todo widget disabled");

	// 2. Enable widgets back
	await runAgentLoop({
		prompt: "Nyalakan kembali widget calendar dan todo di background widgets config.json",
		endpoint: "https://opencode.ai/zen/v1/chat/completions",
		model: "hy3-free",
		confirmTools: false,
		sendEvent: () => {}
	});

	updated = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf-8"));
	assert(updated.background?.widgets?.calendar?.enable === true, "calendar widget re-enabled");
	assert(updated.background?.widgets?.todo?.enable === true, "todo widget re-enabled");

	// Restore original state
	cfg.background.widgets = originalWidgets;
	fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 4));
	console.log("  ✓ Scenario 3 Completed Successfully.");
}

async function runScenario4_InteractiveApprovalDenial() {
	console.log("\n🧪 [Scenario 4] Testing Tool Approval Denial (Clicking [X] Deny button)...");

	let approvalRequested = false;
	let deniedEventReceived = false;

	const events = [];
	await runAgentLoop({
		prompt: "Tuliskan berkas /tmp/test_danger.txt dengan isi 'danger'",
		endpoint: "https://opencode.ai/zen/v1/chat/completions",
		model: "hy3-free",
		confirmTools: true, // Dangerous tools require approval
		requestApproval: async (info) => {
			approvalRequested = true;
			console.log(`  ⚡ Approval requested for tool: ${info.tool}. Simulating user clicking [X] DENY...`);
			return false; // Simulate clicking [X] deny button
		},
		sendEvent: (e) => {
			events.push(e);
			if (e.type === "tool_denied") {
				deniedEventReceived = true;
			}
		}
	});

	assert(approvalRequested === true, "Dangerous tool triggered interactive approval");
	assert(deniedEventReceived === true, "tool_denied event emitted properly");
	assert(!fs.existsSync("/tmp/test_danger.txt"), "Denied file write was blocked and not written to disk");
	console.log("  ✓ Scenario 4 Completed Successfully.");
}

async function runAllTests() {
	console.log("=================================================");
	console.log("🚀 Starting end4-pC Comprehensive AI Agent Tests");
	console.log("=================================================");
	try {
		await runScenario1_TaskbarAutohide();
		await runScenario2_AccentColor();
		await runScenario3_WidgetManagement();
		await runScenario4_InteractiveApprovalDenial();
		console.log("\n🎉 ALL 4 SCENARIOS PASSED WITH ZERO ERRORS!");
	} catch (err) {
		console.error("\n❌ TEST SUITE FAILED WITH EXCEPTION:", err);
		process.exit(1);
	}
}

runAllTests();
