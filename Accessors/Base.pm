package Accessors::Base;

use strict;
use warnings;

use Array::Utils qw/intersect array_minus/;
use Carp qw/cluck confess carp croak/;
use Const::Fast;
use Scalar::Util qw/blessed/;

const my $ACCESS_DENIED => 'Access denied to field "%s"';
const my $METHOD_EXISTS => 'Method "%s" already exists';
const my @PKG_METHODS   => qw/can isa new VERSION DESTROY AUTOLOAD CHECK BEGIN END/;

# default error handlers:
const my $EMETHOD => 'confess';
const my $EACCESS => 'confess';

use vars qw/$VERSION $PROP_METHOD $PRIVATE_DATA %OPT/;
$VERSION      = '2.010';
$PROP_METHOD  = 'property';
$PRIVATE_DATA = __PACKAGE__ . '::Data';

use base qw/Exporter/;
our @EXPORT = qw/$PROP_METHOD $PRIVATE_DATA access_error method_error set_internal_data/;

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
 
