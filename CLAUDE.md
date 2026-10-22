# Writing style for this repo

All study text here (course pages, lab docs, READMEs, comments in YAML and
scripts) is for people learning a technical subject, often for a
certification exam. Many of them are not native English speakers and have no
university degree.

## Technical documentation in plain English

This is technical documentation. Say exactly what the system does, with the
real technical terms, in clear and simple English. Never hide a concept
behind a metaphor, a made-up name or a vague word: the reader must learn the
words they will meet in the product, the logs and the exam.

Strict guidelines:

1. Use the correct technical term every time (request, response, pod,
   namespace, Service, sidecar proxy, certificate, mTLS, JWT, listener). The
   first time a term appears in a file, define it in one plain sentence that
   says what it is and what it does. Spell out every acronym on first use.
2. No metaphors or analogies in explanations. Not "the communications
   officer", but "the sidecar proxy (Envoy)"; not "a signal", but "a
   request"; not "the planet", but "the namespace".
3. Simple sentences. Target a Flesch-Kincaid Grade Level of 8 or 9 for the
   prose around the terms. Keep sentences direct; split long sentences into
   two. No corporate buzzwords.
4. Use short paragraphs (max 3-4 sentences per paragraph).
5. Use the active voice ("istiod sends the configuration", not "the
   configuration is sent").

## How this applies to course material

- **Know which file you are in.** A module has a short landing page, a few
  deep-dive parts and a summary page. The landing page is a map: goals, what
  to know first, the order of the parts. The real teaching goes in the parts.
  The summary closes the module. A lab
  has a task, a step-by-step solution and a short intro. Keep each file to its
  job. Do not add "Prerequisite: ... Next: ..." navigation lines to pages;
  the landing page and the course outline already give the order.
- **Keep each part short.** One idea per part, about 5 to 8 minutes of
  reading and at most about 8 command blocks, so a learner can finish it with
  the playground in one sitting of about 15 minutes. Split at a natural seam
  where each half ends with something the learner has seen work. Never split
  only to hit a number. When you split, renumber the files, fix every "Part N"
  reference in the module and `astrona.yaml`.
- **Read like a book, not like a web page.** Each part reads as a chapter of
  a technical book. Open with a short paragraph on the problem it solves and
  why it matters. Link each paragraph to the next with a transition sentence.
  Close with a paragraph that sums up what the reader now knows and the
  question still open, before `## Common pitfalls` and the mission. Write
  explanations as prose; keep bullets for real lists (fields, ordered steps,
  options). Use `##` only when the topic changes and `###` only inside a long
  section, never for a single command. Weave hands-on steps into the text:
  one or two sentences on what to run and why, the command, the real output,
  then a sentence or two on what it shows.
- **The module ends with a summary.** The last page of every module is
  `course-0N-summary.md` with the title `# Summary`: a few short prose
  paragraphs on what the reader learned, organised by idea, optionally with
  one short list of key facts. It names no parts, modules, sections or
  chapters, and has no links, lab table, quiz or commands. Its last line is
  `<!-- astrona:playground:destroy -->` on its own line; the platform turns it
  into the step that removes the playground.
- **Every heading gets an intro.** A `##` section that has `###`
  subsections starts with one to three sentences that say what the section
  is about and why it matters, before the first `###`. Never put a `###`
  directly under a `##`.
- **Every module stands on its own.** Never refer to other sections or
  modules: no "see section 040", "as module 3 showed", "you met this in
  section 000", and no links to pages in another module. If the reader needs
  a fact from elsewhere, state the fact directly in one or two sentences.
  This also goes for parts of the same module: never write "Part 2 shows",
  "from Part 1" or "as in Part 3". Say the fact itself ("the commands below
  need the `scout` `DestinationRule` applied"). This includes the summary.
  The landing page does not have a "Where this fits" section.
- **Write words out in full.** Do not use informal short forms in prose:
  write "communications", "configuration", "repository", "administrator",
  "for example" and "that is", never "comms", "config", "repo", "admin",
  "e.g." or "i.e.". Names in code, commands and file paths stay as they are.
- **Exam terms stay.** The product's own names are what the reader must learn
  (for example a resource kind, a field, a command). Use them as they are and
  define each one in plain technical words the first time it appears in a
  file. Spell out acronyms on first use, with a short plain meaning.
- **The space theme is only for examples.** Space appears in two places and
  nowhere else: the names of the example workloads (the Starfleet: `bridge`,
  `scout`, `shuttle`, `probe`, the `starfleet` and `outpost` namespaces) and
  the short scenario that opens a lab task or a practice exercise (for
  example "the `drifter` in `outpost` must keep reaching the probe"). The
  explanation around an example is plain technical text: write "the
  `shuttle` pod sends a request to the `probe` Service", never "the shuttle
  sends a signal to the probe ship". Do not address the reader as an
  astronaut, and do not use space metaphors (communications officer, mission
  control, badge, airlock, guest list, star chart) for Istio or Kubernetes
  concepts. Titles of pages and labs name the technical task ("Require mTLS
  With PeerAuthentication"), not a space story.
- **Show one real example before the rule.** Start with a concrete case the
  reader can run, then give the general rule.
- **Say which part does the work.** Readers often mix up the parts of a system
  that sit close together. Whenever something happens, say which component
  did it.
- **Never change code to fit the style.** Commands, configuration files, field
  names, resource names, log lines and command output stay exactly as they
  are. They were run and checked on a real system. Never make up command
  output. If you shorten it, say that you did.
- **Prose only.** The grade-level and sentence rules apply to explanations.
  They do not apply to code blocks, tables of field names or reference lists
  (those may stay short and dense).
- **Keep the page furniture the same.** Hands-on steps are part of the prose
  (see "Read like a book"), not boxes or headings of their own. A `> [!TIP]` box is
  only for a real tip: advice the reader can reuse beyond this one step (a
  habit, a shortcut, how to spot a problem, an exam habit). Everything else
  is a normal sentence: notes about the current step ("if the log line is
  old, run it again"), background facts, optional extra steps, and plain
  information. Never a command snippet, never two in a row, and most pages
  need zero or one tip. Each part ends with a
  `## Common pitfalls` `> [!WARNING]` block for that part only. Use a Mermaid
  diagram for a flow, an order or a state change, keep it under about 12
  boxes, and follow it with one sentence that says what it shows.
- **Labs come right after the part they practise.** Do not collect all
  graded labs at the end of a module. In `astrona.yaml`, put each lab (its
  `question.md` reading and the `lab` entry) right after the reading part it
  tests. If a part teaches a gradeable skill and no lab covers it, create a
  new lab. That part then ends with a `## Your mission: <lab title>` section:
  one sentence on what the reader can now do, one on what the mission asks,
  then pause the playground (`astrona stop <playground name>`), the
  `astrona run` and `astrona submit` commands, and finally
  `astrona destroy <lab name>` plus `astrona start <playground name>`.
- **Renew the playground before hands-on work.** Every reading part that
  runs commands has `<!-- astrona:playground:renew -->` exactly once, on its
  own line, right before the first hands-on step (the first "Save this as"
  or the first command block), so the playground timer is reset before the
  learner needs the playground. Not on landing pages (they carry
  `<!-- astrona:playground -->`), summary pages (they carry
  `<!-- astrona:playground:destroy -->`) or pages without commands.
- **Mermaid without HTML.** The platform renders Mermaid with HTML labels
  switched off, so `<br/>` and any other HTML tag break the drawing. Rules:
  - One line per box, no `<br/>`, no HTML. Keep the box to the thing's name
    (`"scout-v2"`, `"istiod"`, `"Service: scout"`).
  - Put the logic on the arrows: `E -->|"version: v2"| P2`,
    `I -->|"CDS"| C`, `A -->|"end-user: jason"| B`. Keep edge labels short.
  - Quote every label. Prefer `flowchart TB`; use `LR` only for a short chain.
  - Sequence diagrams: short participant aliases (`participant S as shuttle`)
    and short message text.
  - Anything longer (cluster names, full hostnames) goes in the sentence under
    the diagram.
- **Every course starts with an Introduction.** It lives in `sections/intro/`
  and is the first entry in `astrona.yaml` (`id: module-intro`, title
  "Introduction"). It has exactly these four pages, in this order:
  - `README.md`, `# Introduction`: what the introduction covers and its three
    pages, named in prose (no links), ending with the topic the course starts
    with.
  - `course-01-welcome.md`, `# Welcome To The Course`: who the course is for,
    the exam domain and what the reader can do at the end, the words the
    course uses, the example app, how the course is laid out and how to read
    a page.
  - `course-02-get-your-machine-ready.md`, `# Get Your Machine Ready`: the
    tools to install, the `astrona` commands used every day, and what to do
    when a start goes wrong.
  - `course-03-how-this-course-is-made.md`, `# How This Course Is Made`: how
    content is written and checked, the maintainers, how to report a mistake,
    and the license.
  The Introduction teaches no product content and has no playground, labs or
  summary. Its only links are the repository's contributors page, issues
  page and license.
- **No links to other course files.** A course page (every reading listed in
  `astrona.yaml`, the playground guide `docs/overview.md`, and a lab's
  `question.md` and `solution.md`) never links to or points the reader at
  another page or file of the repository: no links to parts, summaries,
  labs, `question.md`, other modules, sections or the Introduction, and no
  "see `practice.md`" or "open `config.yaml`". The platform shows the pages in
  the order of `astrona.yaml`, so a link only adds a second, often wrong,
  path. Name a thing in plain words when the reader needs it ("the task is on
  the next page"), and state a fact on the page itself instead of sending the
  reader somewhere else. Repository files for authors (the root `README.md`,
  a lab's or playground's `README.md`) may link.
- **No links to outside sources.** Course pages, labs and playground docs do
  not link to or point at outside websites (the one exception is the
  `resources` field of a lab entry in `astrona.yaml`) (official docs, GitHub, blogs,
  RFCs), and they have no "Reference" or "Official docs" lists. Everything the
  reader needs is explained on the page itself. Not affected: addresses the
  reader actually uses in a command or browser (`http://127.0.0.1:9080`,
  `curl https://httpbin.org`), and the Introduction's contributors and
  "report a mistake" links.
- **Configuration goes to a file first.** Whenever the reader should apply
  YAML (course parts, playground docs, labs), use three separate steps:
  1. "Save this as `virtualservice-scout.yaml`:" followed by a plain
     ` ```yaml ` block with only the YAML. No `cat > file <<'EOF'`, no
     `kubectl apply -f - <<EOF`, no shell around it.
  2. "Apply it:" followed by a ` ```sh ` block with only
     `kubectl apply -f virtualservice-scout.yaml`.
  3. "Then check the result:" followed by the check commands, if any.
  The file name says the kind and the object. If a value must come from the
  reader's cluster (an IP address), use a placeholder like `<PARTNER>` in the
  YAML and say how to get the value (`echo $PARTNER`); never put shell
  variables inside YAML. Apply an object the first time its YAML appears; do
  not show it once "to read" and paste it again later. Never tell the reader
  to apply something from the playground's `examples/` folder: they start the
  playground with `astrona run`, so that folder is not on their machine.
- **Helpers have readable names.** Shell helper functions and variables use
  names that say what they do (`check_route`, `count_versions`,
  `$SERVICE_URL`), never single letters.


## About this repo (ATS099 only)

Everything above is general and can be copied to other course repositories. This
section is only true for this one.

### What the student is trying to learn

- **The goal:** master the **Multi-Tenancy, Enterprise Operations & Cluster
  Management** domain of the **FluxCD** training path (`ATP019`). It is 15% of
  the path. There is no official Flux certification exam; the path's domains
  and weights are Astrona's own, set in `ATP019/path.yaml`.
- **What the domain really tests:** running Flux for several teams and
  several clusters, and keeping it running. The student must *do* things
  (onboard a tenant that can only touch its own namespace, lock the
  controllers down, send Flux events to a webhook, read controller metrics,
  apply to another cluster through a kubeconfig, uninstall and reinstall Flux
  without touching the workloads). Every explanation should lead to a command
  they can run, and every fix should be proved with an object that becomes
  `Ready`, a request that is refused, or an event that arrives.
- **The four topics:** multi-tenancy with impersonation, alerting and
  monitoring, cross-namespace references and remote clusters, and disaster
  recovery.
- **The sections:**

  | Section | Title | Topic |
  | --- | --- | --- |
  | 010 | Multi-Tenancy With Impersonation | Multi-tenancy |
  | 020 | Alerting And Monitoring | Alerting and monitoring |
  | 030 | Cross-Namespace References And Remote Clusters | Remote clusters |
  | 040 | Disaster Recovery | Disaster recovery |

- **The version:** everything is written for **Flux v2.9.6** (CLI and
  controllers) on a single-node `kind` cluster. Flux 2.9 supports Kubernetes
  1.34.1 or later. Do not teach fields, flags or output from other versions
  without saying so.
- **The main sources:** the Flux documentation, <https://fluxcd.io/flux/>.
  Check every page against it.

### Status: built, not yet run

The first version of this repository was written from the Flux v2.9
documentation **without a live run**. No playground or lab has been started,
and no `astrona test` has passed yet. Until a maintainer runs them:

- Pages describe results in words. Do not add `text` output blocks until the
  output comes from a real run, and then paste it exactly.
- Treat every lab as unverified. Run `astrona validate` and `astrona test` on
  each one, one cluster at a time, before the course goes past `maturity:
  draft`.
- Remove this subsection when every lab has passed `astrona test`.

The biggest open risk is **Git credentials over plain HTTP**. The Flux
documentation describes basic authentication for HTTPS only, and the
repository `gitops/fleet` is private, so the `flux-system` `GitRepository`
sends the `gitops` credentials to `http://gitea.localtest.me:3000`. If
source-controller or `flux bootstrap git` refuses that, every environment
fails at the first fetch. Check this first; the fallback is Gitea on HTTPS
with a self-signed certificate (`--ca-file` for bootstrap, `caFile` in the
Secret). The tenant repositories (`gitops/team-a`, `gitops/team-b`) are public,
so their `GitRepository` objects need no credentials.

Other facts that need a live check: the exact error text when an impersonated
apply is refused (pages describe it in words), the body that the `generic`
provider posts and how `mendhak/http-https-echo` logs it, that `flux
uninstall` really leaves the workloads and that a new bootstrap adopts them
with the same UID, and whether `flux export kustomization --all` exists in
2.9.6.

### Terms, not metaphors

Explanations use Flux's, Git's and Kubernetes' own words. Define each one in
plain technical language on first use in a file, for example:

| Term | First-use definition (example wording) |
| --- | --- |
| Tenant | A team that gets its own namespaces and its own Git repository on a shared cluster, and may change nothing else |
| Platform administrator | The person or team that owns the cluster, the `flux-system` repository and the tenant onboarding |
| Impersonation | kustomize-controller and helm-controller act as another ServiceAccount when they apply, so Kubernetes RBAC limits what they can change |
| `spec.serviceAccountName` | The field on a Flux `Kustomization` or `HelmRelease` that names the ServiceAccount, in the object's own namespace, to impersonate |
| `--default-service-account` | A controller flag: objects without `spec.serviceAccountName` impersonate this ServiceAccount (usually `default`, which has no permissions) |
| `--no-cross-namespace-refs` | A controller flag: a Flux object may only reference sources and objects in its own namespace |
| `--no-remote-bases` | A kustomize-controller flag: a Kustomize file may not pull bases or components from a remote URL |
| Lockdown | The set of controller flags a platform administrator adds, through patches in `clusters/kind/flux-system/kustomization.yaml`, before onboarding tenants |
| Event | A Kubernetes event that a Flux controller records about one object, with a severity (`info` or `error`), a reason and a message |
| `Provider` | A notification-controller object that says where to send events: Slack, Microsoft Teams, a generic webhook and many others |
| `Alert` | A notification-controller object that selects which events (by kind, name, severity and message) go to which `Provider` |
| `gotk_reconcile_duration_seconds` | A histogram every Flux controller exports on port `8080` at `/metrics`: how long reconciliations take |
| `gotk_resource_info` | A metric about each Flux object's state; it comes from kube-state-metrics with a custom resource state configuration, not from the controllers |
| `spec.kubeConfig.secretRef` | The field that makes a Flux `Kustomization` apply to another cluster, using the kubeconfig stored in a Secret (key `value` or `value.yaml`) |
| Cluster API (CAPI) | A Kubernetes project that creates clusters from custom resources; for each cluster it writes a Secret `<cluster>-kubeconfig` that Flux can use |
| Disaster recovery | Bringing the cluster back to the state in Git after Flux, a namespace or the whole cluster is lost |
| Finalizer | A marker on an object that makes Kubernetes wait for a controller before deleting it; `flux uninstall` removes Flux's finalizers so nothing is garbage collected |

The `Kustomization` name clash confuses every learner. On first use in a
file, always say which one you mean: "the Flux `Kustomization` object" or
"the Kustomize file `kustomization.yaml`".

### The example workloads

| Name | Image | What it is |
| --- | --- | --- |
| `gitea` (Deployment and Service `gitea-http`, namespace `gitea`) | `gitea/gitea:28.2.0-rootless` | The in-cluster Git server. HTTP on port `3000`. SQLite storage on an `emptyDir`, so a restart loses every repository |
| Gitea user `gitops` | | Password `gitops-password`, administrator. Lab-only credentials; say so when a page uses them |
| Repository `gitops/fleet` | | The platform repository, private. Flux is bootstrapped from it with `--path=clusters/kind` |
| Repositories `gitops/team-a`, `gitops/team-b` | | Tenant repositories, public, used in section 010 |
| Repository `gitops/private-config` | | A second private repository, used in the section 040 capstone |
| `podinfo` (Deployment and Service) | `ghcr.io/stefanprodan/podinfo:6.15.0` | The demo application, port `9898`. The platform deploys it in `podinfo`; tenants deploy it in `team-a` and `team-b`; section 030 deploys it in `podinfo-staging` |
| `webhook-receiver` (namespace `monitoring`) | `mendhak/http-https-echo:42` | An HTTP server on port `8080` that writes every request it receives, with the body, to its log. Section 020's `generic` `Provider` posts to it |
| `tester` (namespace `gitea`) | `nicolaka/netshoot:v0.13` | Client pod with `curl` and `jq`. Graders call the Gitea API from here |

The platform repository layout:

```text
fleet/
├── apps/podinfo/              # the platform's podinfo
├── apps/podinfo-staging/      # section 030: podinfo without a Namespace object
├── clusters/kind/
│   ├── flux-system/           # written by flux bootstrap; the lockdown patches go in its kustomization.yaml
│   ├── podinfo.yaml           # the Flux Kustomization for apps/podinfo
│   └── tenants.yaml           # section 010: the Flux Kustomization for ./tenants
└── tenants/team-a/            # section 010: rbac.yaml and sync.yaml for one tenant
```

### Environment facts the text must respect

- **Every environment starts bootstrapped.** The bootstrap installs the Flux
  CLI, starts Gitea, adds the CoreDNS rewrite, seeds the repositories and runs
  `flux bootstrap git` with a short-lived port-forward of its own. The reader
  starts the course with Flux already managing itself from
  `gitops/fleet/clusters/kind`. Section 040's lab and capstone then remove
  Flux on purpose.
- **One Git address that works everywhere: `http://gitea.localtest.me:3000`.**
  The public DNS name `gitea.localtest.me` resolves to `127.0.0.1`. On the
  reader's machine, `kubectl -n gitea port-forward svc/gitea-http 3000:3000`
  makes Gitea answer there. Inside the cluster, the bootstrap adds a CoreDNS
  `rewrite stop` block so the same name resolves to
  `gitea-http.gitea.svc.cluster.local`, and rewrites the answer name back to
  `gitea.localtest.me` (Go programs, Flux included, ignore an answer whose name
  differs from the question). Copy the block from
  `sections/section-010/module-01/playground/bootstrap/prepare.sh`; never the
  one-line `rewrite name` form. Some home routers block DNS answers that point
  at `127.0.0.1`; then the reader adds `127.0.0.1 gitea.localtest.me` to
  `/etc/hosts`. Every page that clones says so in one sentence.
- **The port-forward must be running** for every `git` and `flux bootstrap`
  command on the reader's machine. Pages start it in a second terminal and say
  so. Controllers inside the cluster do not need it. Lab scripts that need Git
  from the machine start their own port-forward and stop it on exit.
- **HTTP, not HTTPS.** Say on every page that bootstraps that a real Git
  server uses HTTPS or SSH and that this is lab-only.
- **Multi-tenancy facts (from the documentation, not yet seen on a run):**
  - The lockdown patches go in `clusters/kind/flux-system/kustomization.yaml`:
    `--no-cross-namespace-refs=true` on kustomize-, helm-, notification-,
    image-reflector- and image-automation-controller;
    `--no-remote-bases=true` on kustomize-controller;
    `--default-service-account=default` on kustomize- and helm-controller;
    and `spec.serviceAccountName: kustomize-controller` on the `flux-system`
    Kustomization, so the platform's own sync keeps cluster-wide rights.
    The patch targets match Deployments whose controller is not installed
    (image controllers) without error.
  - `flux create tenant <name> --with-namespace=<ns> --export` writes a
    Namespace, a ServiceAccount and a RoleBinding that binds the ClusterRole
    `cluster-admin` (the `--cluster-role` default) inside that namespace only.
    It is marked as a preview command. The course writes the same objects by
    hand in `tenants/team-a/rbac.yaml` so the reader sees every field.
- **Notification facts:** `Provider` and `Alert` use
  `notification.toolkit.fluxcd.io/v1beta3`. `eventSeverity` is `info` (every
  event) or `error` (errors only). `exclusionList` wins over `inclusionList`.
  `spec.summary` is deprecated; use `eventMetadata`. The `generic` provider
  posts the event as JSON (`involvedObject`, `severity`, `reason`, `message`,
  `metadata`, `reportingController`, `timestamp`) with a `Gotk-Component`
  header. For Slack and Microsoft Teams the webhook address goes in a Secret
  key `address`; pages show those as YAML only, because the lab has no
  internet chat service.
- **Metrics facts:** controllers serve Prometheus metrics on port `8080` at
  `/metrics` (container port name `http-prom`). They export
  `gotk_reconcile_duration_seconds` and controller-runtime metrics such as
  `controller_runtime_reconcile_total`. `gotk_resource_info` comes from
  kube-state-metrics, not the controllers. `flux stats` is a preview command.
- **Remote cluster facts:** `spec.kubeConfig.secretRef.name` names a Secret in
  the Kustomization's namespace; the key defaults to `value` or `value.yaml`.
  Section 030 simulates a second cluster with a kubeconfig that points at the
  same API server (`https://kubernetes.default.svc`) as the ServiceAccount
  `flux-deployer` in `staging-access`, which may only change objects in
  `podinfo-staging`. Say plainly that a real remote cluster has its own
  address and credentials.
- **Disaster recovery facts:** `flux uninstall` removes the controllers, the
  CRDs and the Flux objects, removes the finalizers first, and leaves the
  reconciled workloads and namespaces in place. `--keep-namespace` keeps the
  `flux-system` namespace (and so its Secrets). Running bootstrap again leaves
  existing workloads alone.
- **Many environments start broken on purpose.** A lab seeds a fault in Git
  or in the cluster. The fault is the material. Never "fix" it in the
  bootstrap.
- **The proof is the cluster matching Git.** A fix is proven with `Ready True`
  objects, the workload running, and, where it matters, a refusal (an
  impersonated apply that must fail) or an event in the receiver's log.

### Where things are in this repo

| What | Where |
| --- | --- |
| Course outline the platform reads: every reading page and lab, in order. Never list `solution.md` here | `astrona.yaml` |
| Overview, sections and modules tables, how to run things | `README.md` |
| Introduction (see "Every course starts with an Introduction") | `sections/intro/` |
| Section overview and its modules | `sections/section-0N0/README.md` |
| Module reading: landing page, deep-dive parts, closing page | `sections/section-0N0/module-0M/course.md`, `course-0N-*.md` |
| Graded lab: task, walkthrough, setup, grader | `.../labs/lab-01/` (`question.md`, `solution.md`, `prerequisites.md`, `bootstrap/`, `manifests/`, `solution/`, `testing/`, `validation/`) |
| Ungraded sandbox for a module | `.../playground/` (`config.yaml`, `bootstrap/prepare.sh`, `manifests/`, `docs/overview.md`, which is the only learner page) |
| One graded integration lab per section | `sections/section-0N0/capstone/labs/lab-01/` |

A lab folder holds:

| Path | Purpose |
| --- | --- |
| `config.yaml` | Lab definition; `metadata.docs` points at `question.md` and `solution.md` |
| `README.md` | Short intro for authors with `estimated_duration` front matter and the run, submit and destroy commands |
| `prerequisites.md` | What the learner needs before starting |
| `question.md` | The task. Starts with `# Question` and `Solve this question on: \`terminal\`` |
| `solution.md` | Step-by-step walkthrough |
| `bootstrap/01-install-git-and-flux.sh` | The Flux CLI, Gitea, the CoreDNS rewrite, the seeded repositories and `flux bootstrap git`. The same file in every environment |
| `bootstrap/02-seed-state.sh` | The starting state of this lab, including its faults |
| `manifests/` | `lab-start.yaml` (Gitea and tester), `repo/` (the files seeded into `gitops/fleet`) and any extra repositories or objects |
| `solution/apply.sh` | Reference end state, applied only by `astrona test` |
| `testing/wait-for-flux.sh` | Waits until Gitea and the Flux controllers answer before the reference solution runs |
| `validation/validate-*.sh` | Behavioural grading, one script per check |

`bootstrap/01-install-git-and-flux.sh`, `testing/wait-for-flux.sh` and
`manifests/lab-start.yaml` are identical in every playground and lab (the
playground's `prepare.sh` is the same script plus the playground's own state).
Change them everywhere at once.

### Lab metadata in `astrona.yaml`

`astrona.yaml` has a `training:` block (id `ATS099`, domain
`Multi-Tenancy, Enterprise Operations & Cluster Management`, weight `15`) and
one entry per section under `modules:` (`module-010` to `module-040`). Each
section's `content` lists, in order: the section `README.md`, then for each
module its landing page, its parts, and right after the part a lab tests, a
`Question` reading (`labs/lab-01/question.md`) followed by the `type: lab`
entry; the module's closing page comes last. The section capstone closes the
section. Playgrounds are not listed.

Every `type: lab` entry carries the same fields, in the same order, as in
ATS016: `title`, `path`, `difficulty`, `estimated_duration`, `topic`,
`task_kind`, `tags`, `learning_goals`, `resources`.

- `difficulty`: `beginner`, `intermediate` or `advanced`.
- `estimated_duration`: realistic time to solve it, for example `20m`, `35m`.
- `topic`: exactly one of `multi-tenancy`, `alerting`, `monitoring`,
  `remote-clusters`, `disaster-recovery`.
- `task_kind`: exactly one of `build`, `troubleshooting` or `migration`.
- `tags`: 4 to 8 ids, only from the tag list below. Add a new tag to the list
  first if nothing fits.
- `learning_goals`: 2 or 3 plain sentences, each starting with a verb.
- `resources`: 1 to 4 pages on `fluxcd.io`, each with a `name` and a `url`
  that loads. This is the **only** place outside links are allowed.

**Tag list** (lower case, hyphens, never synonyms):

- Tenancy: `tenant`, `impersonation`, `service-account`, `rbac`,
  `lockdown`, `default-service-account`, `cross-namespace-refs`,
  `remote-bases`
- Notifications: `provider`, `alert`, `generic-webhook`, `event-severity`,
  `event-sources`, `exclusion-list`
- Monitoring: `metrics`, `flux-stats`, `flux-events`
- Delivery: `kustomization`, `gitrepository`, `kubeconfig`,
  `remote-cluster`, `cluster-api`
- Recovery: `flux-bootstrap`, `flux-uninstall`, `flux-suspend`,
  `flux-system`, `git-credentials`, `adoption`

### Running things

```bash
# Playground (ungraded)
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/section-010/module-01/playground
astrona destroy ats-099-playground-010-01   # takes metadata.name from config.yaml, not the path

# Lab or capstone (graded against the live cluster)
astrona run --git ssh://git@github.com/astrona-io/ATS099.git -c sections/section-010/module-01/labs/lab-01
astrona submit -c sections/section-010/module-01/labs/lab-01
astrona destroy ats-099-lab-010-01

# Authors: run a local, uncommitted copy, and prove a lab passes with its reference solution
astrona run -c sections/section-010/module-01/playground
astrona test -c sections/section-010/module-01/labs/lab-01
```

Names: a playground is `ats-099-playground-<section>-<module>`, a module lab
is `ats-099-lab-<section>-<module>` and a capstone is
`ats-099-capstone-<section>`; keep those names. Lab bootstrap scripts do not
pin a kube context: astrona sets `KUBECONFIG` for the lab. Every lab must pass
`astrona validate` and `astrona test`.

Graders check **behaviour**, not just that an object exists. Graders also
reject the plausible but wrong fix: binding a tenant to `cluster-admin` with a
ClusterRoleBinding, removing the lockdown flags, an `Alert` that forwards
every event, a kubeconfig with cluster-wide rights, deleting and recreating
workloads during recovery. A lab's `question.md` and `solution.md` must match
what its `validation/` scripts actually check.

Test clusters on the maintainer's machine: one at a time. Each environment
runs Gitea, the Flux controllers and a few small workloads.

### Where to find trusted sources

Check facts here before writing them down. Prefer these over memory.

- **Multi-tenancy:**
  [multi-tenancy lockdown](https://fluxcd.io/flux/installation/configuration/multitenancy/),
  [flux create tenant](https://fluxcd.io/flux/cmd/flux_create_tenant/),
  the example repository `fluxcd/flux2-multi-tenancy` on GitHub
- **Notifications:** [Providers](https://fluxcd.io/flux/components/notification/providers/),
  [Alerts](https://fluxcd.io/flux/components/notification/alerts/)
- **Monitoring:** [metrics](https://fluxcd.io/flux/monitoring/metrics/),
  [flux stats](https://fluxcd.io/flux/cmd/flux_stats/)
- **Remote clusters:** [Kustomization API: kubeConfig](https://fluxcd.io/flux/components/kustomize/kustomizations/)
- **Recovery:** [uninstall](https://fluxcd.io/flux/installation/uninstall/),
  [flux uninstall](https://fluxcd.io/flux/cmd/flux_uninstall/),
  [bootstrap a generic Git server](https://fluxcd.io/flux/installation/bootstrap/generic-git-server/)

### Skills to use here

The `astrona-course-*` skills do most authoring jobs in this repository:
planning (`domain-plan`), creating the tree (`domain-scaffold`), building
modules (`domain-build`), deep-dive parts (`deep-dive`), labs and playgrounds
(`lab`), lab docs (`lab-docs`), challenges (`create-challenge`), quizzes
(`generate-assessment`) and fact-checking (`review-accuracy`).
