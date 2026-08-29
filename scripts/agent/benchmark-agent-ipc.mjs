#!/usr/bin/env node

import http from "node:http";
import net from "node:net";
import fs from "node:fs";
import { spawn } from "node:child_process";
import { performance } from "node:perf_hooks";

const TEST_TOKENS_COUNT = 1000;
const TEST_CHUNK = JSON.stringify({ type: "content", delta: "Hello world token stream benchmark " });

// --- APPROACH A: Stdio JSON-Lines Benchmark ---
async function benchmarkStdio() {
	const startMem = process.memoryUsage().rss;
	const t0 = performance.now();

	const child = spawn("node", [
		"-e",
		`
		const readline = require("node:readline");
		const rl = readline.createInterface({ input: process.stdin });
		rl.on("line", (line) => {
			for (let i = 0; i < ${TEST_TOKENS_COUNT}; i++) {
				process.stdout.write(${JSON.stringify(TEST_CHUNK)} + "\\n");
			}
			process.stdout.write(JSON.stringify({ type: "done" }) + "\\n");
		});
		`
	], { stdio: ["pipe", "pipe", "inherit"] });

	let firstTokenTime = 0;
	let receivedTokens = 0;

	await new Promise((resolve) => {
		let buffer = "";
		child.stdout.on("data", (chunk) => {
			if (!firstTokenTime) {
				firstTokenTime = performance.now() - t0;
			}
			buffer += chunk.toString("utf-8");
			const lines = buffer.split("\n");
			buffer = lines.pop() || "";
			for (const line of lines) {
				if (!line.trim()) continue;
				const msg = JSON.parse(line);
				if (msg.type === "done") {
					child.kill();
					resolve();
					return;
				}
				receivedTokens++;
			}
		});

		child.stdin.write(JSON.stringify({ prompt: "start" }) + "\n");
	});

	const totalTime = performance.now() - t0;
	const endMem = process.memoryUsage().rss;

	return {
		approach: "Approach A: Stdio JSON-Lines (Child Process Pipe)",
		ttftMs: Number(firstTokenTime.toFixed(2)),
		totalTimeMs: Number(totalTime.toFixed(2)),
		throughput: Math.round((receivedTokens / totalTime) * 1000),
		memoryDeltaMB: Number(((endMem - startMem) / (1024 * 1024)).toFixed(2)),
	};
}

// --- APPROACH B: Local HTTP SSE Benchmark ---
async function benchmarkHttp() {
	const PORT = 18991;
	const startMem = process.memoryUsage().rss;

	const server = http.createServer((req, res) => {
		res.writeHead(200, {
			"Content-Type": "text/event-stream",
			"Cache-Control": "no-cache",
			"Connection": "keep-alive",
		});
		for (let i = 0; i < TEST_TOKENS_COUNT; i++) {
			res.write(`data: ${TEST_CHUNK}\n\n`);
		}
		res.write(`data: ${JSON.stringify({ type: "done" })}\n\n`);
		res.end();
	});

	await new Promise((resolve) => server.listen(PORT, "127.0.0.1", resolve));

	const t0 = performance.now();
	let firstTokenTime = 0;
	let receivedTokens = 0;

	await new Promise((resolve) => {
		http.get(`http://127.0.0.1:${PORT}`, (res) => {
			let buffer = "";
			res.on("data", (chunk) => {
				if (!firstTokenTime) {
					firstTokenTime = performance.now() - t0;
				}
				buffer += chunk.toString("utf-8");
				const parts = buffer.split("\n\n");
				buffer = parts.pop() || "";
				for (const part of parts) {
					if (!part.startsWith("data: ")) continue;
					const jsonStr = part.slice(6).trim();
					if (!jsonStr) continue;
					const msg = JSON.parse(jsonStr);
					if (msg.type === "done") {
						resolve();
						return;
					}
					receivedTokens++;
				}
			});
		});
	});

	const totalTime = performance.now() - t0;
	await new Promise((resolve) => server.close(resolve));
	const endMem = process.memoryUsage().rss;

	return {
		approach: "Approach B: Localhost HTTP SSE Server",
		ttftMs: Number(firstTokenTime.toFixed(2)),
		totalTimeMs: Number(totalTime.toFixed(2)),
		throughput: Math.round((receivedTokens / totalTime) * 1000),
		memoryDeltaMB: Number(((endMem - startMem) / (1024 * 1024)).toFixed(2)),
	};
}

// --- APPROACH C: UNIX Domain Socket Benchmark ---
async function benchmarkUnixSocket() {
	const SOCK_PATH = "/tmp/agent-bench-sock.sock";
	try { fs.unlinkSync(SOCK_PATH); } catch {}

	const startMem = process.memoryUsage().rss;

	const server = net.createServer((socket) => {
		socket.on("data", () => {
			for (let i = 0; i < TEST_TOKENS_COUNT; i++) {
				socket.write(TEST_CHUNK + "\n");
			}
			socket.write(JSON.stringify({ type: "done" }) + "\n");
		});
	});

	await new Promise((resolve) => server.listen(SOCK_PATH, resolve));

	const t0 = performance.now();
	let firstTokenTime = 0;
	let receivedTokens = 0;

	await new Promise((resolve) => {
		const client = net.createConnection(SOCK_PATH, () => {
			client.write("start\n");
		});

		let buffer = "";
		client.on("data", (chunk) => {
			if (!firstTokenTime) {
				firstTokenTime = performance.now() - t0;
			}
			buffer += chunk.toString("utf-8");
			const lines = buffer.split("\n");
			buffer = lines.pop() || "";
			for (const line of lines) {
				if (!line.trim()) continue;
				const msg = JSON.parse(line);
				if (msg.type === "done") {
					client.destroy();
					resolve();
					return;
				}
				receivedTokens++;
			}
		});
	});

	const totalTime = performance.now() - t0;
	await new Promise((resolve) => server.close(resolve));
	try { fs.unlinkSync(SOCK_PATH); } catch {}
	const endMem = process.memoryUsage().rss;

	return {
		approach: "Approach C: UNIX Domain Socket Stream",
		ttftMs: Number(firstTokenTime.toFixed(2)),
		totalTimeMs: Number(totalTime.toFixed(2)),
		throughput: Math.round((receivedTokens / totalTime) * 1000),
		memoryDeltaMB: Number(((endMem - startMem) / (1024 * 1024)).toFixed(2)),
	};
}

async function runAll() {
	console.log("⚡ Running 3-Approach Efficiency & Performance Benchmark...");
	console.log(`Payload: ${TEST_TOKENS_COUNT} streamed tokens\n`);

	const results = [];
	results.push(await benchmarkStdio());
	results.push(await benchmarkHttp());
	results.push(await benchmarkUnixSocket());

	console.table(results);

	const sorted = [...results].sort((a, b) => a.totalTimeMs - b.totalTimeMs);
	console.log(`\n🏆 Winner: ${sorted[0].approach}`);
	console.log(`- Lowest Latency / Fastest Transfer: ${sorted[0].totalTimeMs} ms (${sorted[0].throughput} tokens/sec)`);
}

runAll().catch(console.error);
