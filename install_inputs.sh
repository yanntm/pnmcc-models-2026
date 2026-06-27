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

# create oracle files
mkdir oracle
# all results available
cat raw-result-analysis.csv | grep -v StateSpace | grep -v UpperBound | cut -d ',' -f2,3,16 | sed 's/\s//g' | sort | uniq | ../csv_to_control.pl
# UpperBounds => do not remove whitespace
cat raw-result-analysis.csv | grep UpperBound | cut -d ',' -f2,3,16 | sort | uniq | ../csv_to_control.pl

 
# Patching bad consensus
# No bad consensus identified in 2026.
# When one is found, patch the oracle .out file before archiving, e.g.:
# sed -i -e "s/CryptoMiner-COL-D03N000-UpperBounds-11 0/CryptoMiner-COL-D03N000-UpperBounds-11 +inf/" CryptoMiner-COL-D03N000-UB.out

mv *.out oracle/

#rm -f raw-result-analysis.csv*

cd oracle
# StateSpace oracles are stable year-to-year (at worst slightly incomplete), so we
# reuse the committed ../../oracleSS.tar.gz; refresh with collect_tedd.sh if desired.
tar xzf ../../oracleSS.tar.gz
cd ..
tar czf oracle.tar.gz  oracle/
rm -rf oracle/

tree -H "." > index.html

cd ..
