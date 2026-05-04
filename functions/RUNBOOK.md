# Cloud Functions Runbook

Operations notes for things that aren't deploy-time code.

## structureRecipe latency monitoring (BUT-483)

`structureRecipe` emits a structured log on every exit path:

```
event=structure_recipe.complete
durationMs=<int ms>
textLength=<int>
mode=<extract|enhance|spoken|ingredientLines>
success=<bool>
```

To wire a Cloud Logging distribution metric (p50/p95/p99) when latency
monitoring becomes a need:

1. Cloud Console → Logging → Logs Explorer → Create Metric.
2. Filter: `jsonPayload.event = "structure_recipe.complete"`.
3. Metric type: Distribution; Field name: `jsonPayload.durationMs`.
4. Add label: `jsonPayload.mode` so you can slice by extract/enhance/spoken.
5. Save as `structure_recipe.duration_ms`. Charts in Metrics Explorer.

No deploy needed — the structured fields are already emitted in production.
