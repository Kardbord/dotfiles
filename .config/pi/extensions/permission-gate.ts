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
	const sessionGrants = new Set<string>();
	let allowCount = 0;
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
		// may not be registered yet at startup, so this can under-warn.
		const known = new Set<string>();
		try {
			for (const tool of pi.getAllTools()) known.add(tool.name);
		} catch {
			// Validation is best-effort.
		}
		for (const entry of allow) {
			const base = entry.endsWith("*") ? entry.slice(0, -1) : entry;
			if (![...known].some((n) => n.startsWith(base))) {
				problems.push(`"${entry}" does not match any known tool (yet?)`);
			}
		}

		let msg = `permission-gate: ${allowCount} allow ${allowCount === 1 ? "entry" : "entries"} from ${CONFIG_PATH}`;
		if (problems.length > 0) {
			msg += `\n${problems.map((p) => `  ! ${p}`).join("\n")}`;
		}
		if (ctx?.hasUI) await ctx.ui.notify(msg, problems.length > 0 ? "warning" : "info");
		return msg;
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
