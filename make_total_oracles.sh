#! /bin/bash

# Build the oracle files of the total examinations for one P/T model instance:
# QuasiLivenessAll (one atom per transition), StableMarkingAll and
# UpperBoundsAll (one atom per place). Every verdict is "?" : nobody has
# answered these yet, the files exist so that a run can be checked for the
# atoms it left unanswered, and a "?" is replaced once a verdict is trusted.
#
# Atoms are named by definition order in model.pnml, t<i> and p<i>, and the
# lines carry the keyword the tool prints instead of FORMULA :
#   QLIVE t0 ?      STABLE p0 ?      BOUND p0 ?
# Coloured instances are skipped.
#
# usage : make_total_oracles.sh <model directory> <output directory>

set -e

dir=$1
outdir=$2
if [ -z "$dir" ] || [ -z "$outdir" ] ; then
	echo "usage : make_total_oracles.sh <model directory> <output directory>" >&2
	exit 1
fi
model=$(basename "$dir")

if grep -q TRUE "$dir/iscolored" 2>/dev/null ; then
	exit 0
fi

counts=$(grep -o -E '<(place|transition) ' "$dir/model.pnml" | sort | uniq -c)
P=$(echo "$counts" | awk '/place/ {print $1}')
T=$(echo "$counts" | awk '/transition/ {print $1}')
P=${P:-0} ; T=${T:-0}

mkdir -p "$outdir"
{ echo "$model QuasiLivenessAll" ; seq 0 $((T-1)) | sed 's/^/QLIVE t/; s/$/ ?/' ; } > "$outdir/$model-QLA.out"
{ echo "$model StableMarkingAll" ; seq 0 $((P-1)) | sed 's/^/STABLE p/; s/$/ ?/' ; } > "$outdir/$model-SMA.out"
{ echo "$model UpperBoundsAll" ; seq 0 $((P-1)) | sed 's/^/BOUND p/; s/$/ ?/' ; } > "$outdir/$model-UBA.out"
