open Printf
open Types

let rec pp_pattern out = function
  | Var (_,x,n) -> fprintf out "#VAR_%a" pp_ident x
  | Pattern (_,m,v,args) ->
      begin
        List.iter (fun _ -> fprintf out "#APP(") args ;
        fprintf out "%a.%a" pp_ident m pp_ident v ;
        List.iter (fun pat -> fprintf out ",%a)" pp_pattern pat) args
      end
  | Brackets _ -> failwith "Not Implemented: conditionnal rewriting in TPDB export."
  | Joker (_,n) -> fprintf out "#UNDERSCORE_%i" n

let rec pp_term k out = function
  | Const (_,m,v) -> fprintf out "%a.%a" pp_ident m pp_ident v
  | Lam (_,_,ty,te) -> fprintf out "#LAMBDA(%a,%a)" (pp_term k) ty (pp_term (k+1)) te
  | Pi (_,_,a,b) -> fprintf out "#PI(%a,%a)" (pp_term k) a (pp_term (k+1)) b
  | DB (_,x,n) ->
      if n>=k then fprintf out "#VAR_%a" pp_ident x
      else fprintf out "#DB_%i" (k-n-1)
  | App (f,a,args) ->
      ( List.iter (fun _ -> fprintf out "#APP(" ) (a::args);
        pp_term k out f ;
        List.iter ( fprintf out ",%a)" (pp_term k) ) (a::args) )
  | Kind | Type _ | Meta _ -> assert false

let rec pp_underscore out = function
  | Var _ -> () | Brackets _ -> ()
  | Joker (_,n) -> fprintf out " #UNDERSCORE_%i" n
  | Pattern (_,m,v,args) -> List.iter (pp_underscore out) args

let pp_rule out r =
  let pat = (Pattern (r.l,r.md,r.id,r.args)) in
  fprintf out "(VAR";
  List.iter ( fun (v,_) -> fprintf out " #VAR_%a" pp_ident v ) r.ctx ;
  pp_underscore out pat ;
  fprintf out ")\n";
  fprintf out "(RULES %a -> %a )\n\n" pp_pattern pat (pp_term 0) r.rhs

let export out =
  List.iter (
    fun (md,lst) ->
      fprintf out "(COMMENT Rewrite rules for module '%s')\n" md;
      List.iter (pp_rule out) lst
  )