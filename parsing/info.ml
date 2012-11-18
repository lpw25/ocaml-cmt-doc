(***********************************************************************)
(*                                                                     *)
(*                             OCamldoc                                *)
(*                                                                     *)
(*            Maxence Guesdon, projet Cristal, INRIA Rocquencourt      *)
(*                                                                     *)
(*  Copyright 2001 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

type ref_kind =
    RK_module
  | RK_module_type
  | RK_class
  | RK_class_type
  | RK_value
  | RK_type
  | RK_exception
  | RK_attribute
  | RK_method
  | RK_section of text
  | RK_recfield
  | RK_const

and text_element =
  | Raw of string
  | Code of string
  | CodePre of string
  | Verbatim of string
  | Bold of text
  | Italic of text
  | Emphasize of text
  | Center of text
  | Left of text
  | Right of text
  | List of text list
  | Enum of text list
  | Newline
  | Block of text
  | Title of int * string option * text
  | Latex of string
  | Link of string * text
  | Ref of string * ref_kind option * text option
  | Superscript of text
  | Subscript of text
  | Module_list of string list
  | Index_list
  | Custom of string * text
  | Target of string * string

and text = text_element list

type see_ref =
    See_url of string
  | See_file of string
  | See_doc of string

type see = see_ref * text

type param = (string * text)

type raised_exception = (string * text)

type doc_info = {
    i_desc : text option;
    i_authors : string list;
    i_version : string option;
    i_sees : see list;
    i_since : string option;
    i_before : (string * text) list;
    i_deprecated : text option;
    i_params : param list;
    i_raised_exceptions : raised_exception list;
    i_return_value : text option ;
    i_custom : (string * text) list ;
  }

let dummy_info = {
  i_desc = None ;
  i_authors = [] ;
  i_version = None ;
  i_sees = [] ;
  i_since = None ;
  i_before = [] ;
  i_deprecated = None ;
  i_params = [] ;
  i_raised_exceptions = [] ;
  i_return_value = None ;
  i_custom = [] ;
}

type comment = text option

type info = doc_info option

type 'a doc =
  { dtxt: 'a;
    dloc: Location.t;
    info: info; }

let mkdoc txt loc info = { dtxt = txt; dloc = loc; info }
