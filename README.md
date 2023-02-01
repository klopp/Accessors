# Аксессоры

Создание аксессоров как на уровне пакетов, так и для отдельных объектов.

# Кратко

``` perl
    package MyClass;
    use base q/Accessors/;
    sub new
    {
        my ($class) = @_;
        my $self = bless {
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
    use Accessors qw/create_accessors create_property create_get_set/;
    my $object = MyClass->new;
    create_accessors( $object );
    # или
    # create_property( $object );
    # или
    # create_get_set( $object );
```
Теперь *$object* будет содержать аксессоры.

# Параметры

Все методы принимают необязательный аргумент: ссылку на хэш с дополнительными параметрами. Например:

```perl
    create_property( $object, { exclude => [ 'index' ], eaccess => 'carp', property => 'prop' } );
```

## include => [ name1, name2, ... ]

Список имён полей для которых создавать аксессоры. По умолчанию асксессоры создаются для всех полей.
    
## exclude => [ name1, name2, ... ]

Список имён полей для которых не нужно создавать аксессоры. Если приутствует `include`, то `exclude` обрабатывается после него.

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

## eaccess => VALUE

Обработка случаев обращения через метод `property()` к полям, для которых этот аксессор не создан.
Может принимать значения:
* `"carp"`, `"cluck"`, `"croak"` или `"confess"`. В этом случае будут вызываться соответствующие методы модуля [Carp](https://metacpan.org/pod/Carp) с диагностикой. 
* Ссылка на код обработчика, которому будут переданы два аргумента: ссылка на рабочий объект и имя поля:

```perl
    create_property(
        $object,
        {   eaccess => sub {
                my ( $self, $field ) = @_;
            }
        }
    );
```
* `undef` или любое другое значение - не делать ничего.

При отсутствии `eaccess` (по умолчанию) вызывается `Carp::confess` с соответствующей диагностикой.

## emethod => VALUE

Если при создании аксессора метод с таким же именем будет обнаружен в пакете или объекте, будет вызван этот обработчик. Значения аналогичны параметру `eaccess`.

## etype => VALUE

Проверять тип при установке значения поля.
Может принимать значения:
* `"carp"`, `"cluck"`, `"croak"` или `"confess"`. В этом случае будут вызываться соответствующие методы модуля [Carp](https://metacpan.org/pod/Carp) с диагностикой. 
* Ссылка на код обработчика, которому будут переданы три аргумента: ссылка на рабочий объект, имя поля и новый тип :

```perl
    $books->create_accessors( {
        etype => {
            author => sub {
                my ( $self, $field, $type ) = @_;
                confess sprintf(
                    'Can not change %s::%s type (%s) to "%s"',
                    ( caller(1) )[0],
                    $field, reftype $self->{$field}, $type
                );
            }
        },
    });
```
Эти проверки происходят до проверок из `validate`. По умолчанию проверка не производится.

## lock => VALUE

Управляет защитой полей от прямой модификации.

```perl
    $object->set_foo('bar'); # OK
    say $object->get_foo;    # OK
    say $object->{foo};      # OK
    $object->{foo} = 'bar' ; # ОШИБКА, "Modification of a read-only value attempted at..."
```

По умолчанию блокируются только те поля, для которых созданы аксессоры. Возможные значения:

* `"all"` блокировка всех полей, включая поля без аксессров.
* `ARRAY` блокировка только полей из массива, включая поля без аксессоров.

### Импорт

Все параметры могут указываться глобально, при импорте. Например:

```perl
    use Accessors qw/create_accessors/, { access => 'carp', property => 'prop' };
```

# Методы

## create_accessors( [$object,] \[$options] )

Создаёт методы для доступа и установки значений полей с тем же именем. Например:

```perl
    package MyBook;
    use Accessors, { lock => 'all' };
    use base q/Accessors/;
    sub new
    {
        my ($class) = @_;
        my $self = bless {
            author  => 'me',
        }, $class;
        return $self->create_accessors;
    }
    # [...]
    my $book = MyBook->new;
    say $book->author;        # "me"
    say $book->author('you'); # "you"
    $book->{author} = 'we';   # ОШИБКА
```

## create_property( [$object,] \[$options] )

Создаёт метод с именем `$options->{property}` (по умолчанию `"property"`) для доступа к полям:

```perl
    create_property($object);
    say $object->property('scavar_value');
    say $object->property( 'scavar_value', 'new_value' ));
```

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

# Зависимости

[Array::Utils](https://metacpan.org/pod/Array::Utils)

[Carp](Carp)

[Data::Lock](https://metacpan.org/pod/Data::Lock)

[Const::Fast](https://metacpan.org/pod/Const::Fast)
 
[List::MoreUtils](https://metacpan.org/pod/List::MoreUtils)

[Scalar::Util](https://metacpan.org/pod/Scalar::Util)

# См. также

[accessors](https://metacpan.org/pod/accessors)

[accessors::classic](https://metacpan.org/pod/accessors::classic)

[Class::Accessor](https://metacpan.org/pod/Class::Accessor)

[Class::Accessor::Grouped](https://metacpan.org/pod/Class::Accessor::Grouped)

