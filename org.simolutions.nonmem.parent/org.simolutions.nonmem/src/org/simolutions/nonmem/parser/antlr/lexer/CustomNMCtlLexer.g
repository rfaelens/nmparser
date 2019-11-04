lexer grammar CustomNMCtlLexer;
options {
	tokenVocab=InternalNMCtlLexer;
}
@header {
package org.simolutions.nonmem.parser.antlr.lexer;

// Hack: Use our own Lexer superclass by means of import. 
// Currently there is no other way to specify the superclass for the lexer.
import org.eclipse.xtext.parser.antlr.Lexer;
}

/*
There are multiple levels of context-aware lexing that are needed here.
A first level is to know what the next token should be. If it is supposed to be a filename, an ID or even something else entirely.
In some cases, we will have to use "normal" lexing and let the parser figure it out.

Examples:
FILE=filename
IGNORE=(GEN.EQ.1,AGE.GT.60)

To know which token comes next, we can decide based on keyword identifiers.

However, keywords should only be read as keywords in the appropriate section. Furthermore, some keywords have different arguments depending on the section they are used in:
$ESTIMATION PRINT=5
$TABLE PRINT=E

Finally, some look-ahead may be required to decide the type of token that should be lexed next, as some keywords allow different types of values. 
An example is $INPUT IGNORE=@ vs $INPUT IGNORE=(FOO.EQ.3) vs $INPUT IGNORE="b"
This whole IGNORE= statement is a mess anyway, read the documentation:
      [...]                A list may contain several conditions; these
      should be separated by commas, and the list should be enclosed in
      parentheses.   Up  to  100 different conditions altogether can be
      specified.  Multiple IGNORE options with different lists  may  be
      used.   A  list may span one or more NM-TRAN records.  The use of
      "=" after IGNORE is optional, but parentheses are  required  with
      this  form  of  IGNORE.  Values may be alphabetic or numeric, and
      may optionally be surrounded by single quotes ' or double  quotes
      ".   Quotes  are  required if a value contains special characters
      such as =.  However, a value may not contain  spaces  or  commas.
      No format specification is permitted with this form of IGNORE.
*/

@members {
	enum Mode {NORMAL, RECORD_OPTION};
	Mode mode = Mode.NORMAL;

	boolean readFilename = false;
	
	enum Record {
	NONE,
	THETA, OMEGA, SIGMA,
	PK,	PRED, ERROR,
	DATA, ESTIMATION, COVARIANCE, SUBROUTINES, PRIOR, // key-value tokens
	TABLE, INPUT // key-value, but also ID tokens
	};
	Record record = Record.NONE;	

	boolean lexTokens() {
		return !readFilename;
	}
	
	boolean hasInitialValues() {
		return lexTokens() && (
			record == Record.THETA || record == Record.OMEGA || record==Record.SIGMA
		);
	}
	
	boolean hasAbbrevCode() {
		return lexTokens() && (
			record == Record.PK || record == Record.PRED || record == Record.ERROR
		);
	}
	
	boolean hasRecordOptions() {
		return lexTokens() && ( 
			record == Record.INPUT|| record == Record.DATA|| record == Record.ESTIMATION|| record == Record.COVARIANCE
		);
	}
}

fragment EOL: ('\r'? '\n');
RULE_PROBLEM_RECORD : '$PRO' ('B'|'BL'|'BLE'|'BLEM')? RULE_WS ~(('\n'|'\r'))* EOL?; // do not include EOL
RULE_NM_COMMENT : ';' ~(('\n'|'\r'))* ('\r'? '\n')?;
RULE_WS : (' '|'\t'|'\r'|'\n')+;

RULE_PK_RECORD : '$PK' {record=Record.PK;};
RULE_PRED_RECORD : '$PRED' {record=Record.PRED;};
RULE_ERROR_RECORD : '$ERROR' {record=Record.ERROR;};

RULE_INPUT_RECORD : '$INPUT' {record=Record.INPUT;};
RULE_DATA_RECORD : '$DATA' {readFilename=true; record=Record.DATA;};
RULE_SUBROUTINES_RECORD : '$SUBROUTINES' {record=Record.SUBROUTINES};
RULE_PRIOR_RECORD : '$PRIOR' {record=Record.PRIOR};

RULE_THETA_RECORD : '$THETA' {record=Record.THETA};
RULE_OMEGA_RECORD : '$OMEGA' {record=Record.OMEGA};
RULE_SIGMA_RECORD : '$SIGMA' {record=Record.SIGMA};

RULE_ESTIMATION_RECORD : '$EST' ('IMATION'|'IMATIO'|'IMATI'|'IMAT'|'IMA'|'IM'|'I')? {record=Record.ESTIMATION;};
RULE_COVARIANCE_RECORD : '$COV' ('ARIANCE'|'ARIANC'|'ARIAN'|'ARIA'|'ARI'|'AR'|'A')? {record=Record.COVARIANCE;};
RULE_TABLE_RECORD : '$TABLE' {record=Record.TABLE;};

