#include <stdio.h>
 
int main()
{
    #if defined(__WIN32__)
	printf("hello")
	#endif
 
    return 0;
}
