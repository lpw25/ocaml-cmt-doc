#(***********************************************************************)
#(*                                                                     *)
#(*                             OCamldoc                                *)
#(*                                                                     *)
#(*            Maxence Guesdon, projet Cristal, INRIA Rocquencourt      *)
#(*                                                                     *)
#(*  Copyright 2001 Institut National de Recherche en Informatique et   *)
#(*  en Automatique.  All rights reserved.  This file is distributed    *)
#(*  under the terms of the Q Public License version 1.0.               *)
#(*                                                                     *)
#(***********************************************************************)

include ../config/Makefile

# Various commands and dir
##########################
CAMLRUN=../boot/ocamlrun
OCAMLC   = ../ocamlcomp.sh
OCAMLOPT = ../ocamlcompopt.sh
OCAMLDEP = $(CAMLRUN) ../tools/ocamldep
OCAMLLEX = $(CAMLRUN) ../boot/ocamllex
OCAMLYACC= ../boot/ocamlyacc
OCAMLLIB = $(LIBDIR)
OCAMLBIN = $(BINDIR)

OCAMLPP=-pp './remove_DEBUG'

# For installation
##############
MKDIR=mkdir -p
CP=cp -f
OCAMLDOC=ocamldoc
OCAMLDOC_RUN=sh ./runocamldoc $(SUPPORTS_SHARED_LIBRARIES)
OCAMLDOC_OPT=$(OCAMLDOC).opt
OCAMLDOC_LIBCMA=odoc_info.cma
OCAMLDOC_LIBCMI=odoc_info.cmi
OCAMLDOC_LIBCMXA=odoc_info.cmxa
OCAMLDOC_LIBA=odoc_info.$(A)
INSTALL_LIBDIR=$(OCAMLLIB)/ocamldoc
INSTALL_CUSTOMDIR=$(INSTALL_LIBDIR)/custom
INSTALL_BINDIR=$(OCAMLBIN)
INSTALL_MANODIR=$(MANDIR)/man3

INSTALL_MLIS=odoc_info.mli
INSTALL_CMIS=$(INSTALL_MLIS:.mli=.cmi)

ODOC_TEST=odoc_test.cmo

GENERATORS_CMOS= \
	generators/odoc_todo.cmo \
	generators/odoc_literate.cmo
true = $(GENERATORS_CMOS:.cmo=.cmxs)
false =
GENERATORS_CMXS := $($(NATDYNLINK))


# Compilation
#############
OCAMLSRCDIR=..
INCLUDES_DEP=-I $(OCAMLSRCDIR)/parsing \
	-I $(OCAMLSRCDIR)/utils \
	-I $(OCAMLSRCDIR)/typing \
	-I $(OCAMLSRCDIR)/driver \
	-I $(OCAMLSRCDIR)/bytecomp \
	-I $(OCAMLSRCDIR)/tools \
	-I $(OCAMLSRCDIR)/toplevel/

INCLUDES_NODEP=	-I $(OCAMLSRCDIR)/stdlib \
	-I $(OCAMLSRCDIR)/otherlibs/str \
	-I $(OCAMLSRCDIR)/otherlibs/dynlink \
	-I $(OCAMLSRCDIR)/otherlibs/unix \
	-I $(OCAMLSRCDIR)/otherlibs/num \
	-I $(OCAMLSRCDIR)/otherlibs/graph

INCLUDES=$(INCLUDES_DEP) $(INCLUDES_NODEP)

COMPFLAGS=$(INCLUDES) -warn-error A
LINKFLAGS=$(INCLUDES) -nostdlib

CMOFILES= odoc_config.cmo \
	odoc_messages.cmo\
	odoc_global.cmo\
	odoc_types.cmo\
	odoc_misc.cmo\
	odoc_text_parser.cmo\
	odoc_text_lexer.cmo\
	odoc_text.cmo\
	odoc_name.cmo\
	odoc_parameter.cmo\
	odoc_value.cmo\
	odoc_type.cmo\
	odoc_exception.cmo\
	odoc_class.cmo\
	odoc_module.cmo\
	odoc_print.cmo \
	odoc_str.cmo\
	odoc_comments_global.cmo\
	odoc_parser.cmo\
	odoc_lexer.cmo\
	odoc_see_lexer.cmo\
	odoc_env.cmo\
	odoc_merge.cmo\
	odoc_sig.cmo\
	odoc_ast.cmo\
	odoc_control.cmo\
	odoc_inherit.cmo\
	odoc_search.cmo\
	odoc_scan.cmo\
	odoc_cross.cmo\
	odoc_comments.cmo\
	odoc_dep.cmo\
	odoc_analyse.cmo\
	odoc_info.cmo


CMXFILES= $(CMOFILES:.cmo=.cmx)
CMIFILES= $(CMOFILES:.cmo=.cmi)

