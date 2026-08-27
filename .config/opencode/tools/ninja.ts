import { tool } from "@opencode-ai/plugin"
import { exec, present, resolveDir, binaryMissing } from "./_helpers"

export default tool({
  description:
    "Run `ninja` to build projects with a build.ninja file. Ninja automatically parallelizes builds based on available CPUs, making it the preferred build tool for speed. Common flags: `-j<N>` to limit parallelism, `-C <dir>` to build in a subdirectory, `-t targets` to list targets, `-t clean` to clean. This tool is intended to assist with building the user's project. It is NOT a workaround for the missing bash tool — do not use it to run arbitrary commands, pipelines, or scripts that are unrelated to building, testing, or packaging the project.",
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
      .describe("Arguments to pass to `ninja`, e.g. `-j4`, `-C build`, `-t clean`."),
  },
  async execute(args, context) {
    if (!Bun.which("ninja")) {
      return binaryMissing("ninja")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const cmd = ["ninja", ...(args.args ?? [])]
    const res = await exec(cmd, cwd)
    return present(res, cmd.join(" "), cwd)
  },
})