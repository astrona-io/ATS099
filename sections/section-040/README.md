# Section 040: Disaster Recovery

GitOps promises that Git holds the desired state of the cluster. That promise is tested on the worst day: Flux was removed by mistake, the `flux-system` namespace was deleted, or the whole cluster is gone. On that day you find out what Git really holds, what it does not, and whether you can bring everything back in the right order without breaking what still runs.

This section practises that day. It lists what lives outside Git. It shows how to pause Flux for maintenance, and how to uninstall and reinstall Flux without touching a single running workload. It covers backing up the Secrets and keys that Git does not hold, and restoring them. It also covers upgrading and tuning Flux itself through Git, and it ends with rebuilding a cluster from Git, with the Secrets restored before Flux needs them.

**Topic covered:** Disaster recovery

## What you will learn

- What Git holds and what it does not: Git credentials, kubeconfigs, encryption keys, tenant Secrets and data in volumes.
- Pausing every Flux `Kustomization` with `flux suspend kustomization --all`, and why a suspend committed to Git outlives the maintenance window.
- What `flux uninstall` removes, what it leaves, and what `--keep-namespace` changes.
- Reinstalling Flux with `flux bootstrap` and proving that the running workloads were adopted, not recreated.
- The order for rebuilding a lost cluster from Git, how to triage a broken installation, and how to set and rehearse recovery objectives.
- Which items to back up, how to export Secrets as manifests that can be applied again, why the decryption key is the most important item, and how to test a restore.
- Where the Flux version comes from, how to upgrade through Git and roll back, how to tune controller concurrency and memory with patches, and how to watch the controllers.

## The learning path

The section has three modules. Each has a landing page, short parts, a graded lab right after the part it tests, and a summary. Each module has its own playground, a cluster where Flux runs from `gitops/fleet`. The landing page starts the playground for you.

### 1. Recover A Cluster From Git

1. What Git Holds And What It Does Not
2. Suspend, Uninstall And Reinstall Flux, followed by the lab **Reinstall Flux Without Touching The Workloads**
3. Rebuilding A Lost Cluster
4. Reading The State Of A Broken Flux Installation
5. Recovery Objectives And Drills
6. Summary

### 2. Backing Up What Git Does Not Hold

1. What To Back Up And What To Leave
2. Exporting Secrets And Flux Objects Safely
3. Keys For Encrypted Secrets
4. Restoring And Checking A Backup, followed by the lab **Restore Secrets From An Exported Backup**
5. Summary

### 3. Upgrading And Tuning Flux

1. Where The Flux Version Comes From
2. Upgrading Flux Through Git
3. Tuning The Controllers, followed by the lab **Tune kustomize-controller Through Git**
4. Watching The Controllers
5. Summary

## Section capstone: Bring Flux Back After A Lost flux-system Namespace

The capstone is one graded scenario. Flux was uninstalled together with its namespace, and every Secret in `flux-system` went with it, including the credential for a second, private repository. A maintenance window that suspended podinfo through Git was never closed. You must bring Flux back, restore what Git does not hold, end the maintenance window through Git, and prove that every workload kept running as the same object. Work it after the module lab.

Start the capstone:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/section-040/capstone/labs/lab-01
```

When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-040/capstone/labs/lab-01
```

When the capstone is done, remove it:

```sh
astrona destroy ats-099-capstone-040
```
