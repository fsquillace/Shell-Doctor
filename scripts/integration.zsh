# ==========================================
# Shell Doctor integration for zsh
# ==========================================
#
# Source this file from ~/.zshrc:
#
#     source ~/Projects/Shell\ Doctor/scripts/integration.zsh
#
# Requires the `doctor` executable from bin/ on PATH. When a command fails
# inside a herdr terminal (herdr-app or herdr TUI), the prompt hook prints:
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
if [[ -n "${__SHELL_DOCTOR_ZSH_INTEGRATION:-}" ]]; then
    return 0
fi
typeset -g __SHELL_DOCTOR_ZSH_INTEGRATION=1

# The last failure, kept in this shell only.
typeset -g __shell_doctor_exit_code=0
typeset -g __shell_doctor_suppress=0
# Used only to detect that a new command ran, so one failure gets one banner.
typeset -g __shell_doctor_new_command=0

__shell_doctor_clear() {
    __shell_doctor_exit_code=0
}

# True inside a herdr terminal: herdr-app (HC_TERMINAL_ID) or herdr TUI
# (HERDR_ENV=1). Must mirror the backend detection in bin/doctor.
__shell_doctor_in_herdr() {
    [[ -n "${HC_TERMINAL_ID:-}" || "${HERDR_ENV:-}" == "1" ]]
}

# preexec runs after a command line is read and before it executes. It does
# not run for an empty line, so it is a reliable "a new command ran" signal.
__shell_doctor_preexec() {
    __shell_doctor_new_command=1
}

__shell_doctor_precmd() {
    local exit_code=$?

    # Do not mark the exit status of doctor itself.
    if (( __shell_doctor_suppress )); then
        __shell_doctor_suppress=0
        __shell_doctor_new_command=0
        __shell_doctor_clear
        return 0
    fi

    # An empty prompt keeps the previous exit status: do not print a second
    # banner for the same failure.
    if (( ! __shell_doctor_new_command )); then
        return 0
    fi
    __shell_doctor_new_command=0

    if (( exit_code == 0 )); then
        __shell_doctor_clear
        return 0
    fi

    __shell_doctor_exit_code=$exit_code

    # Advertise the failure only inside a herdr terminal, where doctor can
    # read this terminal's transcript.
    if __shell_doctor_in_herdr; then
        printf '\n\033[1;31m[Shell Doctor]\033[0m Command failed (exit code: %d)\n' \
            "$exit_code"
        printf '  Diagnose with: doctor\n\n'
    fi

    return 0
}

# Set a flag so the next prompt does not mark doctor's own exit status.
doctor() {
    __shell_doctor_suppress=1

    if (( ! $+commands[doctor] )); then
        print -u2 '[Shell Doctor] doctor not found on PATH.'
        print -u2 '  Add the Shell Doctor bin/ directory to PATH.'
        return 127
    fi

    command doctor "$@"
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec __shell_doctor_preexec
add-zsh-hook precmd __shell_doctor_precmd

# Run this hook first, while $? still holds the status of the command that
# just finished (another precmd hook would overwrite it).
precmd_functions=(__shell_doctor_precmd ${precmd_functions:#__shell_doctor_precmd})
