# BEGIN BPS TAGGED BLOCK {{{
# 
# COPYRIGHT:
#  
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC 
#                                          <jesse@bestpractical.com>
# 
# (Except where explicitly superseded by other copyright notices)
# 
# 
# LICENSE:
# 
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
# 
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
# 
# 
# CONTRIBUTION SUBMISSION POLICY:
# 
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
# 
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
# 
# END BPS TAGGED BLOCK }}}
package RT::SQL;

use strict;
use warnings;

# States
use constant VALUE       => 1;
use constant AGGREG      => 2;
use constant OP          => 4;
use constant OPEN_PAREN  => 8;
use constant CLOSE_PAREN => 16;
use constant KEYWORD     => 32;
my @tokens = qw[VALUE AGGREGATOR OPERATOR OPEN_PAREN CLOSE_PAREN KEYWORD];

use Regexp::Common qw /delimited/;
my $re_aggreg      = qr[(?i:AND|OR)];
my $re_delim       = qr[$RE{delimited}{-delim=>qq{\'\"}}];
my $re_value       = qr[\d+|NULL|$re_delim];
my $re_keyword     = qr[[{}\w\.]+|$re_delim];
my $re_op          = qr[=|!=|>=|<=|>|<|(?i:IS NOT)|(?i:IS)|(?i:NOT LIKE)|(?i:LIKE)]; # long to short
my $reopen_paren  = qr[\(];
my $reclose_paren = qr[\)];

sub ParseToArray {
    my ($string) = shift;

    my ($tree, $node, @pnodes);
    $node = $tree = [];

    my %callback;
    $callback{'open_paren'} = sub { push @pnodes, $node; $node = []; push @{ $pnodes[-1] }, $node };
    $callback{'close_paren'} = sub { $node = pop @pnodes };
    $callback{'entry_aggregator'} = sub { push @$node, $_[0] };
    $callback{'Condition'} = sub { push @$node, { Key => $_[0], Op => $_[1], Value => $_[2] } };

    Parse($string, \%callback);
    return $tree;
}

sub Parse {
    my ($string, $cb) = @_;
    $string = '' unless defined $string;

    my $want = KEYWORD | OPEN_PAREN;
    my $last = 0;

    my $depth = 0;
    my ($key,$op,$value) = ("","","");

    # order of matches in the RE is important.. op should come early,
    # because it has spaces in it.    otherwise "NOT LIKE" might be parsed
    # as a keyword or value.

    while ($string =~ /(
                        $re_aggreg
                        |$re_op
                        |$re_keyword
                        |$re_value
                        |$reopen_paren
                        |$reclose_paren
                       )/iogx )
    {
        my $match = $1;

        # Highest priority is last
        my $current = 0;
        $current = OP          if ($want & OP)          && $match =~ /^$re_op$/io;
        $current = VALUE       if ($want & VALUE)       && $match =~ /^$re_value$/io;
        $current = KEYWORD     if ($want & KEYWORD)     && $match =~ /^$re_keyword$/io;
        $current = AGGREG      if ($want & AGGREG)      && $match =~ /^$re_aggreg$/io;
        $current = OPEN_PAREN  if ($want & OPEN_PAREN)  && $match =~ /^$reopen_paren$/io;
        $current = CLOSE_PAREN if ($want & CLOSE_PAREN) && $match =~ /^$reclose_paren$/io;


        unless ($current && $want & $current) {
            my $tmp = substr($string, 0, pos($string)- length($match));
            $tmp .= '>'. $match .'<--here'. substr($string, pos($string));
            my $msg = "Wrong query, expecting a ". _BitmaskToString($want) ." in '$tmp'";
            return $cb->{'Error'}->( $msg ) if $cb->{'Error'};
            die $msg;
        }

        # State Machine:

        # Parens are highest priority
        if ( $current & OPEN_PAREN ) {
            $cb->{'open_paren'}->();
            $depth++;
            $want = KEYWORD | OPEN_PAREN;
        }
        elsif ( $current & CLOSE_PAREN ) {
            $cb->{'close_paren'}->();
            $depth--;
            $want = AGGREG;
            $want |= CLOSE_PAREN if $depth;
        }
        elsif ( $current & AGGREG ) {
            $cb->{'entry_aggregator'}->( $match );
            $want = KEYWORD | OPEN_PAREN;
        }
        elsif ( $current & KEYWORD ) {
            $key = $match;
            $want = OP;
        }
        elsif ( $current & OP ) {
            $op = $match;
            $want = VALUE;
        }
        elsif ( $current & VALUE ) {
            $value = $match;

            # Remove surrounding quotes and unescape escaped
            # characters from $key, $match
            for ( $key, $value ) {
                if ( /$re_delim/o ) {
                    substr($_,0,1) = "";
                    substr($_,-1,1) = "";
                }
                s!\\(.)!$1!g;
            }

            $cb->{'Condition'}->( $key, $op, $value );

            ($key,$op,$value) = ("","","");
            $want = AGGREG;
            $want |= CLOSE_PAREN if $depth;
        } else {
            my $msg = "Query parser is lost";
            return $cb->{'Error'}->( $msg ) if $cb->{'Error'};
            die $msg;
        }

        $last = $current;
    } # while

    unless( !$last || $last & (CLOSE_PAREN | VALUE) ) {
        my $msg = "Incomplete query, last element ("
            . _BitmaskToString($last)
            . ") is not CLOSE_PAREN or VALUE in '$string'";
        return $cb->{'Error'}->( $msg ) if $cb->{'Error'};
        die $msg;
    }

    if( $depth ) {
        my $msg = "Incomplete query, $depth paren(s) isn't closed in '$string'";
        return $cb->{'Error'}->( $msg ) if $cb->{'Error'};
        die $msg;
    }
}

sub _BitmaskToString {
    my $mask = shift;

    my @res;
    for( my $i = 0; $i<@tokens; $i++ ) {
        next unless $mask & (1<<$i);
        push @res, $tokens[$i];
    }

    my $tmp = join ', ', splice @res, 0, -1;
    unshift @res, $tmp if $tmp;
    return join ' or ', @res;
}

1;
