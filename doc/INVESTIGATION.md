# This document
This document is a logbook of everything I figured out so far.

# Language documentation
The main documentation is the $xxx.html files in the NONMEM distribution. They are quite complete, and readable from a language definition point-of-view.

# Lexing
The lexing of nonmem is based around comments and sections.

## Comments
Comments should be filtered out by the lexer.
Comments are defined as `';' !('\n')* `

## Sections
Sections are defined as `$IDENTIFIER !('$'|';')*`.

However, please note that `$` could still appear in comments. Sections also should trigger different lexing modes, as e.g. $PROBLEM will simply parse anything (even ignoring comments!) until the next newline...
I suggest to only parse `$ID` as a lexical token, and then entering into a specific mode based on the section itself.

## Extra identifiers
In general, nonmem uses identifiers defined as `LETTER (LETTER|DIGIT)^{0-3}`. However, it seems like this rule is broken in e.g. `MU_3`.

Furthermore, depending on the section, different lexical rules exist.
* The $PROBLEM section should be parsed as a single token, until the next newline. That is the title of that PROBLEM.
* The $ESTIMATION section has plenty of option keywords. Some keywords have values that have specific lexing rules: e.g. a filename can contain `.` or `-`. There is also support for lists in several cases (`( 15, 30)`).
* The $PK section has different lexing rules. Special keywords exist depending on the context (e.g. `.EQ.` as a substitute for `==`).
* As I see it, the list of reserved keywords not to be used for variable names in abbreviated code is *HUGE*. E.g. `EQ`, `NE`, `HEADER`, `FILE`, etc. However, I would not be surprised if `EQ` is a valid variable name, and could be used in a comparison as follows: `EQ.EQ.3`...

## Lexer requirements
All of this shows that several approaches exist to implement the lexer for nonmem:

1. Use a lexer for the simple tokens. Use grammar rules to collate several tokens together, e.g. `Filename: (ID|INT|'.')+;`. This is tricky, because as soon as you identify as special token (e.g. `.EQ.`), it should also be included in the list of valid tokens for a filename... This will mess up auto-suggest.
2. Use a minimal lexer, and interpret terminals in the parser: only parse comments, section identifiers and single characters. Use parser rules to collate these things together.
3. Use a contextual lexer. This is possible to do in ANTLRv3, but requires a bit of hacking in XText to integrate it.

For now, I am using #1. It works, but has some voodoo issues: `FILE=param.ETA` does not get parsed correctly. The lexer reads this as KEYWORD(FILE)|EQUALS(=)|ID(param)`, and then continues reading `.E` (assuming it matches `.EQ.`). We then get an error `Expecting Q, got T`...

## Nested lexer
NM-TRAN can include fortran code, a feature called `verbatim code`. (see verbatim.htm)
Fortunately, it is very easy for the lexer to discern this: any line starting with `"` is verbatim code.

Therefore, a nonmem lexer can work as follows (starting in 'root' mode):

* Ignore any whitespace encountered.
* If `"` is found, lex the whole line as a FORTRAN verbatim code. (_Note: I do not know if this is allowed in all sections, or if this is a section-specific thing_)
* If `;` is found, lex the whole line as a comment
* If `$` is found, lex the section name, and jump to the specific lexer mode corresponding to that section.

In a section, we will activate different lexing rules depending on the section. I *hope* this will provide enough context to discern between all possible nonmem identifiers...

Note: I need to figure out how the continuation character `&` is used. Can it be used in a comment to make the next line a comment as well? Idem for verbatim code?

## Documentation
XText is probably the way to go. I really like their tooling, they generate an EMF model automatically and build an editor, tests, etc. Very advanced, and hopefully can be convinced to parse a language like NM-TRAN.

* Excellent documentation available: https://www.eclipse.org/Xtext/documentation/index.html

Due to the above-mentioned limitations for the lexer, we should probably write our own lexer, but keep the parser in XText.

* Very nice example of custom lexer in ANTLR: http://consoliii.blogspot.com/2013/04/xtext-is-incredibly-powerful-framework.html
* Add https://www.eclipse.org/forums/index.php/t/1078901/ to integrate it with the new MWE2 workflow

JFlex is another option, but I really hate their language
* https://typefox.io/taming-the-lexer
* https://www.eclipse.org/forums/index.php/m/1772427/
* https://www.eclipse.org/forums/index.php/m/1769838/?srch=xtext+jflex#msg_1769838


# Parser
## Simple sections
Some sections are very simple to parse. The only challenging aspects:

* The amount of available options. We need to think whether we want the AST to contain a node per option, a specific feature per option, or .... For now, it was implemented by using `KeywordEstimationOption(key=KeywordEnum)` elements. If a value is accepted, we can parse using `IntegerEstimationOption` or `FilenameEstimationOption`, with enums as the keyword for each type. Verifying if the value is as expected should be done at compilation, not during parsing.
See also https://theantlrguy.atlassian.net/wiki/spaces/ANTLR3/pages/2687320/How+can+I+allow+keywords+as+identifiers
* The fact that nonmem provides so many alternatives. The `$SIMULATION` section can be specified as `$SIM | $SIMU | $SIMUL | $SIMULA | $SIMULAT | $SIMULATI | $SIMULATIO | $SIMULATION | $SMT`. See also https://theantlrguy.atlassian.net/wiki/spaces/ANTLR3/pages/2687035/How+do+I+handle+abbreviated+keywords
* To left-factorize recursive expressions.
* To make the distinction between function calls and vector calls.

## Repeating sections
* NM-TRAN allows lines without a record name. It assumes the record has the same name as the previous record.
* NM-TRAN allows records to be interleaved.

From IV.pdf: "In general, all the information from all records which use (or are understood to use) the same name, or use (or are understood to use) an alias for this name, is regarded as coming from a single record with that name".

Exceptions to this rule:
* A new $PROBLEM record also finishes collation of all previous sections.
* An $ESTIMATION record can contain multiple $ESTIMATION specifications (?)

The easiest way to lex this, is probably to reorder the tokenstream. See https://stackoverflow.com/questions/50859020/reorder-token-stream-in-xtext-lexer
