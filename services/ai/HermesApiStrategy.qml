import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.functions as CF

ApiStrategy {
    id: root

    property string lastQuery: ""
    property string sessionName: "quickshell-ai"
    property string queryFilePath: "/tmp/quickshell/ai/hermes_query.txt"

    property bool inResponseBox: false
    property bool inReasoningBox: false

    function buildEndpoint(model: AiModel): string {
        return "hermes-cli"
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let userMessages = messages.filter(m => m.role === "user");
        let lastUserMsg = userMessages.length > 0 ? userMessages[userMessages.length - 1].rawContent : "";
        root.lastQuery = lastUserMsg;
        return {
            "query": lastUserMsg,
            "session": root.sessionName
        };
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return "";
    }

    function buildScriptFileSetup(filePath: string): string {
        return "";
    }

    function finalizeScriptContent(scriptContent: string): string {
        let qFile = CF.FileUtils.trimFileProtocol(root.queryFilePath);

        let script = `#!/usr/bin/env bash\n`
            + `mkdir -p /tmp/quickshell/ai\n`
            + `cat << 'EOF_HERMES_QUERY' > "${qFile}"\n`
            + `${root.lastQuery}\n`
            + `EOF_HERMES_QUERY\n\n`
            + `export PATH="$HOME/.local/bin:$PATH"\n`
            + `if command -v hermes >/dev/null 2>&1; then\n`
            + `    hermes chat --continue "${root.sessionName}" --query-file "${qFile}" -t file,terminal,skills,web\n`
            + `else\n`
            + `    echo "Error: Hermes CLI ('hermes') not found in PATH (~/.local/bin/hermes)."\n`
            + `fi\n`;

        return script;
    }

    function isNoiseLine(line: string): bool {
        const trimmed = line.trim();
        if (trimmed.length === 0) return true;
        const noisePrefixes = [
            "Query:",
            "Initializing agent",
            "↻ Resumed session",
            "Resumed session",
            "Resume this session",
            "hermes --resume",
            "hermes -c",
            "Session:",
            "Title:",
            "Duration:",
            "Messages:",
            "total messages",
            "────────────────"
        ];
        for (let i = 0; i < noisePrefixes.length; i++) {
            if (trimmed.includes(noisePrefixes[i])) return true;
        }
        return false;
    }

    function parseResponseLine(line: string, message: AiMessageData) {
        if (!line) return {};
        let clean = line.replace(/\r/g, "");

        // Detect response box start/end
        if (clean.includes("╭─") && clean.includes("Hermes")) {
            root.inResponseBox = true;
            return {};
        }
        if (clean.includes("╰─")) {
            root.inResponseBox = false;
            return {};
        }

        // Detect reasoning box
        if (clean.includes("┌─ Reasoning")) {
            root.inReasoningBox = true;
            return {};
        }
        if (clean.includes("└─")) {
            root.inReasoningBox = false;
            return {};
        }

        if (root.inReasoningBox) {
            return {};
        }

        if (root.inResponseBox) {
            let contentLine = clean.replace(/^[│|]\s?/, "").replace(/\s?[│|]$/, "");
            message.rawContent += contentLine + "\n";
            message.content += contentLine + "\n";
            return { finished: false };
        }

        // Fallback for lines outside boxes
        if (!isNoiseLine(clean)) {
            message.rawContent += clean + "\n";
            message.content += clean + "\n";
        }

        return { finished: false };
    }

    function onRequestFinished(message: AiMessageData): var {
        message.content = message.content.trim();
        root.inResponseBox = false;
        root.inReasoningBox = false;
        return { finished: true };
    }

    function reset() {
        root.lastQuery = "";
        root.inResponseBox = false;
        root.inReasoningBox = false;
    }

    function clearSession() {
        root.sessionName = "quickshell-ai-" + Date.now();
        reset();
    }
}
