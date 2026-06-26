#!/bin/bash

# =============================================================
#  Code Review Service — Workshop Progress Checker
# =============================================================

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

PASS="${GREEN}✓${RESET}"
FAIL="${RED}✗${RESET}"

SERVICE_URL="http://localhost:8080"
PROJECT_DIR="$(cd "$(dirname "$0")/code-review-service" && pwd)"

total=5
passed=0
APP_PID=""

cleanup() {
    if [ -n "$APP_PID" ]; then
        kill "$APP_PID" 2>/dev/null
        wait "$APP_PID" 2>/dev/null
    fi
}
trap cleanup INT TERM EXIT

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║   Code Review Service — Progress Checker     ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════╝${RESET}"
echo ""

# -------------------------------------------------------------------
# Stage 1: Does mvn compile succeed?
# -------------------------------------------------------------------
echo -e "${BOLD}Stage 1/$total: Maven compile...${RESET}"
COMPILE_OUTPUT=$(cd "$PROJECT_DIR" && mvn compile -DskipTests -q 2>&1)
COMPILE_EXIT=$?

if [ $COMPILE_EXIT -eq 0 ]; then
    echo -e "  $PASS Compilation successful"
    ((passed++))
else
    echo -e "  $FAIL Compilation failed"
    echo ""
    echo -e "  ${YELLOW}Compiler output:${RESET}"
    echo "$COMPILE_OUTPUT" | grep -E "^\[ERROR\]" | head -10 | sed 's/^/    /'
    echo ""
    echo -e "  ${YELLOW}Hint: Read the error carefully — is something missing an import or a constructor?${RESET}"
    echo ""
    echo -e "${BOLD}Progress: $passed/$total stages passed${RESET}"
    exit 0
fi

# -------------------------------------------------------------------
# Stage 2: Does the application start?
# -------------------------------------------------------------------
echo -e "${BOLD}Stage 2/$total: Application startup...${RESET}"

# Kill any existing instance on port 8080
lsof -ti:8080 2>/dev/null | xargs kill 2>/dev/null
sleep 1

cd "$PROJECT_DIR" && mvn spring-boot:run -q > /tmp/codereview-app.log 2>&1 &
APP_PID=$!

STARTED=false
for i in $(seq 1 30); do
    if curl -s -o /dev/null -w "" "$SERVICE_URL/api/health" 2>/dev/null; then
        STARTED=true
        break
    fi
    sleep 2
done

if [ "$STARTED" = true ]; then
    echo -e "  $PASS Application started on port 8080"
    ((passed++))
else
    echo -e "  $FAIL Application failed to start within 60 seconds"
    echo ""
    echo -e "  ${YELLOW}Application log (last 15 lines):${RESET}"
    tail -15 /tmp/codereview-app.log | sed 's/^/    /'
    echo ""
    echo -e "  ${YELLOW}Hint: Check application.properties and your Spring configuration beans.${RESET}"
    echo ""
    echo -e "${BOLD}Progress: $passed/$total stages passed${RESET}"
    exit 0
fi

# -------------------------------------------------------------------
# Stage 3: Does GET /api/health return 200?
# -------------------------------------------------------------------
echo -e "${BOLD}Stage 3/$total: Health endpoint...${RESET}"
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$SERVICE_URL/api/health")

if [ "$HEALTH_STATUS" = "200" ]; then
    echo -e "  $PASS GET /api/health returns 200"
    ((passed++))
else
    echo -e "  $FAIL GET /api/health returned $HEALTH_STATUS"
    echo ""
    echo -e "  ${YELLOW}Hint: Check the controller annotations and request mappings.${RESET}"
    echo ""
    echo -e "${BOLD}Progress: $passed/$total stages passed${RESET}"
    exit 0
fi

# -------------------------------------------------------------------
# Stage 4: Does POST /api/review accept a request?
# -------------------------------------------------------------------
echo -e "${BOLD}Stage 4/$total: Review endpoint accepts POST...${RESET}"
REVIEW_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "$SERVICE_URL/api/review" \
    -H "Content-Type: application/json" \
    -d '{"code":"System.out.println(\"hello\");","language":"java"}')

if [ "$REVIEW_STATUS" = "200" ]; then
    echo -e "  $PASS POST /api/review returns 200"
    ((passed++))
else
    echo -e "  $FAIL POST /api/review returned $REVIEW_STATUS"
    echo ""
    if [ "$REVIEW_STATUS" = "405" ]; then
        echo -e "  ${YELLOW}Hint: The server rejected POST. Check the HTTP method annotation on the review endpoint.${RESET}"
    elif [ "$REVIEW_STATUS" = "500" ]; then
        echo -e "  ${YELLOW}Hint: Internal server error. Check the application logs for exceptions (SSL? null pointer?).${RESET}"
    else
        echo -e "  ${YELLOW}Hint: Unexpected status code. Check your controller and service layer.${RESET}"
    fi
    echo ""
    echo -e "${BOLD}Progress: $passed/$total stages passed${RESET}"
    exit 0
fi

# -------------------------------------------------------------------
# Stage 5: Does the review contain actual AI content (not an error)?
# -------------------------------------------------------------------
echo -e "${BOLD}Stage 5/$total: AI-powered code review...${RESET}"
REVIEW_BODY=$(curl -s \
    -X POST "$SERVICE_URL/api/review" \
    -H "Content-Type: application/json" \
    -d '{"code":"System.out.println(\"hello\");","language":"java"}' \
    --max-time 30)

if echo "$REVIEW_BODY" | grep -qi '"review"' && ! echo "$REVIEW_BODY" | grep -qi '"review"\s*:\s*"Error'; then
    echo -e "  $PASS Valid code review received from Granite model!"
    ((passed++))
else
    echo -e "  $FAIL Response does not contain a valid code review"
    echo ""
    echo -e "  ${YELLOW}Response body:${RESET}"
    echo "$REVIEW_BODY" | head -5 | sed 's/^/    /'
    echo ""
    if echo "$REVIEW_BODY" | grep -qi "ssl\|certificate\|handshake"; then
        echo -e "  ${YELLOW}Hint: SSL certificate error. Is the HttpClient configured to trust internal certificates?${RESET}"
    elif echo "$REVIEW_BODY" | grep -qi "model.*not found\|not found.*model"; then
        echo -e "  ${YELLOW}Hint: The model was not found. Double-check the model name in application.properties.${RESET}"
    elif echo "$REVIEW_BODY" | grep -qi "status 4\|status 5"; then
        echo -e "  ${YELLOW}Hint: The Granite API returned an error. Check the API endpoint path in GraniteService.${RESET}"
    elif echo "$REVIEW_BODY" | grep -qi "could not parse"; then
        echo -e "  ${YELLOW}Hint: The response came back but parsing failed. Compare the actual JSON structure to what the parser expects.${RESET}"
    else
        echo -e "  ${YELLOW}Hint: Check the GraniteService for API path, model name, and response parsing issues.${RESET}"
    fi
    echo ""
    echo -e "${BOLD}Progress: $passed/$total stages passed${RESET}"
    exit 0
fi

# -------------------------------------------------------------------
# All stages passed!
# -------------------------------------------------------------------
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${GREEN}║   ALL $total/$total STAGES PASSED!                      ║${RESET}"
echo -e "${BOLD}${GREEN}║   Your Code Review Service is working!       ║${RESET}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════╝${RESET}"
echo ""
