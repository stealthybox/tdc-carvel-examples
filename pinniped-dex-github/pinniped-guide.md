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
- [mkcert](https://github.com/FiloSottile/mkcert#installation) (if demo'ing on your laptop and/or with private TLS)


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

### callback URL
In order to create an Oauth app, you'll need the callback URL for the Dex ingress we
intend to deploy. If we plan deploy dex to `dex.example.com`, set the callback url to
`https://dex.example.com/callback`.

If you are using your laptop's private network IP for this,
you can print the callback URL by running `make hosts`.

Note that the Dex IP address cannot be `localhost`, `127.0.0.1/8`, or `::1` because the
Pinniped Supervisor Pod will fail to health-check Dex.
(The Deployments would need to be merged or co-scheduled to support this edge-case.)
Your laptop's IP address from your router or your VM's private or public IP is sufficient
for this use-case.

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

Personal Oauth apps have a benefit. They can request access to multiple organization's member-lists and teams.
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

Organization Oauth apps will automatically have access to the member-list and teams,
constrained to just this single organization. It is not owned by a particular GitHub user.

### client secret
Once your Oauth App is created, generate a client secret.
Save a file called `config/values.yaml` containing the client secrets.




## Create the Supervisor Kubernetes Cluster
To demo this on your laptop, start a local KinD cluster called `pinniped-1`:
```shell
cat <<EOF | kind create cluster --name pinniped-1 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
```

Install Contour and patch it for KinD, so that we can route our Ingress records.
```shell
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
kubectl patch daemonsets -n projectcontour envoy -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'
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

```shell
# kind create
# install contour + configure for kind
```

### Deploy the Pinniped Concierge
Our first cluster is already running:
- Dex (to talk to GitHub)
- the Pinniped Supervisor
- the Pinniped Concierge (so that we can login to Kubernetes)

For out second cluster, we just need to install the Pinniped Concierge and
point it to the Pinniped Supervisor in the first cluster.

Each cluster should have a unique cluster audience

TODO: document/add `cluster_audience` to the Makefile

```shell

```

## Login to the Second Cluster


