package Params::CallbackExec;

use strict;
use Params::Validate ();
use Params::Callback::Exceptions (abbr => [qw(throw_bad_params)]);

use vars qw($VERSION);
$VERSION = 1.10;

BEGIN {
    for my $attr (qw( default_priority
                      default_pkg_key
                      redirected )) {
        no strict 'refs';
        *{$attr} = sub { $_[0]->{$attr} };
    }
}

Params::Validate::validation_options
  ( on_fail => sub { throw_bad_params join '', @_ } );

# We'll use this code reference for cb_classes parameter validation.
my $valid_cb_classes = sub {
    # Just return true if they use the string "ALL".
    return 1 if $_[0] eq 'ALL';
    # Return false if it isn't an array.
    return unless ref $_[0] || '' eq 'ARRAY';
    # Return true if the first value isn't the string "_ALL_";
    return 1 if $_[0]->[0] ne '_ALL_';
    # Return false if there's more than one element in the array.
    return if @{$_[0]} > 1;
    # Change the value from an array to "ALL"!
    $_[0] = 'ALL';
    return 1;
};

my $exception_handler = sub {
    my $err = shift;
    rethrow_exception($err) if ref $err;
    Params::Callback::Exception::Execution->throw
      ( error => "Error thrown by callback: $err",
        callback_error => $err );
};

# Set up the valid parameters to new().
my %valid_params =
  ( default_priority =>
    { type      => Params::Validate::SCALAR,
      callbacks => { 'valid priority' => sub { $_[0] =~ /^\d$/ } },
      default   => 5,
    },

    default_pkg_key =>
    { type      => Params::Validate::SCALAR,
      default   => 'DEFAULT',
    },

    callbacks =>
    { type      => Params::Validate::ARRAYREF,
      optional  => 1,
    },

    pre_callbacks =>
    { type      => Params::Validate::ARRAYREF,
      optional  => 1,
    },

    post_callbacks =>
    { type      => Params::Validate::ARRAYREF,
      optional  => 1,
    },

    cb_classes =>
    { type      => Params::Validate::ARRAYREF | Params::Validate::SCALAR,
      callbacks => { 'valid cb_classes' => $valid_cb_classes },
      optional  => 1,
    },

    ignore_nulls =>
    { type      => Params::Validate::BOOLEAN,
      default   => 0,
    },

    exception_handler =>
    { type      => Params::Validate::CODEREF,
      default   => $exception_handler
    },

  );

BEGIN {
    require Params::Callback;
    Params::Callback::_find_names();
}

sub new {
    my $proto = shift;
    my %p = Params::Validate::validate(@_, \%valid_params);

    # Grab any class callback specifications.
    @p{qw(_cbs _pre _post)} = Params::Callback->_load_classes($p{cb_classes})
      if $p{cb_classes};

    # Process parameter-triggered callback specs.
    if (my $cb_specs = delete $p{callbacks}) {
        my %cbs;
        foreach my $spec (@$cb_specs) {
            # Set the default package key.
            $spec->{pkg_key} ||= $p{default_pkg_key};

            # Make sure that we have a callback key.
            throw_bad_params "Missing or invalid callback key"
              unless $spec->{cb_key};

            # Make sure that we have a valid priority.
            if (defined $spec->{priority}) {
                throw_bad_params "Not a valid priority: '$spec->{priority}'"
                  unless $spec->{priority} =~ /^\d$/;
            } else {
                # Or use the default.
                $spec->{priority} = $p{default_priority};
            }

            # Make sure that we have a code reference.
            throw_bad_params "Callback for package key '$spec->{pkg_key}' " .
              "and callback key '$spec->{cb_key}' not a code reference"
              unless ref $spec->{cb} eq 'CODE';

            # Make sure that the key isn't already in use.
            throw_bad_params "Callback key '$spec->{cb_key}' already used " .
              "by package key '$spec->{pkg_key}'"
              if $p{_cbs}{$spec->{pkg_key}}->{$spec->{cb_key}};

            # Set it up.
            $p{_cbs}{$spec->{pkg_key}}->{$spec->{cb_key}} =
              { cb => $spec->{cb}, priority => $spec->{priority} };
        }
    }

    # Now validate and store any global callbacks.
    foreach my $type (qw(pre post)) {
        if (my $cbs = delete $p{$type . '_callbacks'}) {
            my @gcbs;
            foreach my $cb (@$cbs) {
                # Make it an array unless Params::Callback has already
                # done so.
                $cb = [$cb, 'Params::Callback']
                  unless ref $cb eq 'ARRAY';
                # Make sure that we have a code reference.
                throw_bad_params "Global $type callback not a code reference"
                  unless ref $cb->[0] eq 'CODE';
                push @gcbs, $cb;
            }
            # Keep 'em.
            $p{"_$type"} = \@gcbs;
        }
    }

    # Warn 'em if they're not using any callbacks.
    unless ($p{_cbs} or $p{_pre} or $p{_post}) {
        require Carp;
        Carp::carp("You didn't specify any callbacks.");
    }

    # Let 'em have it.
    return bless \%p, ref $proto || $proto;
}


