# Upgrading And Tuning Flux — Playground

- **ID:** PLAYGROUND
- **Slug:** ats-099-playground-040-03
- **Author:** Paris Nakita Kejser
- **Type:** Astrona playground — clean environment, no task, no grading

A sandbox that spins up a `kind` cluster, starts Gitea, seeds the repositories,
bootstraps Flux 2.9.6 and waits, so you can explore the module's topic.
Flux bootstrapped from gitops/fleet. The Flux manifests are in clusters/kind/flux-system/ in the repository. kustomize-controller runs with its default arguments and its default memory limit. Nothing to submit.

## Run it

```sh
astrona run -c .
astrona destroy ats-099-playground-040-03
```

`astrona destroy` takes the environment name (`metadata.name` = `ats-099-playground-040-03`), not
the config path. `astrona submit` and `astrona test` do not apply — there is no
grading.

## Layout

| Path | Purpose |
| --- | --- |
| `config.yaml` | Environment definition (bootstrap only) |
| `bootstrap/prepare.sh` | Flux CLI, Gitea, CoreDNS rewrite, repositories, `flux bootstrap git` |
| `manifests/` | `lab-start.yaml` and the files seeded into the Git repositories |
| `docs/overview.md` | What the environment contains and ideas to try |
