#include "type.h"
#include "const.h"
#include "proto.h"


PUBLIC char* atoi(char* str,int num){
	char *p = str;
	int i = 0;
	char ch;

	*p++ = '0';
	*p++ = 'x';

	for(i=28;i>=0;i-=4){
		ch = (num>>i) & 0xf;
		if(ch<0xa)
			ch += '0';
		else
			ch = ch-0xa+'a';

		*p++ = ch; 
	}
	*p = 0;
	return str;

}

PUBLIC void disp_int(int input){
	char output[16];
	atoi(output,input);
	disp_str(output);
}

PUBLIC void delay(int time){
	int i,j,k;
	for(k = 0; k < time; k++){
		for(i = 0; i <10; i++){
			for(j = 0; j < 10000; j++){}
		}
	}
}