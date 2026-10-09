package Koha::Plugin::HKS3::SysprefDefaults::Compare;

use strict;
use warnings;
use utf8;
use Digest::SHA qw(sha256_hex);
use Encode qw(decode FB_CROAK);
use File::Spec;
use Koha::Plugin::HKS3::SysprefDefaults::I18N;

# This is deliberately a data parser, not an SQL interpreter. Never execute
# installer SQL against a running Koha database (not even a temporary table).
sub read_defaults {
    my ( $class, $root ) = @_;
    die "Koha-Installationsverzeichnis fehlt.\n" unless defined $root && length $root;
    my @paths = map { File::Spec->catfile( $root, split m{/}, $_ ) }
        qw(installer/data/mysql/mandatory/sysprefs.sql installer/data/mysql/sysprefs.sql);
    my ($path) = grep { -f $_ } @paths;
    die "Keine lokale sysprefs.sql gefunden.\n" unless $path;
    open my $fh, '<:raw', $path or die "Lokale sysprefs.sql ist nicht lesbar.\n";
    local $/;
    my $bytes = <$fh>;
    close $fh;
    my $sha = sha256_hex($bytes);
    my $sql = decode( 'UTF-8', $bytes, FB_CROAK );
    return { path => $path, sha256 => $sha, defaults => $class->parse_sql($sql) };
}

