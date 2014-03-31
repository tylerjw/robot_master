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

//#define DEBUG

interface laser_int {
    void laser_on();
    void laser_off();
};

int watchdog_timer(int init, int d) {
    static int end;
    int time;
    const int timeout = 3e8; // 2 second timeout
    timer t;
    delay(d);
    if (init) {
        t :> end;
        end += timeout;
    } else {
        t :> time;
        if(end > timeout) {
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
    vector vectors_a[POINT_BUFFER_LENGTH];
    vector vectors_b[POINT_BUFFER_LENGTH];

    int matching_point[POINT_BUFFER_LENGTH]; // holds the index of the point in b that the point in a matches
    const int unfound = -1;
    long distances[POINT_BUFFER_LENGTH];

    int col_idx[MAX_COLUMNS]; // a
    int row_idx[MAX_ROWS]; // b

    LEDS <: 0;
    while(1) {
        select {
        case BUTTON1 when pinseq(0) :> void:
            //watchdog_timer(1,0); // init watchdog
            LASER <: 1; // laserbeam on!
            rx.clear();
            tx(TX, CAPTURE_DOTS);
            while(rx.getc_a() != 0) delay(1e6); // TODO: implement some sort of watchdog timer
            while(rx.getc_b() != 0) delay(1e6);
            LASER <: 0; // laserbeam off!
            BUTTON1 when pinseq(1) :> void;

            break;


        case BUTTON2 when pinseq(0) :> void:
            //watchdog_timer(1,0); // init watchdog
            rx.clear();
            tx(TX, CAPTURE_NORM);
            while(rx.getc_a() != 0) delay(1e6);
            while(rx.getc_b() != 0) delay(1e6);

            rx.clear();
            tx(TX, READ_A);
            while(rx.avalible_a() < 4) delay(1e6);
            num_points_a = rx.geti_a();
            num_columns_a = rx.geti_a();

            // get the points
            int i = 0;

            while(rx.avalible_a() < 4*num_points_a) delay(10e6);
            LEDS <: 1;

            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                points_a[i][0] = rx.geti_a();
                points_a[i][1] = rx.geti_a();
            }
            for(int i = 0; i < num_columns_a && i < MAX_COLUMNS; i++) {
                //while(rx.avalible_a() < 2) delay(1e6);
                col_idx[i] = rx.geti_a();
            }
            LEDS <: 2;

            tx(TX, READ_B);
            while(rx.avalible_b() < 4) delay(1e6);
            num_points_b = rx.geti_b();
            num_rows_b = rx.geti_b();

            // get the points
            for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                while(rx.avalible_b() < 4) delay(1e6);
                points_b[i][0] = rx.geti_b();
                points_b[i][1] = rx.geti_b();
            }
            for(int i = 0; i < num_rows_b && i < MAX_ROWS; i++) {
                while(rx.avalible_b() < 2) delay(1e6);
                row_idx[i] = rx.geti_b();
            }
            LEDS <: 3;

            BUTTON2 when pinseq(1) :> void;
            printf("num_points_a: %d, num_columns: %d\n", num_points_a, num_columns_a);
            for(int i = 0, j = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                if(i == col_idx[j] && j < MAX_COLUMNS) {
                    printf("Column %d:\n", j++);
                }
                printf("(%d, %d)\n", points_a[i][0], points_a[i][1]);
            }
            printf("num_points_b: %d, num_rows: %d\n", num_points_b, num_rows_b);
            for(int i = 0, j = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                if(i == row_idx[j] && j < MAX_ROWS) {
                    printf("Row %d:\n", j++);
                }
                printf("(%d, %d)\n", points_b[i][0], points_b[i][1]);
            }

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
                    if(shortest_distance < 2) {
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
                    printf("(%d, %d, %d) - (%d, %d, %d)\n", vectors_a[p].x, vectors_a[p].y, vectors_a[p].z,
                            vectors_b[bi].x, vectors_b[bi].y, vectors_b[bi].z);
                }
            }

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

int extern line_matcher_test_thread();

int main(void) {
    interface uart_int rx_int;
    par {
        on tile[0]:button_control(rx_int);
        on tile[0]:multiRX(rx_int,RXA,RXB);
//        on tile[0]:line_matcher_test_thread();
    }
    return 0;
}
