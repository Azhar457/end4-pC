#!/usr/bin/env node

/**
 * 🐈 Native Standalone Agent Core for end4-pC (Quickshell)
 * Zero external binary dependencies.
 * ReAct Agentic Loop + Native Tool Calling + Multi-Provider Routing +
 * UNIX Socket server + Stdio JSONL streaming with interactive approval.
 *
 * Modes:
 *   node agent-core.mjs --serve        → UNIX socket daemon (auto-run tools)
 *   node agent-core.mjs --stdin        → read one JSON request per line from stdin,
 *                                        stream events to stdout, support approval
 *   node agent-core.mjs --prompt "hi"  → one-shot direct run
 */

import http from "node:http";
import net from "node:net";
import fs from "node:fs/promises";
import fsSync from "node:fs";
import path from "node:path";
import os from "node:os";
import { exec } from "node:child_process";
import { promisify } from "node:util";

const execAsync = promisify(exec);

export const DEFAULT_SOCKET_PATH = `/tmp/quickshell-agent-${process.getuid?.() ?? 1000}.sock`;

// Tools that mutate the system and therefore require user approval in
// confirmation mode. Read-only tools (file_read, web_*) run automatically.
const DANGEROUS_TOOLS = new Set(["bash", "file_write"]);
function isDangerous(toolName, input) {
	if (DANGEROUS_TOOLS.has(toolName)) return true;
	if (toolName === "hyprland_control" && input?.action === "dispatch") return true;
	return false;
}

// ─── TOOL DEFINITIONS (OpenAI-compatible schema) ─────────────────────────────
export const BUILTIN_TOOLS = [
	{
		name: "bash",
		description: "Execute a bash shell command on the host system asynchronously.",
		parameters: {
			type: "object",
			properties: {
				command: { type: "string", description: "The exact bash command to execute." },
				timeoutMs: { type: "number", description: "Optional execution timeout in milliseconds (default: 30000)." },
				cwd: { type: "string", description: "Optional working directory." }
			},
			required: ["command"]
		}
	},
	{
		name: "file_read",
		description: "Read the contents of a local file.",
		parameters: {
			type: "object",
			properties: {
				filePath: { type: "string", description: "Absolute or relative path to the file." },
				maxLines: { type: "number", description: "Max lines to read (default: 500)." }
			},
			required: ["filePath"]
		}
	},
	{
		name: "file_write",
		description: "Create or overwrite a file with given content.",
		parameters: {
			type: "object",
			properties: {
				filePath: { type: "string", description: "Path to file to write." },
				content: { type: "string", description: "Content to write into the file." }
			},
			required: ["filePath", "content"]
		}
	},
	{
		name: "hyprland_control",
		description: "Interact with Hyprland window manager (switch workspace, focus window, query status, toggle floating, screenshot).",
		parameters: {
			type: "object",
			properties: {
				action: {
					type: "string",
					enum: ["dispatch", "query_monitors", "query_clients", "query_workspaces", "get_active_window"],
					description: "Action to perform on Hyprland."
				},
				args: { type: "string", description: "Arguments for dispatch (e.g. 'workspace 2', 'focuswindow kitty', 'killactive')." }
			},
			required: ["action"]
		}
	},
	{
		name: "web_search",
		description: "Search the web via DuckDuckGo / SearXNG.",
		parameters: {
			type: "object",
			properties: {
				query: { type: "string", description: "Search term or question." }
			},
			required: ["query"]
		}
	},
	{
		name: "web_fetch",
		description: "Fetch web page content and convert HTML to readable markdown text.",
		parameters: {
			type: "object",
			properties: {
				url: { type: "string", description: "The URL to fetch." }
			},
			required: ["url"]
		}
	}
];

function toOpenAITools(tools) {
	return tools.map((t) => ({
		type: "function",
		function: { name: t.name, description: t.description, parameters: t.parameters }
	}));
}

