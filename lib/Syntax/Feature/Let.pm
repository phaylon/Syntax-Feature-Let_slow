use strictures 1;

# ABSTRACT: Provides a simple let keyword

package Syntax::Feature::Let;

use B::Hooks::EndOfScope    0.09;
use Carp                                qw( croak );
use Scope::Upper            0.13        qw( :words unwind want_at );
use Devel::Declare          0.006000;
use Params::Classify        0.013       qw( is_ref is_string );
use Sub::Bypass             0.001;
use B::Hooks::Parser;

use aliased 'Devel::Declare::Context::Simple', 'Context';

use namespace::clean;

$Carp::Internal{ +__PACKAGE__ }++;


=method install

    $class->install( %arguments )

Used by L<syntax> to install this extension into the requesting namespace.

=cut

sub install {
    my ($class, %args) = @_;
    my $target  = $args{into};
    my $options = $class->_prepare_options($args{options});
    my $name    = $options->{ -as };
    Devel::Declare->setup_for(
        $target => { $name => { const => sub {
            return $class->_transform(Context->new->init(@_), $options);
        }}},
    );
    install_bypassed_sub $target, $name;
}

sub _transform {
    my ($class, $ctx, $options) = @_;
    $ctx->skip_declarator;
    $class->_inject($ctx, '(');
    $ctx->skipspace;
    my @vars = $class->_collect_vars($ctx, $options);
    croak sprintf q{Expected %s block, not %s},
            $ctx->declarator,
            $class->_get_reststr($ctx),
        unless $class->_get_reststr($ctx) =~ m{ \A \{ }x;
    croak sprintf q{Using %s without variables makes no sense},
            $ctx->declarator,
        unless @vars;
    $class->_inject($ctx, ' do ');
    $class->_inject($ctx, sprintf(
        'BEGIN { %s->%s };', $class, '_handle_block_end',
    ), 1);
    $class->_inject($ctx, sprintf(
        '(my %s = %s);', @$_,
    )) for @vars;
    $class->_inject($ctx, '();');
    return 1;
}

sub _handle_block_end {
    my ($class) = @_;
    on_scope_end {
        my $linestr = Devel::Declare::get_linestr;
        my $offset  = Devel::Declare::get_linestr_offset;
        substr($linestr, $offset, 0) = ')';
        Devel::Declare::set_linestr($linestr);
    };
}

sub _collect_vars {
    my ($class, $ctx, $options) = @_;
    my @collected;
    while ($class->_get_reststr($ctx) =~ m{ \A \( }x) {
        my $declaration = $ctx->strip_proto;
        push @collected, $class->_deparse_var_declaration($ctx, $declaration);
        $ctx->skipspace;
    }
    return @collected;
}

sub _inject {
    my ($class, $ctx, $code, $skip) = @_;
    $skip ||= 0;
    my $linestr = $ctx->get_linestr;
    substr($linestr, $ctx->offset + $skip, 0) = $code;
    $ctx->inc_offset($skip + length $code);
    $ctx->set_linestr($linestr);
    return 1;
}

my $rxVariable = qr{
    (?: \@ | \% | \$ )
    [a-z_]
    [a-z0-9_]*
}xi;

my $rxVariableList = qr{
    \(
    \s*
    $rxVariable
    (?:
        \s*
        ,
        \s*
        $rxVariable
    )*
    \s*
    \)
}xism;

my $rxDeclaration = qr{
    \A
    \s*
    ( $rxVariable | $rxVariableList )
    \s*
    (?:
        =
        \s*
        ( \S.* )
        \s*
    )?
    \Z
}xism;

sub _deparse_var_declaration {
    my ($class, $ctx, $declaration) = @_;
    if ($declaration =~ $rxDeclaration) {
        my ($var, $expr) = ($1, $2);
        return [$1, defined($2) ? $2 : 'undef'];
    }
    my $keyword = $ctx->declarator;
    croak qq{Invalid $keyword variable declaration '$declaration'};
}

sub _get_reststr {
    my ($class, $ctx) = @_;
    return substr $ctx->get_linestr, $ctx->offset;
}

sub _prepare_options {
    my ($class, $options) = @_;
    $options = {}
        unless defined $options;
    croak qq{Options for $class must be hash ref}
        unless is_ref $options, 'HASH';
    $options->{ -as } = 'let'
        unless defined $options->{ -as };
    croak qq{Option -as for $class must be string}
        unless is_string $options->{ -as };
    return $options;
}

1;

=option -as

    use syntax let => { -as => 'having' };

    my $y = having ($x = 3) { $x * $x };

Allows you to rename the imported keyword.

=head1 SYNOPSIS

    use syntax qw( let );

    # single value
    my $val = let ( $x = foo() )
                  ( $y = bar() ) {
        $x + $y;
    };

    # multiple values
    my @vals = let ( @x = (3 .. 7) )
                   ( $y = 5 ) {
        map $_ + $y, @x;
    };

    # initialise multiple values
    my $result = let
            ( ($x, $y) = (3, 5) )
            ( $z = 23 ) {
        $x + $y * $z;
    };

=head1 DESCRIPTION

This extension provides a C<let> keyword that behaves mostly like a C<do>
block that can declare lexical variables.

=head1 SYNTAX

The general syntax is one of the following:

    let ( <variable> = <expression> ) ... { <code> }
    let ( (<variable>, ...) = <expression> ) ... { <code> }

The keyword is parsed as an expression. It is therefore possible to embed
the C<let> block inside another expression:

    $self->some_method(
        let ($uri = $self->some_uri) {
            $uri->host,
            $uri->path,
        },
        $some_arg,
    );

The C<code> inside the block will always be called in list context. This is
to make the implementation simple and fast, while keeping the behaviour of
a block instead of a subroutine.

The block is a real block, not a subroutine. You can therefor return out
of the enclosing subroutine just like you can with a C<while> loop:

    method something ($id) {

        my $foo = let ($bar = $self->get($id)) {

            # leaves the method 'something'
            return undef
                unless $bar->is_active;

            # value returned to $foo
            $bar->baz;
        };

        return $foo->qux;
    }

The keyword expects one or more parenthesis enclosed variable declarations
per block. These declarations are of the form

    <variable> = <expression>

or

    ( <variable1>, <variable2>, ... ) = <expression>

which allows for all of the following use cases:

    let ( $x = foo() )       { ... };
    let ( @x = foo() )       { ... };
    let ( %x = foo() )       { ... };
    let ( ($x, $y) = foo() ) { ... };
    let ( ($x, @y) = foo() ) { ... };

and so on. Each declaration can access the previous declarations:

    my $foo = let
            ($x = 23)
            ($y = $x * 2) {

        "result: $y";
    };

Remember that this is all parsed as an expression and will not automatically
terminate after the end of the block.

=head1 CAVEATS

=over

=item * The block is always executed in list context.

=back

=head1 SEE ALSO

=over

=item * L<syntax>

=item * L<Devel::Declare>

=back

=cut
