## 0.1.0 (2026-08-09)

First release.

- `words`, `sentences`, `syllables_in_word` tokenisers, usable on their own.
- `stats` record: letters, words, sentences, syllables, polysyllabic words,
  Gunning-complex words, long words, very long words.
- Flesch reading ease, Flesch-Kincaid grade, Gunning fog, SMOG, Coleman-Liau,
  automated readability index, LIX and RIX, each available from a string or
  from a precomputed `stats`.
- `report`, `pp_report` and `report_to_json`.
- `readability` command line tool, text table or `--json`.
- No dependencies outside the OCaml standard library.
