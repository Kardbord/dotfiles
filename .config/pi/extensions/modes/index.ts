/**
 * Modes extension: build / read / plan.
 *
 * - `build` (default) — full access, out-of-the-box behavior.
 * - `read` — read-only: research the codebase and web, answer questions,
 *   ask clarifying questions. No changes of any kind.
 * - `plan` — superset of read: same research abilities, but the goal is to
 *   produce a detailed implementation plan to be executed later, after the
 *   user switches back to build mode.
 *
 * Controls:
 * - `Tab` cycles build → read → plan → build
 * - `/mode` cycles, `/mode <build|read|plan>` sets a specific mode
 * - CLI flags: `--read`, `--plan` start the session in that mode
 * - Status indicator in the footer always shows the current mode
 *
 * Enforcement in read/plan mode:
 * - a per-mode tool selection is computed (see Configuration below) and set
 *   as the active tool set
 * - the tool_call handler blocks anything not in that selection
 *
 * The bash tool is disabled entirely by the separate no-bash extension.
 *
 * Configuration (extensions/modes/config.json, next to this file):
 *
 *   {
 *     "read": { "tools": ["+actionlint", "-mcp__exa*"] },
 *     "plan": { "tools": ["+go_test"] },
 *     "build": { "tools": ["-mcp__filesystem*"] }
 *   }
 *
 * Subagent propagation: a subagent launched from a read/plan session carries
 * the current mode to the child via extension bindings; the child's copy of
 * this extension restores it at session_start, so the child enforces the same
 * read-only selection. Foreground (`async: false`) children are blocked in
 * read/plan mode because they run in-process without ambient extensions and
 * the mode could not be enforced there. An optional per-mode allowlist
 * restricts which agents may be launched (unset = all agents allowed):
 *
 *   "read": { "subagents": { "allow": ["reviewer"] } }
 *
 * A missing or unparseable config file means "no configuration" and falls
 * back to the read-only defaults (below); it can never widen permissions.
 *
 * Tool-list semantics follow `defaultTools`: plain names or `*` patterns
 * replace the mode's default selection, `+pat` adds tools, `-pat` removes
 * them. With no configuration, read/plan fall back to pi's read-only built-in
 * defaults (below) and build keeps the session's normal tools. An explicit
 * configuration is authoritative for that mode: it can re-enable tools the
 * defaults would block ("edit", MCP tools, etc.).
 */

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { AgentMessage } from "@earendil-works/pi-agent-core";
import type { TextContent } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type Mode = "build" | "read" | "plan";

const CYCLE: Mode[] = ["build", "read", "plan"];

const MARKERS: Record<Mode, string> = {
	build: "",
	read: "[READ MODE ACTIVE]",
	plan: "[PLAN MODE ACTIVE]",
};

// Fallback when a mode has no configured tool list: pi's own read-only
// built-in tools only. Script tools and MCP tools are environment-specific
// and are opt-in via the per-mode config (or generic `readOnlyHint`
// annotations); the extension hardcodes nothing about them.
const PI_READ_ONLY_TOOLS = new Set(["read", "grep", "find", "ls", "tool_search"]);

// Pi built-in tools that are write-capable (or reach write-capable tools via
// codemode scripts): excluded from the fallback selection in read/plan mode.
// An explicit per-mode configuration in config.json overrides this.
const HARD_BLOCKED_TOOLS = new Set(["edit", "write", "bash", "powershell", "codemode"]);

const READ_CONTEXT = `[READ MODE ACTIVE]
You are in read mode — a strictly read-only mode for research and Q&A.

What you can do:
- Read files and search the codebase.
- Use read-only MCP tools (docs lookup, web search) for research.
- Answer questions with well-sourced findings: cite file paths (and line
  numbers where helpful).

What you must do:
- If the request is ambiguous or missing context, ask clarifying questions
  before diving deep.
- Do NOT attempt to create, modify, or delete anything. Edit/write tools are
  disabled. If the user wants changes made, tell them to switch to build
  mode (Tab cycles modes) — or to plan mode if they first want a plan.

Note: script tools (e.g. go_test, jq) execute project code and take freeform
string arguments that are not path-checked — "read-only" here means no direct
file modifications, not sandboxing. In particular, go_build may write build
outputs (e.g. a compiled binary) into the working tree.`;

