(* Classic English readability metrics. Stdlib only.

   Implementation notes
   --------------------
   The whole module is written against ASCII. Bytes >= 0x80 are treated as
   non-letters, which means UTF-8 accented characters split words. That is a
   documented limitation rather than an oversight: every formula here was
   calibrated on English, and adding a Unicode dependency to a package whose
   only job is arithmetic over counts is a bad trade. *)

let is_alpha c = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
let is_vowel c = match c with 'a' | 'e' | 'i' | 'o' | 'u' | 'y' -> true | _ -> false

let lower c = if c >= 'A' && c <= 'Z' then Char.chr (Char.code c + 32) else c

(* ---------------------------------------------------------------- words *)

(* A word is a maximal run of letters that may contain internal ' or -.
   "internal" means the apostrophe/hyphen must have a letter on both sides,
   so a trailing quote in  he said 'ok'  does not join the tokens. *)
let words text =
  let n = String.length text in
  assert (n >= 0);
  let out = ref [] in
  let buf = Buffer.create 16 in
  let flush () =
    if Buffer.length buf > 0 then begin
      out := Buffer.contents buf :: !out;
      Buffer.clear buf
    end
  in
  let i = ref 0 in
  while !i < n do
    let c = text.[!i] in
    if is_alpha c then Buffer.add_char buf c
    else if
      (c = '\'' || c = '-')
      && Buffer.length buf > 0
      && !i + 1 < n
      && is_alpha text.[!i + 1]
    then Buffer.add_char buf c
    else flush ();
    incr i
  done;
  flush ();
  List.rev !out

let has_word s = List.length (words s) > 0

let sentences text =
  let n = String.length text in
  assert (n >= 0);
  let out = ref [] in
  let start = ref 0 in
  let i = ref 0 in
  let cut upto =
    let frag = String.sub text !start (upto - !start) in
    if has_word frag then out := String.trim frag :: !out
  in
  while !i < n do
    let c = text.[!i] in
    if c = '.' || c = '!' || c = '?' || c = '\n' then begin
      (* swallow a run of terminators so "?!" and "..." are one boundary *)
      let j = ref !i in
      while
        !j < n
        &&
        let d = text.[!j] in
        d = '.' || d = '!' || d = '?' || d = '\n' || d = '\r' || d = '"' || d = ')'
      do
        incr j
      done;
      cut !j;
      start := !j;
      i := !j
    end
    else incr i
  done;
  if !start < n then cut n;
  List.rev !out

(* ------------------------------------------------------------ syllables *)

(* strip everything that is not a letter and lowercase *)
let normalise w =
  let b = Buffer.create (String.length w) in
  String.iter (fun c -> if is_alpha c then Buffer.add_char b (lower c)) w;
  Buffer.contents b

let count_vowel_groups s =
  let n = String.length s in
  let count = ref 0 in
  let prev_vowel = ref false in
  for i = 0 to n - 1 do
    let v = is_vowel s.[i] in
    if v && not !prev_vowel then incr count;
    prev_vowel := v
  done;
  !count

let ends_with s suf =
  let ls = String.length s and lf = String.length suf in
  ls >= lf && String.sub s (ls - lf) lf = suf

(* Does the -ed / -es inflection carry its own syllable?  It does after a
   sibilant (s, x, z, ch, sh) for -es, and after t or d for -ed. *)
let inflection_is_syllabic w =
  let n = String.length w in
  if n < 3 then false
  else
    let stem = String.sub w 0 (n - 2) in
    let last = stem.[String.length stem - 1] in
    if ends_with w "es" then
      last = 's' || last = 'x' || last = 'z' || ends_with stem "ch"
      || ends_with stem "sh"
    else if ends_with w "ed" then last = 't' || last = 'd'
    else false

