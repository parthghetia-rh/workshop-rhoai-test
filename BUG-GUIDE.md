# Facilitator Bug Guide — Code Review Service Workshop

This is your answer key. Each bug is explained in plain English with the exact
file, line, what developers will see, the fix, and talking points for when
someone gets stuck.

---

## Bug #1 — Missing Import for @SpringBootApplication

**File:** `CodeReviewApplication.java`, line 5
**Category:** Compile error (first thing that breaks)

**What's wrong:**
The `@SpringBootApplication` annotation is used on line 5, but the import
statement for it is missing. Line 3 only imports `SpringApplication` (the
runner), not `SpringBootApplication` (the annotation).

**What developers see:**
```
error: cannot find symbol
  @SpringBootApplication
  ^
  symbol: class SpringBootApplication
```

**The fix — add this import on line 4:**
```java
import org.springframework.boot.autoconfigure.SpringBootApplication;
```

**Plain English explanation:**
Spring Boot needs two things to start: the `@SpringBootApplication` annotation
(which tells Spring "this is the main config class, scan everything from here")
and `SpringApplication.run()` (which actually boots the app). The code has the
runner import but forgot the annotation import. Java requires you to explicitly
import every class you use.

**If someone asks "why are there two imports with similar names?":**
`SpringApplication` is the class with the `run()` method that launches the app.
`SpringBootApplication` is an annotation that combines three Spring annotations
into one (`@Configuration`, `@EnableAutoConfiguration`, `@ComponentScan`). They
sound similar but do completely different things.

---

## Bug #2 — Missing Constructor (Dependency Injection Broken)