const PLAN_CONTEXT = `[PLAN MODE ACTIVE]
You are in plan mode — a strictly read-only mode whose goal is to produce an
implementation plan that the user will execute later in build mode.

What you can do (same as read mode):
- Read files, search the codebase, and consult docs and the web via
  read-only MCP tools.
- Ask clarifying questions whenever requirements are unclear or ambiguous.

What you must produce:
- A detailed, step-by-step implementation plan under a "Plan:" header, with
  numbered steps: which files to change, the approach for each step, risks
  and trade-offs, and how to verify the result.

What you must NOT do:
- Do NOT implement anything. Edit/write tools are disabled. Changes happen
  after the user presses Tab to return to build mode and asks you to
  execute the plan.

Note: script tools (e.g. go_test, jq) execute project code and take freeform
string arguments that are not path-checked — plan mode forbids direct file
modifications but is not a sandbox. In particular, go_build may write build
outputs (e.g. a compiled binary) into the working tree.`;

// Glob helper: `mcp__github__*` matches any suffix, plain names match exactly.
function matchPattern(pattern: string, name: string): boolean {
	if (!pattern.includes("*")) return pattern === name;
	const re = new RegExp(
		"^" + pattern.split("*").map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(".*") + "$",
	);
	return re.test(name);
}

// Extension-owned config file, resolved next to this source file (immune to
// PI_CODING_AGENT_DIR changes). Read fresh on each mode resolution so edits
// apply on the next mode switch without a restart.
const CONFIG_PATH = join(dirname(fileURLToPath(import.meta.url)), "config.json");

// Extension-bindings namespace used to propagate the current mode to subagent
// children. The child's copy of this extension reads it back from
// PI_SUBAGENT_EXTENSION_BINDINGS at session_start (see modeFromBindings).
const MODE_BINDING_KEY = "modes/1";

type ModesConfig = Partial<Record<Mode, { tools?: string[]; subagents?: { allow?: string[] } }>>;

function loadModeConfig(): ModesConfig {
	try {
		return JSON.parse(readFileSync(CONFIG_PATH, "utf8")) as ModesConfig;
	} catch {
		return {};
	}
}

function modeToolEntries(_pi: ExtensionAPI, target: Mode): string[] | undefined {
	const tools = loadModeConfig()[target]?.tools;
	return Array.isArray(tools) ? tools.map(String) : undefined;
}

/**
 * Fallback safety net: is a tool allowed in read/plan mode when the mode has
 * no configured tool list? Only pi's read-only built-ins pass, plus any tool
 * (e.g. MCP) that declares `readOnlyHint: true`.
 */
function isReadOnlyTool(pi: ExtensionAPI, name: string): boolean {
	if (HARD_BLOCKED_TOOLS.has(name)) return false;
	if (PI_READ_ONLY_TOOLS.has(name)) return true;
	const meta = pi.getAllTools().find((t) => t.name === name);
	if (meta?.annotations?.readOnlyHint === true) return true;
	return false;
}

function readOnlyToolNames(pi: ExtensionAPI, names: string[]): string[] {
	return [...new Set(names.filter((name) => isReadOnlyTool(pi, name)))];
}

/**
 * Mode propagated from a parent session via subagent extension bindings.
 * Invalid or missing data means "no propagation" and falls through to the
 * normal session-restore defaults; it can never widen permissions on its own.
 */
function modeFromBindings(): Mode | undefined {
	try {
		const raw = process.env.PI_SUBAGENT_EXTENSION_BINDINGS;
		if (!raw) return undefined;
		const parsed = JSON.parse(raw) as Record<string, unknown>;
		const m = (parsed?.[MODE_BINDING_KEY] as { mode?: unknown } | undefined)?.mode;
		return m === "read" || m === "plan" || m === "build" ? m : undefined;
	} catch {
		return undefined;
	}
}

/**
 * Resolve the active tool set for a mode.
 *
 * No config: the mode's safe subset of `base` (read-only defaults for
 * read/plan; unchanged base for build).
 * With config: plain entries replace the selection (matched against all
 * registered tools, so config can enable tools that aren't active in build
 * mode), then `+pat` adds and `-pat` removes.
 */