EXECMOFILES=$(CMOFILES) \
	odoc_dag2html.cmo \
	odoc_to_text.cmo \
	odoc_ocamlhtml.cmo \
	odoc_html.cmo \
	odoc_man.cmo \
	odoc_latex_style.cmo \
	odoc_latex.cmo \
	odoc_texi.cmo \
	odoc_dot.cmo \
	odoc_gen.cmo \
	odoc_args.cmo \
	odoc.cmo

EXECMXFILES= $(EXECMOFILES:.cmo=.cmx)
EXECMIFILES= $(EXECMOFILES:.cmo=.cmi)

LIBCMOFILES=$(CMOFILES)
LIBCMXFILES= $(LIBCMOFILES:.cmo=.cmx)
LIBCMIFILES= $(LIBCMOFILES:.cmo=.cmi)

# Les cmo et cmx de la distrib OCAML
OCAMLCMOFILES=$(OCAMLSRCDIR)/parsing/printast.cmo \
	$(OCAMLSRCDIR)/typing/ident.cmo \
	$(OCAMLSRCDIR)/utils/tbl.cmo \
	$(OCAMLSRCDIR)/utils/misc.cmo \
	$(OCAMLSRCDIR)/utils/config.cmo \
	$(OCAMLSRCDIR)/utils/clflags.cmo \
	$(OCAMLSRCDIR)/utils/warnings.cmo \
	$(OCAMLSRCDIR)/utils/ccomp.cmo \
	$(OCAMLSRCDIR)/utils/consistbl.cmo \
	$(OCAMLSRCDIR)/parsing/location.cmo\
	$(OCAMLSRCDIR)/parsing/info.cmo\
	$(OCAMLSRCDIR)/parsing/longident.cmo \
	$(OCAMLSRCDIR)/parsing/syntaxerr.cmo \
	$(OCAMLSRCDIR)/parsing/parser.cmo \
	$(OCAMLSRCDIR)/parsing/lexer.cmo \
	$(OCAMLSRCDIR)/parsing/parse.cmo \
	$(OCAMLSRCDIR)/typing/types.cmo \
	$(OCAMLSRCDIR)/typing/path.cmo \
	$(OCAMLSRCDIR)/typing/btype.cmo \
	$(OCAMLSRCDIR)/typing/predef.cmo \
	$(OCAMLSRCDIR)/typing/datarepr.cmo \
	$(OCAMLSRCDIR)/typing/subst.cmo \
	$(OCAMLSRCDIR)/typing/cmi_format.cmo \
	$(OCAMLSRCDIR)/typing/env.cmo \
	$(OCAMLSRCDIR)/typing/ctype.cmo \
	$(OCAMLSRCDIR)/typing/primitive.cmo \
	$(OCAMLSRCDIR)/typing/oprint.cmo \
	$(OCAMLSRCDIR)/typing/printtyp.cmo \
	$(OCAMLSRCDIR)/typing/includecore.cmo \
	$(OCAMLSRCDIR)/typing/typetexp.cmo \
	$(OCAMLSRCDIR)/typing/typedtree.cmo \
	$(OCAMLSRCDIR)/typing/parmatch.cmo \
	$(OCAMLSRCDIR)/typing/stypes.cmo \
	$(OCAMLSRCDIR)/typing/typedtreeMap.cmo \
	$(OCAMLSRCDIR)/typing/cmt_format.cmo \
	$(OCAMLSRCDIR)/typing/typecore.cmo \
	$(OCAMLSRCDIR)/typing/includeclass.cmo \
	$(OCAMLSRCDIR)/typing/typedecl.cmo \
	$(OCAMLSRCDIR)/typing/typeclass.cmo \
	$(OCAMLSRCDIR)/typing/mtype.cmo \
	$(OCAMLSRCDIR)/typing/includemod.cmo \
	$(OCAMLSRCDIR)/typing/typemod.cmo \
	$(OCAMLSRCDIR)/bytecomp/lambda.cmo \
	$(OCAMLSRCDIR)/bytecomp/typeopt.cmo \
	$(OCAMLSRCDIR)/bytecomp/printlambda.cmo \
	$(OCAMLSRCDIR)/bytecomp/switch.cmo \
	$(OCAMLSRCDIR)/bytecomp/matching.cmo \
	$(OCAMLSRCDIR)/bytecomp/translobj.cmo \
	$(OCAMLSRCDIR)/bytecomp/translcore.cmo \
	$(OCAMLSRCDIR)/bytecomp/translclass.cmo \
	$(OCAMLSRCDIR)/tools/depend.cmo \
	$(OCAMLSRCDIR)/driver/pparse.cmo

OCAMLCMXFILES=$(OCAMLCMOFILES:.cmo=.cmx)

