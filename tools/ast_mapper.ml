(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*                        Alain Frisch, LexiFi                         *)
(*                                                                     *)
(*  Copyright 2012 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

(* A generic Parsetree mapping class *)

open Location
open Config
open Parsetree
open Asttypes

(* First, some helpers to build AST fragments *)

let map_flatten f l = List.flatten (List.map f l)
let map_snd f (x, y) = (x, f y)
let map_tuple f1 f2 (x, y) = (f1 x, f2 y)
let map_opt f = function None -> None | Some x -> Some (f x)

module T = struct
  (* Type expressions for the core language *)

  let mk ?(loc = Location.none) x = {ptyp_desc = x; ptyp_loc = loc}
  let any ?loc () = mk ?loc Ptyp_any
  let var ?loc a = mk ?loc (Ptyp_var a)
  let arrow ?loc a b c = mk ?loc (Ptyp_arrow (a, b, c))
  let tuple ?loc a = mk ?loc (Ptyp_tuple a)
  let constr ?loc a b = mk ?loc (Ptyp_constr (a, b))
  let object_ ?loc a = mk ?loc (Ptyp_object a)
  let class_ ?loc a b c = mk ?loc (Ptyp_class (a, b, c))
  let alias ?loc a b = mk ?loc (Ptyp_alias (a, b))
  let variant ?loc a b c = mk ?loc (Ptyp_variant (a, b, c))
  let poly ?loc a b = mk ?loc (Ptyp_poly (a, b))
  let package ?loc a b = mk ?loc (Ptyp_package (a, b))

  let field_type ?(loc = Location.none) x = {pfield_desc = x; pfield_loc = loc}
  let field ?loc s t =
    let t =
      (* The type-checker expects the field to be a Ptyp_poly. Maybe
         it should wrap the type automatically... *)
      match t.ptyp_desc with
      | Ptyp_poly _ -> t
      | _ -> poly ?loc [] t
    in
    field_type ?loc (Pfield (s, t))
  let field_var ?loc () = field_type ?loc Pfield_var

  let core_field_type sub = function
    | {pfield_desc = Pfield (s, d); pfield_loc = loc} -> field ~loc s (sub # typ d)
    | x -> x

  let row_field sub = function
    | Rtag (l, b, tl) -> Rtag (l, b, List.map (sub # typ) tl)
    | Rinherit t -> Rinherit (sub # typ t)

  let map sub {ptyp_desc = desc; ptyp_loc = loc} =
    match desc with
    | Ptyp_any -> any ~loc ()
    | Ptyp_var s -> var ~loc s
    | Ptyp_arrow (lab, t1, t2) -> arrow ~loc lab (sub # typ t1) (sub # typ t2)
    | Ptyp_tuple tyl -> tuple ~loc (List.map (sub # typ) tyl)
    | Ptyp_constr (lid, tl) -> constr ~loc lid (List.map (sub # typ) tl)
    | Ptyp_object l -> object_ ~loc (List.map (core_field_type sub) l)
    | Ptyp_class (lid, tl, ll) -> class_ ~loc lid (List.map (sub # typ) tl) ll
    | Ptyp_alias (t, s) -> alias ~loc (sub # typ t) s
    | Ptyp_variant (rl, b, ll) -> variant ~loc (List.map (row_field sub) rl) b ll
    | Ptyp_poly (sl, t) -> poly ~loc sl (sub # typ t)
    | Ptyp_package (lid, l) -> package ~loc lid (List.map (map_snd (sub # typ)) l)

  let map_type_declaration sub td =
    {td with
     ptype_cstrs =
     List.map
       (fun (ct1, ct2, loc) -> sub # typ ct1, sub # typ ct2, loc)
       td.ptype_cstrs;
     ptype_kind = sub # type_kind td.ptype_kind;
     ptype_manifest = map_opt (sub # typ) td.ptype_manifest;
    }

  let map_type_kind sub = function
    | Ptype_abstract -> Ptype_abstract
    | Ptype_variant l -> Ptype_variant (List.map (fun (s, tl, t, loc, com) -> (s, List.map (sub # typ) tl, map_opt (sub # typ) t, loc, com)) l)
    | Ptype_record l -> Ptype_record (List.map (fun (s, flags, t, loc, com) -> (s, flags, sub # typ t, loc, com)) l)
end

module CT = struct
  (* Type expressions for the class language *)

  let mk ?(loc = Location.none) x = {pcty_loc = loc; pcty_desc = x}

  let constr ?loc a b = mk ?loc (Pcty_constr (a, b))
  let signature ?loc a = mk ?loc (Pcty_signature a)
  let fun_ ?loc a b c = mk ?loc (Pcty_fun (a, b, c))

  let map sub {pcty_loc = loc; pcty_desc = desc} =
    match desc with
    | Pcty_constr (lid, tys) -> constr ~loc lid (List.map (sub # typ) tys)
    | Pcty_signature x -> signature ~loc (sub # class_signature x)
    | Pcty_fun (lab, t, ct) ->
        fun_ ~loc lab
          (sub # typ t)
          (sub # class_type ct)

  let mk_field ?(loc = Location.none) x = {pctf_desc = x; pctf_loc = loc}

  let inher ?loc a = mk_field ?loc (Pctf_inher a)
  let val_ ?loc a b c d = mk_field ?loc (Pctf_val (a, b, c, d))
  let virt ?loc a b c = mk_field ?loc (Pctf_virt (a, b, c))
  let meth ?loc a b c = mk_field ?loc (Pctf_meth (a, b, c))
  let cstr ?loc a b = mk_field ?loc (Pctf_cstr (a, b))

  let map_field sub {pctf_desc = desc; pctf_loc = loc} =
    match desc with
    | Pctf_inher ct -> inher ~loc (sub # class_type ct)
    | Pctf_val (s, m, v, t) -> val_ ~loc s m v (sub # typ t)
    | Pctf_virt (s, p, t) -> virt ~loc s p (sub # typ t)
    | Pctf_meth (s, p, t) -> meth ~loc s p (sub # typ t)
    | Pctf_cstr (t1, t2) -> cstr ~loc (sub # typ t1) (sub # typ t2)

  let map_signature sub {pcsig_self; pcsig_fields; pcsig_loc} =
    {
     pcsig_self = sub # typ pcsig_self;
     pcsig_fields = List.map (sub # class_type_field) pcsig_fields;
     pcsig_loc;
    }
end

module MT = struct
  (* Type expressions for the module language *)

  let mk ?(loc = Location.none) x = {pmty_desc = x; pmty_loc = loc}
  let ident ?loc a = mk ?loc (Pmty_ident a)
  let signature ?loc a = mk ?loc (Pmty_signature a)
  let functor_ ?loc a b c = mk ?loc (Pmty_functor (a, b, c))
  let with_ ?loc a b = mk ?loc (Pmty_with (a, b))
  let typeof_ ?loc a = mk ?loc (Pmty_typeof a)

  let map sub {pmty_desc = desc; pmty_loc = loc} =
    match desc with
    | Pmty_ident s -> ident ~loc s
    | Pmty_signature sg -> signature ~loc (sub # signature sg)
    | Pmty_functor (s, mt1, mt2) -> functor_ ~loc s (sub # module_type mt1) (sub # module_type mt2)
    | Pmty_with (mt, l) -> with_ ~loc (sub # module_type mt) (List.map (map_snd (sub # with_constraint)) l)
    | Pmty_typeof me -> typeof_ ~loc (sub # module_expr me)

  let map_with_constraint sub = function
    | Pwith_type d -> Pwith_type (sub # type_declaration d)
    | Pwith_module s -> Pwith_module s
    | Pwith_typesubst d -> Pwith_typesubst (sub # type_declaration d)
    | Pwith_modsubst s -> Pwith_modsubst s

  let mk_item ?(loc = Location.none) x = {psig_desc = x; psig_loc = loc}

  let value ?loc a b = mk_item ?loc (Psig_value (a, b))
  let type_ ?loc a = mk_item ?loc (Psig_type a)
  let exception_ ?loc a b = mk_item ?loc (Psig_exception (a, b))
  let module_ ?loc a b = mk_item ?loc (Psig_module (a, b))
  let rec_module ?loc a = mk_item ?loc (Psig_recmodule a)
  let modtype ?loc a b = mk_item ?loc (Psig_modtype (a, b))
  let open_ ?loc a = mk_item ?loc (Psig_open a)
  let include_ ?loc a b = mk_item ?loc (Psig_include (a, b))
  let class_ ?loc a = mk_item ?loc (Psig_class a)
  let class_type ?loc a = mk_item ?loc (Psig_class_type a)
  let comment ?loc a = mk_item ?loc (Psig_comment a)

  let map_signature_item sub {psig_desc = desc; psig_loc = loc} =
    match desc with
    | Psig_value (s, vd) -> value ~loc s (sub # value_description vd)
    | Psig_type l -> type_ ~loc (List.map (map_snd (sub # type_declaration)) l)
    | Psig_exception (s, ed) -> exception_ ~loc s (sub # exception_declaration ed)
    | Psig_module (s, mt) -> module_ ~loc s (sub # module_type mt)
    | Psig_recmodule l -> rec_module ~loc (List.map (map_snd (sub # module_type)) l)
    | Psig_modtype (s, Pmodtype_manifest mt) -> modtype ~loc s (Pmodtype_manifest  (sub # module_type mt))
    | Psig_modtype (s, Pmodtype_abstract) -> modtype ~loc s Pmodtype_abstract
    | Psig_open s -> open_ ~loc s
    | Psig_include (mt, i) -> include_ ~loc (sub # module_type mt) i
    | Psig_class l -> class_ ~loc (List.map (sub # class_description) l)
    | Psig_class_type l -> class_type ~loc (List.map (sub # class_type_declaration) l)
    | Psig_comment c -> comment ~loc c

end


module M = struct
  (* Value expressions for the module language *)

  let mk ?(loc = Location.none) x = {pmod_desc = x; pmod_loc = loc}
  let ident ?loc x = mk ?loc (Pmod_ident x)
  let structure ?loc x = mk ?loc (Pmod_structure x)
  let functor_ ?loc arg arg_ty body = mk ?loc (Pmod_functor (arg, arg_ty, body))
  let apply ?loc m1 m2 = mk ?loc (Pmod_apply (m1, m2))
  let constraint_ ?loc m mty = mk ?loc (Pmod_constraint (m, mty))
  let unpack ?loc e = mk ?loc (Pmod_unpack e)

  let map sub {pmod_loc = loc; pmod_desc = desc} =
    match desc with
    | Pmod_ident x -> ident ~loc x
    | Pmod_structure str -> structure ~loc (sub # structure str)
    | Pmod_functor (arg, arg_ty, body) -> functor_ ~loc arg (sub # module_type arg_ty) (sub # module_expr body)
    | Pmod_apply (m1, m2) -> apply ~loc (sub # module_expr m1) (sub # module_expr m2)
    | Pmod_constraint (m, mty) -> constraint_ ~loc (sub # module_expr m) (sub # module_type mty)
    | Pmod_unpack e -> unpack ~loc (sub # expr e)

  let mk_item ?(loc = Location.none) x = {pstr_desc = x; pstr_loc = loc}
  let eval ?loc a = mk_item ?loc (Pstr_eval a)
  let value ?loc a b = mk_item ?loc (Pstr_value (a, b))
  let primitive ?loc a b = mk_item ?loc (Pstr_primitive (a, b))
  let type_ ?loc a = mk_item ?loc (Pstr_type a)
  let exception_ ?loc a b = mk_item ?loc (Pstr_exception (a, b))
  let exn_rebind ?loc a b = mk_item ?loc (Pstr_exn_rebind (a, b))
  let module_ ?loc a b = mk_item ?loc (Pstr_module (a, b))
  let rec_module ?loc a = mk_item ?loc (Pstr_recmodule a)
  let modtype ?loc a b = mk_item ?loc (Pstr_modtype (a, b))
  let open_ ?loc a = mk_item ?loc (Pstr_open a)
  let class_ ?loc a = mk_item ?loc (Pstr_class a)
  let class_type ?loc a = mk_item ?loc (Pstr_class_type a)
  let include_ ?loc a b = mk_item ?loc (Pstr_include (a, b))
  let comment ?loc a = mk_item ?loc (Pstr_comment a)

  let map_structure_item sub {pstr_loc = loc; pstr_desc = desc} =
    match desc with
    | Pstr_eval x -> eval ~loc (sub # expr x)
    | Pstr_value (r, pel) -> value ~loc r (List.map (fun ((p,e),i) -> (((sub # pat p), (sub # expr e)), i)) pel)
    | Pstr_primitive (name, vd) -> primitive ~loc name (sub # value_description vd)
    | Pstr_type l -> type_ ~loc (List.map (fun (s, d) -> (s, sub # type_declaration d)) l)
    | Pstr_exception (name, ed) -> exception_ ~loc name (sub # exception_declaration ed)
    | Pstr_exn_rebind (s, lid) -> exn_rebind ~loc s lid
    | Pstr_module (s, m) -> module_ ~loc s (sub # module_expr m)
    | Pstr_recmodule l -> rec_module ~loc (List.map (fun (s, mty, me) -> (s, sub # module_type mty, sub # module_expr me)) l)
    | Pstr_modtype (s, mty) -> modtype ~loc s (sub # module_type mty)
    | Pstr_open lid -> open_ ~loc lid
    | Pstr_class l -> class_ ~loc (List.map (sub # class_declaration) l)
    | Pstr_class_type l -> class_type ~loc (List.map (sub # class_type_declaration) l)
    | Pstr_include (e, i) -> include_ ~loc (sub # module_expr e) i
    | Pstr_comment c -> comment ~loc c
end

module E = struct
  (* Value expressions for the core language *)

  let mk ?(loc = Location.none) x = {pexp_desc = x; pexp_loc = loc}

  let ident ?loc a = mk ?loc (Pexp_ident a)
  let constant ?loc a = mk ?loc (Pexp_constant a)
  let let_ ?loc a b c = mk ?loc (Pexp_let (a, b, c))
  let function_ ?loc a b c = mk ?loc (Pexp_function (a, b, c))
  let apply ?loc a b = mk ?loc (Pexp_apply (a, b))
  let match_ ?loc a b = mk ?loc (Pexp_match (a, b))
  let try_ ?loc a b = mk ?loc (Pexp_try (a, b))
  let tuple ?loc a = mk ?loc (Pexp_tuple a)
  let construct ?loc a b c = mk ?loc (Pexp_construct (a, b, c))
  let variant ?loc a b = mk ?loc (Pexp_variant (a, b))
  let record ?loc a b = mk ?loc (Pexp_record (a, b))
  let field ?loc a b = mk ?loc (Pexp_field (a, b))
  let setfield ?loc a b c = mk ?loc (Pexp_setfield (a, b, c))
  let array ?loc a = mk ?loc (Pexp_array a)
  let ifthenelse ?loc a b c = mk ?loc (Pexp_ifthenelse (a, b, c))
  let sequence ?loc a b = mk ?loc (Pexp_sequence (a, b))
  let while_ ?loc a b = mk ?loc (Pexp_while (a, b))
  let for_ ?loc a b c d e = mk ?loc (Pexp_for (a, b, c, d, e))
  let constraint_ ?loc a b c = mk ?loc (Pexp_constraint (a, b, c))
  let when_ ?loc a b = mk ?loc (Pexp_when (a, b))
  let send ?loc a b = mk ?loc (Pexp_send (a, b))
  let new_ ?loc a = mk ?loc (Pexp_new a)
  let setinstvar ?loc a b = mk ?loc (Pexp_setinstvar (a, b))
  let override ?loc a = mk ?loc (Pexp_override a)
  let letmodule ?loc (a, b, c)= mk ?loc (Pexp_letmodule (a, b, c))
  let assert_ ?loc a = mk ?loc (Pexp_assert a)
  let assertfalse ?loc () = mk ?loc Pexp_assertfalse
  let lazy_ ?loc a = mk ?loc (Pexp_lazy a)
  let poly ?loc a b = mk ?loc (Pexp_poly (a, b))
  let object_ ?loc a = mk ?loc (Pexp_object a)
  let newtype ?loc a b = mk ?loc (Pexp_newtype (a, b))
  let pack ?loc a = mk ?loc (Pexp_pack a)
  let open_ ?loc a b = mk ?loc (Pexp_open (a, b))

  let lid ?(loc = Location.none) lid = ident ~loc (mkloc (Longident.parse lid) loc)
  let apply_nolabs ?loc f el = apply ?loc f (List.map (fun e -> ("", e)) el)
  let strconst ?loc x = constant ?loc (Const_string x)

  let map sub {pexp_loc = loc; pexp_desc = desc} =
    match desc with
    | Pexp_ident x -> ident ~loc x
    | Pexp_constant x -> constant ~loc x
    | Pexp_let (r, pel, e) -> let_ ~loc r (List.map (map_tuple (sub # pat) (sub # expr)) pel) (sub # expr e)
    | Pexp_function (lab, def, pel) -> function_ ~loc lab (map_opt (sub # expr) def) (List.map (map_tuple (sub # pat) (sub # expr)) pel)
    | Pexp_apply (e, l) -> apply ~loc (sub # expr e) (List.map (map_snd (sub # expr)) l)
    | Pexp_match (e, l) -> match_ ~loc (sub # expr e) (List.map (map_tuple (sub # pat) (sub # expr)) l)
    | Pexp_try (e, l) -> try_ ~loc (sub # expr e) (List.map (map_tuple (sub # pat) (sub # expr)) l)
    | Pexp_tuple el -> tuple ~loc (List.map (sub # expr) el)
    | Pexp_construct (lid, arg, b) -> construct ~loc lid (map_opt (sub # expr) arg) b
    | Pexp_variant (lab, eo) -> variant ~loc lab (map_opt (sub # expr) eo)
    | Pexp_record (l, eo) -> record ~loc (List.map (fun (id, e) -> (id, sub # expr e)) l) (map_opt (sub # expr) eo)
    | Pexp_field (e, lid) -> field ~loc (sub # expr e) lid
    | Pexp_setfield (e1, lid, e2) -> setfield ~loc (sub # expr e1) lid (sub # expr e2)
    | Pexp_array el -> array ~loc (List.map (sub # expr) el)
    | Pexp_ifthenelse (e1, e2, e3) -> ifthenelse ~loc (sub # expr e1) (sub # expr e2) (map_opt (sub # expr) e3)
    | Pexp_sequence (e1, e2) -> sequence ~loc (sub # expr e1) (sub # expr e2)
    | Pexp_while (e1, e2) -> while_ ~loc (sub # expr e1) (sub # expr e2)
    | Pexp_for (id, e1, e2, d, e3) -> for_ ~loc id (sub # expr e1) (sub # expr e2) d (sub # expr e3)
    | Pexp_constraint (e, t1, t2) -> constraint_ ~loc (sub # expr e) (map_opt (sub # typ) t1) (map_opt (sub # typ) t2)
    | Pexp_when (e1, e2) -> when_ ~loc (sub # expr e1) (sub # expr e2)
    | Pexp_send (e, s) -> send ~loc (sub # expr e) s
    | Pexp_new lid -> new_ ~loc lid
    | Pexp_setinstvar (s, e) -> setinstvar ~loc s (sub # expr e)
    | Pexp_override sel -> override ~loc (List.map (map_snd (sub # expr)) sel)
    | Pexp_letmodule (s, me, e) -> letmodule ~loc (s, sub # module_expr me, sub # expr e)
    | Pexp_assert e -> assert_ ~loc (sub # expr e)
    | Pexp_assertfalse -> assertfalse ~loc ()
    | Pexp_lazy e -> lazy_ ~loc (sub # expr e)
    | Pexp_poly (e, t) -> poly ~loc (sub # expr e) (map_opt (sub # typ) t)
    | Pexp_object cls -> object_ ~loc (sub # class_structure cls)
    | Pexp_newtype (s, e) -> newtype ~loc s (sub # expr e)
    | Pexp_pack me -> pack ~loc (sub # module_expr me)
    | Pexp_open (lid, e) -> open_ ~loc lid (sub # expr e)
end

module P = struct
  (* Patterns *)

  let mk ?(loc = Location.none) x = {ppat_desc = x; ppat_loc = loc}
  let any ?loc () = mk ?loc Ppat_any
  let var ?loc a = mk ?loc (Ppat_var a)
  let alias ?loc a b = mk ?loc (Ppat_alias (a, b))
  let constant ?loc a = mk ?loc (Ppat_constant a)
  let tuple ?loc a = mk ?loc (Ppat_tuple a)
  let construct ?loc a b c = mk ?loc (Ppat_construct (a, b, c))
  let variant ?loc a b = mk ?loc (Ppat_variant (a, b))
  let record ?loc a b = mk ?loc (Ppat_record (a, b))
  let array ?loc a = mk ?loc (Ppat_array a)
  let or_ ?loc a b = mk ?loc (Ppat_or (a, b))
  let constraint_ ?loc a b = mk ?loc (Ppat_constraint (a, b))
  let type_ ?loc a = mk ?loc (Ppat_type a)
  let lazy_ ?loc a = mk ?loc (Ppat_lazy a)
  let unpack ?loc a = mk ?loc (Ppat_unpack a)

  let map sub {ppat_desc = desc; ppat_loc = loc} =
    match desc with
    | Ppat_any -> any ~loc ()
    | Ppat_var s -> var ~loc s
    | Ppat_alias (p, s) -> alias ~loc (sub # pat p) s
    | Ppat_constant c -> constant ~loc c
    | Ppat_tuple pl -> tuple ~loc (List.map (sub # pat) pl)
    | Ppat_construct (l, p, b) -> construct ~loc l (map_opt (sub # pat) p) b
    | Ppat_variant (l, p) -> variant ~loc l (map_opt (sub # pat) p)
    | Ppat_record (lpl, cf) ->
        (*record ~loc (List.map (map_snd (sub # pat)) lpl) cf*)
        record ~loc
          (List.map (fun (s, p) -> (s, sub # pat p)) lpl) cf
    | Ppat_array pl -> array ~loc (List.map (sub # pat) pl)
    | Ppat_or (p1, p2) -> or_ ~loc (sub # pat p1) (sub # pat p2)
    | Ppat_constraint (p, t) -> constraint_ ~loc (sub # pat p) (sub # typ t)
    | Ppat_type s -> type_ ~loc s
    | Ppat_lazy p -> lazy_ ~loc (sub # pat p)
    | Ppat_unpack s -> unpack ~loc s
end

module CE = struct
  (* Value expressions for the class language *)

  let mk ?(loc = Location.none) x = {pcl_loc = loc; pcl_desc = x}

  let constr ?loc a b = mk ?loc (Pcl_constr (a, b))
  let structure ?loc a = mk ?loc (Pcl_structure a)
  let fun_ ?loc a b c d = mk ?loc (Pcl_fun (a, b, c, d))
  let apply ?loc a b = mk ?loc (Pcl_apply (a, b))
  let let_ ?loc a b c = mk ?loc (Pcl_let (a, b, c))
  let constraint_ ?loc a b = mk ?loc (Pcl_constraint (a, b))

  let map sub {pcl_loc = loc; pcl_desc = desc} =
    match desc with
    | Pcl_constr (lid, tys) -> constr ~loc lid (List.map (sub # typ) tys)
    | Pcl_structure s ->
        structure ~loc (sub # class_structure s)
    | Pcl_fun (lab, e, p, ce) ->
        fun_ ~loc lab
          (map_opt (sub # expr) e)
          (sub # pat p)
          (sub # class_expr ce)
    | Pcl_apply (ce, l) ->
        apply ~loc (sub # class_expr ce) (List.map (map_snd (sub # expr)) l)
    | Pcl_let (r, pel, ce) ->
        let_ ~loc r
          (List.map (map_tuple (sub # pat) (sub # expr)) pel)
          (sub # class_expr ce)
    | Pcl_constraint (ce, ct) ->
        constraint_ ~loc (sub # class_expr ce) (sub # class_type ct)


  let mk_field ?(loc = Location.none) x = {pcf_desc = x; pcf_loc = loc}

  let inher ?loc a b c d = mk_field ?loc (Pcf_inher (a, b, c, d))
  let valvirt ?loc a b c = mk_field ?loc (Pcf_valvirt (a, b, c))
  let val_ ?loc a b c d = mk_field ?loc (Pcf_val (a, b, c, d))
  let virt ?loc a b c = mk_field ?loc (Pcf_virt (a, b, c))
  let meth ?loc a b c d = mk_field ?loc (Pcf_meth (a, b, c, d))
  let constr ?loc a b = mk_field ?loc (Pcf_constr (a, b))
  let init ?loc a = mk_field ?loc (Pcf_init a)
  let comment ?loc a = mk_field ?loc (Pcf_comment a)

  let map_field sub {pcf_desc = desc; pcf_loc = loc} =
    match desc with
    | Pcf_inher (o, ce, s, c) -> inher ~loc o (sub # class_expr ce) s c
    | Pcf_valvirt (s, m, t) -> valvirt ~loc s m (sub # typ t)
    | Pcf_val (s, m, o, e) -> val_ ~loc s m o (sub # expr e)
    | Pcf_virt (s, p, t) -> virt ~loc s p (sub # typ t)
    | Pcf_meth (s, p, o, e) -> meth ~loc s p o (sub # expr e)
    | Pcf_constr (t1, t2) -> constr ~loc (sub # typ t1) (sub # typ t2)
    | Pcf_init e -> init ~loc (sub # expr e)
    | Pcf_comment c -> comment ~loc c

  let map_structure sub {pcstr_pat; pcstr_fields} =
    {
     pcstr_pat = sub # pat pcstr_pat;
     pcstr_fields = List.map (sub # class_field) pcstr_fields;
    }
end

(* Now, a generic AST mapper class, to be extended to cover all kinds
   and cases of the OCaml grammar.  The default behavior of the mapper
   is the identity. *)

class create =
  object(this)
    method run fn_in fn_out =
      let ic = open_in_bin fn_in in
      let magic = String.create (String.length ast_impl_magic_number) in
      really_input ic magic 0 (String.length magic);
      if magic <> ast_impl_magic_number && magic <> ast_intf_magic_number then
        failwith "Bad magic";
      let input_name = input_value ic in
      let ast = input_value ic in
      close_in ic;

      let (input_name, ast) =
        if magic = ast_impl_magic_number
        then Obj.magic (this # implementation input_name (Obj.magic ast))
        else Obj.magic (this # interface input_name (Obj.magic ast))
      in
      let oc = open_out_bin fn_out in
      output_string oc magic;
      output_value oc input_name;
      output_value oc ast;
      close_out oc

    method main =
      try
        if Array.length Sys.argv > 2 then
          this # run Sys.argv.(1) Sys.argv.(2)
        else begin
          Printf.eprintf "Usage: %s <infile> <outfile>" Sys.executable_name;
          exit 1
        end
      with exn ->
        prerr_endline (Printexc.to_string exn);
        exit 2

    method implementation (input_name : string) ast = (input_name, this # structure ast)
    method interface (input_name: string) ast = (input_name, this # signature ast)
    method structure l = map_flatten (this # structure_item) l
    method structure_item si = [ M.map_structure_item this si ]
    method module_expr = M.map this

    method signature l = map_flatten (this # signature_item) l
    method signature_item si = [ MT.map_signature_item this si ]
    method module_type = MT.map this
    method with_constraint c = MT.map_with_constraint this c

    method class_declaration decl = {decl with pci_expr = this # class_expr decl.pci_expr}
    method class_expr = CE.map this
    method class_field = CE.map_field this
    method class_structure = CE.map_structure this

    method class_type = CT.map this
    method class_type_field = CT.map_field this
    method class_signature = CT.map_signature this

    method class_type_declaration decl = {decl with pci_expr = this # class_type decl.pci_expr}
    method class_description decl = {decl with pci_expr = this # class_type decl.pci_expr}

    method type_declaration = T.map_type_declaration this
    method type_kind = T.map_type_kind this
    method typ = T.map this

    method value_description vd = {vd with pval_type = this # typ vd.pval_type}
    method pat = P.map this
    method expr = E.map this

    method exception_declaration tl = List.map (this # typ) tl
  end


let set_loc loc = object
  inherit create as super

  method! expr x =
    if x.pexp_loc.loc_ghost then
      super # expr {x with pexp_loc = loc}
    else
      x

  method! typ x =
    if x.ptyp_loc.loc_ghost then
      super # typ {x with ptyp_loc = loc}
    else
      x

  method! pat x =
    if x.ppat_loc.loc_ghost then
      super # pat {x with ppat_loc = loc}
    else
      x
end
