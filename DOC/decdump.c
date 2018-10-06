/* ad-hoc program used for dumping a binary file to comma-separated decimal
   bytes */

#include <stdio.h>

unsigned char fil[1000000];

int main(int argc,char **argv) {
	if(argc<2) {
		printf("usage: decdump file\n");
		return 0;
	}
	FILE *f=fopen(argv[1],"rb");
	if(!f) {
		printf("error opening file.\n");
		return 0;
	}
	int len=fread(fil,1,1000000,f);
	fclose(f);
	for(int i=0;i<len;i++) {
		printf("%d,",fil[i]);
		if(i%16==15) printf("\n");
	}
	return 0;
}