#!perl -w

# $Id: 01basic.t,v 1.2 2003/08/14 05:23:22 david Exp $

use strict;
use Test::More tests => 45;

BEGIN { use_ok('Params::CallbackExec') }

my $key = 'myCallbackTester';
my $cbs = [];

##############################################################################
# Set up callback functions.
##############################################################################
# Simple callback.
sub simple {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback' );
    my $params = $cb->params;
    $params->{result} = 'Success';
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'simple',
              cb      => \&simple
            };

##############################################################################
# Array value callback.
sub array_count {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback' );
    my $params = $cb->params;
    my $val = $cb->value;
    # For some reason, if I don't eval this, then the code in the rest of
    # the function doesn't run!
    eval { isa_ok( $val, 'ARRAY' ) };
    $params->{result} = scalar @$val;
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'array_count',
              cb      => \&array_count
            };

##############################################################################
# Hash value callback.
sub hash_check {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback');
    my $params = $cb->params;
    my $val = $cb->value;
    # For some reason, if I don't eval this, then the code in the rest of
    # the function doesn't run!
    eval { isa_ok( $val, 'HASH' ) };
    $params->{result} = "$val"
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'hash_check',
              cb      => \&hash_check
            };

##############################################################################
# Code value callback.
sub code_check {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback');
    my $params = $cb->params;
    my $val = $cb->value;
    # For some reason, if I don't eval this, then the code in the rest of
    # the function doesn't run!
    eval { isa_ok( $val, 'CODE' ) };
    $params->{result} = $val->();
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'code_check',
              cb      => \&code_check
            };

##############################################################################
# Count the number of times the callback executes.
sub count {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback');
    my $params = $cb->params;
    $params->{result}++;
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'count',
              cb      => \&count
            };

##############################################################################
# Abort callbacks.
sub test_abort {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback');
    my $params = $cb->params;
    $params->{result} = 'aborted';
    $cb->abort;
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'test_abort',
              cb      => \&test_abort
            };

##############################################################################
# Check the aborted value.
sub test_aborted {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback');
    my $params = $cb->params;
    my $val = $cb->value;
    eval { $cb->abort } if $val;
    $params->{result} = $cb->aborted($@) ? 'yes' : 'no';
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'test_aborted',
              cb      => \&test_aborted
            };

##############################################################################
# We'll use this callback just to grab the value of the "submit" parameter.
sub submit {
    my $cb = shift;
    isa_ok( $cb, 'Params::Callback');
    my $params = $cb->params;
    $params->{result} = $params->{submit};
}

push @$cbs, { pkg_key => $key,
              cb_key  => 'submit',
              cb      => \&submit
            };

##############################################################################
# We'll use this callback to change the result to uppercase.
sub upper {
    my $cb = shift;
    my $params = $cb->params;
    if ($params->{do_upper}) {
        isa_ok( $cb, 'Params::Callback');
        $params->{result} = uc $params->{result};
    }
}

##############################################################################
# We'll use this callback to flip the characters of the "submit" parameter.
# The value of the "submit" parameter won't be "racecar!"
sub flip {
    my $cb = shift;
    my $params = $cb->params;
    if ($params->{do_flip}) {
        isa_ok( $cb, 'Params::Callback');
        $params->{submit} = reverse $params->{submit};
    }
}

##############################################################################
# Construct the CallbackExec object.
##############################################################################

ok( my $cb_exec = Params::CallbackExec->new( callbacks      => $cbs,
                                             post_callbacks => [\&upper],
                                             pre_callbacks  => [\&flip] ),
    "Construct CBExec object" );
isa_ok($cb_exec, 'Params::CallbackExec' );

##############################################################################
# Test the callbacks themselves.
##############################################################################
# Try a Simple callback.
my %params = ( "$key|simple_cb" => 1 );
ok( $cb_exec->execute(\%params), "Execute simple callback" );
is( $params{result}, 'Success', "Check simple result" );

##############################################################################
# Test an array reference value.
%params = (  "$key|array_count_cb" => [1,2,3,4,5] );
ok( $cb_exec->execute(\%params), "Execute array count callback" );
is( $params{result}, 5, "Check array count result" );

##############################################################################
# Test a hash reference.
%params = (  "$key|hash_check_cb" => { one => 1 } );
ok( $cb_exec->execute(\%params), "Execute hash check callback" );
is( $params{result}, $params{"$key|hash_check_cb"},
    "Check hash check result" );

##############################################################################
# Test a code reference.
%params = (  "$key|code_check_cb" => sub { 'yes!' } );
ok( $cb_exec->execute(\%params), "Execute code callback" );
is( $params{result}, 'yes!', "Check code result" );

##############################################################################
# Make sure that two similar callbacks set up like image callbacks are getting
# properly executed.
%params = ( "$key|simple_cb.x" => 18,
            "$key|simple_cb.y" => 24 );
ok( $cb_exec->execute(\%params), "Execute image button callback" );
is( $params{result}, 'Success', "Check image button result" );

##############################################################################
# Make sure that the image button parameters cause the callback to be called
# only once.
%params = ( "$key|count_cb.x" => 18,
            "$key|count_cb.y" => 24 );
ok( $cb_exec->execute(\%params), "Execute image button count callback" );
is( $params{result}, 1, "Check image button count result" );

##############################################################################
# Just like the above, but make sure that different priorities execute
# at different times.
%params = ( "$key|count_cb1.x" => 18,
            "$key|count_cb1.y" => 24,
            "$key|count_cb2.x" => 18,
            "$key|count_cb2.y" => 24 );
ok( $cb_exec->execute(\%params), "Execute image button priority callback" );
is( $params{result}, 2, "Check image button priority result" );

##############################################################################
# Test the abort functionality. The abort callback's higher priority should
# cause it to prevent simple from being called.
%params = ( "$key|simple_cb" => 1,
            "$key|test_abort_cb0" => 1 );
ok( $cb_exec->execute(\%params), "Execute abort callback" );
is( $params{result}, 'aborted', "Check abort result" );

##############################################################################
# Test the aborted method.
%params = ( "$key|test_aborted_cb" => 1 );
ok( $cb_exec->execute(\%params), "Execute aborted callback" );
is( $params{result}, 'yes', "Check aborted result" );

##############################################################################
# Test the pre-execution callbacks.
my $string = 'yowza';
%params = ( "$key|submit_cb" => 1,
            submit           => $string,
            do_flip         => 1 );
ok( $cb_exec->execute(\%params), "Execute pre callback" );
is( $params{result}, reverse($string), "Check pre result" );


##############################################################################
# Test the post-execution callbacks.
%params = ( "$key|simple_cb" => 1,
            do_upper => 1 );
ok( $cb_exec->execute(\%params), "Execute post callback" );
is( $params{result}, 'SUCCESS', "Check post result" );

##############################################################################
# Now make sure that a callback with a value executes.
ok( my $new_cb_exec = Params::CallbackExec->new( callbacks           => $cbs,
                                                 exec_null_cb_values => 0),
    "Create new CBExec that ignores nulls" );
%params = ( "$key|simple_cb" => 1);
ok( $new_cb_exec->execute(\%params), "Execute simple callback" );
is( $params{result}, 'Success', "Check simple result" );

# And try it with a null value.
%params = ( "$key|simple_cb" => '');
ok( $new_cb_exec->execute(\%params), "Execute null simple callback" );
is( $params{result}, undef, "Check null simple result" );


1;
__END__
