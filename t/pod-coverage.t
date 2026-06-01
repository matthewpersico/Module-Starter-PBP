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