function resolveModeTools(pi: ExtensionAPI, target: Mode, base: string[]): string[] {
	const entries = modeToolEntries(pi, target);
	if (!entries || entries.length === 0) {
		return target === "build" ? [...base] : [...new Set(base.filter((name) => isReadOnlyTool(pi, name)))];
	}

	const all = pi.getAllTools().map((t) => t.name);
	const plain = entries.filter((e) => !e.startsWith("+") && !e.startsWith("-"));
	// Delta entries apply on top of the mode's default selection (the raw tool
	// set for build, the read-only subset for read/plan); plain entries replace
	// it entirely.
	const defaultSelection = target === "build" ? [...base] : readOnlyToolNames(pi, base);
	let selection: string[] = plain.length ? all.filter((n) => plain.some((p) => matchPattern(p, n))) : defaultSelection;

	for (const entry of entries) {
		if (entry.startsWith("+")) {
			selection = selection.concat(all.filter((n) => matchPattern(entry.slice(1), n)));
		} else if (entry.startsWith("-")) {
			selection = selection.filter((n) => !matchPattern(entry.slice(1), n));
		}
	}
	return [...new Set(selection)];
}

// --- Extension ---

export default function modesExtension(pi: ExtensionAPI): void {
	let mode: Mode = "build";
	let savedTools: string[] | undefined;
	let modeAllowedTools: Set<string> | undefined;

	pi.registerFlag("read", {
		description: "Start in read mode (read-only research and Q&A)",
		type: "boolean",
		default: false,
	});
	pi.registerFlag("plan", {
		description: "Start in plan mode (read-only planning)",
		type: "boolean",
		default: false,
	});

	function updateStatus(ctx: ExtensionContext): void {
		if (!ctx.hasUI) return;
		const labels: Record<Mode, { text: string; color: "muted" | "accent" | "warning" }> = {
			build: { text: "◆ build", color: "muted" },
			read: { text: "◇ read", color: "accent" },
			plan: { text: "◇ plan", color: "warning" },
		};
		const { text, color } = labels[mode];
		ctx.ui.setStatus("modes", ctx.ui.theme.fg(color, text));
	}

	function applyMode(ctx: ExtensionContext, notify: boolean): void {
		if (mode === "build") {
			if (savedTools) {
				pi.setActiveTools(resolveModeTools(pi, "build", savedTools));
				savedTools = undefined;
			} else if (modeToolEntries(pi, "build")?.length) {
				// Session starts in build mode with a configured build tool list.
				pi.setActiveTools(resolveModeTools(pi, "build", pi.getActiveTools()));
			}
			modeAllowedTools = undefined;
		} else {
			if (!savedTools) savedTools = pi.getActiveTools();
			const selection = resolveModeTools(pi, mode, savedTools);
			pi.setActiveTools(selection);
			modeAllowedTools = new Set(selection);
		}
		updateStatus(ctx);
		pi.appendEntry("modes", { mode, savedTools });
		if (notify && ctx.hasUI) {
			ctx.ui.notify(
				mode === "build"
					? "Build mode: full access restored."
					: `${mode[0].toUpperCase()}${mode.slice(1)} mode: read-only${mode === "plan" ? ", produce a plan" : ""}.`,
				mode === "build" ? "info" : "warning",
			);
		}
	}

	function setMode(next: Mode, ctx: ExtensionContext): void {
		if (next === mode) {
			updateStatus(ctx);
			return;
		}
		mode = next;
		applyMode(ctx, true);
	}

	function cycleMode(ctx: ExtensionContext): void {
		setMode(CYCLE[(CYCLE.indexOf(mode) + 1) % CYCLE.length], ctx);
	}

	// Tab: cycle modes (tui.input.tab is unbound via keybindings.json)
	pi.registerShortcut("tab", {
		description: "Cycle mode: build → read → plan → build",
		handler: async (ctx) => cycleMode(ctx),
	});

	pi.registerCommand("mode", {
		description: "Show or set mode: /mode [build|read|plan] (no arg cycles)",
		handler: async (args, ctx) => {
			const arg = args.trim().toLowerCase();
			if (!arg) {
				cycleMode(ctx);
				return;
			}
			if (CYCLE.includes(arg as Mode)) {
				setMode(arg as Mode, ctx);
				return;
			}
			if (ctx.hasUI) {
				ctx.ui.notify(`Unknown mode "${arg}". Usage: /mode [build|read|plan]`, "error");
			}
		},
	});

	/**
	 * In read/plan mode, propagate the current mode to a subagent child:
	 * merge it into the launch's extension bindings (the child's copy of this
	 * extension restores it in session_start), and refuse launches that cannot
	 * be enforced. Returns a block result, or undefined when the launch may
	 * proceed (with input mutated in place).
	 */
	function handleSubagentCall(event: { input: unknown }): { block: true; reason: string } | undefined {
		if (typeof event.input !== "object" || event.input === null) return undefined;
		const input = event.input as {
			agent?: unknown;
			async?: unknown;
			options?: { extensionBindings?: unknown } & Record<string, unknown>;
		};

		const agent = typeof input.agent === "string" ? input.agent : undefined;
		const allow = loadModeConfig()[mode]?.subagents?.allow;
		if (allow && agent && !allow.some((pattern) => matchPattern(pattern, agent))) {
			return {
				block: true,
				reason: `Mode "${mode}" restricts subagents to: ${allow.join(", ")}. "${agent}" is blocked.\nPress Tab to switch to build mode to use it.`,
			};
		}

		if (input.async === false) {
			return {
				block: true,
				reason: `Mode "${mode}" is read-only: foreground (async: false) subagents run in-process without ambient extensions, so the mode cannot be enforced in the child.\nRelaunch the subagent with async: true (the default), or switch to build mode.`,
			};
		}

		const options = input.options ?? (input.options = {});
		const existing = options.extensionBindings;
		const bindings: Record<string, unknown> =
			existing && typeof existing === "object" && !Array.isArray(existing)
				? { ...(existing as Record<string, unknown>) }
				: {};
		const prior = bindings[MODE_BINDING_KEY];
		bindings[MODE_BINDING_KEY] = {
			...(prior && typeof prior === "object" && !Array.isArray(prior) ? (prior as Record<string, unknown>) : {}),
			mode,
		};
		options.extensionBindings = bindings;
		return undefined;
	}

	// Block anything that slips through the active-tool filter, and propagate
	// the current mode to subagent children.
	pi.on("tool_call", async (event) => {
		if (mode === "build") return;

		if (event.toolName === "subagent") {
			const blocked = handleSubagentCall(event);
			if (blocked) return blocked;
		}

		// Enforce the mode's resolved selection (falls back to the read-only
		// subset of the current active tools if the selection isn't computed
		// yet, e.g. before restore). The check is strictly selection-based: a
		// tool deliberately excluded by the mode config stays excluded even if
		// it advertises readOnlyHint.
		const allowed = modeAllowedTools ?? new Set(readOnlyToolNames(pi, pi.getActiveTools()));
		if (!allowed.has(event.toolName)) {
			return {
				block: true,
				reason: `Mode "${mode}" is read-only: tool "${event.toolName}" is blocked.\nPress Tab to switch to build mode to make changes.`,
			};
		}
	});

	// Drop stale mode-context messages; the fresh one is injected per prompt.
	pi.on("context", async (event) => {
		let changed = false;
		const messages = event.messages.filter((m) => {
			const msg = m as AgentMessage & { customType?: string };
			if (msg?.customType !== "modes-context") return true;
			const text = messageText(msg);
			const keep = mode !== "build" && text.includes(MARKERS[mode]);
			if (!keep) changed = true;
			return keep;
		});
		if (changed) return { messages };
	});

	// Inject mode-specific instructions ahead of each user prompt.
	pi.on("before_agent_start", async (event) => {
		if (event.messageType !== "user") return;
		if (mode === "build") return;
		return {
			message: {
				customType: "modes-context",
				content: MARKERS[mode] + "\n" + (mode === "read" ? READ_CONTEXT : PLAN_CONTEXT),
				display: false,
			},
		};
	});

	// Restore mode (and tools) on session start / resume.
	pi.on("session_start", async (_event, ctx) => {
		const flagMode: Mode | undefined =
			pi.getFlag("plan") === true ? "plan" : pi.getFlag("read") === true ? "read" : undefined;

		const entries = ctx.sessionManager.getEntries();
		const last = entries
			.filter((e: { type: string; customType?: string }) => e.type === "custom" && e.customType === "modes")
			.pop() as { data?: { mode?: Mode; savedTools?: string[] } } | undefined;

		// Precedence: explicit CLI flag > session restore (the child's own
		// persisted mode) > parent-propagated binding > build. The persisted mode
		// is authoritative: if the binding env var ever leaks into a resume, a
		// child the user switched to a different mode must not be reverted.
		// Fresh launches have no persisted mode, so the binding still applies.
		mode = flagMode ?? last?.data?.mode ?? modeFromBindings() ?? "build";
		savedTools = last?.data?.savedTools;

		applyMode(ctx, false);
	});
}

function messageText(message: unknown): string {
	const content = (message as { content?: unknown })?.content;
	if (typeof content === "string") return content;
	if (Array.isArray(content)) {
		return content
			.filter((c): c is TextContent => (c as { type?: string })?.type === "text")
			.map((c) => c.text)
			.join("\n");
	}
	return "";
}
