# Section 010: Multi-Tenancy With Impersonation

A cluster that runs Flux usually serves more than one team. Each team wants to ship its own application from its own Git repository, without a ticket to the platform team. The platform team wants the opposite guarantee: no team may touch another team's namespace, and no team may create objects that affect the whole cluster.

By default Flux does not give that guarantee. kustomize-controller applies files with a ServiceAccount that holds the ClusterRole `cluster-admin`, so whatever a repository contains, Flux applies. This section shows how Flux closes that gap. Each team, called a **tenant**, gets a namespace, a ServiceAccount and a Git repository. Flux applies the tenant's files **as** that ServiceAccount, so Kubernetes role-based access control (RBAC) decides what is allowed. A few controller flags, the **lockdown**, make sure no tenant can step around it.

**Topic covered:** Multi-tenancy

## What you will learn

- The roles of the platform administrator and the tenant, and how their repositories are laid out.
- What `flux create tenant` generates: a Namespace, a ServiceAccount and a RoleBinding.
- Impersonation with `spec.serviceAccountName`, and how to read a refusal from Kubernetes RBAC.
- The lockdown flags `--no-cross-namespace-refs`, `--no-remote-bases` and `--default-service-account`, and how to add them through Git.
- Why the platform's own Flux `Kustomization` objects need `serviceAccountName: kustomize-controller` once the lockdown is on.

## The learning path

The section has three modules. Each has a landing page, deep-dive parts, a graded lab right after the part it tests, and a summary. Each module has its own playground, a cluster where Flux is already bootstrapped. The landing page starts the playground for you.

### 1. Onboard Tenants With Impersonation

1. Platform Administrators, Tenants And Their Repositories
2. Impersonation With spec.serviceAccountName
3. Locking Down The Cluster For Tenants, followed by the lab **Onboard A Locked-Down Tenant**
4. Impersonation In HelmReleases And Other Objects
5. Reading And Fixing A Refused Tenant
6. Summary

### 2. Guardrails And Secrets For Tenants

1. Choosing The Role Of A Tenant
2. Quotas And Limits Per Tenant, followed by the lab **Give A Tenant Fewer Rights And A Quota**
3. Network Isolation And Tenant Secrets
4. Onboarding And Offboarding Many Tenants
5. Summary

### 3. Governing Tenants With Repositories And Policy

1. Repository Layouts For Many Teams
2. Git Permissions And Verified Sources
3. Admission Policy For Flux Objects, followed by the lab **Reject Flux Kustomizations Without A ServiceAccount**
4. Auditing What Tenants Run
5. Summary

## Section capstone: Repair A Tenant That Cannot Deploy

The capstone is one graded scenario on a locked-down cluster. The tenant `team-a` deploys without trouble. The tenant `team-b` was onboarded in a hurry, and its Flux `Kustomization` is refused for three different reasons. You must find all three from the object's status and events and fix them in Git, without weakening the lockdown and without giving `team-b` any cluster-wide right. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/section-010/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-099-capstone-010
```