let syllables_in_word w =
  let s = normalise w in
  let n = String.length s in
  if n = 0 then 0
  else begin
    (* drop a non-syllabic -ed/-es before counting, so "walked" -> "walk" *)
    let s =
      if (ends_with s "es" || ends_with s "ed") && not (inflection_is_syllabic s)
      then String.sub s 0 (n - 2)
      else s
    in
    let s = if String.length s = 0 then normalise w else s in
    let n = String.length s in
    let groups = count_vowel_groups s in
    (* silent final e, except consonant + "le" as in table / little *)
    let silent_e =
      n >= 2 && s.[n - 1] = 'e'
      && not (n >= 3 && s.[n - 2] = 'l' && not (is_vowel s.[n - 3]))
    in
    let groups = if silent_e && groups > 1 then groups - 1 else groups in
    if groups < 1 then 1 else groups
  end

(* --------------------------------------------------------------- counts *)

type stats = {
  characters : int;
  words : int;
  sentences : int;
  syllables : int;
  polysyllables : int;
  complex_words : int;
  long_words : int;
  very_long_words : int;
}

let empty_stats =
  {
    characters = 0;
    words = 0;
    sentences = 0;
    syllables = 0;
    polysyllables = 0;
    complex_words = 0;
    long_words = 0;
    very_long_words = 0;
  }

(* Gunning's own rule excludes words that only reach three syllables because of
   a common suffix. We apply the -es/-ed part of that rule, which is the part
   that can be decided without a dictionary. *)
let is_complex w syl =
  syl >= 3
  &&
  let s = normalise w in
  if ends_with s "es" || ends_with s "ed" then
    syllables_in_word (String.sub s 0 (String.length s - 2)) >= 3
  else true

let add_word st w =
  let letters = String.length (normalise w) in
  let syl = syllables_in_word w in
  {
    st with
    characters = st.characters + letters;
    words = st.words + 1;
    syllables = st.syllables + syl;
    polysyllables = (if syl >= 3 then st.polysyllables + 1 else st.polysyllables);
    complex_words =
      (if is_complex w syl then st.complex_words + 1 else st.complex_words);
    long_words = (if letters > 6 then st.long_words + 1 else st.long_words);
    very_long_words =
      (if letters >= 7 then st.very_long_words + 1 else st.very_long_words);
  }

let stats text =
  assert (String.length text >= 0);
  let ws = words text in
  let ss = List.length (sentences text) in
  let st = List.fold_left add_word empty_stats ws in
  assert (st.complex_words <= st.polysyllables);
  { st with sentences = ss }

(* ------------------------------------------------------------- formulas *)

let usable st = st.words > 0 && st.sentences > 0
let f = float_of_int

let words_per_sentence st = f st.words /. f st.sentences
let syllables_per_word st = f st.syllables /. f st.words

let flesch_reading_ease_of_stats st =
  if not (usable st) then Float.nan
  else 206.835 -. (1.015 *. words_per_sentence st) -. (84.6 *. syllables_per_word st)

let flesch_kincaid_grade_of_stats st =
  if not (usable st) then Float.nan
  else (0.39 *. words_per_sentence st) +. (11.8 *. syllables_per_word st) -. 15.59

let gunning_fog_of_stats st =
  if not (usable st) then Float.nan
  else
    0.4 *. (words_per_sentence st +. (100. *. f st.complex_words /. f st.words))

let smog_of_stats st =
  if not (usable st) then Float.nan
  else (1.043 *. sqrt (f st.polysyllables *. 30. /. f st.sentences)) +. 3.1291

let coleman_liau_of_stats st =
  if not (usable st) then Float.nan
  else
    let l = 100. *. f st.characters /. f st.words in
    let s = 100. *. f st.sentences /. f st.words in
    (0.0588 *. l) -. (0.296 *. s) -. 15.8

let automated_readability_index_of_stats st =
  if not (usable st) then Float.nan
  else
    (4.71 *. (f st.characters /. f st.words))
    +. (0.5 *. words_per_sentence st)
    -. 21.43

let lix_of_stats st =
  if not (usable st) then Float.nan
  else words_per_sentence st +. (100. *. f st.long_words /. f st.words)

let rix_of_stats st =
  if not (usable st) then Float.nan else f st.very_long_words /. f st.sentences

