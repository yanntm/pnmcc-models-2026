#! /usr/bin/perl

# Fill the oracle files with the consensus verdicts of the raw results.
#
# Reads on stdin lines of the form "model,examination,verdicts" cut from the MCC
# raw-result-analysis.csv, and writes into oracle/<model>-<ABBREV>.out.
#
# Formula names are NOT built here. make_oracle_skeletons.pl has already created
# a skeleton per (model, examination) holding the real formula names read from the
# property files, with "?" as verdict. All we do is replace the "?" of the i-th
# FORMULA line by the i-th verdict of the raw results : position is the only thing
# that relates the two sources, since the raw results carry no formula names at all.
#
# Two exceptions own no property file, so their skeleton does not exist and their
# formula name is synthesized here :
#  - the global properties, whose formula name is the examination name itself,
#  - StateSpace, which is not handled here at all (see collect_tedd.sh).
#
# An optional argument is the raw results file itself. Given it, the TECHNIQUES
# field of every filled verdict names the tools that produced that very value,
# so a reader of the oracle sees at a glance whether a verdict rests on five
# tools or on one :
#
#   FORMULA Liveness FALSE TECHNIQUES ORACLE2026 ITSTOOLS TAPAAL TY 2025GOLD
#
# BVT-2026 is the union of the other rows and is therefore never cited.

my @index = ("00","01","02","03","04","05","06","07","08","09","10","11","12","13","14","15");
my %globalProperties = (
	"ReachabilityDeadlock" => 1,
	"Liveness" => 1,
	"StableMarking" => 1,
	"QuasiLiveness" => 1,
	"OneSafe" => 1 ) ;

my $oracledir = "oracle";

# "model\texamination" -> arrayref of tool lists, one per formula position.
my %support = ();
load_support($ARGV[0]) if defined $ARGV[0];

# The tools that answered as the consensus did, for the i-th formula of a
# (model, examination), as a string ready to append to TECHNIQUES.
sub tools_for {
    my ($model, $examination, $i) = @_;
    my $row = $support{$model."\t".$examination};
    return "" unless defined $row;
    my $tools = @{$row}[$i];
    return "" unless defined $tools && $tools ne "";
    return " ".$tools;
}

# The per formula tokens of a results field. The contest writes one character
# per formula when the verdicts are booleans, and a space separated list when
# they are numbers.
sub tokens {
    my ($field) = @_;
    $field =~ s/[\(\)]//g;
    $field =~ s/^\s+//;
    $field =~ s/\s+$//;
    return () if $field eq "";
    return split /\s+/, $field if $field =~ /\s/;
    return split //, $field if length($field) == 16;
    return ($field);
}

# The verdict spellings of the raw results, as the oracle writes them.
sub normalize {
    my ($v) = @_;
    return "TRUE" if $v eq "T";
    return "FALSE" if $v eq "F";
    $v =~ s/(\d)\.0000E\+0005/${1}00000/g;
    $v =~ s/(?<!\+)inf/+inf/g;
    return $v;
}

# A tool name as a TECHNIQUES token: upper case, no punctuation.
sub tool_token {
    my ($t) = @_;
    $t = uc $t;
    $t =~ s/[^A-Z0-9]//g;
    return $t;
}

# Read the raw results and keep, per formula, the tools that answered exactly
# what the consensus column holds. Only the matches are kept, so the table stays
# small whatever the size of the results file.
sub load_support {
    my ($path) = @_;
    open my $in, '<', $path or die "cannot read $path\n";
    my $header = <$in>;
    my %seen = ();
    while (my $line = <$in>) {
	chomp $line;
	my @f = split /,/, $line;
	next if $#f < 15;
	my ($tool, $model, $examination) = ($f[0], $f[1], $f[2]);
	next if $tool eq "BVT-2026";   # the best virtual tool is the union of the rest
	my @res = tokens($f[6]);
	my @est = tokens($f[15]);
	next unless @res && @est;
	my $key = $model."\t".$examination;
	$support{$key} = [] unless defined $support{$key};
	my $row = $support{$key};
	for (my $i = 0 ; $i <= $#est ; $i++) {
	    last if $i > $#res;
	    my $v = $res[$i];
	    next if $v eq "DNC" || $v eq "DNF" || $v eq "CC" || $v eq "?";
	    next if normalize($v) ne normalize($est[$i]);
	    my $token = tool_token($tool);
	    next if $seen{$key."\t".$i."\t".$token}++;
	    @{$row}[$i] = (defined @{$row}[$i] ? @{$row}[$i]." " : "").$token;
	}
    }
    close $in;
}
# a (model, examination) is filled once : should two tools disagree on the consensus
# column, sort|uniq hands us both rows and we keep the first, as we always have.
my %filled = ();

