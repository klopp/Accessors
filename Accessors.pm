package Accessors;

use strict;
use warnings;

use Array::Utils qw/intersect array_minus/;
use Carp qw/cluck confess carp croak/;
use Const::Fast;
use Data::Lock qw/dlock dunlock/;
use List::MoreUtils qw/any/;
use Scalar::Util qw/blessed reftype/;

const my $ACCESS_DENIED => 'Access denied to field "%s"';
const my $EACCESS       => 'confess';
const my $EMETHOD       => 'confess';
const my $INVALID_TYPE  => 'Can not change "%s" type ("%s") to "%s"';
const my $METHOD_EXISTS => 'Method "%s" already exists';
const my $PROP_METHOD   => 'property';

use vars qw/$VERSION $PRIVATE_DATA %OPT/;
$VERSION = '3.00';
our @EXPORT_OK = qw/create_accessors create_property create_get_set/;

#------------------------------------------------------------------------------
BEGIN {
    $PRIVATE_DATA = __PACKAGE__ . '::Data::' . int rand time;
    dlock $PRIVATE_DATA;
}

#------------------------------------------------------------------------------
sub import
{
    my $self = shift;

    my @exports;
    for (@_) {
        if ( ref $_ eq 'HASH' ) {
            %OPT = ( %OPT, %{$_} );
        }
        elsif ( !ref $_ ) {
            push @exports, $_;
        }
        else {
            confess sprintf "Constructor only accepts a scalar and a hash reference.\n";
        }
    }

    @_ = ( $self, @exports );
    goto &Exporter::import;
}

#------------------------------------------------------------------------------
sub _check_ehandler
{
    my ($ehandler) = @_;

    return 1 if ref $OPT{$ehandler} eq 'CODE';
    return 1 if !ref $OPT{$ehandler} && Carp->can( $OPT{$ehandler} );
    return confess sprintf "Invalid '%s' parameter value.\n", $ehandler;
}

#------------------------------------------------------------------------------
sub _set_internal_data
{
    my ( $self, $opt ) = @_;

    my $caller_pkg = ( caller 1 )[0];
    confess sprintf( '%s can deal with blessed references only', $caller_pkg )
        unless blessed $self;
    confess sprintf( "Can not set private data, field '%s' already exists in %s.\n",
        $PRIVATE_DATA, $caller_pkg, $caller_pkg, $PRIVATE_DATA )
        if exists $self->{$PRIVATE_DATA};

    if ($opt) {
        confess sprintf( '%s can receive option as hash reference only', $caller_pkg )
            if ref $opt ne 'HASH';
        %OPT = ( %OPT, %{$opt} );
    }

    my @fields = keys %{$self};
    @fields = intersect( @fields, @{ $OPT{include} } ) if $OPT{include};
    @fields = array_minus( @fields, @{ $OPT{exclude} } )
        if $opt->{exclude};

    $self->{$PRIVATE_DATA}->{FIELDS} = [@fields];
    $OPT{lock}    //= 1;
    $OPT{emethod} //= $EMETHOD;
    $OPT{eaccess} //= $EACCESS;
    _check_ehandler('emethod');
    _check_ehandler('eaccess');
    _check_ehandler('etype') if $OPT{etype};

    %{ $self->{$PRIVATE_DATA}->{OPT} } = ( %OPT, %{$opt} );

    $self->{$PRIVATE_DATA}->{LOCKABLE} = $self->{$PRIVATE_DATA}->{FIELDS};

    my @all = keys %{$self};
    if ( ref $self->{$PRIVATE_DATA}->{OPT}->{lock} eq 'ARRAY' ) {
        $self->{$PRIVATE_DATA}->{LOCKABLE}
            = [ intersect( @{ $self->{$PRIVATE_DATA}->{OPT}->{lock} }, @all ) ];
    }
    elsif ( $self->{$PRIVATE_DATA}->{OPT}->{lock} eq 'all' ) {
        $self->{$PRIVATE_DATA}->{LOCKABLE} = \@all;
    }

    $self->{$PRIVATE_DATA}->{LOCKABLE}
        = [ grep { $_ ne $PRIVATE_DATA } @{ $self->{$PRIVATE_DATA}->{LOCKABLE} } ];
    dlock $self->{$_} for @{ $self->{$PRIVATE_DATA}->{LOCKABLE} };

    return ( \%{ $self->{$PRIVATE_DATA}->{OPT} }, \@{ $self->{$PRIVATE_DATA}->{FIELDS} } );
}

#------------------------------------------------------------------------------
sub _access_error
{
    my ( $self, $field ) = @_;
    my $eaccess = $self->{$PRIVATE_DATA}->{OPT}->{eaccess};
    if ( ref $eaccess eq 'CODE' ) {
        $eaccess->( $self, $field );
    }
    else {
        no strict 'refs';
        $eaccess->( sprintf $ACCESS_DENIED, $field );
    }
    return;
}

