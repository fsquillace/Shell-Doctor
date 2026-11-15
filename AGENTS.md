# AGENTS.md

Shell Doctor: `bin/doctor` diagnoses the last failed command in a herdr terminal via `hc read` + opencode; `scripts/integration.{bash,zsh,fish}` only print a failure banner. Diagnosis only — never add fix/apply behavior.

## Layout

- `bin/doctor` — the only executable (Bash). Everything but the banner lives here. Users add `bin/` to `PATH` and run `doctor`.
- `scripts/integration.*` — one per shell; print the banner and define a `doctor` wrapper. No other shared logic, no cross-shell state.

## Hard contracts (change together)

- Banner format: `[Shell Doctor] Command failed (exit code: N)` followed by `  Diagnose with: doctor`. `bin/doctor` greps the last banner for N; if you change the text, update the regex there and the prompt.
- Banner is printed only when `HC_TERMINAL_ID` is non-empty (inside herdr). Outside herdr failures are silent.
- Integrations define a shell function named `doctor` that shadows the PATH executable. Inside it always: set the suppression flag first, check the *external* executable (`type -P doctor` / `(( $+commands[doctor] ))` / `command -q doctor` — these ignore functions), then call `command doctor "$@"`.
- Suppression flag: the `doctor` wrapper sets it; the prompt hook consumes and clears it. Without it, `doctor`'s own non-zero exit prints a banner and poisons the transcript.

## Shell specifics

- bash: `PROMPT_COMMAND` (string or array), prepend ours so `$?` is read first. Duplicate-banner guard compares `HISTCMD` (does not advance on empty Enter, nor for history-ignored commands) plus the exit code — do not remove it; without it a blank Enter re-prints the banner and the model reports `FAILED COMMAND unknown`.
- zsh: `add-zsh-hook preexec` sets a new-command flag (preexec never fires on empty Enter); `precmd` reads `local exit_code=$?` first and must be prepended into `precmd_functions` or another hook clobbers `$?`.
- fish: `fish_postexec` (never fires on empty Enter, no dedup needed); capture `set -l exit_code $status` as the first line.

## Config

`SHELL_DOCTOR_{AGENT,MODEL,LINES,MAX_BYTES,TERMINAL,DISABLE}` only; old `AI_RUN_*` names are deliberately unsupported. `DISABLE` is read by integrations at source time, the rest by `bin/doctor` at run time.

## Verify (no test suite exists)

- Syntax: `bash -n bin/doctor scripts/integration.bash`, `zsh -n scripts/integration.zsh`, `fish -n scripts/integration.fish`.
- Behavior via ptys: pipe commands into `script -q -c '<shell> -i' /dev/null`, strip ANSI/OSC (`sed -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' -e 's/\x1b\][^\x07]*\x07//g'`) and `\r`, then grep for banners.
- Stub `hc` and `opencode` with shims on PATH (log argv to a file to inspect the prompt). Test: one banner, empty Enter, `doctor` suppression, no banner outside herdr, missing terminal, `hc read` failure, transcript without banner.
- Real-model checks need `SHELL_DOCTOR_MODEL=opencode/deepseek-v4.1-flash-free` — the opencode default model in this env has insufficient credits. Expect `FAILED COMMAND` to name the command above the last banner.

## Gotchas

- Repo path contains a space (`Shell Doctor`): always quote paths in code and docs.
- User-facing docs are `README.md`; update it whenever behavior, config, or messages change.
