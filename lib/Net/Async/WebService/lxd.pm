package Net::Async::WebService::lxd;

use strict;
use warnings;

use Data::Dumper;
$Data::Dumper::Indent = 1;

our $VERSION = '0.01';

use Encode qw(encode_utf8);
use JSON;
use HTTP::Status qw(:constants);

use Moose;


use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
no warnings 'once';
our $log = Log::Log4perl->get_logger("nawl");


has 'loop'                 => (isa => 'IO::Async::Loop',     is => 'ro' );
has '_http'                => (isa => 'Net::Async::HTTP',    is => 'ro' );
has 'endpoint'             => (isa => 'Str',	             is => 'ro' );
has 'client_cert_file'     => (isa => 'Str',	             is => 'ro' );
has 'client_key_file'      => (isa => 'Str',	             is => 'ro' );
has 'server_fingerprint'   => (isa => 'Str',	             is => 'ro' );
has 'polling_time'         => (isa => 'Int', default => 1,   is => 'rw' );
has '_timer'               => (isa => 'IO::Async::Timer::Periodic', is => 'ro' );
has '_pendings'            => (isa => 'HashRef', default => sub { {} }, is => 'rw');

# need it for now
has 'project'              => (isa => 'Str', is => 'ro');

sub BUILD {
    my $elf = shift;
    
    use Net::Async::HTTP;
    my $http = Net::Async::HTTP->new(
	SSL_cert_file   => $elf->{client_cert_file},
	SSL_key_file    => $elf->{client_key_file},
	SSL_fingerprint => $elf->{server_fingerprint},
	);
#-- add http resolver
    $elf->{loop}->add( $http );
    $elf->{_http} = $http; # keep it handy
#-- add timer for background operation
    use IO::Async::Timer::Periodic;
    my $timer = IO::Async::Timer::Periodic->new(
           interval => $elf->{polling_time},
           on_tick => sub {
	       my $pendings = $elf->{_pendings};
#warn "current pendings ".Dumper [ keys %$pendings ];
	       if (scalar %$pendings) { # only if we have open issues
		   my $ops = $elf->operations_recursion1( $elf->{project}? (project => $elf->{project}) : () )->get;
#warn Dumper $ops;
		   map      { delete $pendings->{ $_->{id} } }                             # delete this id from the local pendings
		       map  { $pendings->{ $_->{id} }->{future}->done( 'success' ) && $_ }    # tunnel id, and set the future to done
		       grep { $pendings->{ $_->{id} } }   # only look at those pendings we have open
#map { warn Dumper $_ && $_ }
		       @{ $ops->{success} }; # iterate over all recent success
		   map      { delete $pendings->{ $_->{id} } }                             # delete this id from the local pendings
#map { warn Dumper $_ }
		       map  { $pendings->{ $_->{id} }->{future}->fail( $_->{err} ) && $_ }    # tunnel id, and set the future to fail
		       grep { $pendings->{$_->{id}} }   # only look at those pendings we have open
		       @{ $ops->{failure} }; # iterate over all recent success
		   # ignore the running ops
	       }

           },
        );
    $elf->{loop}->add( $timer );
    $timer->start;
    $elf->{_timer} = $timer;
}

sub _fix_broken_YAML {
    my $yaml = shift;

    $yaml =~ s|(\S+?(\{\S+?\}\S*?)+?):|"$1":|msg;
#    $yaml =~ s|(x-go-name)|"$1"|g;
    $yaml =~ s{( +- )(description)}{"$1\n" . " " x length($1) . $2 }esg;
    foreach my $attr (qw(description title example)) {
	$yaml =~ s{((\ +)($attr):([^\n]+?))(\n(\ +)(.+?)\n)}
          { $1
           . ( $4 eq ' |-' # or length($2) == 1
               ? ( $5 ) 
               : 
# length($2)." ".length($6). " for $3 $5 $7".
                 ( length($2) >= length($6) 
                   ? $5
                   : " $7\n" 
                 )
             ) 
           }xegs;
    }
    $yaml =~ s/^-/  -/msg;
    $yaml = "---\n$yaml";
}

my $data = do { local $/; <DATA> };
my $yaml = _fix_broken_YAML( $data );
# write_file('/tmp/xxx.yaml', $yaml);

use YAML;
my $rest_api = YAML::Load( $yaml );
#warn Dumper [ sort keys %{ $rest_api->{paths} } ];
#warn scalar keys %{ $rest_api->{paths} }; #exit;

my $POST_translations = {
                               instances_post => 'create_instance'                                   , # Creates a new instance on LXD.                               
                          images_aliases_post => 'create_images_alias'                               , # Creates a new image alias.                                   
      storage_pool_volumes_type_snapshot_post => 'rename_storage_pool_volumes_type_snapshot'         , # Renames a storage volume snapshot.                           
                           storage_pools_post => 'create_storage_pool'                               , # Creates a new storage pool.                                  
                       instance_snapshot_post => 'migrate_instance_snapshot'                         , # Renames or migrates an instance snapshot to another server.  
        storage_pool_volumes_type_backup_post => 'rename_storage_pool_volumes_type_backup'           , # Renames a storage volume backup.                             
                           images_secret_post => 'initiate_image_upload'                             , # This generates a background operation including a secret one time key
                        images_post_untrusted => 'push_image_untrusted'                              , # Pushes the data to the target image server.                  
                      instance_snapshots_post => 'create_instance_snapshot'                          , # Creates a new snapshot.                                      
                                profiles_post => 'create_profile'                                    , # Creates a new profile.                                       
                          instance_files_post => 'create_instance_file'                              , # Creates a new file in the instance.                          
                                instance_post => 'migrate_instance'                                  , # Renames, moves an instance between pools or migrates an instance to another server.
                         cluster_members_post => 'add_cluster_member'                                , # Requests a join token to add a cluster member.               
                        instance_console_post => 'connect_instance_console'                          , # Connects to the console of an instance.                      
                           cluster_group_post => 'rename_cluster_group'                              , # Renames an existing cluster group.                           
                    network_zone_records_post => 'create_network_zone_record'                        , # Creates a new network zone record.                           
                storage_pool_volume_type_post => 'migrate_storage_pool_volume_type'                  , # Renames, moves a storage volume between pools or migrates an instance to another server.
                    storage_pool_volumes_post => 'create_storage_pool_volume'                        , # Creates a new storage volume.                                
                                 profile_post => 'rename_profile'                                    , # Renames an existing profile.                                 
                           images_export_post => 'push_images_export'                                , # Gets LXD to connect to a remote server and push the image to it.
                            certificates_post => 'add_certificate'                                   , # Adds a certificate to the trust store.                       
                           network_zones_post => 'create_network_zone'                               , # Creates a new network zone.                                  
                  certificates_post_untrusted => 'add_certificate_untrusted'                         , # Adds a certificate to the trust store as an untrusted user.  
                         instance_backup_post => 'rename_instance_backup'                            , # Renames an instance backup.                                  
             instance_metadata_templates_post => 'create_instance_metadata_template'                 , # Creates a new image template file for the instance.          
                          cluster_groups_post => 'create_cluster_group'                              , # Creates a new cluster group.                                 
                                 project_post => 'rename_project'                                    , # Renames an existing project.                                 
                                 network_post => 'rename_network'                                    , # Renames an existing network.                                 
                           instance_exec_post => 'execute_in_instance'                               , # Executes a command inside an instance.                       
                        instance_backups_post => 'create_instance_backup'                            , # Creates a new backup.                                        
                    cluster_member_state_post => 'restore_cluster_member_state'                      , # Evacuates or restores a cluster member.                      
                                  images_post => 'create_image'                                      , # Adds a new image to the image store.                         
                          cluster_member_post => 'rename_cluster_member'                             , # Renames an existing cluster member.                          
                           network_peers_post => 'create_network_peer'                               , # Initiates/creates a new network peering.                     
                                networks_post => 'create_network'                                    , # Creates a new network.                                       
                            images_alias_post => 'rename_images_alias'                               , # Renames an existing image alias.                             
                                projects_post => 'create_project'                                    , # Creates a new project.                                       
                        network_forwards_post => 'create_network_forward'                            , # Creates a new network address forward.                       
       storage_pool_volumes_type_backups_post => 'create_storage_pool_volumes_backup'                , # Creates a new storage volume backup.                         
                             network_acl_post => 'rename_network_acl'                                , # Renames an existing network ACL.                             
     storage_pool_volumes_type_snapshots_post => 'create_storage_pool_volumes_snapshot'              , # Creates a new storage volume snapshot.                       
               storage_pool_volumes_type_post => 'create_storage_pool_volumes_type'                  , # Creates a new storage volume (type specific endpoint).       
                          images_refresh_post => 'update_images_refresh'                             , # This causes LXD to check the image source server for an updated
                            network_acls_post => 'create_network_acl'                                , # Creates a new network ACL.
};

my $meta = __PACKAGE__->meta;
my $META; # association between methods and what is in the spec

my %uniq_methods; # make sure we do not duplicate method by name
foreach my $path ( keys %{ $rest_api->{paths} } ) {
    my $op = $rest_api->{paths}->{ $path };
    
    if ($op->{get} && $op->{put}) { # possibly both can be mapped to ONE method
	my %get_params = map  { $_->{name} => $_ }
                         grep { $_->{in} eq 'query' }
                         @{ $op->{get}->{parameters} };
	my %put_params = map  { $_->{name} => $_ }
                         grep { $_->{in} eq 'query' }
                         @{ $op->{put}->{parameters} };
# TODO test params
	my $opId = $op->{get}->{operationId}; $opId =~ s/_get//;
	$meta->add_method(  $opId => _generate_method( $path, $opId, \%get_params, $op->{get}, 'GET' ));
	$META->{$opId} = { path   => $path,
			   name   => $opId,
			   opid   => [ $op->{get}->{operationId}, $op->{put}->{operationId} ],
			   params => \%get_params,
			   op     => [ $op->{get}, $op->{put} ],
			   tags   => $op->{get}->{tags},
			   method => 'GETPUT' };
	$uniq_methods{ $opId }++ and $log->logdie( "Internal error: duplicated $opId" );

    } elsif ($op->{get}) { # only GET
	my %get_params = map  { $_->{name} => $_ }
                         grep { $_->{in} eq 'query' }
                         @{ $op->{get}->{parameters} };
	my $opId = $op->{get}->{operationId}; $opId =~ s/_get//;
	$meta->add_method(  $opId => _generate_method( $path, $opId, \%get_params, $op->{get}, 'GET') );
	$META->{$opId} = { path => $path,
			   name   => $opId,
			   opid   => $op->{get}->{operationId},
			   params => \%get_params,
			   op     => $op,
			   tags   => $op->{get}->{tags},
			   method => 'GET' };
	$uniq_methods{ $opId }++ and $log->logdie( "Internal error: duplicated $opId" );

    } elsif ($op->{put}) { # only PUT
	my %put_params = map  { $_->{name} => $_ }
                         grep { $_->{in} eq 'query' }
                         @{ $op->{put}->{parameters} };
	my $opId = $op->{put}->{operationId}; $opId =~ s/(.+)_put/update_$1/;
	$meta->add_method(  $opId => _generate_method( $path, $opId, \%put_params, $op->{put}, 'PUT') );
	$META->{$opId} = { path   => $path,
			   name   => $opId,
			   opid   => $op->{put}->{operationId},
			   params => \%put_params,
			   op     => $op,
			   tags   => $op->{put}->{tags},
			   method => 'PUT' };
	$uniq_methods{ $opId }++ and $log->logdie( "Internal error: duplicated $opId" );

    } else { # neither nor
    }

    if ($op->{post}) {
	my %post_params = map  { $_->{name} => $_ }
                          grep { $_->{in} eq 'query' }
                          @{ $op->{post}->{parameters} };
	my $opId = $POST_translations->{$op->{post}->{operationId}}
	   or $log->logdie( "no post translation for $op->{post}->{operationId}" );
#my $description = $op->{post}->{description}; $description =~ s/\n.+//s;
#warn sprintf "%45s => %-50s, # %-60s", $op->{post}->{operationId}, $opId, $description;
	$meta->add_method(  $opId => _generate_method( $path, $opId, \%post_params, $op->{post}, 'POST') );
	$META->{$opId} = { path   => $path,
			   name   => $opId,
			   opid   => $op->{post}->{operationId},
			   params => \%post_params,
			   op     => $op,
			   tags   => $op->{post}->{tags},
			   method => 'POST' };
	$uniq_methods{ $opId }++ and $log->logdie( "Internal error: duplicated $opId" );
    }
    if ($op->{delete}) {
	my %params = map  { $_->{name} => $_ }
                          grep { $_->{in} eq 'query' }
                          @{ $op->{delete}->{parameters} };
	my $opId = $op->{delete}->{operationId}; $opId =~ s/(.+)_delete/delete_$1/;
#my $description = $op->{post}->{description}; $description =~ s/\n.+//s;
#warn sprintf "%45s => %-50s, # %-60s", $op->{post}->{operationId}, $opId, $description;
	$meta->add_method(  $opId => _generate_method( $path, $opId, \%params, $op->{delete}, 'DELETE') );
	$META->{$opId} = { path   => $path,
			   name   => $opId,
			   opid   => $op->{delete}->{operationId},
			   params => \%params,
			   op     => $op,
			   tags   => $op->{delete}->{tags},
			   method => 'DELETE' };
	$uniq_methods{ $opId }++ and $log->logdie( "Internal error: duplicated $opId" );
    }
    if ($op->{patch}) {
	my %params = map  { $_->{name} => $_ }
                          grep { $_->{in} eq 'query' }
                          @{ $op->{patch}->{parameters} };
	my $opId = $op->{patch}->{operationId}; $opId =~ s/(.+)_patch/modify_$1/;
#my $description = $op->{post}->{description}; $description =~ s/\n.+//s;
#warn sprintf "%45s => %-50s, # %-60s", $op->{post}->{operationId}, $opId, $description;
	$meta->add_method(  $opId => _generate_method( $path, $opId, \%params, $op->{patch}, 'PATCH') );
	$META->{$opId} = { path   => $path,
			   name   => $opId,
			   opid   => $op->{patch}->{operationId},
			   params => \%params,
			   op     => $op,
			   tags   => $op->{patch}->{tags},
			   method => 'PATCH' };
	$uniq_methods{ $opId }++ and $log->logdie( "Internal error: duplicated $opId" );
    }
}
#warn Dumper \%uniq_methods;

