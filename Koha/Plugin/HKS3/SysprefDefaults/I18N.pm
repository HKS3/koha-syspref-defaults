package Koha::Plugin::HKS3::SysprefDefaults::I18N;

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Spec;
use JSON::PP;

# Plugin-owned catalogs: no changes to Koha's translation files or global locale.
# Read per request so long-lived Plack workers cannot retain another user's language.
sub catalog {
    my ( $class, $requested ) = @_;
    my $language = lc( $requested // 'en' );
    $language =~ tr/_/-/;
    $language = 'en' unless $language =~ /\A[a-z]{2,3}(?:-[a-z0-9]{2,8})*\z/;
    my ($base) = split /-/, $language;
    my $directory = File::Spec->catdir( dirname(__FILE__), 'i18n' );
    my $english = _read( File::Spec->catfile( $directory, 'en.json' ) );
    for my $candidate ( $language, $base ) {
        my $path = File::Spec->catfile( $directory, "$candidate.json" );
        next unless -f $path;
        return { language => $candidate, strings => { %$english, %{ _read($path) } } };
    }
    return { language => 'en', strings => $english };
}

sub _read {
    my ($path) = @_;
    open my $fh, '<:raw', $path or die "Cannot read plugin translation catalog\n";
    local $/;
    my $strings = JSON::PP->new->utf8->decode(<$fh>);
    close $fh;
    die "Invalid plugin translation catalog\n" unless ref($strings) eq 'HASH';
    for my $value ( values %$strings ) {
        die "Invalid plugin translation value\n" if !defined($value) || ref($value);
    }
    return $strings;
}

1;
