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

# $ENV{LXD_ENDPOINT} = 'https://192.168.3.50:8443';
unless ( $ENV{LXD_ENDPOINT} ) {
    plan skip_all => 'no LXD_ENDPOINT defined in ENV';
    done_testing; exit;
}

no  warnings 'once';
use Log::Log4perl qw(:levels);
Log::Log4perl::init( \ q(

log4perl.category = DEBUG, Screen
log4perl.appender.Screen        = Log::Log4perl::Appender::ScreenColoredLevels
log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.Screen.layout.ConversionPattern = %d{HH:mm:ss} %p [%r] %H : %F %L %c - %m%n
                       ) );
my $log = Log::Log4perl->get_logger("naw::lxd");
$log->level($warn ? $DEBUG : $ERROR); # one of DEBUG, INFO, WARN, ERROR, FATAL

use Net::Async::WebService::lxd;
$Net::Async::WebService::lxd::log = $log;

my %SSL = map  { $_ => $ENV{$_} }
          grep { $_ =~ /^SSL_/ }
          keys %ENV;

%SSL = (
    SSL_cert_file   => "t/client.crt",
    SSL_key_file    => "t/client.key",
    SSL_fingerprint => 'sha1$20:15:80:76:E0:A5:04:C6:A9:6A:BA:81:3D:25:91:67:C2:79:97:30',
) unless %SSL;

#== tests ========================================================


use IO::Async::Loop;
my $loop = IO::Async::Loop->new;

my @PROJECT = (); # (	project => 'test' );

my $lxd = Net::Async::WebService::lxd->new( loop        => $loop,
					    endpoint    => $ENV{LXD_ENDPOINT},
					    %SSL,
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
    my $p = $lxd->project( name => 'test1' )->get;
    is( $p->{description}, "test project", $AGENDA.'fetch info');
    ok( exists $p->{config}, $AGENDA.'fetch info');
#--
    $p = $lxd->project_state( name => 'test1' )->get;
    map { is( $_->{Usage}, 0, $AGENDA.'no usage' ) } values %{ $p->{resources} };
#--
    $lxd->rename_project( name => 'test1', body => { name => 'testx' } )->get;
    $p = $lxd->project( name => 'testx' )->get;
    is( $p->{description}, "test project", $AGENDA.'fetch info, renamed');

    $lxd->rename_project( name => 'testx', body => { name => 'test1' } )->get;
    $p = $lxd->project( name => 'test1' )->get;
    is( $p->{description}, "test project", $AGENDA.'fetch info, rerenamed');
#--
    $lxd->modify_project( name => 'test1', body => { description => "XXX" } )->get;
    $p = $lxd->project( name => 'test1' )->get;
    is( $p->{description}, "XXX", $AGENDA.'modified description');
#warn Dumper $p;
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
