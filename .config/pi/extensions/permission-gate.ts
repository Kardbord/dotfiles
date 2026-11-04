/**
 * permission-gate — deny-by-default gating for every tool call.
 *
 * Every tool — pi built-ins, MCP tools, script-tools, and tools from other
 * extensions — requires user approval unless it is allowlisted. This covers
 * direct model calls, nested calls (e.g. from codemode scripts), and MCP
 * calls alike, because all of them pass through the `tool_call` pipeline.
 *
 * Configuration lives in `permissions.json` in the agent directory (next to
 * settings.json). It is explicit about what is being configured:
 *
 *   {
 *     "toolCalls": {
 *       "allow": [
 *         "read",            // pi built-in tools by name
 *         "jq",              // script tools by name
 *         "mcp__github__*"   // MCP tools; trailing * is a prefix wildcard
 *       ]
 *     }
 *   }
 *
 * - A missing or malformed config gates everything (fail closed).
 * - Without a UI (print/JSON mode), gated calls are blocked.
 * - The prompt offers a per-session grant ("Allow for this session"); the
 *   grant is held in memory only and cleared whenever a session starts.
 *
 * Unknown-entry validation is MCP-aware: `mcp.json` servers connect in the
 * background after `session_start`, so `mcp__<server>` entries are validated
 * against the configured server names instead of registered tools, and any
 * remaining unknowns are re-checked once at the first tool call.
 *
 * Reload the config with /permissions-reload.
 */

import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";

