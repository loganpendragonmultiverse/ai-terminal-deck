# Contributing

Open an issue before changing command discovery, quoting, pane sizing, or the supported CLI set. Pull requests must explain the Windows behavior being changed, include a regression test using stub commands, preserve the one-file release artifact, and pass the Windows test and packaging workflows.

Do not add bundled credentials, unattended installation, telemetry, prompt relaying, destructive cleanup, or automatic permission bypasses. New dependencies need a concrete benefit that cannot be achieved with Windows Terminal and built-in Windows tools.
