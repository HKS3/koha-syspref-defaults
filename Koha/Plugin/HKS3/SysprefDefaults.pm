package Koha::Plugin::HKS3::SysprefDefaults;

use Modern::Perl;
use utf8;
use base qw(Koha::Plugins::Base);
use C4::Auth qw(get_template_and_user);
use C4::Context;
use C4::Languages qw(getlanguage);
use Koha;
use Koha::Template::Plugin::Koha;
use Koha::Plugin::HKS3::SysprefDefaults::Compare;
use Koha::Plugin::HKS3::SysprefDefaults::I18N;

our $VERSION = '0.2.0';
our $metadata = {
    name => 'System preferences: compare with defaults',
    author => 'HKS3',
    description => 'Read-only comparison of system preferences with the defaults shipped with the installed Koha version. English and German interface.',
    date_authored => '2026-10-09', date_updated => '2026-10-09',
    minimum_version => '24.11', version => $VERSION,
};

sub new {
    my ( $class, $args ) = @_;
    $args ||= {};
    $args->{metadata} = { %$metadata, class => $class };
    return $class->SUPER::new($args);
}

sub install { return 1; }
sub upgrade { return 1; }
sub uninstall { return 1; }

sub tool {
    my ($self) = @_;
    # plugins/run.pl checks plugins.tool; sysprefs require this extra permission.
    # Authorize BEFORE reading preferences, including credentials and HTML/JS.
    my ( $template, $loggedinuser, $cookie ) = get_template_and_user({
        template_name => $self->mbf_path('tool.tt'),
        query => $self->{cgi}, type => 'intranet',
        flagsrequired => { parameters => 'manage_sysprefs' },
    });
    my $catalog = Koha::Plugin::HKS3::SysprefDefaults::I18N->catalog(
        scalar($self->{cgi}->param('plugin_language')) || getlanguage($self->{cgi})
    );
    my $strings = $catalog->{strings};
    $template->param( i18n => $strings, plugin_language => $catalog->{language} );
    my $compare = 'Koha::Plugin::HKS3::SysprefDefaults::Compare';
    my $result;
    my $ok = eval {
        my $source = $compare->read_defaults( C4::Context->config('intranetdir') );
        my $current = C4::Context->dbh->selectall_arrayref(
            'SELECT variable, value FROM systempreferences ORDER BY variable', { Slice => {} }
        );
        my ($db_version) = map { $_->{value} } grep { lc($_->{variable}) eq 'version' } @$current;
        $result = $compare->compare( $source->{defaults}, $current, \%ENV, $strings );
        $result->{source_path} = $source->{path};
        $result->{source_sha256} = $source->{sha256};
        $result->{code_version} = Koha::version();
        $result->{db_version} = $db_version // $strings->{unknown};
        $result->{version_mismatch} = !$compare->version_matches( Koha::version(), $db_version );
        1;
    };
    if ($ok) {
        $template->param(%$result);
    } else {
        # Do not echo parser input, SQL, DB connection errors or secrets.
        $template->param( comparison_error => 1 );
    }
    $template->param(
        footerjs => 1,
        csp_nonce => Koha::Template::Plugin::Koha->can('CSPNonce')
            ? Koha::Template::Plugin::Koha->CSPNonce : '',
    );
    $self->output_html( $template->output, undef, { force_no_caching => 1 }, $cookie );
}

1;
