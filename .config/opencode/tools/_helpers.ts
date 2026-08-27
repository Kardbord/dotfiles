import path from "node:path"
import { existsSync } from "node:fs"

export interface RunResult {
  code: number
  stdout: string
  stderr: string
}

const TIMEOUT_MS = 60_000
const SIGKILL_GRACE_MS = 5_000
const PROCESS_EXIT_DEADLINE_MS = SIGKILL_GRACE_MS + 1_000

export async function exec(cmd: string[], cwd: string): Promise<RunResult> {
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
export function isWithinWorkingTree(root: string, resolved: string): boolean {
  return resolved === root || resolved.startsWith(root + path.sep)
}

export function binaryMissing(name: string): string {
  return `${name} is not installed or not on PATH. Stop and inform the user of your current progress.`
}

export function resolveDir(input: string | undefined, base: string): string {
  const root = path.resolve(base)
  const resolved = input && input !== "." ? path.resolve(base, input) : root
  if (!isWithinWorkingTree(root, resolved)) {
    throw new Error(
      `Directory \`${input}\` resolves outside the working tree \`${base}\`. Only directories within the working tree are allowed.`,
    )
  }
  return resolved
}

export function resolveFiles(files: string[], base: string): string[] {
  const root = path.resolve(base)
  return files.map((file) => {
    const resolved = path.resolve(root, file)
    if (!isWithinWorkingTree(root, resolved)) {
      throw new Error(
        `File \`${file}\` resolves outside the working tree \`${base}\`. Only files within the working tree are allowed.`,
      )
    }
    return resolved
  })
}

export function present(result: RunResult, cmdLine: string, cwd: string): string {
  const out = [result.stdout.trim(), result.stderr.trim()].filter(Boolean).join("\n\n")
  if (result.code === 0) {
    return out ? out : `OK: \`${cmdLine}\` succeeded in \`${cwd}\`.`
  }
  throw new Error(
    `\`${cmdLine}\` failed (exit ${result.code}) in \`${cwd}\`.\n\n${out || "(no output)"}`,
  )
}
