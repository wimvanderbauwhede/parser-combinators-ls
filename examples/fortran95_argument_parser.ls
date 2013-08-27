#
{say, print, Dumper, sequence, choice, tryParse, maybe, whiteSpace, word, parens, sepBy, comma, semi, natural, symbol, regex, getParseTree} = require '../src/parser-combinators.ls'

# let
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
# in
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


str1 = '      integer(kind=8), dimension(0:ip, -1:jp+1, kp) , intent( In ) :: u, v,w'
str2 = '      real, dimension(0:7) :: f '
str3 = '      real(8), dimension(0:7,kp) :: f,g '

str4 = 'integer(kind=8), dimension(0:ip, -1:jp+1, kp) , intent( In ) :: u, v,w'
str5 = 'dimension(0:ip, -1:jp+1, kp) , intent( In ) :: u, v,w'
str6 = 'intent( In ) :: u, v,w'
str7 = ':: u, v,w'


[st,rest, matches1] = f95_arg_decl_parser(str1)
say Dumper getParseTree matches1

[ st, rest, matches2] = f95_arg_decl_parser(str2)
say Dumper getParseTree matches2

[ st, rest, matches3] = f95_arg_decl_parser(str3)
say Dumper getParseTree matches3

#[st,rest, matches] = type_parser(str4)
#[st,rest, matches] = dim_parser(str5)
#[st,rest, matches] = intent_parser(str6)
#[st,rest, matches] = arglist_parser(str7)