let lift g text = g (stats text)
let flesch_reading_ease = lift flesch_reading_ease_of_stats
let flesch_kincaid_grade = lift flesch_kincaid_grade_of_stats
let gunning_fog = lift gunning_fog_of_stats
let smog = lift smog_of_stats
let coleman_liau = lift coleman_liau_of_stats
let automated_readability_index = lift automated_readability_index_of_stats
let lix = lift lix_of_stats
let rix = lift rix_of_stats

(* -------------------------------------------------------------- reports *)

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
}

let median xs =
  let a = Array.of_list xs in
  let n = Array.length a in
  if n = 0 then Float.nan
  else begin
    Array.sort compare a;
    if n mod 2 = 1 then a.(n / 2) else (a.((n / 2) - 1) +. a.(n / 2)) /. 2.
  end

let report_of_stats st =
  let fk = flesch_kincaid_grade_of_stats st in
  let fog = gunning_fog_of_stats st in
  let sm = smog_of_stats st in
  let cl = coleman_liau_of_stats st in
  let ari = automated_readability_index_of_stats st in
  {
    text_stats = st;
    flesch_reading_ease_score = flesch_reading_ease_of_stats st;
    flesch_kincaid_grade_score = fk;
    gunning_fog_score = fog;
    smog_score = sm;
    coleman_liau_score = cl;
    ari_score = ari;
    lix_score = lix_of_stats st;
    rix_score = rix_of_stats st;
    consensus_grade = (if usable st then median [ fk; fog; sm; cl; ari ] else Float.nan);
  }

let report text = report_of_stats (stats text)

let pp_report ppf r =
  let st = r.text_stats in
  Format.fprintf ppf "sentences            %d@\n" st.sentences;
  Format.fprintf ppf "words                %d@\n" st.words;
  Format.fprintf ppf "letters              %d@\n" st.characters;
  Format.fprintf ppf "syllables            %d@\n" st.syllables;
  Format.fprintf ppf "polysyllabic words   %d@\n" st.polysyllables;
  Format.fprintf ppf "long words (>6)      %d@\n" st.long_words;
  Format.fprintf ppf "flesch reading ease  %.2f@\n" r.flesch_reading_ease_score;
  Format.fprintf ppf "flesch-kincaid grade %.2f@\n" r.flesch_kincaid_grade_score;
  Format.fprintf ppf "gunning fog          %.2f@\n" r.gunning_fog_score;
  Format.fprintf ppf "smog                 %.2f@\n" r.smog_score;
  Format.fprintf ppf "coleman-liau         %.2f@\n" r.coleman_liau_score;
  Format.fprintf ppf "automated readability %.2f@\n" r.ari_score;
  Format.fprintf ppf "lix                  %.2f@\n" r.lix_score;
  Format.fprintf ppf "rix                  %.2f@\n" r.rix_score;
  Format.fprintf ppf "consensus grade      %.2f" r.consensus_grade

let jnum x = if Float.is_finite x then Printf.sprintf "%.4f" x else "null"

let report_to_json r =
  let st = r.text_stats in
  Printf.sprintf
    "{\"sentences\":%d,\"words\":%d,\"characters\":%d,\"syllables\":%d,\"polysyllables\":%d,\"complex_words\":%d,\"long_words\":%d,\"very_long_words\":%d,\"flesch_reading_ease\":%s,\"flesch_kincaid_grade\":%s,\"gunning_fog\":%s,\"smog\":%s,\"coleman_liau\":%s,\"automated_readability_index\":%s,\"lix\":%s,\"rix\":%s,\"consensus_grade\":%s}"
    st.sentences st.words st.characters st.syllables st.polysyllables
    st.complex_words st.long_words st.very_long_words
    (jnum r.flesch_reading_ease_score)
    (jnum r.flesch_kincaid_grade_score)
    (jnum r.gunning_fog_score) (jnum r.smog_score) (jnum r.coleman_liau_score)
    (jnum r.ari_score) (jnum r.lix_score) (jnum r.rix_score)
    (jnum r.consensus_grade)
