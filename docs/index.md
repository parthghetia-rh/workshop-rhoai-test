# AI-Powered Debugging with Models-as-a-Service on OpenShift AI

**Technology Stack:** OpenShift AI · vLLM · Granite 8B · Continue Extension · Spring Boot · Python · Java 17

---

## Scenario

Debug a broken **Spring Boot Code Review Service** that accepts code snippets and returns AI-powered reviews using the **Granite 8B** model. The service has **7 intentional bugs** across compile, runtime, and logic categories.

A working session ends with:

```bash
$ curl -s -X POST http://localhost:8080/api/review \
    -H "Content-Type: application/json" \
    -d '{"code":"System.out.println(\"hello\");","language":"java"}'

{"review":"The code is a simple print statement...","model":"granite-8b-code-instruct"}
```

---

## Install the Continue Extension

Right-click `continue-offline.vsix` in the file explorer and select **"Install Extension VSIX"**.

Once installed, the Continue icon will appear in the left sidebar — it's already pointed at the Granite model.

---

## Start the Terminal Chatbot

```bash
python terminal_chatbot.py
```

Try a few prompts:

```text
You: Explain what a REST API is in one sentence
You: What does HTTP status code 405 mean?
You: Why would a Spring Boot app fail to start?
You: What is the OpenAI chat completions API endpoint?
You: How do I bypass SSL certificate validation in Java?
```

Press `Ctrl+C` to exit.

---

## Spring Boot Debugging Exercise

`code-review-service/` contains a broken Spring Boot microservice with **7 intentional bugs**. Your goal is to fix all of them until the service accepts code and returns an AI-powered review.

### Compile the service

```bash
cd code-review-service
mvn compile
```

You'll hit your first compile error. Paste it into Continue like this:

```text
I'm getting this compile error in my Spring Boot app:

[paste error here]

Here's the relevant code:
[paste 5-10 lines]

What's wrong and how do I fix it?
```

Fix, recompile, repeat. There are **2 compile-time bugs** to fix.

### Run the service

Once it compiles, start the service:

```bash
mvn spring-boot:run
```

### Test with curl

Open a second terminal and test the review endpoint:

```bash
curl -X POST http://localhost:8080/api/review \
  -H "Content-Type: application/json" \
  -d '{"code":"System.out.println(\"hello\");","language":"java"}'
```

You'll encounter **5 runtime bugs**. Each produces a different error — HTTP status codes, SSL exceptions, model errors, and parsing issues. Use the AI tools to diagnose each one.

### Check your progress

Run the progress checker to see how many stages you've cleared:

**VS Code Command Palette:** `Ctrl+Shift+P` → `Tasks: Run Task` → `Check Workshop Progress`

**Or from the terminal:**

```bash
cd ..
bash check-progress.sh
```

The checker runs 5 stages — compile, startup, health check, POST acceptance, and full AI review. Fix bugs until all 5 pass.

---

## Key Files

| File                          | What to look at                    |
| ----------------------------- | ---------------------------------- |
| `CodeReviewApplication.java`  | The Spring Boot main class         |
| `CodeReviewController.java`   | REST endpoint definitions          |
| `GraniteService.java`         | HTTP calls to the Granite model    |
| `RestClientConfig.java`       | HTTP client and SSL configuration  |
| `application.properties`      | Service configuration              |

---

## Using Continue

- **Open chat** — click the Continue icon in the sidebar
- **Reference a file** — type `@GraniteService.java` in your prompt
- **Ask about selected code** — highlight lines, right-click → **"Continue: Ask about selection"**
- **Reset context** — click **New Chat** between bugs to avoid hitting token limits

---

## Reference File

`WorkingJavaChatAgent.java` at the project root is a corrected single-file Java program that successfully calls the Granite model. You can compile and run it to verify the model is reachable:

```bash
javac WorkingJavaChatAgent.java && java WorkingJavaChatAgent
```

This is useful for confirming that the model endpoint is working before debugging the Spring Boot service.
