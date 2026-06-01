package Module::Starter::PBP;
use base 'Module::Starter::Simple';

use warnings;
use strict;
use Carp;
use Data::Dumper;
use File::Copy;

our $VERSION = '0.003';

sub module_guts {
    my $self    = shift;
    my %context = (
        'MODULE NAME' => shift,
        'RT NAME'     => shift,
        'DATE'        => scalar localtime,
        'YEAR'        => $self->_thisyear(),
    );

    return $self->_load_and_expand_template('Module.pm', \%context);
}

sub Makefile_PL_guts {
    my $self = shift;

    my $meta_merge = $self->Makefile_PL_meta_merge();
    $meta_merge =~ s/^\s*META_MERGE\s*=>\s*//i;

    my %context = (
        'MAIN MODULE'    => shift,
        'MAIN PM FILE'   => shift,
        'DATE'           => scalar localtime,
        'YEAR'           => $self->_thisyear(),
        'META_MERGE_opt' => eval $meta_merge,     ## no critic (BuiltinFunctions::ProhibitStringyEval)
    );

    return $self->_load_and_expand_template('Makefile.PL', \%context);
}

sub Build_PL_guts {
    my $self = shift;

    my $meta_merge = $self->Build_PL_meta_merge();
    $meta_merge =~ s/^\s*META_MERGE\s*=>\s*//i;

    my %context = (
        'MAIN MODULE'    => shift,
        'MAIN PM FILE'   => shift,
        'DATE'           => scalar localtime,
        'YEAR'           => $self->_thisyear(),
        'META_MERGE_opt' => eval $meta_merge,     ## no critic (BuiltinFunctions::ProhibitStringyEval)
    );

    return $self->_load_and_expand_template('Build.PL', \%context);
}

sub Changes_guts {
    my $self = shift;

    my %context = (
        'DATE' => scalar localtime,
        'YEAR' => $self->_thisyear(),
    );

    return $self->_load_and_expand_template('Changes', \%context);
}

sub README_guts {
    my $self = shift;

    my %context = (
        'BUILD INSTRUCTIONS' => shift,
        'DATE'               => scalar localtime,
        'YEAR'               => $self->_thisyear(),
    );

    return $self->_load_and_expand_template('README', \%context);
}

sub t_guts {
    my $self    = shift;
    my @modules = @_;
    my %context = (
        'DATE' => scalar localtime,
        'YEAR' => $self->_thisyear(),
    );

    my %t_files;
    for my $test_file (map { my $x = $_; $x =~ s{\A .*/t/}{}xms; $x; }
        glob "$self->{template_dir}/t/*") {
        $t_files{$test_file} = $self->_load_and_expand_template("t/$test_file", \%context);
    }

    my $nmodules    = @modules;
    my $main_module = $modules[0];
    my $use_lines   = join("\n", map {"    use_ok('$_');"} @modules);

    $t_files{'00.load.t'} = <<"END_LOAD";
use strict;
use warnings;

use Test::More tests => $nmodules;

BEGIN {
$use_lines
}

diag("Testing $main_module \$${main_module}::VERSION");
END_LOAD

    return %t_files;
}