sub execute {
    my ($self, $params) = @_;
    return $self unless $params;
    throw_bad_params "Parameter '$params' is not a hash reference"
      unless UNIVERSAL::isa($params, 'HASH');

    # Use an array to store the callbacks according to their priorities. Why
    # an array when most of its indices will be undefined? Well, because I
    # benchmarked it vs. a hash, and found a very negligible difference when
    # the array had only element five filled (with no 6-9 elements) and the
    # hash had only one element. Furthermore, in all cases where the array had
    # two elements (with the other 8 undef), it outperformed the two-element
    # hash every time. But really this just starts to come down to very fine
    # differences compared to the work that the callbacks will likely be
    # doing, anyway. And in the meantime, the array is just easier to use,
    # since the priorities are just numbers, and its easist to unshift and
    # push on the pre- and post- request callbacks than to stick them onto a
    # hash. In short, the use of arrays is cleaner, easier to read and
    # maintain, and almost always just as fast or faster than using hashes. So
    # that's the way it'll be.
    my (@cbs, %cbhs);
    if ($self->{_cbs}) {
        foreach my $k (keys %$params) {
            # Strip off the '.x' that an <input type="image" /> tag creates.
            (my $chk = $k) =~ s/\.x$//;
            if ((my $key = $chk) =~ s/_cb(\d?)$//) {
                # It's a callback field. Grab the priority.
                my $priority = $1;

                # Skip callbacks without values, if necessary.
                next if $self->{ignore_nulls} &&
                  (! defined $params->{$k} || $params->{$k} eq '');

                if ($chk ne $k) {
                    # Some browsers will submit $k.x and $k.y instead of just
                    # $k for <input type="image" />, a field that can only be
                    # submitted once for a given page. So skip it if we've
                    # already seen this arg.
                    next if exists $params->{$chk};
                    # Otherwise, add the unadorned key to $params with a true
                    # value.
                    $params->{$chk} = 1;
                }

                # Find the package key and the callback key.
                my ($pkg_key, $cb_key) = split /\|/, $key, 2;
                next unless $pkg_key;

                # Find the callback.
                my $cb;
                my $class = $self->{_cbs}{$pkg_key} or
                  Params::Callback::Exception::InvalidKey->throw
                    ( error   => "No such callback package '$pkg_key'",
                      callback_key => $chk );

                if (ref $class) {
                    # It's a functional callback. Grab it.
                    $cb = $class->{$cb_key}{cb} or
                      Params::Callback::Exception::InvalidKey->throw
                        ( error   => "No callback found for callback key '$chk'",
                          callback_key => $chk );

                    # Get the specified priority if none was included in the
                    # callback key.
                    $priority = $class->{$cb_key}{priority}
                      unless $priority ne '';
                    $class = 'Params::Callback';
                } else {
                    # It's a method callback. Get it from the class.
                    $cb = $class->_get_callback($cb_key, \$priority) or
                      Params::Callback::Exception::InvalidKey->throw
                        ( error   => "No callback found for callback key '$chk'",
                          callback_key => $chk );
                }

                # Push the callback onto the stack, along with the parameters
                # for the construction of the Params::Callback object that
                # will be passed to it.
                $cbhs{$class} ||= $class->new( params  => $params,
                                               cb_exec => $self,
                                             );
                push @{$cbs[$priority]},
                  [ $cb, $cbhs{$class},
                    [ $priority, $cb_key, $pkg_key, $chk, $params->{$k} ]
                  ];
            }
        }
    }

    # Put any pre and post callbacks onto the stack.
    if ($self->{_pre} or $self->{_post}) {
        my $params = [ params  => $params,
                       cb_exec => $self ];
        unshift @cbs,
          [ map { [ $_->[0], $cbhs{$_} || $_->[1]->new(@$params), [] ] }
            @{$self->{_pre}} ]
          if $self->{_pre};

        push @cbs,
          [ map { [ $_->[0], $cbhs{$_} || $_->[1]->new(@$params), [] ] }
            @{$self->{_post}} ]
          if $self->{_post};
    }

    # Now execute the callbacks.
    eval {
        local $SIG{__DIE__} = $self->{exception_handler};
        foreach my $cb_list (@cbs) {
            # Skip it if there are no callbacks for this priority.
            next unless $cb_list;
            foreach my $cb_data (@$cb_list) {
                my ($cb, $cbh, $cbargs) = @$cb_data;
                # Cheat! But this keeps them read-only for the client.
                @{$cbh}{qw(priority cb_key pkg_key trigger_key value)} =
                  @$cbargs;
                # Execute the callback.
                $cb->($cbh);
            }
        }
    };

    if (my $err = $@) {
        # Just pass exception objects to the exception handler unless it's
        # an abort.
        rethrow_exception($err)
          unless isa_cb_exception($err, 'Abort');
    }

    # We now return to normal processing.
    return $self;
}

1;
__END__

=begin comment

=head1 ABSTRACT

Params::CallbackExec provides functional and object-oriented callbacks to
method and function parameters.

=end comment

=cut