#------------------------------------------------------------------------------
sub _method_error
{
    my ( $self, $method ) = @_;
    my $emethod = $self->{$PRIVATE_DATA}->{OPT}->{emethod};
    if ( ref $emethod eq 'CODE' ) {
        $emethod->( $self, $method );
    }
    else {
        no strict 'refs';
        $emethod->( sprintf $METHOD_EXISTS, $method );
    }
    return;
}

#------------------------------------------------------------------------------
sub _check_etype
{
    my ( $self, $from, $to ) = @_;

    my $etype = $self->{$PRIVATE_DATA}->{OPT}->{etype};
    return 1 unless $etype;

    # undef = something, OK
    # something = undef, OK
    return 1 if ( !defined $self->{$from} || !defined $to );

    my ( $rfrom, $rto ) = ( reftype $self->{$from} || q{}, reftype $to || q{} );
    return 1 if $rfrom eq $rto;

    if ( ref $etype eq 'CODE' ) {
        $etype->( $self, $from, $rto );
    }
    else {
        no strict 'refs';
        Carp->$etype->( sprintf $INVALID_TYPE, ( ( caller 1 )[0] ) . q{::} . $from, $rfrom, $rto );
    }

    return;
}

#------------------------------------------------------------------------------
sub create_accessors
{
    my ( $self, $params ) = @_;
    my $package = ref $self;
    my ( $opt, $fields ) = _set_internal_data( $self, $params );

    for my $field ( @{$fields} ) {
        if ( !$self->can($field) ) {
            no strict 'refs';
            *{"$package\::$field"} = sub {
                my $self = shift;
                if (@_) {
                    my $value = shift;
                    local *__ANON__ = __PACKAGE__ . "::$field";
                    return unless _check_etype( $self, $field, $value );
                    if ( $opt->{validate}->{$field} ) {
                        return unless $opt->{validate}->{$field}->($value);
                    }
                    my $lock = any { $field eq $_ } @{ $self->{$PRIVATE_DATA}->{LOCKABLE} };
                    dunlock $self->{$field} if $lock;
                    $self->{$field} = $value;
                    dlock $self->{$field} if $lock;
                }
                return $self->{$field};
            }
        }
        else {
            _method_error( $self, "$package\::$field" );
        }
    }
    return $self;
}

#------------------------------------------------------------------------------
sub create_property
{
    my ( $self, $params ) = @_;
    my $package = ref $self;
    my ( $opt, $fields ) = _set_internal_data( $self, $params );
    my $property = $opt->{property} || $PROP_METHOD;

    if ( !$self->can($property) ) {
        no strict 'refs';
        *{"$package\::$property"} = sub {
            my ( $self, $field ) = ( shift, shift );
            local *__ANON__ = __PACKAGE__ . "::$property";
            if ( any { $field eq $_ } @{$fields} ) {
                if (@_) {
                    my $value = shift;
                    return unless _check_etype( $self, $field, $value );
                    if ( $opt->{validate}->{$field} ) {
                        return unless $opt->{validate}->{$field}->($value);
                    }
                    my $lock = any { $field eq $_ } @{ $self->{$PRIVATE_DATA}->{LOCKABLE} };
                    dunlock $self->{$field} if $lock;
                    $self->{$field} = $value;
                    dlock $self->{$field} if $lock;
                }
                return $self->{$field};
            }
            else {
                return _access_error( $self, $field );
            }
        }
    }
    else {
        _method_error( $self, "$package\::$property" );
    }
    return $self;
}

#------------------------------------------------------------------------------
sub create_get_set
{
    my ( $self, $params ) = @_;
    my $package = ref $self;
    my ( $opt, $fields ) = _set_internal_data( $self, $params );

    for my $field ( @{$fields} ) {
        if ( !$self->can( 'get_' . $field ) ) {
            no strict 'refs';
            *{"$package\::get_$field"} = sub {
                my ($self) = @_;
                return $self->{$field};
            }
        }
        else {
            _method_error( $self, "$package\::get_$field" );
        }
        if ( !$self->can( 'set_' . $field ) ) {
            no strict 'refs';
            *{"$package\::set_$field"} = sub {
                my ( $self, $value ) = @_;
                local *__ANON__ = __PACKAGE__ . "::set_$field";
                return unless _check_etype( $self, $field, $value );
                if ( $opt->{validate}->{$field} ) {
                    return unless $opt->{validate}->{$field}->($value);
                }
                my $lock = any { $field eq $_ } @{ $self->{$PRIVATE_DATA}->{LOCKABLE} };
                dunlock $self->{$field} if $lock;
                $self->{$field} = $value;
                dlock $self->{$field} if $lock;
                return $self->{$field};
            }
        }
        else {
            _method_error( $self, "$package\::set_$field" );
        }
    }
    return $self;
}