sub _space {
    my ($input) = @_;
    while ( $$input =~ s/\A\s+// || $$input =~ s/\A--[^\n]*(?:\n|\z)//
        || $$input =~ s/\A\#[^\n]*(?:\n|\z)// || $$input =~ s{\A/\*.*?\*/}{}s ) { }
}

sub _take {
    my ( $input, $pattern ) = @_;
    _space($input);
    return $$input =~ s/\A(?:$pattern)//i;
}

sub _expect {
    my ( $input, $pattern ) = @_;
    die "Nicht unterstütztes Format der sysprefs.sql.\n" unless _take( $input, $pattern );
}

sub _literal {
    my ($input) = @_;
    _space($input);
    if ( $$input =~ s/\A(['"])// ) {
        my $quote = $1;
        my $result = '';
        while ( length $$input ) {
            my $char = substr( $$input, 0, 1, '' );
            if ( $char eq $quote ) {
                if ( substr( $$input, 0, 1 ) eq $quote ) {
                    substr( $$input, 0, 1, '' );
                    $result .= $quote;
                    next;
                }
                return $result;
            }
            if ( $char eq '\\' ) {
                die "Unvollständige SQL-Zeichenkette.\n" unless length $$input;
                my $escaped = substr( $$input, 0, 1, '' );
                my %escapes = ( '0' => "\0", b => "\b", n => "\n", r => "\r", t => "\t", Z => chr(26) );
                $result .= exists $escapes{$escaped} ? $escapes{$escaped}
                    : $escaped =~ /[%_]/ ? '\\' . $escaped : $escaped;
            } else {
                $result .= $char;
            }
        }
        die "Unvollständige SQL-Zeichenkette.\n";
    }
    return undef if $$input =~ s/\ANULL\b//i;
    return $1 if $$input =~ s/\A(-?\d+(?:\.\d+)?)(?=\s*[,\)])//;
    die "Nicht unterstützter SQL-Wert; Vergleich abgebrochen.\n";
}

sub parse_sql {
    my ( $class, $sql ) = @_;
    my %defaults;
    while (1) {
        _space(\$sql);
        last unless length $sql;
        _expect( \$sql, qr/INSERT\s+INTO\s+`?systempreferences`?\s*\(/ );
        my @columns;
        while (1) {
            _space(\$sql);
            die "Ungültige SQL-Spaltenliste.\n" unless $sql =~ s/\A`?([a-z_]+)`?//i;
            push @columns, lc $1;
            last if _take( \$sql, qr/\)/ );
            _expect( \$sql, qr/,/ );
        }
        my %columns;
        for (@columns) {
            die "Unbekannte oder doppelte SQL-Spalte.\n"
                unless /\A(?:variable|value|options|explanation|type)\z/ && !$columns{$_}++;
        }
        die "SQL-Spalten variable/value fehlen.\n" unless $columns{variable} && $columns{value};
        _expect( \$sql, qr/VALUES\b/ );
        while (1) {
            _expect( \$sql, qr/\(/ );
            my @values;
            for my $i ( 0 .. $#columns ) {
                _expect( \$sql, qr/,/ ) if $i;
                push @values, _literal(\$sql);
            }
            _expect( \$sql, qr/\)/ );
            my %row;
            @row{@columns} = @values;
            die "Ungültiger Preference-Name.\n"
                unless defined $row{variable} && $row{variable} =~ /\A[A-Za-z0-9_:-]+\z/;
            my $key = lc $row{variable};
            die "Doppelter Preference-Name in sysprefs.sql.\n" if exists $defaults{$key};
            $defaults{$key} = \%row;
            last unless _take( \$sql, qr/,/ );
        }
        _expect( \$sql, qr/;/ );
    }
    die "Keine Defaults in sysprefs.sql gefunden.\n" unless keys %defaults;
    return \%defaults;
}

sub _same {
    my ( $a, $b ) = @_;
    return !defined($a) && !defined($b) if !defined($a) || !defined($b);
    return $a eq $b;
}

sub sensitive {
    my ( $class, $name, $type, @values ) = @_;
    return 1 if ( $type // '' ) =~ /password/i;
    return 1 if $name =~ /password|passwd|secret|token|credential|private.?key|api.?key|access.?key|client.?key|encryption.?key|signing.?key|hash.?key|oauth|smtp|dsn|authorization|mana.*key/i;
    return scalar grep { defined($_) && /(?:password|secret|token|api[_-]?key)\s*[:=]|-----BEGIN .*PRIVATE KEY-----|\bBearer\s+\S+|:\/\/[^\s\/]+:[^\s\/]+\@/i } @values;
}

sub _display {
    my ( $present, $value, $sensitive, $strings ) = @_;
    return $strings->{value_absent} unless $present;
    return $strings->{value_null} unless defined $value;
    return $strings->{value_empty} if $value eq '';
    return $strings->{value_masked} if $sensitive;
    return $value;
}

sub compare {
    my ( $class, $defaults, $current, $environment, $strings ) = @_;
    $environment ||= {};
    $strings ||= Koha::Plugin::HKS3::SysprefDefaults::I18N->catalog('en')->{strings};
    my ( %current, %overrides );
    for my $row (@$current) {
        my $key = lc $row->{variable};
        die "Doppelte aktuelle Preference.\n" if exists $current{$key};
        $current{$key} = $row;
    }
    for my $key ( sort keys %$environment ) {
        $overrides{ lc $1 } = $environment->{$key} if $key =~ /\AOVERRIDE_SYSPREF_(.+)\z/i;
    }
    my %keys = map { $_ => 1 } ( keys %$defaults, keys %current, keys %overrides );
    my @rows;
    my %counts = map { $_ => 0 } qw(changed equal missing extra overridden);
    for my $key ( sort keys %keys ) {
        next if $key eq 'version'; # Database schema version, displayed separately.
        my $d = $defaults->{$key};
        my $c = $current{$key};
        my $override = exists $overrides{$key};
        my $status = !$d ? 'extra' : !$c ? 'missing'
            : _same( $c->{value}, $d->{value} ) ? 'equal' : 'changed';
        my $name = $c ? $c->{variable} : $d ? $d->{variable} : $key;
        my $dv = $d ? $d->{value} : undef;
        my $cv = $c ? $c->{value} : undef;
        my $secret = $class->sensitive( $name, ( $d || {} )->{type}, $dv, $cv, $overrides{$key} );
        $counts{$status}++;
        $counts{overridden}++ if $override;
        push @rows, {
            name => $name, status => $status,
            current => _display( !!$c, $cv, $secret, $strings ),
            default => _display( !!$d, $dv, $secret, $strings ),
            override => _display( $override, $overrides{$key}, $secret, $strings ),
            overridden => $override ? 1 : 0,
            masked => $secret ? 1 : 0,
        };
    }
    return { rows => \@rows, counts => \%counts, total => scalar @rows };
}

sub version_matches {
    my ( $class, $code, $database ) = @_;
    return 0 unless defined($code) && defined($database);
    # Koha::version returns YY.MM.mm.NNN; DB Version uses YY.MMmmNNN.
    for ( $code, $database ) {
        s/\s+//g;
        s/\A(\d+)\.(\d{2})\.(\d{2})\.(\d{3})\z/$1.$2$3$4/;
        s/0+\z// if /\./;
        s/\.\z//;
    }
    return $code eq $database;
}

1;
