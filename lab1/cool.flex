/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>
#include <stdio.h>
/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;
		
/*
 *  Add Your own definitions here
 */

	int comment_depth=0;
	int string_length = 0 ;
	
void resetStr();
	
void addStr(char*);
	
bool IsLong();
	
	
	
%}

/*
 * Define names for regular expressions here.
 */

%x COMMENT
%x COMMENT1
%x STRING
%x BROKENSTRING

DARROW          =>

digit			([0-9])
digits			({digit}+)
letter			([a-zA-Z])
letters			({letters}+)
whitespace 		([ \t\r\v\f]+)
	
%%

	
	
 /*
  *  Nested comments
  */
	
<INITIAL>"(*"		{
	BEGIN(COMMENT);
	comment_depth++	;
}

<INITIAL>"*)"		{
	cool_yylval.error_msg="Unmatched *)";
	return(ERROR);
}

<COMMENT>"(*"		{
	comment_depth++;
}

<COMMENT><<EOF>>	{
	cool_yylval.error_msg="EOF in comment";
	BEGIN(INITIAL);
	return(ERROR);	
}

<COMMENT>\n	{
	curr_lineno++;
}

<COMMENT>"*)"		{
	comment_depth--;
	if(comment_depth==0){
		BEGIN(INITIAL);
	}
}

<COMMENT>.			{
// no action;
}

"--"	{
	BEGIN(COMMENT1);
}

<COMMENT1>.		{
	// no action	
}

<COMMENT1>\n	{
	curr_lineno++;
	BEGIN(INITIAL);
}


 /*
  *  The multiple-character operators.
  */
{DARROW}		{return(DARROW);}
"<-"			{return(ASSIGN);}
"<="			{return(LE);}
"+"				{return('+');}
"-"				{return('-');}
"*"				{return('*');}
"/"				{return('/');}
"="				{return('=');}
"~"				{return('~');}
"<"				{return('<');}
":"				{return(':');}
";"				{return(';');}
","				{return(',');}
"."				{return('.');}
"("				{return('(');}
")"				{return(')');}
"{"				{return('{');}
"}"				{return('}');}
"@"				{return('@');}



 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */

(?i:class)						{return(CLASS);}
(?i:else)						{return(ELSE);}
(?i:fi)							{return(FI);}
(?i:if)							{return(IF);}
(?i:in)							{return(IN);}
(?i:inherits)					{return(INHERITS);}
(?i:isvoid)						{return(ISVOID);}
(?i:let)						{return(LET);}
(?i:loop)						{return(LOOP);}
(?i:pool)						{return(POOL);}
(?i:then)						{return(THEN);}
(?i:while)						{return(WHILE);}
(?i:case)						{return(CASE);}
(?i:esac)						{return(ESAC);}
(?i:new)						{return(NEW);}
(?i:of)							{return(OF);}
(?i:not)						{return(NOT);}

t(?i:rue)						{
									cool_yylval.boolean=true;
									return(BOOL_CONST);
								}

f(?i:alse)						{
									cool_yylval.boolean=false;
									return(BOOL_CONST);
								}


{digits}	{
	cool_yylval.symbol=inttable.add_string(yytext);
	return(INT_CONST);
}

[A-Z]("_"|{digit}|{letter})*	{
	cool_yylval.symbol=idtable.add_string(yytext);
	return(TYPEID);
}

[a-z]("_"|{digit}|{letter})*	{
	cool_yylval.symbol=idtable.add_string(yytext);
	return(OBJECTID);
}


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

<INITIAL>\"	{
	BEGIN(STRING);
}

<STRING>\"	{
	cool_yylval.symbol=stringtable.add_string(string_buf);	
	resetStr();
	BEGIN(INITIAL);
	return(STR_CONST);
}

<BROKENSTRING>\n	{
	resetStr();
	BEGIN(INITIAL);
}

<BROKENSTRING>\"	{
	resetStr();
	BEGIN(INITIAL);
}

<BROKENSTRING>.	{
// no action
}

<STRING>(\0|\\\0)	{
	cool_yylval.error_msg="String contains null character";	
//	printf("the 0 is %s\n",yytext);
	BEGIN(BROKENSTRING);
	return(ERROR);
}

<STRING><<EOF>>	{
	cool_yylval.error_msg="EOF in string constant";	
	resetStr();
	BEGIN(INITIAL);
	return(ERROR);
}

<STRING>\n	{
	curr_lineno++;
	cool_yylval.error_msg="Unterminated string constant";
	resetStr();
	BEGIN(INITIAL);
	return(ERROR);
}

<STRING>\\\n     {   
	if(IsLong()){
		cool_yylval.error_msg="String constant too long";	
		BEGIN(BROKENSTRING);
		return(ERROR);
	}else{
		curr_lineno++;
		addStr("\n");
	}
}	

<STRING>\\n {
	if(IsLong()){
		cool_yylval.error_msg="String constant too long";	
		BEGIN(BROKENSTRING);
		return(ERROR);
	}else{
		curr_lineno++;
		addStr("\n");
	}
}

<STRING>\\b	{
	if(IsLong()){
		cool_yylval.error_msg="String constant too long";	
		BEGIN(BROKENSTRING);
		return(ERROR);
	}else{
		addStr("\b");
	}
}

<STRING>\\f	{
	if(IsLong()){
		cool_yylval.error_msg="String constant too long";	
		BEGIN(BROKENSTRING);
		return(ERROR);
	}else{
		addStr("\f");
	}
}

<STRING>\\t	{
	if(IsLong()){
		cool_yylval.error_msg="String constant too long";	
		BEGIN(BROKENSTRING);
		return(ERROR);
	}else{
		addStr("\t");
	}
}

<STRING>\\.	{
	if(IsLong()){
		cool_yylval.error_msg="String constant too long";	
		BEGIN(BROKENSTRING);
		return(ERROR);
	}else{
		addStr(&yytext[1]);
	}
}

<STRING>.	{
		if(IsLong()){
		cool_yylval.error_msg="String constant too long";	
		BEGIN(BROKENSTRING);
		return(ERROR);
	}else{
		addStr(yytext);
	}
}



[ \r\t\v\f]+	{

}

\n	{
	curr_lineno++;	
	
}


.	{
	cool_yylval.error_msg=yytext;
	return(ERROR);
}


%%
	
void resetStr(){
	string_buf[0]='\0';
	string_length = 0 ;
}

bool IsLong(){
	if(string_length+1>=MAX_STR_CONST){
		return true;
	}else{
		return false;
	}
}

void addStr(char *c){
	if(string_length>=MAX_STR_CONST){
		return ;
	}else{
		strcat(string_buf,c);
	}
	string_length++;
}