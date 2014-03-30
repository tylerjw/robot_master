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


out port LEDS = on tile[0]:XS1_PORT_4F;

in port BUTTON1 = on tile[0]:XS1_PORT_1K;
in port BUTTON2 = on tile[0]:XS1_PORT_1L;

in port RXB = on tile[0]:XS1_PORT_1E;
in port RXA = on tile[0]:XS1_PORT_1F;
out port TX = on tile[0]:XS1_PORT_4C;

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

int wait_for_continue(streaming chanend rxa, streaming chanend rxb) {
    int c = 1;

    while(c != 0) {
        rxa :> c;
    }

    c = 1;
    while(c != 0) {
        rxb :> c;
    }
}

int uart_getc(streaming chanend rx) {
    int c;
    rx :> c;
    return c;
}

int uart_geti(streaming chanend rx) {
    int c, r;
    rx :> c;
    r = c;
    rx :> c;
    r |= c << 8;
    return r;
}

void button_control(streaming chanend rxa, streaming chanend rxb) {
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
            //delay(20e6); // debounce
#ifdef DEBUG
            printf("Button 1 pressed\n");
#endif
            //laser.laser_on();
            LASER <: 1;
            tx(TX, CAPTURE_DOTS);
            wait_for_continue(rxa, rxb);
            LASER <: 0;
            BUTTON1 when pinseq(1) :> void;
            delay(20e6); // debounce
            break;


        case BUTTON2 when pinseq(0) :> void:
            //delay(20e6); // debounce
#ifdef DEBUG
            printf("Button 2 pressed\n");
#endif
            tx(TX, CAPTURE_NORM);
            wait_for_continue(rxa, rxb);

            tx(TX, READ_A);
            num_points_a = uart_geti(rxa);
            num_columns_a = uart_geti(rxa);
            // get the points
            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                points_a[i][0] = uart_geti(rxa);
                points_a[i][1] = uart_geti(rxa);
            }
            for(int i = 0; i < num_columns_a && i < MAX_COLUMNS; i++) {
                col_idx[i] = uart_geti(rxa);
            }
            LEDS <: 1;
#ifdef DEBUG
            printf("num_points_a: %d, num_columns: %d\n", num_points_a, num_columns_a);
            for(int i = 0; i < num_points_a && i < POINT_BUFFER_LENGTH; i++) {
                printf("(%d, %d)\n", points_a[i][0], points_a[i][1]);
            }
#endif

            tx(TX, READ_B);
            num_points_b = uart_geti(rxb);
            num_rows_b = uart_geti(rxb);
            // get the points
            for(int i = 0; i < num_points_b && i < POINT_BUFFER_LENGTH; i++) {
                points_b[i][0] = uart_geti(rxb);
                points_b[i][1] = uart_geti(rxb);
            }
            for(int i = 0; i < num_rows_b && i < MAX_ROWS; i++) {
                row_idx[i] = uart_geti(rxb);
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

/*
void sensor_control(void) {
    int n_points_a = 0;
    int n_points_b = 0;

    int points_a[POINT_BUFFER_LENGTH][2];
    int points_b[POINT_BUFFER_LENGTH][2];

    int n_columns_a = 0;
    int col_idx[MAX_COLUMNS];
    int n_rows_b = 0;
    int row_idx[MAX_ROWS];

    //uart_init(1e6); // init the baud rate - not needed (default)

    while(1) {
        // stop movement!
        // turn on laser!
        // capture the dots
        tx(TX, CAPTURE_DOTS);
        // turn off laser!
        tx(TX, CAPTURE_NORM); // does math imidiatly

        // clear out the point buffers - time for math to be done
        for(int i = 0; i < POINT_BUFFER_LENGTH; i++) {
            for(int j = 0; j < 2; j++) {
                points_a[i][j] = 0;
                points_b[i][j] = 0;
            }
        }
        for(int i = 0; i < MAX_COLUMNS; i++)
            col_idx[i] = 0;
        for(int i = 0; i < MAX_ROWS; i++)
            row_idx[i] = 0;

        tx(TX, READ_A); // camera a send your data
        n_points_a = rx(RX);
        n_points_a |= rx(RX) << 8;
        n_columns_a = rx(RX);
        n_columns_a |= rx(RX) << 8;
        for(int i = 0; i < n_points_a; i++) {
            for(int j = 0; j < 2; j++) {
                points_a[i][j] = rx(RX);
                points_a[i][j] |= rx(RX) << 8;;
            }
        }
        for(int i = 0; i < n_columns_a; i++) {
            col_idx[i] = rx(RX);
        }

        tx(TX, READ_B); // camera b send your data
        n_points_b = rx(RX);
        n_points_b |= rx(RX) << 8;
        n_rows_b = rx(RX);
        n_rows_b |= rx(RX) << 8;
        for(int i = 0; i < n_points_b; i++) {
            for(int j = 0; j < 2; j++) {
                points_b[i][j] = rx(RX);
                points_b[i][j] |= rx(RX) << 8;;
            }
        }
        for(int i = 0; i < n_rows_b; i++) {
            row_idx[i] = rx(RX);
        }

        printf("A: points: %d, columns: %d\n", n_points_a, n_columns_a);
        printf("B: points: %d, row: %d\n", n_points_b, n_rows_b);
        delay(100e6);
    }
}
*/

int main(void) {
    streaming chan rxa, rxb;
    par {
        on tile[0]:button_control(rxa, rxb);
        on tile[0]:uart_rx_thread(rxa, RXA);
        on tile[0]:uart_rx_thread(rxb, RXB);
    }
    return 0;
}
