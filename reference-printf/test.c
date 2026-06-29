/* Test harness for the reference implementation in myprintf.s
 * Build & run:  gcc -no-pie test.c myprintf.s -o t && ./t
 * Expected output:
 *   Hello world, you are 42 years old.
 *   neg=-12345  zero=0  intmin=-2147483648  100%
 *   char=X  unknown=%q  ok
 */
extern int my_printf(const char *fmt, ...);

int main(void) {
    my_printf("Hello %s, you are %d years old.%c", "world", 42, '\n');
    my_printf("neg=%d  zero=%d  intmin=%d  100%%\n", -12345, 0, -2147483648);
    my_printf("char=%c  unknown=%q  ok\n", 'X');
    return 0;
}
