import { tool } from "@opencode-ai/plugin"
import { exec, present, resolveDir, resolveFiles, binaryMissing } from "./_helpers"

const FORBIDDEN_FLAGS = new Set(["-i", "--inplace"])

function isForbidden(arg: string): boolean {
  if (FORBIDDEN_FLAGS.has(arg)) return true
  for (const flag of FORBIDDEN_FLAGS) {
    if (arg.startsWith(flag + "=")) return true
  }
  return false
}

function flagName(arg: string): string {
  return arg.split("=")[0]
}

function validateArgs(args: string[]): void {
  for (const arg of args) {
    if (isForbidden(arg)) {
      throw new Error(
        `The \`${flagName(arg)}\` flag is not allowed. yq is restricted to read-only operations. Use the edit tool to modify files.`,
      )
    }
  }
}

export default tool({
  description:
    "Run `yq` to query and transform YAML data. Requires explicit file inputs (no stdin). Examples: `yq '.jobs.build.steps' ci.yaml`, `yq '.spec.containers[0].name' deployment.yaml`. Supports all read-only flags (`-o json`, `-o props`, `-P` pretty print, `--indent`, etc.). In-place editing (`-i`) is not allowed. Great for inspecting GitHub Actions workflows, Kubernetes manifests, and other YAML config files.",
  args: {
    expression: tool.schema
      .string()
      .describe("The yq expression, e.g. `.name`, `.jobs[].name`, `.spec.containers[0].image`."),
    files: tool.schema
      .array(tool.schema.string())
      .min(1)
      .describe("YAML file paths to query, e.g. `.github/workflows/ci.yaml`, `docker-compose.yml`."),
    directory: tool.schema
      .string()
      .optional()
      .describe(
        "Directory to run the command in, relative to the session working directory. Defaults to the session working directory.",
      ),
    args: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe("Additional flags to pass to `yq`, e.g. `-o json`, `-P` (pretty), `--indent 2`. `-i`/`--inplace` are not allowed."),
  },
  async execute(args, context) {
    if (!Bun.which("yq")) {
      return binaryMissing("yq")
    }
    const cliArgs = args.args ?? []
    validateArgs(cliArgs)
    const cwd = resolveDir(args.directory, context.directory)
    const resolvedFiles = resolveFiles(args.files, cwd)
    const cmd = ["yq", ...cliArgs, args.expression, ...resolvedFiles]
    const res = await exec(cmd, cwd)
    return present(res, cmd.join(" "), cwd)
  },
})