# Section 040: Disaster Recovery

GitOps promises that Git holds the desired state of the cluster. That promise is tested on the worst day: Flux was removed by mistake, the `flux-system` namespace was deleted, or the whole cluster is gone. On that day you find out what Git really holds, what it does not, and whether you can bring everything back in the right order without breaking what still runs.

This section practises that day. It lists what lives outside Git. It shows how to pause Flux for maintenance, and how to uninstall and reinstall Flux without touching a single running workload. It ends with rebuilding a cluster from Git, with the Secrets restored before Flux needs them.

**Topic covered:** Disaster recovery

## What you will learn

- What Git holds and what it does not: Git credentials, kubeconfigs, encryption keys, tenant Secrets and data in volumes.
- Pausing every Flux `Kustomization` with `flux suspend kustomization --all`, and why a suspend committed to Git outlives the maintenance window.
- What `flux uninstall` removes, what it leaves, and what `--keep-namespace` changes.
- Reinstalling Flux with `flux bootstrap` and proving that the running workloads were adopted, not recreated.
- The order for rebuilding a lost cluster from Git.

## The learning path

The section has one module. It has a landing page, three short parts, a graded lab right after the part it tests, and a summary. The module has its own playground, a cluster where Flux runs podinfo from `gitops/fleet`. The landing page starts the playground for you.

### 1. Recover A Cluster From Git

1. What Git Holds And What It Does Not
2. Suspend, Uninstall And Reinstall Flux, followed by the lab **Reinstall Flux Without Touching The Workloads**
3. Rebuilding A Lost Cluster
4. Summary

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
