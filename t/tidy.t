#!perl
use Test::More;
eval "use Perl::Tidy";
plan skip_all => "Perl::Tidy required for testing code tidiness" if $@;

use FindBin;
my $manifest = "$FindBin::Bin/../MANIFEST";
ok( -r $manifest, "Found MANIFEST file" );
open my $fh, '<', $manifest or croak $!;
my @all_files = map { chomp; my @x = split(/\s+/,$_); "$FindBin::Bin/../$x[0]" } <$fh>;
my @perl_files;

for my $file (@all_files) {
    if ( $file =~ m/\.(p[ml]|t|PL)/) {
        push @perl_files, $file;
    } else {
        open my $fh, '<', $file or croak $!;
        my @text = <$fh>;
        if ( $text[0] =~ m/perl/ ) {
            push @perl_files, $file;
        }
    }
}

my $argv = join(
    ' ',
    "--pro=$FindBin::Bin/../.perltidyrc", '--assert-tidy',
    '-nst',    ## Turns off the -st in -pbp in .perltidyrc
    map {"$FindBin::Bin/../$_"}
        qw(Build.PL Makefile.PL lib/Module/Starter/PBP.pm t/00.load.t t/pod.t t/pod-coverage.t t/tidy.t)
    @perl_files
);
is(Perl::Tidy::perltidy(argv => $argv), 0, "tidy");
done_testing();
