# Welcome To The Course

This course trains you for the **Multi-Tenancy, Enterprise Operations & Cluster Management** part of the Astrona **FluxCD** training path. That part is 15% of the path. This page tells you who the course is for, what you can do at the end, which words and example setup it uses, and how its pages fit together.

## Who this course is for

You already run Flux. You know what a `GitRepository` and a Flux `Kustomization` are, you have bootstrapped Flux into a cluster, and you can push a change to Git and watch Flux apply it. You know Kubernetes role-based access control (RBAC): ServiceAccounts, Roles, ClusterRoles and their bindings. Each new idea in this course is explained the first time it appears.

## What you can do at the end

This course is about running Flux for more than one team and more than one cluster, and keeping it running when something breaks. It asks you to change Git, watch Flux act, and prove the result. The course has four topics, and each one turns into a set of skills you will practise.

The first topic is **multi-tenancy with impersonation**. You will learn to:

- Give a team its own namespace, ServiceAccount and Git repository on a shared cluster.
- Make Flux apply a team's files as that team's ServiceAccount, so Kubernetes RBAC limits what the team can change.
- Lock the Flux controllers down so one team cannot reach another team's sources or create cluster-wide objects.

A shared platform needs to tell people when something fails, so the second topic is **alerting and monitoring**. You will learn to:

- Send Flux events to a webhook, Slack or Microsoft Teams with a `Provider` and an `Alert`.
- Choose which events become alerts, by object, by severity and by message.
- Read the Prometheus metrics the Flux controllers export.

The third topic is **cross-namespace references and remote clusters**. You will learn to:

- Explain when a Flux object may use a source in another namespace.
- Make Flux apply to another cluster through a kubeconfig stored in a Secret, with an account that has narrow rights.
- Explain how Cluster API hands Flux the kubeconfig of every cluster it creates.

The fourth topic is **disaster recovery**. You will learn to:

- List what Git holds and what it does not, such as Git credentials and other Secrets.
- Uninstall and reinstall Flux without touching the running workloads.
- Bring a cluster back from Git in the right order after its `flux-system` namespace is lost.

Everything is written for **Flux v2.9.6**.

## The words this course uses

The pages use Flux's, Git's and Kubernetes' own terms, because those are the words you meet in the product, the logs and the documentation. Each term gets a short, plain definition the first time it appears on a page. A few terms come back on almost every page, so here they are up front.

A **tenant** is a team that gets its own namespaces and its own Git repository on a shared cluster, and may change nothing else. The **platform administrator** owns the cluster and the repository Flux was bootstrapped from. **Impersonation** means that a Flux controller acts as another ServiceAccount when it applies files, so Kubernetes RBAC decides what it may change. An **event** is a short record that a Flux controller writes about one object, with a severity of `info` or `error`.

Two Flux objects come back on almost every page:

| Object | What it does |
| --- | --- |
| `GitRepository` | Tells source-controller which Git repository and branch to fetch, and how often |
| Flux `Kustomization` | Tells kustomize-controller which folder of that repository to apply, as which ServiceAccount, and to which cluster |

The Flux `Kustomization` object is not the same thing as the Kustomize file `kustomization.yaml`, even though the names are alike. The pages always say which one you mean.

## The example setup in your playground

Every playground and lab runs the same small setup. A Git server called Gitea runs inside the cluster, in the namespace `gitea`. It holds the platform repository `gitops/fleet`, and Flux is already bootstrapped from it when the playground starts. Flux deploys the demo application `podinfo`, a small web server, into the namespace `podinfo`.

Some modules add more. Tenants have their own repositories, `gitops/team-a` and `gitops/team-b`. A webhook receiver in the namespace `monitoring` writes every request it gets to its log, so you can see the alerts Flux sends. A `tester` pod sends requests to Gitea and to the applications.

You work with the repositories from your own machine: you clone, change a file, commit and push, and then watch Flux apply the change. Many labs start with something broken on purpose. That is the material, not a fault in the course.

## How the course is laid out

The course has four sections. It starts with sharing one cluster safely, then shows how to know when something fails, reaches out to other clusters, and ends with bringing everything back after a loss.

| Section | What it covers |
| --- | --- |
| 010 | Multi-Tenancy With Impersonation |
| 020 | Alerting And Monitoring |
| 030 | Cross-Namespace References And Remote Clusters |
| 040 | Disaster Recovery |

Each section has one or more **modules**, and each module teaches one skill. A module brings together four kinds of material:

| What | What it is for | Graded? |
| --- | --- | --- |
| **Reading** | A short landing page, a few chapters that teach one idea each, and a summary | No |
| **Playground** | A small cluster on your own machine, to try everything you read | No |
| **Lab** | A cluster in a starting state, a task, and a grader that checks your work | Yes |
| **Capstone** | The last lab in a section, with several faults at once | Yes |

The best order is simple: read the chapters with the playground open next to them, take each lab when a chapter sends you to it, and finish each section with its capstone. The next part of this page explains how a module's pages guide you through that order.

## How to read a page

A module starts with a **landing page**. It says what the module teaches, what you should know first, and the order of its chapters. At the bottom of the landing page you start the module's playground, and you keep it running while you read.

The chapters (the parts of a module) read like the chapters of a technical book. Each one opens with the problem it solves, explains one idea in connected paragraphs, and closes with what you now know. The hands-on steps sit right in the text: a sentence or two on what to run and why, the command, and then what the result shows. Run each step in your playground as you reach it. You learn more from one real result than from a page of text.

Every chapter ends with a box of common pitfalls, the mistakes people make most often with what the chapter taught, and how to spot them. Now and then a page also has a tip box with a habit or shortcut you can use again, well beyond that page. The two boxes look like this:

> [!TIP]
> **A tip.** A habit or shortcut you can use again, well beyond this one page.

> [!WARNING]
> **Common pitfalls.** The mistakes people make most often with what you just learned, and how to spot them. Every chapter ends with one.

When a graded lab tests what a chapter taught, that chapter ends with a **Your mission** section. It tells you what the lab asks, then gives every command you need, in order: pause the playground with `astrona stop`, start the lab with `astrona run`, and send your work for grading with `astrona submit`. Solve the lab on your own before you look at its solution. When the lab is done, remove it with `astrona destroy` and start the playground again with `astrona start`, so you can carry on reading where you left off.

The last page of every module is the **Summary**. It sums up what you learned in a few short paragraphs, organised by idea. It also ends the module's hands-on work: the Summary page removes the playground, so your machine is clean before the next module.

One rule holds on every page. Code blocks are exactly what you type. Never change a command to make it "look right". If the result is different from what the page describes, that difference is the lesson.