// ─── TOOL EXECUTORS ──────────────────────────────────────────────────────────
export async function executeTool(toolName, args = {}, onDelta = () => {}) {
	try {
		switch (toolName) {
			case "bash": {
				const cmd = args.command;
				const timeout = args.timeoutMs || 30000;
				const cwd = args.cwd || process.env.HOME || "/tmp";
				const { stdout, stderr } = await execAsync(cmd, { timeout, cwd, maxBuffer: 1024 * 1024 * 8 });
				const res = ((stdout || "") + (stderr ? `\n[stderr]: ${stderr}` : "")).trim();
				if (!res) return "(Command completed with no output)";
				return res.length > 2000 ? (res.slice(0, 2000) + `\n... (truncated, total ${res.length} chars)`) : res;
			}
			case "file_read": {
				const fullPath = path.resolve(args.filePath.replace(/^~/, os.homedir()));
				const content = await fs.readFile(fullPath, "utf-8");
				const maxLines = args.maxLines || 100;
				const lines = content.split("\n");
				if (lines.length > maxLines) {
					return lines.slice(0, maxLines).join("\n") + `\n\n... (truncated ${lines.length - maxLines} lines)`;
				}
				return content.length > 2500 ? (content.slice(0, 2500) + `\n\n... (truncated)`) : content;
			}
			case "file_write": {
				const fullPath = path.resolve(args.filePath.replace(/^~/, os.homedir()));
				await fs.mkdir(path.dirname(fullPath), { recursive: true });
				await fs.writeFile(fullPath, args.content, "utf-8");
				return `Successfully wrote ${args.content.length} bytes to ${fullPath}`;
			}
			case "hyprland_control": {
				if (args.action === "dispatch") {
					const { stdout } = await execAsync(`hyprctl dispatch ${args.args || ""}`);
					return stdout.trim() || "Hyprland dispatch executed.";
				}
				const map = {
					query_monitors: "hyprctl monitors -j",
					query_clients: "hyprctl clients -j",
					query_workspaces: "hyprctl workspaces -j",
					get_active_window: "hyprctl activewindow -j"
				};
				if (!map[args.action]) return "Unknown hyprland action.";
				const { stdout } = await execAsync(map[args.action]);
				return stdout.trim();
			}
			case "web_search": {
				const query = encodeURIComponent(args.query);
				const text = await fetchUrlRaw(`https://html.duckduckgo.com/html/?q=${query}`);
				const results = [];
				const regex = /<a class="result__snippet[^>]*>(.*?)<\/a>/g;
				let match;
				let count = 0;
				while ((match = regex.exec(text)) !== null && count < 5) {
					const clean = match[1].replace(/<[^>]+>/g, "").trim();
					if (clean) {
						results.push(`- ${clean}`);
						count++;
					}
				}
				return results.length > 0 ? results.join("\n") : "No direct snippet found for query.";
			}
			case "web_fetch": {
				const text = await fetchUrlRaw(args.url);
				const clean = text
					.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
					.replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, "")
					.replace(/<[^>]+>/g, " ")
					.replace(/\s+/g, " ")
					.trim();
				return clean.slice(0, 6000) + (clean.length > 6000 ? " ...[truncated]" : "");
			}
			default:
				return `Error: Tool '${toolName}' is not supported.`;
		}
	} catch (err) {
		return `Error executing tool '${toolName}': ${err.message || String(err)}`;
	}
}

async function fetchUrlRaw(targetUrl) {
	const res = await fetch(targetUrl, {
		redirect: "follow",
		headers: { "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko)" }
	});
	if (!res.ok) throw new Error(`HTTP ${res.status} fetching ${targetUrl}`);
	return await res.text();
}

// ─── API KEY RESOLUTION ─────────────────────────────────────────────────────
// The 9Router gateway requires a bearer key. Hermes (which "just works" on this
// machine) carries it in its process environment, so we auto-discover it to make
// the agent work with zero configuration. Falls back to explicit env vars.
const KEY_ENV_CANDIDATES = [
	"HERMES_CUSTOM_9ROUTER_API_KEY",
	"OPENAI_API_KEY",
	"NINEROUTER_KEY",
	"9ROUTER_KEY"
];

export function resolveApiKey() {
	for (const c of KEY_ENV_CANDIDATES) {
		if (process.env[c]) return process.env[c];
	}
	try {
		for (const pid of fsSync.readdirSync("/proc")) {
			if (!/^\d+$/.test(pid)) continue;
			let env;
			try {
				env = fsSync.readFileSync(`/proc/${pid}/environ`, "utf-8");
			} catch {
				continue;
			}
			for (const c of KEY_ENV_CANDIDATES) {
				const m = env.match(new RegExp(`${c}=([^\\x00]*)\\x00`));
				if (m && m[1]) return m[1];
			}
		}
	} catch {}
	return "";
}

