# Аксессоры

Создание аксессоров как на уровне пакетов, так и для отдельных объектов.

# Кратко

``` perl
    package MyClass;
    use base q/Accessors::Weak/;
    sub new
    {
        my ($class) = @_;
        my $self = bless {
            array  => [1],
            hash   => { 2 => 3 },
            scalar => 'scalar value',
        }, $class;

        return $self->create_accessors;
        # или
        # return $self->create_property;
        # или
        # return $self->create_get_set;
    }
```
Теперь все объекты *MyClass* будут содержать аксессоры.

```perl
    use Accessors::Strict qw/create_accessors create_property create_get_set/;
    my $object = MyClass->new;
    $object->create_accessors( $object );
    # или
    # $object = create_property( $object );
    # или
    # $object = create_get_set( $object );
```
Теперь *$object* будет содержать аксессоры.

## Accessors::Weak

Созданные аксессоры не исключают прямого доступа к полям объекта.

## Accessors::Strict

Созданные аксессоры запрещают прямой доступ к полям объекта. При этом сам объект меняет `@ISA`:

```perl
    my $object = MyClass->new;
    say ref $object;     # => "MyClass"
    $object = create_accessors( $object );
    say ref $object;     # => "MyClass::DEAFBEEF"
    say MyClass->data;   # => OK, выведет значение MyClass->{data}
    say MyClass->{data}; # => ОШИБКА, выведет "Not a HASH reference at ..."
```

# Параметры

Все методы принимают необязательный аргумент: ссылку на хэш с дополнительными параметрами. Например:

```perl
    create_property( $object, { exclude => [ 'index' ], access => 'carp', property => 'prop' } );
```

## include => [ name1, name2, ... ]

Список имён полей для которых создавать аксессоры. По умолчанию асксессоры создаются для всех полей.
    
## exclude => [ name1, name2, ... ]

Список имён полей для которых не нужно создавать аксессоры. Этот параметр обрабатывается после `include`.

## property => name

Имя метода, который будет создан при вызове *create_property()*. По умолчанию `"property"`.

## validate => { field => coderef, ... }

Список валидаторов для устанавливаемых значений. Функции должны возвращать `undef` если валидация не прошла. В этом случае значения поля не устанавливается и аксессор возвращает `undef`. Например:

```perl
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
```

## access => class

Способ обработки нарушения доступа (см. списки `include` и `exclude`). Может принимать значения `"carp"`, `"cluck"`, `"croak"` или `"confess"` (методы модуля [Carp](https://metacpan.org/pod/Carp)). При задании любого другого значения обработка будет пропущена (поведение по умолчанию).

## method => class

Если при создании аксессора метод с таким же именем будет обнаружен в пакете или объекте, будет вызван этот обработчик. Значения аналогичны параметру `access`.

### Импорт

Все параметры могут указываться глобально, при импорте. Например:

```perl
    use Accessors::Weak { access => 'carp', property => 'prop' };
    # [...]
    use Accessors::Strict qw/create_accessors/, { access => 'carp', property => 'prop' };
```

# Методы

## create_accessors( [$object,] \[$options] )

Создаёт методы для доступа и установки значений полей с тем же именем. Например, для поля `author` будет создан такой метод:

```perl
    sub author
    {
        my $self = shift;
        $self->{author} = shift if @_;
        return $self->{author};
    }
```

## create_property( [$object,] \[$options] )

Создаёт метод с именем `$options->{property}` (по умолчанию `"property"`) для доступа к полям:

```perl
    sub property
    {
        my ( $self, $field ) = (shift, shift);
        $self->{$field} = shift if @_;
        return $self->{$field};
    }
```
При нарушении доступа (см. параметры `include` и `exclude`) обрабатывается параметр `access`.

## create_get_set( [$object,] \[$options] )

Создаёт пару методов для получения и установки значений полей:

```perl
    sub get_author
    {
        # [...]
    }
    sub set_author
    {
        # [...]
    }
```

# Примеры
