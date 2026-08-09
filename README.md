# readability_metrics

Classic English readability metrics for OCaml, with **no dependencies outside
the standard library**.

```ocaml
let r = Readability_metrics.report "The cat sat on the mat. A dog ran away." in
Format.printf "%a@." Readability_metrics.pp_report r
```

```
sentences            2
words                10
letters              28
syllables            11
polysyllabic words   0
long words (>6)      0
flesch reading ease  108.70
flesch-kincaid grade -0.66
gunning fog          2.00
smog                 3.13
coleman-liau         -5.26
automated readability -5.74
lix                  5.00
rix                  0.00
consensus grade      -0.66
```

## What it computes

| Metric | Source | Scale |
| --- | --- | --- |
| Flesch reading ease | Flesch (1948) | 0–100, higher is easier |
| Flesch–Kincaid grade | Kincaid et al. (1975) | US school grade |
| Gunning fog | Gunning (1952) | US school grade |
| SMOG | McLaughlin (1969) | US school grade |
| Coleman–Liau | Coleman & Liau (1975) | US school grade |
| Automated readability index | Senter & Smith (1967) | US school grade |
| LIX | Björnsson (1968) | ~20 easy … ~60 hard |
| RIX | Anderson (1983) | long words per sentence |

Plus a `consensus_grade`, the median of the five grade-scale formulas.

The counting layer is public too, because it is usually the part you actually
want to inspect when a score looks wrong: `words`, `sentences`,
`syllables_in_word` and a `stats` record holding letters, words, sentences,
syllables, polysyllabic words, Gunning-complex words and long words.

Every formula is exposed twice — `flesch_reading_ease : string -> float` and
`flesch_reading_ease_of_stats : stats -> float` — so computing eight scores
over one document tokenises once.

## Install

```
opam install readability_metrics
```

## Command line

The package installs a `readability` binary:

```
$ readability --json < article.txt
{"sentences":41,"words":812,...,"consensus_grade":9.8}

$ readability article.txt draft.txt      # text table, one block per file
```

## Honest limitations

This library is arithmetic over counts, and the counts come from heuristics,
not from a parser or a pronunciation dictionary.

* **Sentence splitting is punctuation-based.** It does not know about
  abbreviations, so `Dr. Who` counts as two sentences. Text heavy in
  abbreviations or decimal numbers will report too many sentences and therefore
  too low a grade.
* **Syllable counting is a vowel-group heuristic.** Its systematic error is
  vowel hiatus: `science`, `create` and `idea` each come out one syllable
  short. Across a document this is a small downward bias in the syllable count
  and a slightly optimistic Flesch score. The test suite pins these known-wrong
  answers deliberately, so behaviour changes show up as failures.
* **ASCII only.** Bytes ≥ 0x80 are treated as non-letters, so UTF-8 accented
  characters split words. Adding a Unicode dependency to a package whose job is
  arithmetic was judged a bad trade; if you need it, normalise the text first.
* **SMOG needs ~30 sentences** to mean anything. The formula extrapolates from
  shorter samples but McLaughlin did not calibrate it there.
* Every formula returns `nan` when the text has no words or no sentences.
  Check with `Float.is_nan`.

These are the same limitations the Python `textstat` and JavaScript
`text-readability` packages carry. The formulas themselves are reproduced
exactly as published.

## Tests

```
dune runtest
```

113 checks: tokeniser and syllable tables against hand-written expectations,
each formula against a value computed by hand from a synthetic `stats` record
(so the arithmetic is verified independently of the tokeniser), and properties
that must hold for any input — `nan` on empty text, syllables ≥ words,
`complex_words ≤ polysyllables`, harder prose scoring a higher grade, and no
exception on degenerate input.

## Provenance

Released by Michal Lip under the ISC licence. The implementation was written
with AI assistance (Claude). Each formula was transcribed from its published
definition and is checked in the test suite against a value computed by hand
from a synthetic `stats` record, so the arithmetic does not depend on the
tokeniser being right. The limitations section above is a list of measured
shortcomings, not boilerplate.

Published by the maintainers of
[BeLikeNative](https://belikenative.com/fix-grammar-with-belikenative/), an
English writing assistant.

## Licence

ISC. See [LICENSE](LICENSE).
