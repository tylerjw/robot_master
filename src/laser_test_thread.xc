/*
 * laser_test_thread.xc
 *
 *  Created on: Mar 31, 2014
 *      Author: tylerjw
 */
#include <platform.h>
#include <xs1.h>

extern out port LASER;
extern in port BUTTON1;
extern in port BUTTON2;

extern void delay(int);

void laser_test_thread(void) {
    int state = 0;

    while(1) {
        select {
            case BUTTON1 when pinseq(0) :> void:
                delay(30e5); // debounce
                if(state == 0) {
                    state = 1;
                    LASER <: 1;
                } else {
                    state = 0;
                    LASER <: 0;
                }
                BUTTON1 when pinseq(1) :> void;
                delay(30e5); // debounce
                break;
        }
    }
}
