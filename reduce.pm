#
#
#
package reduce;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(reduce);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use JSON qw/encode_json decode_json/;
use Data::Dumper;
use config;
use csvlib;
use dump;
use util;
use csv2graph;

my $DEBUG = 0;
my $VERBOSE = 0;
my $dumpf = 0;


#
#
#
sub	reduce_cdp_target
{
	my ($cdp, $target_colp) = @_;

	my $dst_cdp = {};
	return &reduce_cdp_target_a($dst_cdp, $cdp, $target_colp);
}


#
#
#
sub	reduce_cdp_target_a
{
	my ($dst_cdp, $cdp, $target_colp) = @_;

	#dp::dp Dumper $target_colp;

	$dumpf = 1;
	my @target_keys = ();
	#dp::dp "reduce_cdp_target: $target_colp " . csvlib::join_array(",", $target_colp) . "\n";
	my $target = select::select_keys($cdp, $target_colp // "", \@target_keys);
	#dp::dp "result of select(", $#target_keys, ") " . join(",", @target_keys) . "\n";
	if($target < 0){
		dp::ABORT "No data " . csvlib::join_array(",", @$target_colp) . "##" . join(",", @target_keys) . "\n";
	}
	#my $ft = $target_colp->[0] ;
	#if(0 && $ft eq "NULL"){
	#	$dumpf = 1;
	#	#dp::dp "###### TARGET_KEYS #######\n";
	#	#dp::dp join("\n", @target_keys);
	#	#dp::dp "################\n";
	#}
	&reduce_cdp($dst_cdp, $cdp, \@target_keys);
	&dump_cdp($dst_cdp, {ok => 1, lines => 20, items => 20}) if($DEBUG);
	$dumpf = 0;
	return $dst_cdp;
}

sub	reduce_cdp
{
	my($dst_cdp, $cdp, $target_keys) = @_;

	csv2graph::new($dst_cdp);

	my $all_key = [];
	if((!defined $target_keys) || $target_keys eq ""){
		$target_keys = $all_key;
		@$target_keys = keys %{$cdp->{csv_data}};
		#dp::dp join(",", @$target_keys) . "\n";
	}
		
	@{$dst_cdp->{load_order}} = @$target_keys;		

	#my @arrays = ("date_list", "keys");
	#my @hashs = ("order");
	my @hash_with_keys = ("csv_data", "key_items");


	csv2graph::new($dst_cdp);
	%$dst_cdp = %$cdp;
	# $cdp_values = [ "id", "title", "main_url", "src_url","csv_file", "src_dlm", "timefmt", "data_start", "down_load"]
	foreach my $val (@$csv2graph::cdp_values){
		$dst_cdp->{$val} = $cdp->{$val} // "";
	}
	# $cdp_arrays = [ "date_list", "keys", "load_order", "item_name_list", "defined_item_name_list",]
	foreach my $array_item (@$csv2graph::cdp_arrays){
		$dst_cdp->{$array_item} = [];
		@{$dst_cdp->{$array_item}} = @{$cdp->{$array_item}};
	}
	# $cdp_hashs = ["order","item_name_hash", "defined_item_name_hash",]
	foreach my $hash_item (@$csv2graph::cdp_hashs){
		$dst_cdp->{$hash_item} = {};
		%{$dst_cdp->{$hash_item}} = %{$cdp->{$hash_item}};
	}
	# $cdp_hash_with_keys = ["csv_data", "key_items"]
	foreach my $hwk (@$csv2graph::cdp_hash_with_keys){
		my $src = $cdp->{$hwk};
		$dst_cdp->{$hwk} = {};
		my $dst = $dst_cdp->{$hwk};
	
		foreach my $key (@$target_keys){
			#dp::dp "reduce - target_keys: $hwk:$key\n";# if($dumpf);
			$dst->{$key} = [];
			#dp::dp "$hwk: $key:\n";
			if(! defined $src->{$key}){
				dp::WARNING "$hwk $key is not allocated\n";
				next;
			}
			@{$dst->{$key}} = @{$src->{$key}};
		}
	}
	my $dst_key = $dst_cdp->{key_items};
	my $dst_csv = $dst_cdp->{csv_data};
	if($DEBUG){
		my $kn = 0;
		foreach my $key (keys %$dst_csv){
			last if($kn++ > 5);

			#dp::dp "############ $key\n" if($key =~ /Canada/);
			#dp::dp "csv[$key] " . join(",", @{$dst_csv->{$key}}[0..5]) . "\n";
			#dp::dp "key[$key] " . join(",", @{$dst_key->{$key}}[0..5]) . "\n";
		}
		dump::dump_cdp($dst_cdp, {ok => 1, lines => 20, items => 20, search_key => "Canada"}); # if($DEBUG);
	}
}

#
#	Copy and Reduce CSV DATA with replace data set
#
sub	dup_cdp
{
	my($cdp) = @_;
	
	#csv2graph::dump_cdp($cdp, {ok => 1, lines => 5});
	my $dst_cdp = {};
	&reduce_cdp($dst_cdp, $cdp, ""); 

	return $dst_cdp;
}

sub	dup_csv
{
	my ($cdp, $work_csv, $target_keys) = @_;

	my $csv_data = $cdp->{csv_data};
	#dp::dp "dup_csv: cdp[$cdp] csv_data : $csv_data\n";
	$target_keys = $target_keys // "";
	if(! $target_keys){
		my @tgk = ();
		my $csv_data = $cdp->{csv_data};
		#dp::dp ">>dup_csv cdp[$cdp] csv_data[$csv_data]\n";
		foreach my $k (keys %$csv_data){
			push(@tgk, $k);
		}
		#@$target_keys = (keys %$csv_data);
		#dp::dp "DUP.... " . join(",", @tgk) . "\n";
		$target_keys = \@tgk;
		#exit;
	}
	foreach my $key (@$target_keys){						#
		$work_csv->{$key} = [];
		#dp::dp "$key: $csv_data->{$key}\n";
		push(@{$work_csv->{$key}}, @{$csv_data->{$key}});
	}
}

1;
