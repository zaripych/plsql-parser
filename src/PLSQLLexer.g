/*
 * Oracle(c) PL/SQL 11g Parser  
 *
 * Copyright (c) 2009, Alexandre Porcelli
 * 
 * This copyrighted material is made available to anyone wishing to use, modify, 
 * copy, or redistribute it subject to the terms and conditions of the GNU 
 * Lesser General Public License, as published by the Free Software Foundation. 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * See the GNU Lesser General Public License  for more details. 
 * 
 * You should have received a copy of the GNU Lesser General Public License 
 * along with this distribution; if not, write to: 
 * Free Software Foundation, Inc. 
 * 51 Franklin Street, Fifth Floor 
 * Boston, MA  02110-1301  USA 
 * 
 */
lexer grammar PLSQLLexer;

tokens { // moved to the import vocabulary
	UNSIGNED_INTEGER; // Imaginary token based on subtoken typecasting - see the rule <EXACT_NUM_LIT>
	APPROXIMATE_NUM_LIT; // Imaginary token based on subtoken typecasting - see the rule <EXACT_NUM_LIT>
	MINUS_SIGN; // Imaginary token based on subtoken typecasting - see the rule <SEPARATOR>
	DOUBLE_PERIOD;
	UNDERSCORE; // Imaginary token based on subtoken typecasting - see the rule <INTRODUCER>
}

@header {
/*
 * Oracle(c) PL/SQL 11g Parser  
 *
 * Copyright (c) 2009, Alexandre Porcelli
 * 
 * This copyrighted material is made available to anyone wishing to use, modify, 
 * copy, or redistribute it subject to the terms and conditions of the GNU 
 * Lesser General Public License, as published by the Free Software Foundation. 
 * 
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * See the GNU Lesser General Public License  for more details. 
 * 
 * You should have received a copy of the GNU Lesser General Public License 
 * along with this distribution; if not, write to: 
 * Free Software Foundation, Inc. 
 * 51 Franklin Street, Fifth Floor 
 * Boston, MA  02110-1301  USA 
 * 
 */ 
import java.util.LinkedList;
}

@members {
	// buffer (queue) to hold the emit()'d tokens
	private LinkedList<Token> tokenBuffer = new LinkedList<Token>();

	public void emit(Token t) {
		tokenBuffer.add(t);
	}

	private void advanceInput(){
		state.tokenStartCharIndex = input.index();
		state.tokenStartCharPositionInLine = input.getCharPositionInLine();
		state.tokenStartLine = input.getLine();
	}

	/**
	 * Return a token from this source; i.e., match a token on the char stream.
	 */
	public Token nextToken() {
		while (true) {
			if (tokenBuffer.size() == 0) {
				state.token = null;
				state.channel = Token.DEFAULT_CHANNEL;
				state.tokenStartCharIndex = input.index();
				state.tokenStartCharPositionInLine = input
						.getCharPositionInLine();
				state.tokenStartLine = input.getLine();
				state.text = null;
				if (input.LA(1) == CharStream.EOF) {
					return Token.EOF_TOKEN;
				}
				try {
					mTokens();
					if (state.token == null) {
						emit();
					} else if (state.token == Token.SKIP_TOKEN) {
						continue;
					}
				} catch (NoViableAltException nva) {
					reportError(nva);
					recover(nva); // throw out current char and try again
				} catch (RecognitionException re) {
					reportError(re);
					// match() routine has already called recover()
				}
			} else {
				Token result = tokenBuffer.poll();
				if (result != Token.SKIP_TOKEN || result != null) { // discard
					// SKIP
					// tokens
					return result;
				}
			}
		}
	}
}

FOR_NOTATION
	:	UNSIGNED_INTEGER
		{state.type = UNSIGNED_INTEGER; emit(); advanceInput();}
		'..'
		{state.type = DOUBLE_PERIOD; emit(); advanceInput();}
		UNSIGNED_INTEGER
		{state.type = UNSIGNED_INTEGER; emit(); advanceInput(); $channel=HIDDEN;}
	;

