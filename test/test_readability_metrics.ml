(* Tests for readability_metrics.

   Three kinds of check:
     1. tokenisation and syllable counts against hand-written expectations;
     2. each formula against a value computed by hand from a stats record, so
        the arithmetic is checked independently of the tokeniser;
     3. properties that must hold for any input (bounds, nan handling,
        monotonicity of reading ease in sentence length). *)

module R = Readability_metrics

let failures = ref 0
let checks = ref 0

let fail fmt =
  Printf.ksprintf
    (fun s ->
      incr failures;
      prerr_endline ("FAIL: " ^ s))
    fmt

let check name cond =
  incr checks;
  if not cond then fail "%s" name

let check_int name ~expected ~got =
  incr checks;
  if expected <> got then fail "%s: expected %d, got %d" name expected got

let check_float ?(eps = 0.005) name ~expected ~got =
  incr checks;
  if Float.is_nan got || Float.abs (expected -. got) > eps then
    fail "%s: expected %.4f, got %.4f" name expected got

let check_list name ~expected ~got =
  incr checks;
  if expected <> got then
    fail "%s: expected [%s], got [%s]" name (String.concat ";" expected)
      (String.concat ";" got)

(* ------------------------------------------------------------ tokenising *)

let test_words () =
  check_list "words: plain" ~expected:[ "The"; "cat"; "sat" ]
    ~got:(R.words "The cat sat.");
  check_list "words: apostrophe kept" ~expected:[ "don't"; "stop" ]
    ~got:(R.words "don't stop");
  check_list "words: hyphen kept" ~expected:[ "well-known"; "fact" ]
    ~got:(R.words "well-known fact");
  check_list "words: quotes not joined" ~expected:[ "he"; "said"; "ok" ]
    ~got:(R.words "he said 'ok'");
  check_list "words: digits dropped" ~expected:[ "version"; "of"; "it" ]
    ~got:(R.words "version 3.14 of it");
  check_list "words: empty" ~expected:[] ~got:(R.words "");
  check_list "words: punctuation only" ~expected:[] ~got:(R.words "-- ... !!")

let test_sentences () =
  check_int "sentences: three" ~expected:3
    ~got:(List.length (R.sentences "One. Two! Three?"));
  check_int "sentences: ellipsis is one boundary" ~expected:2
    ~got:(List.length (R.sentences "Wait... then go."));
  check_int "sentences: interrobang is one boundary" ~expected:2
    ~got:(List.length (R.sentences "Really?! Yes."));
  check_int "sentences: unterminated tail counts" ~expected:1
    ~got:(List.length (R.sentences "no full stop here"));
  check_int "sentences: newline separates" ~expected:2
    ~got:(List.length (R.sentences "line one\nline two"));
  check_int "sentences: wordless fragments dropped" ~expected:1
    ~got:(List.length (R.sentences "Hello. ... !"));
  check_int "sentences: empty" ~expected:0 ~got:(List.length (R.sentences ""))

let syllable_cases =
  [
    ("cat", 1); ("a", 1); ("the", 1); ("apple", 2); ("banana", 3);
    ("table", 2); ("little", 2); ("simple", 2); ("people", 2);
    ("walked", 1); ("wanted", 2); ("needed", 2); ("boxes", 2);
    ("watches", 2); ("makes", 1); ("hope", 1); ("hoped", 1);
    ("readability", 5); ("computer", 3); ("beautiful", 3);
    ("science", 1); ("rhythm", 1); ("strength", 1); ("queue", 1);
    ("idea", 2); ("create", 1); ("running", 2); ("sentence", 2);
    ("understand", 3); ("everyone", 3);
  ]

let test_syllables () =
  List.iter
    (fun (w, n) ->
      check_int (Printf.sprintf "syllables %S" w) ~expected:n
        ~got:(R.syllables_in_word w))
    syllable_cases;
  check_int "syllables: empty is zero" ~expected:0 ~got:(R.syllables_in_word "");
  check_int "syllables: punctuation only is zero" ~expected:0
    ~got:(R.syllables_in_word "---")

