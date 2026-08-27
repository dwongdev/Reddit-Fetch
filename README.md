# Reddit Saved Posts Fetcher

Export your saved Reddit posts and comments to JSON or HTML.

The app uses Reddit OAuth, stores a refresh token in `tokens.json`, and reuses that token for later runs. It does not scrape Reddit pages.

## Quick Path

- New Reddit API user: read [What You Need](#what-you-need), then [Install](#install) and [Authenticate](#authenticate).
- Existing user with `tokens.json`: copy it into this install, then run the fetcher.
- Headless VPS/server: use [Headless Server Over SSH](#headless-server-over-ssh).
- Docker: use [Docker](#docker) to create `data/tokens.json`, then start the normal container.

## Contents

- [What You Need](#what-you-need)
- [Install](#install)
- [Authenticate](#authenticate)
- [Run](#run)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Data Handling](#data-handling)

## What You Need

- Python 3.6+
- Reddit API access and OAuth credentials
- A Reddit app with redirect URI set to `http://localhost:8080`

Reddit now gates API access behind its Responsible Builder Policy. If you cannot create an app at Reddit's app settings page, request API access/approval first:

- Responsible Builder Policy: https://support.reddithelp.com/hc/en-us/articles/42728983564564-Responsible-Builder-Policy
- Data API Wiki: https://support.reddithelp.com/hc/en-us/articles/16160319875092-Reddit-Data-API-Wiki
- App registration: https://developers.reddit.com/app-registration

For personal archiving, describe the use case plainly: non-commercial, read-only export of your own saved items, local storage only, no scraping, no resale/sharing, no AI training, and low-volume usage.

Sample approval request:

```text
I am requesting Reddit Data API access for a non-commercial personal archiving tool.

The app lets me authenticate my own Reddit account and export my own saved posts and comments for personal backup/reference. It uses Reddit OAuth and the Data API. It does not scrape Reddit pages, access other users' private data, resell/share Reddit data, train AI/ML models, or perform automated posting, voting, messaging, or moderation actions.

Requested access:
- OAuth access for my own account
- Read-only access to my saved items
- Low-volume usage within Reddit's published rate limits
- A unique User-Agent identifying the app/version/account

Data handling:
- Exported data is stored locally by me
- No public database or hosted data service
- I will refresh/remove stored content as required when content is deleted from Reddit
```

Current Reddit access flow:

1. Request or confirm Reddit Data API access under Reddit's Responsible Builder Policy.
2. Register or create the Reddit app/developer profile Reddit asks for.
3. Create an OAuth app if Reddit makes that option available for your approved account.
4. Set the app redirect URI to `http://localhost:8080`.
5. Copy the app's client ID and client secret into `.env`.

This project uses Reddit's Data API OAuth flow. Devvit apps on `developers.reddit.com` use a different hosted app model and do not map directly to this local archiving tool.

## Install

```bash
git clone https://github.com/your-username/Reddit-Fetch.git
cd Reddit-Fetch
python3 -m venv venv
source venv/bin/activate
pip install -e .
```

On Windows PowerShell, activate the virtual environment with:

```powershell
.\venv\Scripts\Activate.ps1
```

Create `.env`:

```ini
CLIENT_ID=your_client_id_here
CLIENT_SECRET=your_client_secret_here
REDIRECT_URI=http://localhost:8080
USER_AGENT=linux:reddit-fetcher:v1.0.0 (by /u/your_reddit_username)
REDDIT_USERNAME=your_reddit_username
```

`CLIENT_ID` is the short value under the app name. It is not the client secret. Keep the redirect URI exactly the same in Reddit and `.env`.

## Authenticate

Run this once:

```bash
python -m reddit_fetch.generate_tokens
```

The command prints a Reddit authorization URL, starts a temporary callback server on `localhost:8080`, and saves `tokens.json` after Reddit redirects back.

### Reuse an Existing Token

If you already have a working `tokens.json` from another install using the same Reddit app credentials, copy it instead of re-running OAuth:

```bash
cp /path/to/working/tokens.json ./tokens.json
```

For Docker:

```bash
mkdir -p data
cp /path/to/working/tokens.json ./data/tokens.json
```

This is useful when Reddit still allows refresh for an existing token, but blocks new app creation or new OAuth authorization for the same use case.

### Headless Server Over SSH

Use SSH port forwarding so your local browser can reach the callback server running on the remote machine:

```bash
ssh -L 8080:localhost:8080 user@your-server
cd /path/to/Reddit-Fetch
source venv/bin/activate
python -m reddit_fetch.generate_tokens
```

Open the printed URL in your local browser. When Reddit redirects to `http://localhost:8080`, the SSH tunnel forwards that request to the remote script and creates `tokens.json` on the server.

If local port `8080` is busy, use another port on both sides:

```bash
ssh -L 18080:localhost:18080 user@your-server
```

Then set the Reddit app redirect URI and `.env` to:

```ini
REDIRECT_URI=http://localhost:18080
```

### Docker

Generate `tokens.json` with a one-shot auth container, then start the normal container.

```bash
mkdir -p data
docker run --rm -it \
  --env-file .env \
  -e DOCKER=1 \
  -p 8080:8080 \
  -v "$(pwd)/data:/data" \
  pandeyak/reddit-fetcher:latest auth

docker run --rm \
  --env-file .env \
  -e DOCKER=1 \
  -e FETCH_INTERVAL=once \
  -e OUTPUT_FORMAT=json \
  -e FORCE_FETCH=false \
  -v "$(pwd)/data:/data" \
  pandeyak/reddit-fetcher:latest
```

During the `auth` run, open the printed Reddit URL in your browser. The redirect to `http://localhost:8080` reaches the container through `-p 8080:8080`, and the refresh token is saved as `data/tokens.json`.

`docker-compose.yml`:

```yaml
version: "3.8"
services:
  reddit-fetcher:
    image: pandeyak/reddit-fetcher:latest
    container_name: reddit-fetcher
    env_file: .env
    environment:
      DOCKER: "1"
      FETCH_INTERVAL: "86400"
      OUTPUT_FORMAT: json
      FORCE_FETCH: "false"
    volumes:
      - ./data:/data
    restart: unless-stopped
```

To build the image locally instead of using Docker Hub:

```bash
docker build -t reddit-fetcher .
```

Then replace `pandeyak/reddit-fetcher:latest` with `reddit-fetcher` in the commands above. The repository also includes `sample-docker-compose.yml` for a build-from-source compose setup.

## Run

```bash
reddit-fetcher
```

Non-interactive:

```bash
OUTPUT_FORMAT=json FORCE_FETCH=false reddit-fetcher
```

Output files:

- `saved_posts.json`
- `saved_posts.html`
- `last_fetch.json`

In Docker, these files live under the mounted `data/` directory.

## Configuration

| Variable | Description | Default | Required |
| --- | --- | --- | --- |
| `CLIENT_ID` | Reddit app client ID | - | yes |
| `CLIENT_SECRET` | Reddit app client secret | - | yes |
| `REDIRECT_URI` | OAuth callback URL | `http://localhost:8080` | yes |
| `USER_AGENT` | Unique Reddit API User-Agent | - | yes |
| `REDDIT_USERNAME` | Reddit username to fetch saved items for | - | yes |
| `OUTPUT_FORMAT` | `json` or `html` | `json` | no |
| `FORCE_FETCH` | Fetch all saved items again | `false` | no |
| `FETCH_INTERVAL` | Docker loop interval in seconds | `86400` | no |

## Troubleshooting

Run the credential checker first:

```bash
python validate_credentials.py
```

Common failures:

- `401 Unauthorized`: wrong client ID/secret, whitespace in `.env`, revoked token, or redirect URI mismatch.
- `403 Forbidden`: Reddit may require API approval, app registration, or different scopes.
- Browser says `invalid client_id`: confirm the client ID belongs to the same app as the secret and that the app is still available to the logged-in Reddit account. If an old `tokens.json` still refreshes but new OAuth fails, reuse the existing token and request/confirm Reddit API approval.
- Reddit app creation returns `500` or only shows the Responsible Builder Policy page: this appears to be Reddit-side behavior reported by other developers. Try again later, verify the account is eligible/approved, or use a working existing `tokens.json`.
- No browser opens: copy the printed authorization URL into a browser yourself.
- SSH callback does not complete: confirm the SSH tunnel is open and the browser redirects to the same `localhost` port as `REDIRECT_URI`.
- Docker says `tokens.json` is missing: run the Docker `auth` command above and confirm it creates `data/tokens.json`.

If authentication gets stuck, delete `tokens.json` and run `python -m reddit_fetch.generate_tokens` again.

## Using as a Library

```python
from reddit_fetch.api import fetch_saved_posts

result = fetch_saved_posts(format="json", force_fetch=False)
for post in result["content"]:
    print(post["title"])
```

## Data Handling

Reddit's Data API guidance requires OAuth, a truthful User-Agent, respecting rate limits, and removing Reddit content you possess when it has been deleted from Reddit. For personal archiving, keep exports local and refresh/delete old stored content as needed.

## License

MIT License. See `LICENSE`.