sub post_create_distro {
    my $self = shift;

    if (move(
            File::Spec->catfile($self->{basedir}, 't', 'perltidyrc'),
            File::Spec->catfile($self->{basedir}, '.perltidyrc')
        )
    ) {
        my $manifest_filepath = File::Spec->catfile($self->{basedir}, 'MANIFEST');
        if (-f $manifest_filepath) {
            open my $fh, '<', File::Spec->catfile($self->{basedir}, 'MANIFEST');
            my @orig_lines = <$fh>;
            close $fh;
            my @lines = map {
                my $du = $_;
                $du =~ s|t/perltidyrc|.perltidyrc|;
                $du =~ s/^(\S+\s+)(?!#)(.+)$/$1#$2/;    # Adds comment char where missing.
                $du
            } @orig_lines;
            push @lines, "META.json # Will be created by 'make dist'\n";
            push @lines, "META.yml  # Will be created by 'make dist'\n";
            open $fh, '>', File::Spec->catfile($self->{basedir}, 'MANIFEST');
            $fh->print(@lines);
            close $fh;
            for (my $i = 0; $i < scalar(@orig_lines); $i++) {
                if ($orig_lines[$i] ne $lines[$i]) {
                    chomp $orig_lines[$i];
                    chomp $lines[$i];
                    warn "Updated MANIFEST: '$orig_lines[$i]' => '$lines[$i]'\n";
                }
            }
        }
    }
}

sub _comma_list {
    if ($_[1] eq 'Makefile.PL') {
        # Makefile.PL takes an array ref of individual strings, so we quote
        # each string..
        return q(') . join(q(', '), @{ $_[0] }) . q(');
    } else {
        # Text can just be joined.
        return join(', ', @{ $_[0] });
    }
}

sub _placeholder_subst {
    my ($placeholder, $context_ref, $rel_file_path) = @_;
    if (not exists $context_ref->{$placeholder}) {
        if ($placeholder =~ /_opt$/) {
            return '';
        } else {
            die "Unknown placeholder <$placeholder> in $rel_file_path\n";
        }
    }
    my $reftype = ref($context_ref->{$placeholder});
    if ($reftype eq 'ARRAY') {
        if ($placeholder eq 'AUTHOR') {
            return _comma_list($context_ref->{$placeholder}, $rel_file_path);
        } else {
            return $context_ref->{$placeholder}->[0];
        }
    }

    if ($reftype eq 'HASH') {
        my $key = $placeholder;
        $key =~ s/ /_/g;
        $key =~ s/_opt//;
        $key = lc($key) if $rel_file_path eq 'Build.PL';
        my $text = Data::Dumper->Dump([$context_ref->{$placeholder}]);
        chomp($text);
        $text =~ s/\$VAR1 = /$key => /;
        $text =~ s/;$/,/;
        return $text;
    }

    return $context_ref->{$placeholder};
}

sub _load_and_expand_template {
    my ($self, $rel_file_path, $context_ref) = @_;

    @{$context_ref}{ map {uc} keys %$self } = values %$self;

    # Allow spaces instead of underscores...
    for my $key (sort keys %$context_ref) {
        my $value = $context_ref->{$key};
        $context_ref->{$key} = $value if $key =~ tr/_/ /;
    }

    die "Can't find directory that holds Module::Starter::PBP templates\n",
        "(no 'template_dir: <directory path>' in config file)\n"
        if not defined $self->{template_dir};

    die "Can't access Module::Starter::PBP template directory\n",
        "(perhaps 'template_dir: $self->{template_dir}' is wrong in config file?)\n"
        if not -d $self->{template_dir};

    my $abs_file_path = "$self->{template_dir}/$rel_file_path";

    die "The Module::Starter::PBP template: $rel_file_path\n",
        "isn't in the template directory ($self->{template_dir})\n\n"
        if not -e $abs_file_path;

    die "The Module::Starter::PBP template: $rel_file_path\n",
        "isn't readable in the template directory ($self->{template_dir})\n\n"
        if not -r $abs_file_path;

    open my $fh, '<', $abs_file_path or croak $!;
    local $/;
    my $text = <$fh>;

    $text =~ s{<([A-Z ]+( opt){0,1})>}{_placeholder_subst($1, $context_ref, $rel_file_path)}xmseg;

    return $text;
}

sub import {
    my $class = shift;
    my ($setup, @other_args) = @_;

    # If this is not a setup request,
    # refer the import request up the hierarchy...
    if (@other_args || !$setup || $setup ne 'setup') {
        return $class->SUPER::import(@_);
    }

    # Otherwise, gather the necessary tools...
    use ExtUtils::Command qw( mkpath );
    use File::Spec;
    local $| = 1;

    # Locate the home directory...
    if (!defined $ENV{HOME}) {
        print 'Please enter the full path of your home directory: ';
        $ENV{HOME} = <>;
        chomp $ENV{HOME};
        croak 'Not a valid directory. Aborting.'
            if !-d $ENV{HOME};
    }

    # Create the directories...
    my $template_dir = File::Spec->catdir($ENV{HOME}, '.module-starter', 'PBP');
    if (not -d $template_dir) {
        print {*STDERR} "Creating $template_dir...";
        local @ARGV = $template_dir;
        mkpath;
        print {*STDERR} "done.\n";
    }

    my $template_test_dir = File::Spec->catdir($ENV{HOME}, '.module-starter', 'PBP', 't');
    if (not -d $template_test_dir) {
        print {*STDERR} "Creating $template_test_dir...";
        local @ARGV = $template_test_dir;
        mkpath;
        print {*STDERR} "done.\n";
    }

    # Create or update the config file (making a backup, of course)...
    my $config_file = File::Spec->catfile($ENV{HOME}, '.module-starter', 'config');

    my @config_info;

    if (-e $config_file) {
        print {*STDERR} "Backing up $config_file...";
        my $backup = File::Spec->catfile($ENV{HOME}, '.module-starter', 'config.bak');
        rename($config_file, $backup);
        print {*STDERR} "done.\n";

        print {*STDERR} "Updating $config_file...";
        open my $fh, '<', $backup or die "$config_file: $!\n";
        @config_info = grep { not /\A (?: template_dir | plugins ) : /xms } <$fh>;
        close $fh or die "$config_file: $!\n";
    } else {
        print {*STDERR} "Creating $config_file...\n";

        my $author = _prompt_for('your full name');
        my $email  = _prompt_for('an email address');

        @config_info = (
            "author:  $author\n",
            "email:   $email\n",
            "builder: ExtUtils::MakeMaker Module::Build\n",
        );

        print {*STDERR} "Writing $config_file...\n";
    }

    push @config_info, ("plugins: Module::Starter::PBP\n", "template_dir: $template_dir\n",);

    open my $fh, '>', $config_file or die "$config_file: $!\n";
    print {$fh} @config_info or die "$config_file: $!\n";
    close $fh                or die "$config_file: $!\n";
    print {*STDERR} "done.\n";

    print {*STDERR} "Installing templates...\n";

    # Then install the various files...
    my @files = (
        ['Build.PL'], ['Makefile.PL'], ['README'], ['Changes'], ['Module.pm'],
        ['t', 'perltidyrc'],
        ['t', 'pod-coverage.t'],
        ['t', 'pod.t'],
        ['t', 'perlcritic.t'],
        ['t', 'tidy.t']
    );

    my %contents_of = do { local $/; "", split /_____\[ (\S+) \]_+\n/, <DATA> };

    # In order not to confuse pod when it is processing the PBP.pm file, pod
    # headers in the templates are prefixed with a !. This for loop removes
    # those before we write the templates.
    for (values %contents_of) {
        s/^!=([a-z])/=$1/gxms;
    }

    for my $ref_path (@files) {
        my $abs_path
            = File::Spec->catfile( $ENV{HOME}, '.module-starter', 'PBP', @{$ref_path} );
        print {*STDERR} "\t$abs_path...";
        open my $fh, '>', $abs_path or die "$abs_path: $!\n";
        print {$fh} $contents_of{ $ref_path->[-1] } or die "$abs_path: $!\n";
        close $fh                                   or die "$abs_path: $!\n";
        print {*STDERR} "done\n";
    }
    print {*STDERR} "Installation complete.\n";

    exit;
}

sub _prompt_for {
    my ($requested_info) = @_;
    my $response;
    RESPONSE: while (1) {
        print "Please enter $requested_info: ";
        $response = <>;
        if (not defined $response) {
            warn "\n[Installation cancelled]\n";
            exit;
        }
        $response =~ s/\A \s+ | \s+ \Z//gxms;
        last RESPONSE if $response =~ /\S/;
    }
    return $response;
}

1;    # Magic true value required at end of module

=pod

=head1 NAME

Module::Starter::PBP - Create a module as recommended in "Perl Best Practices"


=head1 VERSION

This document describes Module::Starter::PBP version 0.003


=head1 SYNOPSIS

    # In your  ~/.module-starter/config file...

    author:  <Your Name>
    email:   <your@email.addr>
    plugins: Module::Starter::PBP
    template_dir: </some/absolute/path/name>


    # Then on the command-line...

    > module-starter --module=Your::New::Module


    # Or, if you're lazy and happy to go with
    # the recommendations in "Perl Best Practices"...

    > perl -MModule::Starter::PBP=setup


=head1 DESCRIPTION

This module implements a simple approach to creating modules and their support
files, based on the Module::Starter approach. Module::Starter needs to be
installed before this module can be used.

When used as a Module::Starter plugin, this module allows you to specify a
simple directory of templates which are filled in with module-specific
information, and thereafter form the basis of your new module.

The default templates that this module initially provides are based on
the recommendations in the book "Perl Best Practices".


=head1 INTERFACE

This module simply acts as a plugin for Module::Starter. So it uses the same
command-line interface as that module.

The template files it is to use are specified in your Module::Starter
C<config> file, by adding a C<template_dir> configuration variable that
gives the full path name of the directory in which you want to put
the templates.

The easiest way to set up this C<config> file, the associated directory, and
the necessary template files is to type:

    > perl -MModule::Starter::PBP=setup

on the command line. You will then be asked for your name, email address, and
the full path name of the directory where you want to keep the templates,
after which they will be created and installed.

Then you can create a new module by typing:

    > module-starter --module=Your::New::Module


=head2 Template format

The templates are plain files named:

        Build.PL
        Makefile.PL
        README
        Changes
        Module.pm
        t/whatever_you_like.t
        t/perltidyrc

The C<Module.pm> file is the template for the C<.pm> file for your module. Any
*.t files in the C<t/> subdirectory become the templates for the testing files
of your module. The 't/perltidyrc' template file will end up as '.perltidyrc'
in the top level directory of the distribution. All the remaining files are
templates for the ditribution files of the same names.

In those files, the following placeholders are replaced by the appropriate
information specific to the file:

=over

=item <AUTHOR>

The nominated author. Taken from the C<author> setting in your Module::Starter
C<config> file. If any other authors are specified on the command line, they
are added.

=item <BUILD INSTRUCTIONS>

Makefile or Module::Build instructions. Computed automatically according to
the C<builder> setting in your Module::Starter C<config> file.

=item <DATE>

The current date (as returned by C<localtime>).

=item <DISTRO>

The name of the complete module distribution. Computed automatically from the
name of the module.

=item <EMAIL>

Where to send feedback. Taken from the C<email> setting in your Module::Starter
C<config> file. This placeholder is not handled well in Module::Starter.

=item <LICENSE>

The licence under which the module is released. Taken from the C<license>
setting in your Module::Starter C<config> file.

=item <MAIN MODULE>

The name of the main module of the distribution.

=item <MAIN PM FILE>

The name of the C<.pm> file for the main module.

=item <MODULE NAME>

The name of the current module being created within the distribution.

=item <RT NAME>

The name to use for bug reports to the RT system.
That is:

    Please report any bugs or feature requests to
    bug-<RT NAME>@rt.cpan.org>

=item <YEAR>

The current year. Computed automatically

=back

=head1 MANIFEST

The MANIFEST is generated when after the templates are copied and
transformed. The MANIFEST also assumes the existance of META.yml and
META.json. However, those file are generated when creating a distribution. We
suggest your do NOT add either file to your source code control system. If you
want to keep those files as references in source control, put the MYMETA*
versions into git.

=head1 OVERRIDES

In order to do its work, Module::Starter::PBP overrides a number of functions
in Module::Starter. If your wanted to write your own Module::Starter plugin,
these are the functions you would override to create your functionality.

=over

=item module_guts

Writes templates for all the .pm files.

=item Build_PL_guts

Writes 'Build.PL'.

=item Makefile_PL_guts

Writes 'Makefile.PL'.

=item Changes_guts

Writes a template 'Changes' file.

=item README_guts

Writes the 'README' file.

=item t_guts

Writes the test files 'pod-coverage.t', 'pod.t', 'perlcritic.t' and, 'tidy.t'
into the 't/' subdir.

Also writes the perltidyrc file 'perltidyrc' into the 't/' subdir. The
perltidy command in the 't/tidy.t' file is hard-wired to this file. The reason
that it is in the 't/' subdir is there was no other way to get it into the
module; there is no 'guts' handler in Module::Starter to place arbitrary files.

=item post_create_distro

Moves 't/perltidyrc' up one directory, and renames it '.perltidyrc', since it
is not a test file. Adjusts any MANIFEST file to match.

=back

=head1 DIAGNOSTICS

=over

=item C<< Can't find directory that holds Module::Starter::PBP templates >>

You did not tell Module::Starter::PBP where your templates are stored.
You need a 'template_dir' specification. Typically this would go in
your ~/.module-starter/config file. Something like:

    template_dir: /users/you/.module-starter/Templates


=item C<< Can't access Module::Starter::PBP template directory >>

You specified a 'template_dir', but the path didn't lead to a readable
directory.


=item C<< The template: %s isn't in the template directory (%s) >>

One of the required templates:

was missing from the template directory you specified.


=item C<< The template: %s isn't readable in the template directory (%s) >>

One of the templates in the template directory you specified was not readable.


=item C<< Unknown placeholder <%s> in %s >>

One of the templates in the template directory contained a replacement item
that wasn't a known piece of information.

=back


=head1 CONFIGURATION AND ENVIRONMENT

See the documentation for C<Module::Starter> and C<module-starter>.


=head1 DEPENDENCIES

Requires the C<Module::Starter> module.


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-module-starter-pbp@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Matthew O. Persico <persicom.cpan@gmail.com>

=head1 AUTHORS EMERITUS

Damian Conway <DCONWAY.CPAN@gmail.com>
Mark Leighton Fisher <mlfisher@cpan.org>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2026, Matthew O. Persico <persicom.cpan@gmail.com>, Damian Conway <DCONWAY.CPAN@gmail.com>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

__DATA__
_____[ Build.PL ]________________________________________________
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => '<MAIN MODULE>',
    license             => '<LICENSE>',
    dist_author         => '<AUTHOR>',
    dist_version_from   => '<MAIN PM FILE>',
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
    add_to_cleanup => [ '<DISTRO>-*' ],
    <META MERGE opt>
);

