package Params::Callback;

use strict;
use Params::Validate ();
use Params::Callback::Exceptions (abbr => [qw(throw_bad_params)]);

use vars qw($VERSION);
$VERSION = 1.10;
use constant DEFAULT_PRIORITY => 5;
use constant REDIRECT => 302;

Params::Validate::validation_options
  ( on_fail => sub { throw_bad_params join '', @_ } );

my $is_num = { 'valid priority' => sub { $_[0] =~ /^\d$/ } };


BEGIN {
    # The object-oriented interface is only supported with the use of
    # Attribute::Handlers in Perl 5.6 and later. We'll use Class::ISA
    # to get a list of all the classes that a class inherits from so
    # that we can tell ApacheHandler::WithCallbacks that they exist and
    # are loaded.
    unless ($] < 5.006) {
        require Attribute::Handlers;
        require Class::ISA;
    }

    for my $attr (qw( cb_exec
                      params
                      apache_req
                      priority
                      cb_key
                      pkg_key
                      trigger_key
                      value )) {
        no strict 'refs';
        *{$attr} = sub { $_[0]->{$attr} };
    }
    *class_key = \&pkg_key;
}

my %valid_params =
  ( cb_exec      =>
    { isa        => 'Params::CallbackExec',
    },

    params =>
    {  type      => Params::Validate::HASHREF,
    },

    apache_req   =>
    { isa        => 'Apache',
      optional   => 1,
    },

    priority =>
    { type      => Params::Validate::SCALAR,
      callbacks => $is_num,
      optional  => 1,
      desc      => 'Priority'
    },

    cb_key =>
    { type      => Params::Validate::SCALAR,
      optional  => 1,
      desc      => 'Callback key'
    },

    pkg_key =>
    { type      => Params::Validate::SCALAR,
      optional  => 1,
      desc      => 'Package key'
    },

    trigger_key =>
    { type      => Params::Validate::SCALAR,
      optional  => 1,
      desc      => 'Trigger key'
    },

    value =>
    { optional  => 1,
      desc      => 'Callback value'
    },
  );

sub new {
    my $proto = shift;
    my %p = Params::Validate::validate(@_, \%valid_params);
    return bless \%p, ref $proto || $proto;
}

##############################################################################
# Subclasses must use register_subclass() to register the subclass. They can
# also use it to set up the class key and a default priority for the subclass,
# But base class CLASS_KEY() and DEFAULT_PRIORITY() methods can also be
# overridden to do that.
my (%priorities, %classes, %pres, %posts, @reqs, %isas, @classes);
sub register_subclass {
    shift; # Not needed.
    my $class = caller;
    return unless UNIVERSAL::isa($class, __PACKAGE__)
      and $class ne __PACKAGE__;
    my $spec = { default_priority =>
                 { type      => Params::Validate::SCALAR,
                   optional  => 1,
                   callbacks => $is_num
                 },
                 class_key =>
                 { type      => Params::Validate::SCALAR,
                   optional  => 1
                 },
               };

    my %p = Params::Validate::validate(@_, $spec);

    # Grab the class key. Default to the actual class name.
    my $ckey = $p{class_key} || $class;

    # Create the CLASS_KEY method if it doesn't exist already.
    unless (defined &{"$class\::CLASS_KEY"}) {
        no strict 'refs';
        *{"$class\::CLASS_KEY"} = sub { $ckey };
    }
    $classes{$class->CLASS_KEY} = $class;

    if (defined $p{default_priority}) {
        # Override any base class DEFAULT_PRIORITY methods.
        no strict 'refs';
        *{"$class\::DEFAULT_PRIORITY"} = sub { $p{default_priority} };
    }

    # Push the class into an array so that we can be sure to process it in
    # the proper order later.
    push @classes, $class;
}

##############################################################################

# This method is called by subclassed methods that want to be
# argument-triggered callbacks.

