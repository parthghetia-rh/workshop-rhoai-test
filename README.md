# AI-Powered Debugging with Models-as-a-Service on OpenShift AI

**Technology Stack:** OpenShift AI · vLLM · Granite 8B · Continue Extension · Spring Boot · Python · Java 17

---

## Scenario

A broken **Spring Boot Code Review Service** needs your help. The microservice is supposed to accept code snippets via a REST API and return AI-powered reviews using the **Granite 8B** model running in-cluster — but it has **7 intentional bugs** preventing it from working.

Your job: use the AI tools available (Continue extension and terminal chatbot) to diagnose and fix each bug until the service returns a valid code review.

A working request looks like this:

```bash
curl -s -X POST http://localhost:8080/api/review \
  -H "Content-Type: application/json" \
  -d '{"code":"System.out.println(\"hello\");","language":"java"}'
```

```json
{"review":"The code looks correct...","model":"granite-8b-code-instruct"}
```

---

## What's Included

| File | Purpose |
|------|---------|
| `code-review-service/` | Broken Spring Boot microservice (7 bugs) |
| `WorkingJavaChatAgent.java` | Working reference — compile and run to verify the model is reachable |
| `terminal_chatbot.py` | Python chatbot for AI-assisted debugging |
| `check-progress.sh` | Progress checker — run to see how many bugs you've fixed |

---

## Install the Continue Extension

Right-click `continue-offline.vsix` in the file explorer and select **"Install Extension VSIX"**.

Once installed, the Continue icon will appear in the left sidebar — it's already pointed at the Granite model.

---

## Start the Terminal Chatbot

```bash
python terminal_chatbot.py
```

Try a few prompts to confirm the model is working:

```
You: Explain what a REST API is in one sentence
You: What does HTTP status code 405 mean?
You: Why would a Spring Boot app fail to start?
```

Press `Ctrl+C` to exit.

---

## Spring Boot Debugging Exercise

### Step 1: Try to compile

```bash
cd code-review-service
mvn compile
```

You'll see a compile error. Paste it into Continue or the terminal chatbot to diagnose the issue.

### Step 2: Fix, recompile, repeat

Fix the bug, recompile. There are **2 compile-time bugs** before the project will build.

### Step 3: Run the service

```bash
mvn spring-boot:run
```

### Step 4: Test with curl

```bash
curl -X POST http://localhost:8080/api/review \
  -H "Content-Type: application/json" \
  -d '{"code":"System.out.println(\"hello\");","language":"java"}'
```

You'll encounter **5 more runtime bugs**. Use the AI tools to diagnose each one.

### Step 5: Check your progress

Run the progress checker from the VS Code Command Palette:

**`Ctrl+Shift+P` → `Tasks: Run Task` → `Check Workshop Progress`**

Or from the terminal:

```bash
bash check-progress.sh
```

---

## Using Continue

- **Open chat** — click the Continue icon in the sidebar
- **Reference a file** — type `@CodeReviewController.java` in your prompt
- **Ask about selected code** — highlight lines, right-click → **"Continue: Ask about selection"**
- **Paste errors** — copy a stack trace and ask "What's wrong and how do I fix it?"
- **Reset context** — click **New Chat** between bugs to avoid hitting token limits

---

## Architecture

```
┌──────────────────────┐       ┌──────────────────────────┐
│  Code Review Service │ ────→ │  Granite 8B Code Instruct│
│  (Spring Boot)       │ HTTP  │  (vLLM on OpenShift AI)  │
│  POST /api/review    │       │  /v1/chat/completions    │
└──────────────────────┘       └──────────────────────────┘
```
