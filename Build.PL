use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name => 'Module::Starter::PBP',
    license     => 'artistic2',
    dist_author =>
        'Matthew O. Persico <persicom.cpan@gmail.com>, Damian Conway <DCONWAY.CPAN@gmail.org>',
    dist_version_from  => 'lib/Module/Starter/PBP.pm',
    configure_requires => {
        'Module::Build' => '0.4004',
    },
    test_requires => {
        'Perl::Tidy'          => 0,
        'Test::More'          => 0,
        'Test::Pod'           => 0,
        'Test::Pod::Coverage' => 0,
        'Test::Perl::Critic'  => 0,
        'version'             => 0,
    },
    add_to_cleanup => ['Module-Starter-PBP-*'],
    meta_merge     => {
        'resources' => {
            'bugtracker' => 'https://github.com/matthewpersico/Module-Starter-PBP/issues',
            'repository' => 'https://github.com/matthewpersico/Module-Starter-PBP'
        }
    },

);

$builder->create_build_script();
