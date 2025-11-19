---
layout: post
title: "Patching CoreDNS configuration with Terraform on Kubernetes"
---

During a recent training, a student asked me how I would
update the configuration of CoreDNS on a Kubernetes cluster,
when the cluster is deployed is Terraform and comes with
CoreDNS pre-installed. This article explains how to do it,
and shows more generally speaking how to get Terraform to
update resources that it did not create directly in the first place.

## The context

Almost every Kubernetes distribution out there will take care
of installing CoreDNS when provisioning the cluster. This is
because CoreDNS provides resolution and for Kubernetes services
inside the cluster. For instance, when a container running
in a pod in namespace `prod` tries to resolve the name `db`,
it will try (among other things) to resolve it as `db.prod.svc.cluster.local`,
and CoreDNS will resolve that to the ClusterIP address of
service `db` in namespace `prod`.

(For more details about DNS resolution in Kubernetes cluster,
check [this other article][kubernetes-dns]) for a deep dive
on the topic!)

CoreDNS will typically run as a `Deployment` in the `kube-system`
namespace, and its configuration will typically be located
in a `ConfigMap` aptly named `coredns`, itself containing
an entry called `Corefile`. Some Kubernetes distributions
might do things differently; but 99% of the clusters I've seen
do it that way. (The final 1% is for scenarios where the
cluster was installed completely manually for educational
purposes, like in my "Dessine-moi un cluster" workshop.)

## The problem

Sometimes, one might want to customize the configuration of
CoreDNS. For simplicity, in the example below, we'll assume
that we want to forward external queries to a hard-coded set
of resolvers, instead of the ones provided by kubelet.

This can be trivially done with a `kubectl edit` after
deployment the cluster, but unfortunately, `kubectl edit`
doesn't lean itself very well to scripting and automation.

It would also be possible to run e.g. `kubectl replace`
to overwrite the `ConfigMap`; but that still requires some
kind of semi-manual operation after deploying the cluster.
Additionally, if we just want to patch one line in the `Corefile`
it requires some extra steps.

So... Can we do it in a way that "feels right", meaning,
that blends nicely with our cluster provisioning process,
and will be as future-proof as possible?

## The solution

...Or should I say, "one" solution, because of course there
might be other ones!

In this case, our clusters are deployed with Terraform,
so ideally, we want a solution based on Terraform.

At first, it would look like Terraform isn't the right
tool for the job, because there is typically no "clean"
way to modify an existing resource in Terraform.

**Except!**

The Kubernetes provider for terraform has a resource
specifically for that use-case:

[kubernetes_config_map_v1_data](https://library.tf/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1_data).

It lets us add or replace a piece of data in an existing
`ConfigMap`. That's exactly what we need!

Let's see how to build a Terrafu (Terraform or OpenTofu)
configuration to do that.

*In the examples below, we'll actually operate on a KinD
cluster, because it will make it easy for you to reproduce
the whole thing in a lab in just a couple of minutes.*

First, we define the provider that we want to use.
Here, we're hard-coding our kubeconfig file and indicating
that we want to act on the `kind-kind` context. This is
just an extra safety to make sure that we don't accidentally
apply this configuration on one of our production clusters... 

```
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "kind-kind"
}
```

Next, we're going to define a *data source* to access
the existing `coredns` `ConfigMap`.

```
data "kubernetes_config_map_v1" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
}
```

Now, we're creating a local variable, `new_corefile`, with
the patched `Corefile`. In this scenario we do a simple `replace()`.
If you want to do more complex edits (adding lines or changing
whole sections), **make sure that the changes are idempotent,**
which means that if the `replace()` (or whatever transformation
you use!) is applied multiple times, it yields the same result.

```
locals {
  new_corefile = replace(
    data.kubernetes_config_map_v1.coredns.data.Corefile,
    "forward . /etc/resolv.conf",
    "forward . 1.0.0.1 1.1.1.1"
  )
}
```

We can then use that local variable to update the `Corefile`
in the existing `ConfigMap`. Note the `force = true`, which
means "hey, if that particular piece of data is already in
the `ConfigMap`, just overwrite it, OK?"

```
resource "kubernetes_config_map_v1_data" "coredns" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  data = {
    "Corefile" = local.new_corefile
  }
  force = true
}
```

Finally, after changing the `ConfigMap`, we need to make
sure that CoreDNS uses it. To achieve that, we'll use a
resource called `kubernetes_annotations`, which adds annotations
to existing resources, and has the ability to add annotations
to *templates insides resources*.

Specifically, we're adding an annotation to the `coredns` `Deployment`
pod template.
This, in turns, triggers a *rolling update*. This is exactly
the same principle as doing `kubectl rollout restart`
(which adds or updates an annotation called
`kubectl.kubernetes.io/restartedAt` in the pod template),
or generally speaking, making *any* change in the pod template:
that triggers a rolling update.

```
resource "kubernetes_annotations" "coredns" {
  kind = "Deployment"
  api_version = "apps/v1"
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }
  template_annotations = {
    "Corefile-hash" = sha256(local.new_corefile)
  }
  depends_on = [ kubernetes_config_map_v1_data.coredns ]
}
```

We've put a hash on the configuration file, so that if it changes later
for any reason, that will again trigger a rolling update.

We've also specified a `depends_on`, which *should* prevent a
race condition. Specifically, that `depends_on` makes sure that
the `ConfigMap` is updated *before* we update (or add) the
annotation. Without it, Terraform might update the annotation *first*,
triggering the rolling update; and update the `ConfigMap` later.
If the rolling update completes before the `ConfigMap` gets updated,
CoreDNS might start with the old `ConfigMap` still.

Note that this is a rather unlikely scenario, since all Terraform
has to do is two very quick Kubernetes API calls, so it's almost
impossible for the rolling update to complete before the second
API call... Unless there is any kind of glitch between the two API
calls. Then, all bets are off! So, to be on the safe side, we
put the `depends_on`.

Note: I wonder if, instead of the `depends_on`, we could introduce
a dependency from the annotation to the `ConfigMap`, e.g.
by expressing the annotation as `sha256(kubernetes_config_map_v1_data.coredns.data.Corefile)`.
I gave it a try, and it seems like the value of the hash was known
at planning time, which leads me to think that this does not
actually introduce a dependency. If a Terraform pro knows better,
feel free to let me know!

## Testing

1. Copy-paste the configuration shown above, or download
   the [coredns.tf](/assets/coredns.tf) file in a new empty directory.
2. Create a KinD cluster with `kind create cluster`.
3. `tofu init`
4. `tofu apply`

That's it!

(This assumes that you have KinD on your machine. If you don't,
feel free to either install and set it up, or point the `provider`
section to another test cluster!)

## Caveats

One drawback of this technique is that if we remove the
`kubernetes_config_map_v1_data` resource from the Terrafu
configuration, it will remove the `Corefile` entry from the
`ConfigMap`, which will break CoreDNS.

We'll have to take extra steps if we want to remove that resource safely!

Also, if "something else" (e.g. a cluster upgrade routine)
updates the Corefile by overwiting it, we'll have to re-apply
our configuration.

## Conclusions

Usually, it's not possible to use Terraform to update a resource
that was *not* created with Terraform (unless the resource is manually
imported into the Terraform state first). But some providers
give us exotic resources like the ones we show here, giving us
a way to update these resources anyway without having to completely
break the model (by e.g. shelling out to `kubectl`).


[kubernetes-dns]: {% post_url 2024-05-12-understanding-kubernetes-dns-hostnetwork-dnspolicy-dnsconfigforming %}