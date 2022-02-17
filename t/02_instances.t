

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

require_ok( 'Net::Async::WebService::lxd' );

no  warnings 'once';
use Log::Log4perl::Level;
$Net::Async::WebService::lxd::log->level($warn ? $DEBUG : $ERROR); # one of DEBUG, INFO, WARN, ERROR, FATAL

use constant DONE => 1;

use IO::Async::Loop;
my $loop = IO::Async::Loop->new;

my @PROJECT = (	project => 'test' );


my $lxd = Net::Async::WebService::lxd->new( loop               => $loop,
					    endpoint           => 'https://192.168.3.50:8443',
					    client_cert_file   => "t/client.crt",
					    client_key_file    => "t/client.key",
					    server_fingerprint => 'sha1$92:DD:63:F8:99:C4:5F:82:59:52:82:A9:09:C8:57:F0:67:56:B0:1B',
					    @PROJECT,
                                           );
eval {
    $lxd->create_project(
	body => {
	    "config" => {
		"features.images"   => "false",
		    "features.profiles" => "false"
	    },
		"description" => "Net::Async::WebService::lxd test suite",
		"name" => $PROJECT[1],
	})->get;
};

if (DONE) {
    my $AGENDA = q{instances: };

#-- simple life cycle
    my $f = $lxd->create_instance(
	@PROJECT,
	body => {
	    architecture => 'x86_64',
	    profiles     => [ 'default'  ],
	    name         => 'test1',
	    source       => { 'type' => 'image', fingerprint => '6dc6aa7c8c00' },
	    config       => {},
	} );

    is( $f->get, 'success', $AGENDA.'created inside project');
    throws_ok {
	$lxd->create_instance(
	    @PROJECT,
	    body => {
		architecture => 'x86_64',
		profiles     => [ 'default'  ],
		name         => 'test1',
		source       => { 'type' => 'image', fingerprint => '6dc6aa7c8c00' },
		config       => {},
	    } )->get;
    } qr/already/, $AGENDA.'container exists';
#-- instances
    $f = $lxd->instances( @PROJECT );
    isa_ok( $f, 'Future' );
    like( $f->get->[0],  qr{/1.0/instances/test1}, $AGENDA.'one instance found');
    isa_ok ( $lxd->instances( )->get, 'ARRAY', $AGENDA.'default project');

    ok( eq_set( $lxd->instances( project => 'testxxx' )->get, [] ), $AGENDA.'wrong project');
#    ok( eq_set( $lxd->instances( 'all-projects' => 'true' )->get, [ '/1.0/instances/test'] ), $AGENDA.'all projects');
#--
    my $i = $lxd->instance( name => 'test1', @PROJECT )->get;
#warn Dumper $i;
    cmp_deeply( $i, superhashof({
	name         => 'test1',
	description  => ignore(),
	architecture => ignore(),
	status       => ignore(),
				}), $AGENDA.'instance data');

#-- instances recursive
    my $is = $lxd->instances_recursion1( @PROJECT )->get;
#warn Dumper $is; exit;
    cmp_deeply( $is->[0], superhashof({
	name         => 'test1',
	description  => ignore(),
	config       => ignore(),
	expanded_config => ignore(),
	status       => ignore(),
				}), $AGENDA.'instances recursion 1');
    $is = $lxd->instances_recursion2( @PROJECT )->get;
#warn Dumper $is; exit;
    cmp_deeply( $is->[0], superhashof({
	name         => 'test1',
	backups      => ignore(),
	description  => ignore(),
	config       => ignore(),
	expanded_config => ignore(),
	status       => ignore(),
				}), $AGENDA.'instances recursion 2');
#--
    throws_ok {
	$lxd->instance( @PROJECT, name => 'xxx' )->get;
    } qr/not found/i, $AGENDA.'non-existing instance bombed';
#--
    $i = $lxd->instance_recursion1( @PROJECT, name => 'test1' )->get;
    cmp_deeply( $i, superhashof({
	name         => 'test1',
	description  => ignore(),
	architecture => ignore(),
	backups      => ignore(),
	description  => ignore(),
	config       => ignore(),
	expanded_config => ignore(),
	status       => ignore(),
				}), $AGENDA.'instance recursive data');
#--
    my $s = $lxd->instance_state( @PROJECT, name => 'test1' )->get;
    cmp_deeply( $s, superhashof({
	status         => 'Stopped',
	processes      => 0,
	memory         => ignore(),
	disk           => ignore(),
	network        => ignore(),
				}), $AGENDA.'instance state');
#- PUT state
    $s = $lxd->instance_state( @PROJECT, name => 'test1',
			       body => {
				   action   => "start",
				   force    => JSON::false,
				   stateful => JSON::false,
				   timeout  => 30,
			       } )->get;
#warn Dumper $s;
#--
    throws_ok {
	$lxd->delete_instance(@PROJECT, name => 'test1')->get;
    } qr/running/i, $AGENDA.'failed to delete running container';
#--
    $lxd->instance_state( @PROJECT, name => 'test1',
			  body => {
			      action   => "stop",
			      force    => JSON::false,
			      stateful => JSON::false,
			      timeout  => 30,
			  } )->get;
    is( $lxd->delete_instance(@PROJECT, name => 'test1')->get, 'success', $AGENDA.'deleted container');
}

$lxd->delete_project( name => $PROJECT[1] )->get;

done_testing;

__END__


