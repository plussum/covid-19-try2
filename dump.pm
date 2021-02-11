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
	my ($cdp, $p) = @_;

	my $ok = $p->{ok} // 1;
	my $lines = $p->{lines} // "";
	my $items =$p->{items} // 5;
	my $mess = $p->{message} // "";


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
			$arsize = $items if($arsize > $items);
		 	print "$k\t" . csvlib::join_array(",", @{$p}[0..$arsize]). "\n";
		}
		else {
			print "$k\tundef\n";
		}
	}
	print "##### HASH ######\n";
	foreach my $k (@$csv2graph::dp_hashs){
		my $p = $cdp->{$k} // "";
		if($p){
			my @ar = %$p;
			my $arsize = ($#ar > ($items * 2)) ? ($items * 2) : $#ar;
			my @w = ();
			for(my $i = 0; $i <= $arsize; $i += 2){
				push(@w, $ar[$i] . "=>" , $ar[$i+1]);
			}
		 	print "$k\t" . join(",", @w);
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
	&dump_csv_data($csv_data, $p, $cdp);
	&dump_key_items($key_items, $p, $cdp);
	#dp::dp "LOAD ORDER " . join(",", @$load_order) . "\n";

	print "#" x 40 . "\n\n";
}

sub dump_key_items
{
	my($key_items, $p, $cdp) = @_;
	my $ok = $p->{ok} // 1;
	my $lines = $p->{lines} // 5;
	my $items = $p->{items} // 5;
	my $mess = $p->{message} // "";


	my $src_csv = $cdp->{src_csv} // "";
	my $search_key = $p->{search_key} // "";
	$lines = 0 if($search_key && ! defined $p->{lines});

	print "------ [$mess] Dump keyitems data ($key_items) search_key[$search_key] --------\n";
	my $ln = 0;
	foreach my $k (keys %$key_items){
		if($search_key &&  $k =~ /$search_key/){
			print "[$ln] $k: " . join(",", @{$key_items->{$k}}, " [$search_key]") . "\n";
		}
		elsif($lines eq "" || $ln <= $lines){
			print "[$ln] $k: " . join(",", @{$key_items->{$k}}) . "\n";
		}
		$ln++;
	}
}

sub	dump_csv_data
{
	my($csv_data, $p, $cdp) = @_;
	my $ok = $p->{ok} // 1;
	my $lines = $p->{lines} // "";
	my $items = $p->{items} // 5;
	my $src_csv = $cdp->{src_csv} // "";
	my $mess = $p->{message} // "";
	my $search_key = $p->{search_key} // "";
	$lines = 0 if($search_key && ! defined $p->{lines});

	$mess = " [$mess]" if($mess);
	print "------$mess Dump csv data ($csv_data) [$search_key]--------\n";
	#csvlib::disp_caller(1..3);
	print "-" x 30 . "\n";
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
	dp::dp "-" x 30 . "\n";
}

1;