sub _generate_method {
    my $path   = shift;
    my $id     = shift;
    my $params = shift;
    my $op     = shift;
    my $method = shift;

#warn Dumper [ caller ] unless $method;
#warn "generate $method $path -> $id";
#warn Dumper [ $path, $op ] if $path eq '/1.0/instances/{name}'; # =~ /instance/;
    return sub {
	my $elf = shift;
	my %options = @_;
#warn "sub options".Dumper \%options;

	my $fullpath = $path;
	$fullpath =~ s/{(\w+)}/ delete $options{$1} /eg;
#warn "$path -> $fullpath";
#	$params->{$_} or die "parameter '$_' not valid for '$path'" for keys %options;  # TODO validation
#warn "params ".Dumper $params;

	use URI;
	my $uri = URI->new( $elf->{endpoint} . $fullpath );
#warn ">>> uri $uri";
	$uri->query_form( $uri->query_form,                           # if we already have params (it happens)
			                                              # add _query_ params we received
			      map  { $_ => $options{$_} }
			      grep { $params->{$_} or $_ eq 'recursion' } # allow also any recursion
			      grep { $_ ne 'body' }     # body param does not go into the uri
			      keys %options
			   );

	my $req = HTTP::Request->new( ($options{body} && $method eq 'GET' ? 'PUT' : $method),
				      $uri,
				      ($options{body}
				       ? ( [ Content_Type => 'application/json; charset=UTF-8' ],
					   encode_utf8(encode_json( $options{body} )) )
				       : () ) );
	$log->debug( ">>> ".$req->as_string );

	my $f = $elf->{loop}->new_future;
	$elf->{_http}->do_request( request => $req,
				   on_response => sub {
					 my $resp = $_[0];
					 $log->debug( "<<< ".$resp->as_string );
					 if ($resp->is_success) {                      # the HTTP req was handled ok
					     my $data = from_json ($resp->content);    # so there should be a solid json
					     if ($data->{type} eq 'sync') {            # we are finished with the operation
						 if ($data->{status_code} == 200) {    # and everyhing is ok from the lxd side
						     $f->done( $data->{metadata} // $data->{status});     # that would be the result
						 } else {
						     $f->fail( $data->{error} );       # lxd sent an error
						 }
					     } else {                                  # the only other option: we are not finished on the lxd server
						 #warn Dumper $data;
						 $log->debug( "pending operation: ".$data->{metadata}->{description} );
						 $elf->{_pendings}->{ $data->{metadata}->{id} } = {
						     operation => $data->{operation},
						     future    => $f };
					     }
					 } elsif (my $c = $resp->content) {
					     my $data = from_json ($c);
					     $f->fail( $data->{error} );
					 } else {
					     $f->fail( $resp->status_line );           # something happened on the transport level
					 }
				   },
	                        );
	return $f;
    }
}



# warn "###########";
# for my $method ( $meta->get_all_methods ) {
#     warn $method->fully_qualified_name;
# }

my $SPEC_base = 'https://linuxcontainers.org/lxd/api/master/#';

sub generate_pod {
#    print Dumper $rest_api;
    my %tags;
    map { $tags{$_}++ }
    map { @{ $_->{tags} } } values %$META;
    my @tags = keys %tags;

    my $pod = q{
=head1 NAME

Net::Async::WebService::lxd - REST client for lxd Linux containers

=head1 SYNOPSIS

   use IO::Async::Loop;
   my $loop = IO::Async::Loop->new;

   use Net::Async::WebService::lxd;
   my $lxd = Net::Async::WebService::lxd->new( loop               => $loop,
					       endpoint           => 'https://192.168.0.50:8443',
					       client_cert_file   => "t/client.crt",
					       client_key_file    => "t/client.key",
					       server_fingerprint => 'sha1$92:DD:63:F8:99:C4:5F:82:59:52:82:A9:09:C8:57:F0:67:56:B0:1B',
                                              );
   $lxd->create_instance(
	    body => {
		architecture => 'x86_64',
		profiles     => [ 'default'  ],
		name         => 'test1',
		source       => { 'type' => 'image', fingerprint => '6dc6aa7c8c00' },
		config       => {},
	    } )->get;   # wait for it
   # container is still stopped
   $lxd->instance_state( name => 'test1',
            body => {
                action   => "start",
		force    => JSON::false,
		stateful => JSON::false,
		timeout  => 30,
	    } )->get;  # wait for it


=head1 INTERFACE

=head2 Constructor

@@@@
@@@@ environemtn endpoint, project ...

};

    $pod .= "# automatically generated from the Swagger spec at https://raw.githubusercontent.com/lxc/lxd/master/doc/rest-api.yaml\n\n";

    foreach my $tag (sort @tags) {
	my $Tag = ucfirst( $tag );
	$Tag =~ s/-/ /g;
	$Tag =~ s/acl/ACL/;
	$Tag =~ s/( \S)/ uc($1)/ge;

	$pod .= qq{=head2 $Tag

=over

};

	foreach my $method (sort { $a->{name} cmp $b->{name} }
			    grep { $_->{tags}->[0] eq $tag } # this chapter
			    values %$META ) { # all
	    $pod .= qq{=item * B<$method->{name}>

};
#$pod .= Dumper $method;
	    if ($method->{method} eq 'GETPUT') {
		$pod .= $method->{op}->[0]->{description};
#		$pod .= qq{ [L <Spec|${SPEC_base}/$method->{tags}->[0]/$method->{opid}->[0]> ]};
		$pod .= "\n\n";
		$pod .= $method->{op}->[1]->{description};
#		$pod .= qq{ [L <Spec|${SPEC_base}/$method->{tags}->[0]/$method->{opid}->[1]> ]};
		$pod .= "\n\n";
	    } else {
		$pod .= $method->{op}->{ lc( $method->{method} ) }->{description};

$log->debug( "XXXX $method->{opid}  ") unless $method->{tags}->[0];
$log->debug( "YYYY $method->{opid}  ".Dumper $method) unless $method->{opid};

#		$pod .= qq{ [L <Spec|${SPEC_base}/$method->{tags}->[0]/$method->{opid}> ]};
		$pod .= "\n\n";
	    }
	    $pod .= q{=over

};
	    foreach my $p (sort keys %{ $method->{params} }) {
#		my $params = ref($method->{op}) eq 'ARRAY' ? $method->{op}->[1]->{parameters} : $method->{op}->{parameters};
#$pod .= Dumper $params;
		my $docp = $method->{params}->{$p};
#$pod .= Dumper $docp;
		$pod .= qq{=item C<$p>: } . ($docp->{type} ? $docp->{type} : "see Spec") . ', ' . ($docp->{required} ? "required" : "optional") . q{

};
	    }
#$pod .= ' >>>> ' .Dumper $method;
	    foreach my $m ( $method->{path} =~ /\{(.+?)\}/g ) {
#$pod .= ' >>>> '.Dumper \@matches;
		$pod .= qq{=item C<$m>: string (inside URL)

};
	    }

	    $pod .= q{
=back

};
	}
    
	$pod .= q{
=back

};

    }

    $pod .= q{

=head1 AUTHOR

Robert Barta, C<< <rho at devc.at> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-async-webservice-lxd at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Async-WebService-lxd>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 LICENSE AND COPYRIGHT

Copyright 2022 Robert Barta.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

};
print $pod;
}


1; # End of Net::Async::WebService::lxd

__DATA__
definitions:
  Certificate:
    description: Certificate represents a LXD certificate
    properties:
      certificate:
        description: The certificate itself, as PEM encoded X509
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      fingerprint:
        description: SHA256 fingerprint of the certificate
        example: fd200419b271f1dc2a5591b693cc5774b7f234e1ff8c6b78ad703b6888fe2b69
        readOnly: true
        type: string
        x-go-name: Fingerprint
      name:
        description: Name associated with the certificate
        example: castiana
        type: string
        x-go-name: Name
      projects:
        description: List of allowed projects (applies when restricted)
        example:
        - default
        - foo
        - bar
        items:
          type: string
        type: array
        x-go-name: Projects
      restricted:
        description: Whether to limit the certificate to listed projects
        example: true
        type: boolean
        x-go-name: Restricted
      type:
        description: Usage type for the certificate (only client currently)
        example: client
        type: string
        x-go-name: Type
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  CertificateAddToken:
    properties:
      addresses:
        description: The addresses of the server
        example:
        - 10.98.30.229:8443
        items:
          type: string
        type: array
        x-go-name: Addresses
      client_name:
        description: The name of the new client
        example: user@host
        type: string
        x-go-name: ClientName
      fingerprint:
        description: The fingerprint of the network certificate
        example: 57bb0ff4340b5bb28517e062023101adf788c37846dc8b619eb2c3cb4ef29436
        type: string
        x-go-name: Fingerprint
      secret:
        description: The random join secret
        example: 2b2284d44db32675923fe0d2020477e0e9be11801ff70c435e032b97028c35cd
        type: string
        x-go-name: Secret
    title: CertificateAddToken represents the fields contained within an encoded certificate
      add token.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  CertificatePut:
    description: CertificatePut represents the modifiable fields of a LXD certificate
    properties:
      certificate:
        description: The certificate itself, as PEM encoded X509
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      name:
        description: Name associated with the certificate
        example: castiana
        type: string
        x-go-name: Name
      projects:
        description: List of allowed projects (applies when restricted)
        example:
        - default
        - foo
        - bar
        items:
          type: string
        type: array
        x-go-name: Projects
      restricted:
        description: Whether to limit the certificate to listed projects
        example: true
        type: boolean
        x-go-name: Restricted
      type:
        description: Usage type for the certificate (only client currently)
        example: client
        type: string
        x-go-name: Type
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  CertificatesPost:
    description: CertificatesPost represents the fields of a new LXD certificate
    properties:
      certificate:
        description: The certificate itself, as PEM encoded X509
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      name:
        description: Name associated with the certificate
        example: castiana
        type: string
        x-go-name: Name
      password:
        description: Server trust password (used to add an untrusted client)
        example: blah
        type: string
        x-go-name: Password
      projects:
        description: List of allowed projects (applies when restricted)
        example:
        - default
        - foo
        - bar
        items:
          type: string
        type: array
        x-go-name: Projects
      restricted:
        description: Whether to limit the certificate to listed projects
        example: true
        type: boolean
        x-go-name: Restricted
      token:
        description: Whether to create a certificate add token
        example: true
        type: boolean
        x-go-name: Token
      type:
        description: Usage type for the certificate (only client currently)
        example: client
        type: string
        x-go-name: Type
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Cluster:
    properties:
      enabled:
        description: Whether clustering is enabled
        example: true
        type: boolean
        x-go-name: Enabled
      member_config:
        description: List of member configuration keys (used during join)
        example: []
        items:
          $ref: '#/definitions/ClusterMemberConfigKey'
        type: array
        x-go-name: MemberConfig
      server_name:
        description: Name of the cluster member answering the request
        example: lxd01
        type: string
        x-go-name: ServerName
    title: Cluster represents high-level information about a LXD cluster.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterCertificatePut:
    description: ClusterCertificatePut represents the certificate and key pair for
      all members in a LXD Cluster
    properties:
      cluster_certificate:
        description: The new certificate (X509 PEM encoded) for the cluster
        example: X509 PEM certificate
        type: string
        x-go-name: ClusterCertificate
      cluster_certificate_key:
        description: The new certificate key (X509 PEM encoded) for the cluster
        example: X509 PEM certificate key
        type: string
        x-go-name: ClusterCertificateKey
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterGroup:
    properties:
      description:
        description: The description of the cluster group
        example: amd64 servers
        type: string
        x-go-name: Description
      members:
        description: List of members in this group
        example:
        - node1
        - node3
        items:
          type: string
        type: array
        x-go-name: Members
      name:
        description: The new name of the cluster group
        example: group1
        type: string
        x-go-name: Name
    title: ClusterGroup represents a cluster group.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterGroupPost:
    properties:
      name:
        description: The new name of the cluster group
        example: group1
        type: string
        x-go-name: Name
    title: ClusterGroupPost represents the fields required to rename a cluster group.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterGroupPut:
    properties:
      description:
        description: The description of the cluster group
        example: amd64 servers
        type: string
        x-go-name: Description
      members:
        description: List of members in this group
        example:
        - node1
        - node3
        items:
          type: string
        type: array
        x-go-name: Members
    title: ClusterGroupPut represents the modifiable fields of a cluster group.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterGroupsPost:
    properties:
      description:
        description: The description of the cluster group
        example: amd64 servers
        type: string
        x-go-name: Description
      members:
        description: List of members in this group
        example:
        - node1
        - node3
        items:
          type: string
        type: array
        x-go-name: Members
      name:
        description: The new name of the cluster group
        example: group1
        type: string
        x-go-name: Name
    title: ClusterGroupsPost represents the fields available for a new cluster group.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterMember:
    properties:
      architecture:
        description: The primary architecture of the cluster member
        example: x86_64
        type: string
        x-go-name: Architecture
      config:
        additionalProperties:
          type: string
        description: Additional configuration information
        example:
          scheduler.instance: all
        type: object
        x-go-name: Config
      database:
        description: Whether the cluster member is a database server
        example: true
        type: boolean
        x-go-name: Database
      description:
        description: Cluster member description
        example: AMD Epyc 32c/64t
        type: string
        x-go-name: Description
      failure_domain:
        description: Name of the failure domain for this cluster member
        example: rack1
        type: string
        x-go-name: FailureDomain
      groups:
        description: List of cluster groups this member belongs to
        example:
        - group1
        - group2
        items:
          type: string
        type: array
        x-go-name: Groups
      message:
        description: Additional status information
        example: fully operational
        type: string
        x-go-name: Message
      roles:
        description: List of roles held by this cluster member
        example:
        - database
        items:
          type: string
        type: array
        x-go-name: Roles
      server_name:
        description: Name of the cluster member
        example: lxd01
        type: string
        x-go-name: ServerName
      status:
        description: Current status
        example: Online
        type: string
        x-go-name: Status
      url:
        description: URL at which the cluster member can be reached
        example: https://10.0.0.1:8443
        type: string
        x-go-name: URL
    title: ClusterMember represents the a LXD node in the cluster.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterMemberConfigKey:
    description: |-
      The Value field is empty when getting clustering information with GET
      1.0/cluster, and should be filled by the joining node when performing a PUT
      1.0/cluster join request.
    properties:
      description:
        description: A human friendly description key
        example: '"source" property for storage pool "local"'
        type: string
        x-go-name: Description
      entity:
        description: The kind of configuration key (network, storage-pool, ...)
        example: storage-pool
        type: string
        x-go-name: Entity
      key:
        description: The name of the key
        example: source
        type: string
        x-go-name: Key
      name:
        description: The name of the object requiring this key
        example: local
        type: string
        x-go-name: Name
      value:
        description: The value on the answering cluster member
        example: /dev/sdb
        type: string
        x-go-name: Value
    title: |-
      ClusterMemberConfigKey represents a single config key that a new member of
      the cluster is required to provide when joining.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterMemberJoinToken:
    properties:
      addresses:
        description: The addresses of existing online cluster members
        example:
        - 10.98.30.229:8443
        items:
          type: string
        type: array
        x-go-name: Addresses
      fingerprint:
        description: The fingerprint of the network certificate
        example: 57bb0ff4340b5bb28517e062023101adf788c37846dc8b619eb2c3cb4ef29436
        type: string
        x-go-name: Fingerprint
      secret:
        description: The random join secret.
        example: 2b2284d44db32675923fe0d2020477e0e9be11801ff70c435e032b97028c35cd
        type: string
        x-go-name: Secret
      server_name:
        description: The name of the new cluster member
        example: lxd02
        type: string
        x-go-name: ServerName
    title: ClusterMemberJoinToken represents the fields contained within an encoded
      cluster member join token.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterMemberPost:
    properties:
      server_name:
        description: The new name of the cluster member
        example: lxd02
        type: string
        x-go-name: ServerName
    title: ClusterMemberPost represents the fields required to rename a LXD node.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterMemberPut:
    description: ClusterMemberPut represents the the modifiable fields of a LXD cluster
      member
    properties:
      config:
        additionalProperties:
          type: string
        description: Additional configuration information
        example:
          scheduler.instance: all
        type: object
        x-go-name: Config
      description:
        description: Cluster member description
        example: AMD Epyc 32c/64t
        type: string
        x-go-name: Description
      failure_domain:
        description: Name of the failure domain for this cluster member
        example: rack1
        type: string
        x-go-name: FailureDomain
      groups:
        description: List of cluster groups this member belongs to
        example:
        - group1
        - group2
        items:
          type: string
        type: array
        x-go-name: Groups
      roles:
        description: List of roles held by this cluster member
        example:
        - database
        items:
          type: string
        type: array
        x-go-name: Roles
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterMemberStatePost:
    properties:
      action:
        description: The action to be performed. Valid actions are "evacuate" and
          "restore".
        example: evacuate
        type: string
        x-go-name: Action
    title: ClusterMemberStatePost represents the fields required to evacuate a cluster
      member.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterMembersPost:
    properties:
      server_name:
        description: The name of the new cluster member
        example: lxd02
        type: string
        x-go-name: ServerName
    title: ClusterMembersPost represents the fields required to request a join token
      to add a member to the cluster.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ClusterPut:
    description: |-
      ClusterPut represents the fields required to bootstrap or join a LXD
      cluster.
    properties:
      cluster_address:
        description: The address of the cluster you wish to join
        example: 10.0.0.1:8443
        type: string
        x-go-name: ClusterAddress
      cluster_certificate:
        description: The expected certificate (X509 PEM encoded) for the cluster
        example: X509 PEM certificate
        type: string
        x-go-name: ClusterCertificate
      cluster_password:
        description: The trust password of the cluster you're trying to join
        example: blah
        type: string
        x-go-name: ClusterPassword
      enabled:
        description: Whether clustering is enabled
        example: true
        type: boolean
        x-go-name: Enabled
      member_config:
        description: List of member configuration keys (used during join)
        example: []
        items:
          $ref: '#/definitions/ClusterMemberConfigKey'
        type: array
        x-go-name: MemberConfig
      server_address:
        description: The local address to use for cluster communication
        example: 10.0.0.2:8443
        type: string
        x-go-name: ServerAddress
      server_name:
        description: Name of the cluster member answering the request
        example: lxd01
        type: string
        x-go-name: ServerName
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Event:
    description: Event represents an event entry (over websocket)
    properties:
      location:
        description: Originating cluster member
        example: lxd01
        type: string
        x-go-name: Location
      metadata:
        description: JSON encoded metadata (see EventLogging, EventLifecycle or Operation)
        example:
          action: instance-started
          context: {}
          source: /1.0/instances/c1
        type: object
        x-go-name: Metadata
      project:
        description: Project the event belongs to.
        example: default
        type: string
        x-go-name: Project
      timestamp:
        description: Time at which the event was sent
        example: "2021-02-24T19:00:45.452649098-05:00"
        format: date-time
        type: string
        x-go-name: Timestamp
      type:
        description: Event type (one of operation, logging or lifecycle)
        example: lifecycle
        type: string
        x-go-name: Type
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Image:
    description: Image represents a LXD image
    properties:
      aliases:
        description: List of aliases
        items:
          $ref: '#/definitions/ImageAlias'
        type: array
        x-go-name: Aliases
      architecture:
        description: Architecture
        example: x86_64
        type: string
        x-go-name: Architecture
      auto_update:
        description: Whether the image should auto-update when a new build is available
        example: true
        type: boolean
        x-go-name: AutoUpdate
      cached:
        description: Whether the image is an automatically cached remote image
        example: true
        type: boolean
        x-go-name: Cached
      created_at:
        description: When the image was originally created
        example: "2021-03-23T20:00:00-04:00"
        format: date-time
        type: string
        x-go-name: CreatedAt
      expires_at:
        description: When the image becomes obsolete
        example: "2025-03-23T20:00:00-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      filename:
        description: Original filename
        example: 06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb.rootfs
        type: string
        x-go-name: Filename
      fingerprint:
        description: Full SHA-256 fingerprint
        example: 06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb
        type: string
        x-go-name: Fingerprint
      last_used_at:
        description: Last time the image was used
        example: "2021-03-22T20:39:00.575185384-04:00"
        format: date-time
        type: string
        x-go-name: LastUsedAt
      profiles:
        description: List of profiles to use when creating from this image (if none
          provided by user)
        example:
        - default
        items:
          type: string
        type: array
        x-go-name: Profiles
      properties:
        additionalProperties:
          type: string
        description: Descriptive properties
        example:
          os: Ubuntu
          release: focal
          variant: cloud
        type: object
        x-go-name: Properties
      public:
        description: Whether the image is available to unauthenticated users
        example: false
        type: boolean
        x-go-name: Public
      size:
        description: Size of the image in bytes
        example: 272237676
        format: int64
        type: integer
        x-go-name: Size
      type:
        description: Type of image (container or virtual-machine)
        example: container
        type: string
        x-go-name: Type
      update_source:
        $ref: '#/definitions/ImageSource'
      uploaded_at:
        description: When the image was added to this LXD server
        example: "2021-03-24T14:18:15.115036787-04:00"
        format: date-time
        type: string
        x-go-name: UploadedAt
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImageAlias:
    description: ImageAlias represents an alias from the alias list of a LXD image
    properties:
      description:
        description: Description of the alias
        example: Our preferred Ubuntu image
        type: string
        x-go-name: Description
      name:
        description: Name of the alias
        example: ubuntu-20.04
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImageAliasesEntry:
    description: ImageAliasesEntry represents a LXD image alias
    properties:
      description:
        description: Alias description
        example: Our preferred Ubuntu image
        type: string
        x-go-name: Description
      name:
        description: Alias name
        example: ubuntu-20.04
        type: string
        x-go-name: Name
      target:
        description: Target fingerprint for the alias
        example: 06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb
        type: string
        x-go-name: Target
      type:
        description: Alias type (container or virtual-machine)
        example: container
        type: string
        x-go-name: Type
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImageAliasesEntryPost:
    description: ImageAliasesEntryPost represents the required fields to rename a
      LXD image alias
    properties:
      name:
        description: Alias name
        example: ubuntu-20.04
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImageAliasesEntryPut:
    description: ImageAliasesEntryPut represents the modifiable fields of a LXD image
      alias
    properties:
      description:
        description: Alias description
        example: Our preferred Ubuntu image
        type: string
        x-go-name: Description
      target:
        description: Target fingerprint for the alias
        example: 06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb
        type: string
        x-go-name: Target
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImageAliasesPost:
    description: ImageAliasesPost represents a new LXD image alias
    properties:
      description:
        description: Alias description
        example: Our preferred Ubuntu image
        type: string
        x-go-name: Description
      name:
        description: Alias name
        example: ubuntu-20.04
        type: string
        x-go-name: Name
      target:
        description: Target fingerprint for the alias
        example: 06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb
        type: string
        x-go-name: Target
      type:
        description: Alias type (container or virtual-machine)
        example: container
        type: string
        x-go-name: Type
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImageExportPost:
    description: ImageExportPost represents the fields required to export a LXD image
    properties:
      aliases:
        description: List of aliases to set on the image
        items:
          $ref: '#/definitions/ImageAlias'
        type: array
        x-go-name: Aliases
      certificate:
        description: Remote server certificate
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      secret:
        description: Image receive secret
        example: RANDOM-STRING
        type: string
        x-go-name: Secret
      target:
        description: Target server URL
        example: https://1.2.3.4:8443
        type: string
        x-go-name: Target
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImageMetadata:
    description: ImageMetadata represents LXD image metadata (used in image tarball)
    properties:
      architecture:
        description: Architecture name
        example: x86_64
        type: string
        x-go-name: Architecture
      creation_date:
        description: Image creation data (as UNIX epoch)
        example: 1620655439
        format: int64
        type: integer
        x-go-name: CreationDate
      expiry_date:
        description: Image expiry data (as UNIX epoch)
        example: 1620685757
        format: int64
        type: integer
        x-go-name: ExpiryDate
      properties:
        additionalProperties:
          type: string
        description: Descriptive properties
        example:
          os: Ubuntu
          release: focal
          variant: cloud
        type: object
        x-go-name: Properties
      templates:
        additionalProperties:
          $ref: '#/definitions/ImageMetadataTemplate'
        description: Template for files in the image
        type: object
        x-go-name: Templates
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImageMetadataTemplate:
    description: ImageMetadataTemplate represents a template entry in image metadata
      (used in image tarball)
    properties:
      create_only:
        description: Whether to trigger only if the file is missing
        example: false
        type: boolean
        x-go-name: CreateOnly
      properties:
        additionalProperties:
          type: string
        description: Key/value properties to pass to the template
        example:
          foo: bar
        type: object
        x-go-name: Properties
      template:
        description: The template itself as a valid pongo2 template
        example: pongo2-template
        type: string
        x-go-name: Template
      when:
        description: When to trigger the template (create, copy or start)
        example: create
        items:
          type: string
        type: array
        x-go-name: When
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImagePut:
    description: ImagePut represents the modifiable fields of a LXD image
    properties:
      auto_update:
        description: Whether the image should auto-update when a new build is available
        example: true
        type: boolean
        x-go-name: AutoUpdate
      expires_at:
        description: When the image becomes obsolete
        example: "2025-03-23T20:00:00-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      profiles:
        description: List of profiles to use when creating from this image (if none
          provided by user)
        example:
        - default
        items:
          type: string
        type: array
        x-go-name: Profiles
      properties:
        additionalProperties:
          type: string
        description: Descriptive properties
        example:
          os: Ubuntu
          release: focal
          variant: cloud
        type: object
        x-go-name: Properties
      public:
        description: Whether the image is available to unauthenticated users
        example: false
        type: boolean
        x-go-name: Public
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImageSource:
    description: ImageSource represents the source of a LXD image
    properties:
      alias:
        description: Source alias to download from
        example: focal
        type: string
        x-go-name: Alias
      certificate:
        description: Source server certificate (if not trusted by system CA)
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      image_type:
        description: Type of image (container or virtual-machine)
        example: container
        type: string
        x-go-name: ImageType
      protocol:
        description: Source server protocol
        example: simplestreams
        type: string
        x-go-name: Protocol
      server:
        description: URL of the source server
        example: https://images.linuxcontainers.org
        type: string
        x-go-name: Server
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImagesPost:
    description: ImagesPost represents the fields available for a new LXD image
    properties:
      aliases:
        description: Aliases to add to the image
        example:
        - name: foo
        - name: bar
        items:
          $ref: '#/definitions/ImageAlias'
        type: array
        x-go-name: Aliases
      auto_update:
        description: Whether the image should auto-update when a new build is available
        example: true
        type: boolean
        x-go-name: AutoUpdate
      compression_algorithm:
        description: Compression algorithm to use when turning an instance into an
          image
        example: gzip
        type: string
        x-go-name: CompressionAlgorithm
      expires_at:
        description: When the image becomes obsolete
        example: "2025-03-23T20:00:00-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      filename:
        description: Original filename of the image
        example: lxd.tar.xz
        type: string
        x-go-name: Filename
      profiles:
        description: List of profiles to use when creating from this image (if none
          provided by user)
        example:
        - default
        items:
          type: string
        type: array
        x-go-name: Profiles
      properties:
        additionalProperties:
          type: string
        description: Descriptive properties
        example:
          os: Ubuntu
          release: focal
          variant: cloud
        type: object
        x-go-name: Properties
      public:
        description: Whether the image is available to unauthenticated users
        example: false
        type: boolean
        x-go-name: Public
      source:
        $ref: '#/definitions/ImagesPostSource'
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ImagesPostSource:
    description: ImagesPostSource represents the source of a new LXD image
    properties:
      alias:
        description: Source alias to download from
        example: focal
        type: string
        x-go-name: Alias
      certificate:
        description: Source server certificate (if not trusted by system CA)
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      fingerprint:
        description: Source image fingerprint (for type "image")
        example: 8ae945c52bb2f2df51c923b04022312f99bbb72c356251f54fa89ea7cf1df1d0
        type: string
        x-go-name: Fingerprint
      image_type:
        description: Type of image (container or virtual-machine)
        example: container
        type: string
        x-go-name: ImageType
      mode:
        description: Transfer mode (push or pull)
        example: pull
        type: string
        x-go-name: Mode
      name:
        description: Instance name (for type "instance" or "snapshot")
        example: c1/snap0
        type: string
        x-go-name: Name
      project:
        description: Source project name
        example: project1
        type: string
        x-go-name: Project
      protocol:
        description: Source server protocol
        example: simplestreams
        type: string
        x-go-name: Protocol
      secret:
        description: Source image server secret token (when downloading private images)
        example: RANDOM-STRING
        type: string
        x-go-name: Secret
      server:
        description: URL of the source server
        example: https://images.linuxcontainers.org
        type: string
        x-go-name: Server
      type:
        description: Type of image source (instance, snapshot, image or url)
        example: instance
        type: string
        x-go-name: Type
      url:
        description: Source URL (for type "url")
        example: https://some-server.com/some-directory/
        type: string
        x-go-name: URL
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Instance:
    properties:
      architecture:
        description: Architecture name
        example: x86_64
        type: string
        x-go-name: Architecture
      config:
        additionalProperties:
          type: string
        description: Instance configuration (see doc/instances.md)
        example:
          security.nesting: "true"
        type: object
        x-go-name: Config
      created_at:
        description: Instance creation timestamp
        example: "2021-03-23T20:00:00-04:00"
        format: date-time
        type: string
        x-go-name: CreatedAt
      description:
        description: Instance description
        example: My test instance
        type: string
        x-go-name: Description
      devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: Instance devices (see doc/instances.md)
        example:
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: Devices
      ephemeral:
        description: Whether the instance is ephemeral (deleted on shutdown)
        example: false
        type: boolean
        x-go-name: Ephemeral
      expanded_config:
        additionalProperties:
          type: string
        description: Expanded configuration (all profiles and local config merged)
        example:
          security.nesting: "true"
        type: object
        x-go-name: ExpandedConfig
      expanded_devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: Expanded devices (all profiles and local devices merged)
        example:
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: ExpandedDevices
      last_used_at:
        description: Last start timestamp
        example: "2021-03-23T20:00:00-04:00"
        format: date-time
        type: string
        x-go-name: LastUsedAt
      location:
        description: What cluster member this instance is located on
        example: lxd01
        type: string
        x-go-name: Location
      name:
        description: Instance name
        example: foo
        type: string
        x-go-name: Name
      profiles:
        description: List of profiles applied to the instance
        example:
        - default
        items:
          type: string
        type: array
        x-go-name: Profiles
      project:
        description: Instance project name
        example: foo
        type: string
        x-go-name: Project
      restore:
        description: If set, instance will be restored to the provided snapshot name
        example: snap0
        type: string
        x-go-name: Restore
      stateful:
        description: Whether the instance currently has saved state on disk
        example: false
        type: boolean
        x-go-name: Stateful
      status:
        description: Instance status (see instance_state)
        example: Running
        type: string
        x-go-name: Status
      status_code:
        $ref: '#/definitions/StatusCode'
      type:
        description: The type of instance (container or virtual-machine)
        example: container
        type: string
        x-go-name: Type
    title: Instance represents a LXD instance.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceBackup:
    properties:
      container_only:
        description: Whether to ignore snapshots (deprecated, use instance_only)
        example: false
        type: boolean
        x-go-name: ContainerOnly
      created_at:
        description: When the backup was cerated
        example: "2021-03-23T16:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: CreatedAt
      expires_at:
        description: When the backup expires (gets auto-deleted)
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      instance_only:
        description: Whether to ignore snapshots
        example: false
        type: boolean
        x-go-name: InstanceOnly
      name:
        description: Backup name
        example: backup0
        type: string
        x-go-name: Name
      optimized_storage:
        description: Whether to use a pool-optimized binary format (instead of plain
          tarball)
        example: true
        type: boolean
        x-go-name: OptimizedStorage
    title: InstanceBackup represents a LXD instance backup.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceBackupPost:
    properties:
      name:
        description: New backup name
        example: backup1
        type: string
        x-go-name: Name
    title: InstanceBackupPost represents the fields available for the renaming of
      a instance backup.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceBackupsPost:
    properties:
      compression_algorithm:
        description: What compression algorithm to use
        example: gzip
        type: string
        x-go-name: CompressionAlgorithm
      container_only:
        description: Whether to ignore snapshots (deprecated, use instance_only)
        example: false
        type: boolean
        x-go-name: ContainerOnly
      expires_at:
        description: When the backup expires (gets auto-deleted)
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      instance_only:
        description: Whether to ignore snapshots
        example: false
        type: boolean
        x-go-name: InstanceOnly
      name:
        description: Backup name
        example: backup0
        type: string
        x-go-name: Name
      optimized_storage:
        description: Whether to use a pool-optimized binary format (instead of plain
          tarball)
        example: true
        type: boolean
        x-go-name: OptimizedStorage
    title: InstanceBackupsPost represents the fields available for a new LXD instance
      backup.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceConsolePost:
    properties:
      height:
        description: Console height in rows (console type only)
        example: 24
        format: int64
        type: integer
        x-go-name: Height
      type:
        description: Type of console to attach to (console or vga)
        example: console
        type: string
        x-go-name: Type
      width:
        description: Console width in columns (console type only)
        example: 80
        format: int64
        type: integer
        x-go-name: Width
    title: InstanceConsolePost represents a LXD instance console request.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceExecPost:
    properties:
      command:
        description: Command and its arguments
        example:
        - bash
        items:
          type: string
        type: array
        x-go-name: Command
      cwd:
        description: Current working directory for the command
        example: /home/foo/
        type: string
        x-go-name: Cwd
      environment:
        additionalProperties:
          type: string
        description: Additional environment to pass to the command
        example:
          FOO: BAR
        type: object
        x-go-name: Environment
      group:
        description: GID of the user to spawn the command as
        example: 1000
        format: uint32
        type: integer
        x-go-name: Group
      height:
        description: Terminal height in rows (for interactive)
        example: 24
        format: int64
        type: integer
        x-go-name: Height
      interactive:
        description: Whether the command is to be spawned in interactive mode (singled
          PTY instead of 3 PIPEs)
        example: true
        type: boolean
        x-go-name: Interactive
      record-output:
        description: Whether to capture the output for later download (requires non-interactive)
        type: boolean
        x-go-name: RecordOutput
      user:
        description: UID of the user to spawn the command as
        example: 1000
        format: uint32
        type: integer
        x-go-name: User
      wait-for-websocket:
        description: Whether to wait for all websockets to be connected before spawning
          the command
        example: true
        type: boolean
        x-go-name: WaitForWS
      width:
        description: Terminal width in characters (for interactive)
        example: 80
        format: int64
        type: integer
        x-go-name: Width
    title: InstanceExecPost represents a LXD instance exec request.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceFull:
    properties:
      architecture:
        description: Architecture name
        example: x86_64
        type: string
        x-go-name: Architecture
      backups:
        description: List of backups.
        items:
          $ref: '#/definitions/InstanceBackup'
        type: array
        x-go-name: Backups
      config:
        additionalProperties:
          type: string
        description: Instance configuration (see doc/instances.md)
        example:
          security.nesting: "true"
        type: object
        x-go-name: Config
      created_at:
        description: Instance creation timestamp
        example: "2021-03-23T20:00:00-04:00"
        format: date-time
        type: string
        x-go-name: CreatedAt
      description:
        description: Instance description
        example: My test instance
        type: string
        x-go-name: Description
      devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: Instance devices (see doc/instances.md)
        example:
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: Devices
      ephemeral:
        description: Whether the instance is ephemeral (deleted on shutdown)
        example: false
        type: boolean
        x-go-name: Ephemeral
      expanded_config:
        additionalProperties:
          type: string
        description: Expanded configuration (all profiles and local config merged)
        example:
          security.nesting: "true"
        type: object
        x-go-name: ExpandedConfig
      expanded_devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: Expanded devices (all profiles and local devices merged)
        example:
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: ExpandedDevices
      last_used_at:
        description: Last start timestamp
        example: "2021-03-23T20:00:00-04:00"
        format: date-time
        type: string
        x-go-name: LastUsedAt
      location:
        description: What cluster member this instance is located on
        example: lxd01
        type: string
        x-go-name: Location
      name:
        description: Instance name
        example: foo
        type: string
        x-go-name: Name
      profiles:
        description: List of profiles applied to the instance
        example:
        - default
        items:
          type: string
        type: array
        x-go-name: Profiles
      project:
        description: Instance project name
        example: foo
        type: string
        x-go-name: Project
      restore:
        description: If set, instance will be restored to the provided snapshot name
        example: snap0
        type: string
        x-go-name: Restore
      snapshots:
        description: List of snapshots.
        items:
          $ref: '#/definitions/InstanceSnapshot'
        type: array
        x-go-name: Snapshots
      state:
        $ref: '#/definitions/InstanceState'
      stateful:
        description: Whether the instance currently has saved state on disk
        example: false
        type: boolean
        x-go-name: Stateful
      status:
        description: Instance status (see instance_state)
        example: Running
        type: string
        x-go-name: Status
      status_code:
        $ref: '#/definitions/StatusCode'
      type:
        description: The type of instance (container or virtual-machine)
        example: container
        type: string
        x-go-name: Type
    title: InstanceFull is a combination of Instance, InstanceBackup, InstanceState
      and InstanceSnapshot.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstancePost:
    properties:
      container_only:
        description: Whether snapshots should be discarded (migration only, deprecated,
          use instance_only)
        example: false
        type: boolean
        x-go-name: ContainerOnly
      instance_only:
        description: Whether snapshots should be discarded (migration only)
        example: false
        type: boolean
        x-go-name: InstanceOnly
      live:
        description: Whether to perform a live migration (migration only)
        example: false
        type: boolean
        x-go-name: Live
      migration:
        description: Whether the instance is being migrated to another server
        example: false
        type: boolean
        x-go-name: Migration
      name:
        description: New name for the instance
        example: bar
        type: string
        x-go-name: Name
      pool:
        description: Target pool for local cross-pool move
        example: baz
        type: string
        x-go-name: Pool
      project:
        description: Target project for local cross-project move
        example: foo
        type: string
        x-go-name: Project
      target:
        $ref: '#/definitions/InstancePostTarget'
    title: InstancePost represents the fields required to rename/move a LXD instance.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstancePostTarget:
    properties:
      certificate:
        description: The certificate of the migration target
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      operation:
        description: The operation URL on the remote target
        example: https://1.2.3.4:8443/1.0/operations/5e8e1638-5345-4c2d-bac9-2c79c8577292
        type: string
        x-go-name: Operation
      secrets:
        additionalProperties:
          type: string
        description: Migration websockets credentials
        example:
          criu: random-string
          migration: random-string
        type: object
        x-go-name: Websockets
    title: InstancePostTarget represents the migration target host and operation.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstancePut:
    properties:
      architecture:
        description: Architecture name
        example: x86_64
        type: string
        x-go-name: Architecture
      config:
        additionalProperties:
          type: string
        description: Instance configuration (see doc/instances.md)
        example:
          security.nesting: "true"
        type: object
        x-go-name: Config
      description:
        description: Instance description
        example: My test instance
        type: string
        x-go-name: Description
      devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: Instance devices (see doc/instances.md)
        example:
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: Devices
      ephemeral:
        description: Whether the instance is ephemeral (deleted on shutdown)
        example: false
        type: boolean
        x-go-name: Ephemeral
      profiles:
        description: List of profiles applied to the instance
        example:
        - default
        items:
          type: string
        type: array
        x-go-name: Profiles
      restore:
        description: If set, instance will be restored to the provided snapshot name
        example: snap0
        type: string
        x-go-name: Restore
      stateful:
        description: Whether the instance currently has saved state on disk
        example: false
        type: boolean
        x-go-name: Stateful
    title: InstancePut represents the modifiable fields of a LXD instance.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceSnapshot:
    properties:
      architecture:
        description: Architecture name
        example: x86_64
        type: string
        x-go-name: Architecture
      config:
        additionalProperties:
          type: string
        description: Instance configuration (see doc/instances.md)
        example:
          security.nesting: "true"
        type: object
        x-go-name: Config
      created_at:
        description: Instance creation timestamp
        example: "2021-03-23T20:00:00-04:00"
        format: date-time
        type: string
        x-go-name: CreatedAt
      devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: Instance devices (see doc/instances.md)
        example:
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: Devices
      ephemeral:
        description: Whether the instance is ephemeral (deleted on shutdown)
        example: false
        type: boolean
        x-go-name: Ephemeral
      expanded_config:
        additionalProperties:
          type: string
        description: Expanded configuration (all profiles and local config merged)
        example:
          security.nesting: "true"
        type: object
        x-go-name: ExpandedConfig
      expanded_devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: Expanded devices (all profiles and local devices merged)
        example:
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: ExpandedDevices
      expires_at:
        description: When the snapshot expires (gets auto-deleted)
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      last_used_at:
        description: Last start timestamp
        example: "2021-03-23T20:00:00-04:00"
        format: date-time
        type: string
        x-go-name: LastUsedAt
      name:
        description: Snapshot name
        example: foo
        type: string
        x-go-name: Name
      profiles:
        description: List of profiles applied to the instance
        example:
        - default
        items:
          type: string
        type: array
        x-go-name: Profiles
      size:
        description: Size of the snapshot in bytes
        example: 143360
        format: int64
        type: integer
        x-go-name: Size
      stateful:
        description: Whether the instance currently has saved state on disk
        example: false
        type: boolean
        x-go-name: Stateful
    title: InstanceSnapshot represents a LXD instance snapshot.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceSnapshotPost:
    properties:
      live:
        description: Whether to perform a live migration (requires migration)
        example: false
        type: boolean
        x-go-name: Live
      migration:
        description: Whether this is a migration request
        example: false
        type: boolean
        x-go-name: Migration
      name:
        description: New name for the snapshot
        example: foo
        type: string
        x-go-name: Name
      target:
        $ref: '#/definitions/InstancePostTarget'
    title: InstanceSnapshotPost represents the fields required to rename/move a LXD
      instance snapshot.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceSnapshotPut:
    properties:
      expires_at:
        description: When the snapshot expires (gets auto-deleted)
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
    title: InstanceSnapshotPut represents the modifiable fields of a LXD instance
      snapshot.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceSnapshotsPost:
    properties:
      expires_at:
        description: When the snapshot expires (gets auto-deleted)
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      name:
        description: Snapshot name
        example: snap0
        type: string
        x-go-name: Name
      stateful:
        description: Whether the snapshot should include runtime state
        example: false
        type: boolean
        x-go-name: Stateful
    title: InstanceSnapshotsPost represents the fields available for a new LXD instance
      snapshot.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceSource:
    properties:
      alias:
        description: Image alias name (for image source)
        example: ubuntu/20.04
        type: string
        x-go-name: Alias
      allow_inconsistent:
        description: Whether to ignore errors when copying (e.g. for volatile files)
        example: false
        type: boolean
        x-go-name: AllowInconsistent
      base-image:
        description: Base image fingerprint (for faster migration)
        example: ed56997f7c5b48e8d78986d2467a26109be6fb9f2d92e8c7b08eb8b6cec7629a
        type: string
        x-go-name: BaseImage
      certificate:
        description: Certificate (for remote images or migration)
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      container_only:
        description: Whether the copy should skip the snapshots (for copy, deprecated,
          use instance_only)
        example: false
        type: boolean
        x-go-name: ContainerOnly
      fingerprint:
        description: Image fingerprint (for image source)
        example: ed56997f7c5b48e8d78986d2467a26109be6fb9f2d92e8c7b08eb8b6cec7629a
        type: string
        x-go-name: Fingerprint
      instance_only:
        description: Whether the copy should skip the snapshots (for copy)
        example: false
        type: boolean
        x-go-name: InstanceOnly
      live:
        description: Whether this is a live migration (for migration)
        example: false
        type: boolean
        x-go-name: Live
      mode:
        description: Whether to use pull or push mode (for migration)
        example: pull
        type: string
        x-go-name: Mode
      operation:
        description: Remote operation URL (for migration)
        example: https://1.2.3.4:8443/1.0/operations/1721ae08-b6a8-416a-9614-3f89302466e1
        type: string
        x-go-name: Operation
      project:
        description: Source project name (for copy and local image)
        example: blah
        type: string
        x-go-name: Project
      properties:
        additionalProperties:
          type: string
        description: Image filters (for image source)
        example:
          os: Ubuntu
          release: focal
          variant: cloud
        type: object
        x-go-name: Properties
      protocol:
        description: Protocol name (for remote image)
        example: simplestreams
        type: string
        x-go-name: Protocol
      refresh:
        description: Whether this is refreshing an existing instance (for migration
          and copy)
        example: false
        type: boolean
        x-go-name: Refresh
      secret:
        description: Remote server secret (for remote private images)
        example: RANDOM-STRING
        type: string
        x-go-name: Secret
      secrets:
        additionalProperties:
          type: string
        description: Map of migration websockets (for migration)
        example:
          criu: RANDOM-STRING
          rsync: RANDOM-STRING
        type: object
        x-go-name: Websockets
      server:
        description: Remote server URL (for remote images)
        example: https://images.linuxcontainers.org
        type: string
        x-go-name: Server
      source:
        description: Existing instance name or snapshot (for copy)
        example: foo/snap0
        type: string
        x-go-name: Source
      type:
        description: Source type
        example: image
        type: string
        x-go-name: Type
    title: InstanceSource represents the creation source for a new instance.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceState:
    properties:
      cpu:
        $ref: '#/definitions/InstanceStateCPU'
      disk:
        additionalProperties:
          $ref: '#/definitions/InstanceStateDisk'
        description: Dict of disk usage
        type: object
        x-go-name: Disk
      memory:
        $ref: '#/definitions/InstanceStateMemory'
      network:
        additionalProperties:
          $ref: '#/definitions/InstanceStateNetwork'
        description: Dict of network usage
        type: object
        x-go-name: Network
      pid:
        description: PID of the runtime
        example: 7281
        format: int64
        type: integer
        x-go-name: Pid
      processes:
        description: Number of processes in the instance
        example: 50
        format: int64
        type: integer
        x-go-name: Processes
      status:
        description: Current status (Running, Stopped, Frozen or Error)
        example: Running
        type: string
        x-go-name: Status
      status_code:
        $ref: '#/definitions/StatusCode'
    title: InstanceState represents a LXD instance's state.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceStateCPU:
    properties:
      usage:
        description: CPU usage in nanoseconds
        example: 3637691016
        format: int64
        type: integer
        x-go-name: Usage
    title: InstanceStateCPU represents the cpu information section of a LXD instance's
      state.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceStateDisk:
    properties:
      usage:
        description: Disk usage in bytes
        example: 502239232
        format: int64
        type: integer
        x-go-name: Usage
    title: InstanceStateDisk represents the disk information section of a LXD instance's
      state.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceStateMemory:
    properties:
      swap_usage:
        description: SWAP usage in bytes
        example: 12297557
        format: int64
        type: integer
        x-go-name: SwapUsage
      swap_usage_peak:
        description: Peak SWAP usage in bytes
        example: 12297557
        format: int64
        type: integer
        x-go-name: SwapUsagePeak
      usage:
        description: Memory usage in bytes
        example: 73248768
        format: int64
        type: integer
        x-go-name: Usage
      usage_peak:
        description: Peak memory usage in bytes
        example: 73785344
        format: int64
        type: integer
        x-go-name: UsagePeak
    title: InstanceStateMemory represents the memory information section of a LXD
      instance's state.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceStateNetwork:
    properties:
      addresses:
        description: List of IP addresses
        items:
          $ref: '#/definitions/InstanceStateNetworkAddress'
        type: array
        x-go-name: Addresses
      counters:
        $ref: '#/definitions/InstanceStateNetworkCounters'
      host_name:
        description: Name of the interface on the host
        example: vethbbcd39c7
        type: string
        x-go-name: HostName
      hwaddr:
        description: MAC address
        example: 00:16:3e:0c:ee:dd
        type: string
        x-go-name: Hwaddr
      mtu:
        description: MTU (maximum transmit unit) for the interface
        example: 1500
        format: int64
        type: integer
        x-go-name: Mtu
      state:
        description: Administrative state of the interface (up/down)
        example: up
        type: string
        x-go-name: State
      type:
        description: Type of interface (broadcast, loopback, point-to-point, ...)
        example: broadcast
        type: string
        x-go-name: Type
    title: InstanceStateNetwork represents the network information section of a LXD
      instance's state.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceStateNetworkAddress:
    description: |-
      InstanceStateNetworkAddress represents a network address as part of the network section of a LXD
      instance's state.
    properties:
      address:
        description: IP address
        example: fd42:4c81:5770:1eaf:216:3eff:fe0c:eedd
        type: string
        x-go-name: Address
      family:
        description: Network family (inet or inet6)
        example: inet6
        type: string
        x-go-name: Family
      netmask:
        description: Network mask
        example: "64"
        type: string
        x-go-name: Netmask
      scope:
        description: Address scope (local, link or global)
        example: global
        type: string
        x-go-name: Scope
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceStateNetworkCounters:
    description: |-
      InstanceStateNetworkCounters represents packet counters as part of the network section of a LXD
      instance's state.
    properties:
      bytes_received:
        description: Number of bytes received
        example: 192021
        format: int64
        type: integer
        x-go-name: BytesReceived
      bytes_sent:
        description: Number of bytes sent
        example: 10888579
        format: int64
        type: integer
        x-go-name: BytesSent
      errors_received:
        description: Number of errors received
        example: 14
        format: int64
        type: integer
        x-go-name: ErrorsReceived
      errors_sent:
        description: Number of errors sent
        example: 41
        format: int64
        type: integer
        x-go-name: ErrorsSent
      packets_dropped_inbound:
        description: Number of inbound packets dropped
        example: 179
        format: int64
        type: integer
        x-go-name: PacketsDroppedInbound
      packets_dropped_outbound:
        description: Number of outbound packets dropped
        example: 541
        format: int64
        type: integer
        x-go-name: PacketsDroppedOutbound
      packets_received:
        description: Number of packets received
        example: 1748
        format: int64
        type: integer
        x-go-name: PacketsReceived
      packets_sent:
        description: Number of packets sent
        example: 964
        format: int64
        type: integer
        x-go-name: PacketsSent
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceStatePut:
    properties:
      action:
        description: State change action (start, stop, restart, freeze, unfreeze)
        example: start
        type: string
        x-go-name: Action
      force:
        description: Whether to force the action (for stop and restart)
        example: false
        type: boolean
        x-go-name: Force
      stateful:
        description: Whether to store the runtime state (for stop)
        example: false
        type: boolean
        x-go-name: Stateful
      timeout:
        description: How long to wait (in s) before giving up (when force isn't set)
        example: 30
        format: int64
        type: integer
        x-go-name: Timeout
    title: InstanceStatePut represents the modifiable fields of a LXD instance's state.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstanceType:
    title: InstanceType represents the type if instance being returned or requested
      via the API.
    type: string
    x-go-package: github.com/lxc/lxd/shared/api
  InstancesPost:
    properties:
      architecture:
        description: Architecture name
        example: x86_64
        type: string
        x-go-name: Architecture
      config:
        additionalProperties:
          type: string
        description: Instance configuration (see doc/instances.md)
        example:
          security.nesting: "true"
        type: object
        x-go-name: Config
      description:
        description: Instance description
        example: My test instance
        type: string
        x-go-name: Description
      devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: Instance devices (see doc/instances.md)
        example:
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: Devices
      ephemeral:
        description: Whether the instance is ephemeral (deleted on shutdown)
        example: false
        type: boolean
        x-go-name: Ephemeral
      instance_type:
        description: Cloud instance type (AWS, GCP, Azure, ...) to emulate with limits
        example: t1.micro
        type: string
        x-go-name: InstanceType
      name:
        description: Instance name
        example: foo
        type: string
        x-go-name: Name
      profiles:
        description: List of profiles applied to the instance
        example:
        - default
        items:
          type: string
        type: array
        x-go-name: Profiles
      restore:
        description: If set, instance will be restored to the provided snapshot name
        example: snap0
        type: string
        x-go-name: Restore
      source:
        $ref: '#/definitions/InstanceSource'
      stateful:
        description: Whether the instance currently has saved state on disk
        example: false
        type: boolean
        x-go-name: Stateful
      type:
        $ref: '#/definitions/InstanceType'
    title: InstancesPost represents the fields available for a new LXD instance.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  InstancesPut:
    properties:
      state:
        $ref: '#/definitions/InstanceStatePut'
    title: InstancesPut represents the fields available for a mass update.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Network:
    description: Network represents a LXD network
    properties:
      config:
        additionalProperties:
          type: string
        description: Network configuration map (refer to doc/networks.md)
        example:
          ipv4.address: 10.0.0.1/24
          ipv4.nat: "true"
          ipv6.address: none
        type: object
        x-go-name: Config
      description:
        description: Description of the profile
        example: My new LXD bridge
        type: string
        x-go-name: Description
      locations:
        description: Cluster members on which the network has been defined
        example:
        - lxd01
        - lxd02
        - lxd03
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: Locations
      managed:
        description: Whether this is a LXD managed network
        example: true
        readOnly: true
        type: boolean
        x-go-name: Managed
      name:
        description: The network name
        example: lxdbr0
        readOnly: true
        type: string
        x-go-name: Name
      status:
        description: The state of the network (for managed network in clusters)
        example: Created
        readOnly: true
        type: string
        x-go-name: Status
      type:
        description: The network type
        example: bridge
        readOnly: true
        type: string
        x-go-name: Type
      used_by:
        description: List of URLs of objects using this profile
        example:
        - /1.0/profiles/default
        - /1.0/instances/c1
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: UsedBy
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkACL:
    properties:
      config:
        additionalProperties:
          type: string
        description: ACL configuration map (refer to doc/network-acls.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the ACL
        example: Web servers
        type: string
        x-go-name: Description
      egress:
        description: List of egress rules (order independent)
        items:
          $ref: '#/definitions/NetworkACLRule'
        type: array
        x-go-name: Egress
      ingress:
        description: List of ingress rules (order independent)
        items:
          $ref: '#/definitions/NetworkACLRule'
        type: array
        x-go-name: Ingress
      name:
        description: The new name for the ACL
        example: bar
        type: string
        x-go-name: Name
      used_by:
        description: List of URLs of objects using this profile
        example:
        - /1.0/instances/c1
        - /1.0/instances/v1
        - /1.0/networks/lxdbr0
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: UsedBy
    title: NetworkACL used for displaying an ACL.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkACLPost:
    properties:
      name:
        description: The new name for the ACL
        example: bar
        type: string
        x-go-name: Name
    title: NetworkACLPost used for renaming an ACL.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkACLPut:
    properties:
      config:
        additionalProperties:
          type: string
        description: ACL configuration map (refer to doc/network-acls.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the ACL
        example: Web servers
        type: string
        x-go-name: Description
      egress:
        description: List of egress rules (order independent)
        items:
          $ref: '#/definitions/NetworkACLRule'
        type: array
        x-go-name: Egress
      ingress:
        description: List of ingress rules (order independent)
        items:
          $ref: '#/definitions/NetworkACLRule'
        type: array
        x-go-name: Ingress
    title: NetworkACLPut used for updating an ACL.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkACLRule:
    description: Refer to doc/network-acls.md for details.
    properties:
      action:
        description: Action to perform on rule match
        example: allow
        type: string
        x-go-name: Action
      description:
        description: Description of the rule
        example: Allow DNS queries to Google DNS
        type: string
        x-go-name: Description
      destination:
        description: Destination address
        example: 8.8.8.8/32,8.8.4.4/32
        type: string
        x-go-name: Destination
      destination_port:
        description: Destination port
        example: "53"
        type: string
        x-go-name: DestinationPort
      icmp_code:
        description: ICMP message code (for ICMP protocol)
        example: "0"
        type: string
        x-go-name: ICMPCode
      icmp_type:
        description: Type of ICMP message (for ICMP protocol)
        example: "8"
        type: string
        x-go-name: ICMPType
      protocol:
        description: Protocol
        example: udp
        type: string
        x-go-name: Protocol
      source:
        description: Source address
        example: '@internal'
        type: string
        x-go-name: Source
      source_port:
        description: Source port
        example: "1234"
        type: string
        x-go-name: SourcePort
      state:
        description: State of the rule
        example: enabled
        type: string
        x-go-name: State
    title: NetworkACLRule represents a single rule in an ACL ruleset.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkACLsPost:
    properties:
      config:
        additionalProperties:
          type: string
        description: ACL configuration map (refer to doc/network-acls.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the ACL
        example: Web servers
        type: string
        x-go-name: Description
      egress:
        description: List of egress rules (order independent)
        items:
          $ref: '#/definitions/NetworkACLRule'
        type: array
        x-go-name: Egress
      ingress:
        description: List of ingress rules (order independent)
        items:
          $ref: '#/definitions/NetworkACLRule'
        type: array
        x-go-name: Ingress
      name:
        description: The new name for the ACL
        example: bar
        type: string
        x-go-name: Name
    title: NetworkACLsPost used for creating an ACL.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkForward:
    properties:
      config:
        additionalProperties:
          type: string
        description: Forward configuration map (refer to doc/network-forwards.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the forward listen IP
        example: My public IP forward
        type: string
        x-go-name: Description
      listen_address:
        description: The listen address of the forward
        example: 192.0.2.1
        type: string
        x-go-name: ListenAddress
      location:
        description: What cluster member this record was found on
        example: lxd01
        type: string
        x-go-name: Location
      ports:
        description: Port forwards (optional)
        items:
          $ref: '#/definitions/NetworkForwardPort'
        type: array
        x-go-name: Ports
    title: NetworkForward used for displaying an network address forward.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkForwardPort:
    description: NetworkForwardPort represents a port specification in a network address
      forward
    properties:
      description:
        description: Description of the forward port
        example: My web server forward
        type: string
        x-go-name: Description
      listen_port:
        description: ListenPort(s) to forward (comma delimited ranges)
        example: 80,81,8080-8090
        type: string
        x-go-name: ListenPort
      protocol:
        description: Protocol for port forward (either tcp or udp)
        example: tcp
        type: string
        x-go-name: Protocol
      target_address:
        description: TargetAddress to forward ListenPorts to
        example: 198.51.100.2
        type: string
        x-go-name: TargetAddress
      target_port:
        description: TargetPort(s) to forward ListenPorts to (allows for many-to-one)
        example: 80,81,8080-8090
        type: string
        x-go-name: TargetPort
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkForwardPut:
    description: NetworkForwardPut represents the modifiable fields of a LXD network
      address forward
    properties:
      config:
        additionalProperties:
          type: string
        description: Forward configuration map (refer to doc/network-forwards.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the forward listen IP
        example: My public IP forward
        type: string
        x-go-name: Description
      ports:
        description: Port forwards (optional)
        items:
          $ref: '#/definitions/NetworkForwardPort'
        type: array
        x-go-name: Ports
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkForwardsPost:
    description: NetworkForwardsPost represents the fields of a new LXD network address
      forward
    properties:
      config:
        additionalProperties:
          type: string
        description: Forward configuration map (refer to doc/network-forwards.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the forward listen IP
        example: My public IP forward
        type: string
        x-go-name: Description
      listen_address:
        description: The listen address of the forward
        example: 192.0.2.1
        type: string
        x-go-name: ListenAddress
      ports:
        description: Port forwards (optional)
        items:
          $ref: '#/definitions/NetworkForwardPort'
        type: array
        x-go-name: Ports
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkLease:
    description: NetworkLease represents a DHCP lease
    properties:
      address:
        description: The IP address
        example: 10.0.0.98
        type: string
        x-go-name: Address
      hostname:
        description: The hostname associated with the record
        example: c1
        type: string
        x-go-name: Hostname
      hwaddr:
        description: The MAC address
        example: 00:16:3e:2c:89:d9
        type: string
        x-go-name: Hwaddr
      location:
        description: What cluster member this record was found on
        example: lxd01
        type: string
        x-go-name: Location
      type:
        description: The type of record (static or dynamic)
        example: dynamic
        type: string
        x-go-name: Type
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkPeer:
    properties:
      config:
        additionalProperties:
          type: string
        description: Peer configuration map (refer to doc/network-peers.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the peer
        example: Peering with network1 in project1
        type: string
        x-go-name: Description
      name:
        description: Name of the peer
        example: project1-network1
        readOnly: true
        type: string
        x-go-name: Name
      status:
        description: The state of the peering
        example: Pending
        readOnly: true
        type: string
        x-go-name: Status
      target_network:
        description: Name of the target network
        example: network1
        readOnly: true
        type: string
        x-go-name: TargetNetwork
      target_project:
        description: Name of the target project
        example: project1
        readOnly: true
        type: string
        x-go-name: TargetProject
      used_by:
        description: List of URLs of objects using this network peering
        example:
        - /1.0/network-acls/test
        - /1.0/network-acls/foo
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: UsedBy
    title: NetworkPeer used for displaying a LXD network peering.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkPeerPut:
    description: NetworkPeerPut represents the modifiable fields of a LXD network
      peering
    properties:
      config:
        additionalProperties:
          type: string
        description: Peer configuration map (refer to doc/network-peers.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the peer
        example: Peering with network1 in project1
        type: string
        x-go-name: Description
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkPeersPost:
    description: NetworkPeersPost represents the fields of a new LXD network peering
    properties:
      config:
        additionalProperties:
          type: string
        description: Peer configuration map (refer to doc/network-peers.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the peer
        example: Peering with network1 in project1
        type: string
        x-go-name: Description
      name:
        description: Name of the peer
        example: project1-network1
        type: string
        x-go-name: Name
      target_network:
        description: Name of the target network
        example: network1
        type: string
        x-go-name: TargetNetwork
      target_project:
        description: Name of the target project
        example: project1
        type: string
        x-go-name: TargetProject
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkPost:
    description: NetworkPost represents the fields required to rename a LXD network
    properties:
      name:
        description: The new name for the network
        example: lxdbr1
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkPut:
    description: NetworkPut represents the modifiable fields of a LXD network
    properties:
      config:
        additionalProperties:
          type: string
        description: Network configuration map (refer to doc/networks.md)
        example:
          ipv4.address: 10.0.0.1/24
          ipv4.nat: "true"
          ipv6.address: none
        type: object
        x-go-name: Config
      description:
        description: Description of the profile
        example: My new LXD bridge
        type: string
        x-go-name: Description
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkState:
    description: NetworkState represents the network state
    properties:
      addresses:
        description: List of addresses
        items:
          $ref: '#/definitions/NetworkStateAddress'
        type: array
        x-go-name: Addresses
      bond:
        $ref: '#/definitions/NetworkStateBond'
      bridge:
        $ref: '#/definitions/NetworkStateBridge'
      counters:
        $ref: '#/definitions/NetworkStateCounters'
      hwaddr:
        description: MAC address
        example: 00:16:3e:5a:83:57
        type: string
        x-go-name: Hwaddr
      mtu:
        description: MTU
        example: 1500
        format: int64
        type: integer
        x-go-name: Mtu
      ovn:
        $ref: '#/definitions/NetworkStateOVN'
      state:
        description: Link state
        example: up
        type: string
        x-go-name: State
      type:
        description: Interface type
        example: broadcast
        type: string
        x-go-name: Type
      vlan:
        $ref: '#/definitions/NetworkStateVLAN'
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkStateAddress:
    description: NetworkStateAddress represents a network address
    properties:
      address:
        description: IP address
        example: 10.0.0.1
        type: string
        x-go-name: Address
      family:
        description: Address family
        example: inet
        type: string
        x-go-name: Family
      netmask:
        description: IP netmask (CIDR)
        example: "24"
        type: string
        x-go-name: Netmask
      scope:
        description: Address scope
        example: global
        type: string
        x-go-name: Scope
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkStateBond:
    description: NetworkStateBond represents bond specific state
    properties:
      down_delay:
        description: Delay on link down (ms)
        example: 0
        format: uint64
        type: integer
        x-go-name: DownDelay
      lower_devices:
        description: List of devices that are part of the bond
        example:
        - eth0
        - eth1
        items:
          type: string
        type: array
        x-go-name: LowerDevices
      mii_frequency:
        description: How often to check for link state (ms)
        example: 100
        format: uint64
        type: integer
        x-go-name: MIIFrequency
      mii_state:
        description: Bond link state
        example: up
        type: string
        x-go-name: MIIState
      mode:
        description: Bonding mode
        example: 802.3ad
        type: string
        x-go-name: Mode
      transmit_policy:
        description: Transmit balancing policy
        example: layer3+4
        type: string
        x-go-name: TransmitPolicy
      up_delay:
        description: Delay on link up (ms)
        example: 0
        format: uint64
        type: integer
        x-go-name: UpDelay
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkStateBridge:
    description: NetworkStateBridge represents bridge specific state
    properties:
      forward_delay:
        description: Delay on port join (ms)
        example: 1500
        format: uint64
        type: integer
        x-go-name: ForwardDelay
      id:
        description: Bridge ID
        example: 8000.0a0f7c6edbd9
        type: string
        x-go-name: ID
      stp:
        description: Whether STP is enabled
        example: false
        type: boolean
        x-go-name: STP
      upper_devices:
        description: List of devices that are in the bridge
        example:
        - eth0
        - eth1
        items:
          type: string
        type: array
        x-go-name: UpperDevices
      vlan_default:
        description: Default VLAN ID
        example: 1
        format: uint64
        type: integer
        x-go-name: VLANDefault
      vlan_filtering:
        description: Whether VLAN filtering is enabled
        example: false
        type: boolean
        x-go-name: VLANFiltering
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkStateCounters:
    description: NetworkStateCounters represents packet counters
    properties:
      bytes_received:
        description: Number of bytes received
        example: 250542118
        format: int64
        type: integer
        x-go-name: BytesReceived
      bytes_sent:
        description: Number of bytes sent
        example: 17524040140
        format: int64
        type: integer
        x-go-name: BytesSent
      packets_received:
        description: Number of packets received
        example: 1182515
        format: int64
        type: integer
        x-go-name: PacketsReceived
      packets_sent:
        description: Number of packets sent
        example: 1567934
        format: int64
        type: integer
        x-go-name: PacketsSent
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkStateOVN:
    description: NetworkStateOVN represents OVN specific state
    properties:
      chassis:
        description: OVN network chassis name
        type: string
        x-go-name: Chassis
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkStateVLAN:
    description: NetworkStateVLAN represents VLAN specific state
    properties:
      lower_device:
        description: Parent device
        example: eth0
        type: string
        x-go-name: LowerDevice
      vid:
        description: VLAN ID
        example: 100
        format: uint64
        type: integer
        x-go-name: VID
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkZone:
    properties:
      config:
        additionalProperties:
          type: string
        description: Zone configuration map (refer to doc/network-zones.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the network zone
        example: Internal domain
        type: string
        x-go-name: Description
      name:
        description: The name of the zone (DNS domain name)
        example: example.net
        type: string
        x-go-name: Name
      used_by:
        description: List of URLs of objects using this network zone
        example:
        - /1.0/networks/foo
        - /1.0/networks/bar
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: UsedBy
    title: NetworkZone represents a network zone (DNS).
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkZonePut:
    description: NetworkZonePut represents the modifiable fields of a LXD network
      zone
    properties:
      config:
        additionalProperties:
          type: string
        description: Zone configuration map (refer to doc/network-zones.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the network zone
        example: Internal domain
        type: string
        x-go-name: Description
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkZoneRecord:
    properties:
      config:
        additionalProperties:
          type: string
        description: Advanced configuration for the record
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the record
        example: SPF record
        type: string
        x-go-name: Description
      entries:
        description: Entries in the record
        items:
          $ref: '#/definitions/NetworkZoneRecordEntry'
        type: array
        x-go-name: Entries
      name:
        description: The name of the record
        example: '@'
        type: string
        x-go-name: Name
    title: NetworkZoneRecord represents a network zone (DNS) record.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkZoneRecordEntry:
    description: NetworkZoneRecordEntry represents the fields in a record entry
    properties:
      ttl:
        description: TTL for the entry
        example: 3600
        format: uint64
        type: integer
        x-go-name: TTL
      type:
        description: Type of DNS entry
        example: TXT
        type: string
        x-go-name: Type
      value:
        description: Value for the record
        example: v=spf1 mx ~all
        type: string
        x-go-name: Value
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkZoneRecordPut:
    description: NetworkZoneRecordPut represents the modifiable fields of a LXD network
      zone record
    properties:
      config:
        additionalProperties:
          type: string
        description: Advanced configuration for the record
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the record
        example: SPF record
        type: string
        x-go-name: Description
      entries:
        description: Entries in the record
        items:
          $ref: '#/definitions/NetworkZoneRecordEntry'
        type: array
        x-go-name: Entries
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkZoneRecordsPost:
    description: NetworkZoneRecordsPost represents the fields of a new LXD network
      zone record
    properties:
      config:
        additionalProperties:
          type: string
        description: Advanced configuration for the record
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the record
        example: SPF record
        type: string
        x-go-name: Description
      entries:
        description: Entries in the record
        items:
          $ref: '#/definitions/NetworkZoneRecordEntry'
        type: array
        x-go-name: Entries
      name:
        description: The record name in the zone
        example: '@'
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworkZonesPost:
    description: NetworkZonesPost represents the fields of a new LXD network zone
    properties:
      config:
        additionalProperties:
          type: string
        description: Zone configuration map (refer to doc/network-zones.md)
        example:
          user.mykey: foo
        type: object
        x-go-name: Config
      description:
        description: Description of the network zone
        example: Internal domain
        type: string
        x-go-name: Description
      name:
        description: The name of the zone (DNS domain name)
        example: example.net
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  NetworksPost:
    description: NetworksPost represents the fields of a new LXD network
    properties:
      config:
        additionalProperties:
          type: string
        description: Network configuration map (refer to doc/networks.md)
        example:
          ipv4.address: 10.0.0.1/24
          ipv4.nat: "true"
          ipv6.address: none
        type: object
        x-go-name: Config
      description:
        description: Description of the profile
        example: My new LXD bridge
        type: string
        x-go-name: Description
      name:
        description: The name of the new network
        example: lxdbr1
        type: string
        x-go-name: Name
      type:
        description: The network type (refer to doc/networks.md)
        example: bridge
        type: string
        x-go-name: Type
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Operation:
    description: Operation represents a LXD background operation
    properties:
      class:
        description: Type of operation (task, token or websocket)
        example: websocket
        type: string
        x-go-name: Class
      created_at:
        description: Operation creation time
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: CreatedAt
      description:
        description: Description of the operation
        example: Executing command
        type: string
        x-go-name: Description
      err:
        description: Operation error mesage
        example: Some error message
        type: string
        x-go-name: Err
      id:
        description: UUID of the operation
        example: 6916c8a6-9b7d-4abd-90b3-aedfec7ec7da
        type: string
        x-go-name: ID
      location:
        description: What cluster member this record was found on
        example: lxd01
        type: string
        x-go-name: Location
      may_cancel:
        description: Whether the operation can be canceled
        example: false
        type: boolean
        x-go-name: MayCancel
      metadata:
        additionalProperties:
          type: object
        description: Operation specific metadata
        example:
          command:
          - bash
          environment:
            HOME: /root
            LANG: C.UTF-8
            PATH: /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
            TERM: xterm
            USER: root
          fds:
            "0": da3046cf02c0116febf4ef3fe4eaecdf308e720c05e5a9c730ce1a6f15417f66
            "1": 05896879d8692607bd6e4a09475667da3b5f6714418ab0ee0e5720b4c57f754b
          interactive: true
        type: object
        x-go-name: Metadata
      resources:
        additionalProperties:
          items:
            type: string
          type: array
        description: Affected resourcs
        example:
          containers:
          - /1.0/containers/foo
          instances:
          - /1.0/instances/foo
        type: object
        x-go-name: Resources
      status:
        description: Status name
        example: Running
        type: string
        x-go-name: Status
      status_code:
        $ref: '#/definitions/StatusCode'
      updated_at:
        description: Operation last change
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: UpdatedAt
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Profile:
    description: Profile represents a LXD profile
    properties:
      config:
        additionalProperties:
          type: string
        description: Instance configuration map (refer to doc/instances.md)
        example:
          limits.cpu: "4"
          limits.memory: 4GiB
        type: object
        x-go-name: Config
      description:
        description: Description of the profile
        example: Medium size instances
        type: string
        x-go-name: Description
      devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: List of devices
        example:
          eth0:
            name: eth0
            network: lxdbr0
            type: nic
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: Devices
      name:
        description: The profile name
        example: foo
        readOnly: true
        type: string
        x-go-name: Name
      used_by:
        description: List of URLs of objects using this profile
        example:
        - /1.0/instances/c1
        - /1.0/instances/v1
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: UsedBy
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ProfilePost:
    description: ProfilePost represents the fields required to rename a LXD profile
    properties:
      name:
        description: The new name for the profile
        example: bar
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ProfilePut:
    description: ProfilePut represents the modifiable fields of a LXD profile
    properties:
      config:
        additionalProperties:
          type: string
        description: Instance configuration map (refer to doc/instances.md)
        example:
          limits.cpu: "4"
          limits.memory: 4GiB
        type: object
        x-go-name: Config
      description:
        description: Description of the profile
        example: Medium size instances
        type: string
        x-go-name: Description
      devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: List of devices
        example:
          eth0:
            name: eth0
            network: lxdbr0
            type: nic
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: Devices
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ProfilesPost:
    description: ProfilesPost represents the fields of a new LXD profile
    properties:
      config:
        additionalProperties:
          type: string
        description: Instance configuration map (refer to doc/instances.md)
        example:
          limits.cpu: "4"
          limits.memory: 4GiB
        type: object
        x-go-name: Config
      description:
        description: Description of the profile
        example: Medium size instances
        type: string
        x-go-name: Description
      devices:
        additionalProperties:
          additionalProperties:
            type: string
          type: object
        description: List of devices
        example:
          eth0:
            name: eth0
            network: lxdbr0
            type: nic
          root:
            path: /
            pool: default
            type: disk
        type: object
        x-go-name: Devices
      name:
        description: The name of the new profile
        example: foo
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Project:
    description: Project represents a LXD project
    properties:
      config:
        additionalProperties:
          type: string
        description: Project configuration map (refer to doc/projects.md)
        example:
          features.networks: "false"
          features.profiles: "true"
        type: object
        x-go-name: Config
      description:
        description: Description of the project
        example: My new project
        type: string
        x-go-name: Description
      name:
        description: The project name
        example: foo
        readOnly: true
        type: string
        x-go-name: Name
      used_by:
        description: List of URLs of objects using this project
        example:
        - /1.0/images/0e60015346f06627f10580d56ac7fffd9ea775f6d4f25987217d5eed94910a20
        - /1.0/instances/c1
        - /1.0/networks/lxdbr0
        - /1.0/profiles/default
        - /1.0/storage-pools/default/volumes/custom/blah
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: UsedBy
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ProjectPost:
    description: ProjectPost represents the fields required to rename a LXD project
    properties:
      name:
        description: The new name for the project
        example: bar
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ProjectPut:
    description: ProjectPut represents the modifiable fields of a LXD project
    properties:
      config:
        additionalProperties:
          type: string
        description: Project configuration map (refer to doc/projects.md)
        example:
          features.networks: "false"
          features.profiles: "true"
        type: object
        x-go-name: Config
      description:
        description: Description of the project
        example: My new project
        type: string
        x-go-name: Description
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ProjectState:
    description: ProjectState represents the current running state of a LXD project
    properties:
      resources:
        additionalProperties:
          $ref: '#/definitions/ProjectStateResource'
        description: Allocated and used resources
        example:
          containers:
            limit: 10
            usage: 4
          cpu:
            limit: 20
            usage: 16
        readOnly: true
        type: object
        x-go-name: Resources
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ProjectStateResource:
    description: ProjectStateResource represents the state of a particular resource
      in a LXD project
    properties:
      Limit:
        description: Limit for the resource (-1 if none)
        example: 10
        format: int64
        type: integer
      Usage:
        description: Current usage for the resource
        example: 4
        format: int64
        type: integer
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ProjectsPost:
    description: ProjectsPost represents the fields of a new LXD project
    properties:
      config:
        additionalProperties:
          type: string
        description: Project configuration map (refer to doc/projects.md)
        example:
          features.networks: "false"
          features.profiles: "true"
        type: object
        x-go-name: Config
      description:
        description: Description of the project
        example: My new project
        type: string
        x-go-name: Description
      name:
        description: The name of the new project
        example: foo
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Resources:
    description: Resources represents the system resources available for LXD
    properties:
      cpu:
        $ref: '#/definitions/ResourcesCPU'
      gpu:
        $ref: '#/definitions/ResourcesGPU'
      memory:
        $ref: '#/definitions/ResourcesMemory'
      network:
        $ref: '#/definitions/ResourcesNetwork'
      pci:
        $ref: '#/definitions/ResourcesPCI'
      storage:
        $ref: '#/definitions/ResourcesStorage'
      system:
        $ref: '#/definitions/ResourcesSystem'
      usb:
        $ref: '#/definitions/ResourcesUSB'
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesCPU:
    description: ResourcesCPU represents the cpu resources available on the system
    properties:
      architecture:
        description: Architecture name
        example: x86_64
        type: string
        x-go-name: Architecture
      sockets:
        description: List of CPU sockets
        items:
          $ref: '#/definitions/ResourcesCPUSocket'
        type: array
        x-go-name: Sockets
      total:
        description: Total number of CPU threads (from all sockets and cores)
        example: 1
        format: uint64
        type: integer
        x-go-name: Total
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesCPUCache:
    description: ResourcesCPUCache represents a CPU cache
    properties:
      level:
        description: Cache level (usually a number from 1 to 3)
        example: 1
        format: uint64
        type: integer
        x-go-name: Level
      size:
        description: Size of the cache (in bytes)
        example: 32768
        format: uint64
        type: integer
        x-go-name: Size
      type:
        description: Type of cache (Data, Instruction, Unified, ...)
        example: Data
        type: string
        x-go-name: Type
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesCPUCore:
    description: ResourcesCPUCore represents a CPU core on the system
    properties:
      core:
        description: Core identifier within the socket
        example: 0
        format: uint64
        type: integer
        x-go-name: Core
      die:
        description: What die the CPU is a part of (for chiplet designs)
        example: 0
        format: uint64
        type: integer
        x-go-name: Die
      frequency:
        description: Current frequency
        example: 3500
        format: uint64
        type: integer
        x-go-name: Frequency
      threads:
        description: List of threads
        items:
          $ref: '#/definitions/ResourcesCPUThread'
        type: array
        x-go-name: Threads
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesCPUSocket:
    description: ResourcesCPUSocket represents a CPU socket on the system
    properties:
      cache:
        description: List of CPU caches
        items:
          $ref: '#/definitions/ResourcesCPUCache'
        type: array
        x-go-name: Cache
      cores:
        description: List of CPU cores
        items:
          $ref: '#/definitions/ResourcesCPUCore'
        type: array
        x-go-name: Cores
      frequency:
        description: Current CPU frequency (Mhz)
        example: 3499
        format: uint64
        type: integer
        x-go-name: Frequency
      frequency_minimum:
        description: Minimum CPU frequency (Mhz)
        example: 400
        format: uint64
        type: integer
        x-go-name: FrequencyMinimum
      frequency_turbo:
        description: Maximum CPU frequency (Mhz)
        example: 3500
        format: uint64
        type: integer
        x-go-name: FrequencyTurbo
      name:
        description: Product name
        example: Intel(R) Core(TM) i5-7300U CPU @ 2.60GHz
        type: string
        x-go-name: Name
      socket:
        description: Socket number
        example: 0
        format: uint64
        type: integer
        x-go-name: Socket
      vendor:
        description: Vendor name
        example: GenuineIntel
        type: string
        x-go-name: Vendor
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesCPUThread:
    description: ResourcesCPUThread represents a CPU thread on the system
    properties:
      id:
        description: Thread ID (used for CPU pinning)
        example: 0
        format: int64
        type: integer
        x-go-name: ID
      isolated:
        description: Whether the thread has been isolated (outside of normal scheduling)
        example: false
        type: boolean
        x-go-name: Isolated
      numa_node:
        description: NUMA node the thread is a part of
        example: 0
        format: uint64
        type: integer
        x-go-name: NUMANode
      online:
        description: Whether the thread is online (enabled)
        example: true
        type: boolean
        x-go-name: Online
      thread:
        description: Thread identifier within the core
        example: 0
        format: uint64
        type: integer
        x-go-name: Thread
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesGPU:
    description: ResourcesGPU represents the GPU resources available on the system
    properties:
      cards:
        description: List of GPUs
        items:
          $ref: '#/definitions/ResourcesGPUCard'
        type: array
        x-go-name: Cards
      total:
        description: Total number of GPUs
        example: 1
        format: uint64
        type: integer
        x-go-name: Total
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesGPUCard:
    description: ResourcesGPUCard represents a GPU card on the system
    properties:
      driver:
        description: Kernel driver currently associated with the GPU
        example: i915
        type: string
        x-go-name: Driver
      driver_version:
        description: Version of the kernel driver
        example: 5.8.0-36-generic
        type: string
        x-go-name: DriverVersion
      drm:
        $ref: '#/definitions/ResourcesGPUCardDRM'
      mdev:
        additionalProperties:
          $ref: '#/definitions/ResourcesGPUCardMdev'
        description: Map of available mediated device profiles
        example: null
        type: object
        x-go-name: Mdev
      numa_node:
        description: NUMA node the GPU is a part of
        example: 0
        format: uint64
        type: integer
        x-go-name: NUMANode
      nvidia:
        $ref: '#/definitions/ResourcesGPUCardNvidia'
      pci_address:
        description: PCI address
        example: "0000:00:02.0"
        type: string
        x-go-name: PCIAddress
      product:
        description: Name of the product
        example: HD Graphics 620
        type: string
        x-go-name: Product
      product_id:
        description: PCI ID of the product
        example: "5916"
        type: string
        x-go-name: ProductID
      sriov:
        $ref: '#/definitions/ResourcesGPUCardSRIOV'
      usb_address:
        description: USB address (for USB cards)
        example: "2:7"
        type: string
        x-go-name: USBAddress
      vendor:
        description: Name of the vendor
        example: Intel Corporation
        type: string
        x-go-name: Vendor
      vendor_id:
        description: PCI ID of the vendor
        example: "8086"
        type: string
        x-go-name: VendorID
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesGPUCardDRM:
    description: ResourcesGPUCardDRM represents the Linux DRM configuration of the
      GPU
    properties:
      card_device:
        description: Card device number
        example: "226:0"
        type: string
        x-go-name: CardDevice
      card_name:
        description: Card device name
        example: card0
        type: string
        x-go-name: CardName
      control_device:
        description: Control device number
        example: "226:0"
        type: string
        x-go-name: ControlDevice
      control_name:
        description: Control device name
        example: controlD64
        type: string
        x-go-name: ControlName
      id:
        description: DRM card ID
        example: 0
        format: uint64
        type: integer
        x-go-name: ID
      render_device:
        description: Render device number
        example: 226:128
        type: string
        x-go-name: RenderDevice
      render_name:
        description: Render device name
        example: renderD128
        type: string
        x-go-name: RenderName
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesGPUCardMdev:
    description: ResourcesGPUCardMdev represents the mediated devices configuration
      of the GPU
    properties:
      api:
        description: The mechanism used by this device
        example: vfio-pci
        type: string
        x-go-name: API
      available:
        description: Number of available devices of this profile
        example: 2
        format: uint64
        type: integer
        x-go-name: Available
      description:
        description: Profile description
        example: 'low_gm_size: 128MB\nhigh_gm_size: 512MB\nfence: 4\nresolution: 1920x1200\nweight:
          4'
        type: string
        x-go-name: Description
      devices:
        description: List of active devices (UUIDs)
        example:
        - 42200aac-0977-495c-8c9e-6c51b9092a01
        - b4950c00-1437-41d9-88f6-28d61cf9b9ef
        items:
          type: string
        type: array
        x-go-name: Devices
      name:
        description: Profile name
        example: i915-GVTg_V5_8
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesGPUCardNvidia:
    description: ResourcesGPUCardNvidia represents additional information for NVIDIA
      GPUs
    properties:
      architecture:
        description: Architecture (generation)
        example: "3.5"
        type: string
        x-go-name: Architecture
      brand:
        description: Brand name
        example: GeForce
        type: string
        x-go-name: Brand
      card_device:
        description: Card device number
        example: "195:0"
        type: string
        x-go-name: CardDevice
      card_name:
        description: Card device name
        example: nvidia0
        type: string
        x-go-name: CardName
      cuda_version:
        description: Version of the CUDA API
        example: "11.0"
        type: string
        x-go-name: CUDAVersion
      model:
        description: Model name
        example: GeForce GT 730
        type: string
        x-go-name: Model
      nvrm_version:
        description: Version of the NVRM (usually driver version)
        example: 450.102.04
        type: string
        x-go-name: NVRMVersion
      uuid:
        description: GPU UUID
        example: GPU-6ddadebd-dafe-2db9-f10f-125719770fd3
        type: string
        x-go-name: UUID
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesGPUCardSRIOV:
    description: ResourcesGPUCardSRIOV represents the SRIOV configuration of the GPU
    properties:
      current_vfs:
        description: Number of VFs currently configured
        example: 0
        format: uint64
        type: integer
        x-go-name: CurrentVFs
      maximum_vfs:
        description: Maximum number of supported VFs
        example: 0
        format: uint64
        type: integer
        x-go-name: MaximumVFs
      vfs:
        description: List of VFs (as additional GPU devices)
        example: null
        items:
          $ref: '#/definitions/ResourcesGPUCard'
        type: array
        x-go-name: VFs
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesMemory:
    description: ResourcesMemory represents the memory resources available on the
      system
    properties:
      hugepages_size:
        description: Size of memory huge pages (bytes)
        example: 2097152
        format: uint64
        type: integer
        x-go-name: HugepagesSize
      hugepages_total:
        description: Total of memory huge pages (bytes)
        example: 429284917248
        format: uint64
        type: integer
        x-go-name: HugepagesTotal
      hugepages_used:
        description: Used memory huge pages (bytes)
        example: 429284917248
        format: uint64
        type: integer
        x-go-name: HugepagesUsed
      nodes:
        description: List of NUMA memory nodes
        example: null
        items:
          $ref: '#/definitions/ResourcesMemoryNode'
        type: array
        x-go-name: Nodes
      total:
        description: Total system memory (bytes)
        example: 687194767360
        format: uint64
        type: integer
        x-go-name: Total
      used:
        description: Used system memory (bytes)
        example: 557450502144
        format: uint64
        type: integer
        x-go-name: Used
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesMemoryNode:
    description: ResourcesMemoryNode represents the node-specific memory resources
      available on the system
    properties:
      hugepages_total:
        description: Total of memory huge pages (bytes)
        example: 214536552448
        format: uint64
        type: integer
        x-go-name: HugepagesTotal
      hugepages_used:
        description: Used memory huge pages (bytes)
        example: 214536552448
        format: uint64
        type: integer
        x-go-name: HugepagesUsed
      numa_node:
        description: NUMA node identifier
        example: 0
        format: uint64
        type: integer
        x-go-name: NUMANode
      total:
        description: Total system memory (bytes)
        example: 343597383680
        format: uint64
        type: integer
        x-go-name: Total
      used:
        description: Used system memory (bytes)
        example: 264880439296
        format: uint64
        type: integer
        x-go-name: Used
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesNetwork:
    description: ResourcesNetwork represents the network cards available on the system
    properties:
      cards:
        description: List of network cards
        items:
          $ref: '#/definitions/ResourcesNetworkCard'
        type: array
        x-go-name: Cards
      total:
        description: Total number of network cards
        example: 1
        format: uint64
        type: integer
        x-go-name: Total
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesNetworkCard:
    description: ResourcesNetworkCard represents a network card on the system
    properties:
      driver:
        description: Kernel driver currently associated with the card
        example: atlantic
        type: string
        x-go-name: Driver
      driver_version:
        description: Version of the kernel driver
        example: 5.8.0-36-generic
        type: string
        x-go-name: DriverVersion
      firmware_version:
        description: Current firmware version
        example: 3.1.100
        type: string
        x-go-name: FirmwareVersion
      numa_node:
        description: NUMA node the card is a part of
        example: 0
        format: uint64
        type: integer
        x-go-name: NUMANode
      pci_address:
        description: PCI address (for PCI cards)
        example: 0000:0d:00.0
        type: string
        x-go-name: PCIAddress
      ports:
        description: List of ports on the card
        items:
          $ref: '#/definitions/ResourcesNetworkCardPort'
        type: array
        x-go-name: Ports
      product:
        description: Name of the product
        example: AQC107 NBase-T/IEEE
        type: string
        x-go-name: Product
      product_id:
        description: PCI ID of the product
        example: 87b1
        type: string
        x-go-name: ProductID
      sriov:
        $ref: '#/definitions/ResourcesNetworkCardSRIOV'
      usb_address:
        description: USB address (for USB cards)
        example: "2:7"
        type: string
        x-go-name: USBAddress
      vendor:
        description: Name of the vendor
        example: Aquantia Corp.
        type: string
        x-go-name: Vendor
      vendor_id:
        description: PCI ID of the vendor
        example: 1d6a
        type: string
        x-go-name: VendorID
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesNetworkCardPort:
    description: ResourcesNetworkCardPort represents a network port on the system
    properties:
      address:
        description: MAC address
        example: 00:23:a4:01:01:6f
        type: string
        x-go-name: Address
      auto_negotiation:
        description: Whether auto negotiation is used
        example: true
        type: boolean
        x-go-name: AutoNegotiation
      id:
        description: Port identifier (interface name)
        example: eth0
        type: string
        x-go-name: ID
      infiniband:
        $ref: '#/definitions/ResourcesNetworkCardPortInfiniband'
      link_detected:
        description: Whether a link was detected
        example: true
        type: boolean
        x-go-name: LinkDetected
      link_duplex:
        description: Duplex type
        example: full
        type: string
        x-go-name: LinkDuplex
      link_speed:
        description: Current speed (Mbit/s)
        example: 10000
        format: uint64
        type: integer
        x-go-name: LinkSpeed
      port:
        description: Port number
        example: 0
        format: uint64
        type: integer
        x-go-name: Port
      port_type:
        description: Current port type
        example: twisted pair
        type: string
        x-go-name: PortType
      protocol:
        description: Transport protocol
        example: ethernet
        type: string
        x-go-name: Protocol
      supported_modes:
        description: List of supported modes
        example:
        - 100baseT/Full
        - 1000baseT/Full
        - 2500baseT/Full
        - 5000baseT/Full
        - 10000baseT/Full
        items:
          type: string
        type: array
        x-go-name: SupportedModes
      supported_ports:
        description: List of supported port types
        example:
        - twisted pair
        items:
          type: string
        type: array
        x-go-name: SupportedPorts
      transceiver_type:
        description: Type of transceiver used
        example: internal
        type: string
        x-go-name: TransceiverType
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesNetworkCardPortInfiniband:
    description: ResourcesNetworkCardPortInfiniband represents the Linux Infiniband
      configuration for the port
    properties:
      issm_device:
        description: ISSM device number
        example: 231:64
        type: string
        x-go-name: IsSMDevice
      issm_name:
        description: ISSM device name
        example: issm0
        type: string
        x-go-name: IsSMName
      mad_device:
        description: MAD device number
        example: "231:0"
        type: string
        x-go-name: MADDevice
      mad_name:
        description: MAD device name
        example: umad0
        type: string
        x-go-name: MADName
      verb_device:
        description: Verb device number
        example: 231:192
        type: string
        x-go-name: VerbDevice
      verb_name:
        description: Verb device name
        example: uverbs0
        type: string
        x-go-name: VerbName
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesNetworkCardSRIOV:
    description: ResourcesNetworkCardSRIOV represents the SRIOV configuration of the
      network card
    properties:
      current_vfs:
        description: Number of VFs currently configured
        example: 0
        format: uint64
        type: integer
        x-go-name: CurrentVFs
      maximum_vfs:
        description: Maximum number of supported VFs
        example: 0
        format: uint64
        type: integer
        x-go-name: MaximumVFs
      vfs:
        description: List of VFs (as additional Network devices)
        example: null
        items:
          $ref: '#/definitions/ResourcesNetworkCard'
        type: array
        x-go-name: VFs
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesPCI:
    description: ResourcesPCI represents the PCI devices available on the system
    properties:
      devices:
        description: List of PCI devices
        items:
          $ref: '#/definitions/ResourcesPCIDevice'
        type: array
        x-go-name: Devices
      total:
        description: Total number of PCI devices
        example: 1
        format: uint64
        type: integer
        x-go-name: Total
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesPCIDevice:
    description: ResourcesPCIDevice represents a PCI device
    properties:
      driver:
        description: Kernel driver currently associated with the GPU
        example: mgag200
        type: string
        x-go-name: Driver
      driver_version:
        description: Version of the kernel driver
        example: 5.8.0-36-generic
        type: string
        x-go-name: DriverVersion
      iommu_group:
        description: IOMMU group number
        example: 20
        format: uint64
        type: integer
        x-go-name: IOMMUGroup
      numa_node:
        description: NUMA node the card is a part of
        example: 0
        format: uint64
        type: integer
        x-go-name: NUMANode
      pci_address:
        description: PCI address
        example: "0000:07:03.0"
        type: string
        x-go-name: PCIAddress
      product:
        description: Name of the product
        example: MGA G200eW WPCM450
        type: string
        x-go-name: Product
      product_id:
        description: PCI ID of the product
        example: "0532"
        type: string
        x-go-name: ProductID
      vendor:
        description: Name of the vendor
        example: Matrox Electronics Systems Ltd.
        type: string
        x-go-name: Vendor
      vendor_id:
        description: PCI ID of the vendor
        example: 102b
        type: string
        x-go-name: VendorID
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesStorage:
    description: ResourcesStorage represents the local storage
    properties:
      disks:
        description: List of disks
        items:
          $ref: '#/definitions/ResourcesStorageDisk'
        type: array
        x-go-name: Disks
      total:
        description: Total number of partitions
        example: 1
        format: uint64
        type: integer
        x-go-name: Total
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesStorageDisk:
    description: ResourcesStorageDisk represents a disk
    properties:
      block_size:
        description: Block size
        example: 512
        format: uint64
        type: integer
        x-go-name: BlockSize
      device:
        description: Device number
        example: "259:0"
        type: string
        x-go-name: Device
      device_id:
        description: Device by-id identifier
        example: nvme-eui.0000000001000000e4d25cafae2e4c00
        type: string
        x-go-name: DeviceID
      device_path:
        description: Device by-path identifier
        example: pci-0000:05:00.0-nvme-1
        type: string
        x-go-name: DevicePath
      firmware_version:
        description: Current firmware version
        example: PSF121C
        type: string
        x-go-name: FirmwareVersion
      id:
        description: ID of the disk (device name)
        example: nvme0n1
        type: string
        x-go-name: ID
      model:
        description: Disk model name
        example: INTEL SSDPEKKW256G7
        type: string
        x-go-name: Model
      numa_node:
        description: NUMA node the disk is a part of
        example: 0
        format: uint64
        type: integer
        x-go-name: NUMANode
      partitions:
        description: List of partitions
        items:
          $ref: '#/definitions/ResourcesStorageDiskPartition'
        type: array
        x-go-name: Partitions
      pci_address:
        description: PCI address
        example: "0000:05:00.0"
        type: string
        x-go-name: PCIAddress
      read_only:
        description: Whether the disk is read-only
        example: false
        type: boolean
        x-go-name: ReadOnly
      removable:
        description: Whether the disk is removable (hot-plug)
        example: false
        type: boolean
        x-go-name: Removable
      rpm:
        description: Rotation speed (RPM)
        example: 0
        format: uint64
        type: integer
        x-go-name: RPM
      serial:
        description: Serial number
        example: BTPY63440ARH256D
        type: string
        x-go-name: Serial
      size:
        description: Total size of the disk (bytes)
        example: 256060514304
        format: uint64
        type: integer
        x-go-name: Size
      type:
        description: Storage type
        example: nvme
        type: string
        x-go-name: Type
      usb_address:
        description: USB address
        example: "3:5"
        type: string
        x-go-name: USBAddress
      wwn:
        description: WWN identifier
        example: eui.0000000001000000e4d25cafae2e4c00
        type: string
        x-go-name: WWN
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesStorageDiskPartition:
    description: ResourcesStorageDiskPartition represents a partition on a disk
    properties:
      device:
        description: Device number
        example: "259:1"
        type: string
        x-go-name: Device
      id:
        description: ID of the partition (device name)
        example: nvme0n1p1
        type: string
        x-go-name: ID
      partition:
        description: Partition number
        example: 1
        format: uint64
        type: integer
        x-go-name: Partition
      read_only:
        description: Whether the partition is read-only
        example: false
        type: boolean
        x-go-name: ReadOnly
      size:
        description: Size of the partition (bytes)
        example: 254933278208
        format: uint64
        type: integer
        x-go-name: Size
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesStoragePool:
    description: ResourcesStoragePool represents the resources available to a given
      storage pool
    properties:
      inodes:
        $ref: '#/definitions/ResourcesStoragePoolInodes'
      space:
        $ref: '#/definitions/ResourcesStoragePoolSpace'
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesStoragePoolInodes:
    description: ResourcesStoragePoolInodes represents the inodes available to a given
      storage pool
    properties:
      total:
        description: Total inodes
        example: 30709993797
        format: uint64
        type: integer
        x-go-name: Total
      used:
        description: Used inodes
        example: 23937695
        format: uint64
        type: integer
        x-go-name: Used
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesStoragePoolSpace:
    description: ResourcesStoragePoolSpace represents the space available to a given
      storage pool
    properties:
      total:
        description: Total disk space (bytes)
        example: 420100937728
        format: uint64
        type: integer
        x-go-name: Total
      used:
        description: Used disk space (bytes)
        example: 343537419776
        format: uint64
        type: integer
        x-go-name: Used
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesSystem:
    description: ResourcesSystem represents the system
    properties:
      chassis:
        $ref: '#/definitions/ResourcesSystemChassis'
      family:
        description: System family
        example: ThinkPad X1 Carbon 5th
        type: string
        x-go-name: Family
      firmware:
        $ref: '#/definitions/ResourcesSystemFirmware'
      motherboard:
        $ref: '#/definitions/ResourcesSystemMotherboard'
      product:
        description: System model
        example: 20HRCTO1WW
        type: string
        x-go-name: Product
      serial:
        description: System serial number
        example: PY3DD4X9
        type: string
        x-go-name: Serial
      sku:
        description: |-
          System nanufacturer SKU
          LENOVO_MT_20HR_BU_Think_FM_ThinkPad X1 Carbon 5th
        type: string
        x-go-name: Sku
      type:
        description: System type (unknown, physical, virtual-machine, container, ...)
        example: physical
        type: string
        x-go-name: Type
      uuid:
        description: System UUID
        example: 7fa1c0cc-2271-11b2-a85c-aab32a05d71a
        type: string
        x-go-name: UUID
      vendor:
        description: System vendor
        example: LENOVO
        type: string
        x-go-name: Vendor
      version:
        description: System version
        example: ThinkPad X1 Carbon 5th
        type: string
        x-go-name: Version
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesSystemChassis:
    description: ResourcesSystemChassis represents the system chassis
    properties:
      serial:
        description: Chassis serial number
        example: PY3DD4X9
        type: string
        x-go-name: Serial
      type:
        description: Chassis type
        example: Notebook
        type: string
        x-go-name: Type
      vendor:
        description: Chassis vendor
        example: Lenovo
        type: string
        x-go-name: Vendor
      version:
        description: Chassis version/revision
        example: None
        type: string
        x-go-name: Version
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesSystemFirmware:
    description: ResourcesSystemFirmware represents the system firmware
    properties:
      date:
        description: Firmware build date
        example: 10/14/2020
        type: string
        x-go-name: Date
      vendor:
        description: Firmware vendor
        example: Lenovo
        type: string
        x-go-name: Vendor
      version:
        description: Firmware version
        example: N1MET64W (1.49)
        type: string
        x-go-name: Version
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesSystemMotherboard:
    description: ResourcesSystemMotherboard represents the motherboard
    properties:
      product:
        description: Motherboard model
        example: 20HRCTO1WW
        type: string
        x-go-name: Product
      serial:
        description: Motherboard serial number
        example: L3CF4FX003A
        type: string
        x-go-name: Serial
      vendor:
        description: Motherboard vendor
        example: Lenovo
        type: string
        x-go-name: Vendor
      version:
        description: Motherboard version/revision
        example: None
        type: string
        x-go-name: Version
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesUSB:
    description: ResourcesUSB represents the USB devices available on the system
    properties:
      devices:
        description: List of USB devices
        items:
          $ref: '#/definitions/ResourcesUSBDevice'
        type: array
        x-go-name: Devices
      total:
        description: Total number of USB devices
        example: 1
        format: uint64
        type: integer
        x-go-name: Total
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesUSBDevice:
    description: ResourcesUSBDevice represents a USB device
    properties:
      bus_address:
        description: USB address (bus)
        example: 1
        format: uint64
        type: integer
        x-go-name: BusAddress
      device_address:
        description: USB address (device)
        example: 3
        format: uint64
        type: integer
        x-go-name: DeviceAddress
      interfaces:
        description: List of USB interfaces
        items:
          $ref: '#/definitions/ResourcesUSBDeviceInterface'
        type: array
        x-go-name: Interfaces
      product:
        description: Name of the product
        example: Hermon USB hidmouse Device
        type: string
        x-go-name: Product
      product_id:
        description: USB ID of the product
        example: "2221"
        type: string
        x-go-name: ProductID
      speed:
        description: Transfer speed (Mbit/s)
        example: 12
        format: double
        type: number
        x-go-name: Speed
      vendor:
        description: Name of the vendor
        example: ATEN International Co., Ltd
        type: string
        x-go-name: Vendor
      vendor_id:
        description: USB ID of the vendor
        example: "0557"
        type: string
        x-go-name: VendorID
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ResourcesUSBDeviceInterface:
    description: ResourcesUSBDeviceInterface represents a USB device interface
    properties:
      class:
        description: Class of USB interface
        example: Human Interface Device
        type: string
        x-go-name: Class
      class_id:
        description: ID of the USB interface class
        example: 3
        format: uint64
        type: integer
        x-go-name: ClassID
      driver:
        description: Kernel driver currently associated with the device
        example: usbhid
        type: string
        x-go-name: Driver
      driver_version:
        description: Version of the kernel driver
        example: 5.8.0-36-generic
        type: string
        x-go-name: DriverVersion
      number:
        description: Interface number
        example: 0
        format: uint64
        type: integer
        x-go-name: Number
      subclass:
        description: Sub class of the interface
        example: Boot Interface Subclass
        type: string
        x-go-name: SubClass
      subclass_id:
        description: ID of the USB interface sub class
        example: 1
        format: uint64
        type: integer
        x-go-name: SubClassID
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Server:
    description: Server represents a LXD server
    properties:
      api_extensions:
        description: List of supported API extensions
        example:
        - etag
        - patch
        - network
        - storage
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: APIExtensions
      api_status:
        description: Support status of the current API (one of "devel", "stable" or
          "deprecated")
        example: stable
        readOnly: true
        type: string
        x-go-name: APIStatus
      api_version:
        description: API version number
        example: "1.0"
        readOnly: true
        type: string
        x-go-name: APIVersion
      auth:
        description: Whether the client is trusted (one of "trusted" or "untrusted")
        example: untrusted
        readOnly: true
        type: string
        x-go-name: Auth
      auth_methods:
        description: List of supported authentication methods
        example:
        - tls
        - candid
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: AuthMethods
      config:
        additionalProperties:
          type: object
        description: Server configuration map (refer to doc/server.md)
        example:
          core.https_address: :8443
          core.trust_password: true
        type: object
        x-go-name: Config
      environment:
        $ref: '#/definitions/ServerEnvironment'
      public:
        description: Whether the server is public-only (only public endpoints are
          implemented)
        example: false
        readOnly: true
        type: boolean
        x-go-name: Public
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ServerEnvironment:
    description: ServerEnvironment represents the read-only environment fields of
      a LXD server
    properties:
      addresses:
        description: List of addresses the server is listening on
        example:
        - :8443
        items:
          type: string
        type: array
        x-go-name: Addresses
      architectures:
        description: List of architectures supported by the server
        example:
        - x86_64
        - i686
        items:
          type: string
        type: array
        x-go-name: Architectures
      certificate:
        description: Server certificate as PEM encoded X509
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      certificate_fingerprint:
        description: Server certificate fingerprint as SHA256
        example: fd200419b271f1dc2a5591b693cc5774b7f234e1ff8c6b78ad703b6888fe2b69
        type: string
        x-go-name: CertificateFingerprint
      driver:
        description: List of supported instance drivers (separate by " | ")
        example: lxc | qemu
        type: string
        x-go-name: Driver
      driver_version:
        description: List of supported instance driver versions (separate by " | ")
        example: 4.0.7 | 5.2.0
        type: string
        x-go-name: DriverVersion
      firewall:
        description: Current firewall driver
        example: nftables
        type: string
        x-go-name: Firewall
      kernel:
        description: OS kernel name
        example: Linux
        type: string
        x-go-name: Kernel
      kernel_architecture:
        description: OS kernel architecture
        example: x86_64
        type: string
        x-go-name: KernelArchitecture
      kernel_features:
        additionalProperties:
          type: string
        description: Map of kernel features that were tested on startup
        example:
          netnsid_getifaddrs: "true"
          seccomp_listener: "true"
        type: object
        x-go-name: KernelFeatures
      kernel_version:
        description: Kernel version
        example: 5.4.0-36-generic
        type: string
        x-go-name: KernelVersion
      lxc_features:
        additionalProperties:
          type: string
        description: Map of LXC features that were tested on startup
        example:
          cgroup2: "true"
          devpts_fd: "true"
          pidfd: "true"
        type: object
        x-go-name: LXCFeatures
      os_name:
        description: Name of the operating system (Linux distribution)
        example: Ubuntu
        type: string
        x-go-name: OSName
      os_version:
        description: Version of the operating system (Linux distribution)
        example: "20.04"
        type: string
        x-go-name: OSVersion
      project:
        description: Current project name
        example: default
        type: string
        x-go-name: Project
      server:
        description: Server implementation name
        example: lxd
        type: string
        x-go-name: Server
      server_clustered:
        description: Whether the server is part of a cluster
        example: false
        type: boolean
        x-go-name: ServerClustered
      server_name:
        description: Server hostname
        example: castiana
        type: string
        x-go-name: ServerName
      server_pid:
        description: PID of the LXD process
        example: 1453969
        format: int64
        type: integer
        x-go-name: ServerPid
      server_version:
        description: Server version
        example: "4.11"
        type: string
        x-go-name: ServerVersion
      storage:
        description: List of active storage drivers (separate by " | ")
        example: dir | zfs
        type: string
        x-go-name: Storage
      storage_supported_drivers:
        description: List of supported storage drivers
        items:
          $ref: '#/definitions/ServerStorageDriverInfo'
        type: array
        x-go-name: StorageSupportedDrivers
      storage_version:
        description: List of active storage driver versions (separate by " | ")
        example: 1 | 0.8.4-1ubuntu11
        type: string
        x-go-name: StorageVersion
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ServerPut:
    description: ServerPut represents the modifiable fields of a LXD server configuration
    properties:
      config:
        additionalProperties:
          type: object
        description: Server configuration map (refer to doc/server.md)
        example:
          core.https_address: :8443
          core.trust_password: true
        type: object
        x-go-name: Config
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ServerStorageDriverInfo:
    description: ServerStorageDriverInfo represents the read-only info about a storage
      driver
    properties:
      Name:
        description: Name of the driver
        example: zfs
        type: string
      Remote:
        description: Whether the driver has remote volumes
        example: false
        type: boolean
      Version:
        description: Version of the driver
        example: 0.8.4-1ubuntu11
        type: string
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  ServerUntrusted:
    description: ServerUntrusted represents a LXD server for an untrusted client
    properties:
      api_extensions:
        description: List of supported API extensions
        example:
        - etag
        - patch
        - network
        - storage
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: APIExtensions
      api_status:
        description: Support status of the current API (one of "devel", "stable" or
          "deprecated")
        example: stable
        readOnly: true
        type: string
        x-go-name: APIStatus
      api_version:
        description: API version number
        example: "1.0"
        readOnly: true
        type: string
        x-go-name: APIVersion
      auth:
        description: Whether the client is trusted (one of "trusted" or "untrusted")
        example: untrusted
        readOnly: true
        type: string
        x-go-name: Auth
      auth_methods:
        description: List of supported authentication methods
        example:
        - tls
        - candid
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: AuthMethods
      public:
        description: Whether the server is public-only (only public endpoints are
          implemented)
        example: false
        readOnly: true
        type: boolean
        x-go-name: Public
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StatusCode:
    description: StatusCode represents a valid LXD operation and container status
    format: int64
    type: integer
    x-go-package: github.com/lxc/lxd/shared/api
  StoragePool:
    properties:
      config:
        additionalProperties:
          type: string
        description: Storage pool configuration map (refer to doc/storage.md)
        example:
          volume.block.filesystem: ext4
          volume.size: 50GiB
        type: object
        x-go-name: Config
      description:
        description: Description of the storage pool
        example: Local SSD pool
        type: string
        x-go-name: Description
      driver:
        description: Storage pool driver (btrfs, ceph, cephfs, dir, lvm or zfs)
        example: zfs
        type: string
        x-go-name: Driver
      locations:
        description: Cluster members on which the storage pool has been defined
        example:
        - lxd01
        - lxd02
        - lxd03
        items:
          type: string
        readOnly: true
        type: array
        x-go-name: Locations
      name:
        description: Storage pool name
        example: local
        type: string
        x-go-name: Name
      status:
        description: Pool status (Pending, Created, Errored or Unknown)
        example: Created
        readOnly: true
        type: string
        x-go-name: Status
      used_by:
        description: List of URLs of objects using this storage pool
        example:
        - /1.0/profiles/default
        - /1.0/instances/c1
        items:
          type: string
        type: array
        x-go-name: UsedBy
    title: StoragePool represents the fields of a LXD storage pool.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StoragePoolPut:
    properties:
      config:
        additionalProperties:
          type: string
        description: Storage pool configuration map (refer to doc/storage.md)
        example:
          volume.block.filesystem: ext4
          volume.size: 50GiB
        type: object
        x-go-name: Config
      description:
        description: Description of the storage pool
        example: Local SSD pool
        type: string
        x-go-name: Description
    title: StoragePoolPut represents the modifiable fields of a LXD storage pool.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StoragePoolVolumeBackup:
    description: StoragePoolVolumeBackup represents a LXD volume backup
    properties:
      created_at:
        description: When the backup was cerated
        example: "2021-03-23T16:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: CreatedAt
      expires_at:
        description: When the backup expires (gets auto-deleted)
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      name:
        description: Backup name
        example: backup0
        type: string
        x-go-name: Name
      optimized_storage:
        description: Whether to use a pool-optimized binary format (instead of plain
          tarball)
        example: true
        type: boolean
        x-go-name: OptimizedStorage
      volume_only:
        description: Whether to ignore snapshots
        example: false
        type: boolean
        x-go-name: VolumeOnly
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StoragePoolVolumeBackupPost:
    description: StoragePoolVolumeBackupPost represents the fields available for the
      renaming of a volume backup
    properties:
      name:
        description: New backup name
        example: backup1
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StoragePoolVolumeBackupsPost:
    description: StoragePoolVolumeBackupsPost represents the fields available for
      a new LXD volume backup
    properties:
      compression_algorithm:
        description: What compression algorithm to use
        example: gzip
        type: string
        x-go-name: CompressionAlgorithm
      expires_at:
        description: When the backup expires (gets auto-deleted)
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      name:
        description: Backup name
        example: backup0
        type: string
        x-go-name: Name
      optimized_storage:
        description: Whether to use a pool-optimized binary format (instead of plain
          tarball)
        example: true
        type: boolean
        x-go-name: OptimizedStorage
      volume_only:
        description: Whether to ignore snapshots
        example: false
        type: boolean
        x-go-name: VolumeOnly
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StoragePoolsPost:
    description: StoragePoolsPost represents the fields of a new LXD storage pool
    properties:
      config:
        additionalProperties:
          type: string
        description: Storage pool configuration map (refer to doc/storage.md)
        example:
          volume.block.filesystem: ext4
          volume.size: 50GiB
        type: object
        x-go-name: Config
      description:
        description: Description of the storage pool
        example: Local SSD pool
        type: string
        x-go-name: Description
      driver:
        description: Storage pool driver (btrfs, ceph, cephfs, dir, lvm or zfs)
        example: zfs
        type: string
        x-go-name: Driver
      name:
        description: Storage pool name
        example: local
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolume:
    properties:
      config:
        additionalProperties:
          type: string
        description: Storage volume configuration map (refer to doc/storage.md)
        example:
          size: 50GiB
          zfs.remove_snapshots: "true"
        type: object
        x-go-name: Config
      content_type:
        description: Volume content type (filesystem or block)
        example: filesystem
        type: string
        x-go-name: ContentType
      description:
        description: Description of the storage volume
        example: My custom volume
        type: string
        x-go-name: Description
      location:
        description: What cluster member this record was found on
        example: lxd01
        type: string
        x-go-name: Location
      name:
        description: Volume name
        example: foo
        type: string
        x-go-name: Name
      restore:
        description: Name of a snapshot to restore
        example: snap0
        type: string
        x-go-name: Restore
      type:
        description: Volume type
        example: custom
        type: string
        x-go-name: Type
      used_by:
        description: List of URLs of objects using this storage volume
        example:
        - /1.0/instances/blah
        items:
          type: string
        type: array
        x-go-name: UsedBy
    title: StorageVolume represents the fields of a LXD storage volume.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumePost:
    description: StorageVolumePost represents the fields required to rename a LXD
      storage pool volume
    properties:
      migration:
        description: Initiate volume migration
        example: false
        type: boolean
        x-go-name: Migration
      name:
        description: New volume name
        example: foo
        type: string
        x-go-name: Name
      pool:
        description: New storage pool
        example: remote
        type: string
        x-go-name: Pool
      project:
        description: New project name
        example: foo
        type: string
        x-go-name: Project
      target:
        $ref: '#/definitions/StorageVolumePostTarget'
      volume_only:
        description: Whether snapshots should be discarded (migration only)
        example: false
        type: boolean
        x-go-name: VolumeOnly
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumePostTarget:
    description: StorageVolumePostTarget represents the migration target host and
      operation
    properties:
      certificate:
        description: The certificate of the migration target
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      operation:
        description: Remote operation URL (for migration)
        example: https://1.2.3.4:8443/1.0/operations/1721ae08-b6a8-416a-9614-3f89302466e1
        type: string
        x-go-name: Operation
      secrets:
        additionalProperties:
          type: string
        description: Migration websockets credentials
        example:
          migration: random-string
        type: object
        x-go-name: Websockets
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumePut:
    description: StorageVolumePut represents the modifiable fields of a LXD storage
      volume
    properties:
      config:
        additionalProperties:
          type: string
        description: Storage volume configuration map (refer to doc/storage.md)
        example:
          size: 50GiB
          zfs.remove_snapshots: "true"
        type: object
        x-go-name: Config
      description:
        description: Description of the storage volume
        example: My custom volume
        type: string
        x-go-name: Description
      restore:
        description: Name of a snapshot to restore
        example: snap0
        type: string
        x-go-name: Restore
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumeSnapshot:
    description: StorageVolumeSnapshot represents a LXD storage volume snapshot
    properties:
      config:
        additionalProperties:
          type: string
        description: Storage volume configuration map (refer to doc/storage.md)
        example:
          size: 50GiB
          zfs.remove_snapshots: "true"
        type: object
        x-go-name: Config
      content_type:
        description: The content type (filesystem or block)
        example: filesystem
        type: string
        x-go-name: ContentType
      description:
        description: Description of the storage volume
        example: My custom volume
        type: string
        x-go-name: Description
      expires_at:
        description: When the snapshot expires (gets auto-deleted)
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      name:
        description: Snapshot name
        example: snap0
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumeSnapshotPost:
    description: StorageVolumeSnapshotPost represents the fields required to rename/move
      a LXD storage volume snapshot
    properties:
      name:
        description: New snapshot name
        example: snap1
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumeSnapshotPut:
    description: StorageVolumeSnapshotPut represents the modifiable fields of a LXD
      storage volume
    properties:
      description:
        description: Description of the storage volume
        example: My custom volume
        type: string
        x-go-name: Description
      expires_at:
        description: When the snapshot expires (gets auto-deleted)
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumeSnapshotsPost:
    description: StorageVolumeSnapshotsPost represents the fields available for a
      new LXD storage volume snapshot
    properties:
      expires_at:
        description: When the snapshot expires (gets auto-deleted)
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: ExpiresAt
      name:
        description: Snapshot name
        example: snap0
        type: string
        x-go-name: Name
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumeSource:
    description: StorageVolumeSource represents the creation source for a new storage
      volume
    properties:
      certificate:
        description: Certificate (for migration)
        example: X509 PEM certificate
        type: string
        x-go-name: Certificate
      mode:
        description: Whether to use pull or push mode (for migration)
        example: pull
        type: string
        x-go-name: Mode
      name:
        description: Source volume name (for copy)
        example: foo
        type: string
        x-go-name: Name
      operation:
        description: Remote operation URL (for migration)
        example: https://1.2.3.4:8443/1.0/operations/1721ae08-b6a8-416a-9614-3f89302466e1
        type: string
        x-go-name: Operation
      pool:
        description: Source storage pool (for copy)
        example: local
        type: string
        x-go-name: Pool
      project:
        description: Source project name
        example: foo
        type: string
        x-go-name: Project
      refresh:
        description: Whether existing destination volume should be refreshed
        example: false
        type: boolean
        x-go-name: Refresh
      secrets:
        additionalProperties:
          type: string
        description: Map of migration websockets (for migration)
        example:
          rsync: RANDOM-STRING
        type: object
        x-go-name: Websockets
      type:
        description: Source type (copy or migration)
        example: copy
        type: string
        x-go-name: Type
      volume_only:
        description: Whether snapshots should be discarded (for migration)
        example: false
        type: boolean
        x-go-name: VolumeOnly
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumeState:
    description: StorageVolumeState represents the live state of the volume
    properties:
      usage:
        $ref: '#/definitions/StorageVolumeStateUsage'
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumeStateUsage:
    description: StorageVolumeStateUsage represents the disk usage of a volume
    properties:
      used:
        description: Used space in bytes
        example: 1693552640
        format: uint64
        type: integer
        x-go-name: Used
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  StorageVolumesPost:
    description: StorageVolumesPost represents the fields of a new LXD storage pool
      volume
    properties:
      config:
        additionalProperties:
          type: string
        description: Storage volume configuration map (refer to doc/storage.md)
        example:
          size: 50GiB
          zfs.remove_snapshots: "true"
        type: object
        x-go-name: Config
      content_type:
        description: Volume content type (filesystem or block)
        example: filesystem
        type: string
        x-go-name: ContentType
      description:
        description: Description of the storage volume
        example: My custom volume
        type: string
        x-go-name: Description
      name:
        description: Volume name
        example: foo
        type: string
        x-go-name: Name
      restore:
        description: Name of a snapshot to restore
        example: snap0
        type: string
        x-go-name: Restore
      source:
        $ref: '#/definitions/StorageVolumeSource'
      type:
        description: Volume type (container, custom, image or virtual-machine)
        example: custom
        type: string
        x-go-name: Type
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  Warning:
    properties:
      count:
        description: The number of times this warning occurred
        example: 1
        format: int64
        type: integer
        x-go-name: Count
      entity_url:
        description: The entity affected by this warning
        example: /1.0/instances/c1?project=default
        type: string
        x-go-name: EntityURL
      first_seen_at:
        description: The first time this warning occurred
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: FirstSeenAt
      last_message:
        description: The warning message
        example: Couldn't find the CGroup blkio.weight, disk priority will be ignored
        type: string
        x-go-name: LastMessage
      last_seen_at:
        description: The last time this warning occurred
        example: "2021-03-23T17:38:37.753398689-04:00"
        format: date-time
        type: string
        x-go-name: LastSeenAt
      location:
        description: What cluster member this warning occurred on
        example: node1
        type: string
        x-go-name: Location
      project:
        description: The project the warning occurred in
        example: default
        type: string
        x-go-name: Project
      severity:
        description: The severity of this warning
        example: low
        type: string
        x-go-name: Severity
      status:
        description: Status of the warning (new, acknowledged, or resolved)
        example: new
        type: string
        x-go-name: Status
      type:
        description: Type type of warning
        example: Couldn't find CGroup
        type: string
        x-go-name: Type
      uuid:
        description: UUID of the warning
        example: e9e9da0d-2538-4351-8047-46d4a8ae4dbb
        type: string
        x-go-name: UUID
    title: Warning represents a warning entry.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
  WarningPut:
    properties:
      status:
        description: Status of the warning (new, acknowledged, or resolved)
        example: new
        type: string
        x-go-name: Status
    title: WarningPut represents the modifiable fields of a warning.
    type: object
    x-go-package: github.com/lxc/lxd/shared/api
info:
  contact:
    email: lxc-devel@lists.linuxcontainers.org
    name: LXD upstream
    url: https://github.com/lxc/lxd
  description: |-
    This is the REST API used by all LXD clients.
    Internal endpoints aren't included in this documentation.

    The LXD API is available over both a local unix+http and remote https API.
    Authentication for local users relies on group membership and access to the unix socket.
    For remote users, the default authentication method is TLS client
    certificates with a macaroon based (candid) authentication method also
    supported.
  license:
    name: Apache-2.0
    url: https://www.apache.org/licenses/LICENSE-2.0
  title: LXD external REST API
  version: "1.0"
paths:
  /:
    get:
      description: |-
        Returns a list of supported API versions (URLs).

        Internal API endpoints are not reported as those aren't versioned and
        should only be used by LXD itself.
      operationId: api_get
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example:
                - /1.0
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
      summary: Get the supported API enpoints
      tags:
      - server
  /1.0:
    get:
      description: Shows the full server environment and configuration.
      operationId: server_get
      parameters:
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Server environment and configuration
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Server'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the server environment and configuration
      tags:
      - server
    patch:
      consumes:
      - application/json
      description: Updates a subset of the server configuration.
      operationId: server_patch
      parameters:
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Server configuration
        in: body
        name: server
        required: true
        schema:
          $ref: '#/definitions/ServerPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the server configuration
      tags:
      - server
    put:
      consumes:
      - application/json
      description: Updates the entire server configuration.
      operationId: server_put
      parameters:
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Server configuration
        in: body
        name: server
        required: true
        schema:
          $ref: '#/definitions/ServerPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the server configuration
      tags:
      - server
  /1.0/certificates:
    get:
      description: Returns a list of trusted certificates (URLs).
      operationId: certificates_get
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/certificates/390fdd27ed5dc2408edc11fe602eafceb6c025ddbad9341dfdcb1056a8dd98b1",
                    "/1.0/certificates/22aee3f051f96abe6d7756892eecabf4b4b22e2ba877840a4ca981e9ea54030a"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the trusted certificates
      tags:
      - certificates
    post:
      consumes:
      - application/json
      description: |-
        Adds a certificate to the trust store.
        In this mode, the `password` property is always ignored.
      operationId: certificates_post
      parameters:
      - description: Certificate
        in: body
        name: certificate
        required: true
        schema:
          $ref: '#/definitions/CertificatesPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a trusted certificate
      tags:
      - certificates
  /1.0/certificates/{fingerprint}:
    delete:
      description: Removes the certificate from the trust store.
      operationId: certificate_delete
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the trusted certificate
      tags:
      - certificates
    get:
      description: Gets a specific certificate entry from the trust store.
      operationId: certificate_get
      produces:
      - application/json
      responses:
        "200":
          description: Certificate
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Certificate'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the trusted certificate
      tags:
      - certificates
    patch:
      consumes:
      - application/json
      description: Updates a subset of the certificate configuration.
      operationId: certificate_patch
      parameters:
      - description: Certificate configuration
        in: body
        name: certificate
        required: true
        schema:
          $ref: '#/definitions/CertificatePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the trusted certificate
      tags:
      - certificates
    put:
      consumes:
      - application/json
      description: Updates the entire certificate configuration.
      operationId: certificate_put
      parameters:
      - description: Certificate configuration
        in: body
        name: certificate
        required: true
        schema:
          $ref: '#/definitions/CertificatePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the trusted certificate
      tags:
      - certificates
  /1.0/certificates?public:
    post:
      consumes:
      - application/json
      description: |-
        Adds a certificate to the trust store as an untrusted user.
        In this mode, the `password` property must be set to the correct value.

        The `certificate` field can be omitted in which case the TLS client
        certificate in use for the connection will be retrieved and added to the
        trust store.

        The `?public` part of the URL isn't required, it's simply used to
        separate the two behaviors of this endpoint.
      operationId: certificates_post_untrusted
      parameters:
      - description: Certificate
        in: body
        name: certificate
        required: true
        schema:
          $ref: '#/definitions/CertificatesPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a trusted certificate
      tags:
      - certificates
  /1.0/certificates?recursion=1:
    get:
      description: Returns a list of trusted certificates (structs).
      operationId: certificates_get_recursion1
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of certificates
                items:
                  $ref: '#/definitions/Certificate'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the trusted certificates
      tags:
      - certificates
  /1.0/cluster:
    get:
      description: Gets the current cluster configuration.
      operationId: cluster_get
      produces:
      - application/json
      responses:
        "200":
          description: Cluster configuration
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Cluster'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the cluster configuration
      tags:
      - cluster
    put:
      consumes:
      - application/json
      description: Updates the entire cluster configuration.
      operationId: cluster_put
      parameters:
      - description: Cluster configuration
        in: body
        name: cluster
        required: true
        schema:
          $ref: '#/definitions/ClusterPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the cluster configuration
      tags:
      - cluster
  /1.0/cluster/certificate:
    put:
      consumes:
      - application/json
      description: |-
        Replaces existing cluster certificate and reloads LXD on each cluster
        member.
      operationId: clustering_update_cert
      parameters:
      - description: Cluster certificate replace request
        in: body
        name: cluster
        required: true
        schema:
          $ref: '#/definitions/ClusterCertificatePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the certificate for the cluster
      tags:
      - cluster
  /1.0/cluster/groups:
    get:
      description: Returns a list of cluster groups (URLs).
      operationId: cluster_groups_get
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/cluster/groups/lxd01",
                    "/1.0/cluster/groups/lxd02"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the cluster groups
      tags:
      - cluster-groups
    post:
      consumes:
      - application/json
      description: Creates a new cluster group.
      operationId: cluster_groups_post
      parameters:
      - description: Cluster group to create
        in: body
        name: cluster
        required: true
        schema:
          $ref: '#/definitions/ClusterGroupsPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Create a cluster group.
      tags:
      - cluster
  /1.0/cluster/groups/{name}:
    delete:
      description: Removes the cluster group.
      operationId: cluster_group_delete
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the cluster group.
      tags:
      - cluster-groups
    get:
      description: Gets a specific cluster group.
      operationId: cluster_group_get
      produces:
      - application/json
      responses:
        "200":
          description: Cluster group
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/ClusterGroup'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the cluster group
      tags:
      - cluster-groups
    patch:
      consumes:
      - application/json
      description: Updates the cluster group configuration.
      operationId: cluster_group_patch
      parameters:
      - description: cluster group configuration
        in: body
        name: cluster group
        required: true
        schema:
          $ref: '#/definitions/ClusterGroupPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the cluster group
      tags:
      - cluster-groups
    post:
      consumes:
      - application/json
      description: Renames an existing cluster group.
      operationId: cluster_group_post
      parameters:
      - description: Cluster group rename request
        in: body
        name: name
        required: true
        schema:
          $ref: '#/definitions/ClusterGroupPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename the cluster group
      tags:
      - cluster-groups
    put:
      consumes:
      - application/json
      description: Updates the entire cluster group configuration.
      operationId: cluster_group_put
      parameters:
      - description: cluster group configuration
        in: body
        name: cluster group
        required: true
        schema:
          $ref: '#/definitions/ClusterGroupPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the cluster group
      tags:
      - cluster-groups
  /1.0/cluster/groups?recursion=1:
    get:
      description: Returns a list of cluster groups (structs).
      operationId: cluster_groups_get_recursion1
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of cluster groups
                items:
                  $ref: '#/definitions/ClusterGroup'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the cluster groups
      tags:
      - cluster-groups
  /1.0/cluster/members:
    get:
      description: Returns a list of cluster members (URLs).
      operationId: cluster_members_get
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/cluster/members/lxd01",
                    "/1.0/cluster/members/lxd02"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the cluster members
      tags:
      - cluster
    post:
      consumes:
      - application/json
      description: Requests a join token to add a cluster member.
      operationId: cluster_members_post
      parameters:
      - description: Cluster member add request
        in: body
        name: cluster
        required: true
        schema:
          $ref: '#/definitions/ClusterMembersPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Request a join token
      tags:
      - cluster
  /1.0/cluster/members/{name}:
    delete:
      description: Removes the member from the cluster.
      operationId: cluster_member_delete
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the cluster member
      tags:
      - cluster
    get:
      description: Gets a specific cluster member.
      operationId: cluster_member_get
      produces:
      - application/json
      responses:
        "200":
          description: Profile
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/ClusterMember'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the cluster member
      tags:
      - cluster
    patch:
      consumes:
      - application/json
      description: Updates a subset of the cluster member configuration.
      operationId: cluster_member_patch
      parameters:
      - description: Cluster member configuration
        in: body
        name: cluster
        required: true
        schema:
          $ref: '#/definitions/ClusterMemberPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the cluster member
      tags:
      - cluster
    post:
      consumes:
      - application/json
      description: Renames an existing cluster member.
      operationId: cluster_member_post
      parameters:
      - description: Cluster member rename request
        in: body
        name: cluster
        required: true
        schema:
          $ref: '#/definitions/ClusterMemberPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename the cluster member
      tags:
      - cluster
    put:
      consumes:
      - application/json
      description: Updates the entire cluster member configuration.
      operationId: cluster_member_put
      parameters:
      - description: Cluster member configuration
        in: body
        name: cluster
        required: true
        schema:
          $ref: '#/definitions/ClusterMemberPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the cluster member
      tags:
      - cluster
  /1.0/cluster/members/{name}/state:
    post:
      consumes:
      - application/json
      description: Evacuates or restores a cluster member.
      operationId: cluster_member_state_post
      parameters:
      - description: Cluster member state
        in: body
        name: cluster
        required: true
        schema:
          $ref: '#/definitions/ClusterMemberStatePost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Evacuate or restore a cluster member
      tags:
      - cluster
  /1.0/cluster/members?recursion=1:
    get:
      description: Returns a list of cluster members (structs).
      operationId: cluster_members_get_recursion1
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of cluster members
                items:
                  $ref: '#/definitions/ClusterMember'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the cluster members
      tags:
      - cluster
  /1.0/events:
    get:
      description: Connects to the event API using websocket.
      operationId: events_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Event type(s), comma separated (valid types are logging, operation
          or lifecycle)
        example: logging,lifecycle
        in: query
        name: type
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Websocket message (JSON)
          schema:
            $ref: '#/definitions/Event'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the event stream
      tags:
      - server
  /1.0/images:
    get:
      description: Returns a list of images (URLs).
      operationId: images_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Collection filter
        example: default
        in: query
        name: filter
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/images/06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb",
                    "/1.0/images/084dd79dd1360fd25a2479eb46674c2a5ef3022a40fe03c91ab3603e3402b8e1"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the images
      tags:
      - images
    post:
      consumes:
      - application/json
      description: Adds a new image to the image store.
      operationId: images_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image
        in: body
        name: image
        schema:
          $ref: '#/definitions/ImagesPost'
      - description: Raw image file
        in: body
        name: raw_image
      - description: Push secret for server to server communication
        example: RANDOM-STRING
        in: header
        name: X-LXD-secret
        schema:
          type: string
      - description: Expected fingerprint when pushing a raw image
        in: header
        name: X-LXD-fingerprint
        schema:
          type: string
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add an image
      tags:
      - images
  /1.0/images/{fingerprint}:
    delete:
      description: Removes the image from the image store.
      operationId: image_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the image
      tags:
      - images
    get:
      description: Gets a specific image.
      operationId: image_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Image
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Image'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the image
      tags:
      - images
    patch:
      consumes:
      - application/json
      description: Updates a subset of the image definition.
      operationId: image_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image configuration
        in: body
        name: image
        required: true
        schema:
          $ref: '#/definitions/ImagePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the image
      tags:
      - images
    put:
      consumes:
      - application/json
      description: Updates the entire image definition.
      operationId: image_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image configuration
        in: body
        name: image
        required: true
        schema:
          $ref: '#/definitions/ImagePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the image
      tags:
      - images
  /1.0/images/{fingerprint}/export:
    get:
      description: |-
        Download the raw image file(s) from the server.
        If the image is in split format, a multipart http transfer occurs.
      operationId: image_export_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/octet-stream
      - multipart/form-data
      responses:
        "200":
          description: Raw image data
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the raw image file(s)
      tags:
      - images
    post:
      description: Gets LXD to connect to a remote server and push the image to it.
      operationId: images_export_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image push request
        in: body
        name: image
        required: true
        schema:
          $ref: '#/definitions/ImageExportPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Make LXD push the image to a remote server
      tags:
      - images
  /1.0/images/{fingerprint}/export?public:
    get:
      description: |-
        Download the raw image file(s) of a public image from the server.
        If the image is in split format, a multipart http transfer occurs.
      operationId: image_export_get_untrusted
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Secret token to retrieve a private image
        example: RANDOM-STRING
        in: query
        name: secret
        type: string
      produces:
      - application/octet-stream
      - multipart/form-data
      responses:
        "200":
          description: Raw image data
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the raw image file(s)
      tags:
      - images
  /1.0/images/{fingerprint}/refresh:
    post:
      description: |-
        This causes LXD to check the image source server for an updated
        version of the image and if available to refresh the local copy with the
        new version.
      operationId: images_refresh_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Refresh an image
      tags:
      - images
  /1.0/images/{fingerprint}/secret:
    post:
      description: |-
        This generates a background operation including a secret one time key
        in its metadata which can be used to fetch this image from an untrusted
        client.
      operationId: images_secret_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Generate secret for retrieval of the image by an untrusted client
      tags:
      - images
  /1.0/images/{fingerprint}?public:
    get:
      description: Gets a specific public image.
      operationId: image_get_untrusted
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Secret token to retrieve a private image
        example: RANDOM-STRING
        in: query
        name: secret
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Image
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Image'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the public image
      tags:
      - images
  /1.0/images/aliases:
    get:
      description: Returns a list of image aliases (URLs).
      operationId: images_aliases_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/images/aliases/foo",
                    "/1.0/images/aliases/bar1"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the image aliases
      tags:
      - images
    post:
      consumes:
      - application/json
      description: Creates a new image alias.
      operationId: images_aliases_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image alias
        in: body
        name: image alias
        required: true
        schema:
          $ref: '#/definitions/ImageAliasesPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add an image alias
      tags:
      - images
  /1.0/images/aliases/{name}:
    delete:
      description: Deletes a specific image alias.
      operationId: image_alias_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the image alias
      tags:
      - images
    get:
      description: Gets a specific image alias.
      operationId: image_alias_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Image alias
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/ImageAliasesEntry'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the image alias
      tags:
      - images
    patch:
      consumes:
      - application/json
      description: Updates a subset of the image alias configuration.
      operationId: images_alias_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image alias configuration
        in: body
        name: image alias
        required: true
        schema:
          $ref: '#/definitions/ImageAliasesEntryPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the image alias
      tags:
      - images
    post:
      consumes:
      - application/json
      description: Renames an existing image alias.
      operationId: images_alias_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image alias rename request
        in: body
        name: image alias
        required: true
        schema:
          $ref: '#/definitions/ImageAliasesEntryPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename the image alias
      tags:
      - images
    put:
      consumes:
      - application/json
      description: Updates the entire image alias configuration.
      operationId: images_aliases_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image alias configuration
        in: body
        name: image alias
        required: true
        schema:
          $ref: '#/definitions/ImageAliasesEntryPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the image alias
      tags:
      - images
  /1.0/images/aliases/{name}?public:
    get:
      description: |-
        Gets a specific public image alias.
        This untrusted endpoint only works for aliases pointing to public images.
      operationId: image_alias_get_untrusted
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Image alias
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/ImageAliasesEntry'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the public image alias
      tags:
      - images
  /1.0/images/aliases?recursion=1:
    get:
      description: Returns a list of image aliases (structs).
      operationId: images_aliases_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of image aliases
                items:
                  $ref: '#/definitions/ImageAliasesEntry'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the image aliases
      tags:
      - images
  /1.0/images?public:
    get:
      description: Returns a list of publicly available images (URLs).
      operationId: images_get_untrusted
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Collection filter
        example: default
        in: query
        name: filter
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/images/06b86454720d36b20f94e31c6812e05ec51c1b568cf3a8abd273769d213394bb",
                    "/1.0/images/084dd79dd1360fd25a2479eb46674c2a5ef3022a40fe03c91ab3603e3402b8e1"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the public images
      tags:
      - images
    post:
      consumes:
      - application/json
      description: |-
        Pushes the data to the target image server.
        This is meant for LXD to LXD communication where a new image entry is
        prepared on the target server and the source server is provided that URL
        and a secret token to push the image content over.
      operationId: images_post_untrusted
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image
        in: body
        name: image
        required: true
        schema:
          $ref: '#/definitions/ImagesPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add an image
      tags:
      - images
  /1.0/images?public&recursion=1:
    get:
      description: Returns a list of publicly available images (structs).
      operationId: images_get_recursion1_untrusted
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Collection filter
        example: default
        in: query
        name: filter
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of images
                items:
                  $ref: '#/definitions/Image'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the public images
      tags:
      - images
  /1.0/images?recursion=1:
    get:
      description: Returns a list of images (structs).
      operationId: images_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Collection filter
        example: default
        in: query
        name: filter
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of images
                items:
                  $ref: '#/definitions/Image'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the images
      tags:
      - images
  /1.0/instances:
    get:
      description: Returns a list of instances (URLs).
      operationId: instances_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Collection filter
        example: default
        in: query
        name: filter
        type: string
      - description: Retrieve instances from all projects
        in: query
        name: all-projects
        type: boolean
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/instances/foo",
                    "/1.0/instances/bar"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the instances
      tags:
      - instances
    post:
      consumes:
      - application/json
      description: |-
        Creates a new instance on LXD.
        Depending on the source, this can create an instance from an existing
        local image, remote image, existing local instance or snapshot, remote
        migration stream or backup file.
      operationId: instances_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member
        example: default
        in: query
        name: target
        type: string
      - description: Instance request
        in: body
        name: instance
        schema:
          $ref: '#/definitions/InstancesPost'
      - description: Raw backup file
        in: body
        name: raw_backup
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Create a new instance
      tags:
      - instances
    put:
      consumes:
      - application/json
      description: Changes the running state of all instances.
      operationId: instances_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: State
        in: body
        name: state
        schema:
          $ref: '#/definitions/InstancesPut'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Bulk instance state update
      tags:
      - instances
  /1.0/instances/{name}:
    delete:
      description: |-
        Deletes a specific instance.

        This also deletes anything owned by the instance such as snapshots and backups.
      operationId: instance_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete an instance
      tags:
      - instances
    get:
      description: Gets a specific instance (basic struct).
      operationId: instance_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Instance
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Instance'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the instance
      tags:
      - instances
    patch:
      consumes:
      - application/json
      description: Updates a subset of the instance configuration
      operationId: instance_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Update request
        in: body
        name: instance
        schema:
          $ref: '#/definitions/InstancePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the instance
      tags:
      - instances
    post:
      consumes:
      - application/json
      description: |-
        Renames, moves an instance between pools or migrates an instance to another server.

        The returned operation metadata will vary based on what's requested.
        For rename or move within the same server, this is a simple background operation with progress data.
        For migration, in the push case, this will similarly be a background
        operation with progress data, for the pull case, it will be a websocket
        operation with a number of secrets to be passed to the target server.
      operationId: instance_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Migration request
        in: body
        name: migration
        schema:
          $ref: '#/definitions/InstancePost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename or move/migrate an instance
      tags:
      - instances
    put:
      consumes:
      - application/json
      description: Updates the instance configuration or trigger a snapshot restore.
      operationId: instance_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Update request
        in: body
        name: instance
        schema:
          $ref: '#/definitions/InstancePut'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the instance
      tags:
      - instances
  /1.0/instances/{name}/backups:
    get:
      description: Returns a list of instance backups (URLs).
      operationId: instance_backups_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/instances/foo/backups/backup0",
                    "/1.0/instances/foo/backups/backup1"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the backups
      tags:
      - instances
    post:
      consumes:
      - application/json
      description: Creates a new backup.
      operationId: instance_backups_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Backup request
        in: body
        name: backup
        schema:
          $ref: '#/definitions/InstanceBackupsPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Create a backup
      tags:
      - instances
  /1.0/instances/{name}/backups/{backup}:
    delete:
      consumes:
      - application/json
      description: Deletes the instance backup.
      operationId: instance_backup_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete a backup
      tags:
      - instances
    get:
      description: Gets a specific instance backup.
      operationId: instance_backup_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Instance backup
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/InstanceBackup'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the backup
      tags:
      - instances
    post:
      consumes:
      - application/json
      description: Renames an instance backup.
      operationId: instance_backup_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Backup rename
        in: body
        name: backup
        schema:
          $ref: '#/definitions/InstanceBackupPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename a backup
      tags:
      - instances
  /1.0/instances/{name}/backups/{backup}/export:
    get:
      description: Download the raw backup file(s) from the server.
      operationId: instance_backup_export
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/octet-stream
      responses:
        "200":
          description: Raw image data
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the raw backup file(s)
      tags:
      - instances
  /1.0/instances/{name}/backups?recursion=1:
    get:
      description: Returns a list of instance backups (structs).
      operationId: instance_backups_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of instance backups
                items:
                  $ref: '#/definitions/InstanceBackup'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the backups
      tags:
      - instances
  /1.0/instances/{name}/console:
    delete:
      description: Clears the console log buffer.
      operationId: instance_console_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Clear the console log
      tags:
      - instances
    get:
      description: Gets the console log for the instance.
      operationId: instance_console_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Raw console log
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get console log
      tags:
      - instances
    post:
      consumes:
      - application/json
      description: |-
        Connects to the console of an instance.

        The returned operation metadata will contain two websockets, one for data and one for control.
      operationId: instance_console_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Console request
        in: body
        name: console
        schema:
          $ref: '#/definitions/InstanceConsolePost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Connect to console
      tags:
      - instances
  /1.0/instances/{name}/exec:
    post:
      consumes:
      - application/json
      description: |-
        Executes a command inside an instance.

        The returned operation metadata will contain either 2 or 4 websockets.
        In non-interactive mode, you'll get one websocket for each of stdin, stdout and stderr.
        In interactive mode, a single bi-directional websocket is used for stdin and stdout/stderr.

        An additional "control" socket is always added on top which can be used for out of band communication with LXD.
        This allows sending signals and window sizing information through.
      operationId: instance_exec_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Exec request
        in: body
        name: exec
        schema:
          $ref: '#/definitions/InstanceExecPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Run a command
      tags:
      - instances
  /1.0/instances/{name}/files:
    delete:
      description: Removes the file.
      operationId: instance_files_delete
      parameters:
      - description: Path to the file
        example: default
        in: query
        name: path
        type: string
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete a file
      tags:
      - instances
    get:
      description: Gets the file content. If it's a directory, a json list of files
        will be returned instead.
      operationId: instance_files_get
      parameters:
      - description: Path to the file
        example: default
        in: query
        name: path
        type: string
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      - application/octet-stream
      responses:
        "200":
          description: Raw file or directory listing
          headers:
            X-LXD-gid:
              description: File owner GID
            X-LXD-mode:
              description: Mode mask
            X-LXD-type:
              description: Type of file (file, symlink or directory)
            X-LXD-uid:
              description: File owner UID
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get a file
      tags:
      - instances
    post:
      consumes:
      - application/octet-stream
      description: Creates a new file in the instance.
      operationId: instance_files_post
      parameters:
      - description: Path to the file
        example: default
        in: query
        name: path
        type: string
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Raw file content
        in: body
        name: raw_file
      - description: File owner UID
        example: 1000
        in: header
        name: X-LXD-uid
        schema:
          type: integer
      - description: File owner GID
        example: 1000
        in: header
        name: X-LXD-gid
        schema:
          type: integer
      - description: File mode
        example: 420
        in: header
        name: X-LXD-mode
        schema:
          type: integer
      - description: Type of file (file, symlink or directory)
        example: file
        in: header
        name: X-LXD-type
        schema:
          type: string
      - description: Write mode (overwrite or append)
        example: overwrite
        in: header
        name: X-LXD-write
        schema:
          type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Create or replace a file
      tags:
      - instances
  /1.0/instances/{name}/logs:
    get:
      description: Returns a list of log files (URLs).
      operationId: instance_logs_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/instances/foo/logs/lxc.conf",
                    "/1.0/instances/foo/logs/lxc.log"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the log files
      tags:
      - instances
  /1.0/instances/{name}/logs/{filename}:
    delete:
      description: Removes the log file.
      operationId: instance_log_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the log file
      tags:
      - instances
    get:
      description: Gets the log file.
      operationId: instance_log_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      - application/octet-stream
      responses:
        "200":
          description: Raw file
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the log file
      tags:
      - instances
  /1.0/instances/{name}/metadata:
    get:
      description: Gets the image metadata for the instance.
      operationId: instance_metadata_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Image metadata
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/ImageMetadata'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the instance image metadata
      tags:
      - instances
    patch:
      consumes:
      - application/json
      description: Updates a subset of the instance image metadata.
      operationId: instance_metadata_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image metadata
        in: body
        name: metadata
        required: true
        schema:
          $ref: '#/definitions/ImageMetadata'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the image metadata
      tags:
      - instances
    put:
      consumes:
      - application/json
      description: Updates the instance image metadata.
      operationId: instance_metadata_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Image metadata
        in: body
        name: metadata
        required: true
        schema:
          $ref: '#/definitions/ImageMetadata'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the image metadata
      tags:
      - instances
  /1.0/instances/{name}/metadata/templates:
    delete:
      description: Removes the template file.
      operationId: instance_metadata_templates_delete
      parameters:
      - description: Template name
        example: default
        in: query
        name: path
        type: string
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete a template file
      tags:
      - instances
    get:
      description: |-
        If no path specified, returns a list of template file names.
        If a path is specified, returns the file content.
      operationId: instance_metadata_templates_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Template name
        example: hostname.tpl
        in: query
        name: path
        type: string
      produces:
      - application/json
      - application/octet-stream
      responses:
        "200":
          description: Raw template file or file listing
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the template file names or a specific
      tags:
      - instances
    post:
      consumes:
      - application/octet-stream
      description: Creates a new image template file for the instance.
      operationId: instance_metadata_templates_post
      parameters:
      - description: Template name
        example: default
        in: query
        name: path
        type: string
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Raw file content
        in: body
        name: raw_file
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Create or replace a template file
      tags:
      - instances
  /1.0/instances/{name}/snapshots:
    get:
      description: Returns a list of instance snapshots (URLs).
      operationId: instance_snapshots_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/instances/foo/snapshots/snap0",
                    "/1.0/instances/foo/snapshots/snap1"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the snapshots
      tags:
      - instances
    post:
      consumes:
      - application/json
      description: Creates a new snapshot.
      operationId: instance_snapshots_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Snapshot request
        in: body
        name: snapshot
        schema:
          $ref: '#/definitions/InstanceSnapshotsPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Create a snapshot
      tags:
      - instances
  /1.0/instances/{name}/snapshots/{snapshot}:
    delete:
      consumes:
      - application/json
      description: Deletes the instance snapshot.
      operationId: instance_snapshot_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete a snapshot
      tags:
      - instances
    get:
      description: Gets a specific instance snapshot.
      operationId: instance_snapshot_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Instance snapshot
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/InstanceSnapshot'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the snapshot
      tags:
      - instances
    patch:
      consumes:
      - application/json
      description: Updates a subset of the snapshot config.
      operationId: instance_snapshot_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Snapshot update
        in: body
        name: snapshot
        schema:
          $ref: '#/definitions/InstanceSnapshotPut'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update snapshot
      tags:
      - instances
    post:
      consumes:
      - application/json
      description: |-
        Renames or migrates an instance snapshot to another server.

        The returned operation metadata will vary based on what's requested.
        For rename or move within the same server, this is a simple background operation with progress data.
        For migration, in the push case, this will similarly be a background
        operation with progress data, for the pull case, it will be a websocket
        operation with a number of secrets to be passed to the target server.
      operationId: instance_snapshot_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Snapshot migration
        in: body
        name: snapshot
        schema:
          $ref: '#/definitions/InstanceSnapshotPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename or move/migrate a snapshot
      tags:
      - instances
    put:
      consumes:
      - application/json
      description: Updates the snapshot config.
      operationId: instance_snapshot_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Snapshot update
        in: body
        name: snapshot
        schema:
          $ref: '#/definitions/InstanceSnapshotPut'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update snapshot
      tags:
      - instances
  /1.0/instances/{name}/snapshots?recursion=1:
    get:
      description: Returns a list of instance snapshots (structs).
      operationId: instance_snapshots_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of instance snapshots
                items:
                  $ref: '#/definitions/InstanceSnapshot'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the snapshots
      tags:
      - instances
  /1.0/instances/{name}/state:
    get:
      description: |-
        Gets the runtime state of the instance.

        This is a reasonably expensive call as it causes code to be run
        inside of the instance to retrieve the resource usage and network
        information.
      operationId: instance_state_get
      parameters:
      - description: Project name
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: State
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/InstanceState'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the runtime state
      tags:
      - instances
    put:
      consumes:
      - application/json
      description: Changes the running state of the instance.
      operationId: instance_state_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: State
        in: body
        name: state
        schema:
          $ref: '#/definitions/InstanceStatePut'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Change the state
      tags:
      - instances
  /1.0/instances/{name}?recursion=1:
    get:
      description: |-
        Gets a specific instance (full struct).

        recursion=1 also includes information about state, snapshots and backups.
      operationId: instance_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Instance
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Instance'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the instance
      tags:
      - instances
  /1.0/instances?recursion=1:
    get:
      description: Returns a list of instances (basic structs).
      operationId: instances_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Collection filter
        example: default
        in: query
        name: filter
        type: string
      - description: Retrieve instances from all projects
        in: query
        name: all-projects
        type: boolean
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of instances
                items:
                  $ref: '#/definitions/Instance'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the instances
      tags:
      - instances
  /1.0/instances?recursion=2:
    get:
      description: |-
        Returns a list of instances (full structs).

        The main difference between recursion=1 and recursion=2 is that the
        latter also includes state and snapshot information allowing for a
        single API call to return everything needed by most clients.
      operationId: instances_get_recursion2
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Collection filter
        example: default
        in: query
        name: filter
        type: string
      - description: Retrieve instances from all projects
        in: query
        name: all-projects
        type: boolean
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of instances
                items:
                  $ref: '#/definitions/InstanceFull'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the instances
      tags:
      - instances
  /1.0/metrics:
    get:
      description: Gets metrics of instances.
      operationId: metrics_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - text/plain
      responses:
        "200":
          description: Metrics
          schema:
            description: Instance metrics
            type: string
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get metrics
      tags:
      - metrics
  /1.0/network-acls:
    get:
      description: Returns a list of network ACLs (URLs).
      operationId: network_acls_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/network-acls/foo",
                    "/1.0/network-acls/bar"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network ACLs
      tags:
      - network-acls
    post:
      consumes:
      - application/json
      description: Creates a new network ACL.
      operationId: network_acls_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: ACL
        in: body
        name: acl
        required: true
        schema:
          $ref: '#/definitions/NetworkACLsPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a network ACL
      tags:
      - network-acls
  /1.0/network-acls/{name}:
    delete:
      description: Removes the network ACL.
      operationId: network_acl_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the network ACL
      tags:
      - network-acls
    get:
      description: Gets a specific network ACL.
      operationId: network_acl_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: ACL
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/NetworkACL'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network ACL
      tags:
      - network-acls
    patch:
      consumes:
      - application/json
      description: Updates a subset of the network ACL configuration.
      operationId: network_acl_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: ACL configuration
        in: body
        name: acl
        required: true
        schema:
          $ref: '#/definitions/NetworkACLPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the network ACL
      tags:
      - network-acls
    post:
      consumes:
      - application/json
      description: Renames an existing network ACL.
      operationId: network_acl_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: ACL rename request
        in: body
        name: acl
        required: true
        schema:
          $ref: '#/definitions/NetworkACLPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename the network ACL
      tags:
      - network-acls
    put:
      consumes:
      - application/json
      description: Updates the entire network ACL configuration.
      operationId: network_acl_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: ACL configuration
        in: body
        name: acl
        required: true
        schema:
          $ref: '#/definitions/NetworkACLPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the network ACL
      tags:
      - network-acls
  /1.0/network-acls/{name}/log:
    get:
      description: Gets a specific network ACL log entries.
      operationId: network_acl_log_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/octet-stream
      responses:
        "200":
          description: Raw log file
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network ACL log
      tags:
      - network-acls
  /1.0/network-acls?recursion=1:
    get:
      description: Returns a list of network ACLs (structs).
      operationId: network_acls_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of network ACLs
                items:
                  $ref: '#/definitions/NetworkACL'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network ACLs
      tags:
      - network-acls
  /1.0/network-zones:
    get:
      description: Returns a list of network zones (URLs).
      operationId: network_zones_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/network-zones/example.net",
                    "/1.0/network-zones/example.com"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network zones
      tags:
      - network-zones
    post:
      consumes:
      - application/json
      description: Creates a new network zone.
      operationId: network_zones_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: zone
        in: body
        name: zone
        required: true
        schema:
          $ref: '#/definitions/NetworkZonesPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a network zone
      tags:
      - network-zones
  /1.0/network-zones/{name}:
    delete:
      description: Removes the network zone.
      operationId: network_zone_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the network zone
      tags:
      - network-zones
    get:
      description: Gets a specific network zone.
      operationId: network_zone_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: zone
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/NetworkZone'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network zone
      tags:
      - network-zones
    patch:
      consumes:
      - application/json
      description: Updates a subset of the network zone configuration.
      operationId: network_zone_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: zone configuration
        in: body
        name: zone
        required: true
        schema:
          $ref: '#/definitions/NetworkZonePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the network zone
      tags:
      - network-zones
    put:
      consumes:
      - application/json
      description: Updates the entire network zone configuration.
      operationId: network_zone_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: zone configuration
        in: body
        name: zone
        required: true
        schema:
          $ref: '#/definitions/NetworkZonePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the network zone
      tags:
      - network-zones
  /1.0/network-zones/{zone}/records:
    get:
      description: Returns a list of network zone records (URLs).
      operationId: network_zone_records_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/network-zones/example.net/records/foo",
                    "/1.0/network-zones/example.net/records/bar"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network zone records
      tags:
      - network-zones
    post:
      consumes:
      - application/json
      description: Creates a new network zone record.
      operationId: network_zone_records_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: zone
        in: body
        name: zone
        required: true
        schema:
          $ref: '#/definitions/NetworkZoneRecordsPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a network zone record
      tags:
      - network-zones
  /1.0/network-zones/{zone}/records/{name}:
    delete:
      description: Removes the network zone record.
      operationId: network_zone_record_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the network zone record
      tags:
      - network-zones
    get:
      description: Gets a specific network zone record.
      operationId: network_zone_record_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: zone
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/NetworkZoneRecord'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network zone record
      tags:
      - network-zones
    patch:
      consumes:
      - application/json
      description: Updates a subset of the network zone record configuration.
      operationId: network_zone_record_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: zone record configuration
        in: body
        name: zone
        required: true
        schema:
          $ref: '#/definitions/NetworkZoneRecordPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the network zone record
      tags:
      - network-zones
    put:
      consumes:
      - application/json
      description: Updates the entire network zone record configuration.
      operationId: network_zone_record_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: zone record configuration
        in: body
        name: zone
        required: true
        schema:
          $ref: '#/definitions/NetworkZoneRecordPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the network zone record
      tags:
      - network-zones
  /1.0/network-zones/{zone}/records?recursion=1:
    get:
      description: Returns a list of network zone records (structs).
      operationId: network_zone_records_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of network zone records
                items:
                  $ref: '#/definitions/NetworkZoneRecord'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network zone records
      tags:
      - network-zones
  /1.0/network-zones?recursion=1:
    get:
      description: Returns a list of network zones (structs).
      operationId: network_zones_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of network zones
                items:
                  $ref: '#/definitions/NetworkZone'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network zones
      tags:
      - network-zones
  /1.0/networks:
    get:
      description: Returns a list of networks (URLs).
      operationId: networks_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/networks/lxdbr0",
                    "/1.0/networks/lxdbr1"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the networks
      tags:
      - networks
    post:
      consumes:
      - application/json
      description: |-
        Creates a new network.
        When clustered, most network types require individual POST for each cluster member prior to a global POST.
      operationId: networks_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Network
        in: body
        name: network
        required: true
        schema:
          $ref: '#/definitions/NetworksPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a network
      tags:
      - networks
  /1.0/networks/{name}:
    delete:
      description: Removes the network.
      operationId: network_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the network
      tags:
      - networks
    get:
      description: Gets a specific network.
      operationId: network_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Network
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Network'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network
      tags:
      - networks
    patch:
      consumes:
      - application/json
      description: Updates a subset of the network configuration.
      operationId: network_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Network configuration
        in: body
        name: network
        required: true
        schema:
          $ref: '#/definitions/NetworkPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the network
      tags:
      - networks
    post:
      consumes:
      - application/json
      description: Renames an existing network.
      operationId: network_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Network rename request
        in: body
        name: network
        required: true
        schema:
          $ref: '#/definitions/NetworkPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename the network
      tags:
      - networks
    put:
      consumes:
      - application/json
      description: Updates the entire network configuration.
      operationId: network_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Network configuration
        in: body
        name: network
        required: true
        schema:
          $ref: '#/definitions/NetworkPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the network
      tags:
      - networks
  /1.0/networks/{name}/leases:
    get:
      description: Returns a list of DHCP leases for the network.
      operationId: networks_leases_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of DHCP leases
                items:
                  $ref: '#/definitions/NetworkLease'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the DHCP leases
      tags:
      - networks
  /1.0/networks/{name}/state:
    get:
      description: Returns the current network state information.
      operationId: networks_state_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/NetworkState'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network state
      tags:
      - networks
  /1.0/networks/{networkName}/forwards:
    get:
      description: Returns a list of network address forwards (URLs).
      operationId: network_forwards_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/networks/lxdbr0/forwards/192.0.2.1",
                    "/1.0/networks/lxdbr0/forwards/192.0.2.2"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network address forwards
      tags:
      - network-forwards
    post:
      consumes:
      - application/json
      description: Creates a new network address forward.
      operationId: network_forwards_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Forward
        in: body
        name: forward
        required: true
        schema:
          $ref: '#/definitions/NetworkForwardsPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a network address forward
      tags:
      - network-forwards
  /1.0/networks/{networkName}/forwards/{listenAddress}:
    delete:
      description: Removes the network address forward.
      operationId: network_forward_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the network address forward
      tags:
      - network-forwards
    get:
      description: Gets a specific network address forward.
      operationId: network_forward_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Address forward
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/NetworkForward'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network address forward
      tags:
      - network-forwards
    patch:
      consumes:
      - application/json
      description: Updates a subset of the network address forward configuration.
      operationId: network_forward_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Address forward configuration
        in: body
        name: forward
        required: true
        schema:
          $ref: '#/definitions/NetworkForwardPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the network address forward
      tags:
      - network-forwards
    put:
      consumes:
      - application/json
      description: Updates the entire network address forward configuration.
      operationId: network_forward_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Address forward configuration
        in: body
        name: forward
        required: true
        schema:
          $ref: '#/definitions/NetworkForwardPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the network address forward
      tags:
      - network-forwards
  /1.0/networks/{networkName}/forwards?recursion=1:
    get:
      description: Returns a list of network address forwards (structs).
      operationId: network_forward_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of network address forwards
                items:
                  $ref: '#/definitions/NetworkForward'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network address forwards
      tags:
      - network-forwards
  /1.0/networks/{networkName}/peers:
    get:
      description: Returns a list of network peers (URLs).
      operationId: network_peers_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/networks/lxdbr0/peers/my-peer-1",
                    "/1.0/networks/lxdbr0/peers/my-peer-2"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network peers
      tags:
      - network-peers
    post:
      consumes:
      - application/json
      description: Initiates/creates a new network peering.
      operationId: network_peers_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Peer
        in: body
        name: peer
        required: true
        schema:
          $ref: '#/definitions/NetworkPeersPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "202":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a network peer
      tags:
      - network-peers
  /1.0/networks/{networkName}/peers/{peerName}:
    delete:
      description: Removes the network peering.
      operationId: network_peer_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the network peer
      tags:
      - network-peers
    get:
      description: Gets a specific network peering.
      operationId: network_peer_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Peer
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/NetworkPeer'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network peer
      tags:
      - network-peers
    patch:
      consumes:
      - application/json
      description: Updates a subset of the network peering configuration.
      operationId: network_peer_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Peer configuration
        in: body
        name: Peer
        required: true
        schema:
          $ref: '#/definitions/NetworkPeerPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the network peer
      tags:
      - network-peers
    put:
      consumes:
      - application/json
      description: Updates the entire network peering configuration.
      operationId: network_peer_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Peer configuration
        in: body
        name: peer
        required: true
        schema:
          $ref: '#/definitions/NetworkPeerPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the network peer
      tags:
      - network-peers
  /1.0/networks/{networkName}/peers?recursion=1:
    get:
      description: Returns a list of network peers (structs).
      operationId: network_peer_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of network peers
                items:
                  $ref: '#/definitions/NetworkPeer'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the network peers
      tags:
      - network-peers
  /1.0/networks?recursion=1:
    get:
      description: Returns a list of networks (structs).
      operationId: networks_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of networks
                items:
                  $ref: '#/definitions/Network'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the networks
      tags:
      - networks
  /1.0/operations:
    get:
      description: Returns a dict of operation type to operation list (URLs).
      operationId: operations_get
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                additionalProperties:
                  items:
                    type: string
                  type: array
                description: Dict of operation types to operation URLs
                example: |-
                  {
                    "running": [
                      "/1.0/operations/6916c8a6-9b7d-4abd-90b3-aedfec7ec7da"
                    ]
                  }
                type: object
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the operations
      tags:
      - operations
  /1.0/operations/{id}:
    delete:
      description: Cancels the operation if supported.
      operationId: operation_delete
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Cancel the operation
      tags:
      - operations
    get:
      description: Gets the operation state.
      operationId: operation_get
      produces:
      - application/json
      responses:
        "200":
          description: Operation
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Operation'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the operation state
      tags:
      - operations
  /1.0/operations/{id}/wait:
    get:
      description: Waits for the operation to reach a final state (or timeout) and
        retrieve its final state.
      operationId: operation_wait_get
      parameters:
      - description: Timeout in seconds (-1 means never)
        example: -1
        in: query
        name: timeout
        type: integer
      produces:
      - application/json
      responses:
        "200":
          description: Operation
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Operation'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Wait for the operation
      tags:
      - operations
  /1.0/operations/{id}/wait?public:
    get:
      description: |-
        Waits for the operation to reach a final state (or timeout) and retrieve its final state.

        When accessed by an untrusted user, the secret token must be provided.
      operationId: operation_wait_get_untrusted
      parameters:
      - description: Authentication token
        example: random-string
        in: query
        name: secret
        type: string
      - description: Timeout in seconds (-1 means never)
        example: -1
        in: query
        name: timeout
        type: integer
      produces:
      - application/json
      responses:
        "200":
          description: Operation
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Operation'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Wait for the operation
      tags:
      - operations
  /1.0/operations/{id}/websocket:
    get:
      description: |-
        Connects to an associated websocket stream for the operation.
        This should almost never be done directly by a client, instead it's
        meant for LXD to LXD communication with the client only relaying the
        connection information to the servers.
      operationId: operation_websocket_get
      parameters:
      - description: Authentication token
        example: random-string
        in: query
        name: secret
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Websocket operation messages (dependent on operation)
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the websocket stream
      tags:
      - operations
  /1.0/operations/{id}/websocket?public:
    get:
      description: |-
        Connects to an associated websocket stream for the operation.
        This should almost never be done directly by a client, instead it's
        meant for LXD to LXD communication with the client only relaying the
        connection information to the servers.

        The untrusted endpoint is used by the target server to connect to the source server.
        Authentication is performed through the secret token.
      operationId: operation_websocket_get_untrusted
      parameters:
      - description: Authentication token
        example: random-string
        in: query
        name: secret
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Websocket operation messages (dependent on operation)
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the websocket stream
      tags:
      - operations
  /1.0/operations?recursion=1:
    get:
      description: Returns a list of operations (structs).
      operationId: operations_get_recursion1
      produces:
      - application/json
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of operations
                items:
                  $ref: '#/definitions/Operation'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the operations
      tags:
      - operations
  /1.0/profiles:
    get:
      description: Returns a list of profiles (URLs).
      operationId: profiles_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/profiles/default",
                    "/1.0/profiles/foo"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the profiles
      tags:
      - profiles
    post:
      consumes:
      - application/json
      description: Creates a new profile.
      operationId: profiles_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Profile
        in: body
        name: profile
        required: true
        schema:
          $ref: '#/definitions/ProfilesPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a profile
      tags:
      - profiles
  /1.0/profiles/{name}:
    delete:
      description: Removes the profile.
      operationId: profile_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the profile
      tags:
      - profiles
    get:
      description: Gets a specific profile.
      operationId: profile_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Profile
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Profile'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the profile
      tags:
      - profiles
    patch:
      consumes:
      - application/json
      description: Updates a subset of the profile configuration.
      operationId: profile_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Profile configuration
        in: body
        name: profile
        required: true
        schema:
          $ref: '#/definitions/ProfilePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the profile
      tags:
      - profiles
    post:
      consumes:
      - application/json
      description: Renames an existing profile.
      operationId: profile_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Profile rename request
        in: body
        name: profile
        required: true
        schema:
          $ref: '#/definitions/ProfilePost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename the profile
      tags:
      - profiles
    put:
      consumes:
      - application/json
      description: Updates the entire profile configuration.
      operationId: profile_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Profile configuration
        in: body
        name: profile
        required: true
        schema:
          $ref: '#/definitions/ProfilePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the profile
      tags:
      - profiles
  /1.0/profiles?recursion=1:
    get:
      description: Returns a list of profiles (structs).
      operationId: profiles_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of profiles
                items:
                  $ref: '#/definitions/Profile'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the profiles
      tags:
      - profiles
  /1.0/projects:
    get:
      description: Returns a list of projects (URLs).
      operationId: projects_get
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/projects/default",
                    "/1.0/projects/foo"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the projects
      tags:
      - projects
    post:
      consumes:
      - application/json
      description: Creates a new project.
      operationId: projects_post
      parameters:
      - description: Project
        in: body
        name: project
        required: true
        schema:
          $ref: '#/definitions/ProjectsPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a project
      tags:
      - projects
  /1.0/projects/{name}:
    delete:
      description: Removes the project.
      operationId: project_delete
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the project
      tags:
      - projects
    get:
      description: Gets a specific project.
      operationId: project_get
      produces:
      - application/json
      responses:
        "200":
          description: Project
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Project'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the project
      tags:
      - projects
    patch:
      consumes:
      - application/json
      description: Updates a subset of the project configuration.
      operationId: project_patch
      parameters:
      - description: Project configuration
        in: body
        name: project
        required: true
        schema:
          $ref: '#/definitions/ProjectPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the project
      tags:
      - projects
    post:
      consumes:
      - application/json
      description: Renames an existing project.
      operationId: project_post
      parameters:
      - description: Project rename request
        in: body
        name: project
        required: true
        schema:
          $ref: '#/definitions/ProjectPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename the project
      tags:
      - projects
    put:
      consumes:
      - application/json
      description: Updates the entire project configuration.
      operationId: project_put
      parameters:
      - description: Project configuration
        in: body
        name: project
        required: true
        schema:
          $ref: '#/definitions/ProjectPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the project
      tags:
      - projects
  /1.0/projects/{name}/state:
    get:
      description: Gets a specific project resource consumption information.
      operationId: project_state_get
      produces:
      - application/json
      responses:
        "200":
          description: Project state
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/ProjectState'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the project state
      tags:
      - projects
  /1.0/projects?recursion=1:
    get:
      description: Returns a list of projects (structs).
      operationId: projects_get_recursion1
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of projects
                items:
                  $ref: '#/definitions/Project'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the projects
      tags:
      - projects
  /1.0/resources:
    get:
      description: Gets the hardware information profile of the LXD server.
      operationId: resources_get
      parameters:
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Hardware resources
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Resources'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get system resources information
      tags:
      - server
  /1.0/storage-pools:
    get:
      description: Returns a list of storage pools (URLs).
      operationId: storage_pools_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/storage-pools/local",
                    "/1.0/storage-pools/remote"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage pools
      tags:
      - storage
    post:
      consumes:
      - application/json
      description: |-
        Creates a new storage pool.
        When clustered, storage pools require individual POST for each cluster member prior to a global POST.
      operationId: storage_pools_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage pool
        in: body
        name: storage
        required: true
        schema:
          $ref: '#/definitions/StoragePoolsPost'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a storage pool
      tags:
      - storage
  /1.0/storage-pools/{name}:
    delete:
      description: Removes the storage pool.
      operationId: storage_pools_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the storage pool
      tags:
      - storage
    get:
      description: Gets a specific storage pool.
      operationId: storage_pool_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Storage pool
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/StoragePool'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage pool
      tags:
      - storage
    patch:
      consumes:
      - application/json
      description: Updates a subset of the storage pool configuration.
      operationId: storage_pool_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage pool configuration
        in: body
        name: storage pool
        required: true
        schema:
          $ref: '#/definitions/StoragePoolPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the storage pool
      tags:
      - storage
    put:
      consumes:
      - application/json
      description: Updates the entire storage pool configuration.
      operationId: storage_pool_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage pool configuration
        in: body
        name: storage pool
        required: true
        schema:
          $ref: '#/definitions/StoragePoolPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the storage pool
      tags:
      - storage
  /1.0/storage-pools/{name}/resources:
    get:
      description: Gets the usage information for the storage pool.
      operationId: storage_pool_resources
      parameters:
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Hardware resources
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/ResourcesStoragePool'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get storage pool resources information
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes:
    get:
      description: Returns a list of storage volumes (URLs).
      operationId: storage_pool_volumes_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Collection filter
        example: default
        in: query
        name: filter
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/storage-pools/local/volumes/container/a1",
                    "/1.0/storage-pools/local/volumes/container/a2",
                    "/1.0/storage-pools/local/volumes/custom/backups",
                    "/1.0/storage-pools/local/volumes/custom/images"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volumes
      tags:
      - storage
    post:
      consumes:
      - application/json
      description: Creates a new storage volume.
      operationId: storage_pool_volumes_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage volume
        in: body
        name: volume
        required: true
        schema:
          $ref: '#/definitions/StorageVolumesPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a storage volume
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}:
    get:
      description: Returns a list of storage volumes (URLs) (type specific endpoint).
      operationId: storage_pool_volumes_type_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/storage-pools/local/volumes/custom/backups",
                    "/1.0/storage-pools/local/volumes/custom/images"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volumes
      tags:
      - storage
    post:
      consumes:
      - application/json
      description: Creates a new storage volume (type specific endpoint).
      operationId: storage_pool_volumes_type_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage volume
        in: body
        name: volume
        required: true
        schema:
          $ref: '#/definitions/StorageVolumesPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Add a storage volume
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}/{volume}:
    delete:
      description: Removes the storage volume.
      operationId: storage_pool_volume_type_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the storage volume
      tags:
      - storage
    get:
      description: Gets a specific storage volume.
      operationId: storage_pool_volume_type_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Storage volume
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/StorageVolume'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volume
      tags:
      - storage
    patch:
      consumes:
      - application/json
      description: Updates a subset of the storage volume configuration.
      operationId: storage_pool_volume_type_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage volume configuration
        in: body
        name: storage volume
        required: true
        schema:
          $ref: '#/definitions/StorageVolumePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the storage volume
      tags:
      - storage
    post:
      consumes:
      - application/json
      description: |-
        Renames, moves a storage volume between pools or migrates an instance to another server.

        The returned operation metadata will vary based on what's requested.
        For rename or move within the same server, this is a simple background operation with progress data.
        For migration, in the push case, this will similarly be a background
        operation with progress data, for the pull case, it will be a websocket
        operation with a number of secrets to be passed to the target server.
      operationId: storage_pool_volume_type_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Migration request
        in: body
        name: migration
        schema:
          $ref: '#/definitions/StorageVolumePost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename or move/migrate a storage volume
      tags:
      - storage
    put:
      consumes:
      - application/json
      description: Updates the entire storage volume configuration.
      operationId: storage_pool_volume_type_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage volume configuration
        in: body
        name: storage volume
        required: true
        schema:
          $ref: '#/definitions/StorageVolumePut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the storage volume
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}/{volume}/backups:
    get:
      description: Returns a list of storage volume backups (URLs).
      operationId: storage_pool_volumes_type_backups_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/storage-pools/local/volumes/custom/foo/backups/backup0",
                    "/1.0/storage-pools/local/volumes/custom/foo/backups/backup1"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volume backups
      tags:
      - storage
    post:
      consumes:
      - application/json
      description: Creates a new storage volume backup.
      operationId: storage_pool_volumes_type_backups_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage volume backup
        in: body
        name: volume
        required: true
        schema:
          $ref: '#/definitions/StoragePoolVolumeBackupsPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Create a storage volume backup
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}/{volume}/backups/{backup}:
    delete:
      consumes:
      - application/json
      description: Deletes a new storage volume backup.
      operationId: storage_pool_volumes_type_backup_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete a storage volume backup
      tags:
      - storage
    get:
      description: Gets a specific storage volume backup.
      operationId: storage_pool_volumes_type_backup_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Storage volume backup
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/StoragePoolVolumeBackup'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volume backup
      tags:
      - storage
    post:
      consumes:
      - application/json
      description: Renames a storage volume backup.
      operationId: storage_pool_volumes_type_backup_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage volume backup
        in: body
        name: volume rename
        required: true
        schema:
          $ref: '#/definitions/StorageVolumeSnapshotPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename a storage volume backup
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}/{volume}/backups/{backup}/export:
    get:
      description: Download the raw backup file from the server.
      operationId: storage_pool_volumes_type_backup_export_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/octet-stream
      responses:
        "200":
          description: Raw backup data
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the raw backup file
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}/{volume}/backups?recursion=1:
    get:
      description: Returns a list of storage volume backups (structs).
      operationId: storage_pool_volumes_type_backups_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of storage volume backups
                items:
                  $ref: '#/definitions/StoragePoolVolumeBackup'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volume backups
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}/{volume}/snapshots:
    get:
      description: Returns a list of storage volume snapshots (URLs).
      operationId: storage_pool_volumes_type_snapshots_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/storage-pools/local/volumes/custom/foo/snapshots/snap0",
                    "/1.0/storage-pools/local/volumes/custom/foo/snapshots/snap1"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volume snapshots
      tags:
      - storage
    post:
      consumes:
      - application/json
      description: Creates a new storage volume snapshot.
      operationId: storage_pool_volumes_type_snapshots_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage volume snapshot
        in: body
        name: volume
        required: true
        schema:
          $ref: '#/definitions/StorageVolumeSnapshotsPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Create a storage volume snapshot
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}/{volume}/snapshots/{snapshot}:
    delete:
      consumes:
      - application/json
      description: Deletes a new storage volume snapshot.
      operationId: storage_pool_volumes_type_snapshot_delete
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete a storage volume snapshot
      tags:
      - storage
    get:
      description: Gets a specific storage volume snapshot.
      operationId: storage_pool_volumes_type_snapshot_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Storage volume snapshot
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/StorageVolumeSnapshot'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volume snapshot
      tags:
      - storage
    patch:
      consumes:
      - application/json
      description: Updates a subset of the storage volume snapshot configuration.
      operationId: storage_pool_volumes_type_snapshot_patch
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage volume snapshot configuration
        in: body
        name: storage volume snapshot
        required: true
        schema:
          $ref: '#/definitions/StorageVolumeSnapshotPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the storage volume snapshot
      tags:
      - storage
    post:
      consumes:
      - application/json
      description: Renames a storage volume snapshot.
      operationId: storage_pool_volumes_type_snapshot_post
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage volume snapshot
        in: body
        name: volume rename
        required: true
        schema:
          $ref: '#/definitions/StorageVolumeSnapshotPost'
      produces:
      - application/json
      responses:
        "202":
          $ref: '#/responses/Operation'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Rename a storage volume snapshot
      tags:
      - storage
    put:
      consumes:
      - application/json
      description: Updates the entire storage volume snapshot configuration.
      operationId: storage_pool_volumes_type_snapshot_put
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Storage volume snapshot configuration
        in: body
        name: storage volume snapshot
        required: true
        schema:
          $ref: '#/definitions/StorageVolumeSnapshotPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "412":
          $ref: '#/responses/PreconditionFailed'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the storage volume snapshot
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}/{volume}/snapshots?recursion=1:
    get:
      description: Returns a list of storage volume snapshots (structs).
      operationId: storage_pool_volumes_type_snapshots_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of storage volume snapshots
                items:
                  $ref: '#/definitions/StorageVolumeSnapshot'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volume snapshots
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}/{volume}/state:
    get:
      description: Gets a specific storage volume state (usage data).
      operationId: storage_pool_volume_type_state_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Storage pool
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/StorageVolumeState'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volume state
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes/{type}?recursion=1:
    get:
      description: Returns a list of storage volumes (structs) (type specific endpoint).
      operationId: storage_pool_volumes_type_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of storage volumes
                items:
                  $ref: '#/definitions/StorageVolume'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volumes
      tags:
      - storage
  /1.0/storage-pools/{name}/volumes?recursion=1:
    get:
      description: Returns a list of storage volumes (structs).
      operationId: storage_pool_volumes_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      - description: Cluster member name
        example: lxd01
        in: query
        name: target
        type: string
      - description: Collection filter
        example: default
        in: query
        name: filter
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of storage volumes
                items:
                  $ref: '#/definitions/StorageVolume'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage volumes
      tags:
      - storage
  /1.0/storage-pools?recursion=1:
    get:
      description: Returns a list of storage pools (structs).
      operationId: storage_pools_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of storage pools
                items:
                  $ref: '#/definitions/StoragePool'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the storage pools
      tags:
      - storage
  /1.0/warnings:
    get:
      description: Returns a list of warnings.
      operationId: warnings_get
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: Sync response
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of endpoints
                example: |-
                  [
                    "/1.0/warnings/39c61a48-cc17-40ae-8248-4f7b4cadedf4",
                    "/1.0/warnings/951779a5-2820-4d96-b01e-88fe820e5310"
                  ]
                items:
                  type: string
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "500":
          $ref: '#/responses/InternalServerError'
      summary: List the warnings
      tags:
      - warnings
  /1.0/warnings/{uuid}:
    delete:
      description: Removes the warning.
      operationId: warning_delete
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Delete the warning
      tags:
      - warnings
    get:
      description: Gets a specific warning.
      operationId: warning_get
      produces:
      - application/json
      responses:
        "200":
          description: Warning
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/Warning'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "404":
          $ref: '#/responses/NotFound'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the warning
      tags:
      - warnings
    patch:
      consumes:
      - application/json
      description: Updates a subset of the warning status.
      operationId: warning_patch
      parameters:
      - description: Warning status
        in: body
        name: warning
        required: true
        schema:
          $ref: '#/definitions/WarningPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Partially update the warning
      tags:
      - warnings
    put:
      consumes:
      - application/json
      description: Updates the warning status.
      operationId: warning_put
      parameters:
      - description: Warning status
        in: body
        name: warning
        required: true
        schema:
          $ref: '#/definitions/WarningPut'
      produces:
      - application/json
      responses:
        "200":
          $ref: '#/responses/EmptySyncResponse'
        "400":
          $ref: '#/responses/BadRequest'
        "403":
          $ref: '#/responses/Forbidden'
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Update the warning
      tags:
      - warnings
  /1.0/warnings?recursion=1:
    get:
      description: Returns a list of warnings (structs).
      operationId: warnings_get_recursion1
      parameters:
      - description: Project name
        example: default
        in: query
        name: project
        type: string
      produces:
      - application/json
      responses:
        "200":
          description: API endpoints
          schema:
            description: Sync response
            properties:
              metadata:
                description: List of warnings
                items:
                  $ref: '#/definitions/Warning'
                type: array
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the warnings
      tags:
      - warnings
  /1.0?public:
    get:
      description: |-
        Shows a small subset of the server environment and configuration
        which is required by untrusted clients to reach a server.

        The `?public` part of the URL isn't required, it's simply used to
        separate the two behaviors of this endpoint.
      operationId: server_get_untrusted
      produces:
      - application/json
      responses:
        "200":
          description: Server environment and configuration
          schema:
            description: Sync response
            properties:
              metadata:
                $ref: '#/definitions/ServerUntrusted'
              status:
                description: Status description
                example: Success
                type: string
              status_code:
                description: Status code
                example: 200
                type: integer
              type:
                description: Response type
                example: sync
                type: string
            type: object
        "500":
          $ref: '#/responses/InternalServerError'
      summary: Get the server environment
      tags:
      - server
responses:
  BadRequest:
    description: Bad Request
    schema:
      properties:
        code:
          example: 400
          format: int64
          type: integer
          x-go-name: Code
        error:
          example: bad request
          type: string
          x-go-name: Error
        type:
          example: error
          type: string
          x-go-name: Type
      type: object
  EmptySyncResponse:
    description: Empty sync response
    schema:
      properties:
        status:
          example: Success
          type: string
          x-go-name: Status
        status_code:
          example: 200
          format: int64
          type: integer
          x-go-name: StatusCode
        type:
          example: sync
          type: string
          x-go-name: Type
      type: object
  Forbidden:
    description: Forbidden
    schema:
      properties:
        code:
          example: 403
          format: int64
          type: integer
          x-go-name: Code
        error:
          example: not authorized
          type: string
          x-go-name: Error
        type:
          example: error
          type: string
          x-go-name: Type
      type: object
  InternalServerError:
    description: Internal Server Error
    schema:
      properties:
        code:
          example: 500
          format: int64
          type: integer
          x-go-name: Code
        error:
          example: internal server error
          type: string
          x-go-name: Error
        type:
          example: error
          type: string
          x-go-name: Type
      type: object
  NotFound:
    description: Not found
    schema:
      properties:
        code:
          example: 404
          format: int64
          type: integer
          x-go-name: Code
        error:
          example: not found
          type: string
          x-go-name: Error
        type:
          example: error
          type: string
          x-go-name: Type
      type: object
  Operation:
    description: Operation
    schema:
      properties:
        metadata:
          $ref: '#/definitions/Operation'
        operation:
          example: /1.0/operations/66e83638-9dd7-4a26-aef2-5462814869a1
          type: string
          x-go-name: Operation
        status:
          example: Operation created
          type: string
          x-go-name: Status
        status_code:
          example: 100
          format: int64
          type: integer
          x-go-name: StatusCode
        type:
          example: async
          type: string
          x-go-name: Type
      type: object
  PreconditionFailed:
    description: Precondition Failed
    schema:
      properties:
        code:
          example: 412
          format: int64
          type: integer
          x-go-name: Code
        error:
          example: precondition failed
          type: string
          x-go-name: Error
        type:
          example: error
          type: string
          x-go-name: Type
      type: object
swagger: "2.0"
