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

out port LASER = on tile[0]:XS1_PORT_1B;

void delay(int delay){
    timer t;
    int time;
    t :> time;
    time += delay;
    t when timerafter(time) :> void;
}

#define CAPTURE_DOTS    0
#define CAPTURE_NORM    1
#define READ_A          2
#define READ_B          3

#define POINT_BUFFER_LENGTH   300
#define MAX_COLUMNS           30
#define MAX_ROWS              30

#define START           0b00
#define DONE            0b11

#define DISTANCE_THRESHOLD      2

//#define DEBUG

interface laser_int {
    void laser_on();
    void laser_off();
};

int time_after(timer t, int start, int max) {
    int end;
    t :> end;
    if(end > start) {
        if((start - end) > max) {
            //printf("timeout!\n");
            //LEDS <: 0b1111;
            return -1;
        }
    } else {
        if((2147483647 - start) + end > max) {
            //printf("overflow timeout\n");
            //LEDS <: 0b0111;
            return -1;
        }
    }
    return 0; // good
}

void button_control(interface uart_int client rx) {
    int num_points_a;
    int num_points_b;
    int num_columns_a;
    int num_rows_b;

    char buffer[80];

    int points_a[POINT_BUFFER_LENGTH][2];
    int points_b[POINT_BUFFER_LENGTH][2];
    vector vectors_a[POINT_BUFFER_LENGTH];
    vector vectors_b[POINT_BUFFER_LENGTH];

    int matching_point[POINT_BUFFER_LENGTH]; // holds the index of the point in b that the point in a matches
    const int unfound = -1;
    long distances[POINT_BUFFER_LENGTH];

    int col_idx[MAX_COLUMNS]; // a
    int row_idx[MAX_ROWS]; // b

    timer t;
    int start;
    const int timeout = 1e6;
    int error = 0;
    int wait_delay = 1e4;

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

            LASER <: 1; // laserbeam on!
            rx.clear();
            tx(TX, CAPTURE_DOTS);
            while(!error && rx.getc_a() != 0) {
                delay(wait_delay);
                if(time_after(t,start,timeout)) {
                    error = 1;
                    break;
                }
            }
            while(!error && rx.getc_b() != 0) {
                delay(wait_delay);
                if(time_after(t,start,timeout)) {
                    error = 1;
                    break;
                }
            }
            LASER <: 0; // laserbeam off!
            BUTTON1 when pinseq(1) :> void;
            break;

        case BUTTON2 when pinseq(0) :> void:
            rx.clear();
            tx(TX, CAPTURE_NORM);
            while(!error && rx.getc_a() != 1) {
                delay(wait_delay);
                if(time_after(t,start,timeout)) {
                    error = 1;
                    break;
                }
            }
            if(error) {
                break;
            }
            while(!error && rx.getc_b() != 2) {
                delay(wait_delay);
                if(time_after(t,start,timeout)) {
                    error = 1;
                    break;
                }
            }
            if(error) {
                break;
            }

            //printf("took the no dots image\n");
            delay(100e6);

            t :> start; // reset timeout

            rx.clear();
            tx(TX, READ_A);
            while(rx.avalible_a() < 4 && !error) {
                delay(wait_delay);
                if(time_after(t,start,timeout)) {
                    error = 1;
                    break;
                }
            }
            if(error) {
                break;
            }

            num_points_a = rx.geti_a();
            num_columns_a = rx.geti_a();
            sprintf(buffer, "%d, %d\r\n", num_points_a, num_columns_a);
            for(int i = 0; i < strlen(buffer); i++)
                tx(DEBUGTX, buffer[i]);

            //printf("num_points_a: %d, num_columns: %d\n", num_points_a, num_columns_a);
            LEDS <: 1;

            // get the points
            int i = 0;

            t :> start; // reset timer

            while(rx.avalible_a() < 4*num_points_a && !error) {
                delay(wait_delay);
                sprintf(buffer, "%d\r\n", rx.avalible_a());
                for(int i = 0; i < strlen(buffer); i++)
                    tx(DEBUGTX, buffer[i]);

                if(time_after(t,start,timeout)) {
                    error = 1;
                    break;
                }
            }
            if(error) {
                break;
            }
            LEDS <: 2;

            //printf("ready to recieve points\n");

            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                points_a[i][0] = rx.geti_a();
                points_a[i][1] = rx.geti_a();
            }

            t :> start; // reset timer
            for(int i = 0; i < num_columns_a && i < MAX_COLUMNS; i++) {
                while(rx.avalible_a() < 2 && !error) {
                    delay(wait_delay);
                    if(time_after(t,start,timeout)) {
                        error = 1;
                        break;
                    }
                }
                if(error) {
                    break;
                }
                col_idx[i] = rx.geti_a();
            }
            LEDS <: 3;

            //printf("read from the first camera\n");

            t :> start; // reset timer

            tx(TX, READ_B);
            while(rx.avalible_b() < 4 && !error) {
                delay(wait_delay);
                if(time_after(t,start,timeout)) {
                    error = 1;
                    break;
                }
            }
            if(error) {
                break;
            }
            num_points_b = rx.geti_b();
            num_rows_b = rx.geti_b();

            // get the points
            for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                while(rx.avalible_b() < 4 && !error) {
                    delay(wait_delay);
                    if(time_after(t,start,timeout)) {
                        error = 1;
                        break;
                    }
                }
                if(error) {
                    break;
                }
                points_b[i][0] = rx.geti_b();
                points_b[i][1] = rx.geti_b();
            }
            for(int i = 0; i < num_rows_b && i < MAX_ROWS; i++) {
                while(rx.avalible_b() < 2 && !error) {
                    delay(wait_delay);
                    if(time_after(t,start,timeout)) {
                        error = 1;
                        break;
                    }
                }
                if(error) {
                    break;
                }
                row_idx[i] = rx.geti_b();
            }
            LEDS <: 4;

            if(error) {
                break;
            }

            BUTTON2 when pinseq(1) :> void;
            printf("num_points_a: %d, num_columns: %d\n", num_points_a, num_columns_a);
