#!/usr/bin/perl
#
#
use strict;
use warnings;
use utf8;
use Data::Dumper;
use config;
use csvlib;
use dp;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $dlm = "\t";

my $WIN_PATH = $config::WIN_PATH;
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::WIN_PATH;

my $CSS = $config::CSS;
my $class = $config::CLASS;

my $report_conff = "$WIN_PATH/report.txt";
my $report_htmlf = "$HTML_PATH/report.html";

my @LIST = ();
# file:///W:/cov/plussum.github.io/PNG2/沖縄県_pop_14_nc_40_0_nd_0_2_dr_0_34_0_0.png
open(FD, $report_conff) || die "cannot open $report_conff";
binmode(FD, ":utf8");
#
#	graph
#
while(<FD>){
	chop;
	last if(/#INDEX DATA#/);

	s/^[\s]*#.*//;
	dp::dp "[$_]\n" if(/.html#/);
	# next if(! /\w/);

	s#.*/plussum.github.io/##;
	push(@LIST, $_);
}

#
#	STATS
#
my@INDEX_DATA = ();
my $header = "";
my @headers = ();
my @TABLE_ITEM_ORDER = ();
my %TABLE_ITEM = ();
my $HIST = 5;
my $HIST_TERM = 7;
while(<FD>){
	chop;

	if(/^H:/){
		s/^H://;
		$header = $_;
		push(@headers, $header);
		next;
	}
	next if(! /file:/);

	#dp::dp "<<< $_\n";
	s/[\s]+#.*//;
	my($name, $line, $col, $kind, $file) = split(/,/, $_);
	if(! $file =~ /file:/){
		dp::dp "error $_ \n";
		exit 1;
	}
	$file =~ s#.*/plussum.github.io/##;
	#dp::dp "##$name,$line,$col,$kind,[$file]\n";
	my $p = {file => $file, header => $header, name => $name, line => $line, col => $col, kind => $kind};
	#dp::dp "  $name,$line,$col,$kind,[$file] \n[" . $p->{file} . "]\n";
	push(@INDEX_DATA, $p);
	#dp::dp "
	if(! defined $TABLE_ITEM{$name}){
		$TABLE_ITEM{$name}++;
		push(@TABLE_ITEM_ORDER, $name);
	}
}
close(FD);


#
#	STATS 2nd stage
#
my @INDEX = ();
my %TABLE_DATA = ();
foreach my $p (@INDEX_DATA){
	my $name = $p->{name};
	my $line = $p->{line};
	my $col  = $p->{col};
	my $file = $p->{file};
	my $header = $p->{header};
	
	#dp::dp "$name,$line,$col,$header [$file]\n";
	$file = "$WIN_PATH/$file";
	if(! -e $file){
		dp::dp "cannto find file $file\n";
		next;
	}

	#	Load CSV files
	my @lines = ();
	open(FD, $file) || die "cannot open $file";
	while(<FD>){
		push(@lines, $_);
	}
	close(FD);
	
	my $n = $line;
	if($line < 0){
		$n = $#lines + $line + 1;
	}
	if(!defined $lines[$n]){
		dp::dp "error no data in $name $n $line/$#lines\n";
		next;
	}
	chop($lines[$n]);

	$TABLE_DATA{$name} = {} if(! defined $TABLE_DATA{$name});
	$TABLE_DATA{$name}->{kind} = $p->{kind} // "";
	$TABLE_DATA{$name}->{$header} = [] if(! defined $TABLE_DATA{$name}->{$header});
	for(my $i = 0; $i < $HIST + 1; $i++){
		my @w = split(/$dlm/, $lines[$n-$i*$HIST_TERM]//"---------");
		$w[$#w] =~ s/[\r\n]+$//;
		my $v = $w[$col] // "-99999";
		$TABLE_DATA{$name}->{$header}->[$i] = sprintf("%.2f", $v);
		#dp::dp "HIST: $header $name $i $col " . join(", ", @w, " # ", $v) . "\n" ;
	}
}

#
#
#
my $now = csvlib::ut2dt(time());
open(HTML, "> $report_htmlf") || die "Cannot create $report_htmlf";
binmode(HTML, ":utf8");
#binmode(HTML, ':encoding(cp932)');
print HTML "<html>\n<head>\n";
print HTML "<meta http-equiv=\"Pragma\" content=\"no-cache\">\n";
print HTML "<meta http-equiv=\"Cache-Control\" content=\"no-cache\">\n";
print HTML "<TITLE>COVID 19  [$now]</TITLE>\n";
print HTML "$CSS\n";
print HTML "</head>\n<body>\n";
print HTML "<span class=\"c\">\n";
print HTML $now . "<br>\n";
print HTML '<H1> <a href="../about.html" target="_top">about this page </a></H1><br>' . "\n";
print HTML '<H1>for all information: <a href="../index.html" target="_top">INDEX-1</a> <a href="../index2.html" target="_top">INDEX-2</a></H1><br>' . "\n";

print HTML '<H1>STATS</H1>' . "\n";
foreach my $header (@headers){
	print HTML "<H2>$header</H2>\n";
	print HTML "<table border=\"1\">\n<tbody>\n";
	#print HTML "<tr>" . &tag("th colspan=" . ($HIST * 2 + 1), $header) . "</tr>" . "\n";
	my @col = ();
	for(my $i = 0; $i < $HIST; $i++){
		my $tm = time - ($i * 7 + 1) * 24 * 60  * 60;
		my $date = csvlib::ut2dt($tm, "/");
		$date =~ s/ .*//;
		push(@col, $date);
	}
	print HTML "<tr>" . &tag("td", "date") . &tag("td:colspan=2 align=\"center\"", @col) . "</tr>" . "\n";
	#print "<tr>" . &tag("td", "date") . &tag("td:colspan=2", @col) . "</tr>" . "\n";

		
	foreach my $name (@TABLE_ITEM_ORDER){
		my @col = ();
		push(@col, $name);
		for(my $i = 0; $i < $HIST; $i++){
			my $n = $TABLE_DATA{$name}->{$header}->[$i] // 0;
			my $n1 = $TABLE_DATA{$name}->{$header}->[$i+1] // 0;
			#dp::dp "$i: $name: $n, $n1\n";
			$n1 = 0.000001 if($n1 == 0);
			my $dlt = 0;
			my $kind = $TABLE_DATA{$name}->{kind}//"";
			if($kind){
				$dlt = $n - $n1;
				$dlt = sprintf("%.1f", $dlt) . (($kind eq " ") ? "&nbsp;" : $kind) ;#if($TABLE_DATA{$name}->{kind} eq "%");
				$n .= $kind;
			}
			else {
				$dlt = sprintf("%5.1f%%", 100 * ($n - $n1) / $n1);
			}
			push(@col, $n, $dlt);
		}
		print HTML "<tr>" . &tag("td:align=\"right\"", @col) . "</tr>" . "\n";
	}
	#dp::dp join(",", @col) . "\n";
	print HTML "</table>";
	print HTML "<br>\n";
}


#
#	index
#
foreach my $index (@INDEX){
}
print HTML "</tbody>\n</table>\n";
print HTML "<br>\n";

#
#	graph
#	
my $discription = [];
my $table = [];
my $link = "";
foreach my $item (@LIST){

	if($item =~ /^H\d+/){
		my $h = $&;
		$item =~ s/$h\s*//;
		print HTML "<$h>$item</$h>\n";
	}
	elsif($item =~ /.png$/){
		#if($#discription >= 0){
		#	print HTML "<h2>" . join("<br>", @$discription) . "<h2>\n";
		#	@$header = ();
		#}
		push(@$table, $item);
	}
	elsif($item =~ /.html?$/ || $item =~ /.html?#/){
		$link = $item;
	}
	elsif(!$item || !($item =~ /\S/)){
		&out_image($table, $discription, $link);
		$link = "";
	}
	else {
		push(@$discription, $item);
	}
}
if(scalar(@$table) > 0){
	&out_image($table, $discription, $link);
}

print HTML "</span>\n";
print HTML "<body>\n<html>\n";
close(HTML);

#
#
#
sub	tag
{
	my ($tag, @vals) = @_;
	$tag =~ s/[<>]//g;
	($tag, my $aln) = split(/:/, $tag);
	$aln = $aln // "";
	my $html = "";

	foreach my $v (@vals){
		$html .= "<$tag $aln>$v</$tag>";
	}
	#dp::dp "[$html]\n";
	return $html;
}

#
#
#
sub	out_image
{
	my ($table, $header, $link) = @_;
	
	$link = $link // "";
	#dp::dp "[$link]\n";

	print HTML "<a href = \"../$link\">" if ($link);
	print HTML "<h2>" . join("<br>", @$header) . "</h2>\n";
	print HTML "</a>" if ($link);
	print HTML "<table>\n";
	print HTML "<tbody>\n";
	print HTML "<tr>\n";
	foreach my $item (@$table){
		print HTML "<td>\n";
		$item =~ s#.png##;
		my $html = "<a href=\"../$item.png\" target=\"_blank\"><img src=\"../$item.png\"></a>\n";
		my $csvf = "$item" . "-plot.csv.txt";
		my $plotf = "$item" . "-plot.txt";
		print "ERROR: $WIN_PATH/$csvf\n" if(! -e "$WIN_PATH/$csvf");
		print "ERROR: $WIN_PATH/$plotf\n" if(! -e "$WIN_PATH/$plotf");

		$html .= "<br>\n";
		$html .= "<a href=\"../$item" . "-plot.csv.txt\">CSV</a>\n";
		$html .= "<a href=\"../$item" . "-plot.txt\">PLOT</a>\n";
		$html .= "<br>\n";
		print HTML $html . "\n";
		#print $html . "\n";
		print HTML "</td>\n";

	}
	print HTML "</tr>\n";
	print HTML "</tbody>\n";
	print HTML "</table>\n";

	@$table = ();
	@$header = ();
}
