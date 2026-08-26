import { tool } from "@opencode-ai/plugin"
import { exec, present, resolveDir, binaryMissing } from "./_helpers"

export default tool({
  description:
    "Run `actionlint` to lint GitHub Actions workflow files. Reports nothing when clean.",
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
      .describe("Arguments to pass to `actionlint`, e.g. `-no-color`, `-format '{{range .}}{{.Message}}{{end}}'`."),
  },
  async execute(args, context) {
    if (!Bun.which("actionlint")) {
      return binaryMissing("actionlint")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const cmd = ["actionlint", ...(args.args ?? [])]
    const res = await exec(cmd, cwd)
    return present(res, cmd.join(" "), cwd)
  },
})
