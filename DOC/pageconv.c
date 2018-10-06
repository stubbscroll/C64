/* convert .c files from the petscii editor at
   http://www.kameli.net/marq/?page_id=2717
	 into asm code containing the docs, to be pasted into the actual source
	 (no prg yet)
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

int pages;

void init() {
	int i;
	printf("screenptrlo !byte ");
	for(i=0;i<pages;i++) {
		if(i) putchar(',');
		printf("<screen%d",i+1);
	}
	putchar('\n');
	printf("screenptrhi !byte ");
	for(i=0;i<pages;i++) {
		if(i) putchar(',');
		printf(">screen%d",i+1);
	}
	putchar('\n');
	printf("colourptrlo !byte ");
	for(i=0;i<pages;i++) {
		if(i) putchar(',');
		printf("<col%d",i+1);
	}
	putchar('\n');
	printf("colourptrhi !byte ");
	for(i=0;i<pages;i++) {
		if(i) putchar(',');
		printf(">col%d",i+1);
	}
	putchar('\n');
}

void parsenum(char *s,int *a,int n) {
	int i,v;
	for(i=0;i<n;i++) {
		v=0;
		if(!isdigit(*s)) {
			printf("parse error, expected digit.\n");
			exit(1);
		}
		while(isdigit(*s)) v=v*10+*(s++)-48;
		if(*s==',') s++;
		a[i]=v;
	}
}

/* set space to previous colour, and toss higher nybble to be sure */
void preprocess(int *screen,int *col,int len) {
	int prev=0;
	for(int i=0;i<len;i++) {
		if(screen[i]==32) col[i]=prev;
		else prev=col[i];
		col[i]=col[i]&15;
	}
}

int encode(int *in,int len,int *out) {
	int q=0;
	int p=0;
	int i;
	while(p<len) {
		/* find un-equal stream */
		for(i=0;i<128 && i+p<len;i++) {
			if(i+p+3<len && in[i+p]==in[i+p+1] && in[i+p]==in[i+p+2]) break;
		}
		if(i) {
			/* stream of non-equal bytes */
			out[q++]=256-i;
			while(i--) out[q++]=in[p++];
		}
		/* do we still have equal stream? */
		if(p+3<len && in[p]==in[p+1] && in[p]==in[p+2]) {
			for(i=0;i<128 && i+p<len;i++) if(in[p]!=in[p+i]) break;
			out[q++]=i-1;
			out[q++]=in[p];
			p+=i;
		}
	}
	out[q++]=0;
	return q;
}

void conv(int n,char *file) {
	char s[10000];
	int temp[40];
	int col[2];
	int screen[1000];
	int colour[1000];
	int output[1500];
	int len;
	FILE *f=fopen(file,"r");
	if(!f) {
		printf("error opening file %s.\n",file);
		exit(1);
	}
	fgets(s,10000,f);
	if(strncmp("unsigned char",s,13)) {
		printf("not correct file format in %s.\n",file);
		exit(1);
	}
	/* get border and background colours */
	fgets(s,10000,f);
	parsenum(s,col,2);
	/* get screen, one row at a time */
	for(int i=0;i<25;i++) {
		fgets(s,10000,f);
		parsenum(s,temp,40);
		for(int j=0;j<40;j++) screen[i*40+j]=temp[j];
	}
	/* get colour memory, one row at a time */
	for(int i=0;i<25;i++) {
		fgets(s,10000,f);
		parsenum(s,temp,40);
		for(int j=0;j<40;j++) colour[i*40+j]=temp[j];
	}
	fclose(f);
	preprocess(screen,colour,1000);
	/* rle encode */
	len=encode(screen,1000,output);
	printf("screen%d !hex",n);
	for(int i=0;i<len;i++) printf(" %02x",output[i]);
	putchar('\n');
	len=encode(colour,1000,output);
	printf("col%d\t!hex",n);
	for(int i=0;i<len;i++) printf(" %02x",output[i]);
	putchar('\n');
}

void usage() {
	puts("this program takes screen files (in .c format) from the petscii editor at");
	puts("kameli.net and creates an executable that views the files.\n");
	puts("usage:");
	puts("conv file1 file2 ...\n");
	puts("where file1, file2 etc are the input screens (in .c format). a hexdump in");
	puts("acme format is written to stdout. each file must have one screen!");
	exit(0);
}

int main(int argc, char **argv) {
	puts("petscii-pageconv 1.0 by scroll/megastyle in 2018\n");
	if(argc==1) usage();
	pages=argc-1;
	init();
	for(int i=1;i<argc;i++) conv(i,argv[i]);
	return 0;
}
