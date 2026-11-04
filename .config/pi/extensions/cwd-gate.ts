/**
 * cwd-gate — confine every tool's file access to the session working
 * directory plus a per-session scratch directory.
 *
 * Every tool call passes through this extension's tool_call handler: pi
 * built-ins, MCP tools, script tools, and nested calls from codemode
 * scripts alike.
 *
 * Allowed roots (passed silently):
 *   - the session working directory (ctx.cwd)
 *   - /tmp/pi-sandbox/<session id>, when the session has an id (ephemeral
 *     sessions get no scratch directory; fail closed)
 *
 * Access classes:
 *   - write-class tools ("write", "edit"): paths outside the roots are
 *     hard-blocked, never prompted — the path field is explicit, so there
 *     is no false-positive concern to soften.
 *   - read-class tools (everything else with a path-shaped input: the
 *     read/grep/find/ls built-ins, the filesystem and git MCP tools,
 *     script tools, any unknown tool): paths outside the roots trigger an
 *     approval prompt — Deny / Allow once / Allow <dir> for this session.
 *     False positives therefore cost at most a prompt, never a wrong block.
 *
 * Rule ladder for a candidate path (first match wins):
 *   1. read.deny / write.deny → hard block, never prompted, even inside
 *      the allowed roots. Entries without "/" are name patterns matched
 *      against the file name and — for deny rules — against every path
 *      component, so ".env" files are denied everywhere, including inside
 *      the working directory.
 *   2. inside a root → pass
 *   3. read.allow / write.allow → pass (pre-blessed outside roots; use
 *      this for module caches, system includes, etc. to avoid prompts)
 *   4. a session grant from an earlier prompt → pass
 *   5. write-class → block; read-class → prompt (blocked without a UI)
 *
 * Script tools take a single opaque `args` string, so the arguments are
 * tokenized with POSIX quoting rules and every token that looks like a
 * path (leading /, ~, .., ./) is judged like a read. Heuristic limits:
 * non-path tokens pass silently (e.g. `go_test github.com/x/y`, which
 * reads the module cache), and read vs write intent is indistinguishable
 * (`yq -i` prompts as a read). The failure mode is a missed gate, and the
 * cost of a false positive is one prompt — never a wrong block.
 *
 * Symlink hardening: for explicit-path tools the nearest existing ancestor
 * of the target is resolved through realpath; an escape through a symlinked
 * directory is re-judged against the real path (deny still applies, and a
 * read prompts / a write blocks). Not-yet-created sandbox files are
 * handled: a lexical match stands when the matched root itself does not
 * exist yet. A symlinked final component that resolves to an existing file
 * outside the roots is caught the same way. Note this resolves through
 * legitimate symlinked dependencies too (e.g. pnpm-style stores): reads of
 * those will prompt unless the real location is allowlisted.
 *
 * Configuration lives in `cwd-gate.json` in the agent directory (next to
 * settings.json; respects PI_CODING_AGENT_DIR):
 *
 *   {
 *     "read":  { "deny": ["~/.ssh", ".env"],  "allow": ["/usr/share"] },
 *     "write": { "deny": [".env", "*.pem"],   "allow": [] }
 *   }
 *
 * Entries are path prefixes: a leading `~/` expands to the home directory,
 * relative entries resolve against the session cwd, and containment is
 * boundary-checked (an entry covers the path itself and everything below
 * it). Entries without any "/" are name patterns ("*" and "?" globs)
 * matched against the file name — and, for deny rules, against every path
 * component. A missing or malformed config warns and continues with empty
 * rule lists; the roots + prompt layer still applies (fail closed).
 *
 * Session grants are held in memory only and cleared on every session
 * start; they are never persisted and never visible to the model.
 *
 * The `bash` tool is intentionally not gated here: the separate no-bash
 * extension hard-blocks every bash call already, and opaque shell commands
 * would only produce noise prompts.
 *
 * Reload with /cwd-gate-reload; inspect with /cwd-gate-status.
 */

import { readFile, realpath } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";

