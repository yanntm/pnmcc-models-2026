#! /bin/bash

set -x

mkdir website
cd website

# grab the archive file for all inputs
wget --no-check-certificate --progress=dot:mega https://mcc.lip6.fr/2026/archives/INPUTS-2026.tar.gz
tar xzf INPUTS-2026.tar.gz
# cleanup
rm -f INPUTS-2026.tar.gz

mv INPUTS-2026 INPUTS

# The models are decompressed here anyway, so this is also where we harvest the real
# formula names into oracle skeletons : the naming is not homogeneous across
# examinations nor stable across editions, so it must be read, never rebuilt.
mkdir oracle

# remove strange MacOS specific stuff 'LIBARCHIVE.xattr.com.apple.quarantine'
echo "Patching tgz archives"
set +x
cd INPUTS
for i in *.tgz ;
do
	tar xzf $i
	model=$(echo $i | sed 's/.tgz//g')
#	echo "Treating : $model"
	rm $i
	tar czf $i $model/
	../../make_oracle_skeletons.pl $model ../oracle
	rm -rf $model/
done

# unfortunately, these two models are over 100MB compressed, GH pages does not support such large files without paying.
rm StigmergyCommit-PT-11b.tgz TokenRing-PT-050.tgz

cd ..
set -x

if [ ! -f raw-result-analysis.csv ] 
then
	# grab the raw results file from MCC website
	wget --no-check-certificate --progress=dot:mega https://mcc.lip6.fr/2026/archives/raw-result-analysis.csv.tar.gz
	tar xzf raw-result-analysis.csv.tar.gz
fi

# fill the oracle skeletons with the consensus verdicts
# all results available
cat raw-result-analysis.csv | grep -v StateSpace | grep -v UpperBound | cut -d ',' -f2,3,16 | sed 's/\s//g' | sort | uniq | ../csv_to_control.pl
# UpperBounds => do not remove whitespace
cat raw-result-analysis.csv | grep UpperBound | cut -d ',' -f2,3,16 | sort | uniq | ../csv_to_control.pl

 
# Patching bad consensus
# Manually inspected, consensus error due to trusting Gold25 over ITS-Tools.
# It is the only mismatch/consensus issue found so far in 2026 : it is also the only
# UpperBounds query of the whole edition where ITS-Tools answers inf and the consensus
# is finite. No other tool could answer this query.
sed -i -e "s/BugTracking-PT-q3m256-UpperBounds-12 1/BugTracking-PT-q3m256-UpperBounds-12 +inf/" oracle/BugTracking-PT-q3m256-UB.out

# When another one is found, patch the oracle .out file before archiving, e.g.:
# sed -i -e "s/CryptoMiner-COL-D03N000-UpperBounds-11 0/CryptoMiner-COL-D03N000-UpperBounds-11 +inf/" oracle/CryptoMiner-COL-D03N000-UB.out

#rm -f raw-result-analysis.csv*

cd oracle
# StateSpace oracles cannot come from raw-result-analysis.csv (large numbers are
# shortened there), so we use ../../oracleSS.tar.gz, built offline with collect_tedd.sh
# from the full 2026 contest logs (Tedd, gold medalist of the category).
tar xzf ../../oracleSS.tar.gz
cd ..
tar czf oracle.tar.gz  oracle/
rm -rf oracle/

tree -H "." > index.html

cd ..