import type {
	ExtensionAPI,
	ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

const CONFIG_PATH = path.join(
	process.env.PI_CODING_AGENT_DIR ?? path.join(homedir(), ".pi", "agent"),
	"permissions.json",
);

const MAX_SUMMARY_CHARS = 300;

function makeAllowlistMatcher(entries: string[]): (name: string) => boolean {
	const exact = new Set<string>();
	const prefixes: string[] = [];
	for (const entry of entries) {
		if (entry.endsWith("*")) prefixes.push(entry.slice(0, -1));
		else exact.add(entry);
	}
	return (name) => exact.has(name) || prefixes.some((p) => name.startsWith(p));
}

function mcpEntryServer(entry: string): string | null {
	if (!entry.startsWith("mcp__")) return null;
	const rest = entry.slice("mcp__".length);
	const sep = rest.indexOf("__");
	if (sep !== -1) return rest.slice(0, sep);
	return rest.endsWith("*") ? rest.slice(0, -1) : rest;
}

/**
 * Server names configured in mcp.json (agent dir, plus project dir for
 * trusted projects, mirroring what pi itself honors). Read for validation
 * only, so a missing or unreadable file just means no known names; the
 * allowlist itself is unaffected.
 */
async function configuredMcpServers(sessionCwd?: string, projectTrusted?: boolean): Promise<Set<string>> {
	const names = new Set<string>();
	const files = [
		path.join(path.dirname(CONFIG_PATH), "mcp.json"),
		...(sessionCwd && projectTrusted ? [path.join(sessionCwd, ".pi", "mcp.json")] : []),
	];
	for (const file of files) {
		try {
			const parsed: unknown = JSON.parse(await readFile(file, "utf8"));
			const map = (parsed as { mcpServers?: unknown } | null)?.mcpServers;
			if (map === null || typeof map !== "object" || Array.isArray(map)) continue;
			for (const [name, config] of Object.entries(map)) {
				if (config !== null && typeof config === "object" && (config as { enabled?: unknown }).enabled !== false) {
					names.add(name);
				}
			}
		} catch {
			// Best-effort.
		}
	}
	return names;
}

function describeInput(input: unknown): string {
	if (input && typeof input === "object") {
		const obj = input as Record<string, unknown>;
		if (typeof obj.command === "string") return obj.command;
		if (typeof obj.args === "string") return obj.args;
		if (typeof obj.path === "string") return obj.path;
	}
	const json = JSON.stringify(input) ?? "";
	return json.length > MAX_SUMMARY_CHARS ? `${json.slice(0, MAX_SUMMARY_CHARS)}…` : json;
}

export default function extension(pi: ExtensionAPI) {
	const problems: string[] = [];
	const unknownEntries: string[] = [];
	const sessionGrants = new Set<string>();
	let allowCount = 0;
	let lateCheckDone = false;
	let isAllowed = (_name: string): boolean => false;

	async function loadConfig(ctx?: ExtensionCommandContext): Promise<string> {
		problems.length = 0;
		const allow: string[] = [];
		try {
			const parsed: unknown = JSON.parse(await readFile(CONFIG_PATH, "utf8"));
			const root = parsed as { toolCalls?: { allow?: unknown } } | null;
			if (root !== null && typeof root === "object" && !Array.isArray(root)) {
				const rawAllow = root.toolCalls?.allow;
				if (rawAllow === undefined) {
					// Absent section: nothing is allowlisted (gate everything).
				} else if (Array.isArray(rawAllow)) {
					allow.push(...rawAllow.filter((n): n is string => typeof n === "string"));
				} else {
					problems.push(`"toolCalls.allow" must be an array of tool names`);
				}
			} else {
				problems.push(`expected an object with a "toolCalls.allow" array`);
			}
		} catch (err) {
			if ((err as { code?: string } | null)?.code === "ENOENT") {
				problems.push(`not found (everything is gated)`);
			} else {
				problems.push(err instanceof Error ? err.message : String(err));
			}
		}
		isAllowed = makeAllowlistMatcher(allow);
		allowCount = allow.length;

		// Best-effort warning for entries that match no known tool. MCP tools
		// register asynchronously once their server connects (after
		// session_start), so `mcp__<server>` entries are validated against the
		// servers configured in mcp.json instead; anything else that is still
		// unknown gets re-checked at the first tool call.
		lateCheckDone = false;
		unknownEntries.length = 0;
		const known = new Set<string>();
		try {
			for (const tool of pi.getAllTools()) known.add(tool.name);
		} catch {
			// Validation is best-effort.
		}
		const mcpServers = await configuredMcpServers(ctx?.cwd, ctx?.isProjectTrusted());
		for (const entry of allow) {
			const base = entry.endsWith("*") ? entry.slice(0, -1) : entry;
			if (![...known].some((n) => n.startsWith(base))) unknownEntries.push(entry);
		}
		const unmatched = unknownEntries.filter((entry) => {
			const server = mcpEntryServer(entry);
			return server === null || !mcpServers.has(server);
		});

		const warnings = [...problems, ...unmatched.map((e) => `"${e}" does not match any known tool (yet?)`)];
		let msg = `permission-gate: ${allowCount} allow ${allowCount === 1 ? "entry" : "entries"} from ${CONFIG_PATH}`;
		if (warnings.length > 0) {
			msg += `\n${warnings.map((p) => `  ! ${p}`).join("\n")}`;
		}
		if (ctx?.hasUI) await ctx.ui.notify(msg, warnings.length > 0 ? "warning" : "info");
		return msg;
	}

	/**
	 * Once-only re-check of entries still unknown after loading. By the first
	 * tool call, everything that registers in this session (MCP tools whose
	 * servers connected, script tools from later-loaded extensions, ...) has
	 * registered. Entries that became known are cleared; entries that are
	 * still unknown are reported once.
	 */
	async function recheckUnknownEntries(ctx: ExtensionCommandContext): Promise<void> {
		if (lateCheckDone || unknownEntries.length === 0) return;
		lateCheckDone = true;
		let known: Set<string>;
		try {
			known = new Set(pi.getAllTools().map((tool) => tool.name));
		} catch {
			return;
		}
		const still = unknownEntries.filter((entry) => {
			const base = entry.endsWith("*") ? entry.slice(0, -1) : entry;
			return ![...known].some((n) => n.startsWith(base));
		});
		if (still.length === unknownEntries.length) return; // Nothing changed; keep the startup report.
		const resolved = unknownEntries.filter((entry) => !still.includes(entry));
		unknownEntries.length = 0;
		unknownEntries.push(...still);
		if (!ctx.hasUI) return;
		if (still.length === 0) {
			await ctx.ui.notify(
				`permission-gate: previously unmatched allow ${resolved.length === 1 ? "entry" : "entries"} ${resolved.length === 1 ? "matches" : "match"} a registered tool: ${resolved.map((e) => `"${e}"`).join(", ")}`,
				"info",
			);
		} else {
			await ctx.ui.notify(
				`permission-gate: allow ${still.length === 1 ? "entry" : "entries"} still do not match any known tool:\n${still.map((e) => `  ! "${e}"`).join("\n")}`,
				"warning",
			);
		}
	}

	void loadConfig().catch((err: unknown) => {
		problems.push(`load failed: ${err instanceof Error ? err.message : String(err)}`);
	});

	pi.on("session_start", async (_event, ctx) => {
		// A fresh session starts with a clean per-session grant slate.
		sessionGrants.clear();
		try {
			await loadConfig(ctx);
		} catch (err) {
			if (ctx.hasUI) {
				await ctx.ui.notify(
					`permission-gate: reload failed: ${err instanceof Error ? err.message : String(err)}`,
					"error",
				);
			}
		}
	});

	pi.registerCommand("permissions-reload", {
		description: "Reload permissions.json (tool-call gating allowlist)",
		handler: async (_args, ctx) => {
			try {
				await loadConfig(ctx);
			} catch (err) {
				await ctx.ui.notify(
					`permission-gate: reload failed: ${err instanceof Error ? err.message : String(err)}`,
					"error",
				);
			}
		},
	});

	pi.on("tool_call", async (event, ctx) => {
		await recheckUnknownEntries(ctx);
		const name = event.toolName;
		if (isAllowed(name) || sessionGrants.has(name)) return undefined;

		if (!ctx.hasUI) {
			return {
				block: true,
				reason: `${name} requires user approval, but no UI is available in this mode.`,
			};
		}

		const summary = describeInput(event.input);
		const choice = await ctx.ui.select(
			`Allow ${name}?\n\n${summary || "(no arguments)"}`,
			["Allow", "Allow for this session", "Deny"],
		);
		if (choice === "Allow for this session") {
			sessionGrants.add(name);
			return undefined;
		}
		if (choice === "Allow") return undefined;
		return { block: true, reason: `${name} was not approved by the user.` };
	});
}
