import { tool } from "@opencode-ai/plugin"
import path from "node:path"
import { existsSync } from "node:fs"

interface RunResult {
  code: number
  stdout: string
  stderr: string
}

const TIMEOUT_MS = 60_000
const SIGKILL_GRACE_MS = 5_000
const PROCESS_EXIT_DEADLINE_MS = SIGKILL_GRACE_MS + 1_000

async function exec(cmd: string[], cwd: string): Promise<RunResult> {
  if (!existsSync(cwd)) {
    throw new Error(
      `Directory not found: \`${cwd}\`. Provide a valid \`directory\` or omit it to use the session working directory.`,
    )
  }
  const proc = Bun.spawn(cmd, { cwd, stdout: "pipe", stderr: "pipe", detached: true })
  let timeoutTimer: ReturnType<typeof setTimeout> | undefined
  let sigkillTimer: ReturnType<typeof setTimeout> | undefined

  // Single authority: when the deadline fires we send SIGTERM, arm a SIGKILL
  // escalation, and signal the in-flight reads to treat the result as a timeout.
  const deadline = new Promise<"timeout">((resolve) => {
    timeoutTimer = setTimeout(() => {
      try {
        process.kill(-proc.pid, "SIGTERM")
      } catch {
        // the process may already have exited
      }
      sigkillTimer = setTimeout(() => {
        try {
          process.kill(-proc.pid, "SIGKILL")
        } catch {
          // the process may already have exited
        }
      }, SIGKILL_GRACE_MS)
      resolve("timeout")
    }, TIMEOUT_MS)
  })

  const read = (stream: ReadableStream<Uint8Array> | null): Promise<string> => {
    if (!stream) return Promise.resolve("")
    return new Response(stream).text()
  }

  // Race the full completion (reading both streams AND the process exit) against
  // the deadline, so a slow output drain can never be mistaken for success: we
  // either get the complete output with the real exit code, or we report a timeout.
  const completion = Promise.all([read(proc.stdout), read(proc.stderr), proc.exited]).then(
    ([stdout, stderr, code]) => ({ stdout, stderr, code }),
  )
  // The completion promise may outlive the race when the deadline wins; consume
  // its settlement so a late stream rejection is not an unhandled rejection.
  completion.catch(() => {})
  const outcome = await Promise.race([completion, deadline])

  if (outcome === "timeout") {
    // Give the process the grace window (plus a margin) to die from the kill
    // escalation before surfacing the timeout.
    let graceTimer: ReturnType<typeof setTimeout> | undefined
    await Promise.race([
      proc.exited,
      new Promise((resolve) => {
        graceTimer = setTimeout(resolve, PROCESS_EXIT_DEADLINE_MS)
      }),
    ])
    if (graceTimer) clearTimeout(graceTimer)
    if (sigkillTimer) clearTimeout(sigkillTimer)
    throw new Error(`\`${cmd.join(" ")}\` timed out after ${TIMEOUT_MS / 1000}s in \`${cwd}\`.`)
  }

  if (timeoutTimer) clearTimeout(timeoutTimer)
  return outcome
}

// Syntactic boundary check only: path.resolve does not follow symlinks, so a
// symlink under `root` pointing outside is not detected here.
function isWithinWorkingTree(root: string, resolved: string): boolean {
  return resolved === root || resolved.startsWith(root + path.sep)
}

function binaryMissing(name: string): string {
  return `${name} is not installed or not on PATH. Stop and inform the user of your current progress.`
}

function resolveDir(input: string | undefined, base: string): string {
  const root = path.resolve(base)
  const resolved = input && input !== "." ? path.resolve(base, input) : root
  if (!isWithinWorkingTree(root, resolved)) {
    throw new Error(
      `Directory \`${input}\` resolves outside the working tree \`${base}\`. Only directories within the working tree are allowed.`,
    )
  }
  return resolved
}

function present(result: RunResult, cmdLine: string, cwd: string): string {
  const out = [result.stdout.trim(), result.stderr.trim()].filter(Boolean).join("\n\n")
  if (result.code === 0) {
    return out ? out : `OK: \`${cmdLine}\` succeeded in \`${cwd}\`.`
  }
  throw new Error(
    `\`${cmdLine}\` failed (exit ${result.code}) in \`${cwd}\`.\n\n${out || "(no output)"}`,
  )
}

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
