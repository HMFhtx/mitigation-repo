# API Vulnerability Mitigations Repository

This repository contains mitigation code for OWASP API Security Top 10 vulnerabilities. It serves as the external code source for the automated vulnerability remediation pipeline — the **Vulnerability Loader** fetches fix definitions from here at runtime, keeping mitigation logic versioned and decoupled from the database.

---

## How It Works

The Vulnerability DB stores a pointer (path + version tag) to a file in this repo. At remediation time, the Vulnerability Loader fetches the file via the raw GitHub URL and passes the fix steps to the Remediation Executor.

```
Vulnerability DB (pointer only)
        │
        │  path: "api3_excessive_data_exposure/search_replace.json"
        │  version: "v1.2.0"
        ▼
  This Repository (source of truth for fix logic)
        │
        ▼
  Vulnerability Loader → Remediation Executor → Verification
```

---

## Repository Structure

```
mitigations-repo/
├── README.md
├── api1_broken_object_level_auth/
│   ├── search_replace.json
│   └── metadata.json
├── api2_broken_authentication/
│   ├── search_replace.json
│   └── metadata.json
├── api3_excessive_data_exposure/
│   ├── search_replace.json
│   └── metadata.json
├── api4_lack_of_rate_limiting/
│   ├── search_replace.json
│   └── metadata.json
├── api5_broken_function_level_auth/
│   ├── search_replace.json
│   └── metadata.json
├── api6_mass_assignment/
│   ├── search_replace.json
│   └── metadata.json
├── api7_security_misconfiguration/
│   ├── search_replace.json
│   └── metadata.json
├── api8_injection/
│   ├── search_replace.json
│   └── metadata.json
├── api9_improper_asset_management/
│   ├── search_replace.json
│   └── metadata.json
└── api10_insufficient_logging/
    ├── search_replace.json
    └── metadata.json
```

### File Types

| File | Purpose |
|------|---------|
| `search_replace.json` | Search/replace fix steps applied by the Remediation Executor |
| `metadata.json` | OWASP tag, detection tool, severity, description |

---

## File Formats

### `search_replace.json`

Defines one or more code-level fix steps. Each step targets a specific file with a search pattern and its replacement.

```json
{
  "vulnerability": "API3-2023",
  "owasp_tag": "Excessive Data Exposure",
  "steps": [
    {
      "file_path": "src/main/java/com/crapi/exception/ExceptionHandler.java",
      "search_code": "return ResponseEntity.status(INTERNAL_SERVER_ERROR).body(e.getMessage());",
      "replace_code": "log.error(\"Unhandled runtime exception\", e);\nreturn ResponseEntity.status(INTERNAL_SERVER_ERROR).body(\"Internal error\");"
    },
    {
      "file_path": "src/main/java/com/crapi/exception/ExceptionHandler.java",
      "search_code": "e.printStackTrace();",
      "replace_code": "log.warn(\"Account locked\", e);"
    }
  ]
}
```

### `metadata.json`

Describes the vulnerability and links it back to the detection pipeline.

```json
{
  "vulnerability_id": "API3-2023",
  "owasp_tag": "Excessive Data Exposure",
  "severity": "High",
  "detection_tools": ["EvoMaster", "RESTler", "Manual"],
  "description": "API returns more data than the client needs, leaking sensitive fields or stack traces.",
  "references": [
    "https://owasp.org/API-Security/editions/2023/en/0xa3-broken-object-property-level-authorization/"
  ]
}
```

---

## Fetching Files at Runtime

The Vulnerability Loader constructs the raw file URL from the DB pointer:

```
https://raw.githubusercontent.com/<org>/mitigations-repo/<version>/<path>
```

**Example:**

```
https://raw.githubusercontent.com/your-org/mitigations-repo/v1.2.0/api3_excessive_data_exposure/search_replace.json
```

> Always pin to a version tag, never `main`. This ensures a verified fix is not silently changed by a later commit.

---

## Versioning

This repository uses [Semantic Versioning](https://semver.org/):

| Change type | Version bump |
|-------------|-------------|
| New mitigation added | `MINOR` — e.g. `v1.1.0` → `v1.2.0` |
| Existing fix corrected or improved | `PATCH` — e.g. `v1.2.0` → `v1.2.1` |
| Breaking change to file format/structure | `MAJOR` — e.g. `v1.x.x` → `v2.0.0` |

After merging a PR, create a new Git tag before updating the DB to point to it.

---

## Contributing a New Mitigation

1. **Create a branch** from `main`:
   ```bash
   git checkout -b add/api4-rate-limiting-fix
   ```

2. **Add your files** under the correct OWASP folder:
   ```
   api4_lack_of_rate_limiting/
   ├── search_replace.json
   └── metadata.json
   ```

3. **Test locally** by running the Remediation Executor against a CrAPI staging instance.

4. **Open a Pull Request** — requires Analyst Review approval before merging (mirrors the Analyst Review step in the remediation pipeline).

5. **Tag the release** after merge:
   ```bash
   git tag v1.3.0
   git push origin v1.3.0
   ```

6. **Update the Vulnerability DB** to point to the new version tag.

---

## Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Folder | `api{N}_{short_vulnerability_name}` | `api3_excessive_data_exposure` |
| File | lowercase, underscores | `search_replace.json` |
| Version tag | `v{MAJOR}.{MINOR}.{PATCH}` | `v1.2.0` |

---

## Related Components

| Component | Role |
|-----------|------|
| **Vulnerability DB** | Stores OWASP tags and pointers to files in this repo |
| **Vulnerability Loader** | Fetches `search_replace.json` from this repo at runtime |
| **Remediation Executor** | Applies the fix steps to the target codebase |
| **Verification** | Re-runs the detection tool to confirm the vulnerability is resolved |
| **Detection tools** | EvoMaster, RESTler, Manual — feed into the Detect stage |
