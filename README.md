# Slurm Plugin

## Introduction

The `slurm plugin` adds useful functions for working with [Slurm Workload Manager](https://slurm.schedmd.com/) clusters.

To use it, add `slurm` to the plugins array of your bashrc file:

```bash
plugins=(... slurm)
```

## Requirements

This plugin requires the following commands to be installed:

- `sinfo` - Slurm information command
- `sacct` - Slurm accounting command
- `sacctmgr` - Slurm account manager
- `jq` - JSON processor

## Functions

| Function      | Description                                                                |
|:--------------|:---------------------------------------------------------------------------|
| `sinfo-nodes` | Wrapper to sinfo that displays total nodes per partition with formatting  |
| `job-nodes`   | Lists the nodes that a specific job is using                               |

### sinfo-nodes

Displays cluster node information with automatic column width adjustment. All `sinfo` options are supported except `--format` and `--Format` (these are set by the function).

**Usage:**
```bash
sinfo-nodes [sinfo options]
```

**Example:**
```bash
# Show all partitions
sinfo-nodes

# Show specific partition
sinfo-nodes -p compute

# Show with state filtering
sinfo-nodes -t idle
```

**Output format:**
- Partition name
- Cluster name (if in a federation)
- Node count
- Node state (allocated/idle/other/total)

### job-nodes

Lists the compute nodes assigned to a specific Slurm job.

**Usage:**
```bash
job-nodes <JOB_ID>
```

**Example:**
```bash
# Get nodes for job 12345
job-nodes 12345
```

**Note:** This function requires the job to have at least 2 steps recorded in sacct.