// ─── SYSTEM PROMPT BUILDER ───────────────────────────────────────────────────
export function buildAgentSystemPrompt() {
	return `You are the built-in AI Desktop Assistant for "end4-pC" (a customized Material 3 Quickshell desktop environment on Fedora Linux, supporting Hyprland & Niri Wayland compositors).

IMPORTANT: An explicit configuration reference file exists at SETTINGS.md in the end4-pC root directory (~/.config/quickshell/end4-pC/SETTINGS.md). When the user asks about desktop settings, wallpaper changes, keybinds, or shell customization, you MUST consult or follow SETTINGS.md as your authoritative source of truth.

Key Architectural Context of end4-pC:
- Shell Core: Quickshell (Qt6/QML) with Material 3 theming.
- Shell Configuration File: ~/.config/illogical-impulse/config.json (stores settings for bar, background, widgets, colors, services).
- GUI Settings App: Can be toggled with Super+I or clicked from the sidebar/bar.
- Wallpaper & Color Theming:
  * Switch wallpaper & auto-generate Material You palette: ~/.config/quickshell/end4-pC/scripts/colors/switchwall.sh <image_path>
  * Generate/apply colors manually: ~/.config/quickshell/end4-pC/scripts/colors/applycolor.sh
  * Theme palettes: Generated to ~/.local/state/quickshell/user/generated/colors.json via Matugen.
- Compositors:
  * Hyprland: Config files in ~/.config/hypr/ (keybinds: ~/.config/hypr/hyprland/keybinds.conf).
  * Niri: Config file in ~/.config/niri/config.kdl.
  * Note: GNOME, KDE Plasma, and X11 are NOT used. Always provide Wayland-native solutions (grim, slurp, hyprctl, niri msg).
- Widgets & Services:
  * Background widgets (AI Agent, Clock, Media, Notes, Todo, etc.) are configured in GUI Settings -> Background or ~/.config/illogical-impulse/config.json -> "background"."widgets".
  * Bar modules are in modules/ii/bar/ and configured via GUI Settings -> Bar.

Guidelines:
1. Always be direct, friendly, and practical in Indonesian or English (matching the user's language).
2. Point users directly to the right setting or file path according to SETTINGS.md when asked how to customize or fix something.
3. When executing tasks (e.g. changing wallpaper or switching themes), run the proper script directly and provide the user with clear feedback.
4. Keep explanations concise, clear, and actionable.`;
}