sub Callback : ATTR(CODE, BEGIN) {
    my ($class, $symbol, $coderef, $attr, $data, $phase) = @_;
    # Validate the arguments. At this point, there's only one allowed,
    # priority. This is to set a priority for the callback method that
    # overrides that set for the class.
    my $spec = { priority =>
                 { type      => Params::Validate::SCALAR,
                   optional  => 1,
                   callbacks => $is_num
                 },
               };
    my %p = Params::Validate::validate(@$data, $spec);
    # Get the priority.
    my $priority = exists $p{priority} ? $p{priority} :
      $class->DEFAULT_PRIORITY;
    # Store the priority under the code reference.
    $priorities{$coderef} = $priority;
}

##############################################################################

# These methods are called by subclassed methods that want to be request
# callbacks.

sub PreCallback : ATTR(CODE, BEGIN) {
    my ($class, $symbol, $coderef) = @_;
    # Store a reference to the code in a temporary location and a pointer to
    # it in the array.
    push @reqs, $coderef;
    push @{$pres{$class}->{__TMP}}, $#reqs;
}

sub PostCallback : ATTR(CODE, BEGIN) {
    my ($class, $symbol, $coderef) = @_;
    # Store a reference to the code in a temporary location and a pointer to
    # it in the array.
    push @reqs, $coderef;
    push @{$posts{$class}->{__TMP}}, $#reqs;
}

##############################################################################
# This method is called by Params::CallbackExec to find the
# names of all the callback methods declared with the PreCallback and
# PostCallback attributes (might handle those declared with the Callback
# attribute at some point, as well -- there's some of it in CVS Revision
# 1.21). This is necessary because, in a BEGIN block, the symbol isn't defined
# when the attribute callback is called. I would use a CHECK or INIT block,
# but mod_perl ignores them. So the solution is to have the callback methods
# save the code references for the methods, make sure that
# Params::CallbackExec is loaded _after_ all the classes that
# inherit from Params::Callback, and have it call this method to go
# back and find the names of the callback methods. The method names will then
# of course be used for the callback names. In mod_perl2, we'll likely be able
# to call this method from a PerlPostConfigHandler instead of making
# ApacheHandler::WithCallbacks do it, thus relieving the enforced loading
# order.
# http://perl.apache.org/docs/2.0/user/handlers/server.html#PerlPostConfigHandler

sub _find_names {
    foreach my $class (@classes) {
        # Find the names of the request callback methods.
        foreach my $type (\%pres, \%posts) {
            # We've stored an index pointing to each method in the @reqs
            # array under __TMP PreCallback() and PostCallback().
            if (my $idxs = delete $type->{$class}{__TMP}) {
                foreach my $idx (@$idxs) {
                    my $code = $reqs[$idx];
                    # Grab the symbol hash for this code reference.
                    my $sym = Attribute::Handlers::findsym($class, $code)
                      or die "Anonymous subroutines not supported. Make " .
                        "sure that Params::CallbackExec loads last";
                    # ApacheHandler::WithCallbacks wants this array reference.
                    $type->{$class}{*{$sym}{NAME}} = [ sub { goto $code },
                                                       $class ];
                }
            }
        }
        # Copy any request callbacks from their parent classes. This is to
        # ensure that rquest callbacks act like methods, even though,
        # technically, they're not.
        $isas{$class} = _copy_meths($class);
    }
     # We don't need these anymore.
    @classes = ();
    @reqs = ();
}

##############################################################################
# This little gem, called by _find_names(), mimics inheritance by copying the
# request callback methods declared for parent class keys into the children.
# Any methods declared in the children will, of course, override. This means
# that the parent methods can never actually be called, since request
# callbacks are called for every request, and thus don't have a class
# association. They still get the correct object passed as their first
# parameter, however.
sub _copy_meths {
    my $class = shift;
    my %seen;
    # Grab all of the super classes.
    foreach my $super (grep { UNIVERSAL::isa($_, __PACKAGE__) }
                       Class::ISA::super_path($class)) {
        # Skip classes we've already seen.
        unless ($seen{$super}) {
            # Copy request callback code references.
            foreach my $type (\%pres, \%posts) {
                if ($type->{$class} and $type->{$super}) {
                    # Copy the methods, but allow newer ones to override.
                    $type->{$class} = { %{ $type->{$super} },
                                        %{ $type->{$class} }
                                      };
                } elsif ($type->{$super}) {
                    # Just copy the methods.
                    $type->{$class} = { %{ $type->{$super} }};
                }
            }
            $seen{$super} = 1;
        }
    }

    # Return an array ref of the super classes.
    return [keys %seen];
}

