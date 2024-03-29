(**************************************************************************)
(*                                                                        *)
(*                                OCaml                                   *)
(*                                                                        *)
(*    Thomas Gazagnaire (OCamlPro), Fabrice Le Fessant (INRIA Saclay)     *)
(*    Hongbo Zhang (University of Pennsylvania)                           *)
(*   Copyright 2007 Institut National de Recherche en Informatique et     *)
(*   en Automatique.  All rights reserved.  This file is distributed      *)
(*   under the terms of the Q Public License version 1.0.                 *)
(*                                                                        *)
(**************************************************************************)

(* Original Code from Ber-metaocaml, modified fo 3.12.0 and fixed *)
(* Printing code expressions *)
(* Authors:  Ed Pizzi, Fabrice Le Fessant *)
(* Extensivily Rewrite: Hongbo Zhang: University of Pennsylvania*)
(* TODO more fine-grained precedence pretty-printing *)
open Asttypes
open Format
open Location
open Longident
open Parsetree

let prefix_symbols  = [ '!'; '?'; '~' ] ;;
let infix_symbols = [ '='; '<'; '>'; '@'; '^'; '|'; '&'; '+'; '-'; '*'; '/'; '$'; '%' ] 
let operator_chars = [ '!'; '$'; '%'; '&'; '*'; '+'; '-'; '.'; '/';
                       ':'; '<'; '='; '>'; '?'; '@'; '^'; '|'; '~' ] 
let numeric_chars  = [ '0'; '1'; '2'; '3'; '4'; '5'; '6'; '7'; '8'; '9' ] 

(* type fixity = Infix| Prefix  *)


let special_infix_strings =
  ["asr"; "land"; "lor"; "lsl"; "lsr"; "lxor"; "mod"; "or"; ":="; "!=" ] 

(* determines if the string is an infix string.
   checks backwards, first allowing a renaming postfix ("_102") which
   may have resulted from Pexp -> Texp -> Pexp translation, then checking
   if all the characters in the beginning of the string are valid infix
   characters. *)
let fixity_of_string  = function
  | s when List.mem s special_infix_strings -> `Infix s
  | s when List.mem s.[0] infix_symbols -> `Infix s
  | s when List.mem s.[0] prefix_symbols -> `Prefix s
  | _ -> `Normal

let view_fixity_of_exp = function 
  | {pexp_desc = Pexp_ident {txt=Lident l;_};_} -> fixity_of_string l
  | _ -> `Normal  ;;

let is_infix  = function  | `Infix _ -> true | _  -> false

let is_predef_option = function
  | (Ldot (Lident "*predef*","option")) -> true
  | _ -> false
        
type space_formatter = (unit, Format.formatter, unit) format

let override = function
  | Override -> "!"
  | Fresh -> ""

(* variance encoding: need to sync up with the [parser.mly] *)        
let type_variance = function
  | (false,false) -> ""
  | (true,false) -> "+"
  | (false,true) -> "-"
  | (_,_) -> assert false

type construct = 
  [ `cons of expression list
  | `list of expression list
  | `nil
  | `normal
  | `simple of Longident.t
  | `tuple ]
      
let view_expr x = 
  match x.pexp_desc with
  | Pexp_construct ( {txt= Lident "()"; _},_,_) -> `tuple
  | Pexp_construct ( {txt= Lident "[]";_},_,_) -> `nil
  | Pexp_construct ( {txt= Lident"::";_},Some _,_) ->
      let rec loop exp acc = match exp with
          | {pexp_desc=Pexp_construct ({txt=Lident "[]";_},_,_);_} -> (List.rev acc,true)
          | {pexp_desc=
             Pexp_construct ({txt=Lident "::";_},Some ({pexp_desc= Pexp_tuple([e1;e2]);_}),_);_} ->
              loop e2 (e1::acc)
          | e -> (List.rev (e::acc),false) in
      let (ls,b) = loop x []  in
      if b then
        `list ls
      else `cons ls
  | Pexp_construct (x,None,_) -> `simple (x.txt)
  | _ -> `normal
        
let is_simple_construct :construct -> bool = function
  | `nil | `tuple | `list _ | `simple _  -> true
  | `cons _ | `normal -> false
  
let pp = fprintf

let rec is_irrefut_patt x =
  match x.ppat_desc with
  | Ppat_any | Ppat_var _ | Ppat_unpack _ -> true
  | Ppat_alias (p,_) -> is_irrefut_patt p
  | Ppat_tuple (ps) -> List.for_all is_irrefut_patt ps
  | Ppat_constraint (p,_) -> is_irrefut_patt p
  | Ppat_or (l,r) -> is_irrefut_patt l || is_irrefut_patt r
  | Ppat_record (ls,_) -> List.for_all (fun (_,x) -> is_irrefut_patt x) ls
  | Ppat_lazy p -> is_irrefut_patt p 
  | Ppat_constant _ | Ppat_construct _  | Ppat_variant _ | Ppat_array _ | Ppat_type _-> false (*conservative*)
