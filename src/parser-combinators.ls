/* LiveScript requires explicit importing of function names! */
{is-type, keys, values, head, map, zip, filter} = require 'prelude-ls'

sys = require 'sys'

say = (x) -> process.stdout.write(x+"\n")
print = (x) -> process.stdout.write(x)
Dumper = (x) -> sys.inspect(x);

V=0

# I want to write the parser using lists, because sequencing is the most common operation.
# So I need a function to generate the actual parser from the lists
# which is actually a sequence of parsers
# The first arg is a list typeof, the second arg is an optional code typeof to process the returned list of matches

sequence = (plst, proc) ->
    gen = (str) ->
        say "* sequence( '#{str}' )" if V
        matches=[]
        st=1
        str2=''
        ms=[]
        for p in plst
            if typeof p == 'function'
                [st, str, ms]=p(str)
            else if not is-type 'Array' p # assuming it is a Hash
                k = head keys p
                pp = p[k]
                [st, str, mms]=pp(str)
                ms= {}
                ms[k]= mms
            else  # assuming it's ARRAY
                p2 = sequence(p)
                [st, str, ms]=p2(str) 
            if !st
                return [0,str,void]                 
            matches.push ms
        
        if proc != undefined
            if typeof(proc) == 'function'
                return [1,str,proc matches]
            else 
                return [1,str,matches]
        else 
            return [1,str,matches]
    return gen


# In the best tradition, bind() and return()
bind = (p1,p2)  ->
    gen = (str1)  ->
        matches=[]
        [st1,m1,str2] = p1( str1 )
        matches.push m1
        if (st1==1 ) 
            [st2,m2,str3] = p2( str2 )
            matches.push m2
            return [st2,str3,matches]
        else         
            return [0,str1, void]
    return gen


# Only we can't call it 'return' so let's call it enter ^.^
enter = (str)  -> return [0,str,void] 

# how to do 'OR' without running?
choice = (parsers) ->
    gen = (str) ->
        say "* choice( '#{str}' )" if V
        for p in parsers
            status=0 
            matches=[]
            if typeof(p) == 'function'
                [status, str, matches]=p(str)
            else if not is-type 'Array' p
                k = head keys p
                pp = p[k]
                [status, str, mms]=pp(str)
                matches = {}; matches[k] = mms
            else 
                say 'ARRAY'
            if status 
                say "choice: remainder : <#{str}>" if V
                say "choice: matches : ["++matches++"]" if V
                return [status, str, matches]
        return [0, str, void]
    return gen

# try(), but we can't call it try
# 
tryParse = (p) ->
    gen = (str) ->
        say "* try('#{str}')" if V
        [status, rest, matches]=p(str)
        if status
            say "try: remainder => <#{rest}>" if V
            say "try: matches => ["+matches+"]" if V
            return [1, rest, matches]
        else
            say "try: no matches => <#{str}>" if V
            return [0, str, matches]
    return gen

# maybe() is like try() but always succeeds
# it returns the matches and the consumed string or the orig string and no matches
maybe = (p) ->
    gen = (str) ->
        say "* maybe('#{str}')" if V
        [status, rest, matches]=p(str)
        if status
            say "maybe matches: ["++matches++"]" if V
            return [1, rest, matches]
        else
            say "maybe: no matches for <#{str}>" if V
            return [1, str, void]
    return gen

parens = (p) ->
    gen = (str0) ->
        say "* parens( '#{str0}' )" if V
        matches=[]
#        str2 = str0.replace( /^\s+/,'')
        [status, str3, ch]=parseChar('(')(str0)
#        say "parens1: #{status} => <#{str3}>\n" if V
        if status         
            str4 = str3.replace(/^\s*/,'');
            [st,str4s,matches]=p(str4) 
            say "parens: remainder => <#{str4s}>\n" if V
            say "parens: matches => "+sys.inspect(matches)+"\n" if V
            status*=st
            if status==1
                [st, str5, ch]=parseChar(')')(str4s)
                status*=st
                if status==1 # OK!
                    str6=str5.replace(/^\s*/,'');
                    say "parens: remainder => <#{str5}>\n" if V
                    say "parens: closing matches => "+sys.inspect(matches)+"\n" if V
                    return [1,str6, matches]
                else # parse failed on closing paren
                    return [0,str5, matches]
            else # parse failed on ref
                return [0,str4, matches]
        else # parse failed on opening paren
            return [0,str3,void]
    return gen
    

