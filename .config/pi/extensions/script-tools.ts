/**
 * script-tools — turn bash scripts into LLM-callable tools.
 *
 * Drop executable bash scripts into the script-tools directory (default
 * `<agent-dir>/extensions/script-tools`, override with `PI_SCRIPT_TOOLS_DIR`). Each
 * script declares its interface in a header comment block:
 *
 *   #!/usr/bin/env bash
 *   # tool: my_tool                  (optional; defaults to filename without .sh)
 *   # description: What the tool does — shown to the LLM
 *   # timeout: 60000                 (optional, milliseconds; default 60000)
 *   # lazy                           (optional; defer the tool until tool_search loads it)
 *   # detect: go.mod,*.go            (optional; activate when a marker matches the session cwd)
 *   # param: branch required Branch to deploy
 *   # param: dry_run boolean optional Skip actual deploy
 *   # param: mode oneof:fast,safe optional Deployment mode
 *
 * The header ends at the first non-comment, non-blank line.
 *
 * Param syntax:
 *   # param: <name> [string|number|boolean|oneof:a,b,c] [required|optional] [description]
 *
 * Defaults: type=string, required=true.
 *
 * At execution, every param is exported as an env var named
 * PI_TOOL_<NAME_UPPERCASE> (booleans become "true"/"false", absent optionals
 * become ""), plus PI_TOOL_ARGS_JSON holding the full args object and
 * PI_TOOL_SCRIPT_NAME holding the tool's name. The script runs with the
 * current session's cwd.
 *
 * A string param named `args` is additionally tokenized with POSIX shell
 * quoting rules (single quotes, double quotes, backslash escapes) and passed
 * to the script as positional parameters, available as `"$@"`. Quoted
 * arguments — including ones containing spaces or newlines — survive intact.
 *
 * Tool-call permission gating (deny by default, with an allowlist in
 * permissions.json at the agent-directory root) is handled by the separate
 * permission-gate extension, not here.
 *
 * `# lazy` defers a tool: with `deferred` exposure it is not declared to the
 * model at startup and costs no prompt space. The built-in `tool_search`
 * tool declares it on demand — it stays declared for the rest of the
 * session — and codemode scripts can call it at any time. Permission gating
 * still applies to every call.
 *
 * `# detect: marker,marker,...` registers the tool inactive and activates it
 * automatically when any marker (exact name, `*`/`?` glob, or directory name
 * with an optional trailing `/`) matches an entry at the root of the session
 * cwd. Detection re-runs on every session start (including resume) and after
 * /script-tools-reload. If no marker matches or the cwd cannot be read, the
 * tool stays deferred until tool_search loads it (fail closed).
 *
 * Reload with /script-tools-reload after editing scripts.
 */

import { readFile, readdir } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";

