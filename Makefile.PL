use ExtUtils::MakeMaker;

my @args =
  ( NAME         => 'Params::CallbackRequest',
    VERSION_FROM => 'lib/Params/CallbackRequest.pm', # finds $VERSION
    PREREQ_PM    => { Params::Validate => 0.59,
                      Exception::Class => 1.10,
                      Test::Simple     => 0.17,
                    }
  );

push @args, (ABSTRACT_FROM => 'lib/Params/CallbackRequest.pm',
             AUTHOR        => 'David Wheeler <david@kineticode.com>')
  if $] >= 5.005;

WriteMakefile(@args);
