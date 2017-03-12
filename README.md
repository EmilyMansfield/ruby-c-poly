C and Ruby share some syntactic similarities that make writing code that
runs in both languages not too difficult. This is a summary of the
techniques I've found so far to implement common language constructs
simultaneously in both languages.

# Comments and Ruby-only Execution

By abusing the fact that the C++ comment character constructs an empty
regular expression in Ruby, any code after `//;` will be run by Ruby
only. I originally had it matching an empty string with `//=~""`, but
since a literal is a valid expression it's not necessary to do that.

Of course you can also the multiline comment, `/**/`, which leads to one
of many ways of writing actual comments

```c
/* Everything until the next forward slash is in a regexp, so will
essentially be a no-op in Ruby and a comment in C. You still need to
obey the Regexp synax though, which is a little restrictive. */

"Using string literals constructs a literal in both languages, which
then does nothing. This is far more robust than the Regexp construction"

#line 1 // The first hash triggers a Ruby comment, which we then use as
#line 1 // a directive to essentially no-op, before starting a C comment
```

A downside with using literals to store comments is that Ruby may
actually construct the objects storing the comments, causing slowdown. I
haven't actually tested this, however.

Sadly it does not seem to be possible to create code that only runs in
C, and not in Ruby, because no code can be added on the same line as a
preprocessor directive. It is possible to define a macro however, which
can be used to map Ruby keywords to C functionality

```c
#define end ; // This will give us while loops
#include <stdio.h> // This is obviously very convenient too
```

# `main()`
To define `main`, we'll need a way for Ruby to accept `{}` after
function names. But that's the syntax for a block, so we define a
function that simply yields to whatever it was given, executing that

```c
//; def main; yield; end
main() {
    "Code goes here"
}
```

C is actually very lax when it comes to `main`, to the point where
no return type, no return, and no arguments are needed. This is crucial,
because in Ruby you can't `return` in a block. We can actually add the
return type and arguments though, by defining an `int` function

```c
//; def int(*args); args; end
```

Since Ruby doesn't require parentheses to call a method, we can now add
the return type

```c
int main() {
}
```

which will call the `int` function with the whole `main() {}` shebang
passed as an argument. But since arguments are evaluated, `main` is run.

# Variables
The same mechanism gives us variable declarations for free

```c
int foo = 10;
"Ruby sees this as int(foo = 10);"
```

Because Ruby doesn't support named arguments (neither does C,
incidentally), this will not set the value of the argument named `foo`
but will instead set the value of the variable named `foo`. And since
setting a variable that hasn't been created will create it, this gives
us a way of defining variables in both languages. Furthermore, the
variable is defined in the scope *surrounding* the `int` call!

Why the use of `*args` instead of a single argument? With that we get
multiple initialization

```c
int a = 5, b = 10, c = 3;
```

By repeating this construction with different types we can use variables
pretty much how we normally would in C, but in both languages
simultaneously.

# Arguments
By using the same `*args` construction, we can give arguments to `main`

```c
//; def main(*args); yield; end
int main(int argc, char* argv[]) {
}
```

Now though, because there's no equals signs `argc` and `argv` have to be
set beforehand (in Ruby only) so that Ruby knows they're variables.

Magically Ruby copes with the variable number of functions given
variable numbers of parentheses, but this isn't legal just yet because
of the funky `char* argv[]`. To fix that, we use the equivalent C code
`char** argv` then abuse the fact that `**` is the exponentiation
operator in Ruby to define

```c
//; def char; 0; end
//; argc = ARGV.length + 1; argv = 1
int main(int argc, char** argv) {
}
```

So now `argc` is correctly set to the number of arguments in both
languages (in C the program name is passed as the first argument, but it
isn't in Ruby), then `argv` is temporarily set to 1.

First `char` is called, which takes no arguments, evaluates to 0,
then is exponentiated with `argv` to evaluate to 0. I'm unsure
exactly where the 0 is passed (either to `main` or to `int`) but either
way this code runs without error.

To fix the contents of `argv`, we use Ruby's `ARGV` variable, then we're
free to parse the arguments as normal!

```rb
//; argv = [''] + ARGV # Compensate for the lack of program name
```

In this way we can receive command line arguments, but without return
values we'll need `stdout` to do anything useful. Luckily this is easy,
as Ruby has the same (or at least very similar, I haven't checked fully)
`printf` function as `C`.

```c
printf("%d from %s and %s\n", a, "Ruby", "C");
```

# If Statements and While Loops
What about any kind of logic? Well `if` statements are pretty easy,
because Ruby let's you but parentheses if you want

```c
#define end ;
if(foo < 10)
    printf("Yes!\n");
end
```

In C the `;` will result in a no-op, but it's necessary because Ruby
requires the `end`. Omitting the `{}` in C though means that the body
can only contain a single statement, so the following code gives
different results in C and Ruby, even though it is valid in both.

```c
#define end ;
if(foo < 10)
    printf("This runs in both\n");
    printf("This will always run in C, but only if foo < 10 in Ruby\n");
end
```

The exact same idea applies to `while` loops, which I didn't even
realise Ruby had until writing this

```c
int foo = 0;
while(foo < 10)
    printf("%d\n", foo -= 1);
end
```

A 'clearer' alternative to the actual `if` statement is to use a
`ternary` operator, which exists in both languages. Though this is
arguably much harder to read!

```c
foo < 10 ?
    printf("%d\n", foo -= 1) : 0;
```

Either way, it's not possible to declare variables with a single
expression, so they must be declared beforehand. On the other hand, it
*is* possible to evaluate more than one statement. For example, the
following will store the value of `p % i != 0` but will also always
increment `i`, because the compile doesn't know in advance if it will be
`true` or not

```c
prime = (p % i != 0) && (i = i + 1)
```

This chaining technique is particularly unwieldy when dealing with
general expressions, because it requires the subexpressions to cast to
`true`, which may not always be the case. This problem goes away if we
can create functions, where then the loop body can simply call the
function.

# Functions

We can't apply the same strategy for `main` to general functions,
because yielding to a block would call the function when it was defined
and do nothing when it was called. Instead, we need a method of
remembering the block originally passed to the function. The simplest
way is to use global variables

```rb
//; def void(_); end
//; $foo_block = ->(){}
//; def foo(&block); block_given? ? $foo_block = block : $foo_block.call; end;

void foo() {
    printf("Hello, world\n");
}

...

"Now 'hello, world' is printed"
foo();
```

Clearly this is pretty ugly, and requires a lot of Ruby-specific
boilerplate. A more elegant alternative is to let `foo` redefine itself
to the block

```rb
//; def void(_); end
//; def foo(&block); define_method(:foo, block) if block_given?; end

"`foo` is redefined to call the block"
void foo() { }

"Calls the block originally passed to foo"
foo()
```

Both of these strategies allow for declarations before definitions, too

```c
"In the first case $foo_block is called, but it's defined to a"
"no-op. In the second case, there's no block so nothing"
" happens."
void foo();

void foo() { }
```

Unfortunately, we have no hope of returning values because we can't
`return` in a block. We can still send values back to the caller by
using global variables though (conveniently starting a variable name
with `$` is legal C).

```c
int $ret = 0;
void foo() {
    $ret = 10;
}

```

This is annoying to use because every function call becomes two
statements. Using the ternary operator though we can combine the two
into one

```c
"The compiler will warn that the return is missing, but not"
"error. This is necessary because void cannot be cast to bool"
int foo() {
    $ret = 10;
}
"The condition is always true so always evaluates to $ret, but"
"unless the compiler overzealously optimizes, foo will still run"
((foo() || true) ? $ret : 0)
```
