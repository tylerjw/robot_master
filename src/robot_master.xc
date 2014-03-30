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


out port LEDS = on tile[0]:XS1_PORT_4F;

in port BUTTON1 = on tile[0]:XS1_PORT_1K;
in port BUTTON2 = on tile[0]:XS1_PORT_1L;

in port RXB = on tile[0]:XS1_PORT_1E;
in port RXA = on tile[0]:XS1_PORT_1F;
out port TX = on tile[0]:XS1_PORT_4C;

out port DEBUGTX = on tile[0]:XS1_PORT_1D;
in port DEBUGRX = on tile[0]:XS1_PORT_1C;

out port LASER = on tile[0]:XS1_PORT_1B;

void delay(int delay){
    timer t;
    int time;
    t :> time;
    time += delay;
    t when timerafter(time) :> void;
}

#define CAPTURE_DOTS    '0'
#define CAPTURE_NORM    '1'
#define READ_A          '2'
#define READ_B          '3'

#define POINT_BUFFER_LENGTH   300
#define MAX_COLUMNS           30
#define MAX_ROWS              30

#define START           0b00
#define DONE            0b11

#define DEBUG

interface laser_int {
    void laser_on();
    void laser_off();
};

int watchdog_timer(int init, int d) {
    static int base;
    int time;
    const int timeout = 2e8; // 2 second timeout
    timer t;
    delay(d);
    if (init) {
        t :> base;
    } else {
        t :> time;
        if((time - base) > timeout) {
            return 1;
        }
    }
    return 0;
}

void button_control(interface uart_int client rx) {
    int num_points_a;
    int num_points_b;
    int num_columns_a;
    int num_rows_b;

    int points_a[POINT_BUFFER_LENGTH][2];
    int points_b[POINT_BUFFER_LENGTH][2];
    int col_idx[MAX_COLUMNS];
    int row_idx[MAX_ROWS];

    LEDS <: 0;
    while(1) {
        select {
        case BUTTON1 when pinseq(0) :> void:
            watchdog_timer(1,0); // init watchdog
#ifdef DEBUG
            printf("Button 1 pressed\n");
#endif
            //laser.laser_on();
            LASER <: 1;
            rx.clear();
            tx(TX, CAPTURE_DOTS);
            while(rx.getc_a() != 0)
                if(watchdog_timer(0,1e6))
                    break;
            while(rx.getc_b() != 0)
                if(watchdog_timer(0,1e6))
                    break;
            LASER <: 0;
            BUTTON1 when pinseq(1) :> void;

#ifdef DEBUG
            printf("took the forst picture\n");
#endif
            break;


        case BUTTON2 when pinseq(0) :> void:
            watchdog_timer(1,0); // init watchdog
#ifdef DEBUG
            printf("Button 2 pressed\n");
#endif
            rx.clear();
            tx(TX, CAPTURE_NORM);
            while(rx.getc_a() != 0)
                if(watchdog_timer(0,1e6))
                    break;
            while(rx.getc_b() != 0)
                if(watchdog_timer(0,1e6))
                    break;
#ifdef DEBUG
            printf("Captured no dots...\n");
#endif

            rx.clear();
            tx(TX, READ_A);
            while(rx.avalible_a() < 4)
                if(watchdog_timer(0,1e6))
                    break;
            num_points_a = rx.geti_a();
            num_columns_a = rx.geti_a();

#ifdef DEBUG
            printf("got the number of points and columns\n");
#endif
            // get the points
            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                while(rx.avalible_a() < 4)
                    if(watchdog_timer(0,1e6))
                        break;
                points_a[i][0] = rx.geti_a();
                points_a[i][1] = rx.geti_a();
            }
            for(int i = 0; i < num_columns_a && i < MAX_COLUMNS; i++) {
                while(rx.avalible_a() < 2)
                    if(watchdog_timer(0,1e6))
                        break;
                col_idx[i] = rx.geti_a();
            }
            LEDS <: 1;
#ifdef DEBUG
            printf("num_points_a: %d, num_columns: %d\n", num_points_a, num_columns_a);
            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                printf("(%d, %d)\n", points_a[i][0], points_a[i][1]);
            }
#endif

            tx(TX, READ_B);
            while(rx.avalible_b() < 4)
                if(watchdog_timer(0,1e6))
                    break;
            num_points_b = rx.geti_b();
            num_rows_b = rx.geti_b();

            // get the points
            for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                while(rx.avalible_b() < 4)
                    if(watchdog_timer(0,1e6))
                        break;
                points_b[i][0] = rx.geti_b();
                points_b[i][1] = rx.geti_b();
            }
            for(int i = 0; i < num_rows_b && i < MAX_ROWS; i++) {
                while(rx.avalible_b() < 2)
                    if(watchdog_timer(0,1e6))
                        break;
                row_idx[i] = rx.geti_b();
            }
            LEDS <: 2;
#ifdef DEBUG
            printf("num_points_b: %d, num_rows: %d\n", num_points_b, num_rows_b);
            for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                printf("(%d, %d)\n", points_b[i][0], points_b[i][1]);
            }
#endif
            BUTTON2 when pinseq(1) :> void;

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

int main(void) {
    interface uart_int rx_int;
    par {
        on tile[0]:button_control(rx_int);
        on tile[0]:multiRX(rx_int,DEBUGRX,RXB);
    }
    return 0;
}