RULE_COMMA : {lexTokens()}? ',';
RULE_PARENL : {lexTokens()}? '(';
RULE_PARENR : {lexTokens()}? ')';

RULE_FIX: {hasInitialValues()}? 'FIXED'|'FIX';
RULE_BLOCK: {hasInitialValues()}? 'BLOCK';
RULE_VALUES: {hasInitialValues()}? 'VALUES';
RULE_SAME: {hasInitialValues()}? 'SAME';
RULE_DIAGONAL: {hasInitialValues()}? 'DIAGONAL';

RULE_EQ : {hasRecordOptions() || hasAbbrevCode()}? '=';

// TODO: Do not know exactly where these tokens appear...
RULE_PLUS : {hasAbbrevCode()}? '+';
RULE_MINUS : {hasAbbrevCode()}? '-';
RULE_MULT : {hasAbbrevCode()}? '*';
RULE_DIV : {hasAbbrevCode()}? '/';
RULE_POW : {hasAbbrevCode()}? '^' | '**';
RULE_DOT: '.';
RULE_X: 'x' | 'X';
RULE_THETA: {hasAbbrevCode()}? 'THETA';
RULE_OMEGA : {hasAbbrevCode()}? 'OMEGA';
RULE_SIGMA : {hasAbbrevCode()}? 'SIGMA';
RULE_ETA : {hasAbbrevCode()}? 'ETA';
RULE_EPS : {hasAbbrevCode()}? 'EPS';
RULE_ERR : {hasAbbrevCode()}? 'ERR';
// TODO: Conditions can also appear in the IGNORE= block of $INPUT
RULE_AND_OP : '.AND.';
RULE_OR_OP :  '.OR.';
RULE_EQ_OP : ('.EQ.'|'==');
RULE_NE_OP : ('.NE.'|'/=');
RULE_LE_OP : ('.LE.'|'<=');
RULE_GE_OP : ('.GE.'|'>=');
RULE_LT_OP : ('.LT.'|'>');
RULE_GT_OP : ('.GT.'|'<');

RULE_OPTION_KEY : {hasRecordOptions()}? (
	'POSTHOC' |
	'NOPOSTHOC' |
	'INTERACTION' |
	'NOABORT'|
	'UNCONDITIONAL' |
	'NOPRINT' |
	'NOAPPEND' |
	'FIRSTONLY' |
	'ONEHEADER'
	// etc: continue for all of the known nonmem options without values
);
RULE_OPTION_KEY_ID : {hasRecordOptions()}? (
	'METHOD' |
	'IGNORE' |
	'MATRIX' |
	RULE_OPTION_KEY_PRINT_COVARIANCE
	// Oh great! PRINT is something with a number value in an $ESTIMATION record, but it can also be 'PRINT=E' in the $COV record!  
);
RULE_OPTION_KEY_PRINT_COVARIANCE : {record==Record.COVARIANCE}? (
	'PRINT'
);
RULE_OPTION_KEY_PRINT_ESTIMATION : {record==Record.ESTIMATION}? (
	'PRINT'
);

RULE_OPTION_KEY_FILENAME
	:	{hasRecordOptions()}? (
	'FILE' | 'FILENAME'
	) {nextTokenIsFilename=true;};
RULE_OPTION_KEY_INT : {hasRecordOptions()}? (
	'NITER' |
	'PRINT' |
	'SIGL' |
	'CTYPE' |
	'CITER' |
	'NOPRIOR' |
	'NSIG' |
	'NBURN' |
	'SEED' |
	'ISAMPLE' |
	'MAPITER' |
	'EONLY' |
	'MAXEVAL' |
	RULE_OPTION_KEY_PRINT_ESTIMATION 
	// PRINT is something with a number value in $ESTIMATION, but with an ID in $COVARIANCE 
);
RULE_OPTION_KEY_FLOAT: {hasRecordOptions()}? (
	'CALPHA'
);
RULE_OPTION_KEY_INTLIST :  {hasRecordOptions()}? 'CUSTOM4';

// This has to be first, because if next token is filename, we need to read it!
RULE_FILENAME: {readFilename}? ('a'..'z'|'A'..'Z'|'_'|'0'..'9'|'-'|'.')+ {readFilename=false;};

fragment INT : ('0'..'9')+;
RULE_FLOAT :
(('+'|'-')? INT ('.'INT?) (('E'|'e')('+'|'-')? INT )?) |
(('+'|'-')? INT           (('E'|'e')('+'|'-')? INT ) ) |
(                ('.'INT) (('E'|'e')('+'|'-')? INT )?) |
('-'        INT                                      );

RULE_ID : (('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'_'|'0'..'9')*) ;
RULE_STRING : ('"' ('\\' .|~(('\\'|'"')))* '"'|'\'' ('\\' .|~(('\\'|'\'')))* '\'');
RULE_INT : INT;
