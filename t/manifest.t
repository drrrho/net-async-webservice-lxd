#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

unless ( $ENV{RELEASE_TESTING} ) {
    plan( skip_all => "Author tests not required for installation" );
}

my $min_tcm = 0.9;
eval "use Test::CheckManifest $min_tcm";
plan skip_all => "Test::CheckManifest $min_tcm required" if $@;

ok_manifest({filter => [ qr/\.git/, qr/~$/, qr/Net-Async-WebService-lxd.*/, qr/_build/, qr/ignore.*/, qr/.*\.tar\.gz/, qr/.*\.deb/ ]});
