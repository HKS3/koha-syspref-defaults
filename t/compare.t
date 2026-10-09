use strict;
use warnings;
use utf8;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";
use Koha::Plugin::HKS3::SysprefDefaults::Compare;

my $class = 'Koha::Plugin::HKS3::SysprefDefaults::Compare';

subtest 'SQL formats and MySQL string decoding' => sub {
    my $sql = <<'SQL';
-- New format, including multiline strings and commas inside values
INSERT INTO systempreferences (`variable`, `value`) VALUES
('Empty',''), ('Zero',0), ('NullValue',NULL),
('Text','O\'Brien, (x); it''s fine'),
('Escapes','line\nnext\tcol\r\b\0\Z\\\"\%\_\q'),
('OAI-PMH:archiveID','KOHA'), ('Multiline','one
two'), ('Unicode','Grüße');
/* Old Koha format */
INSERT INTO `systempreferences` (`variable`,`value`,`options`,`explanation`,`type`) VALUES
('OldPref', '0', NULL, 'don\'t', 'YesNo');
SQL
    my $d = $class->parse_sql($sql);
    is scalar(keys %$d), 9, 'both INSERT formats parsed';
    is $d->{'oai-pmh:archiveid'}{value}, 'KOHA', 'colon in real preference names';
    is $d->{empty}{value}, '', 'empty';
    is $d->{zero}{value}, '0', 'zero';
    ok !defined($d->{nullvalue}{value}), 'SQL NULL retained';
    is $d->{text}{value}, "O'Brien, (x); it's fine", 'escaped and doubled quotes';
    is $d->{escapes}{value}, "line\nnext\tcol\r\b\0" . chr(26) . '\\"\\%\\_q', 'MySQL escapes decoded';
    is $d->{multiline}{value}, "one\ntwo", 'literal multiline';
    is $d->{unicode}{value}, 'Grüße', 'Unicode retained';
    is $d->{oldpref}{type}, 'YesNo', 'old metadata retained';
};

subtest 'Fail closed, never execute SQL' => sub {
    for my $sql (
        '', 'DELETE FROM systempreferences;',
        "INSERT INTO systempreferences (variable,value) VALUES ('X',NOW());",
        "INSERT INTO systempreferences (variable,value) VALUES ('X','1'),('x','2');",
        "INSERT INTO systempreferences (variable,value) VALUES ('X','unterminated);",
        "INSERT INTO systempreferences (variable,value) VALUES ('X','1'); DROP TABLE borrowers;",
        "INSERT INTO another_table (variable,value) VALUES ('X','1');",
        "INSERT INTO systempreferences (variable,value) VALUES ('X');",
        "INSERT INTO systempreferences (variable,value) VALUES ('X','1')",
        "INSERT INTO systempreferences (variable,value) VALUES ('X','1'); /* unfinished",
        "INSERT INTO systempreferences (variable,value,value) VALUES ('X','1','2');"
    ) {
        ok !eval { $class->parse_sql($sql); 1 }, 'unsupported/malformed input rejected';
    }
};

subtest 'Exact comparison, union and case-insensitive names' => sub {
    my $d = $class->parse_sql("INSERT INTO systempreferences (variable,value) VALUES ('Same','0'),('Changed','0'),('Null',NULL),('Missing','x'),('Whitespace','a ');");
    my $r = $class->compare($d, [
        {variable=>'same',value=>'0'}, {variable=>'Changed',value=>'1'},
        {variable=>'Null',value=>''}, {variable=>'Whitespace',value=>'a'},
        {variable=>'Custom',value=>'x'}, {variable=>'Version',value=>'26.0600017'}
    ], {OVERRIDE_SYSPREF_Same=>'1'});
    is_deeply $r->{counts}, {changed=>3,equal=>1,missing=>1,extra=>1,overridden=>1}, 'counts';
    is $r->{total}, 6, 'Version excluded only';
    my %rows = map { lc($_->{name})=>$_ } @{$r->{rows}};
    is $rows{same}{status}, 'equal', 'stored equality distinct from override';
    is $rows{same}{override}, '1', 'override explicitly shown';
    is $rows{null}{default}, '— NULL —', 'NULL distinguished from empty';
    is $rows{null}{current}, '— empty —', 'empty distinguished from NULL';
    is $rows{missing}{status}, 'missing', 'missing row';
    is $rows{custom}{status}, 'extra', 'custom row';
    my $only = $class->compare({}, [], {OVERRIDE_SYSPREF_Only=>'x'});
    is $only->{rows}[0]{override}, 'x', 'override-only preference visible';
};

subtest 'Secrets removed from view model, not just visually hidden' => sub {
    my $d = $class->parse_sql("INSERT INTO systempreferences (variable,value) VALUES ('APIKey','oldsecret'),('Config','');");
    my $r = $class->compare($d,[{variable=>'APIKey',value=>'newsecret'},{variable=>'Config',value=>'password: nested-secret'}],{OVERRIDE_SYSPREF_APIKey=>'override-secret'});
    use Data::Dumper;
    my $dump = Dumper($r);
    unlike $dump, qr/oldsecret|newsecret|nested-secret|override-secret/, 'no secret in template model';
    is $r->{counts}{changed}, 2, 'real values still compared';
    ok $class->sensitive('Anything','Password','value'), 'password type';
    ok $class->sensitive('CASPrivateKey',undef,'value'), 'private key';
    ok $class->sensitive('URL',undef,'https://user:password@example.org'), 'URL credentials';
    ok !$class->sensitive('SearchEngine',undef,'Zebra'), 'ordinary pref stays readable';
};

subtest 'Version comparison' => sub {
    ok $class->version_matches('26.06.00.017','26.0600017'), 'real Koha code and DB formats';
    ok $class->version_matches('26.05.04.000','26.0504000'), 'release version';
    ok $class->version_matches('26.0500000','26.0500000'), 'same';
    ok $class->version_matches('26.0500000','26.05'), 'trailing zeros';
    ok !$class->version_matches('26.0600017','26.0500000'), 'different';
    ok !$class->version_matches('26.0500000',undef), 'missing DB version';
};

if (my $root = $ENV{KOHA_SOURCE}) {
    subtest 'Actual Koha installer data, read-only' => sub {
        my $source = $class->read_defaults($root);
        cmp_ok scalar(keys %{$source->{defaults}}), '>', 500, 'full default set parsed';
        like $source->{sha256}, qr/\A[0-9a-f]{64}\z/, 'source checksum';
        is $source->{defaults}{acqcreateitem}{value}, 'ordering', 'known default';
        my @current = map { +{%$_} } values %{$source->{defaults}};
        my $r = $class->compare($source->{defaults}, \@current);
        is $r->{counts}{changed}, 0, 'self comparison';
        is $r->{counts}{extra}, 0, 'no extra rows';
    };
}

done_testing;
