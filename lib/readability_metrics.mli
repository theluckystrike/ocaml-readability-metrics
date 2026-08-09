(** Classic English readability metrics, with no dependencies outside the
    OCaml standard library.

    The library is deliberately split into three layers:

    - {b tokenisation} ([words], [sentences], [syllables_in_word]) — plain
      functions you can call on their own and test in isolation;
    - {b counting} ([stats]) — a single pass that produces the six counts every
      published readability formula is built from;
    - {b formulas} ([flesch_reading_ease] and friends) — each exposed twice, once
      taking a [string] and once taking a [stats] record, so that a caller
      computing several scores over the same text pays for the counting once.

    {2 Accuracy caveats}

    Every formula below is defined over counts of sentences, words, syllables
    and letters. Those counts come from heuristics, not from a parser or a
    pronunciation dictionary, so scores are approximations. In particular:

    - sentence splitting is punctuation based and does not know about
      abbreviations, so ["Dr. Who"] counts as two sentences;
    - syllable counting is a vowel-group heuristic tuned for English and will
      be wrong on loanwords, names and initialisms. Its systematic error is
      vowel hiatus, where two adjacent vowels belong to different syllables:
      ["science"], ["create"] and ["idea"] each come out one syllable short.
      Over a document this shows up as a small downward bias in the syllable
      count, and therefore a slightly optimistic Flesch score.

    These are the same limitations the widely used Python [textstat] and
    JavaScript [text-readability] packages have; the formulas themselves are
    reproduced exactly as published. *)

(** {1 Tokenisation} *)

val words : string -> string list
(** [words text] splits [text] into word tokens. A token is a maximal run of
    ASCII letters, optionally containing internal apostrophes or hyphens
    (["don't"] and ["well-known"] are one token each). Digits and punctuation
    are not words. Returns tokens in order of appearance. *)

val sentences : string -> string list
(** [sentences text] splits [text] on the sentence-final punctuation [.], [!],
    [?] and on newline-separated blocks, then drops any fragment that contains
    no word. Consecutive terminators (["..."], ["?!"]) count as one boundary.
    A trailing fragment without a terminator still counts as a sentence, so
    ["hello"] is one sentence. *)

val syllables_in_word : string -> int
(** [syllables_in_word w] estimates the number of English syllables in the
    single token [w], using a vowel-group heuristic:

    - letters are lowercased and non-letters dropped;
    - maximal runs of [aeiouy] each contribute one syllable;
    - a silent trailing ["e"] is removed, unless the word ends in a consonant
      followed by ["le"] (["table"], ["little"]), and unless removing it would
      leave no vowel group at all;
    - the trailing inflections ["es"] and ["ed"] do not add a syllable when the
      preceding letter is not a sibilant or [t]/[d] (["walked"] is one syllable,
      ["wanted"] is two);
    - the result is never less than 1 for a non-empty token.

    [syllables_in_word ""] is [0]. *)

(** {1 Counting} *)

type stats = {
  characters : int;
      (** Letters only. Spaces, digits and punctuation are excluded, which is
          the convention the Coleman-Liau index and the ARI were calibrated
          against. *)
  words : int;  (** Number of tokens returned by {!words}. *)
  sentences : int;  (** Number of fragments returned by {!sentences}. *)
  syllables : int;  (** Sum of {!syllables_in_word} over all words. *)
  polysyllables : int;  (** Words of three syllables or more. *)
  complex_words : int;
      (** Gunning fog "complex" words: three syllables or more, excluding words
          made polysyllabic only by an ["es"] or ["ed"] inflection. Always at
          most [polysyllables]. *)
  long_words : int;  (** Words of more than six letters (the LIX definition). *)
  very_long_words : int;
      (** Words of seven letters or more (the RIX definition). *)
}
(** The counts every formula in this module is a function of. *)

val stats : string -> stats
(** [stats text] tokenises [text] once and returns all counts. On text with no
    words every field is [0]. *)

val empty_stats : stats
(** All fields [0]. Useful as a fold seed. *)

(** {1 Formulas}

    Each formula is given for a [stats] record ([*_of_stats]) and, for
    convenience, directly for a string. The string version is exactly
    [f_of_stats (stats text)].

    All of them return [nan] when the text has no words or no sentences, since
    every formula divides by at least one of those counts. Use
    {!Float.is_nan} to detect it rather than testing for a sentinel. *)

val flesch_reading_ease : string -> float
val flesch_reading_ease_of_stats : stats -> float
(** Flesch reading ease, Flesch (1948):
    [206.835 - 1.015 * (words / sentences) - 84.6 * (syllables / words)].
    Higher is easier; 60-70 is "plain English", above 90 is very easy. The
    scale is open ended and can go negative or above 100. *)

val flesch_kincaid_grade : string -> float
val flesch_kincaid_grade_of_stats : stats -> float
(** Flesch-Kincaid grade level, Kincaid et al. (1975):
    [0.39 * (words / sentences) + 11.8 * (syllables / words) - 15.59].
    The result is a US school grade. *)

val gunning_fog : string -> float
val gunning_fog_of_stats : stats -> float
(** Gunning fog index, Gunning (1952):
    [0.4 * ((words / sentences) + 100 * (complex_words / words))]. *)

val smog : string -> float
val smog_of_stats : stats -> float
(** SMOG grade, McLaughlin (1969):
    [1.043 * sqrt (polysyllables * 30 / sentences) + 3.1291].
    McLaughlin specified a 30-sentence sample; the formula extrapolates from
    shorter text but is unreliable below roughly 10 sentences. *)

val coleman_liau : string -> float
val coleman_liau_of_stats : stats -> float
(** Coleman-Liau index, Coleman and Liau (1975): [0.0588 * l - 0.296 * s -
    15.8], where [l] is letters per 100 words and [s] is sentences per 100
    words. Unlike the Flesch family this one needs no syllable counting, so it
    is the most robust of the set. *)

val automated_readability_index : string -> float
val automated_readability_index_of_stats : stats -> float
(** Automated readability index, Senter and Smith (1967):
    [4.71 * (characters / words) + 0.5 * (words / sentences) - 21.43]. *)

val lix : string -> float
val lix_of_stats : stats -> float
(** Läsbarhetsindex, Björnsson (1968):
    [(words / sentences) + 100 * (long_words / words)]. Below 30 is very easy,
    above 60 is very hard. Language independent by design. *)

val rix : string -> float
val rix_of_stats : stats -> float
(** Anderson's RIX (1983): [very_long_words / sentences]. *)

(** {1 Reports} *)

type report = {
  text_stats : stats;
  flesch_reading_ease_score : float;
  flesch_kincaid_grade_score : float;
  gunning_fog_score : float;
  smog_score : float;
  coleman_liau_score : float;
  ari_score : float;
  lix_score : float;
  rix_score : float;
  consensus_grade : float;
      (** Median of the five US-grade-scale formulas (Flesch-Kincaid, fog,
          SMOG, Coleman-Liau, ARI). [nan] if the stats are empty. *)
}

val report : string -> report
(** [report text] computes the stats once and every score from them. *)

val report_of_stats : stats -> report

val pp_report : Format.formatter -> report -> unit
(** Human readable multi-line rendering, one metric per line. *)

val report_to_json : report -> string
(** A single-line JSON object. Only ASCII, no dependencies; [nan] is rendered
    as JSON [null]. *)