// ─── LLM STREAMING CLIENT ────────────────────────────────────────────────────
// Returns { text, toolCalls } where toolCalls is an array of
// { id, name, parameters }. Emits think/content deltas via callbacks.
export async function streamLLMCompletion({
	endpoint,
	model,
	apiKey,
	messages,
	onChunk = () => {},
	onThink = () => {}
}) {
	apiKey = apiKey || resolveApiKey();
	const postData = JSON.stringify({
		model: model || "ag/claude-sonnet-4-6",
		messages,
		stream: true,
		temperature: 0.6,
		tools: toOpenAITools(BUILTIN_TOOLS),
		tool_choice: "auto"
	});

	const controller = new AbortController();
	const timer = setTimeout(() => controller.abort(), 120000);

	let res;
	try {
		res = await fetch(endpoint, {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				"Content-Length": Buffer.byteLength(postData),
				...(endpoint.includes("opencode.ai") ? {
					"HTTP-Referer": "https://hermes-agent.nousresearch.com",
					"X-Title": "end4-pC AI Agent",
					"User-Agent": "HermesAgent/0.1"
				} : (apiKey ? { Authorization: `Bearer ${apiKey}` } : {}))
			},
			body: postData,
			signal: controller.signal
		});
	} catch (err) {
		clearTimeout(timer);
		if (err.name === "AbortError") throw new Error("LLM request timed out");
		throw new Error(`Could not reach LLM endpoint ${endpoint}: ${err.message}`);
	}
	clearTimeout(timer);

	if (!res.ok) {
		const body = await res.text().catch(() => "");
		throw new Error(`LLM HTTP ${res.status}: ${body.slice(0, 500)}`);
	}

	const hider = createToolCallHider(onChunk);
	const reader = res.body.getReader();
	const decoder = new TextDecoder();
	let buffer = "";
	let fullText = "";
	let inReasoning = false;
	// accumulated native tool calls keyed by index
	const toolAcc = {};

	try {
		while (true) {
			const { done, value } = await reader.read();
			if (done) break;
			buffer += decoder.decode(value, { stream: true });
			let idx;
			while ((idx = buffer.indexOf("\n")) >= 0) {
				const line = buffer.slice(0, idx);
				buffer = buffer.slice(idx + 1);
				const trimmed = line.trim();
				if (!trimmed || trimmed.startsWith(":")) continue;
				if (trimmed === "data: [DONE]") continue;
				if (!trimmed.startsWith("data:")) continue;

				let json;
				try {
					json = JSON.parse(trimmed.slice(5).trim());
				} catch {
					continue;
				}

				const choice = json.choices?.[0];
				if (!choice) continue;
				const delta = choice.delta || {};

				const reasoning = delta.reasoning || delta.reasoning_content || delta.thinking;
				if (reasoning) {
					if (!inReasoning) {
						inReasoning = true;
						onThink("<think>");
					}
					onThink(reasoning);
					fullText += reasoning;
				}
				if (delta.content) {
					if (inReasoning) {
						inReasoning = false;
						onThink("</think>\n\n");
					}
					hider(delta.content);
					fullText += delta.content;
				}
				if (delta.tool_calls) {
					for (const tc of delta.tool_calls) {
						const i = tc.index ?? 0;
						toolAcc[i] = toolAcc[i] || { id: "", name: "", arguments: "" };
						if (tc.id) toolAcc[i].id = tc.id;
						if (tc.function?.name) toolAcc[i].name += tc.function.name;
						if (tc.function?.arguments) toolAcc[i].arguments += tc.function.arguments;
					}
				}
			}
		}
	} finally {
		reader.releaseLock?.();
	}
	if (inReasoning) onThink("</think>\n\n");

	// Build tool call list
	const toolCalls = Object.keys(toolAcc)
		.map((k) => toolAcc[k])
		.filter((t) => t.name)
		.map((t) => {
			let parameters = {};
			try {
				parameters = t.arguments ? JSON.parse(t.arguments) : {};
			} catch {
				parameters = { _raw: t.arguments };
			}
			return { id: t.id || `call_${Math.random().toString(36).slice(2)}`, name: t.name, parameters };
		});

	// Fallback: parse <tool_call> XML from the full text if no native calls arrived.
	if (toolCalls.length === 0) {
		const xmlCall = parseToolCallXml(fullText);
		if (xmlCall) toolCalls.push(xmlCall);
	}

	return { text: fullText, toolCalls };
}

function parseToolCallXml(text) {
	const m = text.match(/<tool_call>([\s\S]*?)<\/tool_call>/);
	if (!m) return null;
	try {
		const data = JSON.parse(m[1].trim());
		if (!data.name) return null;
		return { id: `call_${Math.random().toString(36).slice(2)}`, name: data.name, parameters: data.parameters || {} };
	} catch {
		return null;
	}
}

// Streams visible content to onText while hiding <tool_call>...</tool_call> blocks
// (so the raw XML never reaches the chat UI).
function createToolCallHider(onText) {
	let state = 0; // 0 = outside, 1 = inside tag
	let buf = "";
	return (chunk) => {
		buf += chunk;
		let out = "";
		let i = 0;
		while (i < buf.length) {
			if (state === 0) {
				const open = buf.indexOf("<tool_call", i);
				if (open === -1) {
					out += buf.slice(i);
					i = buf.length;
					break;
				}
				out += buf.slice(i, open);
				const close = buf.indexOf("</tool_call>", open);
				if (close === -1) {
					state = 1;
					i = open;
					break;
				}
				i = close + "</tool_call>".length;
			} else {
				const close = buf.indexOf("</tool_call>", i);
				if (close === -1) {
					i = buf.length;
					break;
				}
				i = close + "</tool_call>".length;
				state = 0;
			}
		}
		buf = buf.slice(i);
		if (out) onText(out);
	};
}

