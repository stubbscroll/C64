/* convert input file of day 3 from text to binary, using no more bytes per
   field than necessary */

#include <stdio.h>

int main() {
	int dummy,x,y,w,h;
	while(scanf("#%d @ %d,%d: %dx%d\n",&dummy,&x,&y,&w,&h)==5) {
		printf("\t!hex %02x %02x %02x %02x %02x %02x\n",x&255,x/256,y&255,y/256,w,h);
	}
	return 0;
}
