# Prerequisites

## Linode

This tutorial leverages [Linode](https://cloud.linode.com) to streamline provisioning of the compute infrastructure required to bootstrap a Kubernetes cluster from the ground up. It would cost less then $2 for a 24 hour period that would take to complete this exercise.

> There is no free tier for Linode. Make sure that you clean up the resource at the end of the activity to avoid incurring unwanted costs. 

## Linode CLI

### Install the Linode CLI

Follow the Linode CLI [documentation](https://www.linode.com/docs/guides/linode-cli/) to install and configure the `linode-cli` command line utility.

The current walkthrough was done with version 5.5.0

Verify the Linode CLI version using:

```
linode-cli --version
```

### Set a Default Compute Region and Zone

This tutorial assumes a default compute region.

Go ahead and set a default compute region:

- there's unfortunately no simple place to find a list of Linode regions, but if you run `linode-cli regions list`, that will bring back all of them. For convenience, the output is as below:

```
┌──────────────┬─────────┬───────────────────────────────────────────────────────────────────────────────────────┬────────┐
│ id           │ country │ capabilities                                                                          │ status │
├──────────────┼─────────┼───────────────────────────────────────────────────────────────────────────────────────┼────────┤
│ ap-west      │ in      │ Linodes, NodeBalancers, Block Storage, GPU Linodes, Kubernetes, Cloud Firewall, Vlans │ ok     │
│ ca-central   │ ca      │ Linodes, NodeBalancers, Block Storage, Kubernetes, Cloud Firewall, Vlans              │ ok     │
│ ap-southeast │ au      │ Linodes, NodeBalancers, Block Storage, Kubernetes, Cloud Firewall, Vlans              │ ok     │
│ us-central   │ us      │ Linodes, NodeBalancers, Block Storage, Kubernetes, Cloud Firewall                     │ ok     │
│ us-west      │ us      │ Linodes, NodeBalancers, Block Storage, Kubernetes, Cloud Firewall                     │ ok     │
│ us-southeast │ us      │ Linodes, NodeBalancers, Cloud Firewall, Vlans                                         │ ok     │
│ us-east      │ us      │ Linodes, NodeBalancers, Block Storage, Object Storage, GPU Linodes, Kubernetes        │ ok     │
│ eu-west      │ uk      │ Linodes, NodeBalancers, Block Storage, Kubernetes, Cloud Firewall                     │ ok     │
│ ap-south     │ sg      │ Linodes, NodeBalancers, Block Storage, Object Storage, GPU Linodes, Kubernetes        │ ok     │
│ eu-central   │ de      │ Linodes, NodeBalancers, Block Storage, Object Storage, GPU Linodes, Kubernetes        │ ok     │
│ ap-northeast │ jp      │ Linodes, NodeBalancers, Block Storage, Kubernetes                                     │ ok     │
└──────────────┴─────────┴───────────────────────────────────────────────────────────────────────────────────────┴────────┘
```

I _think_ all we need for this tutorial are linodes and nodebalancers, but I guess we'll find out! :)

```
REGION=eu-west
```











### configure the CLI tool to interact with your account

Follow along with the [documentation](https://www.digitalocean.com/docs/apis-clis/api/create-personal-access-token/) to generate an access token, then use:

```
doctl auth init
```

to be prompted to enter it so you can interact with the DO API


## Running Commands in Parallel with tmux

[tmux](https://github.com/tmux/tmux/wiki) can be used to run commands on multiple compute instances at the same time. Labs in this tutorial may require running the same commands across multiple compute instances, in those cases consider using tmux and splitting a window into multiple panes with `synchronize-panes` enabled to speed up the provisioning process.

> The use of tmux is optional and not required to complete this tutorial.

![tmux screenshot](images/tmux-screenshot.png)

> Enable `synchronize-panes`: `ctrl+b` then `shift :`. Then type `set synchronize-panes on` at the prompt. To disable synchronization: `set synchronize-panes off`.

Next: [Installing the Client Tools](02-client-tools.md)