//{ Rule #358 <NATIONAL_CHAR_STRING_LIT> - subtoken typecast in <REGULAR_ID>, it also incorporates <character_representation>
//  Lowercase 'n' is a usual addition to the standard
NATIONAL_CHAR_STRING_LIT
	:	('N' | 'n') '\'' (options{greedy=true;}: ~('\'' | '\r' | '\n' ) | '\'' '\'' | NEWLINE)* '\''
	;
//}

//{ Rule #040 <BIT_STRING_LIT> - subtoken typecast in <REGULAR_ID>
//  Lowercase 'b' is a usual addition to the standard
BIT_STRING_LIT
	:	('B' | 'b') ('\'' ('0' | '1')* '\'' SEPARATOR? )+
	;
//}


//{ Rule #284 <HEX_STRING_LIT> - subtoken typecast in <REGULAR_ID>
//  Lowercase 'x' is a usual addition to the standard
HEX_STRING_LIT
	:	('X' | 'x') ('\'' ('a'..'f' | 'A'..'F' | '0'..'9')* '\'' SEPARATOR? )+ 
	;
//}

PERIOD
	:	'.' 
	{	if ((char) input.LA(1) == '.') {
			input.consume();
			$type = DOUBLE_PERIOD;
		}
	}
	;

//{ Rule #238 <EXACT_NUM_LIT> 
//  This rule is a bit tricky - it resolves the ambiguity with <PERIOD> 
//  It als44o incorporates <mantisa> and <exponent> for the <APPROXIMATE_NUM_LIT>
//  Rule #501 <signed_integer> was incorporated directly in the token <APPROXIMATE_NUM_LIT>
//  See also the rule #617 <unsigned_num_lit>
EXACT_NUM_LIT
	:	UNSIGNED_INTEGER
			( '.' UNSIGNED_INTEGER
			|	{$type = UNSIGNED_INTEGER;}
			) ( ('E' | 'e') ('+' | '-')? UNSIGNED_INTEGER {$type = APPROXIMATE_NUM_LIT;} )?
	|	'.' UNSIGNED_INTEGER ( ('E' | 'e') ('+' | '-')? UNSIGNED_INTEGER {$type = APPROXIMATE_NUM_LIT;} )?
	;
//}

//{ Rule #--- <CHAR_STRING> is a base for Rule #065 <char_string_lit> , it incorporates <character_representation>
//  and a superfluous subtoken typecasting of the "QUOTE"
CHAR_STRING
	:	'\'' (options{greedy=true;}: ~('\'' | '\r' | '\n') | '\'' '\'' | NEWLINE)* '\''
	;
//}

//{ Rule #163 <DELIMITED_ID>
DELIMITED_ID
	:	'"' (~('"' | '\r' | '\n') | '"' '"')+ '"' 
	;
//}

//{ Rule #546 <SQL_SPECIAL_CHAR> was split into single rules
PERCENT
	:	'%'
	;

AMPERSAND
	:	'&'
	;

LEFT_PAREN
	:	'('
	;

RIGHT_PAREN
	:	')'
	;

DOUBLE_ASTERISK
	:	'**'
	;

ASTERISK
	:	'*'
	;

PLUS_SIGN
	:	'+'
	;

COMMA
	:	','
	;

SOLIDUS
	:	'/'
	; 

AT_SIGN
	:	'@'
	;

ASSIGN_OP
	:	':='
	;

COLON
	:	':'
	;

SEMICOLON
	:	';'
	;

LESS_THAN_OR_EQUALS_OP
	:	'<='
	;

LESS_THAN_OP
	:	'<'
	;

GREATER_THAN_OR_EQUALS_OP
	:	'>='
	;

NOT_EQUAL_OP
	:	'!='
	|	'<>'
	|	'^='
	|	'�='
	;

GREATER_THAN_OP
	:	'>'
	;

QUESTION_MARK
	:	'?'
	;

// protected UNDERSCORE : '_' SEPARATOR ; // subtoken typecast within <INTRODUCER>
CONCATENATION_OP
	:	'||'
	;

VERTICAL_BAR
	:	'|'
	;

EQUALS_OP
	:	'='
	;

//{ Rule #532 <SQL_EMBDD_LANGUAGE_CHAR> was split into single rules:
LEFT_BRACKET
	:	'['
	;

