
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

#define Addr(a)  (unsigned long long)(a)
int main(int argc, char ** argv)
{
    printf("Hello\n");

    struct stat s;
    unsigned long long addr = Addr(&s);
    printf("st_dev %d  off: %d\n", sizeof(s.st_dev), Addr(&s.st_dev)-addr);
    printf("st_ino %d  off: %d\n", sizeof(s.st_ino), Addr(&s.st_ino)-addr);
    printf("st_nlink %d  off: %d\n", sizeof(s.st_nlink), Addr(&s.st_nlink)-addr);
    printf("st_mode %d  off: %d\n", sizeof(s.st_mode), Addr(&s.st_mode)-addr);
    printf("st_uid %d  off: %d\n", sizeof(s.st_uid), Addr(&s.st_uid)-addr);
    printf("st_gid %d  off: %d\n", sizeof(s.st_gid), Addr(&s.st_gid)-addr);
    printf("st_rdev %d  off: %d\n", sizeof(s.st_rdev), Addr(&s.st_rdev)-addr);
    printf("st_size %d  off: %d\n", sizeof(s.st_size), Addr(&s.st_size)-addr);

    printf("__S_IFDIR %0x\n", __S_IFDIR);
    printf("__S_IFREG %0x\n", __S_IFREG);
    printf("sizeof(stat): %d\n", sizeof(struct stat));

    return 0;
}