/* ------------------------------------------------------------------------
@NAME       : bibtex.g
@DESCRIPTION: PCCTS-based lexer and parser for BibTeX files.  (Or rather,
              for the BibTeX data description language.  This parser
              enforces nothing about the structure and contents of
              entries; that's up to higher-level processors.  Thus, there's
              nothing either particularly bibliographic or TeXish about
              the language accepted by this parser, apart from the affinity
              for curly braces.)

              There are a few minor differences from the language accepted
              by BibTeX itself, but these are generally improvements over
              BibTeX's behaviour.  See the comments in the grammar, at least
              until I write a decent description of the language.

              I have used Gerd Neugebauer's BibTool (yet another BibTeX
              parser, along with a prettyprinter and specialized language
              for a common set of bibhacks) as another check of correctness
              -- there are a few screwball things that BibTeX accepts and
              BibTool doesn't, so I felt justified in rejecting them as
              well.  In general, this parser is a little stricter than
              BibTeX, but a little looser than BibTool.  YMMV.

              Another source of inspiration is Nelson Beebe's bibclean, or
              rather Beebe's article describing bibclean (from TUGboat
              vol. 14 no. 4; also included with the bibclean distribution).

              The product of the parser is an abstract syntax tree that can
              be traversed to be printed in a simple form (see
              print_entry() in bibparse.c) or perhaps transformed to a
              format more convenient for higher-level languages (see my
              Text::BibTeX Perl module for an example).

              Whole files may be parsed by entering the parser at `bibfile';
              in this case, the parser really returns a forest (list of
              ASTs, one per entry).  Alternately, you can enter the parser
              at `entry', which reads and parses a single entry.
@GLOBALS    : the usual DLG and ANTLR cruft
@CALLS      : 
@CREATED    : first attempt: May 1996, Greg Ward
              second attempt (complete rewrite): July 25-28 1996, Greg Ward
@MODIFIED   : Sep 1996, GPW: changed to generate an AST rather than print
                             out each entry as it's encountered
              Jan 1997, GPW: redid the above, because it was lost when
                             my !%&$#!@ computer was stolen
              Jun 1997, GPW: greatly simplified the lexer, and added handling
                             of %-comments, @comment and @preamble entries,
                             and proper scanning of between-entry junk
@VERSION    : $Id: bibtex.g 640 1999-11-29 01:13:10Z greg $
@COPYRIGHT  : Copyright (c) 1996-99 by Gregory P. Ward.  All rights reserved.

              This file is part of the btparse library.  This library is
              free software; you can redistribute it and/or modify it under
              the terms of the GNU Library General Public License as
              published by the Free Software Foundation; either version 2
              of the License, or (at your option) any later version.
-------------------------------------------------------------------------- */

#header
<<
#define ZZCOL
#define USER_ZZSYN

#include "config.h"
#include "btparse.h"
#include "attrib.h"
#include "lex_auxiliary.h"
#include "error.h"
#include "my_dmalloc.h"

extern char * InputFilename;            /* for zzcr_ast call in pccts/ast.c */
>>

/*
 * The lexer has three modes -- START (between entries, hence it's what
 * we're in initially), LEX_ENTRY (entered once we see an '@' at
 * top-level), and LEX_STRING (for scanning quoted strings).  Note that all
 * the functions called from lexer actions can be found in lex_auxiliary.c.
 *
 * The START mode just looks for '@', discards comments and whitespace,
 * counts lines, and keeps track of any other junk.  The "keeping track"
 * just consists of counting the number of junk characters, which is then
 * reported at the next '@' sign.  This will hopefully let users clean up
 * "old style" implicit comments, and possibly catch some legitimate errors
 * in their files (eg. a complete entry that's missing an '@').
 */

#token AT           "\@"            << at_sign (); >>
#token              "\n"            << newline (); >>
#token COMMENT      "\%~[\n]*\n"    << comment (); >>
#token              "[\ \r\t]+"     << zzskip (); >>
#token              "~[\@\n\ \r\t]+"<< toplevel_junk (); >>

#lexclass LEX_ENTRY