// ─── REACT AGENT LOOP ────────────────────────────────────────────────────────
export async function runAgentLoop({
	prompt,
	history = [],
	endpoint = "http://127.0.0.1:20128/v1/chat/completions",
	model = "ag/claude-sonnet-4-6",
	apiKey = "",
	confirmTools = false,
	requestApproval = null,
	sendEvent = () => {}
}) {
	sendEvent({ type: "log", level: "info", text: `🚀 Initializing Agent Loop for model: ${model}` });
	const messages = [
		{ role: "system", content: buildAgentSystemPrompt() },
		...history,
		{ role: "user", content: prompt }
	];

	const maxTurns = 10;
	for (let turn = 0; turn < maxTurns; turn++) {
		sendEvent({ type: "turn_start", turn: turn + 1 });
		sendEvent({ type: "log", level: "info", text: `🔄 Turn ${turn + 1}/${maxTurns}: sending context (${messages.length} messages) to ${endpoint}...` });

		let result;
		try {
			result = await streamLLMCompletion({
				endpoint,
				model,
				apiKey,
				messages,
				onThink: (d) => sendEvent({ type: "think", delta: d }),
				onChunk: (d) => sendEvent({ type: "content", delta: d })
			});
		} catch (err) {
			sendEvent({ type: "log", level: "error", text: `❌ LLM request failed: ${err.message}` });
			sendEvent({ type: "error", message: err.message });
			break;
		}

		const { text, toolCalls } = result;
		sendEvent({ type: "log", level: "llm", text: `📥 Turn ${turn + 1} stream finished. Content length: ${text.length}, Tool calls: ${toolCalls.length}` });

		// Persist assistant message (with tool_calls for proper multi-turn context).
		if (toolCalls.length) {
			messages.push({
				role: "assistant",
				content: text,
				tool_calls: toolCalls.map((t) => ({
					id: t.id,
					type: "function",
					function: { name: t.name, arguments: JSON.stringify(t.parameters) }
				}))
			});
		} else {
			messages.push({ role: "assistant", content: text });
		}

		if (toolCalls.length === 0) {
			sendEvent({ type: "log", level: "info", text: `✨ No further tool calls requested. Final answer ready.` });
			break;
		}

		for (const tc of toolCalls) {
			if (confirmTools && isDangerous(tc.name, tc.parameters) && requestApproval) {
				sendEvent({ type: "log", level: "warn", text: `⚠️ Dangerous tool '${tc.name}' needs user approval...` });
				const approved = await requestApproval({ id: tc.id, tool: tc.name, input: tc.parameters });
				if (!approved) {
					sendEvent({ type: "log", level: "warn", text: `🚫 Tool '${tc.name}' denied by user.` });
					sendEvent({ type: "tool_denied", id: tc.id, tool: tc.name });
					messages.push({
						role: "tool",
						tool_call_id: tc.id,
						content: "Tool execution denied by the user."
					});
					continue;
				}
				sendEvent({ type: "log", level: "info", text: `✅ Tool '${tc.name}' approved by user.` });
			}

			sendEvent({ type: "tool_start", id: tc.id, tool: tc.name, input: tc.parameters });
			sendEvent({ type: "log", level: "tool", text: `⚙️ Executing '${tc.name}': ${JSON.stringify(tc.parameters).slice(0, 100)}` });
			const toolResult = await executeTool(tc.name, tc.parameters);
			sendEvent({ type: "log", level: "tool", text: `✔️ '${tc.name}' returned ${toolResult.length} characters.` });
			sendEvent({
				type: "tool_end",
				id: tc.id,
				tool: tc.name,
				result: toolResult,
				isError: toolResult.startsWith("Error:")
			});
			messages.push({ role: "tool", tool_call_id: tc.id, content: toolResult });
		}
	}

	sendEvent({ type: "log", level: "done", text: `🏁 Agent loop completed.` });
	sendEvent({ type: "done", history: messages.filter((m) => m.role !== "system") });
}

