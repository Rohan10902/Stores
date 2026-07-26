# 7.1 Smart Repair test
Use the broken record containing 411004.
Expected: value preserved; ZIP suggested with confidence/reason; no ambiguous value silently deleted, merged, shifted or reassigned.
Confidence policy: >=95 AUTO-FIX CANDIDATE; 70-94 REVIEW; <70 UNRESOLVED.
Original source is never overwritten. Approved mappings are stored locally only.
Important: the inference engine is included in 7.1; ambiguous mappings still require review rather than unsafe guessing.
