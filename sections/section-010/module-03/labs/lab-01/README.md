---
estimated_duration: 30m
---

# Reject Flux Kustomizations Without A ServiceAccount

- **ID:** LAB
- **Slug:** ats-099-lab-010-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded lab

Starting state: Flux bootstrapped from gitops/fleet with podinfo, and the public tenant repository gitops/team-a. The tenant team-a is onboarded through gitops/fleet. The cluster needs Kubernetes 1.30 or later. Read `question.md` for the task; `solution.md` is the walkthrough.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-099-lab-010-03
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-099-lab-010-03`), not
the config path. The graders run `flux` and `kubectl` on this machine and call
the Gitea API from the `tester` pod.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition, bootstrap and grading |
| `question.md` | The task |
| `solution.md` | Step-by-step walkthrough |
| `prerequisites.md` | Assumed knowledge and what the environment provides |
| `bootstrap/01-install-git-and-flux.sh` | Shared: Flux CLI, Gitea, CoreDNS rewrite, repositories, `flux bootstrap git` |
| `bootstrap/02-seed-state.sh` | The starting state of this lab |
| `manifests/` | `lab-start.yaml` and the files seeded into the Git repositories |
| `solution/apply.sh` | Reference solution used by `astrona test` |
| `testing/wait-for-flux.sh` | Waits for Gitea and the Flux controllers before the reference solution |
| `validation/` | Grading scripts, one per check |
