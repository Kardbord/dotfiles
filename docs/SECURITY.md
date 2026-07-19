# Security Posture

## Goal

Mitigate supply-chain attacks from untrusted code executed during package installs,
dependency builds, and IDE plugin updates. Protect credentials from exfiltration.
Balance security with convenience so the system doesn't get bypassed.

No system is perfectly secure because it would be too inconvenient to use. The aim
here is to protect against low-hanging attack vectors wherever possible.

## Layers

### Secrets Management (gopass + gpg)

Secrets live in an encrypted store, never in plaintext config. Retrieved at runtime
as needed. Scope them minimally: API keys go only to tools that need them.

#### Setup

##### First time setup

**Install prerequisites:**

```
# openSUSE
zypper install gopass gpg2 git
```

**Copy `gopass` configuration:**

```
mkdir -m 700 -p "${HOME}/.config/gopass"
cp ./.config/gopass/config "${HOME}/.config/gopass/config"
```

**Set up `gopass` for age:**

```
gopass setup --crypto age
```

You will be prompted to create a new age keypair. When prompted to add a git
remote, say "Yes". Provide the git remote, ex: `git@github.com:<org|owner>/<repo>.git`

**(Optional) Add your SSH key as a recipient:**



**Usage:**

Add a new secret:

```
gopass insert personal/github/api-key <TOKEN>
```

This stores your personal github token under `personal/github/api-key`.
Organize secrets in a hierarchy by path (e.g., `work/aws-key`, `personal/github/api-key`).

Retrieve a secret:

```
gopass show personal/github/api-key
```

Or copy it to the clipboard without echoing:

```
gopass -c personal/github/api-key
```

List all stored secrets:

```
gopass list
```

Sync secrets with the git remote:

```
gopass sync
```

Inject a secret into a subprocess environment:

```
gopass env personal/github/api-key -- foocmd fooarg1 fooarg2
```

#### Multi-machine setup

**Adding another machine (or another user):**

1. On the new machine, install gopass and set up a gopass GPG identity.
2. Share the public key with an existing store recipient.
3. On an already-authorized machine, add the new public key as a recipient, then
   re-encrypt the store and sync:
   ```
   gopass recipients add <PUBLIC-KEY>
   gopass fsck
   gopass sync
   ```
   `gopass fsck` re-encrypts all secrets for the new recipient set.
4. On the new machine, clone and sync the store:
   ```
   gopass clone --crypto age git@github.com:<user>/<repo>.git && gopass sync
   ```

   Now the new recipient can access the secrets in the store.

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
