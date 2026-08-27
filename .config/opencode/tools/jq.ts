import { tool } from "@opencode-ai/plugin"
import { exec, present, resolveDir, resolveFiles, binaryMissing } from "./_helpers"

export default tool({
  description:
    "Run `jq` to query and transform JSON data. Requires explicit file inputs (no stdin). Examples: `jq '.name' package.json`, `jq '.[] | select(.type == \"error\")' data.json`. Supports all read-only flags (`-r` raw output, `-c` compact, `--sort-keys`, etc.). Great for inspecting config files, API responses, and structured data.",
  args: {
    expression: tool.schema
      .string()
      .describe("The jq filter expression, e.g. `.name`, `.[] | select(.active)`, `{name, version}`."),
    files: tool.schema
      .array(tool.schema.string())
      .min(1)
      .describe("JSON file paths to query, e.g. `package.json`, `data/response.json`."),
    directory: tool.schema
      .string()
      .optional()
      .describe(
        "Directory to run the command in, relative to the session working directory. Defaults to the session working directory.",
      ),
    args: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("Additional flags to pass to `jq`, e.g. `-r` (raw output), `-c` (compact), `--sort-keys`."),
  },
  async execute(args, context) {
    if (!Bun.which("jq")) {
      return binaryMissing("jq")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const resolvedFiles = resolveFiles(args.files, cwd)
    const cmd = ["jq", ...(args.args ?? []), args.expression, ...resolvedFiles]
    const res = await exec(cmd, cwd)
    return present(res, cmd.join(" "), cwd)
  },
})