while (my $line = <STDIN>) {
    # print $line;
    chomp $line;
  my @fields = split /,/, $line;
  my $modelname = @fields[0];

  my $examination = @fields[1];

  @fields[2] =~ s/[\(\)]//g;
  my @verdicts = split //, @fields[2];

   # print "Verdicts ($#verdicts) = @verdicts \n";
  if ($#verdicts != 15 && $#verdicts != 0) {
    @verdicts = split / /, @fields[2];
    if ($#verdicts != 15) {
	    next;
	}
  }
  my $abbrev = @fields[1];
  $abbrev =~ s/[a-z]//g;

  my $outff = $oracledir."/".$modelname."-".$abbrev.".out";
  my $csvff = "consensus.csv";

  if ($filled{$modelname."/".$examination}) {
      print "Not overwriting existing oracle file $outff\n";
      next;
  }
  $filled{$modelname."/".$examination} = 1;

  # normalize the verdicts, as we always have
  for (my $i=0 ; $i <= $#verdicts ; $i++) {
      @verdicts[$i] =~ s/F/FALSE/g;
      @verdicts[$i] =~ s/T/TRUE/g;
      @verdicts[$i] =~ s/(\d)\.0000E\+0005/${1}00000/g ;
      @verdicts[$i] =~ s/(?<!\+)inf/+inf/g ;
  }

  open CSV, ">> $csvff";

  if ($globalProperties{$examination}) {
      # no property file : the formula name is simply the examination
      print "doing $modelname $examination, in file $outff has ".($#verdicts + 1)." entries \n";
      open OUT, "> $outff";
      print OUT $modelname." ".$examination ."\n";
      for (my $i=0 ; $i <= $#verdicts ; $i++) {
	  print OUT "FORMULA ".$examination." ".@verdicts[$i]." TECHNIQUES ORACLE2026".tools_for($modelname,$examination,$i)."\n";
	  print CSV  $modelname.",".$examination.",0,".@verdicts[$i]."\n";
      }
      close OUT;
      close CSV;
      next;
  }

  if (! -f $outff) {
      # model instance we do not ship (e.g. dropped for size), hence no skeleton
      print "No oracle skeleton $outff, skipping $modelname $examination\n";
      close CSV;
      next;
  }

  open OUT, "< $outff" or die "cannot read $outff\n";
  my @lines = <OUT>;
  close OUT;

  my $nbformulas = grep { /^FORMULA / } @lines;

  if ($#verdicts == 0) {
      # total failure of all tools : leave the skeleton "?" verdicts in place
      print "doing $modelname $examination, in file $outff has $nbformulas unanswered entries \n";
      foreach (@index) {
	  print CSV  $modelname.",".$examination.",".$_.",".@verdicts[0]."\n";
      }
      close CSV;
      next;
  }

  if ($nbformulas != $#verdicts + 1) {
      print "Skipping $modelname $examination : $nbformulas formulas in $outff but ".($#verdicts + 1)." verdicts in the raw results\n";
      close CSV;
      next;
  }

  print "doing $modelname $examination, in file $outff has $nbformulas entries \n";

  my $k = 0;
  foreach my $l (@lines) {
      next if ($l !~ /^FORMULA /);
      my $res = @verdicts[$k];
      # replace the verdict, and rewrite TECHNIQUES to cite the tools that hold it
      my $tech = "ORACLE2026".tools_for($modelname,$examination,$k);
      $l =~ s/^(FORMULA\s+\S+\s+)\S+\s+TECHNIQUES\b.*$/$1$res TECHNIQUES $tech/;
      print CSV  $modelname.",".$examination.",".@index[$k].",".$res."\n";
      $k++;
  }

  open OUT, "> $outff" or die "cannot write $outff\n";
  print OUT @lines;
  close OUT;
  close CSV;
}

# for COL formula names in PT models, it might be necassary to run this in sh.
# for j in `(for i in *COL*.out ; do echo $i | sed 's/-.*\.out//'  ; done) | uniq ` ; do for k in $j*PT*.out ; do cat $k | sed -re 's/(FORMULA.*)PT(.*)/\1COL\2/g' > $k.bak ; \mv $k.bak $k  ; done ; done
