/*
 * arduino_thread.xc
 *
 *  Created on: Apr 1, 2014
 *      Author: tylerjw
 */
#include <uart.h>
#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <string.h>

extern in port ARDUINO_RX;
extern out port DEBUGTX;

int extern time_after(timer t, int start, int max);

void arduino_thread(interface arduino_int client ard_rx, out port beacon) {
    int state = 0; // 0 - recieving 9-dof data, 1 - taking beacon reading
    int yaw, pitch, roll;
    int beacon_angle;
    const int start_bit = 0;
    const int end_bit = 1;
    int ahrs_read = 0;
    timer t;
    int start;
    int timeout = 1e8;

    char buffer[80];

    while(1) {
        while(ard_rx.avalible() < 2);
        int c = ard_rx.geti();
        sprintf(buffer, "%d\r\n", c);
//        for(int i = 0; i < strlen(buffer); i++) {
//            tx(DEBUGTX, buffer[i]);
//        }
    }

    while(1) {
        t :> start;
        // switch back and forth, for debug...
        //if(state == 0) state = 1;
        //else state = 0;

        switch(state) {
        case 0: // reading from 9-dof
            ahrs_read = 0;
            while(ard_rx.geti() != start_bit) {
                delay(1e6);
                if(time_after(t,start,timeout)) {
                    printf("timeout\n");
                    break;
                }
            }
            while(ard_rx.avalible() < 6); // size of full reading
            yaw = ard_rx.geti();
            pitch = ard_rx.geti();
            roll = ard_rx.geti();
            ahrs_read = 1;
            break;
        case 1: //taking a beacon reading
            beacon <: 1; // start the reading
            ard_rx.clear(); // clear the buffer
            while(ard_rx.avalible() < 2) delay(1e6);
            beacon <: 0; // stop the beacon
            beacon_angle = ard_rx.geti();
            break;
        }

        // do something with the data we just got... maybe set state based on something
        if(ahrs_read) {
            printf("y:%d, p:%d, r:%d\n", yaw, pitch, roll);
        } else if(state == 1) {
            printf("beacon angle: %d\n", beacon_angle);
        }
    }
}
