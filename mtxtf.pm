#!/usr/bin/perl
#
#
#
package mtxtf;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(mtxtf);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use Data::Dumper;
use List::Util 'min';

use dp;

#my $rs =	"\\((\\w+)\\) ([\\w ]+) *";
#my $rd =	'$1#$2';
sub	mtxtf
{
	my ($p) = @_;

	my $SRC_FILE = $p->{src_file};
	my $DST_FILE = $p->{dst_file};
	my $src_dlm = $p->{src_dlm}//",";
	my $dst_dlm = $p->{dst_dlm}//",";
	my $din = $p->{default_item_name}//"item";
	my $subs = $p->{subs}//"";

	dp::dp "ITEM NAME: $din\n";
	my @DATA = ();
	my $col = 0;
	open(SRC, $SRC_FILE) || die "cannot open $SRC_FILE\n";
	binmode(SRC, ":utf8");
	while(<SRC>){
		s/[\r\n]+$//;
		if($#DATA < 0 && $subs){
			$_ = $subs->($_);		 #s/\((\w+)\) ([\w ]+) */$1#$2/g;
		}
		my @w = split(/$src_dlm/, $_);
		if($#DATA < 0 && $din){
			$w[0] = $din;
		}
		push(@DATA, [@w]);
		$col = $#w if($#w > $col);
	}
	close(SRC);
		
	dp::dp join(", ", $col, $#DATA) . "\n";
	open(DST, "> $DST_FILE") || die "cannto create $DST_FILE\n";
	for(my $c = 0; $c <= $col; $c++){
		my @w = ();
		for(my $l = 0; $l <= $#DATA; $l++){
			my $v = $DATA[$l]->[$c]//"NaN";
			if($l == 0){
				$v =~ s/#DLM#/$dst_dlm/g;
			}
			#dp::dp join(", ", $c, $l, $v) . "\n";
		
			push(@w, $v);
		}
		print DST join($dst_dlm, @w) . "\n";
	}
	close(DST);
	return 1;
}			

sub	s
{
	my ($l) = @_;
	$l =~ s/\((\w+)\) ([\w ]+) */$1#DLM#$2/g;
	return $l;
}
1;
