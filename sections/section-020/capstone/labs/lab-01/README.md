---
estimated_duration: 35m
---

# Find Why No Alert Arrives

- **ID:** CAPSTONE
- **Slug:** ats-099-capstone-020
- **Author:** Paris Nakita Kejser
- **Type:** Astrona graded capstone

Starting state: Flux bootstrapped from gitops/fleet with podinfo, the webhook receiver, and a Provider and an Alert in Git that deliver nothing. Read `question.md` for the task; `solution.md` is the walkthrough.

## Run it

```sh
astrona run -c .
astrona submit
astrona destroy ats-099-capstone-020
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-099-capstone-020`), not
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
| `bootstrap/02-seed-state.sh` | The starting state of this capstone |
| `manifests/` | `lab-start.yaml` and the files seeded into the Git repositories |
| `solution/apply.sh` | Reference solution used by `astrona test` |
| `testing/wait-for-flux.sh` | Waits for Gitea and the Flux controllers before the reference solution |
| `validation/` | Grading scripts, one per check |
