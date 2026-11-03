# Recovery Objectives And Drills

A recovery plan needs numbers and rehearsal. Without numbers nobody knows whether the plan is good enough. Without rehearsal the plan is a guess.

## Two numbers

- **Recovery time objective (RTO).** How long the service may be without delivery or without a cluster before the cost is too high.
- **Recovery point objective (RPO).** How much data may be lost, measured in time. An RPO of one hour means the newest backup is at most one hour old.

They are set by the business, not by the tools. The tools decide whether they can be met. Flux affects the first number: with the keys at hand, a cluster rebuilt from Git takes the time of `flux bootstrap` plus the time the workloads need to start. Flux does not affect the second number at all, because it does not hold data.

## Different failures, different targets

| Failure | What is lost | Recovery |
| --- | --- | --- |
| Flux removed or broken | Delivery only; workloads run | Reinstall Flux from Git |
| `flux-system` namespace deleted | Flux and its Secrets | Restore Secrets, bootstrap again |
| One cluster lost | Cluster, workloads, data | Rebuild from Git, restore data from backup |
| Git server lost | The source of truth | Restore Git from its own backup or from a clone |

The last line matters. Every developer's clone is a copy of the repository, but a clone is not a backup plan. Back up the Git server on its own schedule.

## A runbook

A runbook turns the plan into steps that a person can follow at night. It should have:

- The order of the steps, with the commands.
- Where each credential and key lives, and who can read it.
- How to check that each step worked.
- Who decides to start the recovery, and who to tell.

Keep the runbook outside the cluster that it recovers.

## A drill

Run the recovery on a throwaway cluster from the same repository:

1. Start a stopwatch.
2. Follow the runbook exactly, without help from memory.
3. Write down every step that failed or was missing.
4. Stop the stopwatch when every Flux object is `Ready` and the workloads answer.
5. Fix the runbook, and fix anything in Git that caused a surprise.

Compare the time with the RTO. Run the drill again after a large change, such as a new secret store, a new cluster version, or a new person who may be on call.

## Common pitfalls

> [!WARNING]
> - **A runbook stored in the cluster it recovers.** It is gone when you need it.
> - **A plan with no numbers.** Nobody can say whether a drill passed.
> - **Counting Flux as a backup of data.** It restores objects, not bytes.
> - **One person who knows the steps.** Rotate who runs the drill.
