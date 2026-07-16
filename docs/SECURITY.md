# Dev Environment Security Posture

## Goal

Mitigate supply-chain attacks from untrusted code executed during package installs, dependency builds, and IDE plugin updates. Protect credentials from exfiltration. Balance security with convenience so the system doesn't get bypassed.

## Layers

### Secrets Management (passage + age)

Secrets live in an encrypted store, never in plaintext config. Retrieved at execution time, not at shell or Neovim load. Scoped minimally: API keys go only to tools that need them, SSH/GPG keys inaccessible by default.

### Opt-In Sandboxing (bubblewrap)

Explicit, not automatic. A `sandbox` function wraps commands in `bwrap` when you choose to. Avoids false-positive friction that leads to disabling the whole system. Default profile: read-only root filesystem, network isolation (`--unshare-net`), sensitive directories (`~/.ssh`, `~/.gnupg`, `~/.passage`) overlaid with empty tmpfs. Network-enabled variant exists for package installs needing registry access.

### Filesystem Permissions

Independent of sandboxing. Provides a safety net when sandboxes fail or are bypassed.

**System-level:** Mount options (`nosuid`, `nodev`, `noexec`) on partitions like `/home` and `/opt`. Immutable files (`chattr +i`) on critical binaries and configs. Full-disk encryption (LUKS2) for data at rest.

**User-level:** Strict umask (`077`), `chmod 700` on `~/.ssh`, `~/.gnupg`, `~/.passage`. ACLs for fine-grained exceptions. Separate Unix users for different workflows (dev, admin, CI) to isolate credentials and file ownership.

### Firewall / Network Isolation

Independent of `bwrap --unshare-net`. Provides host-level egress control that persists regardless of sandbox state.

**Outbound:** Default-deny egress. Whitelist known-good destinations (package registries, API endpoints). Application-specific rules via uid matching. Zone-based segmentation by trust level (trusted, external, blocked).

**Inbound:** Deny all incoming unless running servers. Periodic port auditing (`ss -tulpn`, `nmap localhost`) to detect unexpected listeners.

### Neovim Plugin Sandboxing

Plugin build hooks (`:Lazy update`, `:Mason update`, `:TSUpdate`) route through `custom/sandbox.lua`, wrapping build commands in `bwrap` with the same isolation profile. ACP providers (avante.nvim's opencode integration) also sandboxed. Falls back gracefully to unsandboxed execution with a warning if `bwrap` is unavailable.

### Integrity Verification (Optional)

Post-install hash verification for high-assurance tool installs. Catches tampering after download but before execution.

## How the Layers Interlock

Each layer should be able to stop an attack on its own. An adversary must defeat all of them simultaneously.

| Attack Vector | bwrap | Filesystem | Firewall |
|---------------|-------|------------|----------|
| Malicious `npm install` script | `--unshare-net` blocks exfil | Can't write outside allowed dirs | Outbound blocked by default |
| Compromised `pip` module | Secrets not in env | Can't read `~/.ssh` | No egress to unknown hosts |
| SUID privilege escalation | N/A | `nosuid` mount stops it | N/A |
| Credential theft via env leak | Secrets retrieved at runtime only | `chmod 700` on passage store | Transmission blocked |
| Physical disk theft | N/A | Full-disk encryption | N/A |

**If bwrap fails:** Firewall still blocks exfil, filesystem permissions still restrict writes, secrets not stored in plaintext.

**If firewall is misconfigured:** bwrap `--unshare-net` still denies egress, filesystem permissions prevent persistent writes.

**If filesystem permissions are too loose:** bwrap isolates to sandboxed tree, firewall limits where leaked data can go.

## Principles

1. **Opt-in, not automatic.** Explicit sandboxing reduces friction-driven workarounds.
2. **Secrets are ephemeral.** Retrieved at call time, injected into the sandboxed process only, never persisted in memory or config.
3. **Deny by default.** Network off, sensitive paths hidden, root filesystem read-only. Grant access only when needed.
4. **Layered defense.** No single mechanism is sufficient. bwrap, filesystem permissions, firewall rules, and secret management each provide independent coverage.
5. **Each layer stands alone.** If one fails, others still catch the attack.
6. **Convenience matters.** Over-engineered security gets bypassed. If the sandbox fights you, simplify it.
