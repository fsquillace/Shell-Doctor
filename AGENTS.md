# AGENTS.md

Shell Doctor: `bin/doctor` diagnoses the last failed command in a herdr terminal via opencode; `scripts/integration.{bash,zsh,fish}` only print a failure banner. Works with both herdr variants: herdr-app (`hc read`) and herdr TUI (`herdr pane read`). Diagnosis only — never add fix/apply behavior.

## Layout

- `bin/doctor` — the only executable (Bash). Everything but the banner lives here. Users add `bin/` to `PATH` and run `doctor`.
- `scripts/integration.*` — one per shell; print the banner and define a `doctor` wrapper. No other shared logic, no cross-shell state.

## Hard contracts (change together)

- Banner format: `[Shell Doctor] Command failed (exit code: N)` followed by `  Diagnose with: doctor`. `bin/doctor` greps the last banner for N; if you change the text, update the regex there and the prompt.
- Banner is printed only inside a herdr terminal: `HC_TERMINAL_ID` non-empty (herdr-app) or `HERDR_ENV=1` (herdr TUI). Each integration has an `__shell_doctor_in_herdr` predicate that must mirror backend detection in `bin/doctor`. Outside herdr failures are silent.
- Backend detection in `bin/doctor`, in order: `SHELL_DOCTOR_PANE` → TUI, `SHELL_DOCTOR_TERMINAL` → app, `HERDR_ENV=1` → TUI (target `$HERDR_PANE_ID`), `HC_TERMINAL_ID` → app, else error. Never guess the backend from CLI availability; only check the selected backend's CLI. Read commands: app `hc read --lines N <t>`; TUI `herdr pane read <pane> --source recent-unwrapped --lines N` (plain text, ANSI stripped).
- Integrations define a shell function named `doctor` that shadows the PATH executable. Inside it always: set the suppression flag first, check the *external* executable (`type -P doctor` / `(( $+commands[doctor] ))` / `command -q doctor` — these ignore functions), then call `command doctor "$@"`.
- Suppression flag: the `doctor` wrapper sets it; the prompt hook consumes and clears it. Without it, `doctor`'s own non-zero exit prints a banner and poisons the transcript.

## Shell specifics

- bash: `PROMPT_COMMAND` (string or array), prepend ours so `$?` is read first. Duplicate-banner guard compares `HISTCMD` (does not advance on empty Enter, nor for history-ignored commands) plus the exit code — do not remove it; without it a blank Enter re-prints the banner and the model reports `FAILED COMMAND unknown`.
- zsh: `add-zsh-hook preexec` sets a new-command flag (preexec never fires on empty Enter); `precmd` reads `local exit_code=$?` first and must be prepended into `precmd_functions` or another hook clobbers `$?`.
- fish: `fish_postexec` (never fires on empty Enter, no dedup needed); capture `set -l exit_code $status` as the first line.

## Config

`SHELL_DOCTOR_{AGENT,MODEL,LINES,MAX_BYTES,TERMINAL,PANE,DISABLE}` only; old `AI_RUN_*` names are deliberately unsupported. `DISABLE` is read by integrations at source time, the rest by `bin/doctor` at run time.

## Verify (no test suite exists)

- Syntax: `bash -n bin/doctor scripts/integration.bash`, `zsh -n scripts/integration.zsh`, `fish -n scripts/integration.fish`.
- Behavior via ptys: pipe commands into `script -q -c '<shell> -i' /dev/null`, strip ANSI/OSC (`sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\x1b\][^\x07]*\x07//g'`) and `\r`, then grep for banners.
- Stub `hc`, `herdr`, and `opencode` with shims first on PATH (log argv to a file to inspect the prompt; shims need `cat` for heredocs). Test: one banner, empty Enter, `doctor` suppression, no banner outside herdr, backend dispatch (app/TUI/overrides/both-set), missing CLI, read failure, empty transcript, transcript without banner.
- When stubbing with a restricted PATH, remember the pty harness needs `script`, `env`, `bash`, `grep`, `tail`, `uname`, `sed`, `tr`, `timeout` and the shell itself available — otherwise tests fail for the wrong reason.
- Real herdr TUI end-to-end: start an isolated named session (`herdr --session <name> server` in background, `workspace create --cwd /tmp`, use `pane run` + `pane wait-output` on the returned pane), then `herdr session stop <name>` and `herdr session delete <name>`. TUI docs are authoritative via `herdr --skill` and `herdr <group> --help`.
- Real-model checks need `SHELL_DOCTOR_MODEL=opencode/deepseek-v4.1-flash-free` — the opencode default model in this env has insufficient credits. Expect `FAILED COMMAND` to name the command above the last banner.

## Gotchas

- Repo path contains a space (`Shell Doctor`): always quote paths in code and docs.
- User-facing docs are `README.md`; update it whenever behavior, config, or messages change.
