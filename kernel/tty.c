#include "type.h"
#include "const.h"
#include "proto.h"
#include "protect.h"
#include "proc.h"
#include "global.h"

PUBLIC void task_tty(){
	while(1){
		keyboard_read();
	}
}