//            for(int i = 0, j = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
//                if(i == col_idx[j] && j < MAX_COLUMNS) {
//                    printf("Column %d:\n", j++);
//                }
//                printf("(%d, %d)\n", points_a[i][0], points_a[i][1]);
//            }
            printf("num_points_b: %d, num_rows: %d\n", num_points_b, num_rows_b);
//            for(int i = 0, j = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
//                if(i == row_idx[j] && j < MAX_ROWS) {
//                    printf("Row %d:\n", j++);
//                }
//                printf("(%d, %d)\n", points_b[i][0], points_b[i][1]);
//            }

            // calibrate!
            // convert to vectors
            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                vector_init(vectors_a[i], points_a[i], 0);
            }
            for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                vector_init(vectors_b[i], points_b[i], 1);
            }

            printf("vectors initialized\n");

            // inistialize matching point array
            for(int i = 0; i < POINT_BUFFER_LENGTH; i++) {
                matching_point[i] = unfound;
            }

            // comare columns to rows
            int a_idx, b_idx;
            // iterate through the columns and rows
            for(int c = 0; c < num_columns_a && c < MAX_COLUMNS; c++) {
                for(int r = 0; r < num_rows_b && r < MAX_ROWS; r++) {
                    //printf("col: %d, row: %d\n", c, r);
                    // iterate through the points in these columns and rows
                    long shortest_distance = 0;
                    int shortest_a, shortest_b;
                    for(a_idx=col_idx[c];a_idx < num_points_a;a_idx++) {
                        if(c < (num_columns_a - 1) && a_idx == col_idx[c+1]) {
                            // if not last column but we reached the next row break!
                            break; // done with this set of rows and columns... get next one
                        }
                        for(b_idx=row_idx[r];b_idx < num_points_b;b_idx++) {
                            if(r < (num_rows_b - 1) && b_idx == row_idx[r+1]) {
                                // similar as above... done with this row... next column
                                break;
                            }
                            // do the comparison
                            // test that this isn't a point we've already solved for
                            // if not solved for this point... test
                            if(matching_point[a_idx] == unfound) {
                                testResult r;
                                vector_togetherness(vectors_a[a_idx], vectors_b[b_idx], r);
                                if(r.togetherness < 0) {
                                    // points come together behind the camera
                                    continue;
                                }
                                if(r.n_magnitude == 0) {
                                    // parallel - bad
                                    continue;
                                }
                                long distance = vector_normalDistance(vectors_a[a_idx], vectors_b[b_idx], r);
                                if(distance < 0) {
                                    distance *= -1;
                                }
                                if(distance < shortest_distance || shortest_distance == 0) {
                                    shortest_distance = distance;
                                    shortest_a = a_idx;
                                    shortest_b = b_idx;
                                }
                            }
                        }
                    }
                    // tested all the points in this row and column combination
                    if(shortest_distance < DISTANCE_THRESHOLD) {
                        matching_point[shortest_a] = shortest_b;
                        distances[shortest_a] = shortest_distance;
                    }
                }
            }

            // done finding the points and columns that match

            // print the results
            for(int p = 0, c = 0; p < num_points_a; p++) {
                if(matching_point[p] != unfound) {
                    int bi = matching_point[p];
                    printf("(%d, %d) - (%d, %d) - %d\n", points_a[p][0], points_a[p][1], points_b[bi][0], points_b[bi][1], distances[p]);
//                    printf("(%d, %d, %d) - (%d, %d, %d)\n", vectors_a[p].x, vectors_a[p].y, vectors_a[p].z,
//                            vectors_b[bi].x, vectors_b[bi].y, vectors_b[bi].z);
                }
            }

            break;
        }
    }
    printf("something horable happened\n"); // should never get here
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
        //on tile[0]:button_control(rx_int);
        on tile[0]:multiRX(rx_int,arduino,RXA,RXB,ARDUINO_RX);
        on tile[0]:arduino_thread(arduino, ARDUINO_INT);
//        on tile[0]:line_matcher_test_thread();
//        on tile[0]:laser_test_thread();
//        on tile[0]:debug_tx_test();
    }
    return 0;
}