RIGHT_BRACKET
	:	']'
	;

//}

//{ Rule #319 <INTRODUCER>
INTRODUCER
	:	'_' (SEPARATOR {$type = UNDERSCORE;})?
	;

//{ Rule #479 <SEPARATOR>
//  It was originally a protected rule set to be filtered out but the <COMMENT> and <MINUS_SIGN> clashed. 
SEPARATOR
	:	'-' {$type = MINUS_SIGN;}
	|	COMMENT { $channel=HIDDEN; }
	|	(SPACE | NEWLINE)+ { $channel=HIDDEN; }
	;
//}

//{ Rule #504 <SIMPLE_LETTER> - simple_latin _letter was generalised into SIMPLE_LETTER
//  Unicode is yet to be implemented - see NSF0
fragment
SIMPLE_LETTER
	:	'a'..'z'
	|	'A'..'Z'
	;
//}

//  Rule #176 <DIGIT> was incorporated by <UNSIGNED_INTEGER> 
//{ Rule #615 <UNSIGNED_INTEGER> - subtoken typecast in <EXACT_NUM_LIT> 
fragment
UNSIGNED_INTEGER
	:	('0'..'9')+ 
	;
//}

//{ Rule #097 <COMMENT>
fragment
COMMENT
	:	'--' ( ~('\r' | '\n') )* (NEWLINE|EOF)
	|	'/*' (options{greedy=false;} : .)* '*/'
	;
//}

//{ Rule #360 <NEWLINE>
fragment
NEWLINE
	:	'\r' (options{greedy=true;}: '\n')?
	|	'\n'
	;
//}

//{ Rule #522 <SPACE>
fragment
SPACE	:	' '
	|	'\t'
	;
//}

fragment APPROXIMATE_NUM_LIT: ;
fragment MINUS_SIGN: ;	
fragment UNDERSCORE: ;
fragment DOUBLE_PERIOD: ;

//{ Rule #442 <REGULAR_ID> additionally encapsulates a few STRING_LITs.
//  Within testLiterals all reserved and non-reserved words are being resolved

SQL92_RESERVED_ALL
	:	'all'
	;

SQL92_RESERVED_ALTER
	:	'alter'
	;

SQL92_RESERVED_AND
	:	'and'
	;

SQL92_RESERVED_ANY
	:	'any'
	;

SQL92_RESERVED_AS
	:	'as'
	;

SQL92_RESERVED_ASC
	:	'asc'
	;

SQL92_RESERVED_AT
	:	'at'
	;

SQL92_RESERVED_BEGIN
	:	'begin'
	;

SQL92_RESERVED_BETWEEN
	:	'between'
	;

SQL92_RESERVED_BY
	:	'by'
	;

SQL92_RESERVED_CASE
	:	'case'
	;

SQL92_RESERVED_CHECK
	:	'check'
	;

PLSQL_RESERVED_CLUSTERS
	:	'clusters'
	;

PLSQL_RESERVED_COLAUTH
	:	'colauth'
	;

PLSQL_RESERVED_COLUMNS
	:	'columns'
	;

PLSQL_RESERVED_COMPRESS
	:	'compress'
	;

SQL92_RESERVED_CONNECT
	:	'connect'
	;

PLSQL_RESERVED_CRASH
	:	'crash'
	;

SQL92_RESERVED_CREATE
	:	'create'
	;

SQL92_RESERVED_CURRENT
	:	'current'
	;

SQL92_RESERVED_DECLARE
	:	'declare'
	;

SQL92_RESERVED_DEFAULT
	:	'default'
	;

SQL92_RESERVED_DELETE
	:	'delete'
	;

SQL92_RESERVED_DESC
	:	'desc'
	;

SQL92_RESERVED_DISTINCT
	:	'distinct'
	;

SQL92_RESERVED_DROP
	:	'drop'
	;

SQL92_RESERVED_ELSE
	:	'else'
	;

SQL92_RESERVED_END
	:	'end'
	;

SQL92_RESERVED_EXCEPTION
	:	'exception'
	;

PLSQL_RESERVED_EXCLUSIVE
	:	'exclusive'
	;