STDLIB_MLIS=../stdlib/*.mli \
	../otherlibs/unix/unix.mli \
	../otherlibs/str/str.mli \
	../otherlibs/bigarray/bigarray.mli \
	../otherlibs/num/num.mli

all: exe lib generators manpages

exe: $(OCAMLDOC)
lib: $(OCAMLDOC_LIBCMA) $(OCAMLDOC_LIBCMI) $(ODOC_TEST)
generators: $(GENERATORS_CMOS)

opt.opt: exeopt libopt generatorsopt
exeopt: $(OCAMLDOC_OPT)
libopt: $(OCAMLDOC_LIBCMXA) $(OCAMLDOC_LIBCMI)
generatorsopt: $(GENERATORS_CMXS)

debug:
	$(MAKE) OCAMLPP=""

$(OCAMLDOC): $(EXECMOFILES)
	$(OCAMLC) -o $@ -linkall unix.cma str.cma dynlink.cma $(LINKFLAGS) $(OCAMLCMOFILES) $(EXECMOFILES)
$(OCAMLDOC_OPT): $(EXECMXFILES)
	$(OCAMLOPT) -o $@ -linkall unix.cmxa str.cmxa dynlink.cmxa $(LINKFLAGS) $(OCAMLCMXFILES) $(EXECMXFILES)

$(OCAMLDOC_LIBCMA): $(LIBCMOFILES)
	$(OCAMLC) -a -o $@ $(LINKFLAGS) $(OCAMLSRCDIR)/tools/depend.cmo $(LIBCMOFILES)
$(OCAMLDOC_LIBCMXA): $(LIBCMXFILES)
	$(OCAMLOPT) -a -o $@ $(LINKFLAGS)	$(OCAMLSRCDIR)/tools/depend.cmx $(LIBCMXFILES)

manpages: stdlib_man/Pervasives.3o

dot: $(EXECMOFILES)
	$(OCAMLDOC_RUN) -dot -dot-reduce -o ocamldoc.dot $(INCLUDES) \
	odoc*.ml

# Parsers and lexers dependencies :
###################################
odoc_text_parser.ml: odoc_text_parser.mly
odoc_text_parser.mli: odoc_text_parser.mly

odoc_parser.ml:	odoc_parser.mly
odoc_parser.mli:odoc_parser.mly

odoc_text_lexer.ml: odoc_text_lexer.mll

odoc_lexer.ml:odoc_lexer.mll

odoc_ocamlhtml.ml: odoc_ocamlhtml.mll

odoc_see_lexer.ml: odoc_see_lexer.mll


# generic rules :
#################

.SUFFIXES: .mll .mly .ml .mli .cmo .cmi .cmx .cmxs

.ml.cmo:
	$(OCAMLC) $(OCAMLPP) $(COMPFLAGS) -c $<

.mli.cmi:
	$(OCAMLC) $(OCAMLPP) $(COMPFLAGS) -c $<

.ml.cmx:
	$(OCAMLOPT) $(OCAMLPP) $(COMPFLAGS) -c $<

.ml.cmxs:
	$(OCAMLOPT) -shared -o $@ $(OCAMLPP) $(COMPFLAGS) $<

.mll.ml:
	$(OCAMLLEX) $<

.mly.ml:
	$(OCAMLYACC) -v $<

.mly.mli:
	$(OCAMLYACC) -v $<

# Installation targets
######################
install: dummy
	if test -d $(INSTALL_BINDIR); then : ; else $(MKDIR) $(INSTALL_BINDIR); fi
	if test -d $(INSTALL_LIBDIR); then : ; else $(MKDIR) $(INSTALL_LIBDIR); fi
	if test -d $(INSTALL_CUSTOMDIR); then : ; else $(MKDIR) $(INSTALL_CUSTOMDIR); fi
	$(CP) $(OCAMLDOC) $(INSTALL_BINDIR)/$(OCAMLDOC)$(EXE)
	$(CP) ocamldoc.hva *.cmi $(OCAMLDOC_LIBCMA) $(INSTALL_LIBDIR)
	$(CP) $(INSTALL_MLIS) $(INSTALL_CMIS) $(INSTALL_LIBDIR)
	if test -d $(INSTALL_MANODIR); then : ; else $(MKDIR) $(INSTALL_MANODIR); fi
	if test -d stdlib_man; then $(CP) stdlib_man/* $(INSTALL_MANODIR); else : ; fi

installopt:
	if test -f $(OCAMLDOC_OPT) ; then $(MAKE) installopt_really ; fi

installopt_really:
	if test -d $(INSTALL_BINDIR); then : ; else $(MKDIR) $(INSTALL_BINDIR); fi
	if test -d $(INSTALL_LIBDIR); then : ; else $(MKDIR) $(INSTALL_LIBDIR); fi
	$(CP) $(OCAMLDOC_OPT) $(INSTALL_BINDIR)/$(OCAMLDOC_OPT)$(EXE)
	$(CP) ocamldoc.hva $(OCAMLDOC_LIBA) $(OCAMLDOC_LIBCMXA) $(INSTALL_LIBDIR)
	$(CP) $(INSTALL_MLIS) $(INSTALL_CMIS) $(INSTALL_LIBDIR)

# Testing :
###########
test: dummy
	$(MKDIR) $@
	$(OCAMLDOC_RUN) -html -colorize-code -sort -d $@ $(INCLUDES) -dump $@/ocamldoc.odoc odoc*.ml odoc*.mli -v
	$(MKDIR) $@-custom
	$(OCAMLDOC_RUN) -colorize-code -sort -d $@-custom $(INCLUDES) \
	-g generators/odoc_literate.cmo -g generators/odoc_todo.cmo \
	-load $@/ocamldoc.odoc -v

test_stdlib: dummy
	$(MKDIR) $@
	$(OCAMLDOC_RUN) -html -colorize-code -sort -d $@ $(INCLUDES) -dump $@/stdlib.odoc -keep-code \
	../stdlib/pervasives.ml ../stdlib/*.mli \
	../otherlibs/unix/unix.mli \
	../otherlibs/str/str.mli

test_stdlib_code: dummy
	$(MKDIR) $@
	$(OCAMLDOC_RUN) -html -colorize-code -sort -d $@ $(INCLUDES) -dump $@/stdlib.odoc -keep-code \
	`ls ../stdlib/*.ml | grep -v Labels` \
	../otherlibs/unix/unix.ml \
	../otherlibs/str/str.ml

test_framed: dummy
	$(MKDIR) $@
	$(OCAMLDOC_RUN) -g odoc_fhtml.cmo -sort -colorize-code -d $@ $(INCLUDES) odoc*.ml odoc*.mli

test_latex: dummy
	$(MKDIR) $@
	$(OCAMLDOC_RUN) -latex -sort -o $@/test.tex -d $@ $(INCLUDES) odoc*.ml odoc*.mli test2.txt ../stdlib/*.mli ../otherlibs/unix/unix.mli

test_latex_simple: dummy
	$(MKDIR) $@
	$(OCAMLDOC_RUN) -latex -sort -o $@/test.tex -d $@ $(INCLUDES) \
	-latextitle 6,subsection -latextitle 7,subsubection \
	../stdlib/hashtbl.mli \
	../stdlib/arg.mli \
	../otherlibs/unix/unix.mli \
	../stdlib/map.mli

test_man: dummy
	$(MKDIR) $@
	$(OCAMLDOC_RUN) -man -sort -d $@ $(INCLUDES) odoc*.ml odoc*.mli

test_texi: dummy
	$(MKDIR) $@
	$(OCAMLDOC_RUN) -texi -sort -d $@ $(INCLUDES) odoc*.ml odoc*.mli

stdlib_man/Pervasives.3o: $(STDLIB_MLIS)
	$(MKDIR) stdlib_man
	$(OCAMLDOC_RUN) -man -d stdlib_man $(INCLUDES) \
	-t "OCaml library" -man-mini \
	$(STDLIB_MLIS)

autotest_stdlib: dummy
	$(MKDIR) $@
	$(OCAMLDOC_RUN) -g autotest/odoc_test.cmo\
	$(INCLUDES) -keep-code \
	../stdlib/pervasives.ml ../stdlib/*.mli \
	../otherlibs/unix/unix.mli \
	../otherlibs/str/str.mli

# backup, clean and depend :
############################

clean:: dummy
	@rm -f *~ \#*\#
	@rm -f $(OCAMLDOC) $(OCAMLDOC_OPT) *.cma *.cmxa *.cmo *.cmi *.cmx *.$(A) *.$(O)
	@rm -f odoc_parser.output odoc_text_parser.output
	@rm -f odoc_lexer.ml odoc_text_lexer.ml odoc_see_lexer.ml odoc_ocamlhtml.ml
	@rm -f odoc_parser.ml odoc_parser.mli odoc_text_parser.ml odoc_text_parser.mli
	@rm -rf stdlib_man
	@rm -f generators/*.cm[aiox] generators/*.$(A) generators/*.$(O) generators/*.cmx[as]

depend::
	$(OCAMLYACC) odoc_text_parser.mly
	$(OCAMLYACC) odoc_parser.mly
	$(OCAMLLEX) odoc_text_lexer.mll
	$(OCAMLLEX) odoc_lexer.mll
	$(OCAMLLEX) odoc_ocamlhtml.mll
	$(OCAMLLEX) odoc_see_lexer.mll
	$(OCAMLDEP) $(INCLUDES_DEP) *.mll *.mly *.ml *.mli > .depend

dummy:

include .depend
