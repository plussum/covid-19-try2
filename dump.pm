#
#
#
#
package dump;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(dump);

use strict;
use warnings;
use utf8;
use config;
use csvlib;
use csv2graph;

#
#	Dump csv definition
#
sub	dump_cdp
{
	csvlib::disp_caller(1..2);
	my ($cdp, $p) = @_;
	my $ok = (!defined $p || !defined $p->{ok}) ? 5 : $p->{ok};
	my $lines = (!defined $p || !defined $p->{lines}) ? 5 : $p->{lines};
	my $items = (!defined $p || !defined $p->{items}) ? 5 : $p->{items};
	my $mess = (!defined $p || !defined $p->{message}) ? 5 : $p->{message};


	print "#" x 10 . "[$mess] CSV DUMP " . $cdp->{src_info} . " " . "#" x 10 ."\n";
	print "##### VALUE ######\n";
	foreach my $k (@$csv2graph::cdp_values){
		print "$k\t" . ($cdp->{$k} // "undef") . "\n";
	}
	print "##### ARRAY ######\n";
	foreach my $k (@$csv2graph::cdp_arrays){
		my $p = $cdp->{$k} // "";
		if($p){
			my $arsize = scalar(@$p) - 1;
			my $as = ($arsize > $items) ? $items :$arsize;
		 	print "$k($arsize)\t[" . csvlib::join_array(",", @{$p}[0..$as]). "]\n";
		}
		else {
			print "$k\tundef\n";
		}
	}
	print "##### HASH ######\n";
	foreach my $k (@$csv2graph::cdp_hashs){
		my $vals = $cdp->{$k} // "";
		if($vals){
			my $sc = scalar(keys %$p);
			print "$k($sc)\t" . &print_hash($p, $items) . "\n";
			#my @ar = %$p;
			#my $arsize = ($#ar > ($items * 2)) ? ($items * 2) : $#ar;
			#my @w = ();
			#for(my $i = 0; $i <= $arsize; $i += 2){
			#	push(@w, $ar[$i] . "=>" . $ar[$i+1]);
			#}
		 	#print "$k\t{" . join(",", @w) . "}\n";
		}
		else {
			print "$k\tundef\n";
		}
	}

	my $csv_data = $cdp->{csv_data};
	my $key_items = $cdp->{key_items};
	my $key_count = scalar(keys (%$csv_data));
	my $load_order = $cdp->{load_order};
	
	$p->{src_csv} = $cdp->{src_csv};
	$p->{nohead} = 1;
	print "##### key_items ######\n";
	&dump_key_items($key_items, $p, $cdp);
	print "##### csv_data ######\n";
	&dump_csv_data($csv_data, $p, $cdp);
	#dp::dp "LOAD ORDER " . join(",", @$load_order) . "\n";

	print "#" x 40 . "\n\n";
}

sub	print_hash
{
	my($hash, $size) = @_;

	$size = $size // 5;
	my $items = scalar(keys %$hash);
	my $arsize = ($size > $items) ? $items : $size;
	my @w = ();
	my $i = 0;
	foreach my $k (keys %$hash){
		last if($i++ >= $size);

		push(@w, "$k=>" . $hash->{$k});
	}
	return "{" . join(",", @w) . "}";
}
	

sub dump_key_items
{
	my($key_items, $p, $cdp) = @_;
	my $ok = (!defined $p || !defined $p->{ok}) ? 5 : $p->{ok};
	my $lines = (!defined $p || !defined $p->{lines}) ? 5 : $p->{lines};
	my $items = (!defined $p || !defined $p->{items}) ? 5 : $p->{items};
	my $mess = (!defined $p || !defined $p->{message}) ? 5 : $p->{message};
	my $nohead = (!defined $p || !defined $p->{nohead}) ? "" : $p->{message};
	my $search_key = (!defined $p || !defined $p->{search_key}) ? "" : $p->{search_key};

	my $src_csv = $cdp->{src_csv} // "";

	$lines = 0 if($search_key && ! defined $p->{lines});

	if(! $nohead){
		print "------ [$mess] Dump keyitems data ($key_items) search_key[$search_key] --------\n";
	}
	my $ln = 0;

	print "\t". join(",", @{$cdp->{item_name_list}}) . "\n";	
	foreach my $k (keys %$key_items){
		my $scv = " ";
		if($src_csv) {
			$scv = $src_csv->{$k} // "-" ;
		}
		my @w = @{$key_items->{$k}};
		if($#w < 0){
			dp::WARNING "nodata in key_items: $k: (" . $#w . ")\n";
		}
		for(my $i = 0; $i < $#w; $i++){ 
			if(! defined $w[$i]){
				dp::WARNING "nodatea at :$k [$i]  (" . $#w . ")\n";
			}
		}
				
		if($search_key &&  $k =~ /$search_key/){
			#print "[$ln] $k" ."[$scv]: " . join(",", @{$key_items->{$k}}, " [$search_key]") . "\n";
			print "[$ln] $k" ."[$scv]: " . join(",", @w, " [$search_key]") . "\n";
		}
		elsif($lines eq "" || $ln <= $lines){
			#print "[$ln] $k" . "[$scv]: $key_items->{$k}:" ;
			print "[$ln] $k" . "[$scv]: " . join(",", @w) . "\n";
			# join(",", @{$key_items->{$k}}) . "\n";
		}
		$ln++;
	}
	#print "-" x 30 . "\n";
}

sub	dump_csv_data
{
	my($csv_data, $p, $cdp) = @_;
	my $ok = (!defined $p || !defined $p->{ok}) ? 5 : $p->{ok};
	my $lines = (!defined $p || !defined $p->{lines}) ? 5 : $p->{lines};
	my $items = (!defined $p || !defined $p->{items}) ? 5 : $p->{items};
	my $mess = (!defined $p || !defined $p->{message}) ? 5 : $p->{message};
	my $nohead = (!defined $p || !defined $p->{nohead}) ? "" : $p->{message};
	my $search_key = (!defined $p || !defined $p->{search_key}) ? "" : $p->{search_key};

	my $src_csv = $cdp->{src_csv} // "";
	$lines = 0 if($search_key && ! defined $p->{lines});

	$mess = " [$mess]" if($mess);
	if(! $nohead){
		print "------$mess Dump csv data ($csv_data) [$search_key]--------\n";
	}

	#csvlib::disp_caller(1..3);
	#print "-" x 30 . "\n";
	my $ln = 0;
	foreach my $k (keys %$csv_data){
		my @w = @{$csv_data->{$k}};
		next if($#w < 0);

		my $f = ($k =~ /$search_key/) ? "*" : " ";
		#dp::dp "$f $ok $k [$search_key] \n";
		if(! defined $w[1]){
			dp::dp " --> [$k] csv_data is not assigned\n";
		}
		if($ok){
			my $scv = "";
			if($src_csv) {
				$scv = $src_csv->{$k} // "-" ;
			}

			if($search_key && $k =~ /$search_key/){
				print "[$ln] " . join(", ", $k, "[$scv]", @w[0..$items]) . " [$search_key]\n";
			}
			elsif($lines eq "" || $ln < $lines){
				print "[$ln] " . join(", ", $k, "[$scv]", @w[0..$items]) . "\n";
			}
		}
		$ln++;
	}
	#print "-" x 30 . "\n";
}

1;