parseChar = (ch) ->
    gen =  (str0) ->
        say "* parseChar('#{ch}', '#{str0}' )" if V
        if str0.substring(0,1) == ch
            say "parseChar: \'#{ch}\' in <#{str0}> => "+str0.substring(1)+"\n" if V
            return [1,str0.substring(1),ch]
        else 
            return [0,str0,void]
    return gen

sepBy = (sep, p) ->
    gen = (str0) ->
        matches=[]
        say "* sepBy( \'#{sep}\', '#{str0}' )" if V
        [status,str1,m]=p(str0)
        if status
            matches.push m        
            say "sepBy: remainder : <#{str1}>" if V
            [status,str2,m]=parseChar(sep)(str1)
            while status 
                str2s=str2.replace(/^\s*/,'')
                [st,str3,m]=p(str2s)
                matches.push m
                [status,str2,m]=parseChar(sep)(str3)
            say "sepBy matches : ["++matches++"]" if V
            return [1, str2, matches]
        else
# first match failed. 
            return [0,str1,void]        
    return gen    


# This is a lexeme parser, so it skips trailing whitespace
word = (str) ->
        say "* word( '#{str}' )" if V
        status=0
        matches=void
        if str.match(/^(\w+)/)
            m=str.match( /^(\w+)/)[1]
            matches=m
            status=1
# FIXME!
            str2 = str.replace(/^\w+\s*/,'')
            say "word: remainder : <#{str2}>" if V
            say 'word: matches : ['++matches++"]" if V
            return [status, str2, matches]
        else 
            say "word: match failed : <str>" if V
            return [status, str, matches] # assumes status is 0|1, str is string, matches is [string]

# matches an unsigned integer
natural = (str) ->
        say "* natural( '#{str}' )" if V
        status=0
        matches=void
        if str.match(/^(\d+)/) 
            m=str.match( /^(\d+)/)[1]
            matches=m
            status=1
            str2 = str.replace(/^\d+\s*/,'')
            say "natural: remainder : <#{str2}>" if V
            say 'natural: matches : ['++matches++"]" if V
            return [status, str2, matches]
        else 
            say "natural: match failed : <str>" if V
            return [status, str, matches] # assumes status is 0|1, str is string, matches is [string]

# As in Parsec, parses a literal and removes trailing whitespace
symbol = (lit_str)  ->
    lit_str_esc = lit_str.replace(/(\W)/g,'\\$1') # FIXME!
    gen =         (str) ->
        say "* symbol('#{lit_str}', '#{str}' )" if V
        status=0
        matches=void
        re = new RegExp('^'+lit_str_esc+'\\\s*')
        if str.match(re)
            matches=lit_str
            status=1
            str2 = str.replace(re,'') # FIXME! create new Match object!
            say "symbol: remainder : <"++str2++">" if V
            say 'symbol: matches : ['++matches++"]" if V
            return [status, str2, matches]
        else 
            say "symbol: match failed : <#{str}>" if V
            return [status, str, matches] # assumes status is 0|1, str is string, matches is [string]
    return gen

# many , as in Parsec, parses 0 or more the specified parsers
many = (parser)  ->
    gen =         (str) ->
        matches=[]
        say "* many( '#{str}' )" if V
        [status,str,m]=parser(str)
        if status
            matches.push m        
            while status==1 
                [st, str, m]=parser(str)
                matches.push m
            say "many: remainder : <str>" if V
            say "many: matches : ["++matches++"]" if V
        else 
# first match failed. 
            say "many: first match failed : <str>" if V
            return [1,str,void]
        return [1, str, matches]    
    return gen

# many1 , as in Parsec, parses 0 or more the specified parsers
many1 = (parser)  ->
    gen =         (str) ->
        matches=[]
        say "* many1( '#{str}' )" if V
        [status,str,m]=parser(str)
        if status
            matches.push m        
            say "many11: status : <str>" if V
            while status==1 
                [st, str, m]=parser(str)
                matches.push m
            say "many1: remainder : <str>" if V
            say "many1: matches : ["++matches++"]" if V
        else 
