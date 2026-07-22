# Security Posture

## Goal

Mitigate supply-chain attacks from untrusted code executed during package installs,
dependency builds, and IDE plugin updates. Protect credentials from exfiltration.
Balance security with convenience so the system doesn't get bypassed.

No system is perfectly secure because it would be too inconvenient to use. The aim
here is to protect against low-hanging attack vectors wherever possible.

## Layers

### Secrets Management (gopass + age)

Secrets live in an encrypted git-backed store, never in plaintext config. Retrieved
at runtime as needed. Scope them minimally: API keys go only to tools that need them.

Uses the [age](https://age-encryption.org) encryption backend. Your private key lives
in a scrypt-encrypted identity file at `~/.config/gopass/age/identities`. SSH keys
from `~/.ssh/` are also discovered and used as decryption identities automatically.

#### Setup

##### First time setup

**Install prerequisites:**

```
# openSUSE
zypper install gopass age git
```

**Set up `gopass` for age:**

```
gopass setup --crypto age
```

This generates a new secret store, a X25519 keypair, adds your public key
(`age1...`) to the store's recipients list, and initializes a git repo to
manage the store and track changes.

You will be prompted to create a passphrase for your identity file. This passphrase
encrypts the file at `~/.config/gopass/age/identities` — without it, anyone with
filesystem access could steal your secret key. Enter the same passphrase when
prompted again (it reads back the file to confirm the key was created).

When prompted to add a git remote, say "Yes" if you want to sync your encrypted
store across machines or users. You must provide a link to a newly created git
remote with no contents. The syntax is `<email>:<org|owner>/<repo>.git` ex:

```
git@github.com:Kardbord/my-secret-repo.git
```

**(Optional) Add your SSH key as a recipient:**

The age backend auto-discovers SSH keys from `~/.ssh/`. To add your SSH public key
as a recipient so secrets are encrypted for it too:

```
gopass recipients add "$(cat ~/.ssh/id_ed25519.pub)"
gopass fsck --decrypt
gopass sync
```

**Avoiding repeated passphrase prompts:**

By default, the passphrase is cached in memory for the lifetime of a single
`gopass` command. Since the CLI exits after each invocation, you'll be prompted
on every command unless you use one of these strategies:

- **Age agent** (recommended): caches decrypted identities in a background daemon.
  ```
  gopass config age.agent-enabled true
  ```
  The agent auto-starts on the first decrypt, prompts once, and handles subsequent
  decryption without further prompts — even after `gopass` exits.

- **Environment variable**: set the passphrase once per shell session.
  ```
  read -s GOPASS_AGE_PASSWORD
  export GOPASS_AGE_PASSWORD
  ```

- **OS keychain**: stores the passphrase in the system keyring.
  ```
  gopass config age.usekeychain true
  ```

**Usage:**

Add a new secret:

```
gopass insert personal/github/api-key
```

You will be prompted for the secret value.

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

Re-encrypt old secrets so that new recipients can read them:

```
gopass fsck --decrypt
gopass sync
```

#### Multi-machine setup

Each machine has its own keypair (age-native or SSH). Recipients in the store's
`.age-recipients` file determine who can decrypt. To authorize a new machine,
add its **public key** as a recipient, re-encrypt, and push.

**Adding another machine (or another user):**

1. On an already-authorized machine, add the new machine's public key as a recipient,
   then re-encrypt the store and sync:
   ```
   gopass recipients add <PUBLIC-KEY>
   gopass fsck --decrypt
   gopass sync
   ```
   The public key can be either an age-native key (`age1...`) or an SSH public key
   (`ssh-ed25519 AAAAC3...`). `gopass fsck --decrypt` re-encrypts all existing
   secrets for the new recipient set.

2. On the new machine, install gopass and clone the store:
   ```
   gopass clone --crypto age [EMAIL]:<user>/<repo>.git
   gopass sync
   ```
   No identity setup is needed if using SSH keys — the age backend auto-discovers
   `~/.ssh/` and uses the corresponding private key for decryption. For age-native
   keys, run `gopass setup --crypto age` first to create a local identity, then add
   its public key as a recipient from an already-authorized machine.

Now the new recipient can access the secrets in the store.

### Sandboxing (flatpak, firejail, bubblewrap)

Supply chain attacks and otherwise compromised FOSS is especially
common now in the day of AI. Sandboxing can mitigate the blast radius
of these vulnerabilities significantly. The easiest way to accomplish
this is to install medium/high-risk tools as
[flatpaks](https://github.com/flatpak/flatpak), which generally run
with as many isolation restrictions as possible (without rendering
the tool unusable) out of the box.

Examples of high-risk tools are anything that relies heavily on
third-party extensions (such as neovim and vscode), or anything
that executes arbitrary code (Makefiles, shell scripts, etc.).

For risky tools that are not available as flatpaks, other tools
exist to help with sandboxing. `firejail` and `bubblewrap`
(`bwrap`) are two of the most common. Of course, it remains that
the best defense is to be vigilant of what you are doing and
running in your day to day work.

### Filesystem Permissions

Provides a safety net in case sandboxing fails or is not used.
These settings are usually fine out of the box, but can be
further locked down if desired by you or a system administrator.

### Firewall / Network Isolation

Provides host-level ingress/egress control.
This should be configured to your desired level by you or a system administrator.

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
