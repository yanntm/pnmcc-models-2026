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

my @index = ("00","01","02","03","04","05","06","07","08","09","10","11","12","13","14","15");
my %globalProperties = (
	"ReachabilityDeadlock" => 1,
	"Liveness" => 1,
	"StableMarking" => 1,
	"QuasiLiveness" => 1,
	"OneSafe" => 1 ) ;

my $oracledir = "oracle";
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
	  print OUT "FORMULA ".$examination." ".@verdicts[$i]." TECHNIQUES ORACLE2026\n";
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
      # replace the verdict field only, the formula name and techniques are kept verbatim
      $l =~ s/^(FORMULA\s+\S+\s+)\S+(\s+TECHNIQUES\b.*)$/$1$res$2/;
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
