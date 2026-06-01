use 5.008003;
use strict;
use warnings;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
    NAME   => 'Module::Starter::PBP',
    AUTHOR =>
        ['Matthew O. Persico <persicom.cpan@gmail.com>', 'Damian Conway <DCONWAY.CPAN@gmail.org>'],
    VERSION_FROM       => 'lib/Module/Starter/PBP.pm',
    ABSTRACT_FROM      => 'lib/Module/Starter/PBP.pm',
    LICENSE            => 'artistic2',
    CONFIGURE_REQUIRES => {
        'CPAN::Meta'          => '2.150013',
        'ExtUtils::MakeMaker' => '0',
    },
    TEST_REQUIRES => {
        'Perl::Tidy'          => 0,
        'Test::More'          => 0,
        'Test::Pod'           => 0,
        'Test::Pod::Coverage' => 0,
        'Test::Perl::Critic'  => 0,
        'version'             => 0,
    },
    PREREQ_PM => {
        'Module::Starter' => 0,
        'version'         => 0
    },
    dist       => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean      => { FILES    => 'Module-Starter-PBP-*' },
    META_MERGE => {
        'resources' => {
            'repository' => {
                'web'  => 'https://github.com/matthewpersico/Module-Starter-PBP',
                'type' => 'git',
                'url'  => 'https://github.com/matthewpersico/Module-Starter-PBP.git'
            },
            'bugtracker' =>
                { 'web' => 'https://github.com/matthewpersico/Module-Starter-PBP/issues' }
        },
        'meta-spec' => { 'version' => 2 }
    },

);

# Compatibility with old versions of ExtUtils::MakeMaker
unless (eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 }) {
    my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES} || {};
    @{ $WriteMakefileArgs{PREREQ_PM} }{ keys %$test_requires } = values %$test_requires;
}

unless (eval { ExtUtils::MakeMaker->VERSION('6.55_03'); 1 }) {
    my $build_requires = delete $WriteMakefileArgs{BUILD_REQUIRES} || {};
    @{ $WriteMakefileArgs{PREREQ_PM} }{ keys %$build_requires } = values %$build_requires;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
    unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };
delete $WriteMakefileArgs{MIN_PERL_VERSION}
    unless eval { ExtUtils::MakeMaker->VERSION('6.48'); 1 };
delete $WriteMakefileArgs{LICENSE}
    unless eval { ExtUtils::MakeMaker->VERSION('6.31'); 1 };

WriteMakefile(%WriteMakefileArgs);
