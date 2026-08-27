# Changelog

## Unreleased

### Changed

- Simplified README setup flow for Reddit's current API approval process.
- Added guidance for personal archiving approval requests.
- Added Docker one-shot auth mode with `docker run ... reddit-fetcher auth`.
- Added SSH port-forwarding instructions for headless OAuth setup.
- Added instructions for reusing an existing `tokens.json` when Reddit blocks new OAuth/app creation.
- Updated Docker troubleshooting to use the new auth flow.
- Updated the Docker base image to Python 3.11 on Alpine 3.24.
- Tightened `.dockerignore` to keep generated reports and local agent/editor files out of the image build context.

### Fixed

- Token generation now prints the Reddit authorization URL instead of relying on browser auto-open.
- Token generation respects the port from `REDIRECT_URI`.
- Docker auth writes `tokens.json` directly to `/data/tokens.json`.
- Docker auth binds the callback server so `-p 8080:8080` works.
- Suppressed callback request logging so OAuth codes are not printed in logs.
- OAuth authorize URLs are now URL-encoded correctly.
- Credential validation no longer prints any portion of app-only access tokens.

### Verification

- Simulated OAuth callback flow passed.
- Simulated Docker auth token-write flow passed.
- Python compile checks passed.
- Docker entrypoint shell syntax check passed.
