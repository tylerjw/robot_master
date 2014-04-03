/*
 * sensor_control.h
 *
 *  Created on: Apr 2, 2014
 *      Author: rdbeethe
 */

#ifndef SENSOR_CONTROL_H_
#define SENSOR_CONTROL_H_

#define CAPTURE_DOTS    0
#define CAPTURE_NORM    1
#define READ_A          2
#define READ_B          3

#define POINT_BUFFER_LENGTH   300
#define MAX_COLUMNS           30
#define MAX_ROWS              30

//#define START           0b00
//#define DONE            0b11

#define DISTANCE_THRESHOLD      2

void delay(int delay);
int time_after(timer t, int start, int max);

int picture_with_laser(interface uart_int client rx, out port TX, out port LASER,
        timer t, int start, int timeout, int wait_delay);

int picture_without_laser(interface uart_int client rx, out port TX, timer t,
        int start, int timeout, int wait_delay);

int read_data_a(interface uart_int client rx, out port TX, timer t, int start,
        int timeout, int wait_delay, int & num_points_a, int & num_columns_a);

int read_data_b(interface uart_int client rx, out port TX, timer t, int start,
        int timeout, int wait_delay, int & num_points_b, int & num_rows_b);

void calibrate_and_match_points(int num_points_a, int num_columns_a,
        int num_points_b, int num_rows_b);

#endif /* SENSOR_CONTROL_H_ */
