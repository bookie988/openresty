package OpenResty::QuasiQuote::Validator;

use strict;
use warnings;

require Filter::QuasiQuote;
our @ISA = qw( Filter::QuasiQuote );

use Parse::RecDescent;

my $grammar = <<'_END_GRAMMAR_';

validator: value <commit> eofile
    { return $item[1] }

value: hash
     | array
     | scalar

hash: '{' <commit> pair(s?) '}' attr(s?)
    {
        my $pairs = $item[3];
        my $topic = $arg{topic};
        my $for_topic = $topic ? " for $topic" : "";
        my $code = <<"_EOC_" . join('', @$pairs);
ref \$_ && ref \$_ eq 'HASH' or die "Invalid value$for_topic: Hash expected.\\n";
_EOC_
        $return =  $code;
    }

pair: key <commit> ':' value[ topic => $item[1] ]
        {
            my $quoted_key = quotemeta($item[1]);
            $return = <<"_EOC_" . $item[4] . "}\n";
{
local \$_ = "$quoted_key";
_EOC_
        }

key: { extract_delimited($text, '"') }
   | ident

ident: /^[A-Za-z]\w*/

scalar: type <commit> attr(s?)
    { $return = $item[1] . join('', @{ $item[3] }); }

array: '[' <commit> array_elem(s?) ']'

array_elem: value

type: 'STRING'
        {
            my $topic = $arg{topic};
            my $for_topic = $topic ? " for $topic" : "";
            <<"_EOC_";
defined \$_ and !ref \$_ and length(\$_) or die "Bad value$for_topic: String expected.\\n";
_EOC_
        }
    | 'INT'
        {
            my $topic = $arg{topic};
            my $for_topic = $topic ? " for $topic" : "";
            <<"_EOC_";
defined \$_ and /^[-+]?\\d+\$/ or die "Bad value$for_topic: Integer expected.\\n";
_EOC_
        }
    | 'IDENT'
        {
            my $topic = $arg{topic};
            my $for_topic = $topic ? " for $topic" : "";
            <<"_EOC_";
defined \$_ and /^\\w+\$/ or die "Bad value$for_topic: Identifier expected.\\n";
_EOC_
        }

attr: ':' <commit> ident arguments(?)

arguments: '(' <commit> argument(s? /^\s*,\s*/)  ')'

argument: /^\w+/

eofile: /^\Z/

_END_GRAMMAR_

$::RD_HINT = 1;
#$::RD_TRACE = 1;
our $Parser = new Parse::RecDescent ($grammar);

sub validator {
    my ($self, $s, $fname, $ln, $col) = @_;
    return $Parser->validator($s);
}

1;
