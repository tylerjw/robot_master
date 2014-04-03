/*
 * robot_master.xc
 *
 *  Created on: Mar 18, 2014
 *      Author: tylerjw
 */

#include <uart.h>
#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <string.h>
#include <LineMatcher.h>
#include <SurfaceAnalyzer.h>
#include <motorController.h>
#include <MovementControl.h>
#include <sensor_control.h>

out port LEDS = on tile[0]:XS1_PORT_4F;

in port BUTTON1 = on tile[0]:XS1_PORT_1K;
in port BUTTON2 = on tile[0]:XS1_PORT_1L;

in port RXB = on tile[0]:XS1_PORT_1E;
in port RXA = on tile[0]:XS1_PORT_1F;
out port TX = on tile[0]:XS1_PORT_4C;
in port ARDUINO_RX = on tile[0]:XS1_PORT_1G;
out port ARDUINO_INT = on tile[0]:XS1_PORT_1H;

out port DEBUGTX = on tile[0]:XS1_PORT_1D;
in port DEBUGRX = on tile[0]:XS1_PORT_1C;

out port MOTORS = on tile[0]:XS1_PORT_8A;
in port ENCODERS = on tile[0]:XS1_PORT_4D;

out port LASER = on tile[0]:XS1_PORT_1B;

//#define DEBUG

interface laser_int {
    void laser_on();
    void laser_off();
};

void button_control(interface uart_int client rx) {
    int num_points_a;
    int num_points_b;
    int num_columns_a;
    int num_rows_b;

    char buffer[80];

    timer t;
    int start;
    const int timeout = 1e6;
    int error = 0;
    const int wait_delay = 1e4;

    //printf("ready\n");

    LEDS <: 0;
    while(1) {
        if(error) {
            //printf("error!\n");
        }
        error = 0;
        t :> start;
        select {
        case BUTTON1 when pinseq(0) :> void:
            error = picture_with_laser(rx,TX,LASER,t,start,timeout,wait_delay);
            BUTTON1 when pinseq(1) :> void;
            break;

        case BUTTON2 when pinseq(0) :> void:
            tx_str(DEBUGTX, "button 2 pressed\r\n");
            error = picture_without_laser(rx,TX,t,start,timeout,wait_delay);
            if(error) {
                break;
            }

            //printf("took the no dots image\n");
            delay(100e6); // ??

            t :> start; // reset timeout

            error = read_data_a(rx,TX,t,start,timeout,wait_delay,
                    num_points_a,num_columns_a);

            if(error) {
                break;
            }

            sprintf(buffer, "num_points_a: %d, num_columns_a %d\r\n", num_points_a, num_columns_a);
            tx_str(DEBUGTX,buffer);

            LEDS <: 1;

            error = read_data_b(rx,TX,t,start,timeout,wait_delay,
                    num_points_b,num_rows_b);

            if(error) {
                break;
            }

            BUTTON2 when pinseq(1) :> void;
            sprintf(buffer,"num_points_b: %d, num_rows_b: %d\n", num_points_b, num_rows_b);
            tx_str(DEBUGTX,buffer);

            LEDS <: 2;
//            for(int i = 0, j = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
//                if(i == col_idx[j] && j < MAX_COLUMNS) {
//                    printf("Column %d:\n", j++);
//                }
//                printf("(%d, %d)\n", points_a[i][0], points_a[i][1]);
//            }
            //printf("num_points_b: %d, num_rows: %d\n", num_points_b, num_rows_b); // bad!!!!!
//            for(int i = 0, j = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
//                if(i == row_idx[j] && j < MAX_ROWS) {
//                    printf("Row %d:\n", j++);
//                }
//                printf("(%d, %d)\n", points_b[i][0], points_b[i][1]);
//            }
            calibrate_and_match_points(num_points_a,num_columns_a,num_points_b,num_rows_b);
            LEDS <: 3;
            break;
        }
    }

}

void uart_rx_thread(streaming chanend rx_chan, in port rx_port) {
    int c;
    while(1) {
        c = rx(rx_port);
        //printf("rx: %d\n", c);
        rx_chan <: c;
    }
}

void pwm_laser_thread(interface laser_int server from_button) {
    int laser_on = 0;
    int laser_state = 0;
    timer t;
    int time;

    int Laser_PWM_period = 1e6;
    int PWM_dutyCycle = 80;

    t :> time;

    while(1) {
        if(laser_state == 0) {
            time += Laser_PWM_period/100*(100-PWM_dutyCycle);
        } else {
            time += Laser_PWM_period/100*PWM_dutyCycle;
        }
        time += Laser_PWM_period/100*PWM_dutyCycle;
        select {
            case from_button.laser_on():
                laser_on = 1;
                break;
            case from_button.laser_off():
                laser_on = 0;
                break;
            case t when timerafter(time) :> void :
                if(laser_state == 1) {
                    LASER <: 0;
                    laser_state = 0;
                } else if(laser_on == 1 && laser_state == 0) {
                    LASER <: 1;
                    laser_state = 1;
                }
                break;
        }
    }
}

void debug_tx_test() {
    char buffer[80];
    while(1) {
        sprintf(buffer, "bla bla %d\r\n", (14));
        for(int i = 0; i < strlen(buffer); i++) {
            tx(DEBUGTX, buffer[i]);
        }
        delay(100e6);
    }
}

int extern line_matcher_test_thread();
void extern laser_test_thread(void);
void arduino_thread(interface arduino_int client ard_rx, out port beacon);

int main(void) {
    interface uart_int rx_int;
    interface arduino_int arduino;
    par {
        on tile[0]:button_control(rx_int);
        on tile[0]:multiRX(rx_int,arduino,RXA,RXB,ARDUINO_RX);
//        on tile[0]:arduino_thread(arduino, ARDUINO_INT);
//        on tile[0]:line_matcher_test_thread();
//        on tile[0]:laser_test_thread();
//        on tile[0]:debug_tx_test();
    }
    return 0;
}
