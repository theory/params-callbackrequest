#!perl -w

# $Id: 06object_request.t,v 1.1 2003/08/16 00:48:48 david Exp $

use strict;
use Test::More;
my $base_key;

##############################################################################
# Figure out if the current configuration can handle OO callbacks.
BEGIN {
    plan skip_all => 'Object-oriented callbacks require Perl 5.6.0 or later'
      if $] < 5.006;

    plan skip_all => 'Attribute::Handlers and Class::ISA required for' .
      ' object-oriented callbacks'
      unless eval { require Attribute::Handlers }
      and eval { require Class::ISA };

    plan tests => 44;

    $base_key = 'OOTester';
}

##############################################################################
# Set up the base callback class.
##############################################################################
package Params::Callback::TestObjects;

use strict;
use base 'Params::Callback';
use constant CLASS_KEY => $base_key;
use constant DEFAULT_PRIORITY => 3;
__PACKAGE__->register_subclass;

sub upperit : PreCallback {
    my $self = shift;
    my $params = $self->params;
    if ($params->{do_upper}) {
        main::isa_ok($self, 'Params::Callback');
        main::isa_ok($self, __PACKAGE__);
        $params->{result} = uc $params->{result};
    }
}

sub lowerit : PostCallback {
    my $self = shift;
    my $params = $self->params;
    if ($params->{do_lower}) {
        main::isa_ok($self, 'Params::Callback');
        main::isa_ok($self, __PACKAGE__);
        $params->{result} = lc $params->{result};
    }
}

sub pre_post : Callback {
    my $self = shift;
    main::isa_ok($self, 'Params::Callback');
    main::isa_ok($self, __PACKAGE__);
    main::is($self->priority, 3, "Check default priority constant" );
    my $params = $self->params;
    $params->{chk_post} = 1;
}

sub chk_post : PostCallback {
    my $self = shift;
    my $params = $self->params;
    if ($params->{chk_post}) {
        main::isa_ok($self, 'Params::Callback');
        main::isa_ok($self, __PACKAGE__);
        # Most of the methods should return undefined values.
        my @res;
        foreach my $meth (qw(value pkg_key cb_key priority trigger_key)) {
            push @res, "$meth => '", $self->$meth, "'\n" if $self->$meth;
        }
        if (@res) {
            $params->{result} = "Oops, some of the accessors have values: @res";
        } else {
            $params->{result} = 'Attributes okay';
        }
    }
}

##############################################################################
# Now set up an a subclass that overrides pre and post execution callbacks,
# and provides a couple of new ones, too.
##############################################################################
package Params::Callback::TestObjects::Sub;
use strict;
use base 'Params::Callback::TestObjects';
use constant CLASS_KEY => $base_key . 'Sub';
__PACKAGE__->register_subclass;

sub upperit : PreCallback {
    my $self = shift;
    $self->SUPER::upperit;
    my $params = $self->params;
    if ($params->{do_upper}) {
        main::isa_ok($self, 'Params::Callback');
        main::isa_ok($self, 'Params::Callback::TestObjects');
        main::isa_ok($self, __PACKAGE__);
        $params->{result} .= ' Overridden';
    }
}

sub lowerit : PostCallback {
    my $self = shift;
    $self->SUPER::lowerit;
    my $params = $self->params;
    if ($params->{do_lower}) {
        main::isa_ok($self, 'Params::Callback');
        main::isa_ok($self, 'Params::Callback::TestObjects');
        main::isa_ok($self, __PACKAGE__);
        $params->{result} .= ' Overridden';
    }
}

# Try totally new methods.
sub sub_pre : PreCallback {
    my $self = shift;
    my $params = $self->params;
    if ($params->{do_lower} or $params->{do_upper}) {
        main::isa_ok($self, 'Params::Callback');
        main::isa_ok($self, 'Params::Callback::TestObjects');
        main::isa_ok($self, __PACKAGE__);
        $params->{result} .= ' PreCallback';
    }
}

sub sub_post : PostCallback {
    my $self = shift;
    my $params = $self->params;
    if ($params->{do_lower} or $params->{do_upper}) {
        main::isa_ok($self, 'Params::Callback');
        main::isa_ok($self, 'Params::Callback::TestObjects');
        main::isa_ok($self, __PACKAGE__);
        $params->{result} .= ' PostCallback';
    }
}

1;

##############################################################################
# Move along, little doggies!
##############################################################################

package main;
use strict;
use_ok( 'Params::CallbackExec' );


##############################################################################
# Make sure that the base pre and post callbacks work properly. Start with
# post.
ok( my $cb_exec = Params::CallbackExec->new(cb_classes => [$base_key]),
    "Construct base callback CBExec" );

##############################################################################
# Start with post.
my %params = (do_lower => 1,
              result => 'LOWER ME, BABY!');
ok( $cb_exec->execute(\%params), "Execute post callback" );
is( $params{result}, 'lower me, baby!', "Check post callback result" );

##############################################################################
# Now check pre.
%params = (do_upper => 1,
           result   => 'taKe mE uP!');
ok( $cb_exec->execute(\%params), "Execute pre callback" );
is( $params{result}, 'TAKE ME UP!', "Check pre callback result" );

##############################################################################
# Make sure that pre and post execution callback inheritance works properly.
ok( $cb_exec = Params::CallbackExec->new
    (cb_classes => [$base_key . 'Sub']),
    "Construct subclasseed callback CBExec" );

##############################################################################
# Post first.
%params = (do_lower => 1,
           result   => 'LOWER ME');
ok( $cb_exec->execute(\%params), "Test subclassed post callback" );
is( $params{result}, 'lower me precallback Overridden PostCallback',
    "Check subclassed post callback result" );

##############################################################################
# Now check pre.
%params = (do_upper => 1,
           result   => 'taKe mE uP aGain!');
ok( $cb_exec->execute(\%params), "Execute subclassed pre callback" );
is( $params{result}, 'TAKE ME UP AGAIN! PRECALLBACK Overridden PostCallback',
    "Check subclassed pre callback result" );

##############################################################################
# Check that no of the unneeded attributes are populated during request
# callbacks.
%params = ("$base_key|pre_post_cb" => 1);
ok( $cb_exec->execute(\%params), "Execute attribute check callback" );
is( $params{result}, 'Attributes okay', "Check attribute check result" );

1;

__END__