**File:** `CodeReviewController.java`, line 13
**Category:** Compile error (surfaces after Bug #1 is fixed)

**What's wrong:**
The controller declares `private final GraniteService graniteService` on line 13
but there's no constructor to initialize it. In Java, a `final` field MUST be
assigned a value either at declaration or in a constructor.

**What developers see:**
```
error: variable graniteService might not have been initialized
```

**The fix — add a constructor after line 13:**
```java
public CodeReviewController(GraniteService graniteService) {
    this.graniteService = graniteService;
}
```

**Plain English explanation:**
Spring Boot uses "dependency injection" — instead of you creating objects with
`new`, Spring creates them and passes them in. The way Spring knows to do this
is through a constructor. When Spring sees the controller needs a
`GraniteService`, it looks for a `GraniteService` bean (which exists because
`GraniteService.java` has `@Service` on it), creates it, and passes it into the
constructor. Without the constructor, Spring can't inject the dependency and Java
won't even compile because the `final` field is never set.

**If someone asks "why final? can't we just remove final?":**
You could, but then `graniteService` would be `null` at runtime and you'd get a
`NullPointerException` when the first request comes in. The `final` keyword is
actually helping here — it forces the compile error EARLY instead of letting a
null slip through to runtime. The real fix is the constructor, not removing
`final`.

---

## Bug #3 — Wrong HTTP Method on /review Endpoint

**File:** `CodeReviewController.java`, line 20
**Category:** Runtime error (surfaces after the app compiles and starts)

**What's wrong:**
The `/api/review` endpoint uses `@GetMapping` but the client sends a POST
request (because it needs to send a JSON body with the code to review). GET
requests don't have a body in standard HTTP.

**What developers see:**
```
HTTP/1.1 405 Method Not Allowed
```

**The fix — change line 20:**
```java
// Before:
@GetMapping("/review")

// After:
@PostMapping("/review")
```

**Plain English explanation:**
HTTP has different methods for different purposes. GET is for retrieving data
(like loading a web page). POST is for sending data (like submitting a form).
When you `curl -X POST`, you're sending a POST request, but the server only has
a GET handler registered for `/review`. Spring returns 405 "Method Not Allowed"
— meaning "I know this URL exists, but you're using the wrong HTTP verb."

**If someone asks "what's the difference between 404 and 405?":**
404 = "this URL doesn't exist at all." 405 = "this URL exists, but you're using
the wrong HTTP method." A 405 is actually helpful — it tells you you're close,
you just need the right method.

---

## Bug #4 — SSL Context Created But Not Applied

**File:** `RestClientConfig.java`, lines 29-30
**Category:** Runtime error (surfaces when the service tries to call Granite)

**What's wrong:**
Lines 18-27 create an SSL context that trusts all certificates (needed because
OpenShift uses internal self-signed certs). But lines 29-30 build the
`HttpClient` without actually using that SSL context. The `sslContext` variable
is created and then ignored.

**What developers see:**
```json
{"review":"Error: javax.net.ssl.SSLHandshakeException: PKIX path building failed..."}
```

**The fix — change lines 29-30:**
```java
// Before:
return HttpClient.newBuilder()
        .build();

// After:
return HttpClient.newBuilder()
        .sslContext(sslContext)
        .build();
```

**Plain English explanation:**
When our service calls the Granite model, it uses HTTPS. OpenShift's internal
network uses certificates that aren't signed by a public certificate authority
(like Let's Encrypt or DigiSign) — they're self-signed. Java doesn't trust
self-signed certs by default, so it refuses the connection. The code creates a
custom SSL context that says "trust everything," but then forgets to actually
plug it into the HTTP client. It's like building a key for a lock, putting it on
the table, and then trying to open the door with your bare hands.

**If someone asks "isn't trusting all certs a security risk?":**
Yes, in production this would be dangerous because it disables SSL verification
entirely (man-in-the-middle attacks become possible). In this workshop, we do it
because we're on an internal cluster network where both services are in the same
OpenShift cluster. In production, you'd import the cluster's CA certificate into
Java's truststore instead.

---

## Bug #5 — Model Name Typo in Configuration

**File:** `application.properties`, line 5
**Category:** Runtime error (surfaces after SSL is fixed)

**What's wrong:**
The model name is misspelled: `granite-8b-code-instuct` (missing the 'r' in
"instruct"). When the service sends this name to vLLM, it can't find a model
by that name.

**What developers see:**
```json
{"review":"Error: Model returned status 404: {\"error\":\"model granite-8b-code-instuct not found\"}"}
```
(or similar model-not-found message from vLLM)

**The fix — change line 5:**
```properties
# Before:
granite.model.name=granite-8b-code-instuct

# After:
granite.model.name=granite-8b-code-instruct
```

**Plain English explanation:**
The model name in the config file has a typo — "instuct" instead of "instruct."
When the service sends a request to the Granite server, it includes this name in
the JSON payload so the server knows which model to use. The server does an exact
string match, finds no model called "granite-8b-code-instuct," and returns an
error. This is a common real-world bug — config typos are one of the top causes
of production incidents.

**If someone asks "how would I find the correct model name?":**
You can query the model server directly:
```bash
curl -k https://granite-8b-code-instruct.workshop-maas.svc.cluster.local/v1/models
```
Or use the Python chatbot — it auto-discovers the model name at startup (look at
the "Active GPU Model" line when it starts).

---

## Bug #6 — Wrong API Endpoint Path

**File:** `GraniteService.java`, line 54
**Category:** Runtime error (surfaces after model name is fixed)

**What's wrong:**
The code sends the request to `/v1/completions` but the JSON payload uses the
`"messages"` array format (with role/content objects). The `/v1/completions`
endpoint expects a `"prompt"` string, not a `"messages"` array. The correct
endpoint for the messages format is `/v1/chat/completions`.

**What developers see:**
```json
{"review":"Error: Model returned status 400: ..."}
```
(vLLM rejects the request because messages format is invalid for the completions endpoint)

**The fix — change line 54:**
```java
// Before:
.uri(URI.create(baseUrl + "/completions"))

// After:
.uri(URI.create(baseUrl + "/chat/completions"))
```

**Plain English explanation:**
vLLM (the model server) provides two different APIs following the OpenAI
standard:

- `/v1/completions` — the older "text completion" API. You send a plain text
  `"prompt"` and it continues the text. No concept of roles or conversation.
- `/v1/chat/completions` — the "chat" API. You send a `"messages"` array with
  roles like `"system"` and `"user"`. This is what ChatGPT-style apps use.

Our code builds a messages array (with system and user roles) but sends it to
the completions endpoint, which doesn't understand that format. It's like
writing a letter in French and mailing it to someone who only reads English.

**If someone asks "what's the difference between completions and chat/completions?":**
`/completions` = "here's some text, keep writing." No awareness of conversation
structure. `/chat/completions` = "here's a conversation with system instructions
and user messages, respond as the assistant." Chat completions is what most
modern AI apps use because it lets you give the model a persona and context.

---

## Bug #7 — Response Parsing Looks for Wrong JSON Field

**File:** `GraniteService.java`, line 78
**Category:** Logic error (surfaces after the API path is fixed)

**What's wrong:**
The `extractContent()` method on line 78 looks for a `"text"` field in the
response JSON. But the `/v1/chat/completions` endpoint returns the content
nested inside `choices[0].message.content`, not `choices[0].text`. The `"text"`
field is what the older `/v1/completions` endpoint returns.

**What developers see:**
```json
{"review":"Error: Could not parse model response. Raw: {\"id\":\"...\",\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"The code is correct...\"}}]}"}
```
The raw JSON is visible in the error message, and developers can see the actual
review text is inside `"content"`, not `"text"`.

**The fix — change line 78:**
```java
// Before:
int textStart = json.indexOf("\"text\"");

// After:
int textStart = json.indexOf("\"content\"");
```

**Plain English explanation:**
The two APIs return different JSON structures:

`/v1/completions` response:
```json
{"choices": [{"text": "The review is..."}]}
```

`/v1/chat/completions` response:
```json
{"choices": [{"message": {"role": "assistant", "content": "The review is..."}}]}
```

Since we fixed Bug #6 to use chat/completions, the response now comes back in
the chat format. But the parsing code still looks for `"text"` (the completions
format). It needs to look for `"content"` instead. The nice thing about this bug
is that the error message shows the raw JSON, so developers can see exactly
where the actual content lives.

**If someone asks "why not use a JSON library instead of string parsing?":**
Great question — in a real application, you absolutely should use Jackson or Gson
to properly parse the JSON into objects. The string-based parsing here is
intentionally fragile to make the bug more visible and educational. In
production code, you'd define response DTOs and let Spring/Jackson deserialize
the response automatically.

---

## Quick Reference Card

| # | File                        | Line | Broken                               | Fixed                                       |
|---|-----------------------------|------|----------------------------------------|---------------------------------------------|
| 1 | CodeReviewApplication.java  | 5    | Missing import                         | Add `import ...SpringBootApplication`       |
| 2 | CodeReviewController.java   | 13   | No constructor                         | Add constructor with `GraniteService` param  |
| 3 | CodeReviewController.java   | 20   | `@GetMapping`                          | `@PostMapping`                               |
| 4 | RestClientConfig.java       | 29   | `.build()`                             | `.sslContext(sslContext).build()`             |
| 5 | application.properties      | 5    | `granite-8b-code-instuct`              | `granite-8b-code-instruct`                   |
| 6 | GraniteService.java         | 54   | `baseUrl + "/completions"`             | `baseUrl + "/chat/completions"`              |
| 7 | GraniteService.java         | 78   | `json.indexOf("\"text\"")`             | `json.indexOf("\"content\"")`                |

## Helpful Hints to Give (Without Giving Away the Answer)

If someone is stuck, try these nudges in order:

- **Bug #1:** "Read the error message carefully. What does 'cannot find symbol' mean in Java?"
- **Bug #2:** "The field is `final`. What does Java require for final fields?"
- **Bug #3:** "What HTTP method does curl use with -X POST? What method does the endpoint accept?"
- **Bug #4:** "The SSL context is created on line 26-27. Where is it used?"
- **Bug #5:** "Read the model name character by character. Compare it to the actual model name."
- **Bug #6:** "The JSON payload has 'messages' with roles. Which OpenAI endpoint handles messages?"
- **Bug #7:** "The raw JSON is right there in the error. Where does the actual text live in that JSON?"
