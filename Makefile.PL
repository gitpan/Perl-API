use 5.006;
use strict;

chomp(my $perlapi_pod = `perldoc -l perlapi`);

open(API, $perlapi_pod) || die "Can't read '$perlapi_pod: $!";

my %AVOID = map { $_ => 1 } qw(
    sv_nolocking
    sv_nosharing
    sv_nounlocking
    SvPVbyte_force
    SvIsCOW
    SvIsCOW_shared_hash
);

print "Creating API from $perlapi_pod...\n";

open(PM, ">API.pm") || die;
open(XS, ">API.xs") || die;

print PM <<'EOT';
package Perl::API;

use strict;

require Exporter;
require DynaLoader;

use vars qw($VERSION @ISA @EXPORT);
$VERSION = '0.01';
@ISA = qw(Exporter DynaLoader);
@EXPORT = qw(
EOT

print XS <<'EOT';
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = Perl::API                PACKAGE = Perl::API

PROTOTYPES: DISABLE
EOT

my $item;
my @doc;

while (<API>) {
    #print;
    if (/^=item /) {
	process_item();
	$item = $_;
    }
    elsif ($item) {
	$item .= $_;
    }
}

sub process_item {
    return unless $item;
    unless ($item =~ s/^=item (\w+)\n//) {
	warn "Skipping [$item]\n";
	return;
    }
    my $name = $1;

    unless ($item =~ /^\t(void|STRLEN|bool|int|[IU]32|[INU]V|[ACHS]V\*\*?|char\*)\s+\Q$name\E\(([^\)]*)\)/m) {
	#print "No prototype for $name found \n";
	return;
    }

    my $ret = $1;
    my $args = $2;

    # avoid some we can't handle yet
    if ($args =~ /\.\.\./ ||
	$args =~ /\*\*/ ||
	$args =~ /\b(PerlInterpreter|PADOFFSET|const)\b/ ||
	$args =~ /(STRLEN|I32|U8|int|[INUG]V|HE|PerlIO)\s*\*/ ||
	$args =~ /(^|,)\s*(sv)?type\b/ ||
	$ret =~ /\*\*/ ||
	$name =~ /^X?PUSH/ ||
	$AVOID{$name} ||
	0)
    {
	#print "$name is too complex\n";
	return;
    }

    push(@doc, "$ret $name($args)");
    print XS "\n$ret\n$name($args)\n";
    print PM "\t$name\n";
}

print PM <<'EOT';
);

Perl::API->bootstrap($VERSION);

1;

__END__

=head1 NAME

Perl::API - Expose the internal API

=head1 SYNPOSIS

EOT

for (@doc) {
    print PM "  $_\n";
}

print PM <<'EOT';

=head1 DESCRIPTION

This module expose selected parts of the internal Perl API.  Use it at
your own risk.

=head1 SEE ALSO

perlapi

=cut
EOT

close(PM) || die;
close(XS) || die;

if ($] < 5.008) {
    open(TYPEMAP, ">typemap") || die;
    print TYPEMAP "STRLEN T_UV\n";
    close(TYPEMAP) || die;
}

#exit;

use ExtUtils::MakeMaker;
WriteMakefile(
    NAME           => 'Perl::API',
    VERSION_FROM   => 'API.pm',
    dist           => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean          => { FILES => 'API.pm API.xs typemap' },
);

#------------------