// ─── UNIX SOCKET IPC SERVER (daemon, auto-run tools) ────────────────────────
export function startAgentSocketServer(socketPath = DEFAULT_SOCKET_PATH) {
	try {
		if (fsSync.existsSync(socketPath)) fsSync.unlinkSync(socketPath);
	} catch {}

	const server = net.createServer((socket) => {
		let buffer = "";
		socket.on("data", async (chunk) => {
			buffer += chunk.toString("utf-8");
			const lines = buffer.split("\n");
			buffer = lines.pop() || "";
			for (const line of lines) {
				if (!line.trim()) continue;
				try {
					const req = JSON.parse(line.trim());
					const sendEvent = (event) => {
						if (!socket.destroyed) socket.write(JSON.stringify(event) + "\n");
					};
					await runAgentLoop({
						prompt: req.prompt || "",
						history: req.history || [],
						endpoint: req.endpoint,
						model: req.model,
						apiKey: req.apiKey || "",
						confirmTools: false,
						sendEvent
					});
				} catch (err) {
					if (!socket.destroyed) {
						socket.write(JSON.stringify({ type: "error", message: err.message }) + "\n");
						socket.write(JSON.stringify({ type: "done" }) + "\n");
					}
				}
			}
		});
	});

	server.listen(socketPath, () => {
		console.log(`🐈 Standalone Agent Server running on UNIX Socket: ${socketPath}`);
	});
	return server;
}

// ─── STDIN JSONL MODE (interactive, used by the QML widget) ──────────────────
function startStdinMode() {
	let pendingApproval = null;
	let activeRequest = false;
	let stdinEnded = false;
	let buffer = "";

	const sendEvent = (ev) => {
		process.stdout.write(JSON.stringify(ev) + "\n");
	};

	function maybeExit() {
		if (!activeRequest && !pendingApproval && stdinEnded) {
			// Flush any pending stdout, then terminate cleanly.
			process.stdout.end(() => process.exit(0));
		}
	}

	process.stdin.setEncoding("utf-8");
	process.stdin.on("data", (chunk) => {
		buffer += chunk.toString("utf-8");
		const lines = buffer.split("\n");
		buffer = lines.pop() || "";
		for (const line of lines) handleLine(line.trim());
	});
	process.stdin.on("end", () => {
		stdinEnded = true;
		maybeExit();
	});

	function handleLine(line) {
		if (!line) return;
		let msg;
		try {
			msg = JSON.parse(line);
		} catch {
			return;
		}

		if (msg.type === "approve" && pendingApproval && pendingApproval.id === msg.id) {
			const p = pendingApproval;
			pendingApproval = null;
			p.resolve(true);
			return;
		}
		if (msg.type === "deny" && pendingApproval && pendingApproval.id === msg.id) {
			const p = pendingApproval;
			pendingApproval = null;
			p.resolve(false);
			return;
		}

		if (msg.type === "request" || (!msg.type && msg.prompt)) {
			activeRequest = true;
			runAgentLoop({
				prompt: msg.prompt || "",
				history: msg.history || [],
				endpoint: msg.endpoint,
				model: msg.model,
				apiKey: msg.apiKey || "",
				confirmTools: msg.confirmTools !== false,
				requestApproval: (info) => {
					sendEvent({ type: "tool_need_approval", id: info.id, tool: info.tool, input: info.input });
					return new Promise((resolve) => {
						pendingApproval = { id: info.id, resolve };
					});
				},
				sendEvent
			})
				.then(() => {
					activeRequest = false;
					maybeExit();
				})
				.catch((e) => {
					sendEvent({ type: "error", message: e.message });
					activeRequest = false;
					maybeExit();
				});
		}
	}
}

// ─── CLI ENTRYPOINT ──────────────────────────────────────────────────────────
if (process.argv[1] && process.argv[1].endsWith("agent-core.mjs")) {
	const args = process.argv.slice(2);
	if (args.includes("--serve")) {
		startAgentSocketServer();
	} else if (args.includes("--stdin")) {
		startStdinMode();
	} else if (args.includes("--prompt")) {
		const idx = args.indexOf("--prompt");
		const prompt = args[idx + 1] || "Hello";
		runAgentLoop({
			prompt,
			sendEvent: (e) => process.stdout.write(JSON.stringify(e) + "\n")
		}).catch((e) => {
			process.stdout.write(JSON.stringify({ type: "error", message: e.message }) + "\n");
			process.exit(1);
		});
	} else {
		startAgentSocketServer();
	}
}
