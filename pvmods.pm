#!/usr/bin/perl -w
sub getkey {
	my $gotkey="";
	my $lastkey="";
	while ($gotkey eq "") {
		system "stty", '-icanon', 'eol', "\001";
		my $key=getc;
		my $ord=ord($key);
#		print "ord => $ord\n";
		system "stty", 'icanon', 'eol', '^@';
		if ($ord == 27) { $lastkey=$ord; }
		elsif (($ord == 91) && ($lastkey == 27)) { $lastkey=$ord; }
		elsif (($ord == 65) && ($lastkey == 91)) { $gotkey="up"; }
		elsif (($ord == 66) && ($lastkey == 91)) { $gotkey="down"; }
		elsif (($ord == 67) && ($lastkey == 91)) { $gotkey="right"; }
		elsif (($ord == 68) && ($lastkey == 91)) { $gotkey="left"; }
		else { $lastkey=""; }
		if (index("abcdefghijklmnopqrstuvwxyz 1234567890",$key) >= 0) { $gotkey=$key; }
		}
	return($gotkey);

} # end getkey()

sub combos {
	# Returns a list of all combinations within boundaries given in paramaters
	# first parameter is the number of values from which to pick the combinations
	# second parameter is the number of values to place in each combination
	# for example combos(6,3); will give you all possible combinations of 3 numbers out of 0-5 (six numbers)
	# returns a list of combinations of colon separated values
	# note third and fourth parameters are for internal use and should be set to "0" , and "" repectively.

	my $i;
	my $no_values=$_[0];
	my $sample_size=$_[1];
	my $add_value=$_[2];
	my $prefix=$_[3];
	my @retlist;

	for ($i=0; $i<=($no_values - $sample_size); $i++) {
		if ($sample_size==1) {
			push(@retlist, $prefix.($i+$add_value));
			}
		else {
			(@retlist)=(@retlist, combos($no_values - $i - 1, $sample_size - 1, $add_value + $i + 1, $prefix.($i + $add_value).":"));
			}
		}
	return(@retlist);
	} # end of combos()

sub factorial {
	if ($_[0] == 0) { return(1); }
	else { return($_[0] * factorial($_[0] - 1)); }
	} #end factorial()

1;