(* Not every expectation above is the dictionary answer, and that is
   deliberate: the table pins down what the documented heuristic does, so a
   change in behaviour shows up as a failing test. The known wrong answers are
   all vowel-hiatus undercounts, where two adjacent vowels belong to different
   syllables: "science" (sci-ence) and "create" (cre-ate) are scored 1 instead
   of 2, and "idea" (i-de-a) is scored 2 instead of 3. Deciding hiatus needs a
   pronunciation dictionary, which this package deliberately does not carry;
   the effect on a whole document is a small downward bias in the syllable
   count. "rhythm" comes out at 1 only because y is treated as a vowel. *)

(* --------------------------------------------------------------- counts *)

let sample = "The cat sat on the mat. A dog ran away."

let test_stats () =
  let st = R.stats sample in
  check_int "stats: sentences" ~expected:2 ~got:st.R.sentences;
  check_int "stats: words" ~expected:10 ~got:st.R.words;
  (* the(3) cat(3) sat(3) on(2) the(3) mat(3) a(1) dog(3) ran(3) away(4) *)
  check_int "stats: letters" ~expected:28 ~got:st.R.characters;
  check_int "stats: syllables" ~expected:11 ~got:st.R.syllables;
  check_int "stats: no polysyllables" ~expected:0 ~got:st.R.polysyllables;
  check_int "stats: no long words" ~expected:0 ~got:st.R.long_words;
  let empty = R.stats "" in
  check_int "stats: empty words" ~expected:0 ~got:empty.R.words;
  check_int "stats: empty sentences" ~expected:0 ~got:empty.R.sentences

let test_complex_subset () =
  (* complex_words is always a subset of polysyllables *)
  let texts =
    [ sample; "Extraordinarily complicated documentation."; "hi"; "";
      "Interested parties have distributed the requested materials." ]
  in
  List.iter
    (fun t ->
      let st = R.stats t in
      check "complex_words <= polysyllables"
        (st.R.complex_words <= st.R.polysyllables))
    texts

(* ------------------------------------------------------------- formulas *)

(* A synthetic stats record with round numbers, so the expected values below
   can be worked out with a calculator and do not depend on tokenising. *)
let synth =
  {
    R.characters = 500;
    words = 100;
    sentences = 5;
    syllables = 150;
    polysyllables = 20;
    complex_words = 20;
    long_words = 30;
    very_long_words = 25;
  }

let test_formulas () =
  (* words/sentence = 20, syllables/word = 1.5 *)
  (* 206.835 - 1.015*20 - 84.6*1.5 = 206.835 - 20.3 - 126.9 = 59.635 *)
  check_float "flesch reading ease" ~expected:59.635
    ~got:(R.flesch_reading_ease_of_stats synth);
  (* 0.39*20 + 11.8*1.5 - 15.59 = 7.8 + 17.7 - 15.59 = 9.91 *)
  check_float "flesch-kincaid grade" ~expected:9.91
    ~got:(R.flesch_kincaid_grade_of_stats synth);
  (* 0.4*(20 + 100*20/100) = 0.4*40 = 16 *)
  check_float "gunning fog" ~expected:16.0 ~got:(R.gunning_fog_of_stats synth);
  (* 1.043*sqrt(20*30/5) + 3.1291 = 1.043*sqrt 120 + 3.1291 *)
  check_float "smog"
    ~expected:((1.043 *. sqrt 120.) +. 3.1291)
    ~got:(R.smog_of_stats synth);
  (* L = 500, S = 5 ; 0.0588*500 - 0.296*5 - 15.8 = 29.4 - 1.48 - 15.8 *)
  check_float "coleman-liau" ~expected:12.12 ~got:(R.coleman_liau_of_stats synth);
  (* 4.71*5 + 0.5*20 - 21.43 = 23.55 + 10 - 21.43 = 12.12 *)
  check_float "ari" ~expected:12.12
    ~got:(R.automated_readability_index_of_stats synth);
  (* 20 + 100*30/100 = 50 *)
  check_float "lix" ~expected:50.0 ~got:(R.lix_of_stats synth);
  (* 25/5 = 5 *)
  check_float "rix" ~expected:5.0 ~got:(R.rix_of_stats synth)