import { StringEnum, Type } from "@earendil-works/pi-ai";
import {
	defineTool,
	type ExtensionAPI,
	type ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

// Fallback must match permission-gate.ts so both extensions read configs
// from the same directory when PI_CODING_AGENT_DIR is unset.
const AGENT_DIR = process.env.PI_CODING_AGENT_DIR ?? path.join(homedir(), ".pi", "agent");
const TOOLS_DIR =
	process.env.PI_SCRIPT_TOOLS_DIR ?? path.join(AGENT_DIR, "extensions", "script-tools");

const RESERVED_NAMES = new Set([
	"read", "bash", "powershell", "edit", "write", "grep", "find", "ls",
	"codemode", "thought", "todo", "subagent",
]);

const DEFAULT_TIMEOUT_MS = 60_000;

const MAX_OUTPUT_CHARS = 30_000;

interface ParamSpec {
	name: string;
	type: "string" | "number" | "boolean";
	enumValues?: string[];
	required: boolean;
	description?: string;
}

interface ScriptSpec {
	name: string;
	description: string;
	promptSnippet?: string;
	timeout?: number;
	lazy?: boolean;
	detect?: string[];
	params: ParamSpec[];
	path: string;
}

// ---------------------------------------------------------------------------
// Header parsing
// ---------------------------------------------------------------------------

function parseParam(rest: string): ParamSpec | undefined {
	const tokens = rest.trim().split(/\s+/);
	const name = tokens.shift();
	if (!name || !/^[A-Za-z_][A-Za-z0-9-]*$/.test(name)) return undefined;

	const spec: ParamSpec = { name, type: "string", required: true };

	let i = 0;
	const first = tokens[i];
	if (first && first.startsWith("oneof:")) {
		const values = first.slice("oneof:".length).split(",").filter(Boolean);
		if (values.length > 0) {
			spec.enumValues = values;
			spec.type = "string";
			i++;
		}
	} else if (first === "string" || first === "number" || first === "boolean") {
		spec.type = first;
		i++;
	}

	const second = tokens[i];
	if (second === "required" || second === "optional") {
		spec.required = second === "required";
		i++;
	}

	const description = tokens.slice(i).join(" ").trim();
	if (description) spec.description = description;
	return spec;
}

function parseHeader(text: string, fallbackName: string, filePath: string): ScriptSpec {
	const spec: ScriptSpec = {
		name: fallbackName,
		description: `Custom tool running the script ${filePath}`,
		params: [],
		path: filePath,
	};

	for (const raw of text.split("\n")) {
		const line = raw.trim();
		if (line === "") continue;
		if (!line.startsWith("#")) break; // header ends at the first code line
		if (line.startsWith("#!")) continue; // shebang

		const body = line.replace(/^#+\s*/, "");
		if (body === "lazy") {
			spec.lazy = true;
			continue;
		}
		const m = body.match(/^(tool|description|timeout|param|lazy|detect):\s*(.*)$/);
		if (!m) continue;
		const [, key, value] = m;

		if (key === "tool") {
			const name = value.trim();
			if (/^[a-zA-Z][a-zA-Z0-9_]*$/.test(name)) spec.name = name;
		} else if (key === "description") {
			spec.description = value.trim() || spec.description;
		} else if (key === "timeout") {
			const ms = Number.parseInt(value.trim(), 10);
			if (Number.isFinite(ms) && ms > 0) spec.timeout = ms;
		} else if (key === "lazy") {
			const flag = value.trim().toLowerCase();
			spec.lazy = flag !== "off" && flag !== "false";
		} else if (key === "detect") {
			spec.detect ??= [];
			for (const marker of value.split(",")) {
				const trimmed = marker.trim();
				if (trimmed && !spec.detect.includes(trimmed)) spec.detect.push(trimmed);
			}
		} else if (key === "param") {
			const param = parseParam(value);
			if (param && !spec.params.some((p) => p.name === param.name)) {
				spec.params.push(param);
			}
		}
	}

	// One-liner for the system prompt <tools> section.
	const firstSentence =
		spec.description.split(/(?<=[.!?])\s|\n/)[0]?.trim() ?? spec.description;
	spec.promptSnippet = firstSentence.length > 120
		? `${firstSentence.slice(0, 117)}...`
		: firstSentence;

	return spec;
}

// ---------------------------------------------------------------------------
// Schema + execution
// ---------------------------------------------------------------------------

function buildSchema(params: ParamSpec[]) {
	const props: Record<string, any> = {};
	for (const p of params) {
		let t: any;
		if (p.enumValues) {
			t = StringEnum(p.enumValues as [string, ...string[]], {
				description: p.description,
			});
		} else if (p.type === "number") {
			t = Type.Number({ description: p.description });
		} else if (p.type === "boolean") {
			t = Type.Boolean({ description: p.description });
		} else {
			t = Type.String({ description: p.description });
		}
		props[p.name] = p.required ? t : Type.Optional(t);
	}
	return Type.Object(props, { additionalProperties: false });
}

function envName(paramName: string): string {
	const upper = paramName.toUpperCase().replace(/[^A-Z0-9_]/g, "_");
	const safe = /^[0-9]/.test(upper) ? `_${upper}` : upper;
	return `PI_TOOL_${safe}`;
}

function shellQuote(s: string): string {
	return `'${s.replace(/'/g, `'\\''`)}'`;
}

function tokenizeArgs(input: string): string[] {
	const tokens: string[] = [];
	let current = "";
	let hasToken = false;
	let state: "normal" | "single" | "double" = "normal";

	for (let i = 0; i < input.length; i++) {
		const ch = input[i];
		if (state === "single") {
			if (ch === "'") {
				state = "normal";
			} else {
				current += ch;
			}
		} else if (state === "double") {
			if (ch === '"') {
				state = "normal";
			} else if (ch === "\\") {
				const next = input[++i];
				if (next === undefined) {
					current += ch;
				} else {
					// Inside double quotes, only these escapes are special in POSIX shells.
					current += next === '"' || next === "\\" || next === "$" || next === "`" ? next : `\\${next}`;
				}
			} else {
				current += ch;
			}
		} else if (/\s/.test(ch)) {
			if (hasToken) {
				tokens.push(current);
				current = "";
				hasToken = false;
			}
		} else if (ch === "'") {
			state = "single";
			hasToken = true;
		} else if (ch === '"') {
			state = "double";
			hasToken = true;
		} else if (ch === "\\") {
			const next = input[++i];
			if (next === undefined) {
				current += ch;
				hasToken = true;
			} else {
				current += next;
				hasToken = true;
			}
		} else {
			current += ch;
			hasToken = true;
		}
	}
	if (hasToken) tokens.push(current);
	return tokens;
}