$builder->create_build_script();
_____[ Makefile.PL ]_____________________________________________
use strict;
use warnings;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
    NAME                => '<MAIN MODULE>',
    AUTHOR              => [<AUTHOR>],
    VERSION_FROM        => '<MAIN PM FILE>',
    ABSTRACT_FROM       => '<MAIN PM FILE>',
    LICENSE             => '<LICENSE>',
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
        #'ABC'              => '1.6',
        #'Foo::Bar::Module' => '5.0401',
    },
    dist       => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean      => { FILES    => 'Module-Starter-PBP-*' },
    <META MERGE opt>
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
_____[ README ]__________________________________________________
<DISTRO> version 0.0.1

[ REPLACE THIS...

  The README is used to introduce the module and provide instructions on
  how to install the module, any machine dependencies it may have (for
  example C compilers and installed libraries) and any other information
  that should be understood before the module is installed.

  A README file is required for CPAN modules since CPAN extracts the
  README file from a module distribution so that people browsing the
  archive can use it get an idea of the modules uses. It is usually a
  good idea to provide version information here so that people can
  decide whether fixes for the module are worth downloading.
]


INSTALLATION

<BUILD INSTRUCTIONS>


DEPENDENCIES

None.


COPYRIGHT AND LICENCE

Copyright (C) <YEAR>, <AUTHOR>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.
_____[ Changes ]_________________________________________________
Revision history for <DISTRO>

