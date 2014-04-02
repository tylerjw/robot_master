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
    int yaw, pitch, roll, temperature;
    int beacon_angle;
    const int start_bit = 0;
    const int end_bit = 1;
    const int beacon_start_bit = -100;
    int ahrs_read = 0;
    timer t;
    int start;
    int timeout = 1e8;

    char buffer[80];

    int counter = 0;

    beacon <: 0;

    while(1) {
        t :> start;
        // switch back and forth, for debug...
//        if(state == 0 && counter > 10) {
//            state = 1;
//            counter = 0;
//        } else {
//            state = 0;
//            counter++;
//        }
        state = 0;

        ahrs_read = 0;

        switch(state) {
        case 0: // reading from 9-dof
            ahrs_read = 0;
            while(ard_rx.geti() != start_bit) {
                delay(1e3);
                if(time_after(t,start,timeout)) {
                    tx_str(DEBUGTX,"timeout\n\r");
                    break;
                }
            }
            while(ard_rx.avalible() < 8); // size of full reading
            yaw = ard_rx.geti();
            pitch = ard_rx.geti();
            roll = ard_rx.geti();
            temperature = ard_rx.geti();
            sprintf(buffer,"y:%d, p:%d, r:%d, t: %d\r\n", yaw, pitch, roll, temperature);
            tx_str(DEBUGTX,buffer);
            ahrs_read = 1;
            ard_rx.clear();
            break;
        case 1: //taking a beacon reading
            beacon <: 1; // start the reading
            while(ard_rx.geti() != beacon_start_bit) {
                delay(1e3);
                if(time_after(t,start,timeout)) {
                    tx_str(DEBUGTX,"timeout\n\r");
                    break;
                }
            }
            while(ard_rx.avalible() < 2);
            beacon_angle = ard_rx.geti();
            beacon <: 0; // stop the beacon
            sprintf(buffer,"beacon angle: %d\r\n", beacon_angle);
            tx_str(DEBUGTX,buffer);
            break;
        }
    }
}