function truncate(s: string): { text: string; truncated: boolean } {
	if (s.length <= MAX_OUTPUT_CHARS) return { text: s, truncated: false };
	return {
		text: `${s.slice(0, MAX_OUTPUT_CHARS / 2)}\n... [output truncated, ${s.length - MAX_OUTPUT_CHARS} chars removed] ...\n${s.slice(-MAX_OUTPUT_CHARS / 2)}`,
		truncated: true,
	};
}

function makeScriptTool(pi: ExtensionAPI, spec: ScriptSpec) {
	return defineTool({
		name: spec.name,
		label: spec.name,
		description: spec.description,
		promptSnippet: spec.promptSnippet,
		parameters: buildSchema(spec.params),
		...(spec.lazy ? { exposure: "deferred" as const } : {}),
		...(spec.lazy || spec.detect ? { defaultActive: false as const } : {}),

		async execute(_toolCallId, params, signal, _onUpdate, ctx) {
			const env: Record<string, string> = { PI_TOOL_SCRIPT_NAME: spec.name };
			for (const p of spec.params) {
				const value = (params as Record<string, unknown>)[p.name];
				env[envName(p.name)] = value === undefined ? "" : String(value);
			}
			env.PI_TOOL_ARGS_JSON = JSON.stringify(params ?? {});

			const exports = Object.entries(env)
				.map(([k, v]) => `export ${k}=${shellQuote(v)}`)
				.join("; ");
			const argsParam = spec.params.find((p) => p.name === "args" && p.type === "string");
			const argv = argsParam
				? tokenizeArgs(String((params as Record<string, unknown>)[argsParam.name] ?? ""))
				: [];
			const positionalArgs = argv.map(shellQuote).join(" ");
			const command = `${exports}; exec bash ${shellQuote(spec.path)}${positionalArgs ? ` ${positionalArgs}` : ""}`;

			const result = await pi.exec("bash", ["-c", command], {
				cwd: ctx.cwd,
				signal,
				timeout: spec.timeout ?? DEFAULT_TIMEOUT_MS,
			});

			const stdout = (result.stdout ?? "").trim();
			const stderr = (result.stderr ?? "").trim();
			const out = truncate(stdout || stderr ? stdout : "(no output)");
			const err = truncate(stderr);

			const parts: string[] = [];
			if (out.text) parts.push(out.text);
			if (err.text) parts.push(`stderr:\n${err.text}`);
			if (result.killed) {
				parts.push("(terminated: aborted, timed out, or output limit hit)");
			}

			if (result.code !== 0) {
				parts.push(`exit code: ${result.code}`);
			}

			const text = parts.join("\n");
			return {
				content: [{ type: "text", text }],
				isError: result.code !== 0,
				details: {
					script: spec.path,
					exitCode: result.code,
					killed: result.killed,
					truncated: out.truncated || err.truncated || result.truncated,
				},
			};
		},
	});
}

// ---------------------------------------------------------------------------
// Loading + registration
// ---------------------------------------------------------------------------

