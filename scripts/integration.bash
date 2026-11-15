# ==========================================
# Shell Doctor integration for bash
# ==========================================
#
# Source this file from ~/.bashrc:
#
#     source ~/Projects/Shell\ Doctor/scripts/integration.bash
#
# Requires the `doctor` executable from bin/ on PATH. When a command fails
# inside a herdr terminal, the prompt hook prints:
#
#     [Shell Doctor] Command failed (exit code: N)
#       Diagnose with: doctor
#
# Outside herdr no banner is printed. Run `doctor` to diagnose the failure.
#
#   SHELL_DOCTOR_DISABLE  1 = do not install the prompt hook  (default: 0)

if [[ "${SHELL_DOCTOR_DISABLE:-0}" == "1" ]]; then
    return 0
fi

# Guard against being sourced twice.
if [[ -n "${__SHELL_DOCTOR_BASH_INTEGRATION:-}" ]]; then
    return 0
fi
__SHELL_DOCTOR_BASH_INTEGRATION=1

# The last failure, kept in this shell only.
__shell_doctor_exit_code=0
__shell_doctor_suppress=0
# Used only to detect that a new command ran, so one failure gets one banner.
__shell_doctor_histcmd=0

__shell_doctor_clear() {
    __shell_doctor_exit_code=0
}

__shell_doctor_prompt() {
    local exit_code=$?
    local hist_cmd=${HISTCMD:-0}
    local new_command=1

    # HISTCMD advances for every executed command, including commands that
    # history does not save, but not for an empty prompt.
    if [[ -o history ]] && (( hist_cmd > 0 )) &&
        (( hist_cmd == __shell_doctor_histcmd )); then
        new_command=0
    fi
    __shell_doctor_histcmd=$hist_cmd

    # Do not mark the exit status of doctor itself.
    if (( __shell_doctor_suppress )); then
        __shell_doctor_suppress=0
        __shell_doctor_clear
        return 0
    fi

    if (( exit_code == 0 )); then
        __shell_doctor_clear
        return 0
    fi

    # An empty prompt keeps the previous exit status: do not print a second
    # banner for the same failure.
    if (( ! new_command )) && (( __shell_doctor_exit_code != 0 )) &&
        (( exit_code == __shell_doctor_exit_code )); then
        return 0
    fi

    __shell_doctor_exit_code=$exit_code

    # Advertise the failure only inside a herdr terminal, where doctor can
    # read this terminal's transcript.
    if [[ -n "${HC_TERMINAL_ID:-}" ]]; then
        printf '\n\033[1;31m[Shell Doctor]\033[0m Command failed (exit code: %d)\n' \
            "$exit_code"
        printf '  Diagnose with: doctor\n\n'
    fi

    return 0
}

# Install the hook once, supporting string and array PROMPT_COMMAND. Ours
# runs first so it sees the exit status of the command that just finished.
if [[ -z "${__SHELL_DOCTOR_HOOKS:-}" ]]; then
    if [[ "$(declare -p PROMPT_COMMAND 2>/dev/null)" == "declare -a"* ]]; then
        PROMPT_COMMAND=(__shell_doctor_prompt "${PROMPT_COMMAND[@]}")
    elif [[ ";${PROMPT_COMMAND:-};" != *";__shell_doctor_prompt;"* ]]; then
        PROMPT_COMMAND="__shell_doctor_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
    fi

    __SHELL_DOCTOR_HOOKS=1
fi

# Set a flag so the next prompt does not mark doctor's own exit status.
doctor() {
    __shell_doctor_suppress=1

    if ! type -P doctor >/dev/null 2>&1; then
        printf '[Shell Doctor] doctor not found on PATH.\n' >&2
        printf '  Add the Shell Doctor bin/ directory to PATH.\n' >&2
        return 127
    fi

    command doctor "$@"
}
