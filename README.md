# Shell Doctor

Diagnose the last failed command in your terminal with AI.

When a command fails inside a herdr terminal (`hc run`), a small prompt hook prints:

```
[Shell Doctor] Command failed (exit code: 1)
  Diagnose with: doctor
```

Running `doctor` reads this terminal's transcript with `hc read`, finds the last failure banner, and asks [opencode](https://opencode.ai) to identify the failed command, explain the root cause, and propose an ordered fix plan.

Diagnosis only: Shell Doctor never runs commands or modifies files.

## Requirements

- `hc` (herdr-core) — Shell Doctor works only inside herdr terminals
- `opencode`
- `bash` 4+ (the diagnosis program itself is a Bash script)
- One of: `bash`, `zsh`, `fish` (the prompt integration)

## Layout

```
bin/doctor                 shared diagnosis program (Bash, executable)
scripts/integration.bash   bash prompt hook + doctor wrapper
scripts/integration.zsh    zsh prompt hook + doctor wrapper
scripts/integration.fish   fish postexec hook + doctor wrapper
```

The integrations only print the failure banner; everything else is done by `bin/doctor`.

## Install

1. Add `bin/` to `PATH` (in your shell startup file):

   ```sh
   export PATH="$HOME/Projects/Shell Doctor/bin:$PATH"
   ```

2. Source the integration for your shell:

   ```sh
   # bash — ~/.bashrc
   source "$HOME/Projects/Shell Doctor/scripts/integration.bash"
   ```

   ```sh
   # zsh — ~/.zshrc
   source "$HOME/Projects/Shell Doctor/scripts/integration.zsh"
   ```

   ```fish
   # fish — ~/.config/fish/config.fish
   source "$HOME/Projects/Shell Doctor/scripts/integration.fish"
   ```

3. Start a shell inside herdr:

   ```sh
   hc run bash
   ```

## Use

Run a command that fails, then:

```sh
doctor
```

Example output:

```
[Shell Doctor] Diagnostic context
  Exit code:  1
  Directory:  ~/Projects/Shell Doctor
  System:     Arch Linux, kernel Linux 6.18
  Terminal:   t1v (hc read --lines 200)
  Agent:      plan
  Model:      opencode default
  Transcript: 291 characters (limit 100000 bytes)

[Shell Doctor] Asking opencode (agent: plan)...

FAILED COMMAND
pacman -S firfox

ROOT CAUSE
pacman -S requires root privileges, and `firfox` is a misspelling of `firefox`.

STEP 1: Check the package name with `pacman -Ss firefox`
STEP 2: Install with `sudo pacman -S firefox`
```

Outside a herdr terminal, failures are silent and `doctor` reports that the shell is not inside herdr.

## Configuration

Set these before running `doctor`:

| Variable                | Default          | Description                                        |
| ----------------------- | ---------------- | -------------------------------------------------- |
| `SHELL_DOCTOR_AGENT`    | `plan`           | opencode agent                                     |
| `SHELL_DOCTOR_MODEL`    | opencode default | opencode model (e.g. `opencode/gpt-5-nano`)        |
| `SHELL_DOCTOR_LINES`    | `200`            | terminal lines to read                             |
| `SHELL_DOCTOR_MAX_BYTES`| `100000`         | transcript size cap in bytes                       |
| `SHELL_DOCTOR_TERMINAL` | `HC_TERMINAL_ID` | terminal to read instead of the current one        |
| `SHELL_DOCTOR_DISABLE`  | `0`              | `1` = do not install the prompt hook (source-time) |

Example:

```sh
export SHELL_DOCTOR_MODEL="opencode/deepseek-v4.1-flash-free"
doctor
```

## How it works

1. The prompt hook notices a non-zero exit status and prints the `[Shell Doctor] Command failed (exit code: N)` banner (only when `HC_TERMINAL_ID` is set).
2. `doctor` reads the transcript with `hc read` and uses the **last** banner as the failure to diagnose; the exit code comes from the banner itself, so no state is shared between shells.
3. The transcript is sent to opencode, which reports `FAILED COMMAND`, `ROOT CAUSE`, and numbered steps.
4. Pressing Enter on an empty prompt does not repeat the banner for the same failure, and running `doctor` never marks its own exit status.

## Troubleshooting

| Message | Fix |
| --- | --- |
| `doctor not found on PATH` | Add `bin/` to `PATH` (see Install) |
| `This shell is not running inside a herdr terminal` | Start the shell with `hc run bash` (or set `SHELL_DOCTOR_TERMINAL=<t7\|name>`) |
| `No failure banner found` | Run a command that fails inside herdr, then run `doctor` |
| `hc read failed for terminal ...` | Check that the terminal id/name is correct and still running |
| `opencode returned no output` | Check `opencode` auth/model availability; try another `SHELL_DOCTOR_MODEL` |
