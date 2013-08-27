# Name: `parser-combinators`

A library of building blocks for parsing text, written in LiveScript.

# Synopsis

    { sequence, choice, ... } = require 'parser-combinators';

    parser = < a combination of the parser building blocks from `parser-combinators` >
    [status, rest, matches) = parser str
    parse_tree = getParseTree matches
    say Dumper parse_tree


# Description

`parser-combinators` is a library of parser building blocks ('parser combinators'), inspired by the Parsec parser combinator library in Haskell
(http://legacy.cs.uu.nl/daan/download/parsec/parsec.html).
The idea is that you build a parsers not by specifying a grammar (as in yacc/lex or Parse::RecDescent), but by combining a set of small parsers that parse
well-defined items.

## Usage

Each parser in this library , e.g. `word` or `symbol`, is a function that returns a function (actually, a closure) that parses a string. You can combine these parsers by using special
parsers like `sequence` and `choice`. For example, a JavaScript variable declaration 

     var res = 42;

could be parsed as:

    p =
        sequence [
            symbol('var'),
            word,
            symbol('='),
            natural,
            semi
        ]

if you want to express that the assignment is optional, i.e. ` var res;` is also valid, you can use `maybe()`:

    p =
        sequence [
            symbol('var'),
            word,
            maybe(
                sequence [
                   symbol('='),
                   natural
                   ]
            ),
            semi
        ]

If you want to parse alternatives you can use `choice()`. For example, to express that either of the next two lines are valid:

    42
    return(42)

you can write

    p = choice( number, sequence [ symbol('return'), parens( number ) ] )

This example also illustrates the `parens()` parser to parse anything enclosed in parenthesis

## Provided Parsers

The library is not complete in the sense that not all Parsec combinators have been implemented. Currently, it contains:

        whiteSpace : parses any white space, always returns success. 

        * Lexeme parsers (they remove trailing whitespace):

        word : (\w+)
        natural : (\d+)
        symbol : parses a given symbol, e.g. symbol('int')
		comma : parses a comma
        semi : parses a semicolon
        

        char : parses a given character

        * Combinators:

        sequence( [ $parser1, $parser2, ... ], $optional_sub_ref )
        choice( $parser1, $parser2, ...) : tries the specified parsers in order
        try : normally, the parser consums matching input. try() stops a parser from consuming the string
        maybe : is like try() but always reports success
        parens( $parser ) : parser '(', then applies $parser, then ')'
        many( $parser) : applies $parser zero or more times
        many1( $parser) : applies $parser one or more times
        sepBy( $separator, $parser) : parses a list of $parser separated by $separator
        oneOf( [$patt1, $patt2,...]): like symbol() but parses the patterns in order

        * Dangerous: the following parsers takes a regular expression, so you can mix regexes and other combinators ...                                       
        
        regex( $patt)

## Labeling

You can label any parser in a sequence using an anonymous hash, for example:

    sub type_parser {	
		sequence [
        {Type =>	word},
        maybe parens choice(
                {Kind => natural},
						sequence [
							symbol('kind'),
							symbol('='),
                            {Kind => natural}
						] 
					)        
		] 
    }

Applying this parser returns a tuple as follows:
   

    str = 'integer(kind=8), '
    [status, rest, matches] = type_parser str

Here,`status` is 0 if the match failed, 1 if it succeeded.  `rest` contains the rest of the string. 
The actual matches are stored in the array $matches. As every parser returns its resuls as an array ref, 
`matches` contains the concrete parsed syntax, i.e. a nested array of arrays of strings. 

    sys.inspect(matches) ==> [{'Type' => 'integer'},['kind','\\=',{'Kind' => '8'}]]

You can remove the unlabeled matches and transform the lists of pairs into maps using `getParseTree`:

    parse_tree = getParseTree matches

    sys.inspect($parse_tree) ==> {Type : 'integer',Kind : 8 }

## A more complete example

I wrote this library because I needed to parse argument declarations of Fortran-95 code. Some examples of valid declarations are:

      integer(kind=8), dimension(0:ip, -1:jp+1, kp) , intent( In ) :: u, v,w
      real, dimension(0:7) :: f 
      real(8), dimension(0:7,kp) :: f,g 

I want to extract the type and kind, the dimension and the list of variable names. For completeness I'm parsing the `intent` attribute as well.
The parser is a sequence of four separate parsers `type_parser`, `dim_parser`, `intent_parser` and `arglist_parser`.
All the optional fields are wrapped in a `maybe()`.
    
    type_parser = sequence [
        {Type : word},
        maybe parens choice [
            {Kind : natural},
            sequence [
                symbol('kind'),
                symbol('='),
                {Kind : natural}
                ] 
            ]        
        ]
    
    dim_parser = sequence [
        symbol('dimension'),
        {Dim : parens sepBy(',', regex('[^,\)]+')) }
        ]
    
    intent_parser = sequence [
        symbol('intent'),
        {Intent : parens word}
        ]
    
    arglist_parser = sequence [
        symbol('::'),
        {Args : sepBy(',', word) }
        ]
    
    f95_arg_decl_parser =
        sequence [
            whiteSpace,
            {TypeTup : type_parser},
            maybe(
                sequence [
                    comma,
                    dim_parser
                ], 
            ),
            maybe(
                sequence [
                    comma,
                    intent_parser
                ], 
            ),
            symbol('::'),
            {Vars : sepBy(',',word)}
        ] 
    

Running the parser and calling getParseTree() om the first string (using the convenient shortcuts `say` and `Dumper` borrowed from Perl) 

    [st,rest, matches1] = f95_arg_decl_parser str1 
    say Dumper getParseTree     

results in 

    { TypeTup: { Type: 'integer', Kind: '8' },
      Dim: [ '0:ip', '-1:jp+1', 'kp' ],
      Intent: 'In',
      Vars: [ 'u', 'v', 'w' ] }
  
Neat, isn't it?

See `examples/test fortran95_argument_declarations.t` for the source code.    

# Author

Wim Vanderbauwhede <Wim.Vanderbauwhede@gmail.com>

# Copyright

Copyright 2013- Wim Vanderbauwhede

# License

This library is free software; see the LICENSE file for details.

# See also

\- The original Parsec library: http://legacy.cs.uu.nl/daan/download/parsec/parsec.html and http://hackage.haskell.org/package/parsec
\- The Perl version of this library: https://github.com/wimvanderbauwhede/Perl-Parser-Combinators and https://metacpan.org/module/Parser::Combinators
