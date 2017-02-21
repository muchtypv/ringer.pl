#!/usr/bin/perl -w
require pvmods;
require ringingmods;

#set-up constants
$HUNT_DOWN=-1;
$MAKE_PLACE=0;
$HUNT_UP=1;
$SKIP_CHANGE=2;
$SKIP_LEAD=3;
$REPEAT_LEAD=4;
$SKIP_PART=5;
$EXIT_PROGRAM=6;

sub get_options() {
	$printlevel = "change";
	$tracetreble = TRUE;
	$stop_at_rounds=TRUE;
	$interact=TRUE;
	$random=FALSE;

	print "How many bells? ";
	$nobells=<STDIN>;
	chomp($nobells);

	print "Which bell are you going to ring? ";
	$tracebell=<STDIN>;
	chomp($tracebell);
	if ($tracebell eq "") { $interact=FALSE; }
	$tracecolour{1}="red";
	$tracebellcolour="blue";

	if (stat("/usr/bin/play") ne "") { $play = TRUE; }
	else { $play = FALSE; }
#	$play=FALSE;

	} # end of get_options()

sub setup_bells() {
	$colour{"grey"}=30;
	$colour{"red"}=31;
	$colour{"green"}=32;
	$colour{"yellow"}=33;
	$colour{"blue"}=34;
	$colour{"magenta"}=35;
	$colour{"cyan"}=36;
	$colour{"white"}=37;
	$colour{"inv-black"}=40;
	$colour{"inv-red"}=41;
	$colour{"inv-green"}=42;
	$colour{"inv-yellow"}=43;
	$colour{"inv-blue"}=44;
	$colour{"inv-magenta"}=45;
	$colour{"inv-cyan"}=46;
	$colour{"inv-grey"}=30;

	$rounds=substr("1234567890ETABCDFGHJKLMNPQRSTUVWXYZ",0,$nobells);
	@bell_symbol = split("",$rounds);
	my $pos=1;
	if (defined($tracebellcolour)) { $tracecolour{$tracebell}=$tracebellcolour; }
	for my $bell (@bell_symbol) {
		$bellhash{$bell}=$pos;
		if ( exists $tracecolour{$pos} ) { 
			$printbell{$bell} = "\033[".$colour{$tracecolour{$pos}}.";01m".$bell."\033[0m";
			}
		else { $printbell{$bell} = $bell; }
		$pos++;
		}
	$bellhash{"~"}=99;
	$bellhash{"-"}=99;

	$tracebell=substr($rounds,$tracebell - 1,1);
	$traceposprev=index($rounds,$tracebell) + 1;
	$newchange="";
	$lastmethod="";
	$mistakes=0;
	$numchanges=0;
	$move=0;
	$skip_lead=FALSE;
	$skip_part=FALSE;
	$exit_program=FALSE;
	$prevchange=$rounds;
	$touch_true="TRUE";
	} # end of setup_bells()

