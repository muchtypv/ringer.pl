#!/usr/bin/perl -w
use IPC::SysV qw(IPC_PRIVATE IPC_RMID S_IRWXU);
sub prime_proof {
	my $nobells=$_[0];
	my $shmid = shmget(IPC_PRIVATE, int(factorial($nobells) / 8) + 1, S_IRWXU) || die "Can't allocate memory!";
	shmwrite($shmid, "\0", 0, int(factorial($nobells) / 8) + 1) || die "$!";
	$FACTORIAL[0]=1;
	for (my $i=1; $i<$nobells; $i++ ) {
		$FACTORIAL[$i]=$FACTORIAL[$i - 1] * $i;
		}
	my $rounds="#1234567890ETABCDFGHIJKLMNPQRSUVWXYZ";
	(@BELL_SYMBOL) = split("",$rounds);
	return($shmid);
	} #end prime_proof

sub prove {
	my $id=$_[0];
	my $change=$_[1];

	my $hash=0;
	for (my $bell=length($change); $bell>0; $bell--) {
		my $pos=index($change,$BELL_SYMBOL[$bell]);
		$hash+=$pos * $FACTORIAL[$bell -1];
		$change =~ s/$bell//;
		}
	my $byte=int($hash/8);
	my $bit=$hash%8;
	my $mask=2**$bit;
	my $oldbyte="";
	shmread($id, $oldbyte, $byte, 1) || die "$!";
	$oldbyte=ord($oldbyte);
	my $truth = ( $oldbyte & $mask ) ;
	my $newbyte=$oldbyte | $mask;
	shmwrite($id, chr($newbyte), $byte, 1) || die "$!";

	return($truth, $hash);
	} #end prove()

sub tidy_proof {
	my $id=$_[0];
	shmctl($id, IPC_RMID, 0) || die "$!";
	}

1;
