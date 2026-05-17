# OWASP API Security Top 10 — Migration from 2019 to 2023

This repository has been updated to align with the **OWASP API Security Top 10 (2023)** list.
All folder names, JSON vulnerability codes, and `owasp_tag` fields now reflect the 2023 edition.

---

## What Changed

### Folder Renames

| Old (2019) | New (2023) | Reason |
|---|---|---|
| `api1_broken_object_level_auth/` | `api1_broken_object_level_authorization/` | Full name spelling |
| `api3_excessive_data_exposure/` | `api3_broken_object_property_level_authorization/` | 2023 merged Excessive Data Exposure + Mass Assignment into one category |
| `api4_lack_of_rate_limiting/` | `api4_unrestricted_resource_consumption/` | Renamed in 2023 |
| `api5_broken_function_level_auth/` | `api5_broken_function_level_authorization/` | Full name spelling |
| `api6_mass_assignment/` | `api6_unrestricted_access_sensitive_business_flows/` | New 2023 category replaced Mass Assignment |
| `api7_security_misconfiguration/` | `api8_security_misconfiguration/` | Security Misconfiguration moved from #7 to #8 |
| `api8_injection/` | *(removed)* | Injection is no longer a standalone category in 2023 |
| `api9_improper_asset_management/` | `api9_improper_inventory_management/` | Renamed in 2023 |
| `api10_insufficient_logging/` | `api10_unsafe_consumption_of_apis/` | New 2023 category replaced Insufficient Logging |

### New Folders

| Folder | Reason |
|---|---|
| `api7_ssrf/` | SSRF became its own dedicated category in 2023 (was buried under Security Misconfiguration in 2019) |

### Content Moves

- `api8_injection/nosql_injection_coupon_validation/` → `api8_security_misconfiguration/nosql_injection_coupon_validation/`
  OWASP 2023 treats injection vulnerabilities as a subset of Security Misconfiguration (improperly configured input handling, missing parameterized queries).

### JSON Tag Fixes

- `api8_security_misconfiguration/improper_error_handling/search_replace.json` had stale 2019 tags (`API3-2023` / `Excessive Data Exposure`). Corrected to `API8-2023` / `Security Misconfiguration`.

---

## Database

Run `update_2023_paths.sql` on the server to update all `repo_path` values in the `mitigations` table to match the new folder structure.

---

## 2019 vs 2023 Full Comparison

| # | 2019 | 2023 |
|---|---|---|
| 1 | Broken Object Level Authorization | Broken Object Level Authorization |
| 2 | Broken User Authentication | Broken Authentication |
| 3 | Excessive Data Exposure | Broken Object Property Level Authorization |
| 4 | Lack of Resources & Rate Limiting | Unrestricted Resource Consumption |
| 5 | Broken Function Level Authorization | Broken Function Level Authorization |
| 6 | Mass Assignment | Unrestricted Access to Sensitive Business Flows |
| 7 | Security Misconfiguration | **Server Side Request Forgery (SSRF)** *(new)* |
| 8 | Injection | Security Misconfiguration |
| 9 | Improper Assets Management | Improper Inventory Management |
| 10 | Insufficient Logging & Monitoring | Unsafe Consumption of APIs |
