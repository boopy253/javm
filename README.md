# JAVM — Java Version Manager (scripts only)

A lightweight Java version manager that works in **locked-down environments**: no installers, no binaries, just shell scripts.

- Works with **Git Bash (Bash/MSYS/Cygwin)**, **PowerShell**, and **cmd.exe**
- Per-user configuration (registry + default) stored in plain text files
- Switch Java versions per shell session
- Optional **directory-based auto switching** via `.java-version` (Bash)

---

## Features

- Register multiple JDK installations with simple aliases (`jdk8`, `jdk21`, `temurin-17`, …)
- Switch versions instantly in the current shell (`JAVA_HOME` + `PATH`)
- Set a default Java that loads when a new shell starts
- (Bash) Auto-switch based on a `.java-version` file in the current directory or parent directories

---

## Installation

Clone anywhere (recommended: `~/.javm`):

```bash
git clone https://github.com/boopy253/javm.git "$HOME/.javm"
```

> The registry is stored in `versions.map` and the default alias in `default`.

---

## Shell setup

### Git Bash / Bash

Add to `~/.bashrc` or `~/.bash_profile`:

```bash
# Optional: auto-switch based on .java-version
export JAVM_AUTO=1

# Load JAVM
[[ -f "$HOME/.javm/javm.sh" ]] && source "$HOME/.javm/javm.sh"
```

Open a new terminal (or `source ~/.bashrc`).

---

### PowerShell

Add to your PowerShell profile:

- Windows PowerShell 5.1:
  `C:\Users\<you>\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`
- PowerShell 7:
  `C:\Users\<you>\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

```powershell
if (Test-Path "$env:USERPROFILE\.javm\javm.ps1") {
  . "$env:USERPROFILE\.javm\javm.ps1"
}
```

Restart PowerShell.

---

### cmd.exe

Create a **cmd.exe Shortcut** and set its target to:

```bat
cmd.exe /k "%USERPROFILE%\.javm\cmd-init.cmd"
```

This will expose `javm` via `doskey` and load your default Java (if set).

---

## Usage

Register JDKs:

```bash
javm add jdk8  ~/.jdks/jdk8
javm add jdk21 ~/.jdks/jdk21
```

Switch for the current shell:

```bash
javm use jdk21
java -version
```

Set a global default (auto-loaded in new shells):

```bash
javm default jdk21
```

List / inspect:

```bash
javm list
javm current
```

---

## Commands

| Command                  | Description                               |
| ------------------------ | ----------------------------------------- |
| `javm list` / `javm ls`  | List registered JDKs                      |
| `javm add <alias> <dir>` | Register a JDK home directory             |
| `javm use <alias>`       | Switch Java version in the current shell  |
| `javm default [alias]`   | Show or set the default Java alias        |
| `javm rm <alias>`        | Remove an alias                           |
| `javm current`           | Show the active Java alias + `JAVA_HOME`  |
| `javm clear`             | Restore original `PATH` / unset Java vars |

---

## Auto switching (Bash)

Enable it:

```bash
export JAVM_AUTO=1
```

Create a `.java-version` file anywhere in a project (content is an alias):

```txt
jdk8
```

When you `cd` into that project (or any subdirectory), JAVM will automatically run `javm use <alias>`.
When you leave the project, it falls back to your default (if set).

---

## Files & environment variables

JAVM stores configuration in:

- `versions.map` — lines like: `alias|path`
- `default` — the default alias

Environment variables used:

- `JAVM_HOME` — location of the registry and default files
- `JAVM_PATH_BASE` — original `PATH` before JAVM changes it
- `JAVM_CURRENT` — current alias (Bash)
- `JAVM_AUTO=1` — enable `.java-version` auto switching (Bash)

---

## Uninstall

1. Remove the shell init line from your profile (`.bashrc` / PowerShell profile / cmd shortcut).
2. Delete the directory:

```bash
rm -rf "$HOME/.javm"
```

---
