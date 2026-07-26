# Store Data Assistant 7.1.1 — Interactive Smart Repair

This package extends 7.1 Smart Repair.

## Behavior
- Column-agnostic candidate scoring.
- ZIP, SID, dates, numeric, Boolean and text/categorical columns use the same profiling pipeline.
- >=95: AUTO-FIX CANDIDATE.
- 70–94: REVIEW.
- <70: UNRESOLVED.
- Ambiguous Boolean values always require user confirmation when multiple destinations are plausible.
- `MappingDecisionDialog.qml` provides Apply Mapping / Keep Unresolved / Remember my choice locally.
- Approved choices are stored locally in `~/.store_data_assistant/approved_mappings.json`.
- Source data must remain unchanged until the user explicitly saves a reviewed copy.

## Integration note
The dialog is a reusable component. When a repair suggestion has `requiresPrompt == true`,
call `mappingDecisionDialog.openForSuggestion(suggestion)`. On `mappingAccepted`, update the
working/review copy and optionally call MappingStore.remember(value, field). Never modify the
original source file.
