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
  local given_opts=$*
  local Clen=$( _longest_word $(sinfo --noheader --format=%V) )
  local Plen=$( _longest_word $(sinfo --noheader --format=%P) )
  local Dlen=$( _longest_word $(sinfo --noheader --format=%D) )
  local Flen=$( _longest_word $(sinfo --noheader --format=%F) )
  local pass_opts=
  while [[ $* ]]
  do
    case $1 in
    -o | --format | -O | --Format ) shift 2 ;;
    --format=* | --Format=* ) shift 1 ;;
    * ) pass_opts="${pass_opts} $1"; shift 1 ;;
    esac
  done
  cluster_len=$( _longest_word $(sinfo --format=%V) )
  partition_len=$( _longest_word $(sinfo --format=%P) )

  sinfo $pass_opts --format="%${Plen}P %${Clen}V %.${Dlen}D %.${Flen}F"
}

fi
