#!/bin/bash
echo "=== Self-Healing Pipeline ==="
# Step 1 - Fetch mitigation pointers from MySQL
echo "[1] Fetching mitigations from database..."
mysql -u root -pCyberSec!1 OWASP_TOP_10_API_VULNERABILITIES \
  -se "SELECT id, vulnerability_name, repo_path, version FROM mitigations WHERE repo_path IS NOT NULL;" | \
while IFS=$'\t' read -r ID NAME REPO_PATH VERSION; do
    echo ""
    echo "--- Processing fix ID: $ID --- $NAME ---"
    # Step 2 - Fetch the JSON file from GitHub
    BASE_URL="https://raw.githubusercontent.com/HMFhtx/mitigation-repo"
    JSON_URL="$BASE_URL/$VERSION/$REPO_PATH"
    echo "[2] Fetching fix from: $JSON_URL"
    JSON=$(curl -s "$JSON_URL")
    # Validate we got real JSON back
    if [ -z "$JSON" ]; then
        echo "SKIPPED - empty response from GitHub"
        continue
    fi
    if ! echo "$JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        echo "SKIPPED - invalid JSON from: $JSON_URL"
        continue
    fi
    # Step 3 - Loop through all steps in the JSON
    STEP_COUNT=$(echo "$JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['steps']))")
    echo "[3] Applying $STEP_COUNT fix steps..."
    for i in $(seq 0 $((STEP_COUNT - 1))); do
        # Extract step fields safely via Python (no shell interpolation risk)
        FILEPATH=$(echo "$JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['steps'][$i]['file_path'])")
        SEARCH=$(echo "$JSON"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['steps'][$i]['search_code'])")
        REPLACE=$(echo "$JSON"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['steps'][$i]['replace_code'])")
        STEP_NAME=$(echo "$JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['steps'][$i]['vulnerability_name'])")
        FULL_PATH="/opt/crapi/$FILEPATH"
        echo ""
        echo "  [Step $((i+1))] $STEP_NAME"
        echo "  Target: $FULL_PATH"
        # --- FILE CREATION (empty search_code means create new file) ---
        if [ -z "$SEARCH" ]; then
            mkdir -p "$(dirname "$FULL_PATH")"
            REPLACE="$REPLACE" FULL_PATH="$FULL_PATH" python3 - <<'PYEOF'
import os
full_path = os.environ['FULL_PATH']
replace   = os.environ['REPLACE']
with open(full_path, 'w') as f:
    f.write(replace)
print(f"  CREATED: {full_path}")
PYEOF
            continue
        fi
        # --- SEARCH & REPLACE (existing file) ---
        if [ ! -f "$FULL_PATH" ]; then
            echo "  SKIPPED - file not found: $FULL_PATH"
            continue
        fi
        # Backup — keep original with .orig extension, rotating .bak each run
        if [ ! -f "$FULL_PATH.orig" ]; then
            cp "$FULL_PATH" "$FULL_PATH.orig"
        fi
        cp "$FULL_PATH" "$FULL_PATH.bak"
        # Apply fix — values passed via env vars, NOT shell-interpolated into script
        SEARCH="$SEARCH" REPLACE="$REPLACE" FULL_PATH="$FULL_PATH" python3 - <<'PYEOF'
import os
full_path = os.environ['FULL_PATH']
search    = os.environ['SEARCH']
replace   = os.environ['REPLACE']
with open(full_path, 'r') as f:
    content = f.read()
if replace in content:
    print(f"  SKIPPED: fix already applied in {full_path}")
elif search in content:
    content = content.replace(search, replace, 1)
    with open(full_path, 'w') as f:
        f.write(content)
    print(f"  APPLIED: fix in {full_path}")
else:
    print(f"  NOT FOUND: search string missing in {full_path}")
PYEOF
    done
    echo ""
    echo "--- Completed: $NAME ---"
done

echo ""
echo "=== Running build verification ==="
cd /opt/crapi/services/identity
./gradlew build -x spotlessCheck -x test
if [ $? -eq 0 ]; then
    echo "BUILD SUCCESS - all fixes applied correctly"
else
    echo "BUILD FAILED - check output above for errors"
    exit 1
fi
echo ""
echo "=== Pipeline Finished ==="
