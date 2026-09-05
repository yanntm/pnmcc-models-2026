#! /usr/bin/perl

# Repair of ill-formed PNML shipped by the contest.
#
# The models are taken verbatim from the MCC archives, and a few of them are not
# valid PNML. The competition never rejected them, so every tool has to cope with
# them or lose the model; we would rather repair the corpus once, here, than ask
# each tool to be bug compatible with a broken file. Each repair below is
# described with the symptom that motivated it. A repair must be conservative:
# it may only turn a file that no conforming parser can read into the file the
# author plainly meant, and it must leave a well formed model untouched.
#
# 1. Doubly wrapped subterm.
#
# In the high level syntax an operator holds its arguments in one <subterm> each,
# so <numberof> carries exactly two: the multiplicity and the token. FileSystem-COL
# wraps the second argument twice:
#
#     <numberof>
#       <subterm><numberconstant value="1"><positive/></numberconstant></subterm>
#       <subterm><subterm><variable refvariable="b"/></subterm></subterm>
#     </numberof>
#
# A parser that reads <subterm> as "one argument" sees the outer pair as a single
# argument and hands the operator one argument where it requires two, so the model
# dies at parse time, before any analysis. The inner wrapper carries no meaning:
# a subterm whose only child is a subterm is the same term either way. We drop the
# redundant wrapper, which is the reading every tool would give the file anyway.
#
# Usage: patch_models.pl <model directory>
# Prints one line per repair applied, nothing when the model is already sound.

use strict;
use warnings;

my $dir = $ARGV[0];
die "usage: patch_models.pl <model directory>\n" unless defined $dir;

my $pnml = "$dir/model.pnml";
exit 0 unless -f $pnml;

local $/ = undef;
open my $in, '<', $pnml or die "cannot read $pnml: $!\n";
my $text = <$in>;
close $in;

my $original = $text;
my $collapsed = 0;

# Collapse <subterm><subterm>X</subterm></subterm> into <subterm>X</subterm>.
# The inner subterm is required to hold no subterm of its own, so that we only
# ever remove a wrapper we can see the whole of, never a real argument list.
# Repeated to a fixed point, in case a wrapper is applied more than twice.
while (1) {
	my $n = ($text =~ s{<subterm>\s*<subterm>((?:(?!</?subterm>).)*?)</subterm>\s*</subterm>}{<subterm>$1</subterm>}gs);
	last unless $n;
	$collapsed += $n;
}

if ($text ne $original) {
	open my $out, '>', $pnml or die "cannot write $pnml: $!\n";
	print $out $text;
	close $out;
	print "$dir : collapsed $collapsed doubly wrapped subterm(s)\n";
}

exit 0;
