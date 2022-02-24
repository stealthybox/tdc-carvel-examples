Install a local CA and create some wildcard TLS certificates:
```shell
mkcert -install
mkcert 'sslip.io' '*.sslip.io' 'localtest.me' '*.localtest.me' 'localhost' '127.0.0.1' '::1'
```

Start up a local KinD cluster:
```shell
COPY
cat <<EOF | kind create cluster --name pinniped --config=-
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

Install Contour and patch it for KinD
```shell
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
kubectl patch daemonsets -n projectcontour envoy -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'
```

Install the Pinniped Supervisor:
```shell
kapp deploy --app pinniped-supervisor --file https://get.pinniped.dev/v0.12.0/install-pinniped-supervisor.yaml
```

Provision the TLS cert in k8s:
```shell
kubectl create secret tls localtls --key sslip.io+6-key.pem --cert sslip.io+6.pem -n pinniped-supervisor
```

Create the Supervisor Service and Ingress:
```shell
kubectl -n pinniped-supervisor expose deploy pinniped-supervisor --port 8080
kubectl -n pinniped-supervisor create ingress pinniped-supervisor --rule="pinniped-supervisor-172-28-143-21.sslip.io/*=pinniped-supervisor:8080,tls=localtls"
```

Create your personal Federation Domain
```shell
cat << EOF | kubectl apply -f -
apiVersion: config.supervisor.pinniped.dev/v1alpha1
kind: FederationDomain
metadata:
  name: my-provider
  # Assuming that this is the namespace where the supervisor was installed. This is the default in install-supervisor.yaml.
  namespace: pinniped-supervisor
spec:
  # The hostname would typically match the DNS name of the public ingress or load balancer for the cluster.
  # Any path can be specified, which allows a single hostname to have multiple different issuers. The path is optional.
  issuer: https://pinniped-supervisor-172-28-143-21.sslip.io

  # Optionally configure the name of a Secret in the same namespace, of type `kubernetes.io/tls`,
  # which contains the TLS serving certificate for the HTTPS endpoints served by this OIDC Provider.
  tls:
    secretName: localtls
EOF
```

Go to your Github account settings and [create an OAuth app](https://github.com/settings/applications/new):
```yaml
Application name: Dex application
Homepage URL: https://dex-172-28-143-21.sslip.io
Authorization callback URL: https://dex-172-28-143-21.sslip.io/callback # this is where Github will redirect you to once your app has authenticated
```
Once completed, copy your **Client ID** and **Client Secret** (generate one if there’s none) as those two will be needed to configure a Github connector in Dex:

Install Dex:
```shell
kubectl create secret tls localtls --key sslip.io+6-key.pem --cert sslip.io+6.pem -n dex
kubectl apply -f dex.yaml
kubectl -n dex create ingress dex --rule="dex-172-28-143-21.sslip.io/*=dex:dex,tls=localtls"
```

Update your Dex config:
```shell
kubectl create secret generic -n dex github-client \
  --from-literal client-id="52bb8fad936de11e0876" \
  --from-literal client-secret="081993c2f65e377979e9ae7a017b930202118d8b"
```

```yaml
### ...
connectors:
- type: github
  id: github
  name: GitHub
  config:
    clientID: $GITHUB_CLIENT_ID
    clientSecret: $GITHUB_CLIENT_SECRET
    redirectURI: https://dex-172-28-143-21.sslip.io/callback
staticClients:
- id: pinniped-cid
  secret: pinniped-cid-secret-abcdef-12345-abcdef-12345
  name: 'Pinniped Supervisor client'
  redirectURIs:
  - 'https://pinniped-supervisor-172-28-143-21.sslip.io/callback'
### ...
```

```yaml
cat << EOF | kubectl apply -f -

---
apiVersion: v1
kind: Secret
metadata:
  name: dex-client-credentials
  namespace: pinniped-supervisor
type: secrets.pinniped.dev/oidc-client
stringData:
  clientID: pinniped-cid
  clientSecret: pinniped-cid-secret-abcdef-12345-abcdef-12345
---
apiVersion: idp.supervisor.pinniped.dev/v1alpha1
kind: OIDCIdentityProvider
metadata:
  name: dex
  namespace: pinniped-supervisor
