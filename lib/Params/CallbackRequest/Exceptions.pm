package Params::Callback::Exceptions;

use strict;
use vars qw($VERSION);
$VERSION = 1.10;

use Exception::Class ( 'Params::Callback::Exception' =>
		       { description => 'Params::Callback exception',
                         alias       => 'throw_cb' },

                       'Params::Callback::Exception::InvalidKey' =>
		       { isa         => 'Params::Callback::Exception',
                         description => 'No callback found for callback key',
                         alias       => 'throw_no_cb',
			 fields      => [ qw(callback_key) ] },

                       'Params::Callback::Exception::Execution' =>
		       { isa         => 'Params::Callback::Exception',
                         description => 'Error thrown by callback',
                         alias       => 'throw_cb_exec',
			 fields      => [ qw(callback_key callback_error) ] },

                       'Params::Callback::Exception::Params' =>
		       { isa         => 'Params::Callback::Exception',
                         description => 'Invalid parameter',
                         alias       => 'throw_bad_params',
			 fields      => [ qw(param) ] },

                       'Params::Callback::Exception::Abort' =>
                       { isa         => 'Params::Callback::Exception',
                         fields      => [qw(aborted_value)],
                         alias       => 'throw_abort',
                         description => 'a callback called abort()' },
		     );

sub import {
    my ($class, %args) = @_;

    my $caller = caller;
    if ($args{abbr}) {
	foreach my $name (@{$args{abbr}}) {
	    no strict 'refs';
	    die "Unknown exception abbreviation '$name'"
              unless defined &{$name};
	    *{"${caller}::$name"} = \&{$name};
	}
    }

    no strict 'refs';
    *{"${caller}::isa_cb_exception"} = \&isa_cb_exception;
    *{"${caller}::rethrow_exception"} = \&rethrow_exception;
}



sub isa_cb_exception {
    my ($err, $name) = @_;
    return unless defined $err;

    my $class = "Params::Callback::Exception";
    $class .= "::$name" if $name;
    return UNIVERSAL::isa($err, $class);
}

sub rethrow_exception {
    my $err = shift or return;
    $err->rethrow if UNIVERSAL::can($err, 'rethrow');
    die $err if ref $err;
    Params::Callback::Exception->throw(error => $err);
}

1;
__END__

