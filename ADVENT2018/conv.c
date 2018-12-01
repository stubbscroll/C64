/* convert input file to data lines for the acme assembler */
/* usage: read from stdin, write to stdout */

#include <stdio.h>
#include <string.h>

#define MAX 1000000
#define W 22

char a[MAX];

int out=0;

void output(unsigned char c) {
	if(out && out%W==0) puts("");
	if(out%W==0) printf("\t!hex");
	printf(" %02x",c);
	out++;
}

int main() {
	while(fgets(a,MAX,stdin)) {
		int l=strlen(a)-1;
		while(l>=0 && (a[l]==13 || a[l]==10)) a[l--]=0;
		for(int i=0;a[i];i++) output(a[i]);
		output(13);
	}
	puts("");
	return 0;
}
