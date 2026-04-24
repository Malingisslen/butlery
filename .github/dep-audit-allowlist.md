# Dependency Audit Allow-List

> **Status:** Documentation only. The `dep-audit.yml` workflow does **not** currently read this file.
> It exists so that accepted-risk exceptions can be recorded in one place while a future iteration
> wires the list into the workflow (e.g. via `osv-scanner` config or a pre-step filter).
>
> Until then: if CI fails on a vulnerability that is genuinely unexploitable in Butlery's context,
> add a row here **and** either (a) bump the package, (b) patch it, or (c) temporarily relax the
> audit level in the workflow with an inline comment pointing back to this file.

## Accepted vulnerabilities

| CVE | Package | Reason | Expires |
| --- | ------- | ------ | ------- |
| _(none yet)_ | | | |

## How to add an entry

1. Verify the vulnerability is not exploitable in Butlery (e.g. dev-only dep, unused code path).
2. Add a row above with CVE ID, package name, short justification, and an expiry date (max 90 days).
3. Link the row from the PR that accepts the risk.
4. Re-evaluate before the expiry date — either remove the row (fix landed) or re-justify with a new expiry.