##############################################################################
# This method is called by Params::CallbackExec to find
# methods for callback classes. This is because Params::Callback stores
# this list of callback classes, not Params::CallbackExec.
# Its arguments are the callback class, the name of the method (callback),
# and a reference to the priority. We'll only assign the priority if it
# hasn't been assigned one already -- that is, it hasn't been _called_ with
# a priority.

sub _get_callback {
    my ($class, $meth, $p) = @_;
    # Get the callback code reference.
    my $c = UNIVERSAL::can($class, $meth) or return;
    # Get the priority for this callback. If there's no priority, it's not
    # a callback, so skip it.
    return unless defined $priorities{$c};
    my $priority = $priorities{$c};
    # Reformat the callback code reference.
    my $code = sub { goto $c };
    # Assign the priority, if necessary.
    $$p = $priority unless $$p ne '';
    # Create and return the callback.
    return $code;
}

##############################################################################
# This method is also called by Params::CallbackExec, where
# the cb_classes parameter passes in a list of callback class keys or the
# string "ALL" to indicate that all of the callback classes should have their
# callbacks loaded for use by the ApacheHandler.

sub _load_classes {
    my ($pkg, $ckeys) = @_;
    # Just return success if there are no classes to be loaded.
    return unless defined $ckeys;
    my ($cbs, $pres, $posts);
    # Process the class keys in the order they're given, or just do all of
    # them if $ckeys eq 'ALL' (checked by ApacheHandler::WithCallbacks).
    foreach my $ckey (ref $ckeys ? @$ckeys : keys %classes) {
        my $class = $classes{$ckey} or
          die "Class with class key '$ckey' not loaded. Did you forget use"
            . " it or to call register_subclass()?";
        # Map the class key to the class for the class and all of its parent
        # classes, all for the benefit of ApacheHandler::WithCallbacks.
        $cbs->{$ckey} = $class;
        foreach my $c (@{$isas{$class}}) {
            next if $c eq __PACKAGE__;
            $cbs->{$c->CLASS_KEY} = $c;
        }
        # Load request callbacks in the order they're defined. Methods
        # inherited from parents have already been copied, so don't worry
        # about them.
        push @$pres, values %{ $pres{$class} } if $pres{$class};
        push @$posts, values %{ $posts{$class} } if $posts{$class};
    }
    return ($cbs, $pres, $posts);
}

##############################################################################

sub redirect {
    my ($self, $url, $wait, $status) = @_;
    $status ||= REDIRECT;
    if (my $r = $self->apache_req) {
        $r->method('GET');
        $r->headers_in->unset('Content-length');
        $r->err_header_out( Location => $url );
    }
    my $cb_exec = $self->cb_exec;
    $cb_exec->{_status} = $status;
    $cb_exec->{redirected} = $url;
    $self->abort($status) unless $wait;
}

##############################################################################

sub redirected { $_[0]->cb_exec->redirected }

##############################################################################

sub abort {
    my ($self, $aborted_value) = @_;
    # Should I use an accessor here?
    $self->cb_exec->{_status} = $aborted_value;
    Params::Callback::Exception::Abort->throw
        ( error => ref $self . '->abort was called',
          aborted_value => $aborted_value );
}

##############################################################################

sub aborted {
    my ($self, $err) = @_;
    $err = $@ unless defined $err;
    return Params::Callback::Exceptions::isa_cb_exception( $err, 'Abort' );
}

1;
__END__
