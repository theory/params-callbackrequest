#!perl -w

# $Id: 05object.t,v 1.1 2003/08/15 02:06:36 david Exp $

use strict;
use Test::More;
my $base_key = 'OOTester';

##############################################################################
# Figure out if an apache configuration was prepared by Makefile.PL.
BEGIN {
    plan skip_all => 'Object-oriented callbacks require Perl 5.6.0 or later'
      if $] < 5.006;

    plan skip_all => 'Attribute::Handlers and Class::ISA required for' .
      ' object-oriented callbacks'
      unless eval { require Attribute::Handlers }
      and eval { require Class::ISA };

    plan tests => 85;
}

##############################################################################
# Set up the callback class.
##############################################################################
package Params::Callback::TestObjects;

use strict;
use base 'Params::Callback';
__PACKAGE__->register_subclass( class_key => $base_key);

sub simple : Callback {
    my $self = shift;
    main::isa_ok($self, 'Params::Callback');
    main::isa_ok($self, __PACKAGE__);
    my $params = $self->params;
    $params->{result} = 'Simple Success';
}

sub complete : Callback(priority => 3) {
    my $self = shift;
    main::isa_ok($self, 'Params::Callback');
    main::isa_ok($self, __PACKAGE__);
    my $params = $self->params;
    $params->{result} = 'Complete Success';
}

sub inherit : Callback {
    my $self = shift;
    my $params = $self->params;
    $params->{result} = UNIVERSAL::isa($self, 'Params::Callback')
      ? 'Yes' : 'No';
}

sub highest : Callback(priority => 0) {
    my $self = shift;
    my $params = $self->params;
    $params->{result} = 'Priority ' . $self->priority;
}

sub upperit : PreCallback {
    my $self = shift;
    my $params = $self->params;
    $params->{result} = uc $params->{result} if $params->{do_upper};
}

sub pre_post : Callback {
    my $self = shift;
    my $params = $self->params;
    $params->{chk_post} = 1;
}

sub lowerit : PostCallback {
    my $self = shift;
    my $params = $self->params;
    $params->{result} = lc $params->{result} if $params->{do_lower};
}

sub class : Callback {
    my $self = shift;
    main::isa_ok( $self, __PACKAGE__);
    main::isa_ok( $self, $self->value);
}

1;

##############################################################################
# Now set up an emtpy callback subclass.
##############################################################################
package Params::Callback::TestObjects::Empty;
use strict;
use base 'Params::Callback::TestObjects';
__PACKAGE__->register_subclass( class_key => $base_key . 'Empty');
1;

##############################################################################
# Now set up an a subclass that overrides a parent method.
##############################################################################
package Params::Callback::TestObjects::Sub;
use strict;
use base 'Params::Callback::TestObjects';
__PACKAGE__->register_subclass( class_key => $base_key . 'Sub');

# Try a method with the same name as one in the parent, and which
# calls the super method.
sub inherit : Callback {
    my $self = shift;
    $self->SUPER::inherit;
    my $params = $self->params;
    $params->{result} .= ' and ';
    $params->{result} .= UNIVERSAL::isa($self, 'Params::Callback::TestObjects')
      ? 'Yes' : 'No';
}

# Try a totally new method.
sub subsimple : Callback {
    my $self = shift;
    my $params = $self->params;
    $params->{result} = 'Subsimple Success';
}

# Try a totally new method.
sub simple : Callback {
    my $self = shift;
    my $params = $self->params;
    $params->{result} = 'Oversimple Success';
}



1;

##############################################################################
# Meanwhile, back at the ranch...
##############################################################################
package main;

my %classes = ( $base_key           => 'Params::Callback::TestObjects',
                $base_key . 'Sub'   => 'Params::Callback::TestObjects::Sub',
                $base_key . 'Empty' => 'Params::Callback::TestObjects::Empty');

use_ok('Params::CallbackExec');
my $all = 'ALL';
for my $key ($base_key, $base_key . "Empty", $all) {
    # Create the CBExec object.
    my $cb_exec;
    if ($key eq 'ALL') {
        ok( $cb_exec = Params::CallbackExec->new( cb_classes => $key ),
            "Construct $key CBExec object" );
        $key = $base_key;
    } else {
        ok( $cb_exec = Params::CallbackExec->new
            ( cb_classes => [$key, $base_key . 'Sub']),
            "Construct $key CBExec object" );
    }

    ##########################################################################
    # Now make sure that the simple callback executes.
    my %params = ("$key|simple_cb" => 1);
    ok( $cb_exec->execute(\%params), "Execute simple callback" );
    is( $params{result}, 'Simple Success', "Check simple result" );

    ##########################################################################
    # And the "complete" callback.
    %params = ("$key|complete_cb" => 1);
    ok( $cb_exec->execute(\%params), "Execute complete callback" );
    is( $params{result}, 'Complete Success', "Check complete result" );

    ##########################################################################
    # Check the class name.
    %params = ("$key|inherit_cb" => 1);
    ok( $cb_exec->execute(\%params), "Execute inherit callback" );
    is( $params{result}, 'Yes', "Check inherit result" );

    ##########################################################################
    # Check class inheritance and SUPER method calls.
    %params = ("$base_key\Sub|inherit_cb" => 1);
    ok( $cb_exec->execute(\%params), "Execute SUPER inherit callback" );
    is( $params{result}, 'Yes and Yes', "Check SUPER inherit result" );

    ##########################################################################
    # Try pre-execution callbacks.
    %params = (do_upper => 1,
               result   => 'upPer_mE');
    ok( $cb_exec->execute(\%params), "Execute pre callback" );
    is( $params{result}, 'UPPER_ME', "Check pre result" );

    ##########################################################################
    # Try post-execution callbacks.
    %params = ("$key|simple_cb" => 1,
               do_lower => 1);
    ok( $cb_exec->execute(\%params), "Execute post callback" );
    is( $params{result}, 'simple success', "Check post result" );

    ##########################################################################
    # Try a method defined only in a subclass.
    %params = ("$base_key\Sub|subsimple_cb" => 1);
    ok( $cb_exec->execute(\%params), "Execute subsimple callback" );
    is( $params{result}, 'Subsimple Success', "Check subsimple result" );

    ##########################################################################
    # Try a method that overrides its parent but doesn't call its parent.
    %params = ("$base_key\Sub|simple_cb" => 1);
    ok( $cb_exec->execute(\%params), "Execute oversimple callback" );
    is( $params{result}, 'Oversimple Success', "Check oversimple result" );

    ##########################################################################
    # Try a method that overrides its parent but doesn't call its parent.
    %params = ("$base_key\Sub|simple_cb" => 1);
    ok( $cb_exec->execute(\%params), "Execute oversimple callback" );
    is( $params{result}, 'Oversimple Success', "Check oversimple result" );

    ##########################################################################
    # Check that the proper class ojbect is constructed.
    %params = ("$key|class_cb" => $classes{$key});
    ok( $cb_exec->execute(\%params), "Execute class callback" );
}

__END__
