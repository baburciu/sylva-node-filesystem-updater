# node-filesystem-updater

A generic Helm chart that deploys **one DaemonSet per entry** of a `nodeFileUpdaters` map, each keeping files on the **node (host) OS filesystem** in sync with in-cluster state. Because files are written through a `hostPath` mount, they can be updated on **already-provisioned Cluster API nodes without triggering a rolling update** — unlike files injected through the bootstrap (cloud-init/ignition) data, whose content is part of the hash that drives Machine rollouts.

## Why

CAPI bakes inline file content into the bootstrap data; changing that content changes the bootstrap data hash and rolls the nodes. For files that must live on the host (e.g. `kube-apiserver` encryption config) but need to change in place, this chart runs a small DaemonSet that writes/refreshes the file from a Kubernetes Secret (auto-refreshed by the kubelet on the projected volume) or from a custom command.

## How files land on the node

`hostPath` is the **node directory** to write into. The chart bind-mounts it into the DaemonSet container at the fixed path **`/host-dir`**, so writing `/host-dir/<file>` inside the pod creates `<hostPath>/<file>` on the node. `/host-dir` is just the chart's internal mount point — the same node directory seen from inside the pod — and only `hostPath` decides which real directory that is (created with `DirectoryOrCreate` if missing).

What sets the **filename** depends on the mode:

- **Built-in sync mode:** the filename comes from the **Secret key**. Each key of `secretName` is projected as a file and copied to `<hostPath>/<key>`, with the key's value as the content.
  Thus a chart consumer should name the Secret key exactly as the file should be named (e.g. key `etcd-s3.yaml` for file `<hostPath>/etcd-s3.yaml`), and a Secret with several keys will write several files into the same directory.
- **Custom command mode:** *your* command chooses the filename(s); it writes under `/host-dir` (e.g. `printf ... > /host-dir/etcd-s3.yaml`). No Secret is projected.

## Modes

Each entry under `nodeFileUpdaters` is one DaemonSet, in one of two modes:

### Built-in sync mode (default)

The chart ships a sync script that copies every key of the projected `secretName` Secret to `<hostPath>/<key>` (the key is the filename, its value is the content), re-applying on change. <br/>
Use it to push a Secret contents onto the node filesystem. See [How files land on the node](#how-files-land-on-the-node).

```yaml
nodeFileUpdaters:
  kms-encryption-config:
    secretName: kms-encryption-config        # required: Secret whose keys become files
    hostPath: /etc/kubernetes/kms            # required: node directory written into
    filePermissions: "0600"                  # optional, default 0600
    syncInterval: 30                         # optional, default .Values.syncInterval
    nodeSelector:
      node-role.kubernetes.io/control-plane: ""
```

The Secret itself is **not** created by this chart, it's expected to be already there (created with some other mechanism).

### Custom command mode

Set `command` (and optionally `args`) to run anything. The `hostPath` is still mounted at `/host-dir`; the Secret projection and built-in script are omitted. Use `extraVolumes`/`extraVolumeMounts` for extra host paths (e.g. a KMS socket directory). This covers cases where the file content is generated inside the DaemonSet pod.

```yaml
nodeFileUpdaters:
  vault-kms-config-updater:
    hostPath: /etc/kubernetes/kms
    hostNetwork: true
    nodeSelector:
      node-role.kubernetes.io/control-plane: ""
    command: ["/bin/sh", "-c"]
    args:
      - |
        set -e
        until [ -S /opt/kms/vaultkms.socket ]; do sleep 5; done
        cat > /host-dir/encryption-config.yaml <<EOF
        ...
        EOF
    extraVolumes:
      - name: kms-socket
        hostPath: { path: /opt/kms, type: DirectoryOrCreate }
    extraVolumeMounts:
      - name: kms-socket
        mountPath: /opt/kms
```

## Per-entry keys

| key                 | mode        | required | description |
|---------------------|-------------|----------|-------------|
| `hostPath`          | both        | yes      | real node directory to write into; bind-mounted into the pod at `/host-dir` |
| `secretName`        | built-in    | yes      | Secret projected at `/sources`; each key is written to `<hostPath>/<key>` (key = filename) |
| `filePermissions`   | built-in    | no       | mode applied to written files (default `0600`) |
| `syncInterval`      | built-in    | no       | seconds between sync loops |
| `command` / `args`  | custom      | yes/no   | container command/args; presence selects custom mode |
| `nodeSelector`      | both        | no       | which nodes run the DaemonSet |
| `tolerations`       | both        | no       | default tolerates `NoSchedule` |
| `hostNetwork`       | both        | no       | sets `hostNetwork` + host-net DNS policy |
| `image`             | both        | no       | per-entry image override |
| `resources`         | both        | no       | per-entry resources override |
| `securityContext`   | both        | no       | deep-merged over the hardened default (see below) |
| `extraEnv`          | both        | no       | extra env vars |
| `extraVolumes`      | both        | no       | extra pod volumes |
| `extraVolumeMounts` | both        | no       | extra container volume mounts |

## Security model

Containers run as root (`uid/gid 0`, needed to write the host filesystem) but with no
privileges: `privileged: false`, `allowPrivilegeEscalation: false`, all capabilities
dropped, `readOnlyRootFilesystem: true`, and no service-account token mounted.

A per-updater `securityContext` is **deep-merged over** this default, so you override only
the keys you need and keep the rest hardened. For example, a custom command that writes to
its own root filesystem:

```yaml
nodeFileUpdaters:
  my-updater:
    hostPath: /etc/example
    command: ["/bin/sh", "-c", "..."]
    securityContext:
      readOnlyRootFilesystem: false   # everything else stays hardened
```

## Quick render

```sh
helm template nfu . -f tests/values.yaml --namespace kube-system
```
