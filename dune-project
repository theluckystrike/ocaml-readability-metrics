(lang dune 3.0)
(name readability_metrics)
(generate_opam_files true)

(source (github theluckystrike/ocaml-readability-metrics))
(license ISC)
(authors "Michal Lip <51033404+theluckystrike@users.noreply.github.com>")
(maintainers "Michal Lip <51033404+theluckystrike@users.noreply.github.com>")
(homepage "https://belikenative.com/fix-grammar-with-belikenative/")
(documentation "https://github.com/theluckystrike/ocaml-readability-metrics#readme")

(package
 (name readability_metrics)
 (synopsis "Classic English readability metrics with no dependencies")
 (description
  "Flesch reading ease, Flesch-Kincaid grade, Gunning fog, SMOG, Coleman-Liau, the automated readability index, LIX and RIX, computed from a single tokenising pass over the text. Includes the sentence, word and syllable counters the formulas are built on, so they can be used and tested on their own, plus a `readability` command line tool that prints a table or a JSON object. Depends on nothing outside the OCaml standard library.")
 (tags ("text" "readability" "nlp" "linguistics" "flesch" "smog"))
 (depends
  (ocaml (>= 4.14))))