sub get_method() {
	my @options;
	my $line="";
	my $placenotation;
	my $methodname;
	while ( $line eq "" ) {
		print "What method will you ring (null to finish method input)? ";
		my $method=<STDIN>;
		chomp($method);
		if ($method eq "") { return -1; }
		else {
			open(IN,"grep -i \"^.$nobells.,.*$method\" methods.csv |") or die "Can't run grep!\n";
			while(<IN>) {
				chomp();
				push(@options, "$_");
				}
			close(IN);
			if ( $#options == -1 ) { print "No methods found!\n"; }
			elsif ( $#options == 0 ) { $line=$options[0]; }
			else  { 
				print "Several matching methods found:\n\n"; 
				for (my $i=0; $i <= $#options ; $i++) {
					(undef, undef, undef, my $name, undef) = split("\"",$options[$i]);
					print "$i:	$name\n"; 
					}
				print "\nPlease choose from the above: ";
				my $methnum=<STDIN>;
				chomp($methnum);
				$line=$options[$methnum];
				}
			}
		}
	(undef, undef, undef, $methodname, undef, $placenotation, undef) = split("\"",$line);
	$placenotation{$methodname}=$placenotation;
	$placenotation{$methodname} =~ s/LH/~/;
	} # end of sub get_method()

sub get_meth_abbr() {
	my $prevmethod="";
	my $sub=1;
	my $nm="";
	my $atleast=1;
	for $nextmethod (sort(keys(%placenotation))) {
		if ($prevmethod ne "") {
			my $pm=lc($prevmethod);
			$pm =~ s/ //;
			$nm=lc($nextmethod);
			$nm =~ s/ //;
			for ($sub=1 ; substr($pm,0,$sub) eq substr($nm,0,$sub) ; $sub++) { }
			if ($atleast > $sub) { $abbr{substr($pm,0,$atleast)}=$prevmethod; }
			else { $abbr{substr($pm,0,$sub)}=$prevmethod; }
			$atleast=$sub;
			}
		$prevmethod=$nextmethod;
		}
	if ( $nm ne "" ) { $abbr{substr($nm,0,$sub)}=$prevmethod; }
	else { $abbr{substr(lc($prevmethod),0,1)}=$prevmethod; } # if only one method

	for my $abbr (sort(keys(%abbr))){
		print "$abbr => $abbr{$abbr}\n";
		}
	} # end of get_meth_abbr()

sub setup_methods() {
	for $method (keys(%abbr)) {
		my $sub=0;
		$pn{$method}[$sub]="";
		for my $nextchar (split("",$placenotation{$abbr{$method}})) {
			if ($nextchar eq ".") { 
				$sub++;
				$pn{$method}[$sub]="";
				}
			elsif ($nextchar eq "-") { 
				if ($pn{$method}[$sub] ne "") { $sub++; }
				$pn{$method}[$sub]=$nextchar;
				$sub++;
				$pn{$method}[$sub]="";
				}
			elsif ($nextchar eq "~") { 
				for (my $sub2=$sub -1; $sub2 >=0; $sub2--) {
					$sub++;
					$pn{$method}[$sub]=$pn{$method}[$sub2];
					}
				$sub++;
				$pn{$method}[$sub]="";
				}
			else { $pn{$method}[$sub] = $pn{$method}[$sub].$nextchar; }
			}
		my $array=$pn{$method};
		if ($pn{$method}[$sub] eq "") { pop(@$array); }
		$call_offset{$method}=$#$array;
		$call_pn{$method.":plain"}=$pn{$method}[$#$array];
		$call_pn{$method.":bob"}="14";
		$call_pn{$method.":single"}="1234";
		}
	} # end of setup_methods()

sub getmove() {

	my $gotkey="";

	while ($gotkey eq "") {
		my $nexttry=getkey();
		if (($nexttry eq $PLACE_KEY ) || ($nexttry eq "8")) { $gotkey="$MAKE_PLACE"; }
		if (($nexttry eq $HUNT_DOWN_KEY ) || ($nexttry eq "7")) { $gotkey="$HUNT_DOWN"; }
		if (($nexttry eq $HUNT_UP_KEY ) || ($nexttry eq "9")) { $gotkey="$HUNT_UP"; }
		if ($nexttry eq " " ) { $gotkey="$SKIP_CHANGE"; }
		if ($nexttry eq "l" ) { $gotkey="$SKIP_LEAD"; }
		if ($nexttry eq "r" ) { $gotkey="$REPEAT_LEAD"; }
		if ($nexttry eq "p" ) { $gotkey="$SKIP_PART"; }
		if ($nexttry eq "q" ) { $gotkey="$EXIT_PROGRAM"; }
		}
	return($gotkey);
	} # end of getmove()

sub save_cfg() {
	print "Enter name of file to save config (Null to not save): ";
	my $cfgfile=<STDIN>;
	chomp($cfgfile);
	if ($cfgfile eq "") { return; }
	$cfgfile="$cfgfile".".cfg";
	open(OUT,"> config/".$cfgfile);
	print OUT "\$nobells=$nobells;\n";
	print OUT "\$play=$play;\n";
	print OUT "\$tracetreble=$tracetreble;\n";
	print OUT "\$stop_at_rounds=$stop_at_rounds;\n";
	print OUT "\$printlevel=\"$printlevel\";\n";
	print OUT "\$tracebell=$tracebell;\n";
	print OUT "\$tracebellcolour=$tracebellcolour;\n";
	print OUT "\$interact=$interact;\n";
	print OUT "\$prove_touch=$prove_touch;\n";
	print OUT "\$random=$random;\n";
	for my $key (keys(%tracecolour)) { print OUT "\$tracecolour{\"$key\"}=\"$tracecolour{$key}\";\n"; }
	for my $key (keys(%placenotation)) { print OUT "\$placenotation{\"$key\"}=\"$placenotation{$key}\";\n"; }
	for my $key (keys(%abbr)) { print OUT "\$abbr{\"$key\"}=\"$abbr{$key}\";\n"; }
	print OUT "\$composition=\"$composition\";\n";
	close(OUT);
	} # end of save_cfg()

sub get_conf_user {
	get_options();
	$nomethods=0;
	while (get_method() != -1) {
		$nomethods++;
		}
	if ($nomethods == 0) {
		print "Cancelled!\n";
		exit;
		}
	get_meth_abbr();
	setup_methods();
	print "Composition? ";
	$composition=<STDIN>;
	chomp($composition);
	$prove_touch=FALSE;

	save_cfg();
	} # end of get_conf_user()

sub get_conf_args {
	my $conf_file=shift(@ARGV);
	my $config="";
	open(IN,"config/".$conf_file.".cfg");
	while(<IN>) { $config=$config.$_; }
	close(IN);
	eval $config;
	while ( $#ARGV != -1 ) {
		my $parm=shift(@ARGV);
		$parm="\$".$parm.";";
		eval $parm;
		}
	setup_methods();
	} # end of get_conf_args()

sub print_change {
	my $change=$_[0];
	my $changetype=$_[1];
	my $addinfo=$_[2];
	my $bell;

	if (($changetype eq $printlevel) || ($changetype eq "f")) {
		foreach $bell (split("",$change)) {
			print $printbell{$bell};
			}
		print "$addinfo\n";
		}
	} # end of print_change()

sub setup_lead {
	$method=$_[0];

	$leadtype=chop($method);
	if ($leadtype eq ".") { $leadtype="bob"; }
	elsif ($leadtype eq ":") { $leadtype="single"; }
	else { 
		$method=$method.$leadtype;
		$leadtype="plain"; 
		}
	if ($method ne $lastmethod) { 
		print "$abbr{$method}\n"; 
		$lastmethod=$method;
		}
	$methodarray=$pn{$method};
	$change_in_lead=0;
	splice(@$methodarray,$call_offset{$method},1,$call_pn{$method.":".$leadtype});
	push(@last_le,$prevchange);
	push(@trace_le,$traceposprev);
	push(@numchanges,$numchanges);
	} # end of setup_lead()

sub apply_place_notation {
	my $oldchange=$_[0];
	my $pn=$_[1];
	my $pl;
	my @newchange;
	my @oldchange = split("",$oldchange);

	if ($bellhash{substr($pn,0,1)} % 2 == 0) { $pn = "1".$pn; }
	my $position = 1;
	foreach $pl (split("",$pn), "~") {
		my $place = $bellhash{$pl};
		while ( ( $position < $place ) && ( $position < $nobells ) ) {
			$newchange[$position-1] = $oldchange[$position];
			$newchange[$position] = $oldchange[$position-1];
			$position +=2;
		}
		if ( $position <= $nobells ) { $newchange[$position-1] = $oldchange[$position-1]; }
		$position++;
	}
	my $newchange=join("",@newchange);
	return($newchange);
	} # end of apply_place_notation()

sub interact {
	$traceposnew=index($newchange,$tracebell) + 1;
	$tracemove=$traceposnew - $traceposprev;
	for ($move=getmove(); 
	($move != $tracemove) && ($move != $SKIP_CHANGE) && ($skip_lead eq FALSE); 
	$move=getmove()) { 
		if ($move == $EXIT_PROGRAM) {
			$exit_program=TRUE;
			last;
			}
		if ($move == $SKIP_LEAD) {
			$skip_lead=TRUE;
			last;
			}
		if ($move == $SKIP_PART) {
			$skip_part=TRUE;
			$skip_lead=TRUE;
			last;
			}
		if ($move == $REPEAT_LEAD) {
			print "Repeat lead...\n";
			if ($#last_le == 0 ) {
				print "Already at first lead!\n";
				}
			else {
				my $times=($change_in_lead == 0)?2:1;
				for (my $i=1; $i <= $times; $i++) {
					if ($lead_in_part == 0) { $lead_in_part=$#comp; }
					else { $lead_in_part--; }
					$prevchange=pop(@last_le);
					$traceposprev=pop(@trace_le);
					$numchanges=pop(@numchanges);
					}
				$lastmethod="";
				print $traceposprev;
				if ($traceposprev == 1) {print "st";}
				elsif ($traceposprev == 2) {print "nds";}
				elsif ($traceposprev == 3) {print "rds";}
				else {print "ths";}
				print " place bell\n";
				print_change($prevchange,"f","");
				return(FALSE);
				}
			}
		else {
			print "\033[31;01mouch!!\033[0m\n"; 
			if ($play eq TRUE) { system "/usr/bin/play bad.wav";}
			$mistakes++;
			}
		}
	$traceposprev = $traceposnew;
	return(TRUE);
	} # end of interact()

# main code starts here
$random=FALSE;
$movekeys="left:down:right";
if ( $#ARGV == -1 ) { get_conf_user(); }
else { get_conf_args(); }
if ($random eq TRUE) { $stop_at_rounds=FALSE; }
system("stty -echo");
setup_bells();
print_change($rounds,"f","");
push(@last_le,$rounds);
push(@trace_le,$traceposprev);
push(@numchanges,0);
if ($prove_touch eq TRUE) { $proveid=prime_proof($nobells); }
($HUNT_DOWN_KEY, $PLACE_KEY, $HUNT_UP_KEY) = split(":",$movekeys);
while (TRUE){
	(@comp) = split(' ',$composition);
	$lead_in_part=0;
	LEAD: while ($lead_in_part <= $#comp) {
		setup_lead($comp[$lead_in_part]);
		++$lead_in_part;
		if (($random eq TRUE) && ( rand($nobells) > 1) && !($move == $REPEAT_LEAD)) {
			$skip_lead=TRUE; }
		foreach $pn (@$methodarray) {
			if (($change_in_lead == $call_offset{$method} -1 ) && ($leadtype ne "plain") && ($printlevel eq "change")) { print "$leadtype\n"; }
			$newchange=apply_place_notation($prevchange,$pn);
			if (($interact eq TRUE) && ($skip_lead eq FALSE)) {
				if (interact() eq FALSE) { redo LEAD; }
				}
			if ($prove_touch eq TRUE) {
				($truth, $hash) = prove($proveid,$newchange);
				$truth=($truth == 0)?"":"FALSE";
				$addinfo="\t".$truth."\t".$hash;
				if ($truth eq FALSE) { $touch_true="FALSE"; }
				}
			else { $addinfo=""; }
			print_change($newchange,"change",$addinfo);
			$prevchange=$newchange;
			$change_in_lead++;
			$numchanges++;
			if ((($stop_at_rounds eq TRUE) && ($newchange eq $rounds)) || ($exit_program eq TRUE)) {
				system("stty echo");
				if ($leadtype ne "plain") {
					print_change($newchange,"lead","\t".$leadtype);
					print_change($newchange,"part","");
					}
				else {
					print_change($newchange,"lead","");
					print_change($newchange,"part","");
					}
				print "\n Finished.  $mistakes mistakes!  $numchanges changes.";
				if ($prove_touch eq TRUE) { 
					tidy_proof($proveid); 
					print "  Touch is $touch_true.";
					}
				print "\n";
				exit ;
				}
			}
		if ($leadtype ne "plain") {
			print_change($newchange,"lead","\t".$leadtype);
			}
		else {
			print_change($newchange,"lead","");
			}
		if ( ( $skip_lead eq TRUE ) && ( $skip_part eq FALSE ) ) { 
			$skip_lead=FALSE;
			$traceposprev=index($prevchange,$tracebell) + 1;
			print $traceposprev;
			if ($traceposprev == 1) {print "st";}
			elsif ($traceposprev == 2) {print "nds";}
			elsif ($traceposprev == 3) {print "rds";}
			else {print "ths";}
			print " place bell\n";
			}
		}
	print_change($newchange,"part","");
	if ( $skip_part eq TRUE ) { 
		$skip_part=FALSE;
		$skip_lead=FALSE;
		$traceposprev=index($prevchange,$tracebell) + 1;
		print $traceposprev;
		if ($traceposprev == 1) {print "st";}
		elsif ($traceposprev == 2) {print "nds";}
		elsif ($traceposprev == 3) {print "rds";}
		else {print "ths";}
		print " place bell\n";
		}
	}
system("stty echo");
print "\n Finished.  $mistakes mistakes!  $numchanges changes.\n";