spec:
  issuer: https://dex-172-28-143-21.sslip.io # no trailing slash
  authorizationConfig:
    additionalScopes: [offline_access, groups, email]
    # If you would also like to allow your end users to authenticate using
    # a password grant, then change this to true.
    # Password grants with Dex will only work in Dex versions that include
    # this bug fix: https://github.com/dexidp/dex/pull/2234
    allowPasswordGrant: false
  # Specify how Dex claims are mapped to Kubernetes identities.
  claims:
    username: email
    # Specify the name of the claim in your Dex ID token that represents the groups
    # that the user belongs to. This matches what you specified above
    # with the Groups claim filter.
    # Note that the group claims from Github are in the format of "org:team".
    # To query for the group scope, you should set the organization you want Dex to
    # search against in its configuration, otherwise your group claim would be empty.
    # An example config can be found at - https://dexidp.io/docs/connectors/github/#configuration
    groups: groups
  # Specify the name of the Kubernetes Secret that contains your Dex
  # application's client credentials (created below).
  client:
    secretName: dex-client-credentials
  tls:
    certificateAuthorityData: |
      LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUVnekNDQXV1Z0F3SUJBZ0lSQU1kakx3Y1Fq
      RjFwZVc5WXpGbjNXcXN3RFFZSktvWklodmNOQVFFTEJRQXcKZ1lFeEhqQWNCZ05WQkFvVEZXMXJZ
      MlZ5ZENCa1pYWmxiRzl3YldWdWRDQkRRVEVyTUNrR0ExVUVDd3dpVmsxWApRVkpGVFZ4c1pXbG5h
      R05BYkdWcFoyaGpMWG93TVNBb2JHVnBaMmhqS1RFeU1EQUdBMVVFQXd3cGJXdGpaWEowCklGWk5W
      MEZTUlUxY2JHVnBaMmhqUUd4bGFXZG9ZeTE2TURFZ0tHeGxhV2RvWXlrd0hoY05NakV4TVRBME1E
      TTAKTlRFeVdoY05NalF3TWpBME1EUTBOVEV5V2pCS01TY3dKUVlEVlFRS0V4NXRhMk5sY25RZ1pH
      VjJaV3h2Y0cxbApiblFnWTJWeWRHbG1hV05oZEdVeEh6QWRCZ05WQkFzTUZuTjBaV0ZzZEdoNVlt
      OTRRR3hsYVdkb1l5MTZNREV3CmdnRWlNQTBHQ1NxR1NJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0Fv
      SUJBUURkWHBrYmhQS3NJRE9BUFd2MG41TmEKczFPZGNCUzBEY0JqRnhaYkxtQXhJUnRTK1RuRHpU
      SzNuN0dlRFJUMGp5WDlzMWptVkFReGRYOUJNaTRiZGFuWAprL1IrNEJJd3NLU3VwM1luc1pOVHJi
      UFJtSjVNN3hNYlFzM2l6OUZ5ckdpMkd5QmxvcWtyTDFqcCtpTldCcEU5CmdGNGdNVjcvbXVxNFph
      UG1RSzJCNERITUg5d0FyTmx2VnZpUHhkWEpYT2FPaVlNZmdOYkhlRVhvaW1EZzM3VSsKMkNZUFAw
      bExqZVE5ZkdrS3N4M2xYTHpMR09XZmdCdGw0OU90ZkNyNnRMdTdwSTIyeTFrVU9CZ1FRV2NFVDI0
      WQpkYUZJR2EzK3NvemNvR2NjNVBxaS9raEtvek9BOTRSY3owNHpMcDF5Tm8wdklaeXJNOW4xdHF3
      NStwUmlHUFp0CkFnTUJBQUdqZ2Fzd2dhZ3dEZ1lEVlIwUEFRSC9CQVFEQWdXZ01CTUdBMVVkSlFR
      TU1Bb0dDQ3NHQVFVRkJ3TUIKTUI4R0ExVWRJd1FZTUJhQUZOWHNpS0V0dDhCNUd1SFZudlpZbHA5
      aDU0ZjdNR0FHQTFVZEVRUlpNRmVDQ0hOegpiR2x3TG1sdmdnb3FMbk56Ykdsd0xtbHZnZ3hzYjJO
      aGJIUmxjM1F1YldXQ0Rpb3ViRzlqWVd4MFpYTjBMbTFsCmdnbHNiMk5oYkdodmMzU0hCSDhBQUFH
      SEVBQUFBQUFBQUFBQUFBQUFBQUFBQUFFd0RRWUpLb1pJaHZjTkFRRUwKQlFBRGdnR0JBSU9HNHRZ
      UTRmNXB0Y1gyL0JUWkVaOWZ6RlM1VjR1UjNsQk1Ma09iYTh4YUYvb1FYRVZmZ05tdQppWHdEMnpY
      UXIwWFMxUGNwZTFVK1luOUIxUUhJN01ZNGdvS0ZnTXJOUEdMU284d1ZsVGZTYUF1OWFsVjdacUM4
      CmhTcXl3bDFIaUVISVVMT2NWdnlGeUFxU1l0VG9rUEJoOExZUXZQNTFtYnZKNkxHZEdPckpDemV0
      REVoczBjWXQKUE5FQ3NJUVNoTDFkclRMV2lPSHR0dzJRQlVaUWhTTDl0UEYzdUQrVmtoRFMva0h6
      cTdkbFp6b3JZcWpkRzVGZQpGSUV4a1N1aDZ1RU8wWXZSd08zWTR2TTQ4UU51a1lyM1NiWGd4VzdE
      NjRtSzZNbURHTFRRRWdDSU50Wi9Fb01VCm50NnozNk5tTGwrUWtTVFR6VFVkTEhkTXVyNkFmdHFn
      SEgvV3V4eUdCczlBOWpRR3RDUVZoVzlObXJVZDVwbloKM0E3Q0dNM2Y3blVnTkcwR1BDNU9QYTl3
      WWlWL2dKYmtGbjFTOTJVUU5GT0JTVkp4RWlFaExnSzY3ckNpeXV4bwpqb0Nnc200cERzRlIwVTZG
      cWx1Zmc2aldJYVNNRVB2UWNNb0J5cldXYUZIUTVCc2wvUDdwK3BEZzF1ZVRzRS9XCk1ueEhuM3lP
      OWc9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==