class printer  ()= object(self:'self)
  val pipe = false
  val semi = false
  val ifthenelse = false
  method under_pipe = {<pipe=true>}
  method under_semi = {<semi=true>}
  method under_ifthenelse = {<ifthenelse=true>}
  method reset_semi = {<semi=false>}
  method reset_ifthenelse = {<ifthenelse=false>}
  method reset_pipe = {<pipe=false>} 
  method reset = {<pipe=false;semi=false;ifthenelse=false>}
  method list : 'a . ?sep:space_formatter -> ?first:space_formatter ->
    ?last:space_formatter -> (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a list -> unit
        = fun  ?sep ?first  ?last fu f xs -> 
          let first = match first with Some x -> x |None -> ""
          and last = match last with Some x -> x |None -> ""
          and sep = match sep with Some x -> x |None -> "@ " in
          let aux f = function
            | [] -> ()
            | [x] -> fu f x
            | xs ->
                let rec loop  f = function
                  | [x] -> fu f x
                  | x::xs ->  pp f "%a%(%)%a" fu x sep loop xs 
                  | _ -> assert false in begin
                      pp f "%(%)%a%(%)" first loop xs last;
                  end in
          aux f xs
  method option : 'a. ?first:space_formatter -> ?last:space_formatter ->
    (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a option -> unit =
      fun  ?first  ?last fu f a ->
        let first = match first with Some x -> x | None -> ""
        and last = match last with Some x -> x | None -> "" in
        match a with
        | None -> ()
        | Some x -> pp f "%(%)%a%(%)" first fu x last
  method paren: 'a . ?first:space_formatter -> ?last:space_formatter ->
    bool -> (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a -> unit =
    fun  ?(first="") ?(last="") b fu f x ->
      if b then pp f "(%(%)%a%(%))" first fu  x last
      else fu f x

          
  method longident f = function
    | Lident s ->
        (* let len = String.length s in *)
        (match s.[0] with
        (* | '~' -> *)
        (*     if List.mem s ["~+";"~-";"~+.";"~-."] then *)
        (*       pp f "%s" (String.sub s 1 (len-1)) *)
        (*     else *)
        (*       pp f "%s" s  *)
        | 'a' .. 'z' | 'A' .. 'Z' | '_' when not (is_infix (fixity_of_string s)) ->
            pp f "%s" s
        | _ -> pp f "(@;%s@;)" s )
    | Ldot(y,s) -> (match s.[0] with
      | 'a'..'z' | 'A' .. 'Z' | '_' when not(is_infix (fixity_of_string s)) ->
          pp f "%a.%s" self#longident y s
      | _ ->
          pp f "%a.(@;%s@;)@ " self#longident y s)
    | Lapply (y,s)->
        pp f "%a(%a)" self#longident y self#longident s
  method longident_loc f x = pp f "%a" self#longident x.txt
  method constant f  = function
    | Const_char i -> pp f "%C"  i 
    | Const_string i -> pp f "%S" i
    | Const_int i -> self#paren (i<0) (fun f -> pp f "%d") f i
    | Const_float  i -> self#paren (i.[0]='-') (fun f -> pp f "%s") f i 
    | Const_int32 i -> self#paren (i<0l) (fun f -> pp f "%ldl") f i
    | Const_int64 i -> self#paren (i<0L) (fun f -> pp f "%LdL") f i (* pp f "%LdL" i *)
    | Const_nativeint i -> self#paren (i<0n) (fun f -> pp f "%ndn") f i (* pp f "%ndn" i *)

  (* trailing space*)        
  method mutable_flag f   = function
    | Immutable -> ()
    | Mutable -> pp f "mutable@;"
  method virtual_flag f  = function
    | Concrete -> ()
    | Virtual -> pp f "virtual@;"

  (* trailing space added *)        
  method rec_flag f = function
    | Nonrecursive -> ()
    | Recursive | Default -> pp f "rec "
  method direction_flag f = function
    | Upto -> pp f "to@ "
    | Downto -> pp f "downto@ "
  method private_flag f = function
    | Public -> ()
    | Private -> pp f "private@ "

  method constant_string f s = pp f "%S" s 
  method tyvar f str = pp f "'%s" str
  method string_quot f x = pp f "`%s" x 
  method type_var_option f str =
    match str with
    | None -> pp f "_" (* wildcard*)
    | Some {txt;_} -> self#tyvar f txt

          (* c ['a,'b] *)                                                                         
  method class_params_def f =  function
    | [] -> ()
    | l ->
        pp f "[%a] " (* space *)
          (self#list (fun f ({txt;_},s) ->
            pp f "%s%a" (type_variance s) self#tyvar txt) ~sep:",") l 
          
  method type_with_label f (label,({ptyp_desc;_}as c) ) =
    match label with
    | "" ->  self#core_type1 f c (* otherwise parenthesize *)
    | s  ->
        if s.[0]='?' then 
          match ptyp_desc with
          | Ptyp_constr ({txt;_}, l) -> 
              assert (is_predef_option txt);
              pp f "%s:%a" s (self#list self#core_type1) l 
          | _ -> failwith "invalid input in print_type_with_label"
        else pp f "%s:%a" s self#core_type1 c
  method core_type f x =
    match x.ptyp_desc with
    | Ptyp_arrow (l, ct1, ct2) ->
        pp f "@[<2>%a@;->@;%a@]" (* FIXME remove parens later *)
          self#type_with_label (l,ct1) self#core_type ct2
    | Ptyp_alias (ct, s) ->               
        pp f "@[<2>%a@;as@;'%s@]" self#core_type1 ct s
    | Ptyp_poly (sl, ct) ->   
        pp f "@[<2>%a%a@]"
          (fun f l ->
            pp f "%a"
              (fun f l -> match l with
              | [] -> ()
              | _ ->
                  pp f "%a@;.@;"
                    (self#list self#tyvar ~sep:"@;")  l) l) sl  self#core_type ct
    | _ -> pp f "@[<2>%a@]" self#core_type1 x
  method core_type1 f x =
    match x.ptyp_desc with
    | Ptyp_any -> pp f "_";       
    | Ptyp_var s -> self#tyvar f  s; 
    | Ptyp_tuple l ->  pp f "(%a)" (self#list self#core_type1 ~sep:"*@;") l 
    | Ptyp_constr (li, l) ->
        pp f (* "%a%a@;" *) "%a%a"
          (fun f l -> match l with
          |[] -> ()
          |[x]-> pp f "%a@;" self#core_type1  x
          | _ -> self#list ~first:"(" ~last:")@;" self#core_type ~sep:"," f l )  l self#longident_loc li
    | Ptyp_variant (l, closed, low) ->
        let type_variant_helper f x =
          match x with
          | Rtag (l, _, ctl) -> pp f "@[<2>%a%a@]"  self#string_quot l
                (fun f l -> match l with
                |[] -> ()
                | _ -> pp f "@;of@;%a"
                      (self#list self#core_type ~sep:"&")  ctl) ctl
          | Rinherit ct -> self#core_type f ct in 
        pp f "@[<2>[%a%a]@]"
          (fun f l -> match l with
          | [] -> ()
          | _ ->
              pp f "%s@;%a"
                (match (closed,low) with
                | (true,None) -> ""
                | (true,Some _) -> "<" (* FIXME desugar the syntax sugar*)
                | (false,_) -> ">") 
                (self#list type_variant_helper ~sep:"@;<1 -2>| ") l) l 
          (fun f low -> match low with
          |Some [] |None -> ()  
          |Some xs ->
              pp f ">@ %a"
                (self#list self#string_quot) xs) low
    | Ptyp_object l ->
        let  core_field_type f {pfield_desc;_} =
          match pfield_desc with
          | Pfield (s, ct) ->
              pp f "@[<hov2>%s@ :%a@ @]" s self#core_type ct 
          | Pfield_var -> pp f ".." in
        pp f "@[<hov2><@ %a@ >@]" (self#list core_field_type ~sep:";") l
    | Ptyp_class (li, l, low) ->   (*FIXME*)
        pp f "@[<hov2>%a#%a%a@]"
          (self#list self#core_type ~sep:"," ~first:"(" ~last:")") l
          self#longident_loc li
          (fun f low -> match low with
          | [] -> ()
          | _ -> pp f "@ [>@ %a]" (self#list self#string_quot) low) low
    | Ptyp_package (lid, cstrs) ->
        let aux f (s, ct) =
          pp f "type %a@ =@ %a" self#longident_loc s self#core_type ct  in
        (match cstrs with
        |[] -> pp f "@[<hov2>(module@ %a)@]" self#longident_loc lid
        |_ ->  
            pp f "@[<hov2>(module@ %a@ with@ %a)@]" self#longident_loc lid
              (self#list aux  ~sep:"@ and@ ")  cstrs)
    | _ -> self#paren true self#core_type f x
          (********************pattern********************)
          (* be cautious when use [pattern], [pattern1] is preferred *)         
  method pattern f x =
    let rec pattern_or_helper  cur = function
      |{ppat_desc = Ppat_constant (Const_char a);_}
        -> 
          if Char.code a = Char.code cur + 1 then
            Some a
          else None
      |{ppat_desc =
        Ppat_or({ppat_desc=Ppat_constant (Const_char a);_}, p2);_} -> 
          if Char.code a = Char.code cur + 1 then
            pattern_or_helper a p2
          else None
      | _ -> None in
    let rec list_of_pattern acc = function (* only consider ((A|B)|C)*)
      | {ppat_desc= Ppat_or (p1,p2);_} ->
          list_of_pattern  (p2::acc) p1
      | x -> x::acc in
    match x.ppat_desc with
    | Ppat_alias (p, s) -> pp f "@[<2>%a@;as@;%a@]"
          self#pattern p
          (fun f s->
            if is_infix (fixity_of_string s.txt) || List.mem s.txt.[0] prefix_symbols
            then pp f "( %s )" s.txt
            else pp f "%s" s.txt ) s (* RA*)
    | Ppat_or (p1, p2) -> (* *)
        (match p1 with
        | {ppat_desc=Ppat_constant (Const_char a);_} -> begin 
            match pattern_or_helper a p2 with
            |Some b -> pp f "@[<2>%C..%C@]" a b 
            |None ->
                self#list  ~sep:"|" self#pattern f (list_of_pattern [] x) end
        | _ ->
            self#list ~sep:"|" self#pattern f (list_of_pattern [] x) 
        )
    | _ -> self#pattern1 f x
  method pattern1 (f:Format.formatter) (x:pattern) :unit =
    let rec pattern_list_helper f  =  function
      | {ppat_desc =
         Ppat_construct
           ({ txt = Lident("::") ;_},
            Some ({ppat_desc = Ppat_tuple([pat1; pat2]);_}),
            _);_} ->
              pp f "%a::%a"  self#simple_pattern  pat1  pattern_list_helper pat2 (*RA*)
      | p -> self#pattern1 f p in
    match x.ppat_desc with 
    | Ppat_variant (l, Some p) ->  pp f "@[<2>`%s@;%a@]" l self#pattern1 p (*RA*)
    | Ppat_construct (({txt=Lident("()"|"[]");_}), _, _) -> self#simple_pattern f x 
    | Ppat_construct (({txt;_} as li), po, _) -> (* FIXME The third field always false *)
        if txt = Lident "::" then
          pp f "%a" pattern_list_helper x
        else
          (match po with
          |Some x ->
              pp f "%a@;%a"  self#longident_loc li self#simple_pattern x
          | None -> pp f "%a@;"self#longident_loc li )
    | _ -> self#simple_pattern f x 
  method simple_pattern (f:Format.formatter) (x:pattern) :unit = 
    match x.ppat_desc with
    | Ppat_construct (({txt=Lident ("()"|"[]" as x);_}), _, _) -> pp f  "%s" x
    | Ppat_any -> pp f "_";           
    | Ppat_var ({txt = txt;_}) ->
        if (is_infix (fixity_of_string txt)) || List.mem txt.[0] prefix_symbols then
          if txt.[0]='*' then
            pp f "(@;%s@;)@ " txt
          else
            pp f "(%s)" txt 
        else
          pp f "%s" txt
    | Ppat_array l ->
        pp f "@[<2>[|%a|]@]"  (self#list self#pattern1 ~sep:";") l
    | Ppat_unpack (s) ->
        pp f "(module@ %s)@ " s.txt
    | Ppat_type li ->
        pp f "#%a" self#longident_loc li
    | Ppat_record (l, closed) ->
        let longident_x_pattern f (li, p) =
          match (li,p.ppat_desc) with
          | ({txt=Lident s;_ },Ppat_var {txt;_} ) when s = txt ->
              pp f "@[<2>%a@]"  self#longident_loc li 
          | _ -> 
            pp f "@[<2>%a@;=@;%a@]" self#longident_loc li self#pattern1 p in
        (match closed with
        |Closed -> 
            pp f "@[<2>{@;%a@;}@]"
              (self#list longident_x_pattern ~sep:";@;") l
        | _ -> 
            pp f "@[<2>{@;%a;_}@]"
              (self#list longident_x_pattern ~sep:";@;") l)
    | Ppat_tuple l -> pp f "@[<1>(%a)@]" (self#list  ~sep:"," self#pattern1)  l (* level1*)
    | Ppat_constant (c) -> pp f "%a" self#constant c
    | Ppat_variant (l,None) ->  pp f "`%s" l
    | Ppat_constraint (p, ct) ->
        pp f "@[<2>(%a@;:@;%a)@]" self#pattern1 p self#core_type ct
    | Ppat_lazy p ->
        pp f "@[<2>(lazy@;%a)@]" self#pattern1 p 
    | _ -> self#paren true self#pattern f x 

  method label_exp f (l,opt,p) =
    if l = "" then
      pp f "%a@ " self#simple_pattern p (*single case pattern parens needed here *)
    else
      if l.[0] = '?' then 
        let len = String.length l - 1 in 
        let rest = String.sub l 1 len in begin
          match p.ppat_desc with
          | Ppat_var {txt;_} when txt = rest ->
              (match opt with
              |Some o -> pp f "?(%s=@;%a)@;" rest  self#expression o
              | None -> pp f "?%s@ " rest)
          | _ -> (match opt with
            | Some o -> pp f "%s:(%a=@;%a)@;" l self#pattern1 p self#expression o
            | None -> pp f "%s:%a@;" l self#simple_pattern p  )
        end
      else
        (match p.ppat_desc with
        | Ppat_var {txt;_} when txt = l ->
            pp f "~%s@;" l 
        | _ ->  pp f "~%s:%a@;" l self#simple_pattern p )
  method sugar_expr f e =
    match e.pexp_desc with 
    | Pexp_apply
        ({pexp_desc=
          Pexp_ident
            {txt= Ldot (Lident (("Array"|"String") as s),"get");_};_},
         [(_,e1);(_,e2)]) -> begin
              let fmt:(_,_,_)format =
                if s= "Array" then "@[%a.(%a)@]" else "@[%a.[%a]@]" in
              pp f fmt   self#simple_expr e1 self#expression e2;
              true
            end
    |Pexp_apply
        ({pexp_desc=
          Pexp_ident
            {txt= Ldot (Lident (("Array"|"String") as s),
                        "set");_};_},[(_,e1);(_,e2);(_,e3)])
      -> 
        let fmt :(_,_,_) format=
          if s= "Array" then
            "@[%a.(%a)@ <-@;%a@]"
          else
            "@[%a.[%a]@ <-@;%a@]" in  (* @;< gives error here *)
        pp f fmt self#simple_expr e1  self#expression e2  self#expression e3;
        true
    | Pexp_apply ({pexp_desc=Pexp_ident {txt=Lident "!";_};_}, [(_,e)]) -> begin
        pp f "@[<hov>!%a@]" self#simple_expr e;
        true
    end
    | _ -> false
  method expression f x =
    match x.pexp_desc with
    | Pexp_function _ | Pexp_match _ | Pexp_try _ | Pexp_sequence _
      when pipe || semi ->
        self#paren true self#reset#expression f x
    | Pexp_ifthenelse _ | Pexp_sequence _ when ifthenelse ->
        self#paren true self#reset#expression f x
    | Pexp_let _ | Pexp_letmodule _ when semi ->
        self#paren true self#reset#expression f x
    | Pexp_function _(* (p, eo, l) *) ->
        let rec aux acc = function
          | {pexp_desc = Pexp_function (l,eo, [(p',e')]);_}
              -> aux ((l,eo,p')::acc) e'
          | x -> (List.rev acc,x)  in
        begin match aux [] x with
        | [], {pexp_desc=Pexp_function(_label,_eo,l);_} -> (* label should be "" *)
            pp f "@[<hv>function%a@]" self#case_list l
        | ls, {pexp_desc=Pexp_when(e1,e2);_}->
            pp f "@[<2>fun@;%a@;when@;%a@;->@;%a@]"
            (self#list
               (fun f (l,eo,p) ->
                 self#label_exp  f (l,eo,p) )) ls
              self#reset#expression e1 self#expression e2
        | ls, e ->
            pp f "@[<2>fun@;%a@;->@;%a@]"
              (self#list
                 (fun f (l,eo,p) ->
                   self#label_exp f (l,eo,p))) ls
              self#expression e end
    | Pexp_match (e, l) ->
        pp f "@[<hv0>@[<hv0>@[<2>match %a@]@ with@]%a@]" self#reset#expression e self#case_list l 

    | Pexp_try (e, l) ->
        pp f "@[<0>@[<hv2>try@ %a@]@ @[<0>with%a@]@]" (* "try@;@[<2>%a@]@\nwith@\n%a"*)
          self#reset#expression e  self#case_list l 
    | Pexp_let (rf, l, e) ->
        (* pp f "@[<2>let %a%a in@;<1 -2>%a@]" (\*no identation here, a new line*\) *)
        (*   self#rec_flag rf *)
        pp f "@[<2>%a in@;<1 -2>%a@]"
          self#reset#bindings (rf,l)
          self#expression e 
    | Pexp_apply (e, l) ->
        (if not (self#sugar_expr f x) then
          match view_fixity_of_exp e with
          | `Infix s ->
            (match l with
            | [ arg1; arg2 ] ->
                pp f "@[<2>%a@;%s@;%a@]" (* FIXME associativity lable_x_expression_parm*)
                  self#reset#label_x_expression_param  arg1 s  self#label_x_expression_param arg2
            | _ ->
                pp f "@[<2>%a %a@]" self#simple_expr e  (self#list self#label_x_expression_param)  l)
          | `Prefix s ->
              let s =
                if List.mem s ["~+";"~-";"~+.";"~-."] then String.sub s 1 (String.length s -1)
                else s in
            (match l with
            |[v] -> pp f "@[<2>%s@;%a@]" s self#label_x_expression_param v
            | _ -> pp f "@[<2>%s@;%a@]" s (self#list self#label_x_expression_param) l  (*FIXME assert false*)
            )  
          | _ -> 
            pp f "@[<hov2>%a@]" begin fun f (e,l) -> 
              pp f "%a@ %a" self#expression2 e
                (self#list self#reset#label_x_expression_param)  l
               (*reset here only because [function,match,try,sequence] are lower priority*)
            end (e,l))
            
    | Pexp_construct (li, Some eo, _)
      when not (is_simple_construct (view_expr x))-> (* Not efficient FIXME*)
        (match view_expr x with
        | `cons ls -> self#list self#simple_expr f ls ~sep:"@;::@;"
        | `normal ->
            pp f "@[<2>%a@;%a@]" self#longident_loc li
              self#simple_expr  eo
        | _ -> assert false)
    | Pexp_setfield (e1, li, e2) ->
        pp f "@[<2>%a.%a@ <-@ %a@]" self#simple_expr  e1  self#longident_loc li self#expression e2;
    | Pexp_ifthenelse (e1, e2, eo) ->
        (* @;@[<2>else@ %a@]@] *)
        let fmt:(_,_,_)format ="@[<hv0>@[<2>if@ %a@]@;@[<2>then@ %a@]%a@]" in
        pp f fmt  self#under_ifthenelse#expression e1 self#under_ifthenelse#expression e2
          (fun f eo -> match eo with
          | Some x -> pp f "@;@[<2>else@;%a@]" self#under_semi#expression  x
          | None -> () (* pp f "()" *)) eo 
    | Pexp_sequence _ ->
        let rec sequence_helper acc = function
          | {pexp_desc=Pexp_sequence(e1,e2);_} ->
              sequence_helper (e1::acc) e2
          | v -> List.rev (v::acc) in
        let lst = sequence_helper [] x in
        pp f "@[<hv>%a@]"
          (self#list self#under_semi#expression ~sep:";@;") lst
    | Pexp_when (_e1, _e2) ->  assert false (*FIXME handled already in pattern *)
    | Pexp_new (li) ->
        pp f "@[<hov2>new@ %a@]" self#longident_loc li;
    | Pexp_setinstvar (s, e) ->
        pp f "@[<hov2>%s@ <-@ %a@]" s.txt self#expression e
    | Pexp_override l -> (* FIXME *)
        let string_x_expression f (s, e) =
          pp f "@[<hov2>%s@ =@ %a@]" s.txt self#expression e in
        pp f "@[<hov2>{<%a>}@]"
          (self#list string_x_expression  ~sep:";"  )  l;
    | Pexp_letmodule (s, me, e) ->
        pp f "@[<hov2>let@ module@ %s@ =@ %a@ in@ %a@]" s.txt
          self#reset#module_expr me  self#expression e
    | Pexp_assert e ->
        pp f "@[<hov2>assert@ %a@]" self#simple_expr e 
    | Pexp_assertfalse ->
        pp f "@[<2>assert@;false@]" ;
    | Pexp_lazy (e) ->
        pp f "@[<hov2>lazy@ %a@]" self#simple_expr e 
    | Pexp_poly _ -> 
        assert false
    | Pexp_open (lid, e) ->
        pp f "@[<2>let open %a in@;%a@]" self#longident_loc lid
          self#expression  e
    | Pexp_variant (l,Some eo) ->
        pp f "@[<2>`%s@;%a@]" l  self#simple_expr eo
    | _ -> self#expression1 f x
  method expression1 f x =
    match x.pexp_desc with
    | Pexp_object cs -> pp f "%a" self#class_structure cs
    | _ -> self#expression2 f x
  (* used in [Pexp_apply] *)        
  method expression2 f x =
    match x.pexp_desc with
    | Pexp_field (e, li) -> pp f "@[<hov2>%a.%a@]" self#simple_expr e self#longident_loc li
    | Pexp_send (e, s) ->  pp f "@[<hov2>%a#%s@]" self#simple_expr e  s 

    | _ -> self#simple_expr f x 
  method simple_expr f x =
    match x.pexp_desc with
    | Pexp_construct _  when is_simple_construct (view_expr x) ->
        (match view_expr x with
        | `nil -> pp f "[]"
        | `tuple -> pp f "()"
        | `list xs -> pp f "@[<hv0>[%a]@]"  (self#list self#under_semi#expression ~sep:";@;") xs 
        | `simple x -> self#longident f x
        | _ -> assert false)
    | Pexp_ident li ->
        self#longident_loc f li 
        (* (match view_fixity_of_exp x with *)
        (* |`Normal -> self#longident_loc f li *)
        (* | `Prefix _ | `Infix _ -> pp f "( %a )" self#longident_loc li) *)
    | Pexp_constant c -> self#constant f c;
    | Pexp_pack me ->
        pp f "(module@;%a)"  self#module_expr me
    | Pexp_newtype (lid, e) ->
        pp f "fun@;(type@;%s)@;->@;%a"  lid  self#expression  e
    | Pexp_tuple l ->
        pp f "@[<hov2>(%a)@]"  (self#list self#simple_expr  ~sep:",@;")  l
    | Pexp_constraint (e, cto1, cto2) ->
        pp f "(%a%a%a)" self#expression e
          (self#option self#core_type ~first:" : " ~last:" ") cto1 (* no sep hint*)
          (self#option self#core_type ~first:" :>") cto2
    | Pexp_variant (l, None) -> pp f "`%s" l 
    | Pexp_record (l, eo) ->
        let longident_x_expression f ( li, e) =
          match e.pexp_desc with
          |  Pexp_ident {txt;_} when li.txt = txt ->
              pp f "@[<hov2>%a@]" self#longident_loc li
          | _ -> 
              pp f "@[<hov2>%a@;=@;%a@]" self#longident_loc li self#simple_expr e in 
        pp f "@[<hv0>@[<hv2>{@;%a%a@]@;}@]"(* "@[<hov2>{%a%a}@]" *)
          (self#option ~last:" with@;" self#simple_expr) eo
          (self#list longident_x_expression ~sep:";@;")  l
    | Pexp_array (l) ->
        pp f "@[<0>@[<2>[|%a|]@]@]"
          (self#list self#under_semi#simple_expr ~sep:";") l
    | Pexp_while (e1, e2) ->
        let fmt:(_,_,_)format = "@[<2>while@;%a@;do@;%a@;done@]" in 
        pp f fmt self#expression e1 self#expression e2 
    | Pexp_for (s, e1, e2, df, e3) ->
        let fmt:(_,_,_)format =
          "@[<hv0>@[<hv2>@[<2>for %s =@;%a@;%a%a@;do@]@;%a@]@;done@]" in
        pp f fmt s.txt self#expression e1 self#direction_flag df self#expression e2  self#expression e3
    | _ ->  self#paren true self#expression f x 

          
  method value_description f x =
    pp f "@[<hov2>%a%a@]" self#core_type x.pval_type
      (fun f x ->
        if x.pval_prim<>[] then begin
          pp f "@ =@ %a" 
            (self#list self#constant_string)
            x.pval_prim ;
        end) x


  method exception_declaration f (s,ed) =
    pp f "@[<hov2>exception@ %s%a@]" s
      (fun f ed -> match ed with
      |[] -> ()
      |_ -> pp f "@ of@ %a" (self#list ~sep:"*" self#core_type) ed) ed


  method class_signature f { pcsig_self = ct; pcsig_fields = l ;_} =
    let class_type_field f x =
      match x.pctf_desc with
      | Pctf_inher (ct) ->  
          pp f "@[<2>inherit@ %a@]" self#class_type ct 
      | Pctf_val (s, mf, vf, ct) ->
          pp f "@[<2>val @ %a%a%s@ :@ %a@]"
            self#mutable_flag mf self#virtual_flag vf s  self#core_type  ct 
      | Pctf_virt (s, pf, ct) ->    (* todo: test this *)
          pp f "@[<2>method@ %a@ virtual@ %s@ :@ %a@]"
            self#private_flag pf s  self#core_type ct 
      | Pctf_meth (s, pf, ct) ->
          pp f "@[<2>method %a%s :@;%a@]"
            self#private_flag pf s self#core_type ct 
      | Pctf_cstr (ct1, ct2) ->
          pp f "@[<2>constraint@ %a@ =@ %a@]"
            self#core_type ct1 self#core_type ct2 in 
    pp f "@[<hv0>@[<hv2>object @[<1>%a@]@ %a@]@ end@]"
      (fun f ct -> match ct.ptyp_desc with
      | Ptyp_any -> ()
      | _ -> pp f "(%a)" self#core_type ct) ct
      (self#list   class_type_field ~sep:"@;") l  ;

  (* call [class_signature] called by [class_signature] *)  
  method class_type f x =
    match x.pcty_desc with
    | Pcty_signature cs -> self#class_signature f cs;
    | Pcty_constr (li, l) ->
        pp f "%a%a"
          (fun f l -> match l with
          | [] -> ()
          | _  -> pp f "[%a]@ " (self#list self#core_type ~sep:"," ) l) l 
          self#longident_loc li 
    | Pcty_fun (l, co, cl) ->
        pp f "@[<2>%a@;->@;%a@]" (* FIXME remove parens later *)
          self#type_with_label (l,co) self#class_type cl

    
  (* [class type a = object end] *)  
  method class_type_declaration_list f  l =
    let class_type_declaration f ({pci_params=(ls,_);pci_name={dtxt;_};pci_variance;_} as x) =
      pp f "%a%a%s@ =@ %a" self#virtual_flag x.pci_virt
        self#class_params_def (List.combine ls pci_variance) dtxt
        self#class_type x.pci_expr in 
    match l with
    | [] -> () 
    | [h] -> pp f "@[<hv2>class type %a@]" class_type_declaration   h 
    | _ ->
        pp f "@[<2>class type %a@]"
          (self#list class_type_declaration ~sep:"@]@;@[<2>and@;") l 

  method class_field f x =
    match x.pcf_desc with
    | Pcf_inher (ovf, ce, so, com) ->
        pp f "@[<2>inherit@ %s@ %a%a@]"  (override ovf) self#class_expr ce
          (fun f so -> match so with
          | None -> ();
          | Some (s) -> pp f "@ as %s" s ) so 
    | Pcf_val (s, mf, ovf, e) ->
        pp f "@[<2>val%s %a%s =@;%a@]" (override ovf)  self#mutable_flag mf
          s.dtxt  self#expression  e 
    | Pcf_virt (s, pf, ct) ->
        pp f "@[<2>method virtual %a %s :@;%a@]"
          self#private_flag pf s.dtxt self#core_type  ct
    | Pcf_valvirt (s, mf, ct) ->
        pp f "@[<2>val virtual %a%s :@ %a@]"
          self#mutable_flag mf s.dtxt
          self#core_type  ct
    | Pcf_meth (s, pf, ovf, e) ->
        pp f "@[<2>method%s %a%a@]"
          (override ovf)
          self#private_flag pf
          (fun f e -> match e.pexp_desc with
          | Pexp_poly (e, Some ct) ->
              pp f "%s :@;%a=@;%a"
                s.dtxt (self#core_type) ct self#expression e
          | Pexp_poly (e,None) ->
              self#binding f ({ppat_desc=Ppat_var {txt=s.dtxt;loc=s.dloc};ppat_loc=Location.none} ,e)
          | _ ->
              self#expression f e ) e 
    | Pcf_constr (ct1, ct2) ->
        pp f "@[<2>constraint %a =@;%a@]" self#core_type  ct1 self#core_type  ct2
    | Pcf_init (e) ->
        pp f "@[<2>initializer@ %a@]" self#expression e 
    | Pcf_comment _ -> ()

  method class_structure f { pcstr_pat = p; pcstr_fields =  l } =
    pp f "@[<hv0>@[<hv2>object %a@;%a@]@;end@]" 
      (fun f p -> match p.ppat_desc with
      | Ppat_any -> ()
      | Ppat_constraint _ -> pp f "%a"  self#pattern  p
      | _ -> pp f "(%a)" self#pattern p) p 
      (self#list self#class_field ) l 
          
  method class_expr f x =
    match x.pcl_desc with
    | Pcl_structure (cs) ->  self#class_structure f cs ;
    | Pcl_fun (l, eo, p, e) ->
        pp f "fun@ %a@ ->@ %a" self#label_exp (l,eo,p)  self#class_expr e
    | Pcl_let (rf, l, ce) ->
        (* pp f "let@;%a%a@ in@ %a" *)
          pp f "%a@ in@ %a"
          (* self#rec_flag rf *)
          self#bindings  (rf,l)
          self#class_expr ce
    | Pcl_apply (ce, l) ->
        pp f "(%a@ %a)"  self#class_expr ce (self#list self#label_x_expression_param) l 
    | Pcl_constr (li, l) ->
        pp f "%a%a"
          (fun f l-> if l <>[] then 
            pp f "[%a]@ " 
              (self#list self#core_type  ~sep:"," ) l ) l 
          self#longident_loc li
    | Pcl_constraint (ce, ct) ->
        pp f "(%a@ :@ %a)"
          self#class_expr ce
          self#class_type ct
          


  method module_type f x =
    match x.pmty_desc with
    | Pmty_ident li ->
        pp f "%a" self#longident_loc li;
    | Pmty_signature (s) ->
        pp f "@[<hv0>@[<hv2>sig@ %a@]@ end@]" (* "@[<hov>sig@ %a@ end@]" *)
          (self#list self#signature_item  ) s (* FIXME wrong indentation*)
    | Pmty_functor (s, mt1, mt2) ->
        pp f "@[<hov2>functor@ (%s@ :@ %a)@ ->@ %a@]" s.txt
          self#module_type mt1  self#module_type mt2 
    | Pmty_with (mt, l) ->
        let longident_x_with_constraint f (li, wc) =
          match wc with
          | Pwith_type ({ptype_params= ls ;_} as td) ->
              pp f "type@ %a %a =@ %a"
                (self#list self#type_var_option ~sep:"," ~first:"(" ~last:")")
                ls self#longident_loc li  self#type_declaration  td 
          | Pwith_module (li2) ->
              pp f "module %a =@ %a" self#longident_loc li self#longident_loc li2;
          | Pwith_typesubst ({ptype_params=ls;_} as td) ->
              pp f "type@ %a %a :=@ %a"
                (self#list self#type_var_option ~sep:"," ~first:"(" ~last:")")
                ls self#longident_loc li
                self#type_declaration  td 
          | Pwith_modsubst (li2) ->
              pp f "module %a :=@ %a" self#longident_loc li self#longident_loc li2 in
        (match l with
        | [] -> pp f "@[<hov2>%a@]" self#module_type mt 
        | _ -> pp f "@[<hov2>(%a@ with@ %a)@]"
              self#module_type mt (self#list longident_x_with_constraint ~sep:"@ and@ ") l )
    | Pmty_typeof me ->
        pp f "@[<hov2>module@ type@ of@ %a@]"
          self#module_expr me 
  method signature f x =  self#list ~sep:"@\n" self#signature_item f x

  method signature_item f x :unit= begin
    match x.psig_desc with
    | Psig_type l ->
        self#type_def_list f l
    | Psig_value (s, vd) ->
        pp f "@[<2>%a@]"
          (fun f (s,vd) -> 
            let intro = if vd.pval_prim = [] then "val" else "external" in
            if (is_infix (fixity_of_string s.dtxt)) || List.mem s.dtxt.[0] prefix_symbols then
              pp f "%s@ (@ %s@ )@ :@ " intro s.dtxt                
            else
              pp f "%s@ %s@ :@ " intro s.dtxt;
            self#value_description f vd;) (s,vd)
    | Psig_exception (s, ed) ->
        self#exception_declaration f (s.dtxt,ed)
    | Psig_class l ->
        let class_description f ({pci_params=(ls,_);pci_name={dtxt;_};pci_variance;_} as x) =
          pp f "%a%a%s@;:@;%a" (* "@[<2>class %a%a%s@;:@;%a@]" *)
            self#virtual_flag x.pci_virt
            self#class_params_def
            (List.combine ls pci_variance)
            dtxt  self#class_type x.pci_expr in 
        pp f  "@[<0>%a@]"
          (fun f l ->  match l with
            |[]  ->()
            |[x] -> pp f "@[<2>class %a@]" class_description x 
            |_ -> self#list ~first:"@[<v0>class @[<2>" ~sep:"@]@;and @[" ~last:"@]@]"
                  class_description f l) l 
    | Psig_module (s, mt) ->
        pp f "@[<hov>module@ %s@ :@ %a@]"
          s.dtxt
          self#module_type  mt
    | Psig_open li ->
        pp f "@[<hov2>open@ %a@]" self#longident_loc li
    | Psig_include (mt, info) ->
        pp f "@[<hov2>include@ %a@]"
          self#module_type  mt
    | Psig_modtype (s, md) ->
        pp f "@[<hov2>module@ type@ %s%a@]"
          s.dtxt
          (fun f md -> match md with
          | Pmodtype_abstract -> ()
          | Pmodtype_manifest (mt) ->
              pp_print_space f () ;
              pp f "@ =@ %a"  self#module_type mt
          ) md 
    | Psig_class_type (l) ->
        self#class_type_declaration_list f l ;
    | Psig_recmodule decls ->
        let rec  string_x_module_type_list f ?(first=true) l =
          match l with
          | [] -> () ;
          | (s,mty) :: tl ->
              if not first then
                pp f "@ @[<hov2>and@ %s:@ %a@]"
                  s.dtxt self#module_type mty
              else
                pp f "@ @[<hov2>module@ rec@ %s:@ %a@]"
                  s.dtxt self#module_type mty;
              string_x_module_type_list f ~first:false tl  in
        string_x_module_type_list f decls
    | Psig_comment _ -> ()
  end
  method module_expr f x =
    match x.pmod_desc with
    | Pmod_structure (s) ->
        pp f "struct@\n%a@\nend"
          (self#list self#structure_item  ) s;
    | Pmod_constraint (me, mt) ->
        pp f "@[<hov2>(%a@ :@ %a)@]"
          self#module_expr  me
          self#module_type mt
    | Pmod_ident (li) ->
        pp f "%a" self#longident_loc li;
    | Pmod_functor (s, mt, me) ->
        pp f "functor@ (%s@ :@ %a)@;->@;%a"
          s.txt  self#module_type mt  self#module_expr me
    | Pmod_apply (me1, me2) ->
        pp f "%a(%a)" self#module_expr me1  self#module_expr  me2
    | Pmod_unpack e ->
        pp f "(val@ %a)"  self#expression  e

  method structure f x = self#list ~sep:"@\n" self#structure_item f x

  (* transform [f = fun g h -> ..] to [f g h = ... ] could be improved *)    
  method binding f ((p:pattern),(x:expression)) =
    let rec pp_print_pexp_function f x =
      match x.pexp_desc with 
      | Pexp_function (label,eo,[(p,e)]) ->
          if label="" then 
            match e.pexp_desc with
            | Pexp_when _  -> pp f "=@;%a" self#expression x
            | _ -> 
                pp f "%a@ %a" self#simple_pattern p pp_print_pexp_function e
          else
            pp f "%a@ %a" self#label_exp (label,eo,p) pp_print_pexp_function e
      | Pexp_newtype (str,e) ->
          pp f "(type@ %s)@ %a" str pp_print_pexp_function e
      | _ -> pp f "=@;%a" self#expression x in 
    match (x.pexp_desc,p.ppat_desc) with
    | (Pexp_when (e1,e2),_) ->
        pp f "=@[<2>fun@ %a@ when@ %a@ ->@ %a@]"
          self#simple_pattern p self#expression e1 self#expression e2
    | ( _ , Ppat_constraint( p ,ty)) -> (* special case for the first*)
        (match ty.ptyp_desc with
        | Ptyp_poly _ -> 
            pp f "%a@;:@;%a=@;%a" self#simple_pattern p  self#core_type ty self#expression x
        | _ ->
            pp f "(%a@;:%a)=@;%a" self#simple_pattern p  self#core_type ty self#expression x)
    | Pexp_constraint (e,Some t1,None),Ppat_var {txt;_} ->
        pp f "%s:@ %a@;=@;%a" txt self#core_type t1  self#expression e
    | (_, Ppat_var _) ->
        pp f "%a@ %a" self#simple_pattern p pp_print_pexp_function x
    | _ ->
        pp f "%a@;=@;%a" self#pattern p self#expression x 
  (* [in] is not printed *)        
  method bindings f (rf,l) =
    begin match l with
    | [] -> ()
    | [x] -> pp f "@[<2>let %a%a@]" self#rec_flag rf self#binding x 
    | x::xs ->
        (* pp f "@[<hv0>let %a@[<2>%a%a@]" *)
        (* FIXME the indentation is not good see [Insert].ml*)
        pp f "@[<hv0>@[<2>let %a%a%a@]"
          self#rec_flag rf  self#binding x
          (fun f l -> match l with
          | [] -> assert false
          | [x] ->
              pp f
                (* "@]@;and @[<2>%a@]" *)
                "@]@;@[<2>and %a@]"
                self#binding x 
          | xs -> 
              self#list self#binding
                (* ~first:"@]@;and @[<2>" *)
                ~first:"@]@;@[<2>and "
                (* ~sep:"@]@;and @[<2>" *)
                ~sep:"@]@;@[<2>and "
                ~last:"@]" f xs )  xs
    end
      
  method structure_item f x = begin
    match x.pstr_desc with
    | Pstr_eval (e) ->
        pp f "@[<hov2>let@ _ =@ %a@]" self#expression e 
    | Pstr_type [] -> assert false
    | Pstr_type l  -> self#type_def_list f l 
    | Pstr_value (rf, l) -> (* pp f "@[<hov2>let %a%a@]"  self#rec_flag rf self#bindings l *)
        pp f "@[<2>%a@]" self#bindings (rf, List.map fst l)
    | Pstr_exception (s, ed) -> self#exception_declaration f (s.dtxt,ed)
    | Pstr_module (s, me) ->
        let rec module_helper me = match me.pmod_desc with
        | Pmod_functor(s,mt,me) ->
            pp f "(%s:%a)"  s.txt  self#module_type mt ;
            module_helper me
        | _ -> me in 
        pp f "@[<hov2>module %s%a@]"
          s.dtxt
          (fun f me ->
            let me = module_helper me  in
            (match me.pmod_desc with
            | Pmod_constraint
                (me,
                 ({pmty_desc=(Pmty_ident (_)
            | Pmty_signature (_));_} as mt)) ->
                pp f " :@;%a@;=@;%a@;"  self#module_type mt self#module_expr  me 
            | _ ->
                pp f " =@ %a"  self#module_expr  me 
            )) me 
    | Pstr_open (li) ->
        pp f "open %a" self#longident_loc li;
    | Pstr_modtype (s, mt) ->
        pp f "@[<2>module type %s =@;%a@]" s.dtxt self#module_type mt 
    | Pstr_class l ->
        let class_declaration f  (* for the second will be changed to and FIXME*)
            ({pci_params=(ls,_);
              pci_name={dtxt;_};
              pci_virt;
              pci_expr={pcl_desc;_};
              pci_variance;_ } as x) =
          let ls = List.combine ls pci_variance in
          let rec  class_fun_helper f e = match e.pcl_desc with
          | Pcl_fun (l, eo, p, e) ->
              self#label_exp f (l,eo,p);
              class_fun_helper f e
          | _ -> e in
          pp f "%a%a%s %a"  self#virtual_flag pci_virt self#class_params_def ls dtxt 
            (fun f _ ->  
              let ce =
                (match pcl_desc with
                | Pcl_fun _ ->
                    class_fun_helper f x.pci_expr;
                | _ -> x.pci_expr) in
              let ce =
                (match ce.pcl_desc with
                | Pcl_constraint (ce, ct) ->
                    pp f ": @[%a@] " self#class_type  ct ;
                    ce
                | _ -> ce ) in
              pp f "=@;%a" self#class_expr ce ) x in
        (match l with
        | [] -> ()
        | [x] -> pp f "@[<2>class %a@]" class_declaration x
        | xs ->  self#list
              ~first:"@[<v0>class @[<2>"
              ~sep:"@]@;and @["
              ~last:"@]@]" class_declaration f xs)
    | Pstr_class_type (l) ->
        self#class_type_declaration_list f l ;
    | Pstr_primitive (s, vd) ->
        let need_parens =
          match s.dtxt with
          | "or" | "mod" | "land"| "lor" | "lxor" | "lsl" | "lsr" | "asr" -> true
          | _ -> match s.dtxt.[0] with
              'a'..'z' -> false | _ -> true in
        pp f "@[<hov2>external@ %s@ :@ %a@]"
          (if need_parens then "( "^s.dtxt^" )" else s.dtxt)
          self#value_description  vd
    | Pstr_include(me, info) ->
        pp f "@[<hov2>include@ %a@]"  self#module_expr  me 
    | Pstr_exn_rebind (s, li) ->        (* todo: check this *)
        pp f "@[<hov2>exception@ %s@ =@ %a@]" s.dtxt self#longident_loc li 
    | Pstr_comment _ -> ()
    | Pstr_recmodule decls -> (* 3.07 *)
        let text_x_modtype_x_module f (s, mt, me) =
          pp f "@[<hov2>and@ %s:%a@ =@ %a@]"
            s.dtxt self#module_type mt self#module_expr me
        in match decls with
        | (s,mt,me):: l2 ->
            pp f "@[<hv>@[<hov2>module@ rec@ %s:%a@ =@ %a@]@ %a@]"
              s.dtxt
              self#module_type mt
              self#module_expr me 
              (fun f l2 -> List.iter (text_x_modtype_x_module f) l2) l2 
        | _ -> assert false
  end
  method type_param f  = function
    | (a,opt) -> pp f "%s%a" (type_variance a ) self#type_var_option opt 
          (* shared by [Pstr_type,Psig_type]*)    
  method  type_def_list f  l =
    let aux f (s, ({ptype_params;ptype_kind;ptype_manifest;ptype_variance;_} as td )) =
      let ptype_params = List.combine  ptype_variance ptype_params in 
      pp f "%a%s%a"
        (fun f l -> match l with
        |[] -> ()
        | _ ->  pp f "%a@;" (self#list self#type_param ~first:"(" ~last:")" ~sep:",") l)
        ptype_params s.dtxt
        (fun f td ->begin match ptype_kind, ptype_manifest with
        | Ptype_abstract, None -> ()
        | _ , _ -> pp f " =@;" end;
          pp f "%a" self#type_declaration td ) td  in 
    match l with
    | [] -> () ;
    | [x] -> pp f "@[<2>type %a@]" aux x
    | xs -> pp f "@[<v>@[<2>type %a"
          (self#list aux ~sep:"@]@,@[<2>and " ~last:"@]@]") xs 
          (* called by type_def_list *)        
  method type_declaration f x = begin
    let  type_variant_leaf f  (s, l,gadt, _loc, _com)  = match gadt with
    |None -> 
        pp f "@\n|@;%s%a" s.txt
          (fun f l -> match l with
          | [] -> ()
          | _ -> pp f "@;of@;%a" (self#list self#core_type1 ~sep:"*@;") l) l
    |Some x ->
        pp f "@\n|@;%s:@;%a" s.txt
          (self#list self#core_type1 ~sep:"@;->@;") (l@[x]) in
    pp f "%a%a@ %a"
      (fun f x -> match (x.ptype_manifest,x.ptype_kind,x.ptype_private) with
      | (None,_,Public) ->  pp f "@;"
      | (None,_,Private) -> pp f "private@;"
      | (Some y, Ptype_abstract,Private) -> 
          pp f "private@;%a" self#core_type y;
      | (Some y, _, Private) -> 
          pp f "%a = private@;" self#core_type y 
      | (Some y,Ptype_abstract, Public) ->  self#core_type f y;
      | (Some y, _,Public) -> begin
          pp f "%a =@;" self#core_type y (* manifest types*)
      end) x 
      (fun f x -> match x.ptype_kind with
        (*here only normal variant types allowed here*)
      | Ptype_variant xs -> 
          pp f "%a"
            (self#list ~sep:"" type_variant_leaf) xs
      | Ptype_abstract -> ()
      | Ptype_record l ->
          let type_record_field f (s, mf, ct, _, _) =
            pp f "@[<2>%a%s:@;%a@]" self#mutable_flag mf s.txt self#core_type ct in
          pp f "{@\n%a}"
            (self#list type_record_field ~sep:";@\n" )  l ;
      ) x
      (self#list
         (fun f (ct1,ct2,_) ->
           pp f "@[<hov2>constraint@ %a@ =@ %a@]"
             self#core_type ct1 self#core_type ct2 ))  x.ptype_cstrs  ;
  end
  method case_list f (l:(pattern * expression) list) :unit=
    let aux f (p,e) =
      let (e,w) =
        (match e with
        | {pexp_desc = Pexp_when (e1, e2);_} -> (e2, Some (e1))
        | _ -> (e, None)) in
      pp f "@;| @[<2>%a%a@;->@;%a@]"
        self#pattern p (self#option self#expression ~first:"@;when@;") w self#under_pipe#expression e in
    self#list aux f l ~sep:""
  method label_x_expression_param f (l,e) =
    match l with
    | ""  -> self#expression2 f e ; (* level 2*)
    | lbl ->
        let simple_name = match e.pexp_desc with
        | Pexp_ident {txt=Lident l;_} -> Some l
        | _ -> None in 
        if  lbl.[0] = '?' then
          let str = String.sub lbl 1 (String.length lbl-1) in
          if Some str = simple_name then
            pp f "%s" lbl
          else
            pp f "%s:%a" lbl self#simple_expr e 
        else
          if Some lbl = simple_name then
            pp f "~%s" lbl 
          else 
            pp f "~%s:%a" lbl self#simple_expr e
              
  method directive_argument f x =
    (match x with
    | Pdir_none -> ()
    | Pdir_string (s) -> pp f "@ %S" s
    | Pdir_int (i) -> pp f "@ %d" i
    | Pdir_ident (li) -> pp f "@ %a" self#longident li
    | Pdir_bool (b) -> pp f "@ %s" (string_of_bool b))

  method toplevel_phrase f x =
    match x with
    | Ptop_def (s) ->
        pp_open_hvbox f 0;
        self#list self#structure_item f s ;
        pp_close_box f ();
    | Ptop_dir (s, da) ->
        pp f "@[<hov2>#%s@ %a@]" s self#directive_argument da 
end;;


let default = new printer ()


let toplevel_phrase f x =
  match x with
  | Ptop_def (s) ->pp f "@[<hov0>%a@]"  (default#list default#structure_item) s 
   (* pp_open_hvbox f 0; *)
   (* pp_print_list structure_item f s ; *)
   (* pp_close_box f (); *)
  | Ptop_dir (s, da) ->
   pp f "@[<hov2>#%s@ %a@]" s default#directive_argument da 
   (* pp f "@[<hov2>#%s@ %a@]" s directive_argument da *)

let expression f x =
  pp f "@[%a@]" default#expression x


let string_of_expression x =
  ignore (flush_str_formatter ()) ;
  let f = str_formatter in
  default#expression f x ;
  flush_str_formatter () ;;
let string_of_structure x =
  ignore (flush_str_formatter ());
  let f = str_formatter in
  default#structure f x;
  flush_str_formatter ();;

let top_phrase f x =
  pp_print_newline f () ;
  toplevel_phrase f x;
  pp f ";;" ;
  pp_print_newline f ();;

let core_type=default#core_type
let pattern=default#pattern
let signature=default#signature
let structure=default#structure   
