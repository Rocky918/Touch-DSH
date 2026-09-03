# Security Policy

## Supported versions

Only the latest GitHub pre-release or stable release receives security fixes.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting feature when it is available. Do not post credentials, private prompts, complete DSH logs, or exploit details in a public issue.

If private reporting is not yet enabled, open a public issue containing only a short request for a private contact channel.

## Security boundaries

- Touch DSH controls only a same-user process that is listening on TCP port 3080 and whose command is recognized as `dsh web`.
- Process identity is checked again immediately before termination and force termination.
- The application connects to loopback DSH HTTP and WebSocket endpoints only.
- It does not read DSH provider credentials or model API keys.
- DSH itself can run model-generated commands and access resources granted by the user. Touch DSH does not make DSH a security sandbox.
- The Touch Bar edition uses undocumented system APIs. The menu-only edition does not link the private Touch Bar integration.

## Logs

When Touch DSH starts DSH, stdout and stderr are written to `~/Library/Logs/Touch DSH/dsh-web.log`. The directory and file are restricted to the current user. The log rotates at 5 MB and retains one backup. DSH output can still contain sensitive paths or content; sanitize it before sharing.
