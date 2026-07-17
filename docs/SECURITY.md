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

### Opt-In Sandboxing (firejail)

Explicit, not automatic. A `firejail <cmd>` invocation wraps a command in a
sandbox with an application-specific profile when you choose to. Firejail
selects the appropriate profile automatically based on the command name,
leveraging community-maintained profiles for tools like `npm`, `pip`, and
`make`.

This approach reduces maintenance burden compared to hand-rolling `bwrap`
arguments, and relies on a single well-maintained tool rather than
bespoke sandbox configurations. Custom profiles can be added under
`~/.config/firejail/` (e.g., `myapp.profile`).

**OpenSUSE (default behavior).** The firejail package on OpenSUSE is
installed with the setuid bit set (`04750`) and ownership
`root:firejail` — the `firejail` group is created automatically. The
only required step is to add your user to the group:

```
sudo usermod -aG firejail $USER
```

Log out and back in for membership to take effect. These settings are
managed by `permctl` and persist across package updates automatically.

**Other distributions.** Firejail is a *setuid-root binary* — it runs
with elevated privileges so it can create kernel sandbox primitives
(namespaces, etc.). Restricting its use to a dedicated group is
recommended:

```
sudo groupadd firejail
sudo usermod -aG firejail $USER
sudo chown root:firejail $(which firejail)
sudo chmod 4750 $(which firejail)
```

Package updates may reset these permissions to defaults. See your
distribution's documentation for how to make file permissions survive
package updates. (If you're reading this on a distro other than
OpenSUSE, please contribute the appropriate instructions!)

Verify permissions after setup or an update with:

```
ls -la $(which firejail)
# Expected: -rwsr-x--- 1 root firejail ...
```

**WSL2 (Windows Subsystem for Linux).** Firejail requires `container=lxc` to be
set in the environment before invocation on WSL2. This can be done inline:

```
container=lxc firejail <cmd>
```

When using the Neovim sandbox module (`custom/sandbox.lua`), this is handled
automatically — see [Neovim Plugin Sandboxing](#neovim-plugin-sandboxing).

### Filesystem Permissions

Independent of this config. Provides a safety net in case sandboxing fails
or is not used. These settings are usually fine out of the box, but can be
further locked down if desired by you or a system administrator.

### Firewall / Network Isolation

Independent of this config. Provides host-level ingress/egress control.
This should be configured to your desired level by you or a system administrator.

### Neovim Plugin Sandboxing

Plugin build hooks route through `custom/sandbox.lua`, wrapping build
commands in `firejail` with automatic profile selection. Spawned subprocesses
should also be sandboxed. Graceful fallback to unsandboxed execution with a
warning should be configured in case `firejail` is unavailable.

### Integrity Verification (Optional)

Post-install hash verification should be performed for high-assurance tool installs.
This catches tampering after download but before execution.

## How the Layers Interlock

Each layer should be able to stop an attack on its own.
An adversary must defeat all of them simultaneously.

| Attack Vector             | Secrets Manager           | Sandboxing                     | Filesystem                       | Firewall                   |
|---------------------------|---------------------------|--------------------------------|----------------------------------|----------------------------|
| Malicious Makefile        | Minimal secrets available | Per-profile restrictions       | Can't r/w/e outside allowed dirs | Outbound rules block exfil |
| Compromised `npm` module  | Minimal secrets available | Per-profile restrictions       | Can't r/w/e outside allowed dirs | Outbound rules block exfil |
| SUID privilege escalation | N/A                       | Per-profile restrictions       | `nosuid` mount stops it          | N/A                        |
| Credential theft          | Minimal secrets available | Per-profile restrictions       | Can't r/w/e outside allowed dirs | Outbound rules block exfil |
| Physical disk theft       | Secrets are encrypted     | N/A                            | Full-disk encryption             | N/A                        |

**If sandboxing fails:** Firewall still blocks exfil, filesystem permissions still restrict writes, secrets are not stored in plaintext.

**If firewall is misconfigured:** sandboxing still denies egress, filesystem permissions prevent persistent writes.

**If filesystem permissions are too loose:** sandboxing isolates changes to sandbox, firewall limits where leaked data can go.

## Principles

1. **Opt-in, not automatic.** Explicit sandboxing reduces friction-driven workarounds.
2. **Secrets are ephemeral.** Retrieved at runtime, injected into processes only when necessary.
3. **Community profiles.** Application-specific profiles are maintained by the firejail community, reducing the need for bespoke sandbox configuration.
4. **Custom profiles.** User-specific profiles can be added under `~/.config/firejail/` for tools not covered by the default set.
5. **Layered defense.** Sandboxing, filesystem permissions, firewall rules, and secret management each provide independent coverage.
6. **Each layer stands alone.** If one fails, others still provide protections.
7. **Convenience matters.** Over-engineered security gets bypassed. If the sandbox fights you, simplify it.
