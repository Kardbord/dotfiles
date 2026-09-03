import { tool } from "@opencode-ai/plugin"
import { exec, present, resolveDir, binaryMissing } from "./_helpers"

export default tool({
  description:
    "Run `make` to build targets in a project with a Makefile. Supports standard targets (all, clean, install) and flags (-j4, -C, -k, -f, etc.). Prefer `ninja` when available for faster parallel builds. This tool is intended to assist with building the user's project. It is NOT a workaround for the missing bash tool — do not use it to run arbitrary commands, pipelines, or scripts that are unrelated to building, testing, or packaging the project.",
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
      .describe("Arguments to pass to `make`, e.g. `-j4`, `-C src`, `-f Makefile`, `-k`."),
  },
  async execute(args, context) {
    if (!Bun.which("make")) {
      return binaryMissing("make")
    }
    await context.ask({
      permission: "make",
      patterns: ["*"],
      always: ["*"],
      metadata: {
        command: "make",
        args: args.args ?? [],
        directory: args.directory ?? context.directory,
      },
    })
    const cwd = resolveDir(args.directory, context.directory)
    const cmd = ["make", ...(args.args ?? [])]
    const res = await exec(cmd, cwd)
    return present(res, cmd.join(" "), cwd)
  },
})