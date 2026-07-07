#! bash oh-my-bash.module
#
# Slurm Plugin - Utilities for Slurm Workload Manager
#
# This plugin provides convenient functions for interacting with Slurm clusters.
# It includes utilities for querying node information and job details.
#
# Author: Seth Underwood
# Requirements: sinfo, sacct, sacctmgr, jq
#

# Check for required commands at plugin load
# Issue warnings but continue loading to allow bash initialization to proceed
for _slurm_cmd in sinfo sacct sacctmgr jq; do
  if ! command -v "$_slurm_cmd" >/dev/null 2>&1; then
    echo "Warning: slurm plugin requires '$_slurm_cmd' but it was not found" >&2
    echo "         Some slurm plugin functions may not work correctly." >&2
    # Continue loading despite missing commands to allow login to proceed
    break
  fi
done
unset _slurm_cmd

# _longest_word - Helper function to find the longest string in a list
#
# This internal function is used to calculate column widths for formatted output.
# It iterates through all arguments and returns the length of the longest one.
#
# Arguments:
#   $@ - List of words to evaluate
#
# Returns:
#   Echoes the length of the longest word
#
function _longest_word {
  local longest=0
  for word in "$@"
  do
    local len=${#word}
    if (( len > longest ))
    then
      longest=$len
    fi
  done
  echo "$longest"
}

# sinfo-nodes - Display Slurm node information with formatted output
#
# This function wraps the Slurm sinfo command to provide a standardized view
# of cluster nodes organized by partition. It automatically adjusts column
# widths based on the actual data and supports federation-aware clusters.
#
# The function queries sinfo multiple times to determine optimal column widths,
# then displays partition information with node counts and states.
#
# Arguments:
#   Any valid sinfo options EXCEPT --format/-o or --Format/-O
#   (format options are set automatically by this function)
#
# Examples:
#   sinfo-nodes                  # Show all partitions
#   sinfo-nodes -p compute       # Show specific partition
#   sinfo-nodes -t idle          # Filter by node state
#
# Output Format:
#   PARTITION [CLUSTER] NODES STATE
#   Where STATE shows allocated/idle/other/total node counts
#
# Returns:
#   0 on success, 1 on error
#
function sinfo-nodes {
  # Query sinfo to determine optimal column widths for formatted output
  # This ensures the output looks clean regardless of partition/cluster names
  local Plen Dlen Flen
  local sinfo_output

  # Get maximum partition name length
  sinfo_output=$(sinfo --format=%P 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$sinfo_output" ]; then
    echo "Error: Failed to query sinfo. Check Slurm availability and permissions." >&2
    return 1
  fi
  Plen="$( _longest_word $sinfo_output )"

  # Get maximum node count length
  sinfo_output=$(sinfo --format=%D 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$sinfo_output" ]; then
    echo "Error: Failed to query sinfo for node counts." >&2
    return 1
  fi
  Dlen="$( _longest_word $sinfo_output )"

  # Get maximum node state string length (allocated/idle/other/total format)
  sinfo_output=$(sinfo --format=%F 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$sinfo_output" ]; then
    echo "Error: Failed to query sinfo for node states." >&2
    return 1
  fi
  Flen="$( _longest_word $sinfo_output )"

  # Check if this slurm is in a federation
  # If so, add cluster name column to output
  local Vfmt=
  if [ "$(sacctmgr --noheader show federation 2>/dev/null | wc -l)" -gt 0 ]
  then
    sinfo_output=$(sinfo --format=%V 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$sinfo_output" ]; then
      local Vlen="$( _longest_word $sinfo_output )"
      Vfmt="%${Vlen}V"
    fi
  fi

  # Parse command-line arguments, filtering out format options
  # since we set our own custom format
  local pass_opts=()
  while [ $# -gt 0 ]
  do
    case $1 in
    -o | --format | -O | --Format ) shift 2 ;;
    --format=* | --Format=* ) shift 1 ;;
    * ) pass_opts+=("$1"); shift 1 ;;
    esac
  done

  # Execute sinfo with calculated format and user-provided options
  if ! sinfo "${pass_opts[@]}" --format="%${Plen}P ${Vfmt} %.${Dlen}D %.${Flen}F" 2>/dev/null; then
    echo "Error: Failed to execute sinfo with provided options." >&2
    return 1
  fi
}

# job-nodes - List compute nodes assigned to a Slurm job
#
# This function queries the Slurm accounting database to retrieve the list
# of nodes that are currently assigned to a specific job. It uses sacct with
# JSON output and parses the results using jq.
#
# The function performs several validation checks:
# - Ensures a job ID is provided
# - Validates that the job ID is numeric
# - Verifies that sacct output is valid JSON
# - Checks that the job has sufficient step data (requires >1 steps)
#
# Arguments:
#   $1 - Job ID (required, must be numeric)
#
# Examples:
#   job-nodes 12345        # List nodes for job 12345
#   job-nodes 67890        # List nodes for job 67890
#
# Output:
#   One node name per line (duplicates removed)
#
# Returns:
#   0 on success, 1 on error
#
function job-nodes()
{
    # Check if job ID argument was provided
    if [ $# -eq 0 ]
    then
        echo "usage: job-nodes <JOB_ID>" >&2
        return 1
    else
        local jobid="$1"

        # Validate job ID is numeric
        if ! [[ "$jobid" =~ ^[0-9]+$ ]]; then
            echo "Error: job ID must be numeric (got: '$jobid')" >&2
            return 1
        fi

        # Query sacct and capture output in JSON format
        local sacct_output
        sacct_output=$(sacct -j "$jobid" --json 2>&1)
        if [ $? -ne 0 ]; then
            echo "Error: Failed to query job $jobid. Check job ID and permissions." >&2
            return 1
        fi

        # Parse JSON with jq to extract job step count
        local nsteps
        nsteps=$(echo "$sacct_output" | jq --raw-output '.jobs[0].steps | length' 2>&1)
        if [ $? -ne 0 ]; then
            echo "Error: Failed to parse sacct output. Invalid JSON or job not found." >&2
            return 1
        fi

        # Validate nsteps is numeric
        if ! [[ "$nsteps" =~ ^[0-9]+$ ]]; then
            echo "Error: Unable to determine number of job steps." >&2
            return 1
        fi

        # Extract node list from job step 1 (step 0 is the batch script itself)
        if [ "$nsteps" -gt 1 ]
        then
            local node_list
            node_list=$(echo "$sacct_output" | jq --raw-output '.jobs[0].steps[1].nodes.list[]' 2>&1)
            if [ $? -ne 0 ]; then
                echo "Error: Failed to extract node list from job data." >&2
                return 1
            fi
            # Output unique node names
            echo "$node_list" | uniq
        else
            echo "Error: Job has insufficient steps (found: $nsteps, need: >1)" >&2
            return 1
        fi
    fi
}
