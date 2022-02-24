# Multi-cluster GitHub login on Kubernetes with Pinniped and Dex

In this guide we'll setup [Pinniped](https://pinniped.dev) and [Dex](https://TODO)
so our teammates can get secure, federated, access to all of our Kubernetes
clusters with a single GitHub login.

This setup will work on any mix of Kubernetes clusters, because Pinniped does not
require any control of special kube-apiserver options. This means you can *use the
same identity provider* across managed Kubernetes services like EKS, GKE, and AKS
alongside self-managed clusters such as [Tanzu Community Edition](https://tanzucommunityedition.io/).

Today's walkthrough is packaged to work on a developer laptop using `kind` and `mkcert`,
but the same setup will work in real Kubernetes environments with some small tweaks
for [cert-manager](https://TODO) and [external-dns](https://TODO).

This guide is of intermediate difficulty since it involves:
- Oauth2 config via the GitHub UI
- DNS, TLS, Ingress
- One or more Kubernetes clusters


## Tools you'll need
- git
- docker
- kubectl
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [pinniped](https://github.com/vmware-tanzu/homebrew-pinniped#how-do-i-install-this-formula)
- [ytt + kapp](https://github.com/vmware-tanzu/homebrew-carvel#homebrew-tap)
- [mkcert](https://github.com/FiloSottile/mkcert#installation) (if demo'ing on your laptop or private network)


## Clone the Repo
First clone the project repo.
We'll need this to discover some machine settings and save our Oauth config.
```shell
# TODO
git clone https://<__>
cd <__>
```


## Create a GitHub Oauth App
Now, we'll need to either create a personal or organization level Oauth app.
Personal apps may need to be granted organizational access to lookup whether a
GitHub user is within that organization and which groups the user is a member of. 

### personal apps
You can create a personal app from your github settings:
https://github.com/settings/developers
Generate a new set of Client Credentials and store them in a safe place such as a
password manager.

Next click on your new app in the integrations list here:
https://github.com/settings/applications
Request access for any organizations you want to use for membership and groups
based on GitHub teams.

Now navigate to an organization's third-party access settings, and allow your new application:
```shell
https://github.com/organizations/${my_organization}/settings/oauth_application_policy
```

Personal Oauth apps can have access to multiple organization's member-lists and teams.
Since they are owned by a particular GitHub user, you may want to create
a [machine user](https://docs.github.com/en/developers/overview/managing-deploy-keys#machine-users)
to manage the Oauth app independent of any single team member.

### organization apps
You can create a organization app from your organization's github settings:
```shell
https://github.com/organizations/${my_organization}/settings/applications
```
Generate a new set of Client Credentials and store them in a safe place such as a
password manager.

This Oauth app will automatically have access to the organization's member-list,
and teams for just this single organization. It is not owned by a particular
GitHub user.


## Create the Supervisor Kubernetes Cluster
```shell
# kind create
# install contour + configure for kind
```


## Deploy Dex and the Pinniped Supervisor

### Local Development

#### Configure TLS
For using kind on our local laptop or demo private network, we can use `mkcert` to
create a development Certificate Authority that is trusted by our machine, Dex, and 
Pinniped.

```shell
# TODO:
# mkcert install
# gen certs
```

Do not use this setup for real services.
Consider using a real Certificate Authority such as Let's Encrypt with cert-manager,
or look into PKI tools like https://cfssl.org/.


### Deploy Dev
The Makefile uses `ytt` to build our patched config.
It then pipes it to `kapp` to deploy and track the Kubernetes resources.

To see what changes `kapp` will make to the cluster, run:
```shell
make dry
```

If you like what you see, you can deploy like so:
```shell
make deploy
```

If you'd like to inspect the YAML output of the ytt program, run:
```shell
make ytt
```

#### Production

link to cert-manager /w let's encrypt demo
link to external-dns
describe which Ingress records need DNS and TLS



## Login



## Grant Access



## Create a Second Cluster
TODO: document/add `cluster_audience` to the Makefile

```shell
# kind create
# install contour + configure for kind
```

### Deploy the Pinniped Concierge
Our first cluster is already running Dex (to talk to GitHub),
the Pinniped Supervisor, and 

## Login to the Second Cluster


