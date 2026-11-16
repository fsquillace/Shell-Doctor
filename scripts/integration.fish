# ==========================================
# Shell Doctor integration for fish
# ==========================================
#
# Source this file from ~/.config/fish/config.fish:
#
#     source ~/Projects/Shell\ Doctor/scripts/integration.fish
#
# Requires the `doctor` executable from bin/ on PATH. When a command fails
# inside a herdr terminal (herdr-app or herdr TUI), the postexec hook prints:
#
#     [Shell Doctor] Command failed (exit code: N)
#       Diagnose with: doctor
#
# Outside herdr no banner is printed. Run `doctor` to diagnose the failure.
#
#   SHELL_DOCTOR_DISABLE  1 = do not install the prompt hook  (default: 0)

set -l __shell_doctor_disabled 0
if set -q SHELL_DOCTOR_DISABLE; and test "$SHELL_DOCTOR_DISABLE" = 1
    set __shell_doctor_disabled 1
end

if test $__shell_doctor_disabled = 0; and not set -q __SHELL_DOCTOR_FISH_INTEGRATION
    set -g __SHELL_DOCTOR_FISH_INTEGRATION 1

    # The last failure, kept in this shell only.
    set -g __shell_doctor_suppress 0

    # True inside a herdr terminal: herdr-app (HC_TERMINAL_ID) or herdr TUI
    # (HERDR_ENV=1). Must mirror the backend detection in bin/doctor.
    function __shell_doctor_in_herdr
        if set -q HC_TERMINAL_ID; and test -n "$HC_TERMINAL_ID"
            return 0
        end
        if set -q HERDR_ENV; and test "$HERDR_ENV" = 1
            return 0
        end
        return 1
    end

    # fish_postexec does not fire for an empty prompt, so no duplicate-banner
    # guard is needed.
    function __shell_doctor_postexec --on-event fish_postexec
        set -l exit_code $status

        # Do not mark the exit status of doctor itself.
        if test $__shell_doctor_suppress = 1
            set -g __shell_doctor_suppress 0
            return
        end

        if test $exit_code -eq 0
            return
        end

        # Advertise the failure only inside a herdr terminal, where doctor can
        # read this terminal's transcript.
        if __shell_doctor_in_herdr
            printf '\n\033[1;31m[Shell Doctor]\033[0m Command failed (exit code: %d)\n' $exit_code
            printf '  Diagnose with: doctor\n\n'
        end
    end

    # Set a flag so the next prompt does not mark doctor's own exit status.
    function doctor
        set -g __shell_doctor_suppress 1

        if not command -q doctor
            printf '[Shell Doctor] doctor not found on PATH.\n' >&2
            printf '  Add the Shell Doctor bin/ directory to PATH.\n' >&2
            return 127
        end

        command doctor $argv
    end
end
