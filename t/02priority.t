#!perl -w

# $Id: 02priority.t,v 1.1 2003/08/14 02:05:47 david Exp $

use strict;
use Test::More tests => 12;

BEGIN { use_ok('Params::CallbackExec') }

my $key = 'myCallbackTester';
my $cbs = [];

##############################################################################
# Set up callback functions.
##############################################################################
# Priority callback.
sub priority {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback');
    my $params = $cb->params;
    my $val = $cb->value;
    $val = '5' if $val eq 'def';
    $params->{result} .= " $val";
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'priority',
              cb      => \&priority
            };

##############################################################################
# Construct the CallbackExec object.
##############################################################################

ok( my $cb_exec = Params::CallbackExec->new( callbacks => $cbs),
    "Construct CBExec object" );
isa_ok($cb_exec, 'Params::CallbackExec' );

##############################################################################
# Test the callbacks themselves.
##############################################################################
# Test the priority ordering.
my %params = (  "$key|priority_cb0" => 0,
                "$key|priority_cb2" => 2,
                "$key|priority_cb9" => 9,
                "$key|priority_cb7" => 7,
                "$key|priority_cb1" => 1,
                "$key|priority_cb4" => 4,
                "$key|priority_cb"  => 'def' );

ok( $cb_exec->execute(\%params), "Execute priority callback" );
is( $params{result}, " 0 1 2 4 5 7 9", "Check priority result" );


1;
__END__
