#! /bin/bash

# Build the oracle files of the total examinations for one P/T model instance:
# QuasiLivenessAll (one atom per transition), StableMarkingAll and
# UpperBoundsAll (one atom per place). Every verdict is "?" : nobody has
# answered these yet, the files exist so that a run can be checked for the
# atoms it left unanswered, and a "?" is replaced once a verdict is trusted.
#
# The file is the header line, the keyword the tool prints in place of
# FORMULA, then the vector of verdicts in definition order of model.pnml,
# wrapped at 80 columns, whitespace being insignificant :
#   QLIVE / STABLE   one character per object, T F or ?
#   BOUND            one token per object, an integer, inf or ?
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

# n question marks, packed, wrapped at 80 columns
marks() { head -c $1 /dev/zero | tr '\0' '?' | fold -w 80 ; echo ; }
# n question mark tokens, wrapped at 80 columns
tokens() { yes '?' | head -n $1 | paste -sd' ' | fold -s -w 80 | sed 's/ $//' ; }

mkdir -p "$outdir"
{ echo "$model QuasiLivenessAll" ; echo "QLIVE" ; marks $T ; } > "$outdir/$model-QLA.out"
{ echo "$model StableMarkingAll" ; echo "STABLE" ; marks $P ; } > "$outdir/$model-SMA.out"
{ echo "$model UpperBoundsAll" ; echo "BOUND" ; tokens $P ; } > "$outdir/$model-UBA.out"