EOF
```

Check the OIDC config:
```shell
kubectl describe OIDCIdentityProvider -n pinniped-supervisor dex
```

Install the concierge:
```shell
kapp deploy --app pinniped-concierge --file https://get.pinniped.dev/v0.12.0/install-pinniped-concierge.yaml
```

Configure the concierge:
```shell
cat << EOF | k apply -f -

apiVersion: authentication.concierge.pinniped.dev/v1alpha1
kind: JWTAuthenticator
metadata:
  name: my-supervisor-authenticator
spec:

  # The value of the `issuer` field should exactly match the `issuer`
  # field of your Supervisor's FederationDomain.
  issuer: https://pinniped-supervisor-172-28-143-21.sslip.io

  # You can use any `audience` identifier for your cluster, but it is
  # important that it is unique for security reasons.
  audience: my-unique-cluster-identifier-da79fa849

  # If the TLS certificate of your FederationDomain is not signed by
  # a standard CA trusted by the Concierge pods by default, then
  # specify its CA here as a base64-encoded PEM.
  tls:
    certificateAuthorityData: |
      LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUVnekNDQXV1Z0F3SUJBZ0lSQU1kakx3Y1Fq
      RjFwZVc5WXpGbjNXcXN3RFFZSktvWklodmNOQVFFTEJRQXcKZ1lFeEhqQWNCZ05WQkFvVEZXMXJZ
      MlZ5ZENCa1pYWmxiRzl3YldWdWRDQkRRVEVyTUNrR0ExVUVDd3dpVmsxWApRVkpGVFZ4c1pXbG5h
      R05BYkdWcFoyaGpMWG93TVNBb2JHVnBaMmhqS1RFeU1EQUdBMVVFQXd3cGJXdGpaWEowCklGWk5W
      MEZTUlUxY2JHVnBaMmhqUUd4bGFXZG9ZeTE2TURFZ0tHeGxhV2RvWXlrd0hoY05NakV4TVRBME1E
      TTAKTlRFeVdoY05NalF3TWpBME1EUTBOVEV5V2pCS01TY3dKUVlEVlFRS0V4NXRhMk5sY25RZ1pH
      VjJaV3h2Y0cxbApiblFnWTJWeWRHbG1hV05oZEdVeEh6QWRCZ05WQkFzTUZuTjBaV0ZzZEdoNVlt
      OTRRR3hsYVdkb1l5MTZNREV3CmdnRWlNQTBHQ1NxR1NJYjNEUUVCQVFVQUE0SUJEd0F3Z2dFS0Fv
      SUJBUURkWHBrYmhQS3NJRE9BUFd2MG41TmEKczFPZGNCUzBEY0JqRnhaYkxtQXhJUnRTK1RuRHpU
      SzNuN0dlRFJUMGp5WDlzMWptVkFReGRYOUJNaTRiZGFuWAprL1IrNEJJd3NLU3VwM1luc1pOVHJi
      UFJtSjVNN3hNYlFzM2l6OUZ5ckdpMkd5QmxvcWtyTDFqcCtpTldCcEU5CmdGNGdNVjcvbXVxNFph
      UG1RSzJCNERITUg5d0FyTmx2VnZpUHhkWEpYT2FPaVlNZmdOYkhlRVhvaW1EZzM3VSsKMkNZUFAw
      bExqZVE5ZkdrS3N4M2xYTHpMR09XZmdCdGw0OU90ZkNyNnRMdTdwSTIyeTFrVU9CZ1FRV2NFVDI0
      WQpkYUZJR2EzK3NvemNvR2NjNVBxaS9raEtvek9BOTRSY3owNHpMcDF5Tm8wdklaeXJNOW4xdHF3
      NStwUmlHUFp0CkFnTUJBQUdqZ2Fzd2dhZ3dEZ1lEVlIwUEFRSC9CQVFEQWdXZ01CTUdBMVVkSlFR
      TU1Bb0dDQ3NHQVFVRkJ3TUIKTUI4R0ExVWRJd1FZTUJhQUZOWHNpS0V0dDhCNUd1SFZudlpZbHA5
      aDU0ZjdNR0FHQTFVZEVRUlpNRmVDQ0hOegpiR2x3TG1sdmdnb3FMbk56Ykdsd0xtbHZnZ3hzYjJO
      aGJIUmxjM1F1YldXQ0Rpb3ViRzlqWVd4MFpYTjBMbTFsCmdnbHNiMk5oYkdodmMzU0hCSDhBQUFH
      SEVBQUFBQUFBQUFBQUFBQUFBQUFBQUFFd0RRWUpLb1pJaHZjTkFRRUwKQlFBRGdnR0JBSU9HNHRZ
      UTRmNXB0Y1gyL0JUWkVaOWZ6RlM1VjR1UjNsQk1Ma09iYTh4YUYvb1FYRVZmZ05tdQppWHdEMnpY
      UXIwWFMxUGNwZTFVK1luOUIxUUhJN01ZNGdvS0ZnTXJOUEdMU284d1ZsVGZTYUF1OWFsVjdacUM4
      CmhTcXl3bDFIaUVISVVMT2NWdnlGeUFxU1l0VG9rUEJoOExZUXZQNTFtYnZKNkxHZEdPckpDemV0
      REVoczBjWXQKUE5FQ3NJUVNoTDFkclRMV2lPSHR0dzJRQlVaUWhTTDl0UEYzdUQrVmtoRFMva0h6
      cTdkbFp6b3JZcWpkRzVGZQpGSUV4a1N1aDZ1RU8wWXZSd08zWTR2TTQ4UU51a1lyM1NiWGd4VzdE
      NjRtSzZNbURHTFRRRWdDSU50Wi9Fb01VCm50NnozNk5tTGwrUWtTVFR6VFVkTEhkTXVyNkFmdHFn
      SEgvV3V4eUdCczlBOWpRR3RDUVZoVzlObXJVZDVwbloKM0E3Q0dNM2Y3blVnTkcwR1BDNU9QYTl3
      WWlWL2dKYmtGbjFTOTJVUU5GT0JTVkp4RWlFaExnSzY3ckNpeXV4bwpqb0Nnc200cERzRlIwVTZG
      cWx1Zmc2aldJYVNNRVB2UWNNb0J5cldXYUZIUTVCc2wvUDdwK3BEZzF1ZVRzRS9XCk1ueEhuM3lP
      OWc9PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==

EOF
```

Get a kubeconfig:
```shell
pinniped get kubeconfig >! tmp.kubeconfig.yaml
```

Trying to get pods using this kubeconfig will start an auto-login.
It will either open the browser or you can navigate to the link output to the terminal.
```shell
KUBECONFIG=./tmp.kubeconfig.yaml kubectl get po
```

You can now see you are logged in as. This will print your username and any groups you are a part of (from organizations the GitHub Oauth App has permission to read).
```shell
KUBECONFIG=./tmp.kubeconfig.yaml pinniped whoami
```

Using an administrator user, permit namespace level admin access for a github group
```shell
kubectl create rolebinding \
  --namespace default \
  --clusterrole admin \
  --group stealthytail:kube-admin \
  stealthytail:kube-admin
```



Using an administrator user, permit cluster-wide admin access for a github group
```shell
kubectl create clusterrolebinding \
  --clusterrole admin \
  --group stealthytail:kube-admin \
  stealthytail:kube-admin
```
