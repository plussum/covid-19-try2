#!/usr/bin/perl
#
#
##

print &init("p", "key", "") . "\n";

sub	init
{
	my($hash, $key, $default) = @_;

	$default = $default // "";
	$default = '""' if($default eq "");
	my $rf = "\$$hash" . "->{" . $key . "}";
	return "(defined \$$hash && defined $rf) ? $rf : $default;";
}

