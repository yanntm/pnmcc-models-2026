#! /usr/bin/perl

# Build "skeleton" oracle files for one model instance.
#
# Formula names are NOT synthesized : they are read verbatim, in document order,
# from the <id> elements of the property files shipped by the MCC. This matters
# because the naming is not homogeneous : within a single edition the CTL* and
# Reachability* examinations carry a year infix that LTL* and UpperBounds do not,
# and the value of that infix is not the edition year (2026 ships "-2024-").
#
# Each skeleton holds a "?" verdict per formula ; csv_to_control.pl later replaces
# the "?" using the position of the formula in the raw results verdict string.
# The i-th FORMULA line of the file is property index i.
#
# usage : make_oracle_skeletons.pl <model directory> <output directory>

use strict;
use warnings;

# Examinations that own a property file. StateSpace has none (oracles come from
# collect_tedd.sh) and the global properties have none either : their formula name
# is the examination name itself, so csv_to_control.pl synthesizes those.
my @examinations = (
	"CTLCardinality",
	"CTLFireability",
	"LTLCardinality",
	"LTLFireability",
	"ReachabilityCardinality",
	"ReachabilityFireability",
	"UpperBounds" );

my $dir = $ARGV[0];
my $outdir = $ARGV[1];

if (! defined $dir || ! defined $outdir) {
	die "usage : make_oracle_skeletons.pl <model directory> <output directory>\n";
}

my $model = $dir;
$model =~ s/\/+$//;
$model =~ s/.*\///;

foreach my $examination (@examinations) {
	my $xml = $dir."/".$examination.".xml";
	next if (! -f $xml);

	open XML, "< $xml" or die "cannot read $xml\n";
	my @ids = ();
	while (my $line = <XML>) {
		while ($line =~ /<id>\s*(.*?)\s*<\/id>/g) {
			push @ids, $1;
		}
	}
	close XML;

	if ($#ids < 0) {
		print "No formula id found in $xml, skipping.\n";
		next;
	}

	# same abbreviation scheme as csv_to_control.pl : drop lowercase letters
	my $abbrev = $examination;
	$abbrev =~ s/[a-z]//g;

	my $outff = $outdir."/".$model."-".$abbrev.".out";
	open OUT, "> $outff" or die "cannot write $outff\n";
	# model examination
	print OUT $model." ".$examination."\n";
	foreach my $id (@ids) {
		print OUT "FORMULA ".$id." ? TECHNIQUES ORACLE2026\n";
	}
	close OUT;
}
