module A :
  sig
    type t = Acterm.acterm
    val compare : Acterm.acterm -> Acterm.acterm -> int
  end
module L :
  sig
    type key = A.t
    type 'a t = 'a Map.Make(A).t
    val empty : 'a t
    val is_empty : 'a t -> bool
    val mem : key -> 'a t -> bool
    val add : key -> 'a -> 'a t -> 'a t
    val singleton : key -> 'a -> 'a t
    val remove : key -> 'a t -> 'a t
    val merge :
      (key -> 'a option -> 'b option -> 'c option) -> 'a t -> 'b t -> 'c t
    val compare : ('a -> 'a -> int) -> 'a t -> 'a t -> int
    val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool
    val iter : (key -> 'a -> unit) -> 'a t -> unit
    val fold : (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
    val for_all : (key -> 'a -> bool) -> 'a t -> bool
    val exists : (key -> 'a -> bool) -> 'a t -> bool
    val filter : (key -> 'a -> bool) -> 'a t -> 'a t
    val partition : (key -> 'a -> bool) -> 'a t -> 'a t * 'a t
    val cardinal : 'a t -> int
    val bindings : 'a t -> (key * 'a) list
    val min_binding : 'a t -> key * 'a
    val max_binding : 'a t -> key * 'a
    val choose : 'a t -> key * 'a
    val split : key -> 'a t -> 'a t * 'a option * 'a t
    val find : key -> 'a t -> 'a
    val map : ('a -> 'b) -> 'a t -> 'b t
    val mapi : (key -> 'a -> 'b) -> 'a t -> 'b t
    val update : key -> 'a -> 'a list t -> 'a list t
    val si_of_l :
      Acterm.acterm Multi_set.elem list t ->
      Acterm.acterm -> Acterm.acterm Acterm.Si.t
  end
val solve_dioph :
  Acterm.acterm -> Acterm.acterm -> Diophantienne.VectSet.elt list
val assocvar :
  Acterm.acterm ->
  Acterm.acterm ->
  Diophantienne.VectMod.t list -> int -> Acterm.acterm Acterm.Si.t
val purifyac_to_assocvar :
  Acterm.acterm -> Acterm.acterm -> int -> Acterm.acterm Acterm.Si.t
val getSymb :
  'a Acterm.Si.t -> 'b Acterm.Si.t -> ((Acterm.Si.key * 'a) * 'b) list
val getVar : 'a Acterm.Si.t -> ((Acterm.Si.key * Acterm.Si.key) * 'a) list
type state_ac = {
  list : (Acterm.acterm * Acterm.acterm) list;
  subst : Acterm.Si.key Acterm.Si.t option;
  sigma : Acterm.Si.key Acterm.Si.t;
  next : state_ac list;
}
val global_a : int ref
val init_state : (Acterm.acterm * Acterm.acterm) list -> state_ac
val get_subst : state_ac -> Acterm.Si.key Acterm.Si.t option
val state_of_list :
  (Acterm.acterm * Acterm.acterm) list ->
  Acterm.Si.key Acterm.Si.t option ->
  state_ac list -> Acterm.Si.key Acterm.Si.t list -> state_ac
val unif_list :
  Acterm.Si.key -> Acterm.Si.key -> (Acterm.Si.key * Acterm.Si.key) list
val aux :
  Acterm.Si.key list ->
  Acterm.Si.key list -> (Acterm.Si.key * Acterm.Si.key) list
val unify : state_ac -> state_ac