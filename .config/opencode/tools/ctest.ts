import { tool } from "@opencode-ai/plugin"
import { exec, present, resolveDir, binaryMissing } from "./_helpers"

export default tool({
  description:
    "Run `ctest` to execute tests defined in a CMake-based project. Common flags: `--test-dir build`, `-R <regex>` to filter tests by name, `--verbose` for full output, `--output-on-failure` to show output only for failed tests, `-j<N>` for parallel test execution. This tool is intended to assist with testing the user's project. It is NOT a workaround for the missing bash tool — do not use it to run arbitrary commands, pipelines, or scripts that are unrelated to building, testing, or packaging the project.",
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
      .describe("Arguments to pass to `ctest`, e.g. `--test-dir build`, `-R mytest`, `--verbose`, `--output-on-failure`."),
  },
  async execute(args, context) {
    if (!Bun.which("ctest")) {
      return binaryMissing("ctest")
    }
    await context.ask({
      permission: "ctest",
      patterns: ["*"],
      always: ["*"],
      metadata: {
        command: "ctest",
        args: args.args ?? [],
        directory: args.directory ?? context.directory,
      },
    })
    const cwd = resolveDir(args.directory, context.directory)
    const cmd = ["ctest", ...(args.args ?? [])]
    const res = await exec(cmd, cwd)
    return present(res, cmd.join(" "), cwd)
  },
})