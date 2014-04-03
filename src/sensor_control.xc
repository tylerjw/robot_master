/*
 * sensor_control.xc
 *
 *  Created on: Apr 2, 2014
 *      Author: rdbeethe
 */
#include <uart.h>
#include <platform.h>
#include <xs1.h>
#include <sensor_control.h>
#include <LineMatcher.h>

// globals ///

int points_a[POINT_BUFFER_LENGTH][2];
int points_b[POINT_BUFFER_LENGTH][2];
vector vectors_a[POINT_BUFFER_LENGTH];
vector vectors_b[POINT_BUFFER_LENGTH];

int matching_point[POINT_BUFFER_LENGTH]; // holds the index of the point in b that the point in a matches
const int unfound = -1;
long distances[POINT_BUFFER_LENGTH];

int col_idx[MAX_COLUMNS]; // a
int row_idx[MAX_ROWS]; // b

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

int picture_with_laser(interface uart_int client rx, out port TX, out port LASER,
        timer t, int start, int timeout, int wait_delay) {
    int error = 0;
    LASER <: 1; // laserbeam on!
    rx.clear();
    tx(TX, CAPTURE_DOTS);
    while(!error && rx.getc_a() != 0) {
        delay(wait_delay);
        if(time_after(t,start,timeout)) {
            error = -1;
            break;
        }
    }
    while(!error && rx.getc_b() != 0) {
        delay(wait_delay);
        if(time_after(t,start,timeout)) {
            error = -1;
            break;
        }
    }
    LASER <: 0; // laserbeam off!
    return error;
}

int picture_without_laser(interface uart_int client rx, out port TX, timer t,
        int start, int timeout, int wait_delay) {
    int error = 0;
    rx.clear();
    tx(TX, CAPTURE_NORM);
    while(!error && rx.getc_a() != 1) {
        delay(wait_delay);
        if(time_after(t,start,timeout)) {
            error = -1;
            break;
        }
    }
    while(!error && rx.getc_b() != 2) {
        delay(wait_delay);
        if(time_after(t,start,timeout)) {
            error = -1;
            break;
        }
    }
    return error;
}

int read_data_a(interface uart_int client rx, out port TX, timer t, int start,
        int timeout, int wait_delay, int & num_points_a, int & num_columns_a) {

    int error = 0;

    t :> start; // reset timer

    rx.clear();
    tx(TX, READ_A);
    while(rx.avalible_a() < 4) {
        delay(wait_delay);
        if(time_after(t,start,timeout)) {
            error = -1;
            break;
        }
    }

    num_points_a = rx.geti_a();
    num_columns_a = rx.geti_a();

    t :> start; // reset timer

    while(rx.avalible_a() < 4*num_points_a && !error) {
        delay(wait_delay);
//        sprintf(buffer, "%d\r\n", rx.avalible_a()); // for debugging...
//        for(int i = 0; i < strlen(buffer); i++)   // requires DEBUGTX and a buffer
//            tx(DEBUGTX, buffer[i]);

        if(time_after(t,start,timeout)) {
            error = -1;
            break;
        }
    }
    //LEDS <: 2; // not implemented here

    for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
        points_a[i][0] = rx.geti_a();
        points_a[i][1] = rx.geti_a();
    }

    t :> start; // reset timer

    for(int i = 0; i < num_columns_a && i < MAX_COLUMNS && !error; i++) {
        while(rx.avalible_a() < 2 && !error) {
            delay(wait_delay);
            if(time_after(t,start,timeout)) {
                error = -1;
                break;
            }
        }
        col_idx[i] = rx.geti_a();
    }

//    LEDS <: 3; // not implemented here
    return error;
}

int read_data_b(interface uart_int client rx, out port TX, timer t, int start,
        int timeout, int wait_delay, int & num_points_b, int & num_rows_b) {

    int error = 0;

    t :> start; // reset timer

    tx(TX, READ_B);
    while(rx.avalible_b() < 4 && !error) {
        delay(wait_delay);
        if(time_after(t,start,timeout)) {
            error = -1;
            break;
        }
    }

    num_points_b = rx.geti_b();
    num_rows_b = rx.geti_b();

    // get the points
    while(rx.avalible_b() < 4*num_points_b && !error) {
        delay(wait_delay);
        if(time_after(t,start,timeout)) {
            error = -1;
            break;
        }
    }

    for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
        points_b[i][0] = rx.geti_b();
        points_b[i][1] = rx.geti_b();
    }

    for(int i = 0; i < num_rows_b && i < MAX_ROWS; i++) {
        while(rx.avalible_b() < 2 && !error) {
            delay(wait_delay);
            if(time_after(t,start,timeout)) {
                error = -1;
                break;
            }
        }
        if(error) {
            break;
        }
        row_idx[i] = rx.geti_b();
    }
    //LEDS <: 4; // not implemented

    return error;
}

void calibrate_and_match_points(int num_points_a, int num_columns_a,
        int num_points_b, int num_rows_b) {
    // calibrate!
    // convert to vectors
    for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
        vector_init(vectors_a[i], points_a[i], 0);
    }
    for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
        vector_init(vectors_b[i], points_b[i], 1);
    }

    //printf("vectors initialized\n");

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
            //printf("(%d, %d) - (%d, %d) - %d\n", points_a[p][0], points_a[p][1], points_b[bi][0], points_b[bi][1], distances[p]);
//                    printf("(%d, %d, %d) - (%d, %d, %d)\n", vectors_a[p].x, vectors_a[p].y, vectors_a[p].z,
//                            vectors_b[bi].x, vectors_b[bi].y, vectors_b[bi].z);
        }
    }
}

void delay(int delay){
    timer t;
    int time;
    t :> time;
    time += delay;
    t when timerafter(time) :> void;
}
