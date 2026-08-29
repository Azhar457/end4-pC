#!/usr/bin/env node
// Safe session-cache writer: reads JSON from stdin, writes it to the path
// given as argv[1]. Avoids shell-quoting issues present in heredoc-based writes.
import fs from "node:fs";
import path from "node:path";

let data = "";
process.stdin.setEncoding("utf-8");
process.stdin.on("data", (c) => { data += c; });
process.stdin.on("end", () => {
	const target = process.argv[2];
	if (!target) {
		console.error("save-cache.mjs: missing target path");
		process.exit(1);
	}
	try {
		fs.mkdirSync(path.dirname(target), { recursive: true });
		fs.writeFileSync(target, data);
		process.exit(0);
	} catch (e) {
		console.error("save-cache.mjs:", e.message);
		process.exit(1);
	}
});
