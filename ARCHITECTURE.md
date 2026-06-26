# Code Review Service — Architecture & Bug Map

## How the Service Works (When Fixed)

```
                          OPENSHIFT CLUSTER
 ┌──────────────────────────────────────────────────────────────────────┐
 │                                                                      │
 │   Developer's Dev Spaces Workspace         workshop-maas namespace   │
 │  ┌─────────────────────────────┐          ┌────────────────────────┐ │
 │  │                             │   HTTPS  │                        │ │
 │  │   Code Review Service       │────────→ │  Granite 8B Code       │ │
 │  │   (Spring Boot on :8080)    │          │  Instruct (vLLM)       │ │
 │  │                             │ ◄──────  │                        │ │
 │  │                             │   JSON   │  /v1/chat/completions  │ │
 │  └─────────────────────────────┘          └────────────────────────┘ │
 │        ▲                                                             │
 │        │ curl / browser                                              │
 │        │                                                             │
 │  ┌─────┴─────┐                                                      │
 │  │ Developer │                                                      │
 │  └───────────┘                                                      │
 │                                                                      │
 └──────────────────────────────────────────────────────────────────────┘
```

## Request Flow Through the Code

This is the path a request takes from `curl` to AI response. Each numbered box
is a Java file. Bugs are marked with their number.

```
 curl -X POST http://localhost:8080/api/review
      -H "Content-Type: application/json"
      -d '{"code":"...","language":"java"}'
                    │
                    ▼
 ┌─────────────────────────────────────────────────────────┐
 │  1. CodeReviewApplication.java                          │
 │     Spring Boot entry point                             │
 │                                                         │
 │     ⚠ BUG #1 (line 5)                                  │
 │     @SpringBootApplication annotation used              │
 │     but import is missing — won't compile               │
 └──────────────────────┬──────────────────────────────────┘
                        │ Spring starts, scans for controllers
                        ▼
 ┌─────────────────────────────────────────────────────────┐
 │  2. CodeReviewController.java                           │
 │     REST API layer — receives HTTP requests             │
 │                                                         │
 │     ⚠ BUG #2 (line 13)                                 │
 │     The field `graniteService` is declared final         │
 │     but there's no constructor to set it                │
 │                                                         │
 │     ⚠ BUG #3 (line 20)                                 │
 │     /api/review uses @GetMapping                        │
 │     but the client sends POST — returns 405             │
 │                                                         │
 │     GET /api/health  ← works fine (no bugs)             │
 │     GET /api/review  ← should be POST                   │
 └──────────────────────┬──────────────────────────────────┘
                        │ calls graniteService.reviewCode()
                        ▼
 ┌─────────────────────────────────────────────────────────┐
 │  3. GraniteService.java                                 │
 │     Builds the JSON payload, calls Granite, parses      │
 │                                                         │
 │     Uses HttpClient bean from RestClientConfig          │
 │     Uses model name from application.properties         │
 │                                                         │
 │     ⚠ BUG #6 (line 54)                                 │
 │     Sends request to /v1/completions                    │
 │     but the payload uses "messages" format              │
 │     which requires /v1/chat/completions                 │
 │                                                         │
 │     ⚠ BUG #7 (line 78)                                 │
 │     extractContent() looks for "text" field             │
 │     but chat/completions returns "message.content"      │
 └──────────┬───────────────────────────┬──────────────────┘
            │ reads config              │ uses HttpClient
            ▼                           ▼
 ┌────────────────────────┐  ┌─────────────────────────────┐
 │  4. application.       │  │  5. RestClientConfig.java   │
 │     properties         │  │     Creates HttpClient bean │
 │                        │  │                             │
 │  ⚠ BUG #5 (line 5)    │  │  ⚠ BUG #4 (line 29-30)    │
 │  granite.model.name=   │  │  SSLContext is created with │
 │  granite-8b-code-      │  │  trust-all certs, but NOT   │
 │  instuct               │  │  passed to HttpClient       │
 │       ^^^              │  │  builder — .sslContext()    │
 │  typo! missing 'r'     │  │  call is missing            │
 │  (should be instruct)  │  │                             │
 └────────────────────────┘  └──────────────┬──────────────┘
                                            │
                                            ▼ HTTPS connection
                              ┌──────────────────────────────┐
                              │  Granite 8B (vLLM)           │
                              │  granite-8b-code-instruct.   │
                              │  workshop-maas.svc.          │
                              │  cluster.local/v1            │
                              │                              │
                              │  Expects:                    │
                              │  POST /v1/chat/completions   │
                              │  { "model": "granite-8b-     │
                              │    code-instruct", ... }     │
                              └──────────────────────────────┘
```

## Bug Discovery Order

Developers will hit bugs in this sequence because each one blocks the next:

```
  mvn compile
       │
       ├── FAIL ──→ Bug #1 (missing import)
       │              fix it, recompile
       │
       ├── FAIL ──→ Bug #2 (missing constructor)
       │              fix it, recompile
       │
       ├── SUCCESS ──→ mvn spring-boot:run
       │
  curl -X POST /api/review
       │
       ├── 405 ────→ Bug #3 (@GetMapping → @PostMapping)
       │              fix it, restart, re-curl
       │
       ├── 500 ────→ Bug #4 (SSL not wired)
       │              fix it, restart, re-curl
       │
       ├── Error ──→ Bug #5 (model name typo)
       │              fix it, restart, re-curl
       │
       ├── Error ──→ Bug #6 (wrong API path)
       │              fix it, restart, re-curl
       │
       ├── Error ──→ Bug #7 (wrong response parsing)
       │              fix it, restart, re-curl
       │
       └── 200 + valid review ✓  DONE
```

## File Map (Clean Files vs Buggy Files)

```
code-review-service/
├── pom.xml                          ✅ CLEAN — no bugs
├── src/main/
│   ├── java/com/workshop/codereview/
│   │   ├── CodeReviewApplication.java    ⚠ BUG #1
│   │   ├── config/
│   │   │   └── RestClientConfig.java     ⚠ BUG #4
│   │   ├── controller/
│   │   │   └── CodeReviewController.java ⚠ BUGS #2, #3
│   │   ├── model/
│   │   │   ├── ReviewRequest.java        ✅ CLEAN
│   │   │   └── ReviewResponse.java       ✅ CLEAN
│   │   └── service/
│   │       └── GraniteService.java       ⚠ BUGS #6, #7
│   └── resources/
│       └── application.properties        ⚠ BUG #5
```
