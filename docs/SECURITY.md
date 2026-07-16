# Security Posture

## Goal

Mitigate supply-chain attacks from untrusted code executed during package installs,
dependency builds, and IDE plugin updates. Protect credentials from exfiltration.
Balance security with convenience so the system doesn't get bypassed.

No system is perfectly secure because it would be too inconvenient to use. The aim
here is to protect against low-hanging attack vectors wherever possible.

## Layers

### Secrets Management (passage + age)

Secrets live in an encrypted store, never in plaintext config. Retrieved at runtime
as needed. Scoped minimally: API keys go only to tools that need them.

### Opt-In Sandboxing (bubblewrap)

Explicit, not automatic. A `sandbox` function wraps commands in `bwrap` when you
choose to. Avoids false-positive friction that leads to disabling the whole
system. Default profile: read-only root filesystem, network isolation
(`--unshare-net`), sensitive directories (`~/.ssh`, `~/.gnupg`, `~/.passage`) overlaid
with empty tmpfs. Network-enabled variant exists for package installs
needing registry access.

### Filesystem Permissions

Independent of this config. Provides a safety net in case sandboxing fails
or is not used. These settings are usually fine out of the box, but can be
further locked down if desired by you or a system administrator.

### Firewall / Network Isolation

Independent of this config. Provides host-level ingress/egress control.
This should be configured to your desired level by you or a system administrator.

### Neovim Plugin Sandboxing

Plugin build hooks should route through `custom/sandbox.lua`, wrapping build
commands in `bwrap` with the same isolation profile as above. Spawned subprocesses
should also be sandboxed. Graceful fallback to unsandboxed execution with a
warning should be configured in case `bwrap` is unavailable.

### Integrity Verification (Optional)

Post-install hash verification should be performed for high-assurance tool installs.
This catches tampering after download but before execution.

## How the Layers Interlock

Each layer should be able to stop an attack on its own.
An adversary must defeat all of them simultaneously.

| Attack Vector             | Secrets Manager           | Sandboxing                     | Filesystem                       | Firewall                   |
|---------------------------|---------------------------|--------------------------------|----------------------------------|----------------------------|
| Malicious Makefile        | Minimal secrets available | Minimal access to fs, net, env | Can't r/w/e outside allowed dirs | Outbound rules block exfil |
| Compromised `npm` module  | Minimal secrets available | Minimal access to fs, net, env | Can't r/w/e outside allowed dirs | Outbound rules block exfil |
| SUID privilege escalation | N/A                       | Minimal access to fs, net, env | `nosuid` mount stops it          | N/A                        |
| Credential theft          | Minimal secrets available | Minimal access to fs, net, env | Can't r/w/e outside allowed dirs | Outbound rules block exfil |
| Physical disk theft       | Secrets are encrypted     | N/A                            | Full-disk encryption             | N/A                        |

**If sandboxing fails:** Firewall still blocks exfil, filesystem permissions still restrict writes, secrets are not stored in plaintext.

**If firewall is misconfigured:** sandboxing still denies egress, filesystem permissions prevent persistent writes.

**If filesystem permissions are too loose:** sandboxing isolates changes to sandbox, firewall limits where leaked data can go.

## Principles

1. **Opt-in, not automatic.** Explicit sandboxing reduces friction-driven workarounds.
2. **Secrets are ephemeral.** Retrieved at runtime, injected into processes only when necessary.
4. **Layered defense.** Sandboxing, filesystem permissions, firewall rules, and secret management each provide independent coverage.
5. **Each layer stands alone.** If one fails, others still provide protections.
6. **Convenience matters.** Over-engineered security gets bypassed. If the sandbox fights you, simplify it.
