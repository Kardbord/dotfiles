/**
 * no-bash — completely disable the built-in bash tool.
 *
 * Re-registers `bash` with `exposure: "hidden"`, which withdraws the tool:
 * it is never declared to the model, never active, and cannot be activated
 * via `--tools`, `defaultTools`, the /tools selector, or pi.setActiveTools()
 * (all of which ignore hidden tools).
 *
 * A tool_call guard blocks any call that slips through anyway — including
 * nested calls from codemode scripts, which pass through the same pipeline.
 *
 * Note: this does not affect script-tools (each script is its own tool,
 * gated by permissions.json) or the user's own `!` shell commands.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

export default function noBash(pi: ExtensionAPI) {
	pi.registerTool({
		name: "bash", // Same name as the built-in — this override wins
		exposure: "hidden", // Registered but unreachable
		label: "bash (disabled)",
		description: "Disabled by the no-bash extension.",
		parameters: Type.Object({}),
		async execute() {
			return {
				content: [{ type: "text", text: "The bash tool is disabled (no-bash extension)." }],
				details: { disabled: true },
			};
		},
	});

	// Backstop: block every bash tool call, direct or nested.
	pi.on("tool_call", async (event) => {
		if (event.toolName !== "bash") return;
		return {
			block: true,
			reason:
				"The bash tool is disabled (no-bash extension). Use the available script tools instead, or ask the user to run the command themselves.",
		};
	});
}
