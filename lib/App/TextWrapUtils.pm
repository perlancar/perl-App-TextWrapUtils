package App::TextWrapUtils;

use 5.010001;
use strict;
use warnings;
use Log::ger;

use Clipboard::Any ();

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
                      Text::WideChar::Util
                      Text::Wrap
              );

our %argspecopt0_filename = (
    filename => {
        schema => 'filename*',
        default => '-',
        pos => 0,
        description => <<'_',

Use dash (`-`) to read from stdin.

_
    },
);

our %argspecopt_backend = (
    backend => {
        schema => ['perl::modname*', in=>\@BACKENDS],
        default => 'Text::ANSI::Util',
        cmdline_aliases => {b=>{}},
    },
);

our %argspecopt_width = (
    width => {
        schema => 'posint*',
        default => 80,
        cmdline_aliases => {w=>{}},
    },
);

$SPEC{textwrap} = {
    v => 1.1,
    summary => 'Wrap (fold) paragraphs in text using one of several Perl modules',
    description => <<'_',

Paragraphs are separated with two or more blank lines.

_
    args => {
        %argspecopt0_filename,
        %argspecopt_backend,
        width => {
            schema => 'posint*',
            default => 80,
            cmdline_aliases => {w=>{}},
        },
        # XXX arg: initial indent string/number of spaces?
        # XXX arg: subsequent indent string/number of spaces?
        # XXX arg: option to not wrap verbatim paragraphs
        # XXX arg: pass per-backend options

        # internal: _text (pass text directly)
    },
};
sub textwrap {
    require File::Slurper::Dash;

    my %args = @_;
    my $text;
    if (defined $args{_text}) {
        $text = $args{_text};
    } else {
        $text = File::Slurper::Dash::read_text($args{filename});
        $text =~ s/\R/ /;
    }

    my $backend = $args{backend} // 'Text::ANSI::Util';
    my $width = $args{width} // 80;

    log_trace "Using text wrapping backend %s", $backend;

    my @paras = split /(\R{2,})/, $text;

    my $res = '';
    while (my ($para_text, $blank_lines) = splice @paras, 0, 2) {
        $para_text =~ s/\R/ /g;

        if ($backend eq 'Text::ANSI::Fold') {
            require Text::ANSI::Fold;
            state $fold = Text::ANSI::Fold->new(width => $width,
                                                boundary => 'word',
                                                linebreak => &Text::ANSI::Fold::LINEBREAK_ALL);
            $para_text = join("\n", $fold->text($para_text)->chops);
        } elsif ($backend eq 'Text::ANSI::Util') {
            require Text::ANSI::Util;
            $para_text = Text::ANSI::Util::ta_wrap($para_text, $width);
        } elsif ($backend eq 'Text::ANSI::WideUtil') {
            require Text::ANSI::WideUtil;
            $para_text = Text::ANSI::WideUtil::ta_mbwrap($para_text, $width);
        } elsif ($backend eq 'Text::Fold') {
            require Text::Fold;
            $para_text = Text::Fold::fold_text($para_text, $width);
        } elsif ($backend eq 'Text::LineFold') {
            require Text::LineFold;
            $para_text = Text::LineFold->new(ColMax => $width)->fold('', '', $para_text);
            $para_text =~ s/\R\z//;
        } elsif ($backend eq 'Text::WideChar::Util') {
            require Text::WideChar::Util;
            $para_text = Text::WideChar::Util::mbwrap($para_text, $width);
        } elsif ($backend eq 'Text::Wrap') {
            require Text::Wrap;
            local $Text::Wrap::columns = $width;
            $para_text = Text::Wrap::wrap('', '', $para_text);
        } else {
            return [400, "Unknown backend '$backend'"];
        }

        $res .= $para_text . ($blank_lines // "");
    }
    [200, "OK", $res];
}

$SPEC{textwrap_clipboard} = {
    v => 1.1,
    summary => 'Wrap (fold) paragraphs in text in clipboard using one of several Perl modules',
    description => <<'_',

This is shortcut for something like:

    % clipget | textwrap ... | clipadd

where <prog:clipget> and <prog:clipadd> are utilities to get text from clipboard
and set text of clipboard, respectively.

_
    args => {
        %argspecopt_backend,
        %argspecopt_width,
        %Clipboard::Any::argspecopt_clipboard_manager,
    },
};
sub textwrap_clipboard {
    my %args = @_;
    my $cm = delete $args{clipboard_manager};

    my $res;
    $res = Clipboard::Any::get_clipboard_content(clipboard_manager=>$cm);
    return [500, "Can't get clipboard content: $res->[0] - $res->[1]"]
        unless $res->[0] == 200;
    my $text = $res->[2];

    $res = textwrap(%args, _text => $text);
    return $res unless $res->[0] == 200;
    my $wrapped_text = $res->[2];

    $res = Clipboard::Any::add_clipboard_content(clipboard_manager=>$cm, content=>$wrapped_text);
    return [500, "Can't add clipboard content: $res->[0] - $res->[1]"]
        unless $res->[0] == 200;

    [200, "OK"];
}

$SPEC{textunwrap} = {
    v => 1.1,
    summary => 'Unwrap (unfold) multiline paragraphs to single-line ones',
    description => <<'_',

This is a shortcut for:

    % textwrap -w 999999

_
    args => {
        %argspecopt0_filename,
        %argspecopt_backend,
    },
};
sub textunwrap {
    my %args = @_;
    textwrap(%args, width=>999_999);
}

$SPEC{textunwrap_clipboard} = {
    v => 1.1,
    summary => 'Unwrap (unfold) multiline paragraphs in clipboard to single-line ones',
    description => <<'_',

This is shortcut for something like:

    % clipget | textunwrap ... | clipadd

where <prog:clipget> and <prog:clipadd> are utilities to get text from clipboard
and set text of clipboard, respectively.

_
    args => {
        %argspecopt_backend,
        %Clipboard::Any::argspecopt_clipboard_manager,
    },
};
sub textunwrap_clipboard {
    my %args = @_;
    my $cm = delete $args{clipboard_manager};

    my $res;
    $res = Clipboard::Any::get_clipboard_content(clipboard_manager=>$cm);
    return [500, "Can't get clipboard content: $res->[0] - $res->[1]"]
        unless $res->[0] == 200;
    my $text = $res->[2];

    $res = textunwrap(%args, _text => $text);
    return $res unless $res->[0] == 200;
    my $unwrapped_text = $res->[2];

    $res = Clipboard::Any::add_clipboard_content(clipboard_manager=>$cm, content=>$unwrapped_text);
    return [500, "Can't add clipboard content: $res->[0] - $res->[1]"]
        unless $res->[0] == 200;

    [200, "OK"];
}

1;
#ABSTRACT: Utilities related to text wrapping

=head1 DESCRIPTION

This distributions provides the following command-line utilities:

# INSERT_EXECS_LIST

Keywords: fold.


=head1 SEE ALSO

L<Text::Wrap>, L<Text::ANSI::Util> and other backends.

=cut