let test_consensus () =
  let r = R.report_of_stats synth in
  (* grades are 9.91, 16.0, smog ~14.55, 12.12, 12.12 -> median 12.12 *)
  check_float "consensus grade is the median" ~expected:12.12
    ~got:r.R.consensus_grade

let test_nan_on_empty () =
  let fs =
    [
      ("flesch", R.flesch_reading_ease); ("fk", R.flesch_kincaid_grade);
      ("fog", R.gunning_fog); ("smog", R.smog); ("cl", R.coleman_liau);
      ("ari", R.automated_readability_index); ("lix", R.lix); ("rix", R.rix);
    ]
  in
  List.iter
    (fun (name, g) ->
      check (name ^ " is nan on empty input") (Float.is_nan (g "")))
    fs;
  check "report consensus is nan on empty input"
    (Float.is_nan (R.report "").R.consensus_grade);
  check "json renders nan as null"
    (let s = R.report_to_json (R.report "") in
     String.length s > 0
     &&
     let re = "\"flesch_reading_ease\":null" in
     let rec find i =
       i + String.length re <= String.length s
       && (String.sub s i (String.length re) = re || find (i + 1))
     in
     find 0)

(* ------------------------------------------------------------ properties *)

let easy = "The dog ran. The cat sat. I see it. We go now. She is here."

let hard =
  "The institutional characterisation of multidimensional organisational \
   behaviour necessitates comprehensive methodological reconsideration \
   throughout contemporary administrative environments, particularly where \
   accountability frameworks intersect with participatory decision-making."

let test_ordering () =
  check "easy text scores higher reading ease than hard text"
    (R.flesch_reading_ease easy > R.flesch_reading_ease hard);
  check "hard text scores a higher grade than easy text"
    (R.flesch_kincaid_grade hard > R.flesch_kincaid_grade easy);
  check "hard text has a higher lix than easy text"
    (R.lix hard > R.lix easy);
  check "hard text has a higher fog than easy text"
    (R.gunning_fog hard > R.gunning_fog easy)

let test_totals_consistent () =
  let texts = [ easy; hard; sample; "one"; "a b c d e f g." ] in
  List.iter
    (fun t ->
      let st = R.stats t in
      let ws = R.words t in
      check_int "stats.words equals List.length (words t)"
        ~expected:(List.length ws) ~got:st.R.words;
      check_int "stats.syllables equals the sum over words"
        ~expected:(List.fold_left (fun a w -> a + R.syllables_in_word w) 0 ws)
        ~got:st.R.syllables;
      check "every word has at least one syllable"
        (List.for_all (fun w -> R.syllables_in_word w >= 1) ws);
      check "syllables >= words" (st.R.syllables >= st.R.words))
    texts

let test_no_exceptions_on_odd_input () =
  let odd =
    [ ""; " "; "\n\n\n"; "..."; "!?!?"; "123 456"; "-"; "'"; "a"; String.make 5000 'x';
      "Sentence with UTF-8: caf\xc3\xa9 na\xc3\xafve." ]
  in
  List.iter
    (fun t ->
      incr checks;
      match R.report_to_json (R.report t) with
      | _ -> ()
      | exception e -> fail "raised on %S: %s" t (Printexc.to_string e))
    odd

let () =
  test_words ();
  test_sentences ();
  test_syllables ();
  test_stats ();
  test_complex_subset ();
  test_formulas ();
  test_consensus ();
  test_nan_on_empty ();
  test_ordering ();
  test_totals_consistent ();
  test_no_exceptions_on_odd_input ();
  Printf.printf "%d checks, %d failures\n" !checks !failures;
  if !failures > 0 then exit 1
