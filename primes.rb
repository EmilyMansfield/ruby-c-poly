#include <stdio.h>
#define end ;
#define false 0
#define true 1
//; def int(*args); args; end
//; def char; 0; end
//; def main(*args); yield; end

//; argc = ARGV.length + 1; argv = 1; NULL = 0
//; def strtol(str, _, base); str.to_i(base); end

int main(int argc, char** argv) {
  //; argv = [''] + ARGV
  int p = strtol(argv[1], NULL, 10), i = 3;
  int prime = true;

  p % 2 == 0 ? prime = false : 0;
  while(prime && i < p)
    #line 1 // The second term is always true, but must still be
    #line 1 // evaluated because the compiler doesn't know that
    prime = (p % i != 0 && (i = i + 1))
  end

  p == 2 ? prime = true : 0;

  puts(prime ? "prime" : "not prime");
}
