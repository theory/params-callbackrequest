#!perl -w

# $Id: 02priority.t,v 1.3 2003/08/15 22:42:08 david Exp $

use strict;
use Test::More tests => 30;

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
    $val = $cb->priority if $val eq 'def';
    $params->{result} .= " $val";
}

sub chk_priority {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback');
    my $val = $cb->value;
    is( $cb->priority, $val, "Check priority value '$val'" );
}

sub def_priority {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback');
    is( $cb->priority, 5, "Check default priority" );
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'priority',
              cb      => \&priority,
              priority => 6
            },
            { pkg_key => $key,
              cb_key  => 'chk_priority',
              cb      => \&chk_priority,
              priority => 2
            },
            { pkg_key => $key,
              cb_key  => 'def_priority',
              cb      => \&def_priority,
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
is( $params{result}, " 0 1 2 4 6 7 9", "Check priority result" );

##############################################################################
# Test the default priority.
%params = ( "$key|def_priority_cb" => 1);
ok( $cb_exec->execute(\%params), "Execute default priority callback" );

##############################################################################
# Check various priority values.
%params = (  "$key|chk_priority_cb0" => 0,
                "$key|chk_priority_cb2" => 2,
                "$key|chk_priority_cb9" => 9,
                "$key|chk_priority_cb7" => 7,
                "$key|chk_priority_cb1" => 1,
                "$key|chk_priority_cb4" => 4,
                "$key|chk_priority_cb"  => 2 );
ok( $cb_exec->execute(\%params), "Execute priority values" );


1;
__END__
