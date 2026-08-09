(* readability - print readability metrics for text read from files or stdin. *)

let usage =
  "readability [--json] [FILE ...]\n\n\
   Reads UTF-8/ASCII text from the given FILEs, or from standard input when no\n\
   file is given, and prints classic English readability metrics.\n\n\
   Options:\n\
  \  --json     emit one JSON object per input instead of a text table\n\
  \  --help     show this message\n"

let read_all ic =
  let buf = Buffer.create 4096 in
  let chunk = Bytes.create 65536 in
  let rec loop () =
    let n = input ic chunk 0 (Bytes.length chunk) in
    if n > 0 then begin
      Buffer.add_subbytes buf chunk 0 n;
      loop ()
    end
  in
  loop ();
  Buffer.contents buf

let read_file path =
  let ic = open_in_bin path in
  Fun.protect ~finally:(fun () -> close_in ic) (fun () -> read_all ic)

let emit json label text =
  let r = Readability_metrics.report text in
  if json then print_endline (Readability_metrics.report_to_json r)
  else begin
    if label <> "" then Printf.printf "== %s\n" label;
    Format.printf "%a@." Readability_metrics.pp_report r
  end

let () =
  let args = Array.to_list Sys.argv |> List.tl in
  if List.mem "--help" args || List.mem "-h" args then print_string usage
  else begin
    let json = List.mem "--json" args in
    let files = List.filter (fun a -> String.length a = 0 || a.[0] <> '-') args in
    match files with
    | [] -> emit json "" (read_all stdin)
    | fs -> List.iter (fun p -> emit json p (read_file p)) fs
  end
