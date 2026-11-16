# Shell Doctor

Diagnose the last failed command in your terminal with AI.

When a command fails inside a herdr terminal, a small prompt hook prints:

```
[Shell Doctor] Command failed (exit code: 1)
  Diagnose with: doctor
```

Running `doctor` reads this terminal's transcript, finds the last failure banner, and asks [opencode](https://opencode.ai) to identify the failed command, explain the root cause, and propose an ordered fix plan.

Diagnosis only: Shell Doctor never runs commands or modifies files.

## Supported terminals

Shell Doctor works with both herdr variants and detects which one you are in automatically:

| Terminal  | Backend   | Detection                    | Transcript read |
| --------- | --------- | ---------------------------- | --------------- |
| herdr-app | `hc`      | `HC_TERMINAL_ID` is set      | `hc read --lines N <terminal>` |
| herdr TUI | `herdr`   | `HERDR_ENV=1` + `HERDR_PANE_ID` | `herdr pane read <pane> --source recent-unwrapped --lines N` |

## Requirements

- `hc` (herdr-core) when using herdr-app, and/or `herdr` when using the TUI
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

3. Run your shell inside a herdr terminal:

   ```sh
   # herdr-app
   hc run bash
   ```

   ```sh
   # herdr TUI
   herdr    # then use any shell pane
   ```

## Use

Run a command that fails, then:

```sh
doctor
```

Example output (inside herdr TUI):

```
[Shell Doctor] Diagnostic context
  Exit code:  1
  Directory:  /tmp
  System:     Arch Linux, kernel Linux 6.18
  Backend:    herdr TUI
  Target:     w1:p1
  Read:       herdr pane read w1:p1 --source recent-unwrapped --lines 200
  Agent:      plan
  Model:      opencode default
  Transcript: 350 characters (limit 100000 bytes)

[Shell Doctor] Asking opencode (agent: plan)...

FAILED COMMAND
pacman -S firfox

ROOT CAUSE
pacman -S requires root privileges, and `firfox` is a misspelling of `firefox`.

STEP 1: Check the package name with `pacman -Ss firefox`
STEP 2: Install with `sudo pacman -S firefox`
```

Outside a herdr terminal, failures are silent and `doctor` reports that the shell is not inside herdr-app or herdr TUI.

## Configuration

Set these before running `doctor`:

| Variable                | Default          | Description                                        |
| ----------------------- | ---------------- | -------------------------------------------------- |
| `SHELL_DOCTOR_AGENT`    | `plan`           | opencode agent                                     |
| `SHELL_DOCTOR_MODEL`    | opencode default | opencode model (e.g. `opencode/gpt-5-nano`)        |
| `SHELL_DOCTOR_LINES`    | `200`            | terminal lines to read                             |
| `SHELL_DOCTOR_MAX_BYTES`| `100000`         | transcript size cap in bytes                       |
| `SHELL_DOCTOR_TERMINAL` | `HC_TERMINAL_ID` | herdr-app terminal to read instead of the current one |
| `SHELL_DOCTOR_PANE`     | `HERDR_PANE_ID`  | herdr TUI pane to read instead of the current one  |
| `SHELL_DOCTOR_DISABLE`  | `0`              | `1` = do not install the prompt hook (source-time) |

Detection order: `SHELL_DOCTOR_PANE`, then `SHELL_DOCTOR_TERMINAL`, then `HERDR_ENV=1` (TUI), then `HC_TERMINAL_ID` (app). Set an override explicitly if both are set or if you are reading a terminal other than the current one.

Example:

```sh
export SHELL_DOCTOR_MODEL="opencode/deepseek-v4.1-flash-free"
doctor
```

## How it works

1. The prompt hook notices a non-zero exit status and prints the `[Shell Doctor] Command failed (exit code: N)` banner (only inside a herdr terminal).
2. `doctor` detects the backend (`hc` for herdr-app, `herdr` for the TUI), reads the transcript, and uses the **last** banner as the failure to diagnose; the exit code comes from the banner itself, so no state is shared between shells.
3. The transcript is sent to opencode, which reports `FAILED COMMAND`, `ROOT CAUSE`, and numbered steps.
4. Pressing Enter on an empty prompt does not repeat the banner for the same failure, and running `doctor` never marks its own exit status.

## Troubleshooting

| Message | Fix |
| --- | --- |
| `doctor not found on PATH` | Add `bin/` to `PATH` (see Install) |
| `This shell is not running inside herdr-app or herdr TUI` | Start the shell with `hc run bash` or inside a herdr TUI pane (or set `SHELL_DOCTOR_TERMINAL` / `SHELL_DOCTOR_PANE`) |
| `hc not found (required by herdr-app)` | Install herdr-core / make sure `hc` is on `PATH` |
| `herdr not found (required by herdr TUI)` | Install herdr / make sure `herdr` is on `PATH` |
| `HERDR_PANE_ID is not set` | Run `doctor` inside a herdr pane, or set `SHELL_DOCTOR_PANE=<w1:p1>` |
| `No failure banner found` | Run a command that fails inside herdr, then run `doctor` |
| `hc read failed` / `herdr pane read failed` | Check that the terminal/pane id is correct and still running |
| `opencode returned no output` | Check `opencode` auth/model availability; try another `SHELL_DOCTOR_MODEL` |
