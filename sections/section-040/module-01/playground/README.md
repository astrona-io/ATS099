# Recover A Cluster From Git — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-099-playground-040-01
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A sandbox that spins up a `kind` cluster, starts Gitea, seeds the repositories,
bootstraps Flux 2.9.6 and waits, so you can explore the module's topic.
Flux bootstrapped from gitops/fleet with podinfo. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-099-playground-040-01
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-099-playground-040-01`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (bootstrap only) |
| `bootstrap/prepare.sh` | Flux CLI, Gitea, CoreDNS rewrite, repositories, `flux bootstrap git` |
| `manifests/` | `lab-start.yaml` and the files seeded into the Git repositories |
| `docs/overview.md` | What the environment contains and ideas to try |
