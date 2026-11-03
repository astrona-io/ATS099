# Repository Layouts For Many Teams

The first design choice in a shared cluster is how many Git repositories to use and who owns each. The choice decides who can change what, how large the history grows, and how much work it is to add a team. This part compares the three common layouts and shows the layout the course uses.

## One repository for everything

In a **monorepo**, the platform files and every tenant's files live in one repository, in separate folders. Reading and searching is easy, and one pull request can change a platform file and a tenant file together.

The cost is access control. Git hosts set permissions per repository or per branch, and path-level control is limited to features such as code owners. A tenant with write access to the repository can change another tenant's folder unless a rule blocks it. For this reason a monorepo suits small organisations where all teams trust each other.

## One repository per tenant

In the layout this course uses, the platform team owns one repository, `fleet`, and each tenant owns its own repository, such as `team-a`. Flux reads the platform repository for the cluster and tenant objects and reads each tenant repository only through that tenant's `GitRepository` and `Kustomization`.

Git permissions now match ownership. The tenant can push to its repository and cannot touch the platform repository. The platform team can see all repositories. The cost is more repositories, and a cluster change that spans two teams needs two commits in two places.

## One repository per environment

A third axis is the environment: `staging` and `production`. Some teams keep one repository per environment, others keep one repository with a branch or a folder per environment. A folder per environment is easier to compare, because a pull request shows the exact difference. A branch per environment hides drift, because two branches can differ in ways nobody reviews.

With a folder per environment, one `Kustomization` in each cluster points at its own folder, for example `clusters/staging` and `clusters/production`. The tenant repository then uses a Kustomize base and one overlay per environment.

## A layout for the platform repository

The platform repository holds three kinds of content: cluster definitions, tenant onboarding and shared infrastructure. A simple shape separates them:

```text
fleet/
  clusters/
    kind/
      flux-system/
      tenants.yaml
      infrastructure.yaml
  infrastructure/
    policies/
    controllers/
  tenants/
    base/
    team-a/
    team-b/
```

Each `clusters/<name>` folder holds the Flux objects that apply the other folders for that cluster. `infrastructure/` holds what every tenant depends on, such as policies and ingress controllers. `tenants/` holds one folder per tenant. The cluster folder is the only place that decides what runs on which cluster.

## Order of applying

The tenant objects need the policies and controllers to exist first. A Flux `Kustomization` can say so with `spec.dependsOn`. The `tenants` object waits until `infrastructure` is `Ready`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: tenants
  namespace: flux-system
spec:
  interval: 5m
  dependsOn:
    - name: infrastructure
  serviceAccountName: kustomize-controller
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./tenants
  prune: true
```

`dependsOn` makes the controller wait. It does not start `infrastructure` itself, so `infrastructure` must exist as its own Flux `Kustomization` in the same namespace unless cross-namespace references are allowed.

## Inspect the layout of the playground

Clone the platform repository and read its tree:

```sh
git clone http://gitea.localtest.me:3000/gitops/fleet.git
cd fleet
find . -path ./.git -prune -o -type f -print | sort
```

The list shows `clusters/kind/flux-system`, `clusters/kind/tenants.yaml`, `clusters/kind/podinfo.yaml`, `apps/podinfo` and `tenants/team-a`. The tenant's own files are not here, because they live in `gitops/team-a`.

## Common pitfalls

> [!WARNING]
> - **Letting a tenant write to the platform repository.** The tenant then controls its own RoleBinding.
> - **Using a branch per environment without review rules.** Drift between branches goes unseen.
> - **Writing `dependsOn` for an object that does not exist.** The waiting object stays `Ready` `False` forever.
> - **Mixing infrastructure and tenant objects in one folder.** One failed object then blocks both.
