# NAME

Net::Async::WebService::lxd - REST client for lxd Linux containers

# SYNOPSIS

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

# INTERFACE

## Constructor

@@@@
@@@@ environemtn endpoint, project ...

\# automatically generated from the Swagger spec at https://raw.githubusercontent.com/lxc/lxd/master/doc/rest-api.yaml

## Certificates

- **add\_certificate**

    Adds a certificate to the trust store.
    In this mode, the \`password\` property is always ignored.

- **add\_certificate\_untrusted**

    Adds a certificate to the trust store as an untrusted user.
    In this mode, the \`password\` property must be set to the correct value.

    The \`certificate\` field can be omitted in which case the TLS client
    certificate in use for the connection will be retrieved and added to the
    trust store.

    The \`?public\` part of the URL isn't required, it's simply used to
    separate the two behaviors of this endpoint.

- **certificate**

    Gets a specific certificate entry from the trust store.

    Updates the entire certificate configuration.

    - `fingerprint`: string (inside URL)

- **certificates**

    Returns a list of trusted certificates (URLs).

- **certificates\_recursion1**

    Returns a list of trusted certificates (structs).

- **delete\_certificate**

    Removes the certificate from the trust store.

    - `fingerprint`: string (inside URL)

- **modify\_certificate**

    Updates a subset of the certificate configuration.

    - `fingerprint`: string (inside URL)

## Cluster

- **add\_cluster\_member**

    Requests a join token to add a cluster member.

- **cluster**

    Gets the current cluster configuration.

    Updates the entire cluster configuration.

- **cluster\_member**

    Gets a specific cluster member.

    Updates the entire cluster member configuration.

    - `name`: string (inside URL)

- **cluster\_members**

    Returns a list of cluster members (URLs).

- **cluster\_members\_recursion1**

    Returns a list of cluster members (structs).

- **clustering\_update\_cert**

    Replaces existing cluster certificate and reloads LXD on each cluster
    member.

- **create\_cluster\_group**

    Creates a new cluster group.

- **delete\_cluster\_member**

    Removes the member from the cluster.

    - `name`: string (inside URL)

- **modify\_cluster\_member**

    Updates a subset of the cluster member configuration.

    - `name`: string (inside URL)

- **rename\_cluster\_member**

    Renames an existing cluster member.

    - `name`: string (inside URL)

- **restore\_cluster\_member\_state**

    Evacuates or restores a cluster member.

    - `name`: string (inside URL)

## Cluster Groups

- **cluster\_group**

    Gets a specific cluster group.

    Updates the entire cluster group configuration.

    - `name`: string (inside URL)

- **cluster\_groups**

    Returns a list of cluster groups (URLs).

- **cluster\_groups\_recursion1**

    Returns a list of cluster groups (structs).

- **delete\_cluster\_group**

    Removes the cluster group.

    - `name`: string (inside URL)

- **modify\_cluster\_group**

    Updates the cluster group configuration.

    - `name`: string (inside URL)

- **rename\_cluster\_group**

    Renames an existing cluster group.

    - `name`: string (inside URL)

## Images

- **create\_image**

    Adds a new image to the image store.

    - `project`: string, optional

- **create\_images\_alias**

    Creates a new image alias.

    - `project`: string, optional

- **delete\_image**

    Removes the image from the image store.

    - `project`: string, optional
    - `fingerprint`: string (inside URL)

- **delete\_image\_alias**

    Deletes a specific image alias.

    - `project`: string, optional
    - `name`: string (inside URL)

- **image**

    Gets a specific image.

    Updates the entire image definition.

    - `project`: string, optional
    - `fingerprint`: string (inside URL)

- **image\_alias**

    Gets a specific image alias.

    Updates the entire image alias configuration.

    - `project`: string, optional
    - `name`: string (inside URL)

- **image\_alias\_untrusted**

    Gets a specific public image alias.
    This untrusted endpoint only works for aliases pointing to public images.

    - `project`: string, optional
    - `name`: string (inside URL)

- **image\_export**

    Download the raw image file(s) from the server.
    If the image is in split format, a multipart http transfer occurs.

    - `project`: string, optional
    - `fingerprint`: string (inside URL)

- **image\_export\_untrusted**

    Download the raw image file(s) of a public image from the server.
    If the image is in split format, a multipart http transfer occurs.

    - `project`: string, optional
    - `secret`: string, optional
    - `fingerprint`: string (inside URL)

- **image\_untrusted**

    Gets a specific public image.

    - `project`: string, optional
    - `secret`: string, optional
    - `fingerprint`: string (inside URL)

- **images**

    Returns a list of images (URLs).

    - `filter`: string, optional
    - `project`: string, optional

- **images\_aliases**

    Returns a list of image aliases (URLs).

    - `project`: string, optional

- **images\_aliases\_recursion1**

    Returns a list of image aliases (structs).

    - `project`: string, optional

- **images\_recursion1**

    Returns a list of images (structs).

    - `filter`: string, optional
    - `project`: string, optional

- **images\_recursion1\_untrusted**

    Returns a list of publicly available images (structs).

    - `filter`: string, optional
    - `project`: string, optional

- **images\_untrusted**

    Returns a list of publicly available images (URLs).

    - `filter`: string, optional
    - `project`: string, optional

- **initiate\_image\_upload**

    This generates a background operation including a secret one time key
    in its metadata which can be used to fetch this image from an untrusted
    client.

    - `project`: string, optional
    - `fingerprint`: string (inside URL)

- **modify\_image**

    Updates a subset of the image definition.

    - `project`: string, optional
    - `fingerprint`: string (inside URL)

- **modify\_images\_alias**

    Updates a subset of the image alias configuration.

    - `project`: string, optional
    - `name`: string (inside URL)

- **push\_image\_untrusted**

    Pushes the data to the target image server.
    This is meant for LXD to LXD communication where a new image entry is
    prepared on the target server and the source server is provided that URL
    and a secret token to push the image content over.

    - `project`: string, optional

- **push\_images\_export**

    Gets LXD to connect to a remote server and push the image to it.

    - `project`: string, optional
    - `fingerprint`: string (inside URL)

- **rename\_images\_alias**

    Renames an existing image alias.

    - `project`: string, optional
    - `name`: string (inside URL)

- **update\_images\_refresh**

    This causes LXD to check the image source server for an updated
    version of the image and if available to refresh the local copy with the
    new version.

    - `project`: string, optional
    - `fingerprint`: string (inside URL)

## Instances

- **connect\_instance\_console**

    Connects to the console of an instance.

    The returned operation metadata will contain two websockets, one for data and one for control.

    - `project`: string, optional
    - `name`: string (inside URL)

- **create\_instance**

    Creates a new instance on LXD.
    Depending on the source, this can create an instance from an existing
    local image, remote image, existing local instance or snapshot, remote
    migration stream or backup file.

    - `project`: string, optional
    - `target`: string, optional

- **create\_instance\_backup**

    Creates a new backup.

    - `project`: string, optional
    - `name`: string (inside URL)

- **create\_instance\_file**

    Creates a new file in the instance.

    - `path`: string, optional
    - `project`: string, optional
    - `name`: string (inside URL)

- **create\_instance\_metadata\_template**

    Creates a new image template file for the instance.

    - `path`: string, optional
    - `project`: string, optional
    - `name`: string (inside URL)

- **create\_instance\_snapshot**

    Creates a new snapshot.

    - `project`: string, optional
    - `name`: string (inside URL)

- **delete\_instance**

    Deletes a specific instance.

    This also deletes anything owned by the instance such as snapshots and backups.

    - `project`: string, optional
    - `name`: string (inside URL)

- **delete\_instance\_backup**

    Deletes the instance backup.

    - `project`: string, optional
    - `name`: string (inside URL)
    - `backup`: string (inside URL)

- **delete\_instance\_console**

    Clears the console log buffer.

    - `project`: string, optional
    - `name`: string (inside URL)

- **delete\_instance\_files**

    Removes the file.

    - `path`: string, optional
    - `project`: string, optional
    - `name`: string (inside URL)

- **delete\_instance\_log**

    Removes the log file.

    - `project`: string, optional
    - `name`: string (inside URL)
    - `filename`: string (inside URL)

- **delete\_instance\_metadata\_templates**

    Removes the template file.

    - `path`: string, optional
    - `project`: string, optional
    - `name`: string (inside URL)

- **delete\_instance\_snapshot**

    Deletes the instance snapshot.

    - `project`: string, optional
    - `name`: string (inside URL)
    - `snapshot`: string (inside URL)

- **execute\_in\_instance**

    Executes a command inside an instance.

    The returned operation metadata will contain either 2 or 4 websockets.
    In non-interactive mode, you'll get one websocket for each of stdin, stdout and stderr.
    In interactive mode, a single bi-directional websocket is used for stdin and stdout/stderr.

    An additional "control" socket is always added on top which can be used for out of band communication with LXD.
    This allows sending signals and window sizing information through.

    - `project`: string, optional
    - `name`: string (inside URL)

- **instance**

    Gets a specific instance (basic struct).

    Updates the instance configuration or trigger a snapshot restore.

    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_backup**

    Gets a specific instance backup.

    - `project`: string, optional
    - `name`: string (inside URL)
    - `backup`: string (inside URL)

- **instance\_backup\_export**

    Download the raw backup file(s) from the server.

    - `project`: string, optional
    - `name`: string (inside URL)
    - `backup`: string (inside URL)

- **instance\_backups**

    Returns a list of instance backups (URLs).

    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_backups\_recursion1**

    Returns a list of instance backups (structs).

    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_console**

    Gets the console log for the instance.

    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_files**

    Gets the file content. If it's a directory, a json list of files will be returned instead.

    - `path`: string, optional
    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_log**

    Gets the log file.

    - `project`: string, optional
    - `name`: string (inside URL)
    - `filename`: string (inside URL)

- **instance\_logs**

    Returns a list of log files (URLs).

    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_metadata**

    Gets the image metadata for the instance.

    Updates the instance image metadata.

    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_metadata\_templates**

    If no path specified, returns a list of template file names.
    If a path is specified, returns the file content.

    - `path`: string, optional
    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_recursion1**

    Gets a specific instance (full struct).

    recursion=1 also includes information about state, snapshots and backups.

    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_snapshot**

    Gets a specific instance snapshot.

    Updates the snapshot config.

    - `project`: string, optional
    - `name`: string (inside URL)
    - `snapshot`: string (inside URL)

- **instance\_snapshots**

    Returns a list of instance snapshots (URLs).

    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_snapshots\_recursion1**

    Returns a list of instance snapshots (structs).

    - `project`: string, optional
    - `name`: string (inside URL)

- **instance\_state**

    Gets the runtime state of the instance.

    This is a reasonably expensive call as it causes code to be run
    inside of the instance to retrieve the resource usage and network
    information.

    Changes the running state of the instance.

    - `project`: string, optional
    - `name`: string (inside URL)

- **instances**

    Returns a list of instances (URLs).

    Changes the running state of all instances.

    - `all-projects`: boolean, optional
    - `filter`: string, optional
    - `project`: string, optional

- **instances\_recursion1**

    Returns a list of instances (basic structs).

    - `all-projects`: boolean, optional
    - `filter`: string, optional
    - `project`: string, optional

- **instances\_recursion2**

    Returns a list of instances (full structs).

    The main difference between recursion=1 and recursion=2 is that the
    latter also includes state and snapshot information allowing for a
    single API call to return everything needed by most clients.

    - `all-projects`: boolean, optional
    - `filter`: string, optional
    - `project`: string, optional

- **migrate\_instance**

    Renames, moves an instance between pools or migrates an instance to another server.

    The returned operation metadata will vary based on what's requested.
    For rename or move within the same server, this is a simple background operation with progress data.
    For migration, in the push case, this will similarly be a background
    operation with progress data, for the pull case, it will be a websocket
    operation with a number of secrets to be passed to the target server.

    - `project`: string, optional
    - `name`: string (inside URL)

- **migrate\_instance\_snapshot**

    Renames or migrates an instance snapshot to another server.

    The returned operation metadata will vary based on what's requested.
    For rename or move within the same server, this is a simple background operation with progress data.
    For migration, in the push case, this will similarly be a background
    operation with progress data, for the pull case, it will be a websocket
    operation with a number of secrets to be passed to the target server.

    - `project`: string, optional
    - `name`: string (inside URL)
    - `snapshot`: string (inside URL)

- **modify\_instance**

    Updates a subset of the instance configuration

    - `project`: string, optional
    - `name`: string (inside URL)

- **modify\_instance\_metadata**

    Updates a subset of the instance image metadata.

    - `project`: string, optional
    - `name`: string (inside URL)

- **modify\_instance\_snapshot**

    Updates a subset of the snapshot config.

    - `project`: string, optional
    - `name`: string (inside URL)
    - `snapshot`: string (inside URL)

- **rename\_instance\_backup**

    Renames an instance backup.

    - `project`: string, optional
    - `name`: string (inside URL)
    - `backup`: string (inside URL)

## Metrics

- **metrics**

    Gets metrics of instances.

    - `project`: string, optional

## Network ACLs

- **create\_network\_acl**

    Creates a new network ACL.

    - `project`: string, optional

- **delete\_network\_acl**

    Removes the network ACL.

    - `project`: string, optional
    - `name`: string (inside URL)

- **modify\_network\_acl**

    Updates a subset of the network ACL configuration.

    - `project`: string, optional
    - `name`: string (inside URL)

- **network\_acl**

    Gets a specific network ACL.

    Updates the entire network ACL configuration.

    - `project`: string, optional
    - `name`: string (inside URL)

- **network\_acl\_log**

    Gets a specific network ACL log entries.

    - `project`: string, optional
    - `name`: string (inside URL)

- **network\_acls**

    Returns a list of network ACLs (URLs).

    - `project`: string, optional

- **network\_acls\_recursion1**

    Returns a list of network ACLs (structs).

    - `project`: string, optional

- **rename\_network\_acl**

    Renames an existing network ACL.

    - `project`: string, optional
    - `name`: string (inside URL)

## Network Forwards

- **create\_network\_forward**

    Creates a new network address forward.

    - `project`: string, optional
    - `networkName`: string (inside URL)

- **delete\_network\_forward**

    Removes the network address forward.

    - `project`: string, optional
    - `networkName`: string (inside URL)
    - `listenAddress`: string (inside URL)

- **modify\_network\_forward**

    Updates a subset of the network address forward configuration.

    - `project`: string, optional
    - `networkName`: string (inside URL)
    - `listenAddress`: string (inside URL)

- **network\_forward**

    Gets a specific network address forward.

    Updates the entire network address forward configuration.

    - `project`: string, optional
    - `networkName`: string (inside URL)
    - `listenAddress`: string (inside URL)

- **network\_forward\_recursion1**

    Returns a list of network address forwards (structs).

    - `project`: string, optional
    - `networkName`: string (inside URL)

- **network\_forwards**

    Returns a list of network address forwards (URLs).

    - `project`: string, optional
    - `networkName`: string (inside URL)

## Network Peers

- **create\_network\_peer**

    Initiates/creates a new network peering.

    - `project`: string, optional
    - `networkName`: string (inside URL)

- **delete\_network\_peer**

    Removes the network peering.

    - `project`: string, optional
    - `networkName`: string (inside URL)
    - `peerName`: string (inside URL)

- **modify\_network\_peer**

    Updates a subset of the network peering configuration.

    - `project`: string, optional
    - `networkName`: string (inside URL)
    - `peerName`: string (inside URL)

- **network\_peer**

    Gets a specific network peering.

    Updates the entire network peering configuration.

    - `project`: string, optional
    - `networkName`: string (inside URL)
    - `peerName`: string (inside URL)

- **network\_peer\_recursion1**

    Returns a list of network peers (structs).

    - `project`: string, optional
    - `networkName`: string (inside URL)

- **network\_peers**

    Returns a list of network peers (URLs).

    - `project`: string, optional
    - `networkName`: string (inside URL)

## Network Zones

- **create\_network\_zone**

    Creates a new network zone.

    - `project`: string, optional

- **create\_network\_zone\_record**

    Creates a new network zone record.

    - `project`: string, optional
    - `zone`: string (inside URL)

- **delete\_network\_zone**

    Removes the network zone.

    - `project`: string, optional
    - `name`: string (inside URL)

- **delete\_network\_zone\_record**

    Removes the network zone record.

    - `project`: string, optional
    - `zone`: string (inside URL)
    - `name`: string (inside URL)

- **modify\_network\_zone**

    Updates a subset of the network zone configuration.

    - `project`: string, optional
    - `name`: string (inside URL)

- **modify\_network\_zone\_record**

    Updates a subset of the network zone record configuration.

    - `project`: string, optional
    - `zone`: string (inside URL)
    - `name`: string (inside URL)

- **network\_zone**

    Gets a specific network zone.

    Updates the entire network zone configuration.

    - `project`: string, optional
    - `name`: string (inside URL)

- **network\_zone\_record**

    Gets a specific network zone record.

    Updates the entire network zone record configuration.

    - `project`: string, optional
    - `zone`: string (inside URL)
    - `name`: string (inside URL)

- **network\_zone\_records**

    Returns a list of network zone records (URLs).

    - `project`: string, optional
    - `zone`: string (inside URL)

- **network\_zone\_records\_recursion1**

    Returns a list of network zone records (structs).

    - `project`: string, optional
    - `zone`: string (inside URL)

- **network\_zones**

    Returns a list of network zones (URLs).

    - `project`: string, optional

- **network\_zones\_recursion1**

    Returns a list of network zones (structs).

    - `project`: string, optional

## Networks

- **create\_network**

    Creates a new network.
    When clustered, most network types require individual POST for each cluster member prior to a global POST.

    - `project`: string, optional
    - `target`: string, optional

- **delete\_network**

    Removes the network.

    - `project`: string, optional
    - `name`: string (inside URL)

- **modify\_network**

    Updates a subset of the network configuration.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)

- **network**

    Gets a specific network.

    Updates the entire network configuration.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)

- **networks**

    Returns a list of networks (URLs).

    - `project`: string, optional

- **networks\_leases**

    Returns a list of DHCP leases for the network.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)

- **networks\_recursion1**

    Returns a list of networks (structs).

    - `project`: string, optional

- **networks\_state**

    Returns the current network state information.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)

- **rename\_network**

    Renames an existing network.

    - `project`: string, optional
    - `name`: string (inside URL)

## Operations

- **delete\_operation**

    Cancels the operation if supported.

    - `id`: string (inside URL)

- **operation**

    Gets the operation state.

    - `id`: string (inside URL)

- **operation\_wait**

    Waits for the operation to reach a final state (or timeout) and retrieve its final state.

    - `timeout`: integer, optional
    - `id`: string (inside URL)

- **operation\_wait\_untrusted**

    Waits for the operation to reach a final state (or timeout) and retrieve its final state.

    When accessed by an untrusted user, the secret token must be provided.

    - `secret`: string, optional
    - `timeout`: integer, optional
    - `id`: string (inside URL)

- **operation\_websocket**

    Connects to an associated websocket stream for the operation.
    This should almost never be done directly by a client, instead it's
    meant for LXD to LXD communication with the client only relaying the
    connection information to the servers.

    - `secret`: string, optional
    - `id`: string (inside URL)

- **operation\_websocket\_untrusted**

    Connects to an associated websocket stream for the operation.
    This should almost never be done directly by a client, instead it's
    meant for LXD to LXD communication with the client only relaying the
    connection information to the servers.

    The untrusted endpoint is used by the target server to connect to the source server.
    Authentication is performed through the secret token.

    - `secret`: string, optional
    - `id`: string (inside URL)

- **operations**

    Returns a dict of operation type to operation list (URLs).

- **operations\_recursion1**

    Returns a list of operations (structs).

    - `project`: string, optional

## Profiles

- **create\_profile**

    Creates a new profile.

    - `project`: string, optional

- **delete\_profile**

    Removes the profile.

    - `project`: string, optional
    - `name`: string (inside URL)

- **modify\_profile**

    Updates a subset of the profile configuration.

    - `project`: string, optional
    - `name`: string (inside URL)

- **profile**

    Gets a specific profile.

    Updates the entire profile configuration.

    - `project`: string, optional
    - `name`: string (inside URL)

- **profiles**

    Returns a list of profiles (URLs).

    - `project`: string, optional

- **profiles\_recursion1**

    Returns a list of profiles (structs).

    - `project`: string, optional

- **rename\_profile**

    Renames an existing profile.

    - `project`: string, optional
    - `name`: string (inside URL)

## Projects

- **create\_project**

    Creates a new project.

- **delete\_project**

    Removes the project.

    - `name`: string (inside URL)

- **modify\_project**

    Updates a subset of the project configuration.

    - `name`: string (inside URL)

- **project**

    Gets a specific project.

    Updates the entire project configuration.

    - `name`: string (inside URL)

- **project\_state**

    Gets a specific project resource consumption information.

    - `name`: string (inside URL)

- **projects**

    Returns a list of projects (URLs).

- **projects\_recursion1**

    Returns a list of projects (structs).

- **rename\_project**

    Renames an existing project.

    - `name`: string (inside URL)

## Server

- **api**

    Returns a list of supported API versions (URLs).

    Internal API endpoints are not reported as those aren't versioned and
    should only be used by LXD itself.

- **events**

    Connects to the event API using websocket.

    - `project`: string, optional
    - `type`: string, optional

- **modify\_server**

    Updates a subset of the server configuration.

    - `target`: string, optional

- **resources**

    Gets the hardware information profile of the LXD server.

    - `target`: string, optional

- **server**

    Shows the full server environment and configuration.

    Updates the entire server configuration.

    - `project`: string, optional
    - `target`: string, optional

- **server\_untrusted**

    Shows a small subset of the server environment and configuration
    which is required by untrusted clients to reach a server.

    The \`?public\` part of the URL isn't required, it's simply used to
    separate the two behaviors of this endpoint.

## Storage

- **create\_storage\_pool**

    Creates a new storage pool.
    When clustered, storage pools require individual POST for each cluster member prior to a global POST.

    - `project`: string, optional
    - `target`: string, optional

- **create\_storage\_pool\_volume**

    Creates a new storage volume.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)

- **create\_storage\_pool\_volumes\_backup**

    Creates a new storage volume backup.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **create\_storage\_pool\_volumes\_snapshot**

    Creates a new storage volume snapshot.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **create\_storage\_pool\_volumes\_type**

    Creates a new storage volume (type specific endpoint).

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)

- **delete\_storage\_pool\_volume\_type**

    Removes the storage volume.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **delete\_storage\_pool\_volumes\_type\_backup**

    Deletes a new storage volume backup.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)
    - `backup`: string (inside URL)

- **delete\_storage\_pool\_volumes\_type\_snapshot**

    Deletes a new storage volume snapshot.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)
    - `snapshot`: string (inside URL)

- **delete\_storage\_pools**

    Removes the storage pool.

    - `project`: string, optional
    - `name`: string (inside URL)

- **migrate\_storage\_pool\_volume\_type**

    Renames, moves a storage volume between pools or migrates an instance to another server.

    The returned operation metadata will vary based on what's requested.
    For rename or move within the same server, this is a simple background operation with progress data.
    For migration, in the push case, this will similarly be a background
    operation with progress data, for the pull case, it will be a websocket
    operation with a number of secrets to be passed to the target server.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **modify\_storage\_pool**

    Updates a subset of the storage pool configuration.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)

- **modify\_storage\_pool\_volume\_type**

    Updates a subset of the storage volume configuration.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **modify\_storage\_pool\_volumes\_type\_snapshot**

    Updates a subset of the storage volume snapshot configuration.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)
    - `snapshot`: string (inside URL)

- **rename\_storage\_pool\_volumes\_type\_backup**

    Renames a storage volume backup.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)
    - `backup`: string (inside URL)

- **rename\_storage\_pool\_volumes\_type\_snapshot**

    Renames a storage volume snapshot.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)
    - `snapshot`: string (inside URL)

- **storage\_pool**

    Gets a specific storage pool.

    Updates the entire storage pool configuration.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)

- **storage\_pool\_resources**

    Gets the usage information for the storage pool.

    - `target`: string, optional
    - `name`: string (inside URL)

- **storage\_pool\_volume\_type**

    Gets a specific storage volume.

    Updates the entire storage volume configuration.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **storage\_pool\_volume\_type\_state**

    Gets a specific storage volume state (usage data).

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **storage\_pool\_volumes**

    Returns a list of storage volumes (URLs).

    - `filter`: string, optional
    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)

- **storage\_pool\_volumes\_recursion1**

    Returns a list of storage volumes (structs).

    - `filter`: string, optional
    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)

- **storage\_pool\_volumes\_type**

    Returns a list of storage volumes (URLs) (type specific endpoint).

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)

- **storage\_pool\_volumes\_type\_backup**

    Gets a specific storage volume backup.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)
    - `backup`: string (inside URL)

- **storage\_pool\_volumes\_type\_backup\_export**

    Download the raw backup file from the server.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)
    - `backup`: string (inside URL)

- **storage\_pool\_volumes\_type\_backups**

    Returns a list of storage volume backups (URLs).

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **storage\_pool\_volumes\_type\_backups\_recursion1**

    Returns a list of storage volume backups (structs).

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **storage\_pool\_volumes\_type\_recursion1**

    Returns a list of storage volumes (structs) (type specific endpoint).

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)

- **storage\_pool\_volumes\_type\_snapshot**

    Gets a specific storage volume snapshot.

    Updates the entire storage volume snapshot configuration.

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)
    - `snapshot`: string (inside URL)

- **storage\_pool\_volumes\_type\_snapshots**

    Returns a list of storage volume snapshots (URLs).

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **storage\_pool\_volumes\_type\_snapshots\_recursion1**

    Returns a list of storage volume snapshots (structs).

    - `project`: string, optional
    - `target`: string, optional
    - `name`: string (inside URL)
    - `type`: string (inside URL)
    - `volume`: string (inside URL)

- **storage\_pools**

    Returns a list of storage pools (URLs).

    - `project`: string, optional

- **storage\_pools\_recursion1**

    Returns a list of storage pools (structs).

    - `project`: string, optional

## Warnings

- **delete\_warning**

    Removes the warning.

    - `uuid`: string (inside URL)

- **modify\_warning**

    Updates a subset of the warning status.

    - `uuid`: string (inside URL)

- **warning**

    Gets a specific warning.

    Updates the warning status.

    - `uuid`: string (inside URL)

- **warnings**

    Returns a list of warnings.

    - `project`: string, optional

- **warnings\_recursion1**

    Returns a list of warnings (structs).

    - `project`: string, optional

# AUTHOR

Robert Barta, `<rho at devc.at>`

# BUGS

Please report any bugs or feature requests to `bug-net-async-webservice-lxd at rt.cpan.org`, or through
the web interface at [https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Async-WebService-lxd](https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-Async-WebService-lxd).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# LICENSE AND COPYRIGHT

Copyright 2022 Robert Barta.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

[http://www.perlfoundation.org/artistic\_license\_2\_0](http://www.perlfoundation.org/artistic_license_2_0)

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