# first match failed. 
            say "many1: first match failed : <str>" if V
            return [0,str,void]
        return [1, str, matches]    
    return gen


comma =  (str)  ->
        say "* comma( '#{str}' )" if V
        st = str.match(/^\s*,\s*/) ? 1 : 0;
        str2 = str.replace(/^\s*,\s*/,'')
        return [st, str2, void]

semi =  (str)  ->
        say "* semi( '#{str}' )" if V
        st = str.match(/^\s*,\s*/) ? 1 : 0;
        str2 = str.replace(/^\s*;\s*/,'')
        return [st, str2, void]
        


# strip leading whitespace, always success
whiteSpace = (str) ->
        say "* whiteSpace( '#{str}' )" if V
        ms = str.match(/^\s*/) ? 1 : 0
        str2 = str.replace(/^\s*/,'')
        return [1,str2,ms[0]]


oneOf = (patt_lst)  ->
    gen =     (str) ->
        say "* oneOf( [" ++ patt_lst ++ "], '#{str}' )" if V
        for p in patt_lst
            [status, str, matches]= symbol(p)(str)
            if status
                say "choice: remainder : <str>" if V
                say "choice: matches : ["++matches++"]" if V
                return [status, str, matches]
        return [0, str, void]
    return gen



# Enough rope: this parser will parse whatever the regex is, stripping trailing whitespace
regex = (regexstr) ->
    gen = (str) ->
        say "* regex( '/#{regexstr}/', '#{str}' )" if V
        re = new RegExp('\('+regexstr+'\)\\\s*')
        if str.match(re)
            m=str.match( re )[1]
            str2=str.replace(re,'')
            matches=m;
            say "regex: remainder => <#{str2}>" if V
            say "regex: matches => [#{matches}]" if V
            return [1,str2, matches];
        else 
            say "regex: match failed => <#{str}>\n" if V
            return [0,str, void]
    return gen

get_tree_as_lists = (list) ->
    hlist=[]
    for elt in list
        say "ELT: <#{elt}>" if V
        if is-type 'Array' elt and elt.length>0 # non-empty list
            hlist.push get_tree_as_lists(elt)
        else if is-type 'Object' elt  # hash: need to process the rhs of the pair
            k = head keys elt
            v = elt[k]
            say "HASH: #{k} => #{v}" if V
            if not is-type 'Array' v  # not an array => just push 
                say '    NOT ARRAY => just push' if V
                kv = {}
                kv[k] = v
                hlist.push kv
            else if v.length==1  # a single-elt array
                say '    SINGLE-ELT ARRAY' if V
                kv = {}
                kv[k] = head v
                hlist.push kv
            else  
                say '    ARRAY' if V
                pv = map( 
                        (x) -> switch 
                            | is-type 'Array' x => get_tree_as_lists(x) 
                            | is-type 'Object' x => get_tree_as_lists([x]) 
                            | not is-type 'Undefined' x => x  
                        , v)
                kpv ={}
                kpv[k]=pv
                hlist.push kpv                     
        else     
            say "SKIP: #{elt}" if V
#    say "LEN: "+hlist.length if V
    if hlist.length==1
        return head hlist
    else
        return hlist

# 
is_list_of_objects = (mlo) -> 
    to = (x) -> not is-type 'Object' x
    l=filter( to, mlo)
    l.length==0

l2m = (hlist) ->   
        hmap = {}
        hmap_keys = map( head . keys, hlist)
        hmap_vals = map( head . values, hlist)
        vl2m =  (h) ->if is_list_of_objects( h ) then l2m( h ) else h
        hmap_kvs = zip hmap_keys, map( vl2m, hmap_vals)
        tf = (kv) -> hmap[ kv[0] ] = kv[1]
        map tf, hmap_kvs
        return hmap
        
getParseTree = (m) -> l2m <| get_tree_as_lists <| m        
#    return ( (hlist.length==1) ? (head hlist) : hlist) # This just returns 'false' ...
    
module.exports = { 
    sequence, choice, tryParse, maybe, oneOf, parens, parseChar, sepBy, word, natural, symbol, comma, semi, many, many1, whiteSpace, regex, getParseTree, say,
    print, Dumper

}

