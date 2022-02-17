use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Deep;

use Data::Dumper;
$Data::Dumper::Indent = 1;
use JSON;

my $warn = shift @ARGV;
unless ($warn) {
    close STDERR;
    open (STDERR, ">/dev/null");
    select (STDERR); $| = 1;
}

use constant DONE => 1;

require_ok( 'Net::Async::WebService::lxd' );

use IO::Async::Loop;
my $loop = IO::Async::Loop->new;

my @PROJECT = (); # (	project => 'test' );

my $lxd = Net::Async::WebService::lxd->new( loop               => $loop,
					    endpoint           => 'https://192.168.3.50:8443',
					    client_cert_file   => "t/client.crt",
					    client_key_file    => "t/client.key",
					    server_fingerprint => 'sha1$92:DD:63:F8:99:C4:5F:82:59:52:82:A9:09:C8:57:F0:67:56:B0:1B',
					    @PROJECT,
                                           );


if (DONE) {
    my $AGENDA = q{project life cycle: };

    my $f = $lxd->create_project(
	body => {
	    "config" => {
		"features.images"   => "false",
		"features.profiles" => "false"
	    },
	    "description" => "test project",
	    "name" => "test1"
	});
    isa_ok( $f, 'Future', $AGENDA.'future');
    like( $f->get, qr/success/i, $AGENDA.'created project');
#--
    throws_ok {
	$lxd->create_project(
	    body => {
		"config" => {
		    "features.images"   => "false",
			"features.profiles" => "false"
		},
		    "description" => "test project",
		    "name" => "test1"
	    })->get;
    } qr/already/, $AGENDA.'duplicate project';
#--
    $lxd->create_project(
	    body => {
		"config" => {
		    "features.images"   => "false",
			"features.profiles" => "false"
		},
		    "description" => "test project",
		    "name" => "test2"
	    })->get;
    my $ps = $lxd->projects->get;
    is( (scalar grep { /test/ }  @$ps), 2, $AGENDA.'all projects');
#--
    foreach my $p ( map { /(test.+)/ ? $1 : () } @$ps ) {
	$lxd->delete_project( name => $p )->get;
    }
    $ps = $lxd->projects->get;
    is( (scalar grep { /test/ }  @$ps), 0, $AGENDA.'no projects');
}

done_testing;

__END__
