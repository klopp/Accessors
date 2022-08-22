package Accessors::Base;

use v5.10;
use strict;
use warnings;

use Array::Utils qw/intersect array_minus/;
use Carp qw/cluck confess carp croak/;
use Const::Fast;
use List::MoreUtils qw/any/;
use Scalar::Util qw/blessed reftype/;

const my $ACCESS_DENIED => 'Access denied to field "%s"';
const my $METHOD_EXISTS => 'Method "%s" already exists';
const my $INVALID_TYPE  => 'Can not change "%s" type ("%s") to "%s"';
const my @PKG_METHODS   => qw/can isa new VERSION DESTROY AUTOLOAD CHECK BEGIN END/;

# default error handlers:
const my $EMETHOD => 'confess';
const my $EACCESS => 'confess';

use vars qw/$VERSION $PROP_METHOD $PRIVATE_DATA %OPT/;
$VERSION      = '2.020';
$PROP_METHOD  = 'property';
$PRIVATE_DATA = __PACKAGE__ . '::Data';

use base qw/Exporter/;
our @EXPORT = qw/$PROP_METHOD $PRIVATE_DATA check_chtype access_error method_error set_internal_data/;

#------------------------------------------------------------------------------
sub access_error
{
    my ( $self, $field ) = @_;
    my $eaccess = $self->{$PRIVATE_DATA}->{OPT}->{access};
    if ($eaccess) {
        if ( ref $eaccess eq 'CODE' ) {
            $eaccess->( $self, $field );
        }
        elsif ( Carp->can($eaccess) ) {
            no strict 'refs';
            $eaccess->( sprintf $ACCESS_DENIED, $field );
        }
    }
    return;
}

#------------------------------------------------------------------------------
sub method_error
{
    my ( $self, $method ) = @_;
    my $emethod = $self->{$PRIVATE_DATA}->{OPT}->{method};
    if ($emethod) {
        if ( ref $emethod eq 'CODE' ) {
            $emethod->( $self, $method );
        }
        elsif ( Carp->can($emethod) ) {
            no strict 'refs';
            $emethod->( sprintf $METHOD_EXISTS, $method );
        }
    }
    return;
}

#------------------------------------------------------------------------------
sub _type_error
{
    my ( $self, $field, $type ) = @_;
    my $echtype = $self->{$PRIVATE_DATA}->{OPT}->{chtype}->{$field};
    if ($echtype) {
        if ( ref $echtype eq 'CODE' ) {
            $echtype->( $self, $field, $type );
        }
        elsif ( Carp->can($echtype) ) {
            no strict 'refs';
            $echtype->(
                sprintf $INVALID_TYPE,
                ( ( caller(1) )[0] ) . q{::} . $field,
                ( reftype $self->{$field} ), $type
            );
        }
    }
    return;
}

#------------------------------------------------------------------------------
sub check_chtype
{
    my ( $self, $from, $to ) = @_;
    state @CTYPES = ( 'REGEXP', 'HASH', 'ARRAY', 'SCALAR' );

    # undef = something, OK
    # something = undef, OK
    return 1 if ( !defined $self->{$from} || !defined $to );

    my ( $rfrom, $rto ) = ( reftype $self->{$from} || '', reftype $to || '' );
    if ( any { $rfrom eq $_ } @CTYPES ) {
        return 1 if $rfrom eq $rto;
        _type_error( $self, $from, $rto );
        return;
    }
    1;
}

#------------------------------------------------------------------------------
sub import
{
    my $self = shift;

    # temporary storage:
    %OPT = ();

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
sub set_internal_data
{
    my ( $self, $params ) = @_;

    my $caller_pkg = ( caller(1) )[0];
    confess sprintf( '%s can deal with blessed references only', $caller_pkg )
        unless blessed $self;
    confess
        sprintf( "Can not set private data, field '%s' already exists in %s.\nUse \$%s::%s = 'unique name' before\n",
        $PRIVATE_DATA, $caller_pkg, $caller_pkg, $PRIVATE_DATA )
        if exists $self->{$PRIVATE_DATA};

    if ($params) {
        confess sprintf( '%s can receive option as hash reference only', $caller_pkg )
            if ref $params ne 'HASH';
        %OPT = ( %OPT, %{$params} );
    }

    my @fields = keys %{$self};
    @fields = intersect( @fields, @{ $OPT{include} } ) if $OPT{include};
    @fields = array_minus( @fields, @{ $OPT{exclude} } )
        if $OPT{exclude};
    @fields = array_minus( @fields, @PKG_METHODS );
    $self->{$PRIVATE_DATA}->{FIELDS} = [@fields];
    $OPT{method} = $EMETHOD unless exists $OPT{method};
    $OPT{access} = $EACCESS unless exists $OPT{access};
    %{ $self->{$PRIVATE_DATA}->{OPT} } = %OPT;
    return $self;
}

#------------------------------------------------------------------------------
1;

__END__

=head1 NAME

Accessors::Base

=head1 DESCRIPTION

Base class for Accessors::Weak and Accessors::Strict
 
