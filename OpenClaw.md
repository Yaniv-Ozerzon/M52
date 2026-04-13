Great — Galaxy S10 Lite (8GB RAM) + GPT is actually a very good setup 👍
I'll give you the clean, safest, and updated installation steps.

We will use:

Termux (Android Linux environment)
OpenClaw
GPT via API (recommended for phone)

This avoids heavy local models and runs fast + stable.

Step 1 — Install Termux (IMPORTANT)

Do NOT install from Play Store.

Install from F-Droid:

👉 https://f-droid.org/packages/com.termux/

After install:
Open Termux once and wait 30 seconds.

Step 2 — Update Termux

Run:

pkg update && pkg upgrade -y
Step 3 — Install Dependencies

Run:

pkg install -y git nodejs python tmux curl wget nano openssh

This installs everything needed.

Step 4 — Install OpenClaw

Run:

npm install -g openclaw

This takes 1–2 minutes.

Step 5 — Start OpenClaw Setup

Run:

openclaw onboard

You will see questions:

Choose:

Provider:

OpenAI / GPT

Then enter:

API key:

sk-xxxxxxxxxxxxxxxx
Step 6 — Where to Get GPT API Key

Go here:

👉 https://platform.openai.com/api-keys

Create new key
Copy it
Paste into Termux

Step 7 — Start OpenClaw

Run:

openclaw gateway

Then:

openclaw dashboard
Step 8 — Keep It Running (Important for Phone)

Run:

termux-wake-lock

This prevents Android from killing it.

Step 9 — Optional (Recommended)

Install tmux so OpenClaw keeps running even if you close Termux:

Start tmux:

tmux

Then run:

openclaw gateway

Now you can close Termux and it keeps running.

What You Can Now Do

After installation:

OpenClaw can:

Personal AI assistant
Automation agent
Task runner
Code assistant
Email automation
WhatsApp automation
Telegram bot
Web browsing agent
Performance Expectation (Galaxy S10 Lite)

With GPT (cloud):

Performance: ⭐⭐⭐⭐⭐
Speed: Fast
Battery: Low impact
RAM usage: ~300–600MB

This is much better than local models.

Recommended GPT Model

Start with:

gpt-4o-mini

Best balance:

Fast
Cheap
Very capable

Later you can switch to:

gpt-4o (stronger)
gpt-4.1 (reasoning)
Important Question

How do you plan to use OpenClaw?

For example:

Personal AI assistant
Coding assistant
Phone automation
Business assistant
Experimenting

Tell me — I'll help configure best setup for your use case.