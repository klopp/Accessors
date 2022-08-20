package Accessors::Weak;

use strict;
use warnings;
use Carp qw/cluck confess carp croak/;
use Const::Fast;

const my $ACCESS_DENIED => 'Access denied to field "%s"';
const my $METHOD_EXISTS => 'Method "%s" already exists';
const my $PROP_METHOD   => 'property';

use vars qw/%OPT @FIELDS $VERSION/;
$VERSION = '2.001';

use Array::Utils qw/intersect array_minus/;
use List::MoreUtils qw/any/;
use Scalar::Util qw/blessed/;

use base qw/Exporter/;
our @EXPORT_OK = qw/create_accessors create_property create_get_set/;

#------------------------------------------------------------------------------
sub import
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
        %OPT = %{$opt};
    }
    @FIELDS = keys %{$self};
    @FIELDS = intersect( @FIELDS, @{ $OPT{include} } ) if $OPT{include};
    @FIELDS = array_minus( @FIELDS, @{ $OPT{exclude} } ) if $OPT{exclude};
    return \@FIELDS;
}

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
sub create_accessors
{
    my ( $self, $opt ) = @_;
    my $package = ref $self;
    my $fields  = _set_internal_data( $self, $opt );

    for my $key ( @{$fields} ) {
        if ( !$self->can($key) ) {
            no strict 'refs';
            *{"$package\::$key"} = sub {
                my $self = shift;
                if (@_) {
                    my $value = shift;
                    if ( $OPT{validate}->{$key} ) {
                        return unless $OPT{validate}->{$key}->($value);
                    }
                    $self->{$key} = $value;
                }
                return $self->{$key};
            }
        }
        else {
            _emethod("$package\::$key");
        }
    }
    return $self;
}

#------------------------------------------------------------------------------
sub create_property
{
    my ( $self, $opt ) = @_;
    my $package  = ref $self;
    my $fields   = _set_internal_data( $self, $opt );
    my $property = $OPT{property} || $PROP_METHOD;

    if ( !$self->can($property) ) {
        no strict 'refs';
        *{"$package\::$property"} = sub {
            my ( $self, $field ) = ( shift, shift );
            if ( any { $field eq $_ } @FIELDS ) {
                my $value = shift;
                if ( $OPT{validate}->{$field} ) {
                    return unless $OPT{validate}->{$field}->($value);
                }
                return $self->{$field};
            }
            else {
                return _eaccess($field);
            }
        }
    }
    else {
        _emethod($property);
    }
    return $self;
}

#------------------------------------------------------------------------------
sub create_get_set
{
    my ( $self, $opt ) = @_;
    my $package = ref $self;
    my $fields  = _set_internal_data( $self, $opt );

    for my $key ( @{$fields} ) {
        if ( !$self->can( 'get_' . $key ) ) {
            no strict 'refs';
            *{"$package\::get_$key"} = sub {
                my ($self) = @_;
                return $self->{$key};
            }
        }
        else {
            _emethod("$package\::get_$key");
        }
        if ( !$self->can( 'set_' . $key ) ) {
            no strict 'refs';
            *{"$package\::set_$key"} = sub {
                my ( $self, $value ) = @_;
                if ( $OPT{validate}->{$key} ) {
                    return unless $OPT{validate}->{$key}->($value);
                }
                $self->{$key} = $value;
                return $self->{$key};
            }
        }
        else {
            _emethod("$package\::set_$key");
        }
    }
    return $self;
}

#------------------------------------------------------------------------------
1;

__END__

=head1 NAME

Accessors::Universal

=head1 SYNOPSIS

=over

=item Accessors for whole package

    package AClass;
    use base q/Accessors::Universal/;
    sub new
    {
        my ($class) = @_;
        my $self = bless {
            array  => [1],
            hash   => { 2 => 3 },
            scalar => 'scalar value',
        }, $class;

        return $self->create_accessors;
        # or
        # return $self->create_property;
        # or
        # return $self->create_get_set;
    }

=item Accessors for single object

    use Accessors::Universal qw/create_accessors create_property create_get_set/;
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


=item access => class

How to handle an access violation (see the C<include> and C<exclude> lists). Can be C<"carp">, C<"cluck">, C<"croak"> or C<"confess"> (L<Carp> module methods). Any other value will skip processing (default behavior).

=item method => class

When an accessor is created, if a method with the same name is found in a package or object, this handler will be called. Values are similar to the C<access> parameter.

=back

=head2 Setting custom properties on module load.

    use Accessors::Universal qw/create_accessors/, { access => croak };

=head2 Setting custom properties on the methods call.

    $object->create_accessors( { exclude => [ 'index' ] } );

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

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2022 Vsevolod Lutovinov.

This program is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. The full text of this license can be found in 
the LICENSE file included with this module.

=head1 AUTHOR

Contact the author at kloppspb@bk.ru