/*
 * The LEX_ENTRY mode is where most of the interesting stuff is -- these
 * tokens control most of the syntax of BibTeX.  First, we duplicate most
 * of the START lexer, in order to handle newlines, comments, and
 * whitespace.
 *
 * Next comes a "number", which is trivial.  This is needed because a
 * BibTeX simple value may be an unquoted digit string; it has to precede
 * the definition of "name" tokens, because otherwise a digit string would
 * be a legitimate "name", which would cause an ambiguity inside entries
 * ("is this a macro or a number?")
 * 
 * Then comes the regexp for a BibTeX "name", which is used for entry
 * types, entry keys, field names, and macro names.  This is basically the
 * same as BibTeX's definition of such "names", with two differences.  The
 * key, fundamental difference is that I have defined names by inclusion
 * rather than exclusion: this regex lists all characters allowed in a
 * type/key/field name/macro name, rather than listing those characters not
 * allowed (as the BibTeX documentation does).  The trivial difference is
 * that I have disallowed a few extra characters: @ \ ~.  Allowing @ could
 * cause confusing BibTeX syntax, and allowing \ or ~ can cause bogus TeX
 * code: try putting "\cite{foo\bar}" in your LaTeX document and see what
 * happens!  I'm also rather skeptical about some of the more exotic
 * punctuation characters being allowed, but since people have been using
 * BibTeX's definition of "names" for a decade or so now, I guess we're
 * stuck with it.  I could always amend name() to warn about any exotic
 * punctuation that offends me, but that should be an option -- and I don't
 * have a mechanism for user selectable warnings yet, so it'll have to
 * wait.
 * 
 * Also note that defining "number" ahead of "name" precludes a string of
 * digits from being a name.  This is usually a good thing; we don't want
 * to accept digit strings as article types or field names (BibTeX
 * doesn't).  However -- dubious as it may seem -- digit strings are
 * legitimate entry keys, so we should accept them there.  This is handled
 * by the grammar; see the `contents' rule below.
 * 
 * Finally, it should be noted that BibTeX does not seem to apply the same
 * lexical rules to entry types, entry keys, and field names -- so perhaps
 * doing so here is not such a great idea.  One immediate manifestation of
 * this is that my grammar in its unassisted state would accept a field
 * name with leading digits; BibTeX doesn't accept this.  I correct this
 * with the check_field_name() function, called from the `field' rule in
 * the grammar and defined in parse_auxiliary.c.
 */
#token              "\n"            << newline (); >>
#token COMMENT      "\%~[\n]*\n"    << comment (); >>
#token              "[\ \r\t]+"     << zzskip (); >>
#token NUMBER       "[0-9]+"
#token NAME         "[a-z0-9\!\$\&\*\+\-\.\/\:\;\<\>\?\[\]\^\_\`\|]+"
                                    << name (); >>

/* 
 * Now come the (apparently) easy tokens, i.e. punctuation.  There are a
 * number of tricky bits here, though.  First, '{' can have two very
 * different meanings: at top-level, it's an entry delimiter, and inside an
 * entry it's a string delimiter.  This is handled (in lbrace()) by keeping
 * track of the "entry state" (top-level, after '@', after type, in
 * comment, or in entry) and using that to determine what to do on a '{'.
 * If we're in an entry, lbrace() will switch to the string lexer by
 * calling start_string(); if we're immediately after an entry type token
 * (which is just a name following a top-level '@'), then we force the
 * current token to ENTRY_OPEN, so that '{' and '(' appear identical to the
 * parser.  (This works because the scanner generated by DLG just happens
 * to assign the token number first, and then executes the action.)
 * Anywhere else (ie. at top level or immediately after an '@', we print a
 * warning and leave the token as LBRACE, which will cause a syntax error
 * (because LBRACE is not used anywhere in the grammar).
 *
 * '(' has some similarities to '{', but it's different enough that it 
 * has its own function.  In particular, it may be an entry opener just 
 * like '{', but in one particular case it may be a string opener.  That
 * particular case is where it follows '@' and 'comment'; in that case,
 * lparen() will call start_string() to enter the string lexer.
 *
 * The other delimiter characters are easier, but still warrant an
 * explanation.  '}' should only occur inside an entry, and if found there
 * the token is forced to ENTRY_CLOSER; anywhere else, a warning is printed
 * and the parser should find a syntax error.  ')' should only occur inside
 * an entry, and likewise will trigger a warning if seen elsewhere.
 * (String-closing '}' and ')' are handled by the string lexer, below.)
 *
 * The other punctuation characters are trivial.  Note that a double quote
 * can start a string anywhere (except at top-level!), but if it occurs in
 * a weird place a syntax error will eventually occur.
 */
#token LBRACE       "\{"            << lbrace (); >>
#token RBRACE       "\}"            << rbrace (); >>
#token ENTRY_OPEN   "\("            << lparen (); >>
#token ENTRY_CLOSE  "\)"            << rparen (); >>
#token EQUALS       "="
#token HASH         "\#"
#token COMMA        ","
#token              "\""            << start_string ('"'); >>


#lexclass LEX_STRING