import type {
	ExtensionAPI,
	ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

const CONFIG_PATH = path.join(
	process.env.PI_CODING_AGENT_DIR ?? path.join(homedir(), ".pi", "agent"),
	"cwd-gate.json",
);

const SANDBOX_BASE = "/tmp/pi-sandbox";

/** Tools whose path inputs are exactly known (field name → candidates). */
const EXPLICIT_FIELDS: Record<string, string[]> = {
	read: ["path"],
	write: ["path"],
	edit: ["path"],
	grep: ["path", "glob"],
	find: ["path", "glob"],
	ls: ["path"],
	mcp__filesystem__read_text_file: ["path"],
	mcp__filesystem__read_multiple_files: ["paths"],
	mcp__filesystem__list_directory: ["path"],
	mcp__filesystem__directory_tree: ["path"],
	mcp__filesystem__get_file_info: ["path"],
	mcp__filesystem__search_files: ["path"],
};

/** Write-class tools: outside-roots access is blocked without a prompt. */
const WRITE_TOOLS = new Set(["write", "edit"]);

/** Never gated here: no-bash hard-blocks every bash call anyway. */
const SKIP_TOOLS = new Set(["bash"]);

/** Upper bound on inspected candidates; beyond it, fail closed. */
const MAX_CANDIDATES = 128;

interface Rules {
	deny: string[];
	allow: string[];
}

interface GateConfig {
	read: Rules;
	write: Rules;
}

type Verdict =
	| { action: "pass" }
	| { action: "prompt"; display: string; grantDir: string }
	| { action: "block"; reason: string };

function emptyRules(): Rules {
	return { deny: [], allow: [] };
}

function emptyConfig(): GateConfig {
	return { read: emptyRules(), write: emptyRules() };
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

async function loadConfig(): Promise<{ config: GateConfig; problems: string[] }> {
	const problems: string[] = [];
	const config = emptyConfig();

	let parsed: unknown;
	try {
		parsed = JSON.parse(await readFile(CONFIG_PATH, "utf8"));
	} catch (err) {
		if ((err as { code?: string } | null)?.code === "ENOENT") {
			problems.push("not found (no deny/allow rules; roots + prompts still apply)");
		} else {
			problems.push(err instanceof Error ? err.message : String(err));
		}
		return { config, problems };
	}

	const readList = (
		rules: Record<string, unknown>,
		key: "deny" | "allow",
		into: Rules,
		label: string,
	): void => {
		const value = rules[key];
		if (value === undefined) return;
		if (!Array.isArray(value) || value.some((entry) => typeof entry !== "string")) {
			problems.push(`"${label}.${key}" must be an array of strings`);
			return;
		}
		into[key] = value as string[];
	};

	if (parsed !== null && typeof parsed === "object" && !Array.isArray(parsed)) {
		const root = parsed as Record<string, unknown>;
		for (const kind of ["read", "write"] as const) {
			const rules = root[kind];
			if (rules === undefined) continue;
			if (rules === null || typeof rules !== "object" || Array.isArray(rules)) {
				problems.push(`"${kind}" must be an object with "deny"/"allow" arrays`);
				continue;
			}
			readList(rules, "deny", config[kind], kind);
			readList(rules, "allow", config[kind], kind);
		}
	} else {
		problems.push(`expected an object with "read" and/or "write" rule objects`);
	}

	return { config, problems };
}

// ---------------------------------------------------------------------------
// Matching helpers
// ---------------------------------------------------------------------------

const within = (root: string, p: string): boolean =>
	p === root || p.startsWith(root + path.sep);

/** Expand one config entry: ~ to home, relative entries against the cwd. */
function expandEntry(entry: string, cwd: string): string {
	if (entry === "~") return homedir();
	if (entry.startsWith("~/")) return path.join(homedir(), entry.slice(2));
	if (entry.startsWith("/")) return path.normalize(entry);
	return path.resolve(cwd, entry);
}

/** Shell-style name glob ("*" and "?" only) to RegExp. */
function globToRegExp(pattern: string): RegExp {
	const escaped = pattern
		.replace(/[.+^${}()|[\]\\]/g, "\\$&")
		.replace(/\*/g, "[^/]*")
		.replace(/\?/g, "[^/]");
	return new RegExp(`^${escaped}$`);
}

/**
 * Does an entry match an absolute path?
 * Entries containing "/" (after expansion) are boundary-checked prefixes.
 * Entries without "/" are name patterns: they match the file name, and —
 * for deny rules — every path component, so ".env" and "secrets" cover
 * whole trees anywhere.
 */
function entryMatches(entry: string, absPath: string, cwd: string, deny: boolean): boolean {
	if (entry.includes("/")) return within(expandEntry(entry, cwd), absPath);
	const re = globToRegExp(entry);
	if (re.test(path.basename(absPath))) return true;
	if (!deny) return false;
	return path
		.dirname(absPath)
		.split(path.sep)
		.some((part) => part.length > 0 && re.test(part));
}

function currentRoots(cwd: string, sessionId: string | undefined): string[] {
	const roots = [path.resolve(cwd)];
	if (sessionId) roots.push(path.join(SANDBOX_BASE, sessionId));
	return roots;
}

/** realpath of the nearest existing ancestor of p (p itself if it exists). */
async function realpathNearest(p: string): Promise<string> {
	let cur = p;
	for (;;) {
		try {
			return await realpath(cur);
		} catch {
			const parent = path.dirname(cur);
			if (parent === cur) return p;
			cur = parent;
		}
	}
}

// ---------------------------------------------------------------------------
// Candidate extraction
// ---------------------------------------------------------------------------

const looksLikePath = (t: string): boolean =>
	t.startsWith("/") ||
	t === "~" ||
	t.startsWith("~/") ||
	t === "." ||
	t === ".." ||
	t.startsWith("./") ||
	t.startsWith("../");

/** POSIX-ish tokenizer: single quotes, double quotes, backslash escapes. */
function tokenizeArgs(s: string): string[] {
	const out: string[] = [];
	let cur = "";
	let started = false;
	let i = 0;
	while (i < s.length) {
		const c = s[i];
		if (c === "'") {
			started = true;
			i++;
			while (i < s.length && s[i] !== "'") cur += s[i++];
			i++;
		} else if (c === '"') {
			started = true;
			i++;
			while (i < s.length && s[i] !== '"') {
				if (s[i] === "\\" && i + 1 < s.length) {
					i++;
					cur += s[i++];
				} else {
					cur += s[i++];
				}
			}
			i++;
		} else if (c === "\\" && i + 1 < s.length) {
			started = true;
			cur += s[i + 1];
			i += 2;
		} else if (/\s/.test(c)) {
			if (started) {
				out.push(cur);
				cur = "";
				started = false;
			}
			i++;
		} else {
			started = true;
			cur += c;
			i++;
		}
	}
	if (started) out.push(cur);
	return out;
}

/** Collect strings from arbitrary JSON input that look like paths. */
function scanForPathStrings(
	value: unknown,
	out: string[],
	depth = 0,
	skipArgs = false,
): void {
	if (depth > 4 || out.length > MAX_CANDIDATES) return;
	if (typeof value === "string") {
		if (!skipArgs && looksLikePath(value)) out.push(value);
		return;
	}
	if (Array.isArray(value)) {
		for (const item of value) scanForPathStrings(item, out, depth + 1);
		return;
	}
	if (value !== null && typeof value === "object") {
		for (const [key, item] of Object.entries(value)) {
			scanForPathStrings(item, out, depth + 1, skipArgs && key === "args");
		}
	}
}

function collectCandidates(name: string, input: Record<string, unknown>): string[] {
	const out: string[] = [];
	const push = (v: unknown): void => {
		if (typeof v === "string") out.push(v);
		else if (Array.isArray(v)) for (const item of v) if (typeof item === "string") out.push(item);
	};

	const fields = EXPLICIT_FIELDS[name];
	if (fields) {
		for (const field of fields) push(input[field]);
		// Defensive: if none of the mapped fields are present, the input shape
		// differs from the map — scan rather than let the call through
		// uninspected.
		if (out.length === 0) scanForPathStrings(input, out);
		return out;
	}

	if (name.startsWith("mcp__")) {
		push(input.path);
		push(input.paths);
		push(input.repo_path);
		if (out.length === 0) scanForPathStrings(input, out);
		return out;
	}

	// Script tools (opaque `args` string) and any other tool.
	if (typeof input.args === "string") {
		out.push(...tokenizeArgs(input.args).filter(looksLikePath));
	}
	scanForPathStrings(input, out, 0, true);
	return out;
}

// ---------------------------------------------------------------------------
// Judgement
// ---------------------------------------------------------------------------

function denyHit(rules: Rules, p: string, cwd: string): string | undefined {
	const entry = rules.deny.find((e) => entryMatches(e, p, cwd, true));
	return entry === undefined ? undefined : `cwd-gate: path "${p}" matches deny rule "${entry}"`;
}

function verdictRank(v: Verdict): number {
	return v.action === "block" ? 2 : v.action === "prompt" ? 1 : 0;
}

/** Judge an outside-roots path (deny already handled by the caller). */
function decideOutside(
	kind: "read" | "write",
	p: string,
	config: GateConfig,
	grants: Set<string>,
	cwd: string,
): Verdict {
	if (config[kind].allow.some((e) => entryMatches(e, p, cwd, false))) {
		return { action: "pass" };
	}
	for (const grant of grants) {
		if (within(grant, p)) return { action: "pass" };
	}
	if (kind === "write") {
		return {
			action: "block",
			reason: `cwd-gate: write to "${p}" is outside the allowed roots (working directory and ${SANDBOX_BASE}/<session>)`,
		};
	}
	return { action: "prompt", display: p, grantDir: path.dirname(p) };
}

async function checkPath(
	raw: string,
	kind: "read" | "write",
	cwd: string,
	sessionId: string | undefined,
	config: GateConfig,
	grants: Set<string>,
): Promise<Verdict> {
	const rules = config[kind];

	// Normalize: strip a leading @ (some models prefix tool paths), expand ~.
	const stripped = raw.startsWith("@") ? raw.slice(1) : raw;
	const expanded =
		stripped === "~" || stripped.startsWith("~/")
			? path.join(homedir(), stripped.slice(1))
			: stripped;
	const resolved = path.resolve(cwd, expanded);

	// 1. Hard deny — never prompted, even inside the allowed roots.
	const denied = denyHit(rules, resolved, cwd);
	if (denied !== undefined) return { action: "block", reason: denied };

	const roots = currentRoots(cwd, sessionId);
	const lexicalRoot = roots.find((r) => within(r, resolved));

	if (lexicalRoot !== undefined) {
		// Symlink hardening: an escape through a symlinked directory is
		// re-judged against the real path.
		const real = await realpathNearest(resolved);
		if (real !== resolved) {
			const deniedReal = denyHit(rules, real, cwd);
			if (deniedReal !== undefined) return { action: "block", reason: deniedReal };
		}
		// Pass when the realpathed view stays inside a root, or when the
		// matched root itself does not exist yet (fresh sandbox files: the
		// nearest existing ancestor is /tmp, which contains the sandbox root).
		if (roots.some((r) => within(r, real) || within(real, r))) {
			return { action: "pass" };
		}
		// The real path escaped the roots: judge it like any outside path.
		return decideOutside(kind, real, config, grants, cwd);
	}

	return decideOutside(kind, resolved, config, grants, cwd);
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

interface NotifyCtx {
	hasUI?: boolean;
	ui?: { notify(message: string, level?: "info" | "warning" | "error"): Promise<void> };
}

function formatList(entries: string[]): string {
	return entries.length === 0 ? "(none)" : entries.join(", ");
}

export default function cwdGate(pi: ExtensionAPI) {
	const grants = new Set<string>();
	let config: GateConfig = emptyConfig();

	async function reload(ctx?: NotifyCtx): Promise<string> {
		const { config: loaded, problems } = await loadConfig();
		config = loaded;
		let msg =
			`cwd-gate: ${loaded.read.deny.length} read-deny, ${loaded.read.allow.length} read-allow, ` +
			`${loaded.write.deny.length} write-deny, ${loaded.write.allow.length} write-allow entries from ${CONFIG_PATH}`;
		if (problems.length > 0) {
			msg += `\n${problems.map((p) => `  ! ${p}`).join("\n")}`;
		}
		if (ctx?.hasUI && ctx.ui) {
			await ctx.ui.notify(msg, problems.length > 0 ? "warning" : "info");
		}
		return msg;
	}

	void reload().catch(() => {
		// Session_start reloads and reports properly.
	});

	pi.on("session_start", async (_event, ctx) => {
		// A fresh session starts with a clean grant slate.
		grants.clear();
		try {
			await reload(ctx);
		} catch (err) {
			if (ctx.hasUI) {
				await ctx.ui.notify(
					`cwd-gate: reload failed: ${err instanceof Error ? err.message : String(err)}`,
					"error",
				);
			}
		}
	});

	pi.registerCommand("cwd-gate-reload", {
		description: "Reload cwd-gate.json (path gate deny/allow rules)",
		handler: async (_args, ctx) => {
			try {
				await reload(ctx);
			} catch (err) {
				await ctx.ui.notify(
					`cwd-gate: reload failed: ${err instanceof Error ? err.message : String(err)}`,
					"error",
				);
			}
		},
	});

	pi.registerCommand("cwd-gate-status", {
		description: "Show cwd-gate roots, rules, and session grants",
		handler: async (_args, ctx) => {
			const sessionId = ctx.sessionManager.getSessionId();
			const lines = [
				"cwd-gate",
				"  roots:",
				...currentRoots(ctx.cwd, sessionId).map((r) => `    ${r}`),
				`  read deny: ${formatList(config.read.deny)}`,
				`  read allow: ${formatList(config.read.allow)}`,
				`  write deny: ${formatList(config.write.deny)}`,
				`  write allow: ${formatList(config.write.allow)}`,
				`  session grants: ${grants.size === 0 ? "(none)" : ""}`,
				...[...grants].map((g) => `    ${g}`),
			];
			await ctx.ui.notify(lines.join("\n"), "info");
		},
	});

	pi.on("tool_call", async (event, ctx) => {
		const name = event.toolName;
		if (SKIP_TOOLS.has(name)) return undefined;

		const input = event.input as Record<string, unknown> | null | undefined;
		if (input === null || typeof input !== "object") return undefined;

		const kind: "read" | "write" = WRITE_TOOLS.has(name) ? "write" : "read";
		const sessionId = ctx.sessionManager.getSessionId();

		const candidates = collectCandidates(name, input);
		if (candidates.length === 0) return undefined;

		let worst: Verdict;
		if (candidates.length > MAX_CANDIDATES) {
			// Arguments too large to vouch for: fail closed to the read-class
			// outcome (block for writes, prompt for reads).
			worst =
				kind === "write"
					? {
							action: "block",
							reason: `cwd-gate: write call has too many arguments to inspect (>${MAX_CANDIDATES})`,
						}
					: {
							action: "prompt",
							display: "(too many path-like arguments to inspect)",
							grantDir: ctx.cwd,
						};
		} else {
			worst = { action: "pass" };
			for (const raw of candidates) {
				const verdict = await checkPath(raw, kind, ctx.cwd, sessionId, config, grants);
				if (verdictRank(verdict) > verdictRank(worst)) worst = verdict;
				if (worst.action === "block") break;
			}
		}

		if (worst.action === "pass") return undefined;
		if (worst.action === "block") return { block: true, reason: worst.reason };

		if (!ctx.hasUI) {
			return {
				block: true,
				reason: `cwd-gate: ${kind} access to "${worst.display}" is outside the allowed roots, and no UI is available to approve it.`,
			};
		}

		const sessionOption = `Allow ${worst.grantDir} for this session`;
		const choice = await ctx.ui.select(
			`cwd-gate: ${kind} access outside the allowed roots\n\n${worst.display}`,
			["Deny", "Allow once", sessionOption],
		);
		if (choice === sessionOption) {
			grants.add(worst.grantDir);
			return undefined;
		}
		if (choice === "Allow once") return undefined;
		return {
			block: true,
			reason: `cwd-gate: ${kind} access to "${worst.display}" was not approved.`,
		};
	});
}
