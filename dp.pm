#
#
package dp;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(dp);

my $DP_ID = "";
sub	set_dp_id
{
	my ($id) = @_;
	$DP_ID = $id;
	return $DP_ID;
}
sub	dp_id
{
	return $DP_ID;
}

#
#
#
sub	dp
{
	my (@p) = @_;

	my ($p1, $f1, $l1, $s1, @w1) = caller;
	my ($package_name, $file_name, $line, $sub, @w) = caller(1);
	print "$DP_ID#[$l1]$f1:$sub " . join("", @p);
	#print "#[$line]$file_name " . join("", @p);
}

sub	WARNING
{
	my(@warns) = @_;
	
	#dp:dp "-" x 10 . " WARNING " . "-" x 10 . "\n";
	my ($p1, $f1, $l1, $s1, @w1) = caller;
	my ($package_name, $file_name, $line, $sub, @w) = caller(1);
	my $info = "$DP_ID#[$l1]$f1;$sub " ;

	my $info = "$info WARNING: ";
	print $info . "-" x 30 . "\n";
	foreach my $warn (@warns){
		print $info . join("", $warn);
	}
	print $info . "-" x 30 . "\n";
	&disp_caller(1..6);

}
sub	ABORT
{
	my(@warns) = @_;
	
	#dp:dp "-" x 10 . " WARNING " . "-" x 10 . "\n";
	my ($p1, $f1, $l1, $s1, @w1) = caller;
	my ($package_name, $file_name, $line, $sub, @w) = caller(1);
	my $info = "$DP_ID#[$l1]$f1;$sub " ;

	my $info = "$info ABORT: ";
	print $info . "-" x 30 . "\n";
	foreach my $warn (@warns){
		print $info . join("", $warn);
	}
	print $info . "-" x 30 . "\n";
	&disp_caller(1..6);
	exit 1;
}
sub disp_caller
{
    my @level = @_;

    @level = (0..1) if($#level < 0);
    foreach my $i (@level){
        my ($package_name, $file_name, $line, $sub) = caller($i);
		last if(! $package_name);

        print "$DP_ID:called from[$i]: $package_name :: $file_name #$line $sub\n";
    }
}
1;
