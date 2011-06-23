use Module::Build;

my $build = Module::Build->new(
    module_name    => 'Params::CallbackRequest',
    license        => 'perl',
    create_makefile_pl => 'traditional',
    configure_requires => { 'Module::Build' => '0.2701' },
    recommends         => { 'Test::Pod'     => '1.20'   },
    build_requires     => {
        'Test::More'    => '0.17',
        'Module::Build' => '0.2701',
    },
    requires       => {
        Params::Validate    => '0.59',
        Exception::Class    => '1.10',
        Test::Simple        => '0.17',
        Attribute::Handlers => '0.77',
        Class::ISA          => 0,
        perl                => 5.006,
    },
);
$build->create_build_script;
