#!perl -T

use Test::More;
eval "use Perl::Tidy";
plan skip_all => "Perl::Tidy required for testing code tidiness" if $@;
use FindBin;
my $argv = join(
    ' ',
    "--pro=$FindBin::Bin/../.perltidyrc", '--assert-tidy',
    '-nst',    ## Turns off the -st in -pbp in .perltidyrc
    map {"$FindBin::Bin/../$_"}
        qw(Build.PL Makefile.PL lib/Module/Starter/PBP.pm t/00.load.t t/pod.t t/pod-coverage.t t/tidy.t)
);
is(Perl::Tidy::perltidy(argv => $argv), 0, "tidy");
done_testing();
