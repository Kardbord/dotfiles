import { tool } from "@opencode-ai/plugin"
import { exec, present, resolveDir, binaryMissing } from "./_helpers"

export default tool({
  description:
    "Run `cpack` to create distribution packages from a CMake-based project. Common generators: `-G DEB` (Debian), `-G RPM` (Red Hat), `-G ZIP`, `-G TBZ2`. Supports `-C <config>` to specify build configuration (e.g. `Release`), `-B <package-dir>` for output directory. This tool is intended to assist with packaging the user's project. It is NOT a workaround for the missing bash tool — do not use it to run arbitrary commands, pipelines, or scripts that are unrelated to building, testing, or packaging the project.",
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
      .describe("Arguments to pass to `cpack`, e.g. `-G DEB`, `-C Release`, `-B packages`."),
  },
  async execute(args, context) {
    if (!Bun.which("cpack")) {
      return binaryMissing("cpack")
    }
    await context.ask({
      permission: "cpack",
      patterns: ["*"],
      always: ["*"],
      metadata: {
        command: "cpack",
        args: args.args ?? [],
        directory: args.directory ?? context.directory,
      },
    })
    const cwd = resolveDir(args.directory, context.directory)
    const cmd = ["cpack", ...(args.args ?? [])]
    const res = await exec(cmd, cwd)
    return present(res, cmd.join(" "), cwd)
  },
})