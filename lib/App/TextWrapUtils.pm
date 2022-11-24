package App::TextWrapUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

our @BACKENDS = qw(
                      Text::ANSI::Fold
                      Text::ANSI::Util
                      Text::ANSI::WideUtil
                      Text::Fold
                      Text::LineFold
                      Text::Wide::Util
                      Text::Wrap
              );

$SPEC{textwrap} = {
    v => 1.1,
    summary => 'Wrap (fold) text using one of several Perl modules',
    description => <<'_',

Paragraphs are separated with two or more blank lines.

_
    args => {
        filename => {
            schema => 'filename*',
            default => '-',
            req => 1,
            pos => 0,
            description => <<'_',

Use dash (`-`) to read from stdin.

_
        },
        width => {
            schema => 'posint*',
            default => 80,
            cmdline_aliases => {w=>{}},
        },
        # XXX arg: initial indent string/number of spaces?
        # XXX arg: subsequent indent string/number of spaces?
        # XXX arg: option to not wrap verbatim paragraphs
        backend => {
            schema => ['perl::modname*', in=>\@BACKENDS],
            default => 'Text::Wrap',
        },
    },
};
sub textwrap {
    require File::Slurper::Dash;

    my %args = @_;
    my $text = File::Slurper::Dash::read_text($args{filename});
    $text =~ s/\R/ /;

    my $backend = $args{backend} // 'Text::Wrap';
    my $width = $args{width} // 80;

    log_trace "Using text wrapping backend %s", $backend;

    my @paras = split /\R{2,}/, $text;

    my $res = '';
    while (my ($para_text, $blank_lines) = splice @paras, 0, 2) {
        if ($backend eq 'Text::ANSI::Fold') {
            require Text::ANSI::Fold;
            $para_text = join("", map {"$_\n"} Text::ANSI::Fold->new(width=>$width)->text($para_text)->chops);
        } elsif ($backend eq 'Text::ANSI::Util') {
        } elsif ($backend eq 'Text::ANSI::WideUtil') {
        } elsif ($backend eq 'Text::Fold') {
        } elsif ($backend eq 'Text::LineFold') {
        } elsif ($backend eq 'Text::Wide::Util') {
        } elsif ($backend eq 'Text::Wrap') {
            require Text::Wrap;
            local $Text::Wrap::columns = $width;
            $para_text = Text::Wrap::wrap('', '', $para_text);
        } else {
            return [400, "Unknown backend '$backend'"];
        }

        $res .= $para_text . $blank_lines;
    }
    [200, "OK", $res];
}

1;
#ABSTRACT: Utilities related to text wrapping

=head1 DESCRIPTION

This distributions provides the following command-line utilities:

# INSERT_EXECS_LIST


=head1 SEE ALSO

L<Text::Wrap> and other backends.

=cut
