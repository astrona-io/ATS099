# Governing Tenants With Repositories And Policy

The platform team can limit what a tenant's Flux objects do. It also needs to decide how the Git repositories are arranged, who may push to them, and how to reject a Flux object that breaks a rule before it reaches the controllers. Three tools do this: the repository layout, Git permissions with signed commits, and an admission policy inside Kubernetes.

The important idea is where each rule is enforced. A repository layout and branch protection rules are enforced by the Git server. A signature check is enforced by source-controller. An admission policy is enforced by the Kubernetes API server. A rule at one of these places does not replace a rule at another, so a platform uses all three.

The module has four parts. **Repository Layouts For Many Teams** compares one repository for everything, one per tenant and one per environment. **Git Permissions And Verified Sources** covers branch protection, review rules and the `verify` field that checks signatures. **Admission Policy For Flux Objects** writes a Kubernetes ValidatingAdmissionPolicy that rejects tenant Flux objects without a ServiceAccount. **Auditing What Tenants Run** lists the commands that show who deploys what. A graded lab follows the third part.

## Learning objectives

After this module you can:

- Choose between a single repository, a repository per tenant and a repository per environment, and state the cost of each.
- Describe the Git permissions the platform team and a tenant need, and where branch protection applies.
- Verify commit signatures or artifact signatures with the `verify` field of a source.
- Write a ValidatingAdmissionPolicy and a binding that reject a Flux `Kustomization` without a ServiceAccount.
- List what a tenant deploys with `flux tree`, `flux trace` and labels.

## Before you start

You need these facts: tenants are onboarded through the platform repository, and the tenant's Flux `Kustomization` impersonates a ServiceAccount. You also need basic Kubernetes admission: an API request is checked before it is stored.

Your playground is a single-node `kind` cluster. Flux 2.9.6 is bootstrapped from the repository `gitops/fleet` at the path `clusters/kind`, on an in-cluster Git server called Gitea. The tenant `team-a` is already onboarded through `tenants/team-a`, and its repository `gitops/team-a` is public. The cluster must run Kubernetes 1.30 or later for the admission policy part, because ValidatingAdmissionPolicy is generally available from that version.

Both repositories live at `http://gitea.localtest.me:3000/gitops/<name>.git`, with the lab-only user `gitops` and the password `gitops-password`. To use `git` from your machine, start this port-forward in a second terminal and leave it running:

```sh
kubectl -n gitea port-forward svc/gitea-http 3000:3000
```

If `git` cannot resolve `gitea.localtest.me`, add the line `127.0.0.1 gitea.localtest.me` to `/etc/hosts`. A real Git server uses HTTPS or SSH; plain HTTP is for this playground only.

Launch your playground now, and keep it running next to you while you read the parts:

<!-- astrona:playground -->