0.0.1  <DATE>
       Initial release.
_____[ Module.pm ]_______________________________________________
package <MODULE NAME>;

use warnings;
use strict;
use Carp;

our $VERSION = '0.003';

# Module implementation here

1;    # Magic true value required at end of module
__END__

!=head1 NAME

<MODULE NAME> - [One line description of module's purpose here]


!=head1 VERSION

This document describes <MODULE NAME> version 0.0.1


!=head1 SYNOPSIS

    use <MODULE NAME>;

!=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.


!=head1 DESCRIPTION

!=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


!=head1 INTERFACE

!=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


!=head1 DIAGNOSTICS

!=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

!=over

!=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

!=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

!=back


!=head1 CONFIGURATION AND ENVIRONMENT

!=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

<MODULE NAME> requires no configuration files or environment variables.


!=head1 DEPENDENCIES

!=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


!=head1 INCOMPATIBILITIES

!=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


!=head1 BUGS AND LIMITATIONS

!=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-<RT NAME>@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.

!=head1 AUTHOR

<AUTHOR>


!=head1 LICENCE AND COPYRIGHT

Copyright (c) <YEAR>, <AUTHOR>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

!=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
_____[ pod-coverage.t ]__________________________________________
#!perl

use strict;
use warnings;
use Test::More;

# The non eval version calls use_ok() in a BEGIN statement, but Test::Pod sets
# the number of tests to the number of files being tested, and the use_ok()
# adds one more test, which confuses Test::More.
eval q(use Test::Pod::Coverage 1.04);    ## no critic (BuiltinFunctions::ProhibitStringyEval)
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
all_pod_coverage_ok();
_____[ pod.t ]___________________________________________________
#!perl

use strict;
use warnings;
use Test::More;

# The non eval version calls use_ok() in a BEGIN statement, but Test::Pod sets
# the number of tests to the number of files being tested, and the use_ok()
# adds one more test, which confuses Test::More.
eval q(use Test::Pod 1.14);    ## no critic (BuiltinFunctions::ProhibitStringyEval)
plan skip_all => "Test::Pod 1.14 required for testing POD" if $@;
all_pod_files_ok();
_____[ perlcritic.t ]___________________________________________________
#!perl

use strict;
use warnings;
use Test::More;

# The non eval version calls use_ok() in a BEGIN statement, but Test::Pod sets
# the number of tests to the number of files being tested, and the use_ok()
# adds one more test, which confuses Test::More.
eval q(use Test::Perl::Critic);    ## no critic (BuiltinFunctions::ProhibitStringyEval)
plan skip_all => "Test::Perl::Critic required for testing PBP compliance" if $@;
Test::Perl::Critic::all_critic_ok();
_____[ tidy.t ]___________________________________________________
#!perl

use strict;
use warnings;

use Test::More;
use FindBin;
use File::Find;

# The non eval version calls use_ok() in a BEGIN statement, but Test::Pod sets
# the number of tests to the number of files being tested, and the use_ok()
# adds one more test, which confuses Test::More.
eval q(use Perl::Tidy);    ## no critic (BuiltinFunctions::ProhibitStringyEval)
plan skip_all => "Perl::Tidy required for testing code tidiness" if $@;

sub is_perl_code {
    # Match by name
    if ($_[0] =~ m/\.(p[ml]|t|PL)/) {
        return 1;
    }
    open my $fh, '<', $_[0]
        or do {
        diag("MANIFEST file entry '$_[0]' not found.");
        return 0;
        };
    my $text = <$fh>;
    if ($text && $text =~ m/#!.*perl/) {
        return 1;
    }
    return 0;
}

open my $fh, '<', "$FindBin::Bin/../MANIFEST";
my @files = map {
    my $filename = "$FindBin::Bin/../$_";
    chomp $filename;
    $filename =~ s/\s+.*//;
    $filename;
} <$fh>;
close $fh;

my @perl_files = grep { is_perl_code($_) } @files;

my $argv = join(
    ' ',
    "--pro=$FindBin::Bin/../.perltidyrc", '--assert-tidy',
    '-nst',    ## Turns off the -st in -pbp in perltidyrc
    @perl_files
);
is(Perl::Tidy::perltidy(argv => $argv), 0, "tidy");
done_testing();
_____[ perltidyrc ]___________________________________________________
# Follow basic PBP guidelines
-pbp

#...except as follows...

# Format to 100 columns
-l=100

# Continuation indent is 4 columns
-ci=4

# Break after all arrow-then-comma sequences (except in one-liners)
-cab=1

# Opening brace ALWAYS on the right
-bar

# Don't outdent labels
-nola

# Preserve all comma breaks in lists (i.e. I'll format them myself)
-boc

# Tighter parens and square brackets...
-pt=2
-sbt=2

# "} else", not "}\nelse".
--cuddled-else

# Do NOT force a blank line before a full line comment.
--noblanks-before-comments

# Do not count the side comment in line-length calcs; comments won't cause line
# breaks.
--ignore-side-comment-lengths

# DON'T left slam long strings.
-nolq

# Turn off aligning qw() for multiple 'use' statements. Was turned on by
# default in perltidy 20220613.
-vxl='q'
