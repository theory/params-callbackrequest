#!perl -w

# $Id: 03keys.t,v 1.1 2003/08/14 02:05:47 david Exp $

use strict;
use Test::More tests => 9;

BEGIN { use_ok('Params::CallbackExec') }

my $key = 'myCallbackTester';
my $cbs = [];

##############################################################################
# Set up callback functions.
##############################################################################
# Callback to test the value of the package key attribute.
sub test_pkg_key {
    my $cb = shift;
    is( $cb->pkg_key, $key, "Check package key" );
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'test_pkg_key',
              cb      => \&test_pkg_key
            };

##############################################################################
# Callback to test the value returned by the class_key method.
sub test_class_key {
    my $cb = shift;
    is( $cb->class_key, $key, "Check class key" );
}
push @$cbs, { pkg_key => $key,
              cb_key  => 'test_class_key',
              cb      => \&test_class_key
            };

##############################################################################
# Callback to test the value of the trigger key attribute.
sub test_trigger_key {
    my $cb = shift;
    is( $cb->trigger_key, "$key|test_trigger_key_cb", "Check trigger key" );
}
push @$cbs, { pkg_key => $key,
              cb_key  => 'test_trigger_key',
              cb      => \&test_trigger_key
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
# Test the package key.
my %params = ( "$key|test_pkg_key_cb" => 1 );
ok( $cb_exec->execute(\%params), "Execute test_pkg_key callback" );

##############################################################################
# Test the class key.
%params = ( "$key|test_class_key_cb" => 1 );
ok( $cb_exec->execute(\%params), "Execute test_class_key callback" );

##############################################################################
# Test the trigger key.
%params = ( "$key|test_trigger_key_cb" => 1 );
ok( $cb_exec->execute(\%params), "Execute test_trigger_key callback" );

1;
__END__
