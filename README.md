# NAME

Net::Async::WebService::lxd - REST client for lxd Linux containers

# SYNOPSIS

@@@@

# INTERFACE

## Constructor

\# automatically generated from the Swagger spec at https://raw.githubusercontent.com/lxc/lxd/master/doc/rest-api.yaml

## Certificates

- **add\_certificate**

    Adds a certificate to the trust store.
    In this mode, the \`password\` property is always ignored. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/certificates/certificates\_post> \]

- **add\_certificate\_untrusted**

    Adds a certificate to the trust store as an untrusted user.
    In this mode, the \`password\` property must be set to the correct value.

    The \`certificate\` field can be omitted in which case the TLS client
    certificate in use for the connection will be retrieved and added to the
    trust store.

    The \`?public\` part of the URL isn't required, it's simply used to
    separate the two behaviors of this endpoint. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/certificates/certificates\_post\_untrusted> \]

- **certificate**

    Gets a specific certificate entry from the trust store. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/certificates/certificate\_get> \]

    Updates the entire certificate configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/certificates/certificate\_put> \]

- **certificates**

    Returns a list of trusted certificates (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/certificates/certificates\_get> \]

- **certificates\_recursion1**

    Returns a list of trusted certificates (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/certificates/certificates\_get\_recursion1> \]

- **delete\_certificate**

    Removes the certificate from the trust store. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/certificates/certificate\_delete> \]

- **modify\_certificate**

    Updates a subset of the certificate configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/certificates/certificate\_patch> \]

## Cluster

- **add\_cluster\_member**

    Requests a join token to add a cluster member. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_members\_post> \]

- **cluster**

    Gets the current cluster configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_get> \]

    Updates the entire cluster configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_put> \]

- **cluster\_member**

    Gets a specific cluster member. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_member\_get> \]

    Updates the entire cluster member configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_member\_put> \]

- **cluster\_members**

    Returns a list of cluster members (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_members\_get> \]

- **cluster\_members\_recursion1**

    Returns a list of cluster members (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_members\_get\_recursion1> \]

- **clustering\_update\_cert**

    Replaces existing cluster certificate and reloads LXD on each cluster
    member. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/clustering\_update\_cert> \]

- **create\_cluster\_group**

    Creates a new cluster group. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_groups\_post> \]

- **delete\_cluster\_member**

    Removes the member from the cluster. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_member\_delete> \]

- **modify\_cluster\_member**

    Updates a subset of the cluster member configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_member\_patch> \]

- **rename\_cluster\_member**

    Renames an existing cluster member. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_member\_post> \]

- **restore\_cluster\_member\_state**

    Evacuates or restores a cluster member. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster/cluster\_member\_state\_post> \]

## Cluster Groups

- **cluster\_group**

    Gets a specific cluster group. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster-groups/cluster\_group\_get> \]

    Updates the entire cluster group configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster-groups/cluster\_group\_put> \]

- **cluster\_groups**

    Returns a list of cluster groups (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster-groups/cluster\_groups\_get> \]

- **cluster\_groups\_recursion1**

    Returns a list of cluster groups (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster-groups/cluster\_groups\_get\_recursion1> \]

- **delete\_cluster\_group**

    Removes the cluster group. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster-groups/cluster\_group\_delete> \]

- **modify\_cluster\_group**

    Updates the cluster group configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster-groups/cluster\_group\_patch> \]

- **rename\_cluster\_group**

    Renames an existing cluster group. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/cluster-groups/cluster\_group\_post> \]

## Images

- **create\_image**

    Adds a new image to the image store. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_post> \]

    - `project`: string, optional

- **create\_images\_alias**

    Creates a new image alias. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_aliases\_post> \]

    - `project`: string, optional

- **delete\_image**

    Removes the image from the image store. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/image\_delete> \]

    - `project`: string, optional

- **delete\_image\_alias**

    Deletes a specific image alias. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/image\_alias\_delete> \]

    - `project`: string, optional

- **image**

    Gets a specific image. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/image\_get> \]

    Updates the entire image definition. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/image\_put> \]

    - `project`: string, optional

- **image\_alias**

    Gets a specific image alias. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/image\_alias\_get> \]

    Updates the entire image alias configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_aliases\_put> \]

    - `project`: string, optional

- **image\_alias\_untrusted**

    Gets a specific public image alias.
    This untrusted endpoint only works for aliases pointing to public images. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/image\_alias\_get\_untrusted> \]

    - `project`: string, optional

- **image\_export**

    Download the raw image file(s) from the server.
    If the image is in split format, a multipart http transfer occurs. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/image\_export\_get> \]

    - `project`: string, optional

- **image\_export\_untrusted**

    Download the raw image file(s) of a public image from the server.
    If the image is in split format, a multipart http transfer occurs. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/image\_export\_get\_untrusted> \]

    - `project`: string, optional
    - `secret`: string, optional

- **image\_untrusted**

    Gets a specific public image. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/image\_get\_untrusted> \]

    - `project`: string, optional
    - `secret`: string, optional

- **images**

    Returns a list of images (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_get> \]

    - `filter`: string, optional
    - `project`: string, optional

- **images\_aliases**

    Returns a list of image aliases (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_aliases\_get> \]

    - `project`: string, optional

- **images\_aliases\_recursion1**

    Returns a list of image aliases (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_aliases\_get\_recursion1> \]

    - `project`: string, optional

- **images\_recursion1**

    Returns a list of images (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_get\_recursion1> \]

    - `filter`: string, optional
    - `project`: string, optional

- **images\_recursion1\_untrusted**

    Returns a list of publicly available images (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_get\_recursion1\_untrusted> \]

    - `filter`: string, optional
    - `project`: string, optional

- **images\_untrusted**

    Returns a list of publicly available images (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_get\_untrusted> \]

    - `filter`: string, optional
    - `project`: string, optional

- **initiate\_image\_upload**

    This generates a background operation including a secret one time key
    in its metadata which can be used to fetch this image from an untrusted
    client. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_secret\_post> \]

    - `project`: string, optional

- **modify\_image**

    Updates a subset of the image definition. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/image\_patch> \]

    - `project`: string, optional

- **modify\_images\_alias**

    Updates a subset of the image alias configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_alias\_patch> \]

    - `project`: string, optional

- **push\_image\_untrusted**

    Pushes the data to the target image server.
    This is meant for LXD to LXD communication where a new image entry is
    prepared on the target server and the source server is provided that URL
    and a secret token to push the image content over. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_post\_untrusted> \]

    - `project`: string, optional

- **push\_images\_export**

    Gets LXD to connect to a remote server and push the image to it. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_export\_post> \]

    - `project`: string, optional

- **rename\_images\_alias**

    Renames an existing image alias. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_alias\_post> \]

    - `project`: string, optional

- **update\_images\_refresh**

    This causes LXD to check the image source server for an updated
    version of the image and if available to refresh the local copy with the
    new version. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/images/images\_refresh\_post> \]

    - `project`: string, optional

## Instances

- **connect\_instance\_console**

    Connects to the console of an instance.

    The returned operation metadata will contain two websockets, one for data and one for control. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_console\_post> \]

    - `project`: string, optional

- **create\_instance**

    Creates a new instance on LXD.
    Depending on the source, this can create an instance from an existing
    local image, remote image, existing local instance or snapshot, remote
    migration stream or backup file. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instances\_post> \]

    - `project`: string, optional
    - `target`: string, optional

- **create\_instance\_backup**

    Creates a new backup. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_backups\_post> \]

    - `project`: string, optional

- **create\_instance\_file**

    Creates a new file in the instance. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_files\_post> \]

    - `path`: string, optional
    - `project`: string, optional

- **create\_instance\_metadata\_template**

    Creates a new image template file for the instance. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_metadata\_templates\_post> \]

    - `path`: string, optional
    - `project`: string, optional

- **create\_instance\_snapshot**

    Creates a new snapshot. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_snapshots\_post> \]

    - `project`: string, optional

- **delete\_instance**

    Deletes a specific instance.

    This also deletes anything owned by the instance such as snapshots and backups. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_delete> \]

    - `project`: string, optional

- **delete\_instance\_backup**

    Deletes the instance backup. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_backup\_delete> \]

    - `project`: string, optional

- **delete\_instance\_console**

    Clears the console log buffer. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_console\_delete> \]

    - `project`: string, optional

- **delete\_instance\_files**

    Removes the file. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_files\_delete> \]

    - `path`: string, optional
    - `project`: string, optional

- **delete\_instance\_log**

    Removes the log file. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_log\_delete> \]

    - `project`: string, optional

- **delete\_instance\_metadata\_templates**

    Removes the template file. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_metadata\_templates\_delete> \]

    - `path`: string, optional
    - `project`: string, optional

- **delete\_instance\_snapshot**

    Deletes the instance snapshot. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_snapshot\_delete> \]

    - `project`: string, optional

- **execute\_in\_instance**

    Executes a command inside an instance.

    The returned operation metadata will contain either 2 or 4 websockets.
    In non-interactive mode, you'll get one websocket for each of stdin, stdout and stderr.
    In interactive mode, a single bi-directional websocket is used for stdin and stdout/stderr.

    An additional "control" socket is always added on top which can be used for out of band communication with LXD.
    This allows sending signals and window sizing information through. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_exec\_post> \]

    - `project`: string, optional

- **instance**

    Gets a specific instance (basic struct). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_get> \]

    Updates the instance configuration or trigger a snapshot restore. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_put> \]

    - `project`: string, optional

- **instance\_backup**

    Gets a specific instance backup. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_backup\_get> \]

    - `project`: string, optional

- **instance\_backup\_export**

    Download the raw backup file(s) from the server. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_backup\_export> \]

    - `project`: string, optional

- **instance\_backups**

    Returns a list of instance backups (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_backups\_get> \]

    - `project`: string, optional

- **instance\_backups\_recursion1**

    Returns a list of instance backups (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_backups\_get\_recursion1> \]

    - `project`: string, optional

- **instance\_console**

    Gets the console log for the instance. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_console\_get> \]

    - `project`: string, optional

- **instance\_files**

    Gets the file content. If it's a directory, a json list of files will be returned instead. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_files\_get> \]

    - `path`: string, optional
    - `project`: string, optional

- **instance\_log**

    Gets the log file. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_log\_get> \]

    - `project`: string, optional

- **instance\_logs**

    Returns a list of log files (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_logs\_get> \]

    - `project`: string, optional

- **instance\_metadata**

    Gets the image metadata for the instance. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_metadata\_get> \]

    Updates the instance image metadata. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_metadata\_put> \]

    - `project`: string, optional

- **instance\_metadata\_templates**

    If no path specified, returns a list of template file names.
    If a path is specified, returns the file content. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_metadata\_templates\_get> \]

    - `path`: string, optional
    - `project`: string, optional

- **instance\_recursion1**

    Gets a specific instance (full struct).

    recursion=1 also includes information about state, snapshots and backups. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_get\_recursion1> \]

    - `project`: string, optional

- **instance\_snapshot**

    Gets a specific instance snapshot. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_snapshot\_get> \]

    Updates the snapshot config. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_snapshot\_put> \]

    - `project`: string, optional

- **instance\_snapshots**

    Returns a list of instance snapshots (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_snapshots\_get> \]

    - `project`: string, optional

- **instance\_snapshots\_recursion1**

    Returns a list of instance snapshots (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_snapshots\_get\_recursion1> \]

    - `project`: string, optional

- **instance\_state**

    Gets the runtime state of the instance.

    This is a reasonably expensive call as it causes code to be run
    inside of the instance to retrieve the resource usage and network
    information. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_state\_get> \]

    Changes the running state of the instance. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_state\_put> \]

    - `project`: string, optional

- **instances**

    Returns a list of instances (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instances\_get> \]

    Changes the running state of all instances. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instances\_put> \]

    - `all-projects`: boolean, optional
    - `filter`: string, optional
    - `project`: string, optional

- **instances\_recursion1**

    Returns a list of instances (basic structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instances\_get\_recursion1> \]

    - `all-projects`: boolean, optional
    - `filter`: string, optional
    - `project`: string, optional

- **instances\_recursion2**

    Returns a list of instances (full structs).

    The main difference between recursion=1 and recursion=2 is that the
    latter also includes state and snapshot information allowing for a
    single API call to return everything needed by most clients. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instances\_get\_recursion2> \]

    - `all-projects`: boolean, optional
    - `filter`: string, optional
    - `project`: string, optional

- **migrate\_instance**

    Renames, moves an instance between pools or migrates an instance to another server.

    The returned operation metadata will vary based on what's requested.
    For rename or move within the same server, this is a simple background operation with progress data.
    For migration, in the push case, this will similarly be a background
    operation with progress data, for the pull case, it will be a websocket
    operation with a number of secrets to be passed to the target server. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_post> \]

    - `project`: string, optional

- **migrate\_instance\_snapshot**

    Renames or migrates an instance snapshot to another server.

    The returned operation metadata will vary based on what's requested.
    For rename or move within the same server, this is a simple background operation with progress data.
    For migration, in the push case, this will similarly be a background
    operation with progress data, for the pull case, it will be a websocket
    operation with a number of secrets to be passed to the target server. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_snapshot\_post> \]

    - `project`: string, optional

- **modify\_instance**

    Updates a subset of the instance configuration \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_patch> \]

    - `project`: string, optional

- **modify\_instance\_metadata**

    Updates a subset of the instance image metadata. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_metadata\_patch> \]

    - `project`: string, optional

- **modify\_instance\_snapshot**

    Updates a subset of the snapshot config. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_snapshot\_patch> \]

    - `project`: string, optional

- **rename\_instance\_backup**

    Renames an instance backup. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/instances/instance\_backup\_post> \]

    - `project`: string, optional

## Metrics

- **metrics**

    Gets metrics of instances. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/metrics/metrics\_get> \]

    - `project`: string, optional

## Network ACLs

- **create\_network\_acl**

    Creates a new network ACL. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-acls/network\_acls\_post> \]

    - `project`: string, optional

- **delete\_network\_acl**

    Removes the network ACL. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-acls/network\_acl\_delete> \]

    - `project`: string, optional

- **modify\_network\_acl**

    Updates a subset of the network ACL configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-acls/network\_acl\_patch> \]

    - `project`: string, optional

- **network\_acl**

    Gets a specific network ACL. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-acls/network\_acl\_get> \]

    Updates the entire network ACL configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-acls/network\_acl\_put> \]

    - `project`: string, optional

- **network\_acl\_log**

    Gets a specific network ACL log entries. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-acls/network\_acl\_log\_get> \]

    - `project`: string, optional

- **network\_acls**

    Returns a list of network ACLs (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-acls/network\_acls\_get> \]

    - `project`: string, optional

- **network\_acls\_recursion1**

    Returns a list of network ACLs (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-acls/network\_acls\_get\_recursion1> \]

    - `project`: string, optional

- **rename\_network\_acl**

    Renames an existing network ACL. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-acls/network\_acl\_post> \]

    - `project`: string, optional

## Network Forwards

- **create\_network\_forward**

    Creates a new network address forward. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-forwards/network\_forwards\_post> \]

    - `project`: string, optional

- **delete\_network\_forward**

    Removes the network address forward. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-forwards/network\_forward\_delete> \]

    - `project`: string, optional

- **modify\_network\_forward**

    Updates a subset of the network address forward configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-forwards/network\_forward\_patch> \]

    - `project`: string, optional

- **network\_forward**

    Gets a specific network address forward. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-forwards/network\_forward\_get> \]

    Updates the entire network address forward configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-forwards/network\_forward\_put> \]

    - `project`: string, optional

- **network\_forward\_recursion1**

    Returns a list of network address forwards (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-forwards/network\_forward\_get\_recursion1> \]

    - `project`: string, optional

- **network\_forwards**

    Returns a list of network address forwards (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-forwards/network\_forwards\_get> \]

    - `project`: string, optional

## Network Peers

- **create\_network\_peer**

    Initiates/creates a new network peering. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-peers/network\_peers\_post> \]

    - `project`: string, optional

- **delete\_network\_peer**

    Removes the network peering. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-peers/network\_peer\_delete> \]

    - `project`: string, optional

- **modify\_network\_peer**

    Updates a subset of the network peering configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-peers/network\_peer\_patch> \]

    - `project`: string, optional

- **network\_peer**

    Gets a specific network peering. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-peers/network\_peer\_get> \]

    Updates the entire network peering configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-peers/network\_peer\_put> \]

    - `project`: string, optional

- **network\_peer\_recursion1**

    Returns a list of network peers (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-peers/network\_peer\_get\_recursion1> \]

    - `project`: string, optional

- **network\_peers**

    Returns a list of network peers (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-peers/network\_peers\_get> \]

    - `project`: string, optional

## Network Zones

- **create\_network\_zone**

    Creates a new network zone. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zones\_post> \]

    - `project`: string, optional

- **create\_network\_zone\_record**

    Creates a new network zone record. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_records\_post> \]

    - `project`: string, optional

- **delete\_network\_zone**

    Removes the network zone. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_delete> \]

    - `project`: string, optional

- **delete\_network\_zone\_record**

    Removes the network zone record. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_record\_delete> \]

    - `project`: string, optional

- **modify\_network\_zone**

    Updates a subset of the network zone configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_patch> \]

    - `project`: string, optional

- **modify\_network\_zone\_record**

    Updates a subset of the network zone record configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_record\_patch> \]

    - `project`: string, optional

- **network\_zone**

    Gets a specific network zone. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_get> \]

    Updates the entire network zone configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_put> \]

    - `project`: string, optional

- **network\_zone\_record**

    Gets a specific network zone record. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_record\_get> \]

    Updates the entire network zone record configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_record\_put> \]

    - `project`: string, optional

- **network\_zone\_records**

    Returns a list of network zone records (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_records\_get> \]

    - `project`: string, optional

- **network\_zone\_records\_recursion1**

    Returns a list of network zone records (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zone\_records\_get\_recursion1> \]

    - `project`: string, optional

- **network\_zones**

    Returns a list of network zones (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zones\_get> \]

    - `project`: string, optional

- **network\_zones\_recursion1**

    Returns a list of network zones (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/network-zones/network\_zones\_get\_recursion1> \]

    - `project`: string, optional

## Networks

- **create\_network**

    Creates a new network.
    When clustered, most network types require individual POST for each cluster member prior to a global POST. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/networks/networks\_post> \]

    - `project`: string, optional
    - `target`: string, optional

- **delete\_network**

    Removes the network. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/networks/network\_delete> \]

    - `project`: string, optional

- **modify\_network**

    Updates a subset of the network configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/networks/network\_patch> \]

    - `project`: string, optional
    - `target`: string, optional

- **network**

    Gets a specific network. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/networks/network\_get> \]

    Updates the entire network configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/networks/network\_put> \]

    - `project`: string, optional
    - `target`: string, optional

- **networks**

    Returns a list of networks (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/networks/networks\_get> \]

    - `project`: string, optional

- **networks\_leases**

    Returns a list of DHCP leases for the network. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/networks/networks\_leases\_get> \]

    - `project`: string, optional
    - `target`: string, optional

- **networks\_recursion1**

    Returns a list of networks (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/networks/networks\_get\_recursion1> \]

    - `project`: string, optional

- **networks\_state**

    Returns the current network state information. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/networks/networks\_state\_get> \]

    - `project`: string, optional
    - `target`: string, optional

- **rename\_network**

    Renames an existing network. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/networks/network\_post> \]

    - `project`: string, optional

## Operations

- **delete\_operation**

    Cancels the operation if supported. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/operations/operation\_delete> \]

- **operation**

    Gets the operation state. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/operations/operation\_get> \]

- **operation\_wait**

    Waits for the operation to reach a final state (or timeout) and retrieve its final state. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/operations/operation\_wait\_get> \]

    - `timeout`: integer, optional

- **operation\_wait\_untrusted**

    Waits for the operation to reach a final state (or timeout) and retrieve its final state.

    When accessed by an untrusted user, the secret token must be provided. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/operations/operation\_wait\_get\_untrusted> \]

    - `secret`: string, optional
    - `timeout`: integer, optional

- **operation\_websocket**

    Connects to an associated websocket stream for the operation.
    This should almost never be done directly by a client, instead it's
    meant for LXD to LXD communication with the client only relaying the
    connection information to the servers. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/operations/operation\_websocket\_get> \]

    - `secret`: string, optional

- **operation\_websocket\_untrusted**

    Connects to an associated websocket stream for the operation.
    This should almost never be done directly by a client, instead it's
    meant for LXD to LXD communication with the client only relaying the
    connection information to the servers.

    The untrusted endpoint is used by the target server to connect to the source server.
    Authentication is performed through the secret token. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/operations/operation\_websocket\_get\_untrusted> \]

    - `secret`: string, optional

- **operations**

    Returns a dict of operation type to operation list (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/operations/operations\_get> \]

- **operations\_recursion1**

    Returns a list of operations (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/operations/operations\_get\_recursion1> \]

    - `project`: string, optional

## Profiles

- **create\_profile**

    Creates a new profile. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/profiles/profiles\_post> \]

    - `project`: string, optional

- **delete\_profile**

    Removes the profile. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/profiles/profile\_delete> \]

    - `project`: string, optional

- **modify\_profile**

    Updates a subset of the profile configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/profiles/profile\_patch> \]

    - `project`: string, optional

- **profile**

    Gets a specific profile. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/profiles/profile\_get> \]

    Updates the entire profile configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/profiles/profile\_put> \]

    - `project`: string, optional

- **profiles**

    Returns a list of profiles (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/profiles/profiles\_get> \]

    - `project`: string, optional

- **profiles\_recursion1**

    Returns a list of profiles (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/profiles/profiles\_get\_recursion1> \]

    - `project`: string, optional

- **rename\_profile**

    Renames an existing profile. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/profiles/profile\_post> \]

    - `project`: string, optional

## Projects

- **create\_project**

    Creates a new project. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/projects/projects\_post> \]

- **delete\_project**

    Removes the project. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/projects/project\_delete> \]

- **modify\_project**

    Updates a subset of the project configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/projects/project\_patch> \]

- **project**

    Gets a specific project. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/projects/project\_get> \]

    Updates the entire project configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/projects/project\_put> \]

- **project\_state**

    Gets a specific project resource consumption information. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/projects/project\_state\_get> \]

- **projects**

    Returns a list of projects (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/projects/projects\_get> \]

- **projects\_recursion1**

    Returns a list of projects (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/projects/projects\_get\_recursion1> \]

- **rename\_project**

    Renames an existing project. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/projects/project\_post> \]

## Server

- **api**

    Returns a list of supported API versions (URLs).

    Internal API endpoints are not reported as those aren't versioned and
    should only be used by LXD itself. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/server/api\_get> \]

- **events**

    Connects to the event API using websocket. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/server/events\_get> \]

    - `project`: string, optional
    - `type`: string, optional

- **modify\_server**

    Updates a subset of the server configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/server/server\_patch> \]

    - `target`: string, optional

- **resources**

    Gets the hardware information profile of the LXD server. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/server/resources\_get> \]

    - `target`: string, optional

- **server**

    Shows the full server environment and configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/server/server\_get> \]

    Updates the entire server configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/server/server\_put> \]

    - `project`: string, optional
    - `target`: string, optional

- **server\_untrusted**

    Shows a small subset of the server environment and configuration
    which is required by untrusted clients to reach a server.

    The \`?public\` part of the URL isn't required, it's simply used to
    separate the two behaviors of this endpoint. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/server/server\_get\_untrusted> \]

## Storage

- **create\_storage\_pool**

    Creates a new storage pool.
    When clustered, storage pools require individual POST for each cluster member prior to a global POST. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pools\_post> \]

    - `project`: string, optional
    - `target`: string, optional

- **create\_storage\_pool\_volume**

    Creates a new storage volume. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_post> \]

    - `project`: string, optional
    - `target`: string, optional

- **create\_storage\_pool\_volumes\_backup**

    Creates a new storage volume backup. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_backups\_post> \]

    - `project`: string, optional
    - `target`: string, optional

- **create\_storage\_pool\_volumes\_snapshot**

    Creates a new storage volume snapshot. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_snapshots\_post> \]

    - `project`: string, optional
    - `target`: string, optional

- **create\_storage\_pool\_volumes\_type**

    Creates a new storage volume (type specific endpoint). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_post> \]

    - `project`: string, optional
    - `target`: string, optional

- **delete\_storage\_pool\_volume\_type**

    Removes the storage volume. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volume\_type\_delete> \]

    - `project`: string, optional
    - `target`: string, optional

- **delete\_storage\_pool\_volumes\_type\_backup**

    Deletes a new storage volume backup. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_backup\_delete> \]

    - `project`: string, optional
    - `target`: string, optional

- **delete\_storage\_pool\_volumes\_type\_snapshot**

    Deletes a new storage volume snapshot. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_snapshot\_delete> \]

    - `project`: string, optional
    - `target`: string, optional

- **delete\_storage\_pools**

    Removes the storage pool. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pools\_delete> \]

    - `project`: string, optional

- **migrate\_storage\_pool\_volume\_type**

    Renames, moves a storage volume between pools or migrates an instance to another server.

    The returned operation metadata will vary based on what's requested.
    For rename or move within the same server, this is a simple background operation with progress data.
    For migration, in the push case, this will similarly be a background
    operation with progress data, for the pull case, it will be a websocket
    operation with a number of secrets to be passed to the target server. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volume\_type\_post> \]

    - `project`: string, optional
    - `target`: string, optional

- **modify\_storage\_pool**

    Updates a subset of the storage pool configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_patch> \]

    - `project`: string, optional
    - `target`: string, optional

- **modify\_storage\_pool\_volume\_type**

    Updates a subset of the storage volume configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volume\_type\_patch> \]

    - `project`: string, optional
    - `target`: string, optional

- **modify\_storage\_pool\_volumes\_type\_snapshot**

    Updates a subset of the storage volume snapshot configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_snapshot\_patch> \]

    - `project`: string, optional
    - `target`: string, optional

- **rename\_storage\_pool\_volumes\_type\_backup**

    Renames a storage volume backup. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_backup\_post> \]

    - `project`: string, optional
    - `target`: string, optional

- **rename\_storage\_pool\_volumes\_type\_snapshot**

    Renames a storage volume snapshot. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_snapshot\_post> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool**

    Gets a specific storage pool. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_get> \]

    Updates the entire storage pool configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_put> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_resources**

    Gets the usage information for the storage pool. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_resources> \]

    - `target`: string, optional

- **storage\_pool\_volume\_type**

    Gets a specific storage volume. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volume\_type\_get> \]

    Updates the entire storage volume configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volume\_type\_put> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volume\_type\_state**

    Gets a specific storage volume state (usage data). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volume\_type\_state\_get> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes**

    Returns a list of storage volumes (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_get> \]

    - `filter`: string, optional
    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes\_recursion1**

    Returns a list of storage volumes (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_get\_recursion1> \]

    - `filter`: string, optional
    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes\_type**

    Returns a list of storage volumes (URLs) (type specific endpoint). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_get> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes\_type\_backup**

    Gets a specific storage volume backup. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_backup\_get> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes\_type\_backup\_export**

    Download the raw backup file from the server. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_backup\_export\_get> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes\_type\_backups**

    Returns a list of storage volume backups (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_backups\_get> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes\_type\_backups\_recursion1**

    Returns a list of storage volume backups (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_backups\_get\_recursion1> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes\_type\_recursion1**

    Returns a list of storage volumes (structs) (type specific endpoint). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_get\_recursion1> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes\_type\_snapshot**

    Gets a specific storage volume snapshot. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_snapshot\_get> \]

    Updates the entire storage volume snapshot configuration. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_snapshot\_put> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes\_type\_snapshots**

    Returns a list of storage volume snapshots (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_snapshots\_get> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pool\_volumes\_type\_snapshots\_recursion1**

    Returns a list of storage volume snapshots (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pool\_volumes\_type\_snapshots\_get\_recursion1> \]

    - `project`: string, optional
    - `target`: string, optional

- **storage\_pools**

    Returns a list of storage pools (URLs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pools\_get> \]

    - `project`: string, optional

- **storage\_pools\_recursion1**

    Returns a list of storage pools (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/storage/storage\_pools\_get\_recursion1> \]

    - `project`: string, optional

## Warnings

- **delete\_warning**

    Removes the warning. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/warnings/warning\_delete> \]

- **modify\_warning**

    Updates a subset of the warning status. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/warnings/warning\_patch> \]

- **warning**

    Gets a specific warning. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/warnings/warning\_get> \]

    Updates the warning status. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/warnings/warning\_put> \]

- **warnings**

    Returns a list of warnings. \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/warnings/warnings\_get> \]

    - `project`: string, optional

- **warnings\_recursion1**

    Returns a list of warnings (structs). \[L <Spec|https://linuxcontainers.org/lxd/api/master/#/warnings/warnings\_get\_recursion1> \]

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
