#!/bin/bash
# Runs the verification checks embedded in every search_replace.json in this repo.
# Each JSON may have a top-level "verification" array with entries that carry:
#   curl             – the curl command to run
#   expect_status    – expected HTTP status code
#   expect_body_contains  – (optional) string that MUST appear in the response body
#   expect_body_excludes  – (optional) string that MUST NOT appear in the response body

PASS=0
FAIL=0
SKIP=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

run_check() {
    local label="$1"
    local actual_status="$2"
    local expect_status="$3"
    local body="$4"
    local expect_contains="$5"
    local expect_excludes="$6"
    local check_ok=true

    if [[ "$actual_status" != "$expect_status" ]]; then
        echo -e "    ${RED}FAIL${RESET} status: expected ${expect_status}, got ${actual_status}"
        check_ok=false
    fi

    if [[ -n "$expect_contains" && "$body" != *"$expect_contains"* ]]; then
        echo -e "    ${RED}FAIL${RESET} body missing: '${expect_contains}'"
        check_ok=false
    fi

    if [[ -n "$expect_excludes" && "$body" == *"$expect_excludes"* ]]; then
        echo -e "    ${RED}FAIL${RESET} body contains forbidden string: '${expect_excludes}'"
        check_ok=false
    fi

    if $check_ok; then
        echo -e "    ${GREEN}PASS${RESET}"
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
}

echo -e "${BOLD}=== Mitigation Verification ===${RESET}"
echo ""

# Find all search_replace.json files
while IFS= read -r json_file; do
    vuln=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(d.get('subcategory', d.get('owasp_tag','Unknown')))" "$json_file" 2>/dev/null)
    verifications=$(python3 -c "import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get('verification',[])) if d.get('verification') else 0)" "$json_file" 2>/dev/null)

    if [[ -z "$verifications" || "$verifications" -eq 0 ]]; then
        continue
    fi

    echo -e "${CYAN}${BOLD}[${json_file}]${RESET}"
    echo -e "  Vulnerability: ${vuln}"
    echo ""

    for i in $(seq 0 $((verifications - 1))); do
        description=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
v = d['verification'][$i]
print(v.get('description',''))
" "$json_file" 2>/dev/null)

        curl_cmd=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
v = d['verification'][$i]
print(v.get('curl',''))
" "$json_file" 2>/dev/null)

        expect_status=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
v = d['verification'][$i]
print(v.get('expect_status',''))
" "$json_file" 2>/dev/null)

        expect_contains=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
v = d['verification'][$i]
print(v.get('expect_body_contains',''))
" "$json_file" 2>/dev/null)

        expect_excludes=$(python3 -c "
import json, sys
d = json.load(open(sys.argv[1]))
v = d['verification'][$i]
print(v.get('expect_body_excludes',''))
" "$json_file" 2>/dev/null)

        echo -e "  ${BOLD}Check $((i+1)):${RESET} ${description}"

        # Skip checks that still have unfilled placeholders
        if echo "$curl_cmd" | grep -qE '<[a-z_-]+-token>'; then
            echo -e "    ${YELLOW}SKIP${RESET} – curl contains placeholder token (manual test required)"
            SKIP=$((SKIP + 1))
            continue
        fi

        # Inject -w '\nHTTP_STATUS:%{http_code}' into the curl command if not already there
        if ! echo "$curl_cmd" | grep -q "HTTP_STATUS"; then
            # Append status-code writer after the first `curl` invocation
            modified_cmd=$(echo "$curl_cmd" | sed "s/curl -s/curl -s -w '\\\\nHTTP_STATUS:%{http_code}'/")
        else
            modified_cmd="$curl_cmd"
        fi

        # Run the command and capture output
        raw_output=$(eval "$modified_cmd" 2>/dev/null)

        # Extract the last HTTP_STATUS line (handles multi-curl loop commands)
        actual_status=$(echo "$raw_output" | grep 'HTTP_STATUS:' | tail -1 | sed 's/.*HTTP_STATUS://')
        body=$(echo "$raw_output" | grep -v 'HTTP_STATUS:')

        # For loop-based commands (rate-limit tests) the expected status is the LAST one
        run_check "$description" "$actual_status" "$expect_status" "$body" "$expect_contains" "$expect_excludes"
    done

    echo ""
done < <(find . -path './.git' -prune -o -name 'search_replace.json' -print | sort)

echo -e "${BOLD}=== Results ===${RESET}"
echo -e "  ${GREEN}Passed:${RESET} ${PASS}"
echo -e "  ${RED}Failed:${RESET} ${FAIL}"
echo -e "  ${YELLOW}Skipped:${RESET} ${SKIP} (placeholder tokens — require manual testing)"
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
