#include <stdio.h>

int pos=0;

void output(int a) {
	if(!pos) printf("\t!hex");
	else if(pos%22==0) printf("\n\t!hex");
	printf(" %02x",a);
	if(a<0 || a>255) printf("A %d\n",a);
	pos++;
}

int main() {
	int a;
	while(scanf("%d",&a)==1) output(a);
}
