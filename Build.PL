use Module::Build;

my $build = Module::Build->new(
    module_name    => 'Params::CallbackRequest',
    license        => 'perl',
    requires       => {
        Params::Validate    => '0.59',
        Exception::Class    => '1.10',
        Test::Simple        => '0.17',
        Attribute::Handlers => '0.77',
        Class::ISA          => 0,
        perl                => '5.6.0',
    },
    build_requires => {
        Test::Simple        => '0.17',
    },
    create_makefile_pl => 'passthrough',
);
$build->create_build_script;
