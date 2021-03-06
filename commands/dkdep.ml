open Basic
open Term
open Rule
open Parser
open Entry

type path = string

(** [deps] contains the dependencies found so far, reset before each file. *)
let current_mod  : mident                 ref = ref (mk_mident "<not initialised>")
let current_deps : (mident * path) list   ref = ref []
let ignore       : bool                   ref = ref false


let in_deps : mident -> bool = fun n ->
  List.mem_assoc n !current_deps

let add_dep : mident -> path option -> unit = fun name file ->
  let cmp (s1,_) (s2,_) = compare s1 s2 in
  match file with
  | None -> ()
  | Some file ->
    current_deps := List.sort cmp ((name, file) :: !current_deps)

(** [find_dk md path] looks for the ".dk" file corresponding to the module
    named [name] in the directories of [path]. If no corresponding file is
    found, or if there are several possibilities, the program fails with a
    graceful error message. *)
let find_dk : mident -> path list -> path option = fun md path ->
  let name = string_of_mident md in
  let file_name = name ^ ".dk" in
  let path = Filename.current_dir_name :: path in
  let path = List.sort_uniq String.compare path in
  let add_dir dir =
    if dir = Filename.current_dir_name then file_name
    else Filename.concat dir file_name
  in
  let files = List.map add_dir path in
  match List.filter Sys.file_exists files with
  | []  ->
    if !ignore then None
    else
      begin
        Format.eprintf "No file for module %S in path...@." name;
        exit 1
      end
  | [f] -> Some f
  | fs  ->
    Format.eprintf "Several files correspond to module %S...@." name;
    List.iter (Format.eprintf "  - %s@.") fs;
    exit 1

(** [add_dep name] adds the module named [name] to the list of dependencies if
    no corresponding ".dko" file is found in the load path. The dependency is
    not added either if it is already present. *)
let add_dep : mident -> unit = fun md ->
  if md <> !current_mod && not (in_deps md)
  then add_dep md (find_dk md (get_path ()))

(** Term / pattern / entry traversal commands. *)

let mk_name c =
  add_dep (md c)

let rec mk_term t =
  match t with
  | Kind | Type _ | DB _ -> ()
  | Const(_,c)           -> mk_name c
  | App(f,a,args)        -> List.iter mk_term (f::a::args)
  | Lam(_,_,None,te)     -> mk_term te
  | Lam(_,_,Some(ty),te) -> mk_term ty; mk_term te
  | Pi (_,_,a,b)         -> mk_term a; mk_term b

let rec mk_pattern p =
  match p with
  | Var(_,_,_,args)   -> List.iter mk_pattern args
  | Pattern(_,c,args) -> mk_name c; List.iter mk_pattern args
  | Lambda(_,_,te)    -> mk_pattern te
  | Brackets(t)       -> mk_term t

let mk_rule r =
  mk_pattern r.pat; mk_term r.rhs

let handle_entry e =
  match e with
  | Decl(_,_,_,te)              -> mk_term te
  | Def(_,_,_,None,te)          -> mk_term te
  | Def(_,_,_,Some(ty),te)      -> mk_term ty; mk_term te
  | Rules(_,rs)                 -> List.iter mk_rule rs
  | Eval(_,_,te)                -> mk_term te
  | Infer (_,_,te)              -> mk_term te
  | Check(_,_,_,Convert(t1,t2)) -> mk_term t1; mk_term t2
  | Check(_,_,_,HasType(te,ty)) -> mk_term te; mk_term ty
  | DTree(_,_,_)                -> ()
  | Print(_,_)                  -> ()
  | Name(_,_)                   -> ()
  | Require(_,md)               -> add_dep md

type dep_data = mident * (path * (mident * path) list)

let handle_file : string -> dep_data = fun file ->
  try
    (* Initialisation. *)
    let md = mk_mident file in
    current_mod := md; current_deps := [];
    (* Actully parsing and gathering data. *)
    let input = open_in file in
    Parse_channel.handle md handle_entry input;
    close_in input;
    (md, (file, !current_deps))
  with
  | Env.EnvError (l,e)   -> Errors.fail_env_error l e
  | Sys_error err        -> Errors.fail_sys_error err

(** Output main program. *)

let output_deps : Format.formatter -> dep_data list -> unit = fun oc data ->
  let objfile src = Filename.chop_extension src ^ ".dko" in
  let output_line : dep_data -> unit = fun (name, (file, deps)) ->
    let deps = List.map (fun (_,src) -> objfile src) deps in
    let deps = String.concat " " deps in
    Format.fprintf oc "%s : %s %s@." (objfile file) file deps
  in
  List.iter output_line data

let topological_sort graph =
  let rec explore path visited node =
    if List.mem node path then
      begin
        Format.eprintf "Dependecies are circular...";
        exit 1
      end;
    if List.mem node visited then visited else
      let edges =
        try List.assoc node graph
        with Not_found ->
          if !ignore
          then []
          else
            begin
              Format.eprintf "Cannot compute dependencies for the file %S... (maybe you forgot to put it on the command line?)@." node;
              exit 1
            end
      in
      node :: List.fold_left (explore (node :: path)) visited edges
  in
  List.fold_left (fun visited (n,_) -> explore [] visited n) [] graph

let output_sorted : Format.formatter -> dep_data list -> unit = fun oc data ->
  let deps = List.map (fun (_,(f,deps)) -> (f, List.map snd deps)) data in
  let deps = List.rev (topological_sort deps) in
  Format.printf "%s@." (String.concat " " deps)

let _ =
  (* Parsing of command line arguments. *)
  let output  = ref stdout in
  let sorted  = ref false  in
  let args = Arg.align
    [ ( "-d"
      , Arg.String Env.set_debug_mode
      , "FLAGS enables debugging for all given flags:
      q : (quiet)    disables all warnings
      n : (notice)   notifies about which symbol or rule is currently treated
      o : (module)   notifies about loading of an external module (associated
                     to the command #REQUIRE)
      c : (confluence) notifies about information provided to the confluence
                     checker (when option -cc used)
      u : (rule)     provides information about type checking of rules
      t : (typing)   provides information about type-checking of terms
      r : (reduce)   provides information about reduction performed in terms
      m : (matching) provides information about pattern matching" )
    ; ( "-v"
      , Arg.Unit (fun () -> Env.set_debug_mode "montru")
      , " Verbose mode (equivalent to -d 'montru')" )
    ; ( "-q"
      , Arg.Unit (fun () -> Env.set_debug_mode "q")
      , " Quiet mode (equivalent to -d 'q')" )
    ; ( "-o"
      , Arg.String (fun n -> output := open_out n)
      , "FILE Outputs to file FILE" )
    ; ( "-s"
      , Arg.Set sorted
      , " Sort the source files according to their dependencies" )
    ; ( "--ignore"
      , Arg.Set ignore
      , " If some dependencies are not found, ignore them" )
    ; ( "-I"
      , Arg.String add_path
      , "DIR Add the directory DIR to the load path" ) ]
  in
  let usage = Format.sprintf "Usage: %s [OPTION]... [FILE]...
Compute the dependencies of the given Dedukti FILE(s).
For more information see https://github.com/Deducteam/Dedukti.
Available options:" Sys.argv.(0) in
  let files =
    let files = ref [] in
    Arg.parse args (fun f -> files := f :: !files) usage;
    List.rev !files
  in
  (* Actual work. *)
  let dep_data = List.map handle_file files in
  let formatter = Format.formatter_of_out_channel !output in
  let output_fun = if !sorted then output_sorted else output_deps in
  output_fun formatter dep_data;
  Format.pp_print_flush formatter ();
  close_out !output
