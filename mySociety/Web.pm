#!/usr/bin/perl
#
# mySociety/Web.pm:
# CGI-like class which we can extend.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Web.pm,v 1.10 2006/07/31 13:12:40 chris Exp $
#

package mySociety::Web;

use strict;

use HTML::Entities;

use Carp;
use CGI qw(-nosticky);
my $have_cgi_fast = 0;
eval {
    use CGI::Fast;
    $have_cgi_fast = 1;
};

use HTML::Entities;

use fields qw(q scratch);
@mySociety::Web::ISA = qw(Exporter); # for the Import* methods

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(ent);
}
our @EXPORT_OK;

sub ent ($) {
    my $s = shift;
    return encode_entities($s, '<>&');
}

=item new [QUERY]

Construct a new mySociety::Web object, optionally from an existing QUERY. Uses
CGI::Fast if available, or CGI otherwise.

=cut
sub new ($;$) {
    my ($class, $q) = @_;
    if (!defined($q)) {
        $q = $have_cgi_fast ? new CGI::Fast() : new CGI();
        return undef if (!defined($q)); # reproduce CGI::Fast behaviour
    }
    $q->autoEscape(1);
    my $self = fields::new('mySociety::Web');
    $self->{q} = $q;
    $self->{scratch} = { };
    return bless($self, $class);
}

# q
# Access to the underlying CGI (or whatever) object.
sub q ($) {
    return $_[0]->{q};
}

=item scratch

Return a reference to the internal scratchpad.

=cut
sub scratch ($) {
    return $_[0]->{scratch};
}

# AUTOLOAD
# Is-a inheritance isn't safe for this kind of thing, so we use has-a.
sub AUTOLOAD {
    my $f = $mySociety::Web::AUTOLOAD;
    $f =~ s/^.*:://;
    eval "sub $f { my \$q = shift; return \$q->{q}->$f(\@_); }";
    goto(&$mySociety::Web::AUTOLOAD);
}

=item Import WHAT PARAMS

Import parameters (WHAT = 'p') or cookies (WHAT = 'c') from the query into the
caller's own namespace; each specified parameter (cookie) NAME is assigned to a
variable "$qp_NAME" ("$qc_NAME"), which should be declared with our(...).
PARAMS gives a hash of NAME => DEFAULT or NAME => [CHECK, DEFAULT]. If a
parameter is not specified, it takes the given DEFAULT value. Optionally, a
CHECK may be given to validate each parameter; a parameter which does not
validate is assigned its DEFAULT value. CHECK may be either a regexp
(qr/.../...) or a code reference, which will be passed the mySociety::Web
object and the named parameter; it should return true if the parameter is valid
and false otherwise.

This function may be called several times for one request.

=cut
use Data::Dumper;
sub Import ($$%) {
    my ($self, $what, %p) = @_;
    my $q = $self->q();

    croak("WHAT should be 'p' for parameters, or 'c' for cookies")
        unless ($what =~ m#^[pc]$#);
    my $p = ($what eq 'p');

    while (my ($name, $x) = each(%p)) {
        my $val = $p ? $q->param($name) : $q->cookie($name);
        if (ref($x) eq 'ARRAY') {
            croak("PARAMS->{$name} should be a 2-element list") unless (@$x == 2);
            my ($check, $dfl) = @$x;
            if (!defined($val)) {
                $val = $dfl;
            } elsif (ref($check) eq 'CODE') {
                $val = $dfl if (!&$check($self, $val));
            } elsif (ref($check) eq 'Regexp') {
                $val = $dfl if ($val !~ $check);
            } else {
                croak("PARAMS->{$name}->[0] should be a code reference or regexp");
            }
        } elsif (defined(ref($x))) {
            croak("PARAMS->{$name} is a reference to " . ref($x) . "; should be scalar or array");
        } else {
            $val = $x if (!defined($val));
        }

        {
            no strict 'refs';
            ${"q${what}_$name"} = $val;
            push(@mySociety::Web::EXPORT, "\$q${what}_$name");
        }
    }

    {
        # Black magic.
        local $Exporter::ExportLevel = 1;
        import mySociety::Web;
    }
}

=item ImportMulti PARAMS

Import multi-valued parameters from the query into the caller's own namespace;
each specified parameter NAME is assigned to an array "@qp_NAME", which should
be declared with our(...). PARAMS gives a hash of NAME => CHECK; each CHECK is
applied to each instance of a multi-valued parameter, filtering the values
supplied by the client.

=cut
sub ImportMulti ($%) {
    my ($self, %p) = @_;
    my $q = $self->q();

    while (my ($name, $check) = each(%p)) {
        my @val;
        if (ref($check) eq 'CODE') {
            @val = grep { &$check($self, $_) } $q->param('name');
        } elsif (ref($check) eq 'Regexp') {
            @val = grep($check, $q->param('name'));
        } else {
            croak("PARAMS->{$_} should be a code reference or regexp");
        }

        {
            no strict 'refs';
            @{"qp_$name"} = @val;
            push(@mySociety::Web::EXPORT, "\@qp_$name");
        }
    }

    {
        # Black magic.
        local $Exporter::ExportLevel = 1;
        import mySociety::Web;
    }
}

=item NewURL [PARAM VALUE ...]

Return a URL for reinvoking this script with changed parameters. Each PARAM
gives the name of a parameter; the VALUE may be a scalar, a reference list to
indicate that a multivalued parameter should be added; or undef to indicate
that the parameter should be removed in the new URL.

=cut
sub NewURL ($%) {
    my ($q, %p) = @_;
    my @v = ();
    my $q = $self->q();
    my $url = $q->url(-absolute => 1);
    foreach my $key ($q->param()) {
        if (exists($p{$key})) {
            next if (!defined($p{$key}));
            my $v = $p{$key};
            croak("can't use ref to " . ref($v) . " as param value")
                if (ref($v) && ref($v) ne 'ARRAY');
            $v = [$v] if (!ref($v));
            push(@v, map { urlencode($key) . '=' . urlencode($_) } @$v);
        } else {
            push(@v, map { urlencode($key) . '=' . urlencode($_) } $q->param($key));
        }
    }
    return "$url?" . join(';', @v);
}

=item header PARAMS

Return an HTTP header, influenced by PARAMS as in CGI.pm.

=cut
sub header ($%) {
    my ($self, %p) = @_;
    if (!exists($p{"-type"})) {
        $p{"-type"} = 'text/html; charset=utf-8';
    }
    return $self->q()->header(%p);
}

=item urlencode STRING

Return a URL-encoded copy of STRING.

=cut
sub urlencode ($) {
    my $v = encode_utf8($_[0]);
    $v =~ s/([^A-Za-z0-9])/sprintf('%%%02x', ord($1))/ge;
    return $v;
}

sub start_form ($%) {
    my ($self, %p) = @_;
    $p{'-accept_charset'} = 'utf-8' if (!exists($p{'-accept_charset'}));
    return $self->q()->start_form(%p);
}

1;
