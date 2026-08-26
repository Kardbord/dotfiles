import { tool } from "@opencode-ai/plugin"
import { exec, present, resolveDir, binaryMissing } from "./_helpers"

const FORBIDDEN_FLAGS = new Set(["-x", "--exec", "-X", "--exec-batch"])

function validateArgs(args: string[]): void {
  for (const arg of args) {
    if (FORBIDDEN_FLAGS.has(arg)) {
      throw new Error(
        `The \`${arg}\` flag is not allowed. fd is restricted to read-only operations.`,
      )
    }
  }
}

export default tool({
  description:
    "Run `fd` to search for files and directories matching a pattern. Read-only — execution flags (`-x`, `--exec`, `-X`, `--exec-batch`) are disallowed.",
  args: {
    directory: tool.schema
      .string()
      .optional()
      .describe(
        "Directory to run the command in, relative to the session working directory. Defaults to the session working directory.",
      ),
    args: tool.schema
      .array(tool.schema.string())
      .optional()
      .describe(
        "Arguments to pass to `fd`, e.g. `--type f`, `--extension ts`, `--hidden`, `--exclude node_modules`.",
      ),
  },
  async execute(args, context) {
    if (!Bun.which("fd")) {
      return binaryMissing("fd")
    }
    const cliArgs = args.args ?? []
    validateArgs(cliArgs)
    const cwd = resolveDir(args.directory, context.directory)
    const cmd = ["fd", ...cliArgs]
    const res = await exec(cmd, cwd)
    return present(res, cmd.join(" "), cwd)
  },
})
