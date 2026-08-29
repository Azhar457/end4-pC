import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
	id: root
	configEntryName: "aiAgent"
	hoverEnabled: true

	readonly property real cardWidth: 460
	readonly property real cardHeight: 520

	implicitWidth: isExpanded ? Math.max(380, Math.min(650, root.configEntry?.width ?? root.cardWidth)) : 380
	implicitHeight: isExpanded ? Math.max(260, Math.min(850, root.configEntry?.height ?? root.cardHeight)) : 140

	Behavior on implicitWidth {
		NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
	}
	Behavior on implicitHeight {
		NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
	}

	property bool isExpanded: true
	property string mode: "sessions" // "sessions" | "chat" | "settings"
	property string previousMode: "sessions"
	property bool isBusy: agentProcess.isExecuting
	property string activeStatus: agentProcess.awaitingApproval ? "Waiting for approval…"
		: (isBusy ? "Agent Thinking & Responding…" : "Ready")

	// Multi-session State
	property string activeSessionId: ""
	property var sessionsList: []
	property string activeSessionTitle: "Chat"
	property int activeSessionToolCallsCount: 0
	readonly property int activeSessionMessageCount: messageModel.count
	property bool showLogsPanel: false

	ListModel { id: agentLogModel }

	function countToolsInMessages(msgs) {
		if (!Array.isArray(msgs)) return 0;
		return msgs.filter(m => (m.toolName && m.toolName.length > 0) || (m.toolResult && m.toolResult.length > 0)).length;
	}

	function updateActiveStats() {
		let cnt = 0;
		for (let i = 0; i < messageModel.count; i++) {
			const item = messageModel.get(i);
			if ((item.toolName && item.toolName.length > 0) || (item.toolResult && item.toolResult.length > 0)) {
				cnt++;
			}
		}
		root.activeSessionToolCallsCount = cnt;
	}

	readonly property string sessionsFilePath: FileUtils.trimFileProtocol(`${Directories.state}/user/ai_agent_sessions.json`)
	readonly property string agentCorePath: `${Directories.scriptPath}/agent/agent-core.mjs`
	readonly property var aiCfg: Config.options.background.widgets.aiAgent

	FileView {
		id: sessionsFileView
		path: root.sessionsFilePath
		blockLoading: true
	}

	onModeChanged: {
		// Keyboard focus must be claimed BEFORE focusing any field: the layer
		// drops keyboard grab when this is false, making forceActiveFocus a no-op.
		if (mode === "chat" || mode === "settings") {
			GlobalStates.desktopWidgetKeyboardFocus = true;
			if (mode === "chat") focusTimer.restart();
			if (mode === "settings") root.fetchLiveModels();
		} else {
			GlobalStates.desktopWidgetKeyboardFocus = false;
		}
	}

	Timer {
		id: focusTimer
		interval: 60  // after flip animation swaps pages
		repeat: false
		onTriggered: inputArea.forceActiveFocus()
	}

	Component.onCompleted: {
		loadSessionsFromDisk();
	}

	function toggleFlip(newMode) {
		root.previousMode = root.mode;
		targetNextMode = newMode;
		flipAnim.start();
	}

	property string targetNextMode: "chat"

	function providerConfig() {
		const prov = aiCfg.provider || "9router";
		if (prov === "opencode" || prov === "opencode-free") {
			return {
				endpoint: "https://opencode.ai/zen/v1/chat/completions",
				model: aiCfg.model || "hy3-free",
				apiKey: ""
			};
		}
		if (prov === "9router") {
			const envKey = Quickshell.env("HERMES_CUSTOM_9ROUTER_API_KEY")
				|| Quickshell.env("NINEROUTER_API_KEY")
				|| Quickshell.env("OPENAI_API_KEY")
				|| (KeyringStorage.keyringData?.apiKeys ? (KeyringStorage.keyringData.apiKeys["9router"] || KeyringStorage.keyringData.apiKeys["gemini"] || "") : "")
				|| "";
			const key = (aiCfg.apiKey && aiCfg.apiKey.trim().length > 0) ? aiCfg.apiKey.trim() : envKey;
			return {
				endpoint: aiCfg.endpoint || "http://127.0.0.1:20128/v1/chat/completions",
				model: aiCfg.model || "ag/gemini-3.7-flash-high",
				apiKey: key
			};
		}
		if (prov === "ollama") {
			return {
				endpoint: "http://127.0.0.1:11434/v1/chat/completions",
				model: aiCfg.model || "qwen2.5:3b-instruct",
				apiKey: ""
			};
		}
		return {
			endpoint: aiCfg.endpoint || "http://127.0.0.1:20128/v1/chat/completions",
			model: aiCfg.model || "ag/gemini-3.7-flash-high",
			apiKey: aiCfg.apiKey || ""
		};
	}

	// ─── SESSION MANAGER ────────────────────────────────────────────────────────
	function loadSessionsFromDisk() {
		try {
			sessionsFileView.path = root.sessionsFilePath;
			sessionsFileView.reload();
			const raw = sessionsFileView.text();
			if (raw && raw.trim().length > 0) {
				const parsed = JSON.parse(raw);
				if (Array.isArray(parsed) && parsed.length > 0) {
					root.sessionsList = parsed;
					selectSession(parsed[0].id, false);
					return;
				}
			}
		} catch (e) {
			console.warn("[AiAgentWidget] Could not load sessions:", e);
		}
		createNewSession(false);
	}

	function saveSessionsToDisk() {
		const msgs = [];
		for (let i = 0; i < messageModel.count; i++) {
			const m = messageModel.get(i);
			msgs.push({
				role: m.role || "user",
				content: m.content || "",
				thinkContent: m.thinkContent || "",
				toolName: m.toolName || "",
				toolInput: m.toolInput || ({}),
				toolResult: m.toolResult || "",
				isRunningTool: false,
				isToolError: !!m.isToolError,
				awaitingApproval: false
			});
		}

		let found = false;
		const updated = root.sessionsList.map(s => {
			if (s.id === root.activeSessionId) {
				found = true;
				return {
					id: s.id,
					title: root.activeSessionTitle,
					createdAt: s.createdAt || Date.now(),
					draft: inputArea.text,
					messages: msgs
				};
			}
			return s;
		});

		if (!found && root.activeSessionId) {
			updated.unshift({
				id: root.activeSessionId,
				title: root.activeSessionTitle,
				createdAt: Date.now(),
				draft: inputArea.text,
				messages: msgs
			});
		}

		// Deep clone to guarantee QML list view bindings update
		root.sessionsList = JSON.parse(JSON.stringify(updated));

		try {
			sessionsFileView.path = root.sessionsFilePath;
			sessionsFileView.setText(JSON.stringify(updated, null, 2));
		} catch (e) {
			console.warn("[AiAgentWidget] Could not save sessions:", e);
		}
	}

	function createNewSession(shouldFlip = true) {
		const newId = `session_${Date.now()}`;
		root.activeSessionId = newId;
		root.activeSessionTitle = "New Conversation";
		messageModel.clear();
		inputArea.text = "";
		root.activeSessionToolCallsCount = 0;

		const updated = [
			{
				id: newId,
				title: root.activeSessionTitle,
				createdAt: Date.now(),
				draft: "",
				messages: []
			},
			...root.sessionsList
		];
		root.sessionsList = updated;
		saveSessionsToDisk();

		if (shouldFlip) {
			toggleFlip("chat");
		}
	}

	function selectSession(sessionId, shouldFlip = true) {
		const sess = root.sessionsList.find(s => s.id === sessionId);
		if (!sess) return;

		root.sessionsList = [sess, ...root.sessionsList.filter(s => s.id !== sessionId)];

		root.activeSessionId = sess.id;
		root.activeSessionTitle = sess.title || "Chat";
		messageModel.clear();
		if (Array.isArray(sess.messages)) {
			for (const m of sess.messages) {
				messageModel.append(m);
			}
		}
		inputArea.text = sess.draft || "";
		updateActiveStats();

		if (shouldFlip) {
			toggleFlip("chat");
		}
	}

	function deleteSession(sessionId) {
		const filtered = root.sessionsList.filter(s => s.id !== sessionId);
		root.sessionsList = filtered;
		if (root.activeSessionId === sessionId) {
			if (filtered.length > 0) {
				selectSession(filtered[0].id, false);
			} else {
				createNewSession(false);
			}
		}
		saveSessionsToDisk();
	}

	function clearCurrentSession() {
		messageModel.clear();
		inputArea.text = "";
		root.activeSessionToolCallsCount = 0;
		saveSessionsToDisk();
	}

	property var availableModelsList: []
	property bool isFetchingModels: false

	function fetchLiveModels() {
		const prov = Config.options.background.widgets.aiAgent.provider || "9router";
		if (prov === "9router" || prov === "custom") {
			const ep = Config.options.background.widgets.aiAgent.endpoint || "http://127.0.0.1:20128/v1/chat/completions";
			const baseEp = ep.replace(/\/chat\/completions\/?$/, "/models");
			modelsFetchProc.command = ["curl", "-sL", "--max-time", "5", baseEp];
			modelsFetchProc.running = true;
		} else if (prov === "ollama") {
			modelsFetchProc.command = ["curl", "-sL", "--max-time", "5", "http://127.0.0.1:11434/api/tags"];
			modelsFetchProc.running = true;
		}
	}

	Process {
		id: modelsFetchProc
		property string buf: ""
		onRunningChanged: {
			if (running) {
				buf = "";
				root.isFetchingModels = true;
			} else {
				root.isFetchingModels = false;
			}
		}
		stdout: SplitParser {
			onRead: (data) => { modelsFetchProc.buf += data + "\n"; }
		}
		onExited: (exitCode, exitStatus) => {
			root.isFetchingModels = false;
			if (exitCode === 0 && modelsFetchProc.buf.trim().length > 0) {
				try {
					const json = JSON.parse(modelsFetchProc.buf.trim());
					let list = [];
					if (Array.isArray(json.data)) {
						list = json.data.map(d => d.id).filter(id => id && id.length > 0);
					} else if (Array.isArray(json.models)) {
						list = json.models.map(m => m.name).filter(n => n && n.length > 0);
					}
					if (list.length > 0) {
						root.availableModelsList = list;
					}
				} catch (e) {}
			}
		}
	}

	// ─── AGENT PROCESS ──────────────────────────────────────────────────────────
	ListModel { id: messageModel }

	Timer {
		id: draftSaveTimer
		interval: 400
		repeat: false
		onTriggered: root.saveSessionsToDisk()
	}

	Process {
		id: agentProcess
		property var pendingRequest: null
		property bool isExecuting: false
		property bool awaitingApproval: false
		property string awaitingApprovalId: ""
		property string awaitingApprovalTool: ""
		property var awaitingApprovalInput: ({})

		command: ["node", root.agentCorePath, "--stdin"]
		stdinEnabled: true

		onRunningChanged: {
			if (running && pendingRequest) {
				const line = JSON.stringify(pendingRequest);
				pendingRequest = null;
				write(line + "\n");
			}
			if (!running) {
				isExecuting = false;
				awaitingApproval = false;
				awaitingApprovalId = "";
				root.saveSessionsToDisk();
			}
		}

		function respond(approved) {
			if (!running || !awaitingApproval || !awaitingApprovalId) return;
			const resp = {
				type: approved ? "approve" : "deny",
				id: awaitingApprovalId
			};
			awaitingApproval = false;
			awaitingApprovalId = "";
			write(JSON.stringify(resp) + "\n");
		}

		stdout: SplitParser {
			splitMarker: "\n"
			onRead: (line) => {
				const trimmed = line.trim();
				if (!trimmed) return;
				try {
					const ev = JSON.parse(trimmed);

					if (ev.type === "log") {
						agentLogModel.append({
							time: Qt.formatTime(new Date(), "hh:mm:ss"),
							level: ev.level || "info",
							text: ev.text || ""
						});
						if (agentLogsListView) agentLogsListView.positionViewAtEnd();
						return;
					}

					if (messageModel.count === 0) return;
					let lastIdx = messageModel.count - 1;
					let cur = messageModel.get(lastIdx);

					if (ev.type === "turn_start") {
						agentProcess.isExecuting = true;
						if (ev.turn > 1 && (cur.toolName || cur.toolResult || (cur.content && cur.content.length > 0))) {
							messageModel.append({
								role: "assistant",
								content: "",
								thinkContent: "",
								toolName: "",
								toolInput: ({}),
								toolResult: "",
								isRunningTool: false,
								isToolError: false,
								awaitingApproval: false
							});
							lastIdx = messageModel.count - 1;
							cur = messageModel.get(lastIdx);
						}
					} else if (ev.type === "content") {
						messageModel.setProperty(lastIdx, "content", cur.content + ev.delta);
					} else if (ev.type === "think") {
						messageModel.setProperty(lastIdx, "thinkContent", cur.thinkContent + ev.delta);
					} else if (ev.type === "tool_need_approval") {
						agentProcess.awaitingApproval = true;
						agentProcess.awaitingApprovalId = ev.id;
						agentProcess.awaitingApprovalTool = ev.tool;
						agentProcess.awaitingApprovalInput = ev.input;
						messageModel.setProperty(lastIdx, "toolName", ev.tool);
						messageModel.setProperty(lastIdx, "toolInput", ev.input);
						messageModel.setProperty(lastIdx, "isRunningTool", false);
						messageModel.setProperty(lastIdx, "awaitingApproval", true);
						root.updateActiveStats();
					} else if (ev.type === "tool_start") {
						messageModel.setProperty(lastIdx, "toolName", ev.tool);
						messageModel.setProperty(lastIdx, "toolInput", ev.input);
						messageModel.setProperty(lastIdx, "isRunningTool", true);
						messageModel.setProperty(lastIdx, "awaitingApproval", false);
						root.updateActiveStats();
					} else if (ev.type === "tool_end") {
						messageModel.setProperty(lastIdx, "toolResult", ev.result || "");
						messageModel.setProperty(lastIdx, "isRunningTool", false);
						messageModel.setProperty(lastIdx, "isToolError", !!ev.isError);
						root.updateActiveStats();
					} else if (ev.type === "tool_denied") {
						messageModel.setProperty(lastIdx, "toolResult", "Tool execution was denied by user.");
						messageModel.setProperty(lastIdx, "isRunningTool", false);
						messageModel.setProperty(lastIdx, "isToolError", true);
						messageModel.setProperty(lastIdx, "awaitingApproval", false);
						root.updateActiveStats();
					} else if (ev.type === "error") {
						agentProcess.isExecuting = false;
						const errText = `\n\n**Error**: ${ev.message}`;
						messageModel.setProperty(lastIdx, "content", cur.content + errText);
						root.updateActiveStats();
						root.saveSessionsToDisk();
					} else if (ev.type === "done") {
						agentProcess.isExecuting = false;
						root.updateActiveStats();
						root.saveSessionsToDisk();
					}
					chatListView.positionViewAtEnd();
				} catch (err) {}
			}
		}
	}

	function executePrompt(text) {
		if (!text || text.trim().length === 0 || root.isBusy) return;

		const userPrompt = text.trim();
		inputArea.text = "";

		// Generate title automatically from first user prompt if still default
		if (root.activeSessionTitle === "New Conversation" || root.activeSessionTitle === "Chat" || messageModel.count <= 2) {
			const clean = userPrompt.replace(/\s+/g, " ").trim();
			root.activeSessionTitle = clean.length > 32 ? (clean.slice(0, 32) + "…") : clean;
			root.sessionsList = root.sessionsList.map(s => {
				if (s.id === root.activeSessionId) {
					return Object.assign({}, s, { title: root.activeSessionTitle });
				}
				return s;
			});
		}

		messageModel.append({
			role: "user",
			content: userPrompt,
			thinkContent: "",
			toolName: "",
			toolInput: ({}),
			toolResult: "",
			isRunningTool: false,
			isToolError: false,
			awaitingApproval: false
		});

		messageModel.append({
			role: "assistant",
			content: "",
			thinkContent: "",
			toolName: "",
			toolInput: ({}),
			toolResult: "",
			isRunningTool: false,
			isToolError: false,
			awaitingApproval: false
		});

		chatListView.positionViewAtEnd();

		const history = [];
		for (let i = 0; i < messageModel.count - 2; i++) {
			const item = messageModel.get(i);
			if (item.content)
				history.push({ role: item.role, content: item.content });
		}

		const cfg = providerConfig();
		const req = {
			type: "request",
			prompt: userPrompt,
			history: history,
			endpoint: cfg.endpoint,
			model: cfg.model,
			apiKey: cfg.apiKey,
			confirmTools: Config.options.background.widgets.aiAgent.confirmTools ?? true
		};

		agentProcess.isExecuting = true;
		agentProcess.pendingRequest = req;
		if (agentProcess.running) {
			agentProcess.write(JSON.stringify(req) + "\n");
		} else {
			agentProcess.running = true;
		}

		saveSessionsToDisk();
	}

	// ─── FLIP ANIMATION ─────────────────────────────────────────────────────────
	Item {
		id: cardWrapper
		anchors.fill: parent

		transform: Scale {
			id: flipScale
			origin.x: cardWrapper.width / 2
			origin.y: cardWrapper.height / 2
			xScale: 1
		}

		SequentialAnimation {
			id: flipAnim
			NumberAnimation {
				target: flipScale; property: "xScale"
				to: 0; duration: 140; easing.type: Easing.InQuad
			}
			ScriptAction {
				script: root.mode = root.targetNextMode
			}
			NumberAnimation {
				target: flipScale; property: "xScale"
				to: 1; duration: 140; easing.type: Easing.OutQuad
			}
		}

		StyledDropShadow { target: contentRect }

		Rectangle {
			id: contentRect
			anchors.fill: parent
			radius: Appearance.rounding?.verylarge ?? 24
			color: Appearance.colors.colLayer0
			border.width: 1
			border.color: root.isBusy ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border

			// ─── PAGE 1: SESSIONS LIST VIEW ─────────────────────────────────────────
			ColumnLayout {
				id: sessionsPage
				anchors.fill: parent
				anchors.margins: 14
				spacing: 10
				visible: root.mode === "sessions"

				// Header
				RowLayout {
					Layout.fillWidth: true
					spacing: 8

					Rectangle {
						implicitWidth: 36
						implicitHeight: 36
						radius: Appearance.rounding.full
						color: Appearance.colors.colPrimary

						MaterialSymbol {
							anchors.centerIn: parent
							iconSize: 22
							color: Appearance.colors.colOnPrimary
							text: "smart_toy"
						}
					}

					ColumnLayout {
						spacing: 0
						StyledText {
							font.pixelSize: Appearance.font.pixelSize.large
							font.weight: Font.DemiBold
							color: Appearance.colors.colOnLayer0
							text: "AI Agent Sessions"
						}
						StyledText {
							font.pixelSize: Appearance.font.pixelSize.smaller
							color: Appearance.colors.colSubtext
							text: `${providerConfig().model}`
						}
					}

					Item { Layout.fillWidth: true }

					// Settings Button
					ToolbarPairedFab {
						baseSize: 34
						iconText: "settings"
						onClicked: root.toggleFlip("settings")
					}

					// New Chat Button
					ToolbarPairedFab {
						baseSize: 34
						iconText: "add"
						onClicked: root.createNewSession(true)
					}
				}

				// Sessions ListView
				StyledListView {
					id: sessionsListView
					Layout.fillWidth: true
					Layout.fillHeight: true
					clip: true
					spacing: 8
					model: root.sessionsList

					delegate: SwipeDelegate {
						id: sessionCard
						required property var modelData
						required property int index

						width: sessionsListView.width
						implicitHeight: 64
						padding: 0
						background: null
						clip: true

						property bool isCurrent: modelData.id === root.activeSessionId

						onClicked: root.selectSession(modelData.id, true)

						contentItem: Rectangle {
							radius: Appearance.rounding.normal
							color: sessionCard.isCurrent ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
							border.width: sessionCard.isCurrent ? 1 : 0
							border.color: Appearance.colors.colPrimary
							width: parent.width - Math.abs(sessionCard.swipe.position) * 6

							RowLayout {
								anchors {
									fill: parent
									margins: 10
								}
								spacing: 10

								MaterialSymbol {
									iconSize: 22
									color: sessionCard.isCurrent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colPrimary
									text: "chat_bubble"
								}

								ColumnLayout {
									Layout.fillWidth: true
									spacing: 2

									StyledText {
										Layout.fillWidth: true
										font.pixelSize: Appearance.font.pixelSize.normal
										font.weight: Font.Medium
										color: sessionCard.isCurrent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer0
										text: modelData.title || "Untitled Session"
										elide: Text.ElideRight
									}

									RowLayout {
										spacing: 6

										StyledText {
											font.pixelSize: Appearance.font.pixelSize.smaller
											color: sessionCard.isCurrent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
											text: `💬 ${Array.isArray(modelData.messages) ? modelData.messages.length : 0} msgs`
										}

										StyledText {
											visible: root.countToolsInMessages(modelData.messages) > 0
											font.pixelSize: Appearance.font.pixelSize.smaller
											font.weight: Font.Medium
											color: sessionCard.isCurrent ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colTertiary
											text: `⚡ ${root.countToolsInMessages(modelData.messages)} tools`
										}
									}
								}

								MaterialSymbol {
									iconSize: 18
									color: Appearance.colors.colSubtext
									text: "chevron_right"
								}
							}
						}

						swipe.right: Rectangle {
							width: 60
							anchors.right: parent.right
							height: parent.height
							radius: Appearance.rounding.normal
							color: Appearance.colors.colError

							MaterialSymbol {
								anchors.centerIn: parent
								text: "delete"
								iconSize: Appearance.font.pixelSize.larger
								color: Appearance.colors.colOnError
							}

							SwipeDelegate.onClicked: root.deleteSession(sessionCard.modelData.id)
						}
					}
				}
			}

			// ─── PAGE 2: ACTIVE CHAT VIEW ───────────────────────────────────────────
			ColumnLayout {
				id: chatPage
				anchors.fill: parent
				anchors.margins: 12
				spacing: 8
				visible: root.mode === "chat"

				// Header
				RowLayout {
					Layout.fillWidth: true
					spacing: 6

					ToolbarPairedFab {
						baseSize: 32
						iconText: "arrow_back"
						onClicked: {
							root.saveSessionsToDisk();
							root.toggleFlip("sessions");
						}
					}

					ColumnLayout {
						spacing: 1
						StyledText {
							font.pixelSize: Appearance.font.pixelSize.normal
							font.weight: Font.DemiBold
							color: Appearance.colors.colOnLayer0
							text: root.activeSessionTitle
							elide: Text.ElideRight
							Layout.maximumWidth: 200
						}

						RowLayout {
							spacing: 5

							StyledText {
								font.pixelSize: Appearance.font.pixelSize.smaller
								color: root.isBusy ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
								text: root.activeStatus
							}

							StyledText {
								font.pixelSize: Appearance.font.pixelSize.smaller
								color: Appearance.colors.colSubtext
								text: "•"
							}

							StyledText {
								font.pixelSize: Appearance.font.pixelSize.smaller
								color: Appearance.colors.colSubtext
								text: `💬 ${root.activeSessionMessageCount}`
							}

							StyledText {
								visible: root.activeSessionToolCallsCount > 0
								font.pixelSize: Appearance.font.pixelSize.smaller
								font.weight: Font.Medium
								color: Appearance.colors.colTertiary
								text: `• ⚡ ${root.activeSessionToolCallsCount}`
							}
						}
					}

					Item { Layout.fillWidth: true }

					ToolbarPairedFab {
						baseSize: 32
						iconText: root.showLogsPanel ? "chat" : "terminal"
						onClicked: root.showLogsPanel = !root.showLogsPanel
					}

					ToolbarPairedFab {
						baseSize: 32
						iconText: "delete_sweep"
						onClicked: root.clearCurrentSession()
					}

					ToolbarPairedFab {
						baseSize: 32
						iconText: "settings"
						onClicked: root.toggleFlip("settings")
					}
				}

				// Messages ListView
				StyledListView {
					id: chatListView
					visible: !root.showLogsPanel
					Layout.fillWidth: true
					Layout.fillHeight: true
					clip: true
					spacing: 10
					model: messageModel

					delegate: ColumnLayout {
						id: messageDelegate
						required property string role
						required property string content
						required property string thinkContent
						required property string toolName
						required property var toolInput
						required property string toolResult
						required property bool isRunningTool
						required property bool isToolError
						required property bool awaitingApproval

						width: chatListView.width
						spacing: 6

						// Thinking Accordion
						AiAgentThinkAccordion {
							visible: thinkContent.length > 0
							thinkingText: thinkContent
							isThinking: root.isBusy && content.length === 0
						}

						// Approval Card
						Rectangle {
							Layout.fillWidth: true
							visible: messageDelegate.awaitingApproval
							implicitHeight: approvalCol.implicitHeight + 16
							radius: Appearance.rounding.normal
							color: Appearance.colors.colTertiaryContainer
							border.width: 1
							border.color: Appearance.colors.colTertiary

							ColumnLayout {
								id: approvalCol
								anchors { fill: parent; margins: 10 }
								spacing: 6

								StyledText {
									font.pixelSize: Appearance.font.pixelSize.small
									font.weight: Font.Bold
									color: Appearance.colors.colOnTertiaryContainer
									text: `⚠️ Approval Required: Run ${messageDelegate.toolName}?`
								}

								StyledText {
									Layout.fillWidth: true
									font.pixelSize: Appearance.font.pixelSize.smaller
									font.family: Appearance.font.family.monospace
									color: Appearance.colors.colOnTertiaryContainer
									wrapMode: Text.WrapAnywhere
									text: JSON.stringify(messageDelegate.toolInput, null, 2)
								}

								RowLayout {
									spacing: 8
									ToolbarPairedFab {
										baseSize: 28
										iconText: "check"
										onClicked: agentProcess.respond(true)
									}
									ToolbarPairedFab {
										baseSize: 28
										iconText: "close"
										onClicked: agentProcess.respond(false)
									}
								}
							}
						}

						// Tool Accordion
						AiAgentToolAccordion {
							visible: toolName.length > 0 && !messageDelegate.awaitingApproval
							toolName: messageDelegate.toolName
							toolInput: messageDelegate.toolInput
							toolResult: messageDelegate.toolResult
							isRunning: messageDelegate.isRunningTool
							isError: messageDelegate.isToolError
						}

						// Message Bubble
						Rectangle {
							Layout.fillWidth: true
							visible: content.length > 0
							implicitHeight: messageCol.implicitHeight + 16
							radius: Appearance.rounding.normal
							color: role === "user" ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
							border.width: role === "user" ? 0 : 1
							border.color: Appearance.colors.colLayer0Border

							ColumnLayout {
								id: messageCol
								anchors {
									left: parent.left
									right: parent.right
									top: parent.top
									margins: 10
								}
								spacing: 6

								StyledText {
									id: messageText
									Layout.fillWidth: true
									font.pixelSize: Appearance.font.pixelSize.normal
									color: role === "user" ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
									wrapMode: Text.Wrap
									text: content
								}

								RowLayout {
									Layout.fillWidth: true
									spacing: 4

									Item { Layout.fillWidth: true }

									Rectangle {
										implicitWidth: 24
										implicitHeight: 24
										radius: Appearance.rounding.small
										color: copyMouseArea.containsMouse ? ColorUtils.transparentize(role === "user" ? Appearance.colors.colOnPrimary : Appearance.colors.colPrimary, 0.85) : "transparent"

										MaterialSymbol {
											anchors.centerIn: parent
											iconSize: 15
											color: role === "user" ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
											text: copyMouseArea.copied ? "check" : "content_copy"
										}

										MouseArea {
											id: copyMouseArea
											anchors.fill: parent
											hoverEnabled: true
											cursorShape: Qt.PointingHandCursor
											property bool copied: false
											Timer {
												id: copyTimer
												interval: 1500
												repeat: false
												onTriggered: copyMouseArea.copied = false
											}
											onClicked: {
												Quickshell.clipboardText = messageDelegate.content;
												copyMouseArea.copied = true;
												copyTimer.restart();
											}
										}
									}
								}
							}
						}
					}
				}

				// Live Logs Inspector Panel
				Rectangle {
					id: agentLogsPanel
					visible: root.showLogsPanel
					Layout.fillWidth: true
					Layout.fillHeight: true
					radius: Appearance.rounding.normal
					color: Appearance.colors.colLayer1
					border.width: 1
					border.color: Appearance.colors.colLayer0Border

					ColumnLayout {
						anchors.fill: parent
						anchors.margins: 10
						spacing: 6

						RowLayout {
							Layout.fillWidth: true
							spacing: 6

							MaterialSymbol {
								iconSize: 18
								color: Appearance.colors.colPrimary
								text: "terminal"
							}

							StyledText {
								Layout.fillWidth: true
								font.pixelSize: Appearance.font.pixelSize.small
								font.weight: Font.Bold
								color: Appearance.colors.colPrimary
								text: `Agent Runtime Logs (${agentLogModel.count} events)`
							}

							ToolbarPairedFab {
								baseSize: 26
								iconText: "delete"
								onClicked: agentLogModel.clear()
							}
						}

						StyledListView {
							id: agentLogsListView
							Layout.fillWidth: true
							Layout.fillHeight: true
							clip: true
							spacing: 6
							model: agentLogModel

							delegate: Rectangle {
								required property string time
								required property string level
								required property string text

								width: agentLogsListView.width
								implicitHeight: logCol.implicitHeight + 10
								radius: Appearance.rounding.small
								color: Appearance.colors.colLayer0

								RowLayout {
									id: logCol
									anchors {
										left: parent.left
										right: parent.right
										verticalCenter: parent.verticalCenter
										margins: 8
									}
									spacing: 8

									StyledText {
										font.pixelSize: Appearance.font.pixelSize.smaller
										font.family: Appearance.font.family.monospace
										color: Appearance.colors.colSubtext
										text: time
									}

									Rectangle {
										implicitHeight: 18
										implicitWidth: levelText.implicitWidth + 8
										radius: Appearance.rounding.full
										color: {
											if (level === "tool") return Appearance.colors.colTertiaryContainer;
											if (level === "error") return Appearance.colors.colErrorContainer;
											if (level === "warn") return Appearance.colors.colWarningContainer;
											if (level === "done") return Appearance.colors.colSecondaryContainer;
											return Appearance.colors.colPrimaryContainer;
										}

										StyledText {
											id: levelText
											anchors.centerIn: parent
											font.pixelSize: 10
											font.weight: Font.Bold
											color: {
												if (level === "tool") return Appearance.colors.colOnTertiaryContainer;
												if (level === "error") return Appearance.colors.colOnErrorContainer;
												if (level === "warn") return Appearance.colors.colOnWarningContainer;
												if (level === "done") return Appearance.colors.colOnSecondaryContainer;
												return Appearance.colors.colOnPrimaryContainer;
											}
											text: level.toUpperCase()
										}
									}

									StyledText {
										Layout.fillWidth: true
										font.pixelSize: Appearance.font.pixelSize.smaller
										font.family: Appearance.font.family.monospace
										color: Appearance.colors.colOnLayer0
										wrapMode: Text.WrapAnywhere
										text: text
									}
								}
							}
						}
					}
				}

				// Input Area
				Rectangle {
					Layout.fillWidth: true
					implicitHeight: Math.min(100, Math.max(44, inputArea.implicitHeight + 14))
					radius: Appearance.rounding.normal
					color: Appearance.colors.colLayer1
					border.width: 1
					border.color: inputArea.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border

					TapHandler {
						onTapped: {
							// Claim keyboard grab first, then focus — order matters
							GlobalStates.desktopWidgetKeyboardFocus = true;
							inputArea.forceActiveFocus();
						}
					}

					RowLayout {
						anchors.fill: parent
						anchors.margins: 6
						spacing: 6

						ScrollView {
							Layout.fillWidth: true
							Layout.fillHeight: true

							TextArea {
								id: inputArea
								placeholderText: "Ask agent or execute a command…"
								placeholderTextColor: Appearance.colors.colSubtext
								color: Appearance.colors.colOnLayer0
								font.pixelSize: Appearance.font.pixelSize.normal
								wrapMode: TextEdit.Wrap
								selectByMouse: true
								background: null
								onActiveFocusChanged: {
									GlobalStates.desktopWidgetKeyboardFocus = activeFocus;
								}
								onTextChanged: {
									draftSaveTimer.restart();
								}
								Keys.onReturnPressed: (event) => {
									if (event.modifiers & Qt.ShiftModifier) {
										event.accepted = false;
									} else {
										event.accepted = true;
										root.executePrompt(inputArea.text);
									}
								}
								Keys.onEscapePressed: {
									inputArea.focus = false;
									GlobalStates.desktopWidgetKeyboardFocus = false;
								}
							}
						}

						ToolbarPairedFab {
							baseSize: 34
							iconText: "content_paste"
							onClicked: {
								inputArea.text += (Quickshell.clipboardText || "");
								inputArea.cursorPosition = inputArea.text.length;
								inputArea.forceActiveFocus();
							}
						}

						ToolbarPairedFab {
							baseSize: 34
							iconText: root.isBusy ? "stop" : "arrow_upward"
							onClicked: {
								if (root.isBusy) {
									agentProcess.running = false;
									agentProcess.isExecuting = false;
								} else {
									root.executePrompt(inputArea.text);
								}
							}
						}
					}
				}
			}

			// ─── PAGE 3: IN-WIDGET SETTINGS VIEW ────────────────────────────────────
			ColumnLayout {
				id: settingsPage
				anchors.fill: parent
				anchors.margins: 14
				spacing: 12
				visible: root.mode === "settings"

				RowLayout {
					Layout.fillWidth: true
					spacing: 8

					ToolbarPairedFab {
						baseSize: 32
						iconText: "arrow_back"
						onClicked: root.toggleFlip(root.previousMode || "sessions")
					}

					StyledText {
						font.pixelSize: Appearance.font.pixelSize.large
						font.weight: Font.DemiBold
						color: Appearance.colors.colOnLayer0
						text: "AI Agent Settings"
					}
				}

				ScrollView {
					Layout.fillWidth: true
					Layout.fillHeight: true

					ColumnLayout {
						width: settingsPage.width - 28
						spacing: 12

						StyledText {
							font.pixelSize: Appearance.font.pixelSize.small
							font.weight: Font.Bold
							color: Appearance.colors.colPrimary
							text: "LLM Provider:"
						}

						RowLayout {
							Layout.fillWidth: true
							spacing: 6

							Repeater {
								model: [
									{ id: "opencode", label: "🌟 OpenCode" },
									{ id: "9router",  label: "🚀 9Router" },
									{ id: "ollama",   label: "🦙 Ollama" },
									{ id: "custom",   label: "🌐 Custom" }
								]
								delegate: Rectangle {
									required property var modelData
									implicitHeight: 32
									Layout.fillWidth: true
									radius: Appearance.rounding.small
									color: (Config.options.background.widgets.aiAgent.provider === modelData.id)
										? Appearance.colors.colPrimary
										: Appearance.colors.colLayer1
									border.width: 1
									border.color: (Config.options.background.widgets.aiAgent.provider === modelData.id)
										? Appearance.colors.colPrimary
										: Appearance.colors.colLayer0Border

									StyledText {
										anchors.centerIn: parent
										font.pixelSize: Appearance.font.pixelSize.smaller
										font.weight: Font.Medium
										color: (Config.options.background.widgets.aiAgent.provider === modelData.id)
											? Appearance.colors.colOnPrimary
											: Appearance.colors.colOnLayer0
										text: modelData.label
									}

									MouseArea {
										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										onClicked: {
											Config.options.background.widgets.aiAgent.provider = modelData.id;
											if (modelData.id === "opencode") {
												Config.options.background.widgets.aiAgent.model = "hy3-free";
											} else if (modelData.id === "9router") {
												Config.options.background.widgets.aiAgent.model = "ag/claude-sonnet-4-6";
											}
											root.fetchLiveModels();
										}
									}
								}
							}
						}

						RowLayout {
							Layout.fillWidth: true
							spacing: 6

							StyledText {
								Layout.fillWidth: true
								font.pixelSize: Appearance.font.pixelSize.small
								font.weight: Font.Bold
								color: Appearance.colors.colPrimary
								text: "Select Model (Live Dropdown & Search):"
							}

							ToolbarPairedFab {
								baseSize: 26
								iconText: "refresh"
								onClicked: root.fetchLiveModels()
							}
						}

						// Live Model Dropdown if fetched
						StyledComboBoxSearch {
							id: liveModelCombo
							Layout.fillWidth: true
							visible: root.availableModelsList.length > 0
							model: root.availableModelsList
							displayText: Config.options.background.widgets.aiAgent.model || (root.availableModelsList.length > 0 ? root.availableModelsList[0] : "Select model...")
							onActivated: (idx) => {
								if (idx >= 0 && idx < root.availableModelsList.length) {
									Config.options.background.widgets.aiAgent.model = root.availableModelsList[idx];
								}
							}
						}

						StyledText {
							font.pixelSize: Appearance.font.pixelSize.small
							font.weight: Font.Bold
							color: Appearance.colors.colPrimary
							text: "Quick Presets & Manual Model ID:"
						}

						// Preset model quick chips
						Flow {
							Layout.fillWidth: true
							spacing: 6

							property var currentPresets: {
								const p = Config.options.background.widgets.aiAgent.provider || "opencode";
								if (p === "opencode") return ["hy3-free", "nemotron-3.5-lightning-free", "ling-3.0-flash-fin-free", "qwen2.5-72b-instruct"];
								if (p === "9router") return ["ag/gemini-3.7-flash-high", "ag/claude-sonnet-4-6", "ag/deepseek-r1", "ag/gpt-4o"];
								if (p === "ollama") return ["qwen2.5:3b-instruct", "llama3.2:3b", "deepseek-r1:7b"];
								return [];
							}

							Repeater {
								model: parent.currentPresets
								delegate: Rectangle {
									required property var modelData
									implicitHeight: 26
									implicitWidth: chipText.implicitWidth + 16
									radius: Appearance.rounding.full
									color: (Config.options.background.widgets.aiAgent.model === modelData)
										? Appearance.colors.colSecondaryContainer
										: Appearance.colors.colLayer1
									border.width: 1
									border.color: (Config.options.background.widgets.aiAgent.model === modelData)
										? Appearance.colors.colSecondary
										: Appearance.colors.colLayer0Border

									StyledText {
										id: chipText
										anchors.centerIn: parent
										font.pixelSize: Appearance.font.pixelSize.smaller
										font.weight: Font.Medium
										color: (Config.options.background.widgets.aiAgent.model === modelData)
											? Appearance.colors.colOnSecondaryContainer
											: Appearance.colors.colOnLayer0
										text: modelData
									}

									MouseArea {
										anchors.fill: parent
										cursorShape: Qt.PointingHandCursor
										onClicked: {
											Config.options.background.widgets.aiAgent.model = modelData;
										}
									}
								}
							}
						}

						Rectangle {
							Layout.fillWidth: true
							implicitHeight: 38
							radius: Appearance.rounding.small
							color: Appearance.colors.colLayer1
							border.width: 1
							border.color: Appearance.colors.colLayer0Border

							TextInput {
								anchors { fill: parent; margins: 8 }
								color: Appearance.colors.colOnLayer0
								font.pixelSize: Appearance.font.pixelSize.normal
								text: Config.options.background.widgets.aiAgent.model ?? "hy3-free"
								onTextChanged: Config.options.background.widgets.aiAgent.model = text
							}
						}

						StyledText {
							font.pixelSize: Appearance.font.pixelSize.small
							font.weight: Font.Bold
							color: Appearance.colors.colPrimary
							text: "API Key (optional for OpenCode Free):"
						}

						Rectangle {
							Layout.fillWidth: true
							implicitHeight: 38
							radius: Appearance.rounding.small
							color: Appearance.colors.colLayer1
							border.width: 1
							border.color: Appearance.colors.colLayer0Border

							TextInput {
								anchors { fill: parent; margins: 8 }
								color: Appearance.colors.colOnLayer0
								font.pixelSize: Appearance.font.pixelSize.normal
								echoMode: TextInput.Password
								text: Config.options.background.widgets.aiAgent.apiKey ?? ""
								onTextChanged: Config.options.background.widgets.aiAgent.apiKey = text
							}
						}

						RowLayout {
							Layout.fillWidth: true
							spacing: 8

							StyledText {
								Layout.fillWidth: true
								font.pixelSize: Appearance.font.pixelSize.small
								color: Appearance.colors.colOnLayer0
								text: "Confirm dangerous tools (Bash, File write, Hyprland)"
							}

							ConfigSwitch {
								checked: Config.options.background.widgets.aiAgent.confirmTools ?? true
								onCheckedChanged: Config.options.background.widgets.aiAgent.confirmTools = checked
							}
						}
					}
				}
			}
		}
	}
}
