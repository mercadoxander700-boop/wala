# Deploying the Telegram Bot on Choreo (WSO2 Developer Platform)

This guide walks you through deploying the bot on [Choreo](https://console.choreo.dev/) for **24/7 uptime** with automatic health checks and self-healing restarts.

---

## Prerequisites

1. A [Choreo account](https://console.choreo.dev/) (free tier available)
2. Your bot code pushed to a **GitHub repository** (public or private)
3. Your environment variables ready:
   - `BOT_TOKEN` — Your Telegram Bot API token
   - `OWNER_ID` — Your Telegram user ID (numeric)

---

## Option A: Deploy with Dockerfile (Recommended)

This is the **best approach** for a long-running worker bot because it gives you full control over the runtime environment, health checks, and dependency installation.

### Step 1: Push Your Code to GitHub

Make sure your repository includes these files at the root:

```
├── .choreo/
│   └── component.yaml      # Choreo endpoint configuration
├── Dockerfile               # Container build instructions
├── main.py                  # Bot entry point
├── requirements.txt         # Python dependencies
├── Procfile                 # Process definition (optional for Choreo)
└── runtime.txt              # Python version (optional for Choreo)
```

### Step 2: Create a Project in Choreo

1. Go to [https://console.choreo.dev/](https://console.choreo.dev/)
2. Click **+ Create Project**
3. Enter a project name (e.g., `telegram-bot`)
4. Click **Create**

### Step 3: Create a Service Component

1. Inside your project, click **+ Create** under **Component Listing**
2. Select **Service** as the component type (this gives you 24/7 uptime with health checks)
3. Under **Connect a Repository**:
   - If you authorized the Choreo GitHub App, select your repository from the list
   - If using a public repo, select **Third-Party GitHub Repository** and paste the URL
4. Select the correct **Branch** (e.g., `main` or `feature/delete-renew-proxy`)

### Step 4: Configure the Build

1. **Build Preset**: Select **Dockerfile**
2. **Dockerfile Path**: `/Dockerfile`
3. **Component Directory**: `/` (leave as default)
4. **Port**: `8080` (the healthcheck server port)
5. Click **Next** or **Create**

### Step 5: Configure Environment Variables

1. After the component is created, go to the **Deploy** page
2. Click **Manage Configs and Secrets** on the environment card
3. Under **Environment Variables**, click **+ Add a Configuration**
4. Add the following:
   - `BOT_TOKEN` = `your_telegram_bot_token` (mark as **Secret** ✅)
   - `OWNER_ID` = `your_telegram_user_id`
   - `CHOREO_DEPLOYMENT` = `true` (tells the bot it's on Choreo)
5. Click **Save and Deploy**

### Step 6: Set Up Health Checks

1. In the left navigation, click **DevOps** → **Health Checks**
2. Click **+ Create**
3. **Liveness Probe**:
   - Type: **HTTP GET**
   - Path: `/health`
   - Port: `8080`
   - Initial Delay: `30` seconds
   - Period: `30` seconds
   - Timeout: `5` seconds
   - Failure Threshold: `3`
4. Click **Save**
5. **Readiness Probe** (optional):
   - Same settings as liveness probe
6. Click **Save**

### Step 7: Deploy and Verify

1. Click **Deploy Manually** on the Deploy page
2. Wait for the build to complete (watch the build logs)
3. Once deployed, check the **Runtime** page under **DevOps** to verify:
   - The pod is running
   - Health checks are passing (green)
4. Your bot should now be online and responding to Telegram messages!

---

## Option B: Deploy with Python Build Preset (Buildpacks)

This approach uses Google Buildpacks — no Dockerfile needed. However, it has some limitations for worker-style bots.

### Step 1–3: Same as Option A

### Step 4: Configure the Build

1. **Build Preset**: Select **Python**
2. **Run Command**: `python main.py`
3. **Port**: `8080`
4. Click **Create**

### Step 5: Configure Environment Variables

Same as Option A, Step 5. Additionally:
- Add `PORT` = `8080` (Choreo should set this automatically, but add it as a fallback)

### Step 6: Set Up Health Checks

Same as Option A, Step 6.

### Step 7: Deploy

Same as Option A, Step 7.

> **Note**: The buildpack approach may have issues with Python packages like `pycryptodome` that require compilation. If the build fails, use Option A (Dockerfile) instead.

---

## 24/7 Uptime Configuration

Choreo runs your Service component as a Kubernetes Deployment, which means:

### Automatic Restart on Crash
- If the bot process crashes, Kubernetes automatically restarts the pod
- The bot's internal crash guard (5 retries with exponential backoff) handles transient errors
- If all internal retries are exhausted, the process exits cleanly and Kubernetes restarts the pod

### Liveness Probes
- The `/health` endpoint returns `200` when the bot is alive and responsive
- Returns `503` if the bot is shutting down or has been inactive for 15+ minutes
- Kubernetes will restart the pod if the liveness probe fails 3 consecutive times

### Readiness Probes
- The `/health` endpoint also serves as the readiness check
- If it returns `503`, the pod stops receiving network traffic but continues running

### Scaling (Free Tier)
- **Free tier**: 1 replica (single instance)
- **Paid plans**: You can configure autoscaling with min/max replicas
- For a Telegram bot, 1 replica is typically sufficient

---

## Monitoring and Troubleshooting

### View Logs
1. Go to **DevOps** → **Runtime**
2. Click **Logs** to see real-time and historical logs
3. Look for these key log lines:
   - `[HEALTH] ✅ Healthcheck server listening on :8080/health` — Server started
   - `[MAIN] Bot started successfully` — Bot is running
   - `[HEALTH] ❌ Healthcheck FAILED` — Bot is unhealthy

### Check Health Status
- Visit the component URL + `/health` in your browser
- You should see: `{"status": "healthy", "active_checkers": 0, "liveness_age_s": X, "proxies": Y}`

### Common Issues

| Issue | Solution |
|-------|----------|
| Build fails with dependency errors | Use the Dockerfile approach (Option A) instead of buildpacks |
| Health check fails immediately | Increase the initial delay to 60 seconds |
| Bot not responding to messages | Check that `BOT_TOKEN` is set correctly as a Secret |
| Pod keeps restarting | Check logs for errors; verify all env vars are set |
| `PORT` not set | Add `PORT=8080` as an environment variable |

---

## Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `BOT_TOKEN` | ✅ | Telegram Bot API token |
| `OWNER_ID` | ✅ | Telegram user ID of the bot owner |
| `PORT` | Auto | Healthcheck port (Choreo sets this automatically) |
| `CHOREO_DEPLOYMENT` | Recommended | Set to `true` to enable Choreo-specific behavior |
| `VIP_THREADS` | Optional | Max concurrent VIP checker threads (default: 3) |
| `FREE_THREADS` | Optional | Max concurrent Free checker threads (default: 2) |

---

## Architecture: How the Bot Stays Online on Choreo

```
┌─────────────────────────────────────────┐
│            Choreo (Kubernetes)           │
│                                         │
│  ┌───────────────────────────────────┐  │
│  │           Bot Pod                  │  │
│  │                                   │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │   main.py (entry point)     │  │  │
│  │  │                             │  │  │
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │  Telegram Polling     │  │  │  │
│  │  │  │  (long-poll 30s)      │  │  │  │
│  │  │  └───────────────────────┘  │  │  │
│  │  │                             │  │  │
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │  Healthcheck Server   │  │  │  │
│  │  │  │  (:8080/health)       │  │  │  │
│  │  │  └───────────────────────┘  │  │  │
│  │  │                             │  │  │
│  │  │  ┌───────────────────────┐  │  │  │
│  │  │  │  Crash Guard          │  │  │  │
│  │  │  │  (5 retries + backoff)│  │  │  │
│  │  │  └───────────────────────┘  │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
│                                         │
│  ┌──────────────────┐                   │
│  │  K8s Liveness    │──→ GET /health    │
│  │  Probe (every 30s)│──→ 200 = alive   │
│  │                  │──→ 503 = restart  │
│  └──────────────────┘                   │
│                                         │
│  ┌──────────────────┐                   │
│  │  K8s Restart     │──→ Pod crashed?   │
│  │  Policy          │──→ Auto-restart!  │
│  └──────────────────┘                   │
└─────────────────────────────────────────┘
```

---

## Updating the Bot

1. Push your code changes to the connected GitHub branch
2. If **Auto Deploy on Commit** is enabled, Choreo will automatically rebuild and redeploy
3. If not, go to the **Deploy** page and click **Deploy Manually**

---

## Migrating from Railway

The bot already supports both Railway and Choreo. Key differences:

| Feature | Railway | Choreo |
|---------|---------|--------|
| Process type | `worker` (Procfile) | Service component |
| Health check | `railway.toml` | DevOps → Health Checks UI |
| PORT env var | Set automatically | Set automatically |
| Crash recovery | Railway API redeploy | K8s pod restart |
| Platform detection | `RAILWAY_SERVICE_ID` | `CHOREO_DEPLOYMENT` |
| Scaling | Railway add-ons | Choreo autoscaling (paid) |

The bot's `_is_cloud()` function detects both platforms and adjusts behavior accordingly.