/*
 * Here's a reasonably decent attempt at lexing BibTeX strings.  There are
 * a couple of sneaky tricks going on here that aren't strictly necessary,
 * but can make the user's life a lot easier.
 *
 * First, here's what a simple and straightforward BibTeX string lexer 
 * would do:
 *   - keep track of brace-depth by incrementing/decrementing a counter
 *     whenever it sees `{' or `}'
 *   - if the string was started with a `{' and it sees a `}' which
 *     brings the brace-depth to 0, end the string
 *   - if the string was started with a `"' and it sees another `"' at
 *     brace-depth 0, end the string
 *   - any other characters are left untouched and become part of the
 *     string
 *
 * (Note that the simple act of counting braces makes this lexer
 * non-regular -- there's a bit more going on here than you might
 * think from reading the regexps.  So sue me.)
 *
 * The first, most obvious refinement to this is to check for newlines
 * and other whitespace -- we should convert either one to a single
 * space (to simplify future processing), as well as increment zzline on
 * newline.  Note that we don't do any collapsing of whitespace yet --
 * newlines surrounded by spaces make that rather tricky to handle
 * properly in the lexer (because newlines are handled separately, in
 * order to increment zzline), so I put it off to a later stage.  (That
 * also gives us the flexibility to collapse whitespace or not,
 * according to the user's whim.)
 * 
 * A PCCTS lexer to handle these requirements would look something like this:
 * 
 * #token     "\n"             << newline_in_string (); >>
 * #token     "[\r\t]"         << zzreplchar (' '); zzmore (); >>
 * #token     "\{"             << open_brace(); >>
 * #token     "\}"             << close_brace(); >>
 * #token     "\""             << quote_in_string (); >>
 * #token     "~[\n\{\}\"]+"   << zzmore (); >>
 *
 * where the functions called are the same as currently in lex_auxiliary.c.
 * 
 * However, I've added some trickery here that lets us heuristically detect
 * runaway strings.  The heuristic is as follows: anytime we have a newline
 * in a string, that's reason to suspect a runaway.  We follow up on this
 * suspicion by slurping everything that could reasonably be part of the
 * string and still be in the same line (i.e., a string of anything except
 * newline, braces, parentheses, double-quote, and backslash), and then
 * calling check_runaway_string().  This function then "backs up" to the
 * beginning of the slurped string (the newline), and scans ahead looking
 * for one of two patterns: "@name[{(]", or "name=" (with optional
 * whitespace between the "tokens").  (Actually, it first makes a pass over
 * the string to convert all whitespace characters -- including the sole
 * newline -- to spaces.  So, it's effectively looking for "\ *\@\ *NAME\
 * *[\{\(]" (DLG regexp syntax) or "\ *NAME\ *=", where
 * NAME="[a-z][a-z0-9+/:'.-]*" -- that is, something that looks like the
 * start of an entry or a new field, but in a string (where they almost
 * certainly shouldn't occur).  Of course, there are no explicit regexps
 * there -- it's all coded as a little hand-crafted automaton in C.
 *
 * At any rate, if either one of these patterns is matched,
 * check_runaway_string() prints a warning and sets a flag so that we don't
 * print that warning -- or indeed, even scan for the suspect patterns --
 * more than once for the current string.  (Because chances are if it
 * occurs once, it'll occur again and again and again.)
 *
 * There is also some trickery going on to deal with '@comment' entries.
 * Syntactically, these are just AT NAME STRING, where NAME must be
 * 'comment'.  This means that an '@comment' entry has no delimiters, it
 * just has a string.  To make them look a bit more like the other kinds of
 * entries (which are delimited with '{' ... '}' or '(' ... ')', the STRING
 * here is special: it's delimited either by braces or parentheses, rather
 * than by the usual braces or double-quotes.  Thus, we treat parentheses
 * much like braces in this lexer, to handle the '@comment(...)' case.  And
 * there's an explicit check for the erroneous '@comment"..."' case in
 * start_string(), just to be complete.
 *
 * So that explains all the regexps in this lexer: the first one (starting
 * with newline) triggers the check for a runaway string.  Then, we have a
 * pattern to convert any single whitespace char (apart from newline) to a
 * space; note that any whitespace chars that are matched in the
 * newline-regexp will be converted by check_runaway_string(), and won't be
 * matched by the whitespace regexp here.  Then, we check for braces;
 * open_brace() and close_brace() take care of counting brace-depth and
 * determining if we have hit the end of the string.  lparen_in_string()
 * and rparen_in_string() do the same for parentheses, to handle
 * '@comment(...)'.  Then, if a double quote is seen, we call
 * quote_in_string(); this takes care of ending strings quoted by double
 * quotes.  Finally, the "fall-through" regexp handles most strings (except
 * for stuff that comes after a newline).
 */
#token        "\n~[\n\{\}\(\)\"\\]*" << check_runaway_string (); >>
#token        "[\r\t]"           << zzreplchar (' '); zzmore (); >>
#token        "\{"               << open_brace (); >>
#token        "\}"               << close_brace (); >>
#token        "\("               << lparen_in_string (); >>
#token        "\)"               << rparen_in_string (); >>
#token STRING "\""               << quote_in_string (); >>
#token        "~[\n\{\}\(\)\"]+" << zzmore (); >>