function extension(pi: ExtensionAPI) {
	const loaded: string[] = [];
	const problems: string[] = [];
	const detectTools: { name: string; markers: string[] }[] = [];
	let loadedOnce = false;

	// A detect tool activates when any of its markers (exact name or `*`/`?`
	// glob) matches an entry at the root of the given directory. A directory
	// read failure fails closed: nothing is activated.
	function markerToRegex(marker: string): RegExp {
		const pattern = marker
			.replace(/[.+^${}()|[\]\\]/g, "\\$&")
			.replace(/\*/g, ".*")
			.replace(/\?/g, ".");
		return new RegExp(`^${pattern}$`);
	}

	async function detectAndActivate(cwd: string): Promise<void> {
		const withMarkers = detectTools.filter((t) => t.markers.length > 0);
		if (withMarkers.length === 0) return;

		let entryNames: string[];
		try {
			const entries = await readdir(cwd, { withFileTypes: true });
			entryNames = entries.map((e) => e.name);
		} catch {
			return;
		}

		const matched: string[] = [];
		for (const tool of withMarkers) {
			const hit = tool.markers.some((raw) => {
				const marker = raw.endsWith("/") ? raw.slice(0, -1) : raw;
				return entryNames.some((entry) => markerToRegex(marker).test(entry));
			});
			if (hit) matched.push(tool.name);
		}
		if (matched.length === 0) return;

		try {
			const active = new Set(pi.getActiveTools());
			for (const name of matched) active.add(name);
			pi.setActiveTools([...active]);
		} catch (err) {
			problems.push(`detect: ${err instanceof Error ? err.message : String(err)}`);
		}
	}

	async function loadAll(ctx?: ExtensionCommandContext): Promise<string> {
		let files: string[];
		try {
			const entries = await readdir(TOOLS_DIR, { withFileTypes: true });
			files = entries
				.filter((e) => e.isFile() && e.name.endsWith(".sh"))
				.map((e) => path.join(TOOLS_DIR, e.name))
				.sort();
		} catch {
			const msg = `script-tools: cannot read ${TOOLS_DIR}`;
			if (ctx) await ctx.ui.notify(msg, "warning");
			return msg;
		}

		problems.length = 0;

		const names: string[] = [];
		detectTools.length = 0;
		for (const file of files) {
			const base = path.basename(file, ".sh");
			const scriptName = base.replace(/[^a-zA-Z0-9_]/g, "_").replace(/^[0-9]/, "_$&");
			try {
				const spec = parseHeader(await readFile(file, "utf8"), scriptName, file);
				if (RESERVED_NAMES.has(spec.name)) {
					problems.push(`${base}.sh: name "${spec.name}" is reserved, skipped`);
					continue;
				}
				pi.registerTool(makeScriptTool(pi, spec));
				names.push(spec.name);
				if (spec.detect && spec.detect.length > 0) {
					detectTools.push({ name: spec.name, markers: spec.detect });
				}
			} catch (err) {
				problems.push(`${base}.sh: ${err instanceof Error ? err.message : String(err)}`);
			}
		}

		loaded.length = 0;
		loaded.push(...names);
		loadedOnce = true;

		let msg = `script-tools: ${names.length} tool(s) from ${TOOLS_DIR}`;
		if (names.length > 0) msg += `: ${names.join(", ")}`;
		if (problems.length > 0) msg += `\n${problems.map((p) => `  ! ${p}`).join("\n")}`;
		if (ctx) await ctx.ui.notify(msg, problems.length > 0 ? "warning" : "info");
		return msg;
	}

	// Register during extension load so tools are available immediately.
	// session_start re-loads if the eager load hasn't finished yet; both are
	// idempotent (registering the same name replaces the prior definition).
	void loadAll().catch((err: unknown) => {
		problems.push(`loadAll failed: ${err instanceof Error ? err.message : String(err)}`);
	});

	pi.on("session_start", async (_event, ctx) => {
		if (!loadedOnce) {
			try {
				await loadAll();
			} catch (err) {
				problems.push(`loadAll failed: ${err instanceof Error ? err.message : String(err)}`);
			}
		}
		// Re-derive detection on every session start (startup, new, resume,
		// fork, reload): the session cwd may differ from the process cwd.
		try {
			await detectAndActivate(ctx.cwd);
		} catch (err) {
			problems.push(`detect failed: ${err instanceof Error ? err.message : String(err)}`);
		}
	});

	pi.registerCommand("script-tools-reload", {
		description: "Reload script tools (bash-script-defined tools)",
		handler: async (_args, ctx) => {
			try {
				await loadAll(ctx);
				await detectAndActivate(ctx.cwd);
			} catch (err) {
				await ctx.ui.notify(
					`script-tools: reload failed: ${err instanceof Error ? err.message : String(err)}`,
					"error",
				);
			}
		},
	});


}

export default extension;
