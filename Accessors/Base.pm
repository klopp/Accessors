package Accessors::Base;

use strict;
use warnings;

use Carp qw/cluck confess carp croak/;
use Const::Fast;
use Array::Utils qw/intersect array_minus/;
use Scalar::Util qw/blessed/;

const my $ACCESS_DENIED => 'Access denied to field "%s"';
const my $METHOD_EXISTS => 'Method "%s" already exists';

use vars qw/%OPT @FIELDS $PROP_METHOD/;

$PROP_METHOD = 'property';

use base qw/Exporter/;
our @EXPORT = qw/@FIELDS %OPT $PROP_METHOD _eaccess _emethod/;

use Modern::Perl;
use DDP;

#------------------------------------------------------------------------------
sub _eaccess
{
    my ($field) = @_;
    if ( $OPT{access} && Carp->can( $OPT{access} ) ) {
        no strict 'refs';
        $OPT{access}->( sprintf $ACCESS_DENIED, $field );
    }
    return;
}

#------------------------------------------------------------------------------
sub _emethod
{
    my ($method) = @_;
    if ( $OPT{method} && Carp->can( $OPT{method} ) ) {
        no strict 'refs';
        $OPT{method}->( sprintf $METHOD_EXISTS, $method );
    }
    return;
}

#------------------------------------------------------------------------------
sub _import
{
    my $self = shift;

    my (@exports);
    for (@_) {
        if ( ref $_ eq 'HASH' ) {
            %OPT = ( %OPT, %{$_} );
        }
        else {
            push @exports, $_;
        }
    }

    @_ = ( $self, @exports );
    goto &Exporter::import;
}
#------------------------------------------------------------------------------
sub _set_internal_data
{
    my ( $self, $opt ) = @_;

    confess sprintf( '%s can deal with blessed references only', __PACKAGE__ )
        unless blessed $self;

    if ($opt) {
        confess sprintf( '%s can receive option as hash reference only', __PACKAGE__ )
            if ref $opt ne 'HASH';
        %OPT = ( %OPT, %{$opt} );
    }
    @FIELDS = keys %{$self};
    @FIELDS = intersect( @FIELDS, @{ $OPT{include} } ) if $OPT{include};
    @FIELDS = array_minus( @FIELDS, @{ $OPT{exclude} } ) if $OPT{exclude};
    return $self;
}

#------------------------------------------------------------------------------
1;

=head1 NAME

Accessors::Base

=head1 DESCRIPTION

Base class for Accessors::Weak and Accessors::Strict
 