# ACS Provider Setup Guide

Detailed setup instructions, model options, and cost information for each
supported LLM provider.

---

## Anthropic (Default)

**Quality**: Highest — Claude is purpose-built for structured document analysis.
**Cost**: Paid only. No free tier for API access.
**Package**: `pip install anthropic`

### Getting your API key

1. Go to [console.anthropic.com](https://console.anthropic.com)
2. Sign in or create an account
3. Navigate to **API Keys** → **Create Key**
4. Copy the key (starts with `sk-ant-`)

### .env configuration

```
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

### Available models

| Model | Speed | Quality | Cost (per 1M tokens in/out) |
|-------|-------|---------|------------------------------|
| `claude-sonnet-4-20250514` | Fast | Excellent | ~$3 / $15 |
| `claude-opus-4-20250514` | Slower | Highest | ~$15 / $75 |
| `claude-haiku-4-5-20251001` | Fastest | Good | ~$0.80 / $4 |

**ACS default**: `claude-sonnet-4-20250514` — best balance of quality and cost
for document ingestion.

### Usage

```bash
python acs_ingest.py --input plan.md
python acs_ingest.py --input plan.md --provider anthropic --model claude-haiku-4-5-20251001
```

### Typical ingestion cost

A 5,000-word planning document costs roughly **$0.02–0.05** per ingestion run
using Sonnet.

---

## OpenAI

**Quality**: Excellent — GPT-4o handles structured extraction well.
**Cost**: Paid. Limited free credits on new accounts.
**Package**: `pip install openai`

### Getting your API key

1. Go to [platform.openai.com](https://platform.openai.com)
2. Sign in or create an account
3. Navigate to **API Keys** → **Create new secret key**
4. Copy the key (starts with `sk-`)

### .env configuration

```
OPENAI_API_KEY=sk-your-key-here
```

### Available models

| Model | Speed | Quality | Cost (per 1M tokens in/out) |
|-------|-------|---------|------------------------------|
| `gpt-4o` | Fast | Excellent | ~$2.50 / $10 |
| `gpt-4o-mini` | Very fast | Good | ~$0.15 / $0.60 |
| `gpt-4-turbo` | Moderate | Excellent | ~$10 / $30 |

**ACS default**: `gpt-4o`

### Usage

```bash
python acs_ingest.py --input plan.md --provider openai
python acs_ingest.py --input plan.md --provider openai --model gpt-4o-mini
```

### Notes

- JSON mode is not explicitly set — the prompt instructs the model to return
  only JSON. GPT-4o follows this reliably. If you get parse errors with smaller
  models, try `gpt-4o` explicitly.

---

## Google Gemini

**Quality**: Good — Gemini 1.5 Pro handles long documents well.
**Cost**: Free tier available (rate-limited). Paid tier for higher volume.
**Package**: `pip install google-generativeai`

### Getting your API key

1. Go to [aistudio.google.com](https://aistudio.google.com)
2. Sign in with a Google account
3. Click **Get API key** → **Create API key**
4. Copy the key

### .env configuration

```
GEMINI_API_KEY=your-key-here
```

### Available models

| Model | Context | Quality | Free Tier |
|-------|---------|---------|-----------|
| `gemini-1.5-pro` | 1M tokens | Excellent | 2 req/min |
| `gemini-1.5-flash` | 1M tokens | Good | 15 req/min |
| `gemini-2.0-flash` | 1M tokens | Good | 15 req/min |

**ACS default**: `gemini-1.5-pro`

### Usage

```bash
python acs_ingest.py --input plan.md --provider gemini
python acs_ingest.py --input plan.md --provider gemini --model gemini-1.5-flash
```

### Notes

- Free tier rate limits (2 req/min for Pro) are fine for ACS — ingestion is
  a one-shot operation, not a high-frequency workload.
- Gemini has a 1M token context window, making it well-suited for very large
  planning documents.

---

## Ollama (Local)

**Quality**: Varies by model. Llama 3 / Mistral give reasonable results for
  structured extraction. Smaller models may produce malformed JSON.
**Cost**: Free. Runs entirely on your machine.
**Package**: `pip install ollama`

### Installation

1. Install Ollama from [ollama.com/download](https://ollama.com/download)
2. Pull your chosen model:

```bash
ollama pull llama3        # 8B — good balance, ~4.7GB
ollama pull mistral       # 7B — fast, good JSON compliance
ollama pull llama3:70b    # 70B — best quality, needs ~40GB RAM
ollama pull phi3          # 3.8B — lightweight, faster on CPU
```

3. Start the Ollama server (runs automatically after install on macOS/Windows;
   on Linux run `ollama serve`):

```bash
ollama serve   # Linux only — runs in background
```

### No .env needed

Ollama requires no API key. ACS will auto-detect and use it when no other
provider keys are present.

### Usage

```bash
python acs_ingest.py --input plan.md --provider ollama
python acs_ingest.py --input plan.md --provider ollama --model mistral
python acs_ingest.py --input plan.md --provider ollama --model llama3:70b
```

### Recommended models for ACS ingestion

| Model | RAM needed | JSON reliability | Notes |
|-------|-----------|-----------------|-------|
| `llama3` | ~8GB | Good | Best default choice |
| `mistral` | ~5GB | Very good | Excellent JSON compliance |
| `phi3` | ~3GB | Moderate | Use for low-RAM machines |
| `llama3:70b` | ~40GB | Excellent | Best quality, needs GPU |

### Troubleshooting

**`Connection refused`** — Ollama server is not running. Run `ollama serve` in
a separate terminal.

**`model not found`** — Run `ollama pull <model-name>` first.

**JSON parse errors** — Try a larger model (`llama3` instead of `phi3`), or
pass `--model mistral` which has strong JSON instruction-following.

---

## Choosing a Provider

| Situation | Recommended provider |
|-----------|---------------------|
| Best quality extraction | `anthropic` |
| Already have OpenAI credits | `openai` with `gpt-4o` |
| Minimise cost | `gemini` (free tier) or `ollama` |
| No internet / private data | `ollama` |
| CI/CD automation | `anthropic` or `openai` (reliable JSON) |
| Very large documents (100k+ tokens) | `gemini` (1M context) |

---

## Environment File Reference

Full `.env.example` with all providers:

```bash
# ACS — Provider API Keys
# Uncomment and fill in the key for your chosen provider.
# ACS auto-detects in this priority order: Anthropic → OpenAI → Gemini → Ollama

# --- Anthropic (default) ---
# ANTHROPIC_API_KEY=sk-ant-your-key-here

# --- OpenAI ---
# OPENAI_API_KEY=sk-your-key-here

# --- Google Gemini ---
# GEMINI_API_KEY=your-gemini-key-here

# --- Ollama ---
# No key needed. Install ollama and run: ollama serve
# Then use: python acs_ingest.py --provider ollama --model llama3
```