SQL92_RESERVED_EXISTS
	:	'exists'
	;

SQL92_RESERVED_FALSE
	:	'false'
	;

SQL92_RESERVED_FETCH
	:	'fetch'
	;

SQL92_RESERVED_FOR
	:	'for'
	;

SQL92_RESERVED_FROM
	:	'from'
	;

SQL92_RESERVED_GOTO
	:	'goto'
	;

SQL92_RESERVED_GRANT
	:	'grant'
	;

SQL92_RESERVED_GROUP
	:	'group'
	;

SQL92_RESERVED_HAVING
	:	'having'
	;

PLSQL_RESERVED_IDENTIFIED
	:	'identified'
	;

PLSQL_RESERVED_IF
	:	'if'
	;

SQL92_RESERVED_IN
	:	'in'
	;

PLSQL_RESERVED_INDEX
	:	'index'
	;

PLSQL_RESERVED_INDEXES
	:	'indexes'
	;

SQL92_RESERVED_INSERT
	:	'insert'
	;

SQL92_RESERVED_INTERSECT
	:	'intersect'
	;

SQL92_RESERVED_INTO
	:	'into'
	;

SQL92_RESERVED_IS
	:	'is'
	;

SQL92_RESERVED_LIKE
	:	'like'
	;

PLSQL_RESERVED_LOCK
	:	'lock'
	;

PLSQL_RESERVED_MINUS
	:	'minus'
	;

PLSQL_RESERVED_MODE
	:	'mode'
	;

PLSQL_RESERVED_NOCOMPRESS
	:	'nocompress'
	;

SQL92_RESERVED_NOT
	:	'not'
	;

PLSQL_RESERVED_NOWAIT
	:	'nowait'
	;

SQL92_RESERVED_NULL
	:	'null'
	;

SQL92_RESERVED_OF
	:	'of'
	;

SQL92_RESERVED_ON
	:	'on'
	;

SQL92_RESERVED_OPTION
	:	'option'
	;

SQL92_RESERVED_OR
	:	'or'
	;

SQL92_RESERVED_ORDER
	:	'order'
	;

SQL92_RESERVED_OVERLAPS
	:	'overlaps'
	;

SQL92_RESERVED_PRIOR
	:	'prior'
	;

SQL92_RESERVED_PROCEDURE
	:	'procedure'
	;

SQL92_RESERVED_PUBLIC
	:	'public'
	;

PLSQL_RESERVED_RESOURCE
	:	'resource'
	;

SQL92_RESERVED_REVOKE
	:	'revoke'
	;

SQL92_RESERVED_SELECT
	:	'select'
	;

PLSQL_RESERVED_SHARE
	:	'share'
	;

SQL92_RESERVED_SIZE
	:	'size'
	;

SQL92_RESERVED_SQL
	:	'sql'
	;

PLSQL_RESERVED_START
	:	'start'
	;

PLSQL_RESERVED_TABAUTH
	:	'tabauth'
	;

SQL92_RESERVED_TABLE
	:	'table'
	;

SQL92_RESERVED_THEN
	:	'then'
	;

SQL92_RESERVED_TO
	:	'to'
	;

SQL92_RESERVED_TRUE
	:	'true'
	;

SQL92_RESERVED_UNION
	:	'union'
	;

SQL92_RESERVED_UNIQUE
	:	'unique'
	;

SQL92_RESERVED_UPDATE
	:	'update'
	;

SQL92_RESERVED_VALUES
	:	'values'
	;

SQL92_RESERVED_VIEW
	:	'view'
	;

PLSQL_RESERVED_VIEWS
	:	'views'
	;

SQL92_RESERVED_WHEN
	:	'when'
	;

SQL92_RESERVED_WHERE
	:	'where'
	;

SQL92_RESERVED_WITH
	:	'with'
	;

PLSQL_NON_RESERVED_USING
	:	'using'
	;

PLSQL_NON_RESERVED_MODEL
	:	'model'
	;

PLSQL_NON_RESERVED_ELSIF
	:	'elsif'
	;

REGULAR_ID
	:	(SIMPLE_LETTER) (SIMPLE_LETTER | '_' | '0'..'9')*
	;

// disambiguate these