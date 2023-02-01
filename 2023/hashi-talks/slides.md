---
author: 'David Alexander'
title: 'IRSA Evolved'
theme: white
css:
  - customizations.css
---

# Agenda

::: incremental

- What is IRSA
- Why you should care
- How it works
- Limits
- Next steps

:::

# Disclaimer


**LICENSE:** [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/)

I do not speak on behalf of my employer.

My views may not reflect those of my employer.

Media relations @ [elevancehealth.com/contact-us](https://www.elevancehealth.com/contact-us).

# IRSA

::: incremental

- IAM Roles for Service Accounts (IRSA)
- Ties a kube service account to an AWS IAM role

:::

<aside class="notes">

- IRSA is an indispensable tool for communicating between a kube cluster and the Amazon cloud platform
- It is a 1:1 translation of the Kubernetes identity to an AWS identity
- 2-way handshake to establish "trust"

</aside>

## Use cases

- `external-dns` w/ Route53
- CSI driver for AWS' Elastic Block Store (EBS)
- Application stores blobs in S3 buckets

## Kubernetes Config

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-workload
  annotations:
    eks.amazonaws.com/role-arn: >
      arn:aws:iam::111122223333:role/my-role
```

## IAM Config

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    // ...
  }]
}
```

<aside class="notes">

- we all know what an IAM policy looks like?

</aside>

---

```json
{
  "Effect": "Allow",
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Principal": {
    "Federated":
      "arn:aws:iam::111122223333:oidc-provider/YOUR_OIDC_URI"
  },
  "Condition": {
    "StringEquals": {
      "YOUR_OIDC_URI:sub": "system:serviceaccount:KUBE_NS:KUBE_SA",
      "YOUR_OIDC_URI:aud": "sts.amazonaws.com"
    }
  }
}
```

---

::: incremental

- `YOUR_OIDC_URI`
  - &rarr; `oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE`
- `KUBE_NS`
  - &rarr; `breakfast-table`
- `KUBE_SA`
  - &rarr; ~~`default`~~
  - &rarr; `waffles`

:::

---

```json
{
  "Effect": "Allow",
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Principal": {
    "Federated":
      "arn:aws:iam::111122223333:oidc-provider/YOUR_OIDC_URI"
  },
  "Condition": {
    "StringEquals": {
      "YOUR_OIDC_URI:sub": "system:serviceaccount:KUBE_NS:KUBE_SA",
      "YOUR_OIDC_URI:aud": "sts.amazonaws.com"
    }
  }
}
```

---

```json
{
// ...
"Principal": {
  "Federated": "arn:aws:iam::111122223333:oidc-provider/YOUR_OIDC_URI"
},
// ...
}
```

---

```json
{
// ...
"StringEquals": {
  // ...
  "YOUR_OIDC_URI:sub": "system:serviceaccount:KUBE_NS:KUBE_SA",
  // ...
}
// ...
}
```

---

```json
{
// ...
  "Action": "sts:AssumeRoleWithWebIdentity",
// ...
}
```

### JWT

```json
{
  "iss": "https://kubernetes.cluster.local",
  "aud": "sts.amazonaws.com",
  "sub": "system:service:KUBE_NS:KUBE_SA",
  "iat": 1516239022
}
```

## OIDC Provider

```terraform
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.eks.certificates[*].sha1_fingerprint
}
```

---

::: incremental

- `aws_eks_cluster.this.identity[0].oidc[0].issuer`
  - &rarr; `https://YOUR_OIDC_URI`

:::

## Observations

::: incremental

- AWS SDKs seem to "just work" without `~/.aws/config`
- EKS-only, no other Kubernetes distros
- Creds are fresh, never frozen

:::

## Limits

::: incremental

- Same-account only
- Trust policies everywhere
- Kube cluster &rarr; OIDC provider &rarr; IAM role

:::

<aside class="notes">

- unless `~/.aws/config` with `assume_role` cross-account
- scaling across 100's of accounts, 2-way handshakes... _HARD_
- several steps, only usable by this kube cluster

</aside>

---

![](https://external-content.duckduckgo.com/iu/?u=http%3A%2F%2Fl450v.alamy.com%2F450v%2Fkm7b21%2Falways-fresh-never-frozen-grunge-rubber-stamp-on-white-background-km7b21.jpg&f=1&nofb=1&ipt=25e551438ce6d0770e8b905d91089ec3e77f927113ed7a1a4c7c55015ab8ae28&ipo=images)

# ...

---

Kubernetes is evolving!

---

![](https://i.imgur.com/OezkEMW.png)

---

![](https://i.imgur.com/QjXHQvI.png)

---

- HashiCorp Vault
- Vault Agent Injector (helm)
- AWS SDK config files

# HashiCorp Vault

::: incremental

- Identity translator
  - Bring your own identity
  - Produces native identity
- Purpose-built

:::

<aside class="notes">

<!-- These are some speaker notes -->

- HashiCorp Vault is, canonically, an identity translator
  - esp. between systems that don't know about, or support your chosen identity system
  - absorbs complexity, exposing simple creds
- Not just Kube, not just AWS, much wider scope

</aside>

## AWS Creds

- Vault Agent Injector
  - annotations &rarr; Pod + Vault Agent
- Templated INI file
  - contents like `~/.aws/credentials`
- `AWS_SHARED_CREDENTIALS`
  - **&rArr;** `/vault/secrets/<NAME>`)

---

```yaml
vault.hashicorp.com/agent-inject: 'true'
vault.hashicorp.com/agent-cache-enable: 'true'
vault.hashicorp.com/role: 'my-kube-auth-role'
```

---

```yaml
vault.hashicorp.com/agent-inject-secret-awscreds: 'aws/sts/s3-rw'
vault.hashicorp.com/agent-inject-template-awscreds: |
  {{- with secret "aws/sts/s3-rw" "role_session_name=vault-agent" -}}
  [default]
  aws_access_key_id = {{ .Data.access_key }}
  aws_secret_access_key = {{ .Data.secret_key }}
  aws_session_token = {{ .Data.security_token }}
  {{- end }}
```

---

```yaml
- name: rss-reader
  image: docker.io/nickchase/rss-php-nginx:v1
  env:
    # ...
    - name: AWS_SHARED_CREDENTIALS
      value: /vault/secrets/awscreds
    # ...
```

---

(demo)

# Who Am I?

---

![David Alexander](https://github.com/thelonelyghost.png)

[www.thelonelyghost.com](https://thelonelyghost.com)
