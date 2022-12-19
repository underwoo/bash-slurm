# If Slurm is not installed on this sytem, do not load this plugin
if [ $(command -v squeue) ]
then

function _longest_word {
  local longest=0
  for word in $*
  do
    local len=${#word}
    if (( len > longest ))
    then
      longest=$len
    fi
  done
  echo $longest
}

# sinfo-nodes is a wrapper to the slurm sinfo command to print the total
# number of nodes for a cluster.  All `sinfo` options, except the --[fF]ormat
# can be used, as this function will pass $* as-is to sinfo.  The --[fF]ormat
# flags will be removed.
function sinfo-nodes {
  # Get max length of sinfo format options
  local Plen=$( _longest_word $(sinfo --format=%P) )
  local Dlen=$( _longest_word $(sinfo --format=%D) )
  local Flen=$( _longest_word $(sinfo --format=%F) )
  # Check if this slurm is in a federation
  local Vfmt=
  if [ $(sacctmgr --noheader show federation) -gt 0 ]
  then
    local Vlen=$( _longest_word $(sinfo --format=%V) )
    Vfmt="%${Vlen}V"
  fi

  local pass_opts=
  while [[ $* ]]
  do
    case $1 in
    -o | --format | -O | --Format ) shift 2 ;;
    --format=* | --Format=* ) shift 1 ;;
    * ) pass_opts="${pass_opts} $1"; shift 1 ;;
    esac
  done

  sinfo $pass_opts --format="%${Plen}P ${Vfmt} %.${Dlen}D %.${Flen}F"
}

fi
