package Accessors::Strict;

use strict;
use warnings;
use Carp qw/cluck confess carp croak/;
use Const::Fast;

use vars qw/$VERSION $CLASS_SUFFIX $PRIVATE_KEYS/;
$VERSION      = '2.001';
$CLASS_SUFFIX = 'DEADBEEF';

use List::MoreUtils qw/any/;
our @EXPORT_OK = qw/create_accessors create_property create_get_set/;

use Accessors::Base;

use Modern::Perl;
use DDP;

#------------------------------------------------------------------------------
sub import
{
    goto &Accessors::Base::_import;
}

#------------------------------------------------------------------------------
sub _set_internal_data
{
    my ( $self, $opt ) = @_;

    Accessors::Base::_set_internal_data( $self, $opt );

    my $package = ref $self;
    $PRIVATE_KEYS                = $package . '_KEYS';
    $self->{$PRIVATE_KEYS}       = {} unless $self->{$PRIVATE_KEYS};
    $self->{$PRIVATE_KEYS}->{$_} = $self->{$_} for @FIELDS;

    my $newclass = $package . '::' . $CLASS_SUFFIX++;
    no strict 'refs';
    @{"$newclass\::ISA"} = ($package);
    return $newclass;
}

#------------------------------------------------------------------------------
sub _create_access
{
    my ($self) = @_;

    my $access = sub {
        my $field = shift;
        if ( any { $field eq $_ } @FIELDS ) {
            if (@_) {
                my $value = shift;
                if ( $OPT{validate}->{$field} ) {
                    return unless $OPT{validate}->{$field}->($value);
                }
                $self->{$PRIVATE_KEYS}->{$field} = $value;
            }
            return $self->{$PRIVATE_KEYS}->{$field};
        }
        else {
            return _eaccess($field);
        }
    };
    return $access;
}

#------------------------------------------------------------------------------
sub create_accessors
{
    my ( $self, $opt ) = @_;
    my $newclass = _set_internal_data( ${$self}, $opt );
    my $access   = _create_access( ${$self} );

    for my $field (@FIELDS) {
        if ( !${$self}->can($field) ) {
            no strict 'refs';
            *{"$newclass\::$field"} = sub {
                shift;
                return $access->( $field, @_ );
            }
        }
        else {
            _emethod( ( ref ${$self} ) . '::' . $field );
        }
    }
    ${$self} = bless $access, $newclass;
    return ${$self};
}

#------------------------------------------------------------------------------
sub create_property
{
    my ( $self, $opt ) = @_;
    my $newclass = _set_internal_data( ${$self}, $opt );
    my $property = $OPT{property} || $PROP_METHOD;
    my $access   = _create_access( ${$self} );

    if ( !${$self}->can($property) ) {
        no strict 'refs';
        *{"$newclass\::$property"} = sub {
            shift;
            return $access->(@_);
        }
    }
    else {
        _emethod($property);
    }
    ${$self} = bless $access, $newclass;
    return ${$self};
}

#------------------------------------------------------------------------------
sub create_get_set
{
    my ( $self, $opt ) = @_;
    my $newclass = _set_internal_data( ${$self}, $opt );
    my $access   = _create_access( ${$self} );

    for my $field (@FIELDS) {
        if ( !${$self}->can( 'get_' . $field ) ) {
            no strict 'refs';
            *{"$newclass\::get_$field"} = sub {
                shift;
                return $access->($field);
            }
        }
        else {
            _emethod( ( ref ${$self} ) . '::get_' . $field );
        }
        if ( !${$self}->can( 'set_' . $field ) ) {
            no strict 'refs';
            *{"$newclass\::set_$field"} = sub {
                shift;
                return $access->( $field, shift );
            }
        }
        else {
            _emethod( ( ref ${$self} ) . '::set_' . $field );
        }
    }
    ${$self} = bless $access, $newclass;
    return ${$self};
}

#------------------------------------------------------------------------------
1;

__END__

