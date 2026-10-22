# ATS099 — Multi-Tenancy, Enterprise Operations & Cluster Management (FluxCD)

Course material for the **Multi-Tenancy, Enterprise Operations & Cluster
Management** domain of the Astrona FluxCD training path
([ATP019](https://github.com/astrona-io/ATP019)), which is **15% of the
path**. Written for **Flux v2.9.6**.

> **Status: draft, not yet run.** Every page, playground and lab was written
> from the Flux v2.9 documentation. None has been started on a cluster, and
> no lab has passed `astrona test` yet. See `CLAUDE.md`.

The course opens with an Introduction in `sections/intro/` (welcome, machine setup,
how the course is made). Everything else lives under `sections/`. Each section
contains:

- **Modules** — a reading chapter split into a short landing page, ordered
  deep-dive parts and a summary page, a throwaway **playground** to explore in,
  and a graded **lab** placed right after the part it tests.
- **A capstone** — one larger graded lab combining that section's module into a
  single scenario with several independent faults.

---

## Sections

| Section | Title | Modules | Labs | Topic |
| --- | --- | --- | --- | --- |
| [010](sections/section-010) | Multi-Tenancy With Impersonation | 1 | 1 + capstone | Multi-tenancy |
| [020](sections/section-020) | Alerting And Monitoring | 1 | 1 + capstone | Alerting and monitoring |
| [030](sections/section-030) | Cross-Namespace References And Remote Clusters | 1 | 1 + capstone | Remote clusters |
| [040](sections/section-040) | Disaster Recovery | 1 | 1 + capstone | Disaster recovery |

The order follows the life of a shared platform. Section 010 makes one
cluster safe for several teams. Section 020 makes failures visible. Section
030 reaches beyond one namespace and one cluster. Section 040 brings it all
back after a loss, which only works when everything before it lives in Git.

---

## Modules

| Module | Reader | Parts | Labs |
| --- | --- | --- | --- |
| 010-01 | [Onboard Tenants With Impersonation](sections/section-010/module-01/course.md) | 3 | [lab-01](sections/section-010/module-01/labs/lab-01) |
| 020-01 | [Send Flux Events To Webhooks And Chat](sections/section-020/module-01/course.md) | 3 | [lab-01](sections/section-020/module-01/labs/lab-01) |
| 030-01 | [Deliver To Other Namespaces And Clusters](sections/section-030/module-01/course.md) | 3 | [lab-01](sections/section-030/module-01/labs/lab-01) |
| 040-01 | [Recover A Cluster From Git](sections/section-040/module-01/course.md) | 3 | [lab-01](sections/section-040/module-01/labs/lab-01) |

---

## Capstones

| Capstone | Scenario | Faults |
| --- | --- | --- |
| [010](sections/section-010/capstone/labs/lab-01) | Repair A Tenant That Cannot Deploy | no impersonated ServiceAccount, a RoleBinding for the wrong namespace, a cross-namespace source |
| [020](sections/section-020/capstone/labs/lab-01) | Find Why No Alert Arrives | a wrong receiver address, the wrong event source, a catch-all exclusion |
| [030](sections/section-030/capstone/labs/lab-01) | Repair A Broken Remote Cluster Connection | the wrong Secret key, the wrong API server port, a Role without Services |
| [040](sections/section-040/capstone/labs/lab-01) | Bring Flux Back After A Lost flux-system Namespace | Flux and its namespace gone, a lost Git credential, a forgotten suspend |

---

## The lab environment

Every playground and lab is a **kind** cluster with an in-cluster Git server
(Gitea, `gitea/gitea:28.2.0-rootless`), the Flux CLI 2.9.6 on the machine,
and Flux **already bootstrapped** from `gitops/fleet` at `clusters/kind`, with
`podinfo` deployed. A webhook receiver (`mendhak/http-https-echo:42`) runs in
the namespace `monitoring` everywhere.

The repository address is `http://gitea.localtest.me:3000/gitops/fleet.git`
everywhere: on the reader's machine through
`kubectl -n gitea port-forward svc/gitea-http 3000:3000`, and inside the
cluster through a CoreDNS rewrite added by the bootstrap. Credentials are the
lab-only `gitops` / `gitops-password`.

The shared plumbing (`bootstrap/01-install-git-and-flux.sh`,
`testing/wait-for-flux.sh`, `manifests/lab-start.yaml`, the seeded repository
files, `config.yaml` and the author READMEs) is the same in every environment.
Change it everywhere at once.

## Running a playground

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/<section>/<module>/playground
astrona destroy <name>
```

## Running a lab

Labs and capstones are graded. Read `question.md`, do the work, and submit:

```bash
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/<section>/<module>/labs/lab-01
astrona submit -c sections/<section>/<module>/labs/lab-01
astrona destroy <name>
```

Each lab grades the **final cluster and Git state** with independent checks,
and several of them deliberately reject the plausible-but-wrong fix (a
ClusterRoleBinding for a tenant, removing the lockdown, an Alert that forwards
every event, a kubeconfig with cluster-wide rights, recreating workloads
during recovery).