#------------------------------------------------------------------------------
1;
__END__

=head1 NAME

Accessors

=head1 SYNOPSIS

=over

=item Accessors for whole package

    package AClass;
    use base q/Accessors/;
    sub new
    {
        my ($class) = @_;
        my $self = bless {
            scalar => 'scalar value',
        }, $class;

        return $self->create_accessors;
        # or
        # return $self->create_property;
        # or
        # return $self->create_get_set;
    }

=item Accessors for single object

    use Accessors qw/create_accessors create_property create_get_set/;
    my $object = MyClass->new;
    create_accessors($object);
    # OR
    # create_property($object);
    # OR
    # create_get_set($object);

=back

=head1 DESCRIPTION

Create methods to get/set package fields.

=head1 CUSTOMIZATION

All methods take an optional argument: a hash reference with additional parameters. For example:

    create_property($object, { exclude => [ 'index' ], access => 'carp', property => 'prop' } );

=over

=item include => [ name1, name2, ... ]

List of field names for which to create accessors. By default, accessors are created for all fields.

=item exclude => [ name1, name2, ... ]

List of field names for which you do not need to create accessors. This parameter is processed after C<include>.

=item property => name

The name of the method that will be created when C<create_property()> is called. The default is C<"property">.

=item validate => { field => coderef, ... }

List of validators for set values. Functions must return undef if validation fails. In this case, the field value is not set and the accessor returns undef. For example:

    $books->create_accessors( {
        validate => {
            author => sub
            {
                my ($author) = @_;
                if( length $author < 3 ) {
                    carp "Author name is too short";
                    return;
                }
                1;
            }
        },
    });


=item eaccess => VALUE

How to handle an access violation (see the C<include> and C<exclude> lists). Can be:

=over

=item * C<"carp">, C<"cluck">, C<"croak"> or C<"confess"> (use L<Carp> methods with diagnostics). 

=item * Reference to the handler code, to which two arguments will be passed: a reference to the work object and the field name.

=item * C<undef> or any other value - do nothing.

Without C<eaccess> C<Carp::confess> is called with the appropriate diagnostic.

=back

=item emethod => VALUE

When an accessor is created, if a method with the same name is found in a package or object, this handler will be called. Values are similar to the C<access> parameter.

=item lock => BOOL

Protects fields for which accessors are created from direct modification:

    $object->set_foo('bar'); # OK
    say $object->get_foo;    # OK
    say $object->{foo};      # OK
    $object->{foo} = 'bar';  # ERROR, "Modification of a read-only value attempted at..."

By default, only those fields for which accessors are created are blocked. Possible values:

=over

=item * C<"all"> block all fields, including fields without accessors.
=item * C<ARRAY> blocking only fields from the array, including fields without accessors.

=back

=back

=head2 Setting custom properties on module load.

    use Accessors qw/create_accessors/, { access => croak };

=head2 Setting custom properties on the methods call.

    $object->create_accessors( $object, { exclude => [ 'index' ] } );

=head1 SUBROUTINES/METHODS

=over

=item create_accessors( I<$options> )

Creates methods to get and set the values of fields with the same name. For example, the following method would be created for the C<author> field:

    sub author
    {
        my $self = shift;
        $self->{author} = shift if @_;
        return $self->{author};
    }

In case of an access violation (see the C<include> and C<exclude> parameters), the C<access> parameter is processed.

=item create_property( I<$options> )

Creates a method named C<$options->{property}> (default C<"property">) to access fields:

    sub property
    {
        my ( $self, $field ) = (shift, shift);
        $self->{$field} = shift if @_;
        return $self->{$field};
    }

In case of an access violation (see the C<include> and C<exclude> parameters), the C<access> parameter is processed.

=item create_get_set( I<$options> )

Creates a couple of methods for getting and setting field values:
    
    sub get_author
    {
        # [...]
    }
    sub set_author
    {
        # [...]
    }

=back

=head1 DEPENDENCIES 

=over

=item L<Array::Utils>

=item L<Carp>

=item L<Const::Fast>

=item L<Data::Lock>
 
=item L<List::MoreUtils>

=item L<Scalar::Util>

=back

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

Requires no configuration files or environment variables.

=head1 INCOMPATIBILITIES

None reported.

=head1 BUGS AND LIMITATIONS

No bugs have been reported.

=head1 SEE ALSO

=over

=item L<accessors>

=item L<accessors::classic>

=item L<Class::Accessor>

=item L<Class::Accessor::Grouped>

=over

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2022 Vsevolod Lutovinov.

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. The full text of this license can be found in 
the LICENSE file included with this module.

=head1 AUTHOR

Contact the author at kloppspb@bk.ru

