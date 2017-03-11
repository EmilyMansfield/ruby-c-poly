C and Ruby share some syntactic similarities that make writing code that
runs in both languages not too difficult. This is a summary of the
techniques I've found so far to implement common language constructs
simultaneously in both languages.

By abusing the fact that the C comment character constructs an empty
regular expression in Ruby, any code after `//;` will be run by Ruby
only. I originally had it matching an empty string with `//=~""`, but
since a literal is a valid expression it's not necessary to do that.

Of course you can also the multiline comment, `/**/`, which leads to one
of many ways of writing actual comments

~~~
/* Everything until the next forward slash is in a regexp, so will
essentially be a no-op in Ruby and a comment in C. You still need to
obey the Regexp synax though, which is a little restrictive. */

"Using string literals constructs a literal in both languages, which
then does nothing. This is far more robust than the Regexp construction"

#line 1 // The first hash triggers a Ruby comment, which we then use as
#line 1 // a directive to essentially no-op, before starting a C comment
~~~

A downside with using literals to store comments is that Ruby may
actually construct the objects storing the comments, causing slowdown. I
haven't actually tested this, however.

Sadly it does not seem to be possible to create code that only runs in
C, and not in Ruby, because no code can be added on the same line as a
preprocessor directive. It is possible to define a macro however, which
can be used to map Ruby keywords to C functionality

~~~
#define end ; // This will give us while loops
#include <stdio.h> // This is obviously very convenient too
~~~

To define `main`, we'll need a way for Ruby to accept `{}` after
function names. But that's the syntax for a block, so we define a
function that simply yields to whatever it was given, executing that

~~~
//; def main; yield; end
main() {
    "Code goes here"
}
~~~

C is actually very lax when it comes to `main`, to the point where
no return type, no return, and no arguments are needed. This is crucial,
because in Ruby you can't `return` in a block. We can actually add the
return type and arguments though, by defining an `int` function

~~~
//; def int(*args); args; end
~~~

Since Ruby doesn't require parentheses to call a method, we can now add
the return type

~~~
int main() {
}
~~~

which will call the `int` function with the whole `main() {}` shebang
passed as an argument. But since arguments are evaluated, `main` is run.
The same mechanism gives us variable declarations for free

~~~
int foo = 10;
"Ruby sees this as int(foo = 10);"
~~~

Because Ruby doesn't support named arguments (neither does C,
incidentally), this will not set the value of the argument named `foo`
but will instead set the value of the variable named `foo`. And since
setting a variable that hasn't been created will create it, this gives
us a way of defining variables in both languages. Furthermore, the
variable is defined in the scope *surrounding* the `int` call!

Why the use of `*args` instead of a single argument? With that we get
multiple initialization

~~~
int a = 5, b = 10, c = 3;
~~~

By repeating this construction with different types we can use variables
pretty much how we normally would in C, but in both languages
simultaneously.

By using the same `*args` construction, we can give arguments to `main`

~~~
//; def main(*args); yield; end
int main(int argc, char* argv[]) {
}
~~~

Now though, because there's no equals signs `argc` and `argv` have to be
set beforehand (in Ruby only) so that Ruby knows they're variables.

Magically Ruby copes with the variable number of functions given
variable numbers of parentheses, but this isn't legal just yet because
of the funky `char* argv[]`. To fix that, we use the equivalent C code
`char** argv` then abuse the fact that `**` is the exponentiation
operator in Ruby to define

~~~
//; def char; 0; end
// argc = ARGV.length + 1; argv = 1
int main(int argc, char** argv) {
}
~~~

So now `argc` is correctly set to the number of arguments in both
languages (in C the program name is passed as the first argument, but it
isn't in Ruby), then `argv` is temporarily set to 1.

First `char` is called, which takes no arguments, evaluates to 0,
then is exponentiated with `argv` to evaluate to 0. I'm unsure
exactly where the 0 is passed (either to `main` or to `int`) but either
way this code runs without error.

To fix the contents of `argv`, we use Ruby's `ARGV` variable, then we're
free to parse the arguments as normal!

~~~
//; argv = [''] + ARGV # Compensate for the lack of program name
~~~

In this way we can receive command line arguments, but without return
values we'll need `stdout` to do anything useful. Luckily this is easy,
as Ruby has the same (or at least very similar, I haven't checked fully)
`printf` function as `C`.

~~~
printf("%d from %s and %s\n", a, "Ruby", "C");
~~~

What about any kind of logic? Well `if` statements are pretty easy,
because Ruby let's you but parentheses if you want

~~~
#define end ;
if(foo < 10)
    printf("Yes!\n");
end
~~~

In C the `;` will result in a no-op, but it's necessary because Ruby
requires the `end`. Omitting the `{}` in C though means that the body
can only contain a single statement, so the following code gives
different results in C and Ruby, even though it is valid in both.

~~~
#define end ;
if(foo < 10)
    printf("This runs in both\n");
    printf("This will always run in C, but only if foo < 10 in Ruby\n");
end
~~~

The exact same idea applies to `while` loops, which I didn't even
realise Ruby had until writing this

~~~
int foo = 0;
while(foo < 10)
    printf("%d\n", foo -= 1);
end
~~~

A 'clearer' alternative to the actual `if` statement is to use a
`ternary` operator, which exists in both languages. Though this is
arguably much harder to read!

~~~
foo < 10 ?
    printf("%d\n", foo -= 1) : 0;
~~~

Either way, it's not possible to declare variables with a single
expression, so they must be declared beforehand. On the other hand, it
*is* possible to evaluate more than one statement. For example, the
following will store the value of `p % i != 0` but will also always
increment `i`, because the compile doesn't know in advance if it will be
`true` or not

~~~
prime = (p % i != 0) && (i = i + 1)
~~~

This chaining technique is particularly unwieldy when dealing with
general expressions, because it requires the subexpressions to cast to
`true`, which may not always be the case. This problem goes away if we
can create functions, where then the loop body can simply call the
function.
