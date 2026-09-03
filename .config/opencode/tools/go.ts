import { tool } from "@opencode-ai/plugin"
import path from "node:path"
import { exec, present, resolveDir, binaryMissing, isWithinWorkingTree } from "./_helpers"

const directoryArg = tool.schema
  .string()
  .optional()
  .describe("Directory to run the command in, relative to the session working directory. Defaults to the session working directory.")

const targetsArg = tool.schema
  .array(tool.schema.string())
  .optional()
  .describe("Package arguments to pass to `go test`, e.g. `./...`. Defaults to `./...`.")

export const format = tool({
  description:
    "Recursively format Go source in the given directory using `gofmt -s -w .`. Writes files in place.",
  args: { directory: directoryArg },
  async execute(args, context) {
    if (!Bun.which("gofmt")) {
      return binaryMissing("gofmt")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const res = await exec(["gofmt", "-s", "-w", "."], cwd)
    return present(res, "gofmt -s -w .", cwd)
  },
})

export const tidy = tool({
  description: "Run `go mod tidy` in the given directory to clean up module dependencies.",
  args: { directory: directoryArg },
  async execute(args, context) {
    if (!Bun.which("go")) {
      return binaryMissing("go")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const res = await exec(["go", "mod", "tidy"], cwd)
    return present(res, "go mod tidy", cwd)
  },
})

export const vet = tool({
  description: "Run `go vet ./...` in the given directory to statically analyze Go source.",
  args: { directory: directoryArg },
  async execute(args, context) {
    if (!Bun.which("go")) {
      return binaryMissing("go")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const res = await exec(["go", "vet", "./..."], cwd)
    return present(res, "go vet ./...", cwd)
  },
})

export const lint = tool({
  description:
    "Run `golangci-lint run ./...` in the given directory. Reports nothing when clean.",
  args: { directory: directoryArg },
  async execute(args, context) {
    if (!Bun.which("golangci-lint")) {
      return binaryMissing("golangci-lint")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const res = await exec(["golangci-lint", "run", "./..."], cwd)
    return present(res, "golangci-lint run ./...", cwd)
  },
})

function resolveRunTarget(target: string, cwd: string): string {
  const root = path.resolve(cwd)
  if (target.includes("@")) {
    throw new Error(
      `\`go run\` target \`${target}\` may not use module version syntax. Only packages already present in the working tree can be run.`,
    )
  }
  if (target.startsWith(".")) {
    const resolvedTarget = path.resolve(root, target)
    if (!isWithinWorkingTree(root, resolvedTarget)) {
      throw new Error(
        `\`go run\` target \`${target}\` resolves outside the working tree \`${cwd}\`. Only packages in the working tree can be run.`,
      )
    }
    return target
  }
  if (path.isAbsolute(target)) {
    if (!isWithinWorkingTree(root, target)) {
      throw new Error(
        `\`go run\` target \`${target}\` is outside the working tree \`${cwd}\`. Only packages in the working tree can be run.`,
      )
    }
    return target
  }
  throw new Error(
    `\`go run\` target \`${target}\` is a bare package path. Only relative or absolute paths within the working tree are accepted (e.g. \`.\` or \`./cmd/server\`).`,
  )
}

const runTargetArg = tool.schema
  .string()
  .optional()
  .describe(
    "Package in the working tree to run, e.g. `.` or `./cmd/server`. Remote or proxy-fetched packages are disallowed. Defaults to `.`.",
  )

const runArgsArg = tool.schema
  .array(tool.schema.string())
  .optional()
  .describe("Arguments to pass to the program after the package.")

export const build = tool({
  description: "Run `go build ./...` in the given directory to compile all packages.",
  args: { directory: directoryArg },
  async execute(args, context) {
    if (!Bun.which("go")) {
      return binaryMissing("go")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const res = await exec(["go", "build", "./..."], cwd)
    return present(res, "go build ./...", cwd)
  },
})

export const run = tool({
  description:
    "Build and run a Go program in the given directory using `go run`. Only runs packages in the working tree (e.g. `.` or `./cmd/server`), never remote or proxy-fetched programs.",
  args: { directory: directoryArg, target: runTargetArg, args: runArgsArg },
  async execute(args, context) {
    if (!Bun.which("go")) {
      return binaryMissing("go")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const target = resolveRunTarget(args.target ?? ".", cwd)
    const cmd = ["go", "run", target, ...(args.args ?? [])]
    const res = await exec(cmd, cwd)
    return present(res, cmd.join(" "), cwd)
  },
})

export const vuln = tool({
  description:
    "Run `govulncheck ./...` in the given directory to report known vulnerabilities in dependencies.",
  args: { directory: directoryArg },
  async execute(args, context) {
    if (!Bun.which("govulncheck")) {
      return binaryMissing("govulncheck")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const res = await exec(["govulncheck", "./..."], cwd)
    return present(res, "govulncheck ./...", cwd)
  },
})

function resolveTargets(targets: string[], cwd: string): string[] {
  const root = path.resolve(cwd)
  for (const t of targets) {
    if (t.includes("@")) {
      throw new Error(
        `\`go test\` target \`${t}\` may not use module version syntax. Only packages in the working tree can be tested.`,
      )
    }
    if (!t.startsWith(".") && !path.isAbsolute(t)) {
      throw new Error(
        `\`go test\` target \`${t}\` is a bare package path. Only relative or absolute paths within the working tree are accepted (e.g. \`.\` or \`./cmd/server\`).`,
      )
    }
    const resolvedTarget = path.resolve(root, t)
    if (!isWithinWorkingTree(root, resolvedTarget)) {
      throw new Error(
        `\`go test\` target \`${t}\` resolves outside the working tree \`${cwd}\`. Only packages in the working tree can be tested.`,
      )
    }
  }
  return targets
}

async function goTest(cwd: string, goFlags: string[]): Promise<string> {
  if (!Bun.which("go")) {
    return binaryMissing("go")
  }
  if (Bun.which("gotestsum")) {
    const res = await exec(
      ["gotestsum", "--format", "standard-quiet", "--", ...goFlags],
      cwd,
    )
    return present(res, `gotestsum --format standard-quiet -- ${goFlags.join(" ")}`, cwd)
  }
  const goArgs = ["go", "test", ...goFlags]
  const res = await exec(goArgs, cwd)
  return present(res, goArgs.join(" "), cwd)
}

export const test = tool({
  description:
    "Run Go tests with shuffle enabled and a cache-busting count of 1. Prefers gotestsum with a failure-focused summary when available; falls back to `go test`.",
  args: { directory: directoryArg, targets: targetsArg },
  async execute(args, context) {
    const cwd = resolveDir(args.directory, context.directory)
    const targets = resolveTargets(args.targets ?? ["./..."], cwd)
    return goTest(cwd, [...targets, "-count=1", "-shuffle=on"])
  },
})

export const testRace = tool({
  description:
    "Run Go tests with the race detector enabled, shuffle enabled, and a cache-busting count of 1.",
  args: { directory: directoryArg, targets: targetsArg },
  async execute(args, context) {
    const cwd = resolveDir(args.directory, context.directory)
    const targets = resolveTargets(args.targets ?? ["./..."], cwd)
    return goTest(cwd, [...targets, "-count=1", "-shuffle=on", "-race"])
  },
})

export const testCover = tool({
  description:
    "Run Go tests with shuffle enabled, coverage reporting, and a cache-busting count of 1.",
  args: { directory: directoryArg, targets: targetsArg },
  async execute(args, context) {
    const cwd = resolveDir(args.directory, context.directory)
    const targets = resolveTargets(args.targets ?? ["./..."], cwd)
    return goTest(cwd, [...targets, "-count=1", "-shuffle=on", "-cover"])
  },
})

export const bench = tool({
  description:
    "Run Go benchmarks with memory allocation reporting (`-bench=. -benchmem -run=^$`) in the given directory.",
  args: { directory: directoryArg, targets: targetsArg },
  async execute(args, context) {
    if (!Bun.which("go")) {
      return binaryMissing("go")
    }
    const cwd = resolveDir(args.directory, context.directory)
    const targets = resolveTargets(args.targets ?? ["./..."], cwd)
    const res = await exec(["go", "test", ...targets, "-run=^$", "-bench=.", "-benchmem"], cwd)
    return present(res, `go test ${targets.join(" ")} -run=^$ -bench=. -benchmem`, cwd)
  },
})

const targetArg = tool.schema
  .string()
  .describe("The Go package to fuzz, e.g. `./foo/bar`. This should generally be a relative path.")

const testNameArg = tool.schema
  .string()
  .describe("The name of the fuzz test function, e.g. `FuzzFoo`.")

const fuzzTimeArg = tool.schema
  .string()
  .optional()
  .describe("Fuzz time duration, e.g. `10s`. Defaults to `10s`.")

export const fuzz = tool({
  description: "Run a Go fuzz test targeting the specified test function within a package using `go test -fuzz`.",
  args: { target: targetArg, test: testNameArg, fuzztime: fuzzTimeArg },
  async execute(args, context) {
    if (!Bun.which("go")) {
      return binaryMissing("go")
    }
    const target = args.target
    const testName = args.test
    const fuzztime = args.fuzztime ?? "10s"
    const cmd = ["go", "test", "-fuzz", testName, "-fuzztime", fuzztime, target]
    const res = await exec(cmd, context.directory)
    return present(res, cmd.join(" "), context.directory)
  },
})
