# Reading A Failing Remote Apply

A Kustomization with `spec.kubeConfig` has more places to fail than one without it. The Secret can be missing or have the wrong key. The kubeconfig can be invalid. The address can be unreachable from the cluster that runs Flux. The certificate authority can be wrong. The token can be expired or revoked. The account can lack a right. The status of the Kustomization says which of these it is, if you read it in the right order.

## Read the status first

```sh
flux get kustomization podinfo-staging
kubectl -n flux-system describe kustomization podinfo-staging
```

The message of the `Ready` condition holds the first error. The events at the bottom of `describe` show the history. Read the message word by word. It names the stage that failed, and the stage tells you where to look.

## The stages, in the order they run

1. **The Secret.** The controller reads the Secret named in `spec.kubeConfig.secretRef.name`, in the namespace of the Kustomization, and takes the key `value`, or `value.yaml`, or the key named in `secretRef.key`. A message about a missing Secret or key means the name, the namespace or the key is wrong.
2. **The kubeconfig.** The controller parses the file. A message about invalid configuration means the YAML is wrong, for example a missing `current-context` or a context that names a cluster that does not exist.
3. **The connection.** The controller connects to the address in `server`. A message about a timeout or a refused connection means the address does not answer from inside the Flux cluster. Test it from a pod in that cluster, not from your laptop.
4. **The certificate.** A message about an unknown certificate authority means `certificate-authority-data` is missing or belongs to another cluster.
5. **The login.** A message about unauthorized means the token is invalid or expired.
6. **The rights.** A message about forbidden names the verb, the kind, the namespace and the account. This is the one you fix by changing the rights on the remote cluster, and only the rights that message names.

## Check each stage by hand

```sh
kubectl -n flux-system get secret staging-kubeconfig -o jsonpath='{.data}' | head -c 120; echo
kubectl -n flux-system get secret staging-kubeconfig -o jsonpath='{.data.value}' | base64 --decode > /tmp/staging.kubeconfig
kubectl --kubeconfig /tmp/staging.kubeconfig auth can-i create deployments -n podinfo-staging
```

The first command shows the keys in the Secret. The second writes the kubeconfig to a file, and the third uses it the way the controller does. Delete the file when you are done, because it holds a token. An address that works only from inside the cluster, such as `https://kubernetes.default.svc`, fails in the third command on your machine, and that is not an error of the kubeconfig. For that case run the check from a pod in the cluster.

## What a failing remote apply does to the rest

A failing remote Kustomization does not touch other Kustomizations, and it does not remove what it applied before. The objects on the remote cluster keep running. A Kustomization that lists it in `dependsOn` waits. The retry runs after `retryInterval`, or after `interval` when `retryInterval` is not set.

## Common pitfalls

> [!WARNING]
> - **Testing the address from your laptop.** The address must work from the pod of kustomize-controller.
> - **Fixing "forbidden" by granting `cluster-admin`.** Grant the verb and kind the message names, in the namespace it names.
> - **Leaving a decoded kubeconfig on disk.** It holds a token. Delete it.
> - **Reading only the status of the parent Kustomization.** Check the Secret and the remote rights as well.