#lexclass START


/* At last, the grammar!  After that lexer, this is a snap. */

/* 
 * `bibfile' is the rule to recognize an entire BibTeX file.  Note that I
 * don't actually use this as the start rule myself; I have a function
 * bt_parse_entry() (in input.c), which takes care of setting up the lexer
 * and parser state in such a way that the parser can be entered multiple
 * times (at the `entry' rule) on the same input stream.  Then, the user
 * calls bt_parse_entry() until end of file is reached, at which point it
 * cleans up its mess.  The `bibfile' rule should work, but I never
 * actually use it, so it hasn't been tested in quite a while.
 */
bibfile!     : << AST *last; #0 = NULL; >>
               ( entry
                 <<                       /* a little creative forestry... */
                    if (#0 == NULL)
                       #0 = #1;
                    else
                       last->right = #1;
                    last = #1;
                 >>    
               )* ;

/*
 * `entry' is the rule that I actually use to enter the parser -- it parses
 * a single entry from the input stream (that is, the lexer scans past
 * junk until an '@' is seen at top-level, and that '@' becomes the AT 
 * token which starts an entry).
 *
 * `entry_metatype()' returns the value of a global variable maintained by
 * lex_auxiliary.c that tells us how to parse the entry.  This is needed
 * because, while the different things that look like BibTeX entries
 * (string definition, preamble, actual entry, etc.) have a similar lexical
 * makeup, the syntax is different.  In `entry', we just use the entry
 * metatype to determine the nodetype field of the AST node for the entry;
 * below, in `body' and `contents', we'll actually use it (in the form of
 * semantic predicates) to select amongst the various syntax options.
 */
entry        : << bt_metatype metatype; >>
               AT! NAME^
               <<
                  metatype = entry_metatype();
                  #1->nodetype = BTAST_ENTRY;
                  #1->metatype = metatype;
               >>
               body[metatype]
             ;

/*
 * `body' is what comes after AT NAME: either a single string, delimited by
 * {} or () (where NAME == 'comment'), or the more usual case of the entry
 * contents, delimited by an entry 'opener' and 'closer' (either
 * parentheses or braces).
 */
body [bt_metatype metatype]
             : << metatype == BTE_COMMENT >>?
               STRING     << #1->nodetype = BTAST_STRING; >>
             | ENTRY_OPEN! contents[metatype] ENTRY_CLOSE!
             ;

/* 
 * `contents' is where we select and accept the syntax for the guts of the
 * entry, based on the type of entry that we're parsing.  We find this
 * out from the `nodetype' field of the top AST node for the entry, which
 * is passed in as `entry_type'.  General entries (ie. any unrecognized
 * entry type) and `modify' entries have a name (the key), a comma, and
 * list of "field = value" assignments.  Macro definitions ('@string') are
 * similar, but without the key-comma pair.  Preambles have just a single
 * value, and aliases have a single "field = value" assignment.  (Note that
 * '@modify' and '@alias' are BibTeX 1.0 additions -- I'll have to check
 * the compatibility of my syntax with BibTeX 1.0 when it is released.)
 * '@comment' entries are handled differently, by the `body' rule above.
 */
contents [bt_metatype metatype]
             : << metatype == BTE_REGULAR /* || metatype == BTE_MODIFY */ >>?
               ( NAME | NUMBER ) << #1->nodetype = BTAST_KEY; >> 
               COMMA!
               fields
             | << metatype == BTE_MACRODEF >>?
               fields
             | << metatype == BTE_PREAMBLE >>?
               value
//           | << metatype == BTE_ALIAS >>?
//             field
             ;

/*
 * `fields' is a comma-separated list of fields.  Note that BibTeX has a
 * little wart in that it allows a single extra comma after the last field
 * only.  This is easy enough to handle, we just have to do it in the
 * traditional BNFish way (loop by recursion) rather than use EBNF
 * trickery.
 */
fields       : field { COMMA! fields }
             | /* epsilon */
             ;

/* `field' recognizes a single "field = value" assignment. */
field        : NAME^
               << #1->nodetype = BTAST_FIELD; check_field_name (#1); >>
               EQUALS! value
               << 
#if DEBUG > 1
                  printf ("field: fieldname = %p (%s)\n"
                          "       first val = %p (%s)\n",
                          #1->text, #1->text, #2->text, #2->text);
#endif
               >>
             ;

/* `value' is a sequence of simple_values, joined by the '#' operator. */
value        : simple_value ( HASH! simple_value )* ;

/* `simple_value' is a single string, number, or macro invocation. */
simple_value : STRING      << #1->nodetype = BTAST_STRING; >>
             | NUMBER      << #1->nodetype = BTAST_NUMBER; >>
             | NAME        << #1->nodetype = BTAST_MACRO; >>
             ;
