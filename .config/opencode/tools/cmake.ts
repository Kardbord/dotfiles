import { tool } from "@opencode-ai/plugin"
import { exec, present, resolveDir, binaryMissing } from "./_helpers"

export default tool({
  description:
    "Run `cmake` to configure, build, and install CMake-based projects. Configure: `cmake -B build`. Build: `cmake --build build`. Install: `cmake --install build`. Supports generators (`-G Ninja` preferred, also `Unix Makefiles`), variables (`-DCMAKE_BUILD_TYPE=Release`), and other options. For testing use `ctest`, for packaging use `cpack`. This tool is intended to assist with building the user's project. It is NOT a workaround for the missing bash tool — do not use it to run arbitrary commands, pipelines, or scripts that are unrelated to building, testing, or packaging the project.",
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
      .describe("Arguments to pass to `cmake`, e.g. `-B build`, `--build build`, `-G Ninja`, `-DCMAKE_BUILD_TYPE=Release`."),
  },
  async execute(args, context) {
    if (!Bun.which("cmake")) {
      return binaryMissing("cmake")
    }
    await context.ask({
      permission: "cmake",
      patterns: ["*"],
      always: ["*"],
      metadata: {
        command: "cmake",
        args: args.args ?? [],
        directory: args.directory ?? context.directory,
      },
    })
    const cwd = resolveDir(args.directory, context.directory)
    const cmd = ["cmake", ...(args.args ?? [])]
    const res = await exec(cmd, cwd)
    return present(res, cmd.join(" "), cwd)
  },